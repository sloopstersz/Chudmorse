MODE.name = "framed"

local MODE = MODE

local ROLE_CIVILIAN, ROLE_COP, ROLE_KILLER = 0, 1, 2

--\\ Fonts
local function CreateFonts()
	local sh = ScrH()

	local function make(name, size, weight, font)
		surface.CreateFont(name, {
			font = font or "Roboto",
			size = math.max(12, math.floor(sh * size)),
			weight = weight or 500,
			antialias = true,
		})
	end

	make("Framed_Type", 0.030, 500)
	make("Framed_Small", 0.023, 500)
	make("Framed_Tiny", 0.017, 500)
	make("Framed_Label", 0.019, 600)
	make("Framed_Name", 0.024, 600)
	make("Framed_Number", 0.120, 700)
	make("Framed_Header", 0.030, 700)
	make("Framed_Notice", 0.030, 600)
	make("Framed_Stamp", 0.040, 800)
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "Framed_Fonts", CreateFonts)
--//

--\\ State
local State = {}

local function ResetState()
	State = {
		role = nil,
		targets = {},
		flavor = {},
		notice = nil,
		releaseAt = 0,
		timeUpAt = 0,
		killTime = 0,
	}
end

ResetState()

local Panels = {}

local function KillPanel(key)
	if IsValid(Panels[key]) then
		Panels[key]:Remove()
	end

	Panels[key] = nil
end

local function clamp01(x)
	return math.Clamp(x, 0, 1)
end

local function ease_out(x)
	return 1 - (1 - x) ^ 3
end

local function ease_in_out(x)
	return x < 0.5 and 4 * x * x * x or 1 - ((-2 * x + 2) ^ 3) / 2
end

local function MakeOverlay()
	local pnl = vgui.Create("DPanel")
	pnl:SetPos(0, 0)
	pnl:SetSize(ScrW(), ScrH())
	pnl:SetMouseInputEnabled(false)
	pnl:SetKeyboardInputEnabled(false)
	pnl:SetPaintBackground(false)
	pnl.Start = CurTime()

	return pnl
end
--//

--\\ Music (sound.PlayFile, the same way the VIP / Juggernaut / Turf Wars intros play their tracks)
local Music

-- Like riot's and Turf Wars' music, the intro ignores the game's music slider (snd_musicvolume) so it is always heard.
-- framed_music_volume scales it: 1 = the file's own level, lower = quieter, higher = louder
-- (above 1 only has an effect if the audio engine allows amplification).
local MusicConVar = CreateClientConVar("framed_music_volume", "1", true, false, "Multiplier on the built-in Framed intro music volume (the built-in level is MODE.MusicVolume).", 0, 5)

local function MusicVolumeScale()
	return (MODE.MusicVolume or 1) * MusicConVar:GetFloat()
end

local function MusicStop()
	if Music and IsValid(Music.chan) then
		Music.chan:Stop()
	end

	Music = nil
end

-- fadeInDur: seconds. fadeAt: absolute time the fade out begins (nil = wait for MusicFadeNow). fadeDur: seconds.
local function MusicStart(path, peak, fadeInDur, fadeAt, fadeDur)
	MusicStop()

	-- the normal background music would fight with the intro track
	if hg and hg.DynaMusic and hg.DynaMusic.Stop then
		hg.DynaMusic:Stop()
	end

	local m = {
		path = path,
		peak = peak or 1,
		start = CurTime(),
		fadeIn = math.max(fadeInDur or 0, 0.01),
		fadeAt = fadeAt,
		fadeDur = math.max(fadeDur or 1, 0.05),
		vol = 0,
	}

	Music = m

	sound.PlayFile(path, "noplay", function(channel, errID, errName)
		if not IsValid(channel) then
			MsgC(Color(255, 90, 90), "[Framed] could not play " .. path .. " (error " .. tostring(errID) .. ": " .. tostring(errName) .. "). Is the file in garrysmod/sound/framed/ on this client?\n")
			return
		end

		-- the round moved on while the file was loading
		if Music ~= m then
			channel:Stop()
			return
		end

		m.chan = channel
		channel:SetVolume(m.vol * MusicVolumeScale())
		channel:Play()
	end)
end

local function MusicFadeNow(dur)
	if not Music or Music.fadeStart then return end

	Music.fadeStart = CurTime()
	Music.fadeFrom = Music.vol
	Music.fadeDur = math.max(dur or Music.fadeDur or 1, 0.05)
end

hook.Add("Think", "Framed_Music", function()
	if not Music then return end

	local now = CurTime()

	if not Music.fadeStart and Music.fadeAt and now >= Music.fadeAt then
		Music.fadeStart = now
		Music.fadeFrom = Music.vol
	end

	local vol

	if Music.fadeStart then
		vol = Music.fadeFrom * (1 - clamp01((now - Music.fadeStart) / Music.fadeDur))

		if vol <= 0.001 then
			MusicStop()
			return
		end
	else
		vol = Music.peak * clamp01((now - Music.start) / Music.fadeIn)
	end

	Music.vol = vol

	if IsValid(Music.chan) then
		Music.chan:SetVolume(vol * MusicVolumeScale())
	end
end)

hook.Add("ShutDown", "Framed_MusicStop", MusicStop)

-- Console helper: framed_music_test killer | civilian | cop
concommand.Add("framed_music_test", function(_, _, args)
	local which = string.lower(args[1] or "killer")
	local path = MODE.Sounds and MODE.Sounds[which]

	if not path then
		print("[Framed] usage: framed_music_test <killer|civilian|cop>")
		return
	end

	print("[Framed] " .. path .. " found on this client: " .. tostring(file.Exists(path, "GAME")) .. " | volume = " .. MusicVolumeScale() .. " (built-in " .. tostring(MODE.MusicVolume) .. " x framed_music_volume " .. MusicConVar:GetFloat() .. ")")
	MusicStart(path, 1, 0.3, CurTime() + 4, 5)
end)
--//

--\\ Appearance helpers (dress a model from a saved appearance, exactly like the round summary / main menu do)
local function appearance_model_data(appearance)
	if not istable(appearance) or not hg or not hg.Appearance or not hg.Appearance.PlayerModels then return end

	return hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
end

local function material_slot(mats, mat)
	if not mat then return end

	local want = string.lower(mat)

	for i = 1, #mats do
		if string.lower(mats[i] or "") == want then return i - 1 end
	end
end

local function appearance_color(clr)
	if not clr then return Vector(1, 1, 1), Color(245, 245, 245) end

	if isvector(clr) then
		return clr, Color(clr.x * 255, clr.y * 255, clr.z * 255)
	end

	local r = clr.r or clr.x or clr[1] or 255
	local g = clr.g or clr.y or clr[2] or 255
	local b = clr.b or clr.z or clr[3] or 255

	if r <= 1 and g <= 1 and b <= 1 then
		return Vector(r, g, b), Color(r * 255, g * 255, b * 255)
	end

	return Vector(r / 255, g / 255, b / 255), Color(r, g, b)
end

-- Camera / pose presets, taken from the round summary cards (they frame a whole character well).
local POSES = {
	{seqs = {"idle_all_angry", "idle_all_02", "idle_all_01"}, ang = Angle(0, 0, 0), cam = Vector(68, 0, 37), fov = 36, target = Vector(0, 0, 38), hy = 0, hp = 0},
	{seqs = {"idle_suitcase", "idle_all_01", "idle_all_02"}, ang = Angle(0, -16, 0), cam = Vector(70, 7, 35), fov = 33, target = Vector(0, 0, 37), hy = -0.45, hp = 0},
	{seqs = {"idle_all_scared", "idle_all_angry", "idle_all_01"}, ang = Angle(0, 24, 0), cam = Vector(63, -12, 34), fov = 40, target = Vector(0, 0, 35), hy = 0.25, hp = 0.15},
	{seqs = {"idle_all_angry", "idle_all_01", "idle_all_02"}, ang = Angle(0, -9, 0), cam = Vector(68, 11, 36), fov = 35, target = Vector(0, 0, 38), hy = -0.3, hp = -0.05},
}

local REF_ASPECT = 1.96 -- height / width of the round summary cards the presets were tuned for

-- Puts the saved look (model, clothes, face, bodygroups, colour) on a clientside model.
-- If the saved table can't be resolved, falls back to copying the live player's current look.
local function apply_look(ent, appearance, livePly)
	appearance = istable(appearance) and appearance or {}

	local model_data = appearance_model_data(appearance)
	local vec = appearance_color(appearance.AColor)

	if not appearance.AColor and IsValid(livePly) and livePly.GetPlayerColor then
		vec = livePly:GetPlayerColor()
	end

	ent.CurAppearance = appearance
	ent.GetPlayerColor = function() return vec end

	if ent.SetNWVector then
		ent:SetNWVector("PlayerColor", vec)
	end

	if model_data then
		if ent:GetModel() ~= model_data.mdl then
			ent:SetModel(model_data.mdl)
		end

		ent:SetSubMaterial()

		local mats = ent:GetMaterials()
		local clothes = istable(appearance.AClothes) and appearance.AClothes or {}
		local sexID = model_data.sex and 2 or 1

		for key, mat in SortedPairs(model_data.submatSlots or {}) do
			local slot = material_slot(mats, mat)
			local set = hg.Appearance.Clothes and hg.Appearance.Clothes[sexID]
			local cloth = set and (set[clothes[key] or "normal"] or set.normal)

			if slot and cloth then ent:SetSubMaterial(slot, cloth) end
		end

		if hg.Appearance.FacemapsSlots then
			local facemap_slot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[model_data.mdl]

			if facemap_slot then
				for i = 1, #mats do
					local set = hg.Appearance.FacemapsSlots[mats[i]]
					local facemap = set and set[appearance.AFacemap]

					if facemap then ent:SetSubMaterial(i - 1, facemap) end
				end
			end
		end

		if hg.Appearance.Bodygroups then
			local bodygroups = istable(appearance.ABodygroups) and appearance.ABodygroups or {}

			for _, bg in ipairs(ent:GetBodyGroups()) do
				local selected = bodygroups[bg.name]
				local bgdata = selected and hg.Appearance.Bodygroups[bg.name]
				local bgset = bgdata and bgdata[sexID] and bgdata[sexID][selected]

				if not bgset then continue end

				for i = 0, #bg.submodels do
					if bgset[1] == bg.submodels[i] then
						ent:SetBodygroup(bg.id, i)
						break
					end
				end
			end
		end

		return true
	end

	if IsValid(livePly) then
		ent:SetSkin(livePly:GetSkin())
		ent:SetSubMaterial()

		local mats = livePly:GetMaterials()

		for i = 1, #mats do
			local sm = livePly:GetSubMaterial(i - 1)

			if sm and sm ~= "" then ent:SetSubMaterial(i - 1, sm) end
		end

		for _, bg in ipairs(ent:GetBodyGroups()) do
			ent:SetBodygroup(bg.id, livePly:GetBodygroup(bg.id))
		end

		return true
	end

	return false
end

-- The accessory list (hats, glasses, masks...) that belongs to a saved appearance.
local function accessory_list(appearance, livePly)
	if istable(appearance) and istable(appearance.AAttachments) and #appearance.AAttachments > 0 then
		return appearance.AAttachments
	end

	if IsValid(livePly) and livePly.GetNetVar then
		local acc = livePly:GetNetVar("Accessories")

		if istable(acc) then return acc end
	end

	return {}
end

-- A DModelPanel showing somebody's saved appearance (clothes AND accessories), camera fitted to the panel shape.
-- slot picks one of the POSES presets so a lineup doesn't look copy-pasted.
local function CreatePortrait(parent, appearance, fallbackModel, livePly, slot)
	local pose = POSES[(((slot or 1) - 1) % #POSES) + 1]

	local model_data = appearance_model_data(appearance)
	local model = model_data and model_data.mdl or fallbackModel

	if (not model or model == "" or not util.IsValidModel(model)) and IsValid(livePly) then
		model = livePly:GetModel()
	end

	if not model or model == "" or not util.IsValidModel(model) then return end

	local look = (pose.target - pose.cam):Angle()
	local accessories = accessory_list(appearance, livePly)

	local mp = vgui.Create("DModelPanel", parent)
	mp:SetModel(model)
	mp:SetMouseInputEnabled(false)
	mp:SetAmbientLight(Color(90, 90, 100))
	mp:SetDirectionalLight(BOX_FRONT, Color(200, 200, 205))
	mp:SetDirectionalLight(BOX_TOP, Color(160, 160, 170))
	mp:SetDirectionalLight(BOX_RIGHT, Color(120, 120, 130))
	mp:SetDirectionalLight(BOX_LEFT, Color(110, 110, 125))
	mp:SetDirectionalLight(BOX_BACK, Color(80, 80, 100))

	-- Keeps the framing the preset was tuned for, whatever shape the panel is.
	function mp:Refit()
		local w, h = self:GetSize()
		if w <= 0 or h <= 0 then return end

		local half = math.tan(math.rad(pose.fov / 2)) * (REF_ASPECT / (h / w))

		self.FitFOV = math.Clamp(math.deg(2 * math.atan(half)), 12, 70)
	end

	function mp:LayoutEntity(ent)
		if not self.LookApplied then
			self.LookApplied = true
			apply_look(ent, appearance, livePly)
		end

		ent:SetAngles(pose.ang)

		if not self.Seq then
			local seq = -1

			for _, name in ipairs(pose.seqs) do
				local s = ent:LookupSequence(name)

				if s and s >= 0 then
					seq = s
					break
				end
			end

			if seq < 0 then seq = ent:LookupSequence("idle_all_01") or 0 end

			self.Seq = math.max(seq, 0)
			ent:ResetSequence(self.Seq)
		end

		ent:FrameAdvance(RealFrameTime())
		ent:SetPoseParameter("head_yaw", pose.hy)
		ent:SetPoseParameter("head_pitch", pose.hp)

		self:SetFOV(self.FitFOV or pose.fov)
		self:SetCamPos(pose.cam)
		self:SetLookAng(look)
	end

	function mp:PostDrawModel(ent)
		if hg and hg.Accessories and DrawAccesories then
			for _, name in ipairs(accessories) do
				local data = hg.Accessories[name]

				if data then DrawAccesories(ent, ent, name, data, false, true) end
			end
		end

		ent:SetupBones()
	end

	-- accessories are clientside models parented to the preview entity: clean them up with the panel
	local baseOnRemove = mp.OnRemove

	function mp:OnRemove()
		local ent = self.Entity

		if IsValid(ent) and ent.modelAccess then
			for key, acc in pairs(ent.modelAccess) do
				if IsValid(acc) then acc:Remove() end

				ent.modelAccess[key] = nil
			end
		end

		if baseOnRemove then baseOnRemove(self) end
	end

	mp:Refit()

	return mp
end
--//

--\\ Wrapping helper
local function WrapText(text, font, maxw)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(text, "%S+") do
		local test = (line == "") and word or (line .. " " .. word)

		if line ~= "" and surface.GetTextSize(test) > maxw then
			lines[#lines + 1] = line
			line = word
		else
			line = test
		end
	end

	if line ~= "" then lines[#lines + 1] = line end

	return lines
end
--//

--\\ Killer intro (MW3 style black screen briefing, F skips it)
local SKIP_FADE = 0.8

local function KillerParagraphs(targetCount)
	local word = MODE.NumberWords[targetCount] or tostring(targetCount)
	local minutes = math.floor(MODE.KillTime / 60)

	return {
		string.format("You are given %s Target%s.", word, targetCount == 1 and "" or "s"),
		string.format("You must kill them in under %d minutes.", minutes),
		"Cops are at the scene.",
		"If the time limit is done, the cops will be given a full sketch of you, knowing what you look like.",
	}
end

local function DrawBlurredText(text, font, x, y, alpha, align)
	-- Cheap blur: a soft halo of offset copies behind a dimmed main copy.
	local spread = math.max(2, math.floor(ScrH() * 0.0028))

	for ox = -1, 1 do
		for oy = -1, 1 do
			if ox ~= 0 or oy ~= 0 then
				draw.SimpleText(text, font, x + ox * spread, y + oy * spread, Color(255, 255, 255, alpha * 0.16), align or TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	draw.SimpleText(text, font, x, y, Color(255, 255, 255, alpha * 0.6), align or TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function CreateKillerIntro(duration, targets)
	KillPanel("intro")

	local sw, sh = ScrW(), ScrH()
	local pnl = MakeOverlay()
	Panels.intro = pnl

	pnl.Dur = duration
	pnl.WasDown = input.IsKeyDown(MODE.KillerSkipKey)
	pnl.Cards = {}

	-- Timeline (seconds, scaled to the intro length)
	local typeStart = 0.5
	local typeEnd = duration * 0.40
	local cardsStart = duration * 0.44
	local fadeLen = 1.1

	-- Typed text layout (left column)
	local paragraphs = KillerParagraphs(#targets)
	local textX = sw * 0.06
	local textW = sw * 0.37
	local lineH = draw.GetFontHeight and draw.GetFontHeight("Framed_Type") or math.floor(sh * 0.04)
	local paraGap = lineH * 0.55
	local pause = 0.22

	local blocks, totalChars, blockH = {}, 0, 0

	for i, text in ipairs(paragraphs) do
		local lines = WrapText(text, "Framed_Type", textW)

		blocks[i] = {text = text, lines = lines, len = #text}
		totalChars = totalChars + #text
		blockH = blockH + #lines * lineH + (i > 1 and paraGap or 0)
	end

	local window = math.max((typeEnd - typeStart) - pause * (#blocks - 1), 0.5)
	local cps = totalChars / window
	local cursor_t = typeStart

	for i, block in ipairs(blocks) do
		block.t0 = cursor_t
		cursor_t = cursor_t + block.len / cps + pause
	end

	local textTop = sh * 0.5 - blockH / 2
	local lastTick = 0

	-- Skip bookkeeping
	pnl.SkipAt = nil

	local function Skip()
		if pnl.SkipAt then return end

		pnl.SkipAt = CurTime()

		local now = CurTime()
		State.releaseAt = now
		State.timeUpAt = now + State.killTime
		MODE.HoldUntil = now

		MusicFadeNow(MODE.KillerMusicSkipFade)

		net.Start("framed_skip")
		net.SendToServer()
	end

	local function GlobalFade(t)
		local fade = clamp01((duration - t) / fadeLen)

		if pnl.SkipAt then
			fade = math.min(fade, 1 - clamp01((CurTime() - pnl.SkipAt) / SKIP_FADE))
		end

		return fade
	end

	function pnl:Think()
		local now = CurTime()
		local t = now - self.Start

		-- F to skip (edge triggered, ignored while typing in chat / game menu open)
		local down = input.IsKeyDown(MODE.KillerSkipKey)
		local ply = LocalPlayer()

		if down and not self.WasDown and not self.SkipAt and IsValid(ply) and not ply:IsTyping() and not gui.IsGameUIVisible() and t > 0.15 then
			Skip()
		end

		self.WasDown = down

		-- Lineup cards are built once, when their moment arrives
		if t >= cardsStart and not self.CardsBuilt then
			self.CardsBuilt = true

			local n = #targets

			if n > 0 then
				local rx, rw = sw * 0.47, sw * 0.49
				local gap = sw * 0.01
				local cw = math.min((rw - gap * (n - 1)) / n, sw * 0.16)
				local ch = sh * 0.5
				local total = n * cw + (n - 1) * gap
				local x0 = rx + (rw - total) / 2
				local y0 = sh * 0.27

				for i, target in ipairs(targets) do
					local card = vgui.Create("DPanel", self)
					card:SetSize(cw, ch)
					card:SetMouseInputEnabled(false)
					card:SetPaintBackground(false)
					card.HomeX, card.HomeY = x0 + (i - 1) * (cw + gap), y0
					card.Delay = (i - 1) * 0.14
					card.Born = now
					card:SetPos(card.HomeX, card.HomeY + sh * 0.02)
					card:SetAlpha(0)

					local _, nameColor = appearance_color(istable(target.appearance) and target.appearance.AColor)
					local labelH = sh * 0.032
					local nameH = sh * 0.045

					card.Paint = function(s, w, h)
						surface.SetDrawColor(255, 255, 255, 38)
						surface.DrawOutlinedRect(0, 0, w, h, 1)

						draw.SimpleText(string.format("TARGET %02d", i), "Framed_Tiny", w / 2, labelH / 2, Color(190, 190, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						draw.SimpleText(target.name or "Unknown", "Framed_Name", w / 2, h - nameH / 2, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

						if target.dead then
							surface.SetDrawColor(190, 0, 0, 200)
							surface.DrawLine(0, 0, w, h)
							surface.DrawLine(w, 0, 0, h)
						end
					end

					local mp = CreatePortrait(card, target.appearance, target.model, target.ply, i)

					card.Portrait = mp

					if mp then
						mp:SetPos(2, labelH)
						mp:SetSize(cw - 4, ch - labelH - nameH)
						mp:Refit()
					end

					self.Cards[#self.Cards + 1] = card
				end
			end
		end

		-- Animate the cards in and out
		for _, card in ipairs(self.Cards) do
			if IsValid(card) then
				local appear = ease_out(clamp01((now - card.Born - card.Delay) / 0.55))
				local alpha = 255 * appear * GlobalFade(t)

				card:SetAlpha(alpha)

				-- a DModelPanel only listens to its own alpha, so fade the portrait too
				if IsValid(card.Portrait) then card.Portrait:SetAlpha(alpha) end

				card:SetPos(card.HomeX, card.HomeY + (1 - appear) * sh * 0.02)
			end
		end

		if t >= duration or (self.SkipAt and now - self.SkipAt >= SKIP_FADE) then
			self:Remove()
		end
	end

	function pnl:Paint(w, h)
		local now = CurTime()
		local t = now - self.Start
		local fade = GlobalFade(t)

		-- Black background
		surface.SetDrawColor(0, 0, 0, 255 * clamp01(t / 0.35) * fade)
		surface.DrawRect(0, 0, w, h)

		if fade <= 0.01 then return end

		-- Typed text
		local textFade = fade
		local y = textTop
		local typedAll = true
		local lastX, lastY, lastLine

		for i, block in ipairs(blocks) do
			local shown = math.Clamp(math.floor((t - block.t0) * cps), 0, block.len)

			if shown < block.len then typedAll = false end

			local remaining = shown

			if i > 1 then y = y + paraGap end

			for _, line in ipairs(block.lines) do
				local take = math.min(#line, remaining)

				if take > 0 then
					local flicker = (math.random() < 0.015) and 0.55 or 1
					local part = string.sub(line, 1, take)

					-- soft glow + main text
					draw.SimpleText(part, "Framed_Type", textX + 1, y + 1, Color(255, 255, 255, 40 * textFade), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					draw.SimpleText(part, "Framed_Type", textX, y, Color(255, 255, 255, 235 * textFade * flicker), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

					if shown < block.len or i == #blocks then
						lastX, lastY, lastLine = textX + surface.GetTextSize(part), y, true
					end
				end

				remaining = math.max(remaining - #line - 1, 0)
				y = y + lineH
			end
		end

		-- Typewriter tick
		local typedNow = math.floor(math.max(t - typeStart, 0) * cps)

		if not typedAll and typedNow - lastTick >= 2 then
			lastTick = typedNow

			local ply = LocalPlayer()
			if IsValid(ply) then
				ply:EmitSound("ui/buttonrollover.wav", 50, math.random(125, 150), 0.18, CHAN_STATIC)
			end
		end

		-- Blinking block cursor
		if lastLine and (not typedAll or t < typeEnd + 1.2) and math.floor(now * 3) % 2 == 0 then
			surface.SetDrawColor(255, 255, 255, 220 * textFade)
			surface.DrawRect(lastX + 3, lastY + lineH * 0.12, math.max(3, sh * 0.009), lineH * 0.76)
		end

		-- Thin accent line next to the text block
		local lineGrow = ease_out(clamp01((t - 0.2) / 0.9))
		surface.SetDrawColor(255, 255, 255, 110 * fade)
		surface.DrawRect(textX - sw * 0.015, textTop + blockH * (1 - lineGrow) / 2, 2, blockH * lineGrow)

		-- Target count header
		if t >= cardsStart - 0.1 and #targets > 0 then
			local appear = ease_out(clamp01((t - (cardsStart - 0.1)) / 0.6))
			local cx = sw * 0.47 + sw * 0.49 / 2
			local a = 255 * appear * fade

			draw.SimpleText(tostring(#targets), "Framed_Number", cx - sw * 0.035, sh * 0.155, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(#targets == 1 and "TARGET" or "TARGETS", "Framed_Header", cx + sw * 0.005, sh * 0.155 + sh * 0.012, Color(210, 210, 210, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- Small blurred skip hint (bottom right)
		if t > 0.6 and not self.SkipAt then
			local pulse = 0.65 + 0.35 * math.sin(now * 3)
			local key = input.GetKeyName(MODE.KillerSkipKey) or "F"
			local hintAlpha = 255 * clamp01((t - 0.6) / 0.6) * fade * pulse

			DrawBlurredText("PRESS  [ " .. string.upper(key) .. " ]  TO SKIP", "Framed_Tiny", w - sw * 0.03, h - sh * 0.05, hintAlpha)
		end
	end

	-- Music: starts with the briefing, fades out when it finishes or the killer skips
	MusicStart(MODE.Sounds.killer, 1, MODE.KillerMusicFadeIn, CurTime() + math.min(MODE.KillerMusicFadeStart, duration), MODE.KillerMusicFadeOut)

	return pnl
end
--//

--\\ Remorse text slam (black screen, text sliding in from the sides with a tilt, parallax on the cursor)
local Cursor = {x = 0, y = 0}

local function DrawTilted(text, font, x, y, color, ang)
	local m = Matrix()
	m:Translate(Vector(x, y, 0))
	m:Rotate(Angle(0, ang, 0))
	m:Translate(Vector(-x, -y, 0))

	cam.PushModelMatrix(m)
		draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.PopModelMatrix()
end

local function NewTilts()
	local tilts = {}

	for i = 1, 8 do
		tilts[i] = (math.random() < 0.5) and 3 or -3
	end

	return tilts
end

-- elements: {text, font, color, x, y, dir = left|right|bottom|top, delay, plx, notilt}
-- appearTime: seconds each element takes to settle. master: overall alpha 0..1.
local function DrawSlam(w, h, elements, t, appearTime, master, tilts)
	Cursor.x = Lerp(FrameTime() * 6, Cursor.x, (gui.MouseX() - w * 0.5) / (w * 0.5))
	Cursor.y = Lerp(FrameTime() * 6, Cursor.y, (gui.MouseY() - h * 0.5) / (h * 0.5))

	local reach = ScreenScale(7)
	local cox = math.Clamp(Cursor.x, -1, 1) * reach
	local coy = math.Clamp(Cursor.y, -1, 1) * reach

	for i, el in ipairs(elements) do
		local appear = ease_out(clamp01((t - el.delay) / appearTime))
		local a = 255 * appear * master

		if a > 1 then
			local slide = 1 - appear
			local x, y = el.x, el.y

			if el.dir == "left" then
				x = x - slide * ScreenScale(220)
			elseif el.dir == "right" then
				x = x + slide * ScreenScale(220)
			elseif el.dir == "bottom" then
				y = y + slide * ScreenScale(120)
			elseif el.dir == "top" then
				y = y - slide * ScreenScale(120)
			end

			x = x + cox * (el.plx or 1)
			y = y + coy * (el.plx or 1)

			local tilt = el.notilt and 0 or (tilts[i] or 3) * appear

			DrawTilted(el.text, el.font, x, y, Color(el.color.r, el.color.g, el.color.b, a), tilt)
		end
	end
end

--\\ Crew intro (civilians and cops)
local function CreateCrewIntro(role, duration)
	KillPanel("intro")

	local pnl = MakeOverlay()
	Panels.intro = pnl

	local data = (role == ROLE_COP) and MODE.CrewRoles.cop or MODE.CrewRoles.civilian
	local tilts = NewTilts()

	function pnl:Think()
		if CurTime() - self.Start >= duration then
			self:Remove()
		end
	end

	function pnl:OnRemove()
		-- Cops: the music fades once the startup screen is done.
		if role == ROLE_COP then
			MusicFadeNow(MODE.CrewMusicFadeOut)
		end
	end

	function pnl:Paint(w, h)
		local t = CurTime() - self.Start
		local master = clamp01(t / 1.25) * clamp01((duration - t) / 4)

		surface.SetDrawColor(0, 0, 0, 255 * master)
		surface.DrawRect(0, 0, w, h)

		DrawSlam(w, h, {
			{text = MODE.Title, font = "ZB_HomicideHeader", color = Color(255, 255, 255), x = w * 0.5, y = h * 0.1, dir = "left", delay = 0, plx = 0.9},
			{text = MODE.Subtitle, font = "ZCity_Menu_Settings_Small", color = Color(210, 210, 210), x = w * 0.5, y = h * 0.17, dir = "left", delay = 0.35, plx = 0.95, notilt = true},
			{text = data.line, font = "ZB_HomicideMediumLarge", color = data.color, x = w * 0.5, y = h * 0.5, dir = "right", delay = 0.7, plx = 1.1},
			{text = data.sub, font = "ZB_HomicideMedium", color = Color(255, 255, 255), x = w * 0.5, y = h * 0.5 + ScreenScale(26), dir = "bottom", delay = 1.2, plx = 1.05, notilt = true},
		}, t, 2.0, master, tilts)
	end

	if role == ROLE_COP then
		-- fades when the startup screen is done (see OnRemove)
		MusicStart(MODE.Sounds.cop, 1, 0.4, nil, MODE.CrewMusicFadeOut)
	else
		-- plays for the whole intro, then fades out
		MusicStart(MODE.Sounds.civilian, 1, 0.4, CurTime() + duration, MODE.CrewMusicFadeOut)
	end

	return pnl
end
--//

--\\ Cop sketch of the killer
local function CreateSketch(name, model, appearance, killerEnt)
	KillPanel("sketch")

	local sw, sh = ScrW(), ScrH()
	local pnl = MakeOverlay()
	Panels.sketch = pnl

	local bigW, bigH = sw * 0.24, sh * 0.74
	local smallW, smallH = sw * 0.115, sh * 0.40
	local HOLD = 7
	local MOVE = 1.1

	pnl:SetSize(bigW, bigH)
	pnl:SetPos(sw / 2 - bigW / 2, sh / 2 - bigH / 2)
	pnl:SetAlpha(0)

	local paper = Color(223, 214, 188)
	local ink = Color(40, 34, 28)

	local mp = CreatePortrait(pnl, appearance, model, killerEnt, 1)

	function pnl:Think()
		local t = CurTime() - self.Start
		local appear = ease_out(clamp01(t / 0.7))
		local dock = ease_in_out(clamp01((t - HOLD) / MOVE))

		local w = Lerp(dock, bigW, smallW)
		local h = Lerp(dock, bigH, smallH)
		local x = Lerp(dock, sw / 2 - bigW / 2, sw * 0.015)
		local y = Lerp(dock, sh / 2 - bigH / 2, sh * 0.5 - smallH / 2)

		self:SetSize(w, h)
		self:SetPos(x, y + (1 - appear) * sh * 0.06)
		self:SetAlpha(255 * appear)

		if IsValid(mp) then
			local head = h * 0.13
			local foot = h * 0.11

			mp:SetPos(w * 0.05, head)
			mp:SetSize(w * 0.9, h - head - foot)
			mp:SetAlpha(255 * appear)
			mp:Refit()
		end
	end

	function pnl:Paint(w, h)
		local small = w < (bigW + smallW) / 2

		draw.RoundedBox(2, 0, 0, w, h, paper)
		surface.SetDrawColor(ink.r, ink.g, ink.b, 200)
		surface.DrawOutlinedRect(w * 0.025, h * 0.02, w * 0.95, h * 0.96, 2)

		-- faint paper lines
		surface.SetDrawColor(120, 100, 70, 22)
		for ly = h * 0.15, h * 0.88, h * 0.035 do
			surface.DrawLine(w * 0.05, ly, w * 0.95, ly)
		end

		draw.SimpleText("POLICE DISPATCH", small and "Framed_Tiny" or "Framed_Label", w / 2, h * 0.045, ink, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("SUSPECT SKETCH", small and "Framed_Tiny" or "Framed_Header", w / 2, h * 0.095, Color(150, 20, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(name or "Unknown", small and "Framed_Tiny" or "Framed_Name", w / 2, h * 0.945, ink, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- tape
		surface.SetDrawColor(200, 190, 150, 190)
		surface.DrawRect(w * 0.05, -h * 0.008, w * 0.2, h * 0.03)
		surface.DrawRect(w * 0.75, -h * 0.008, w * 0.2, h * 0.03)
	end

	-- Slight "drawn" wash over the portrait + a stamp
	function pnl:PaintOver(w, h)
		surface.SetDrawColor(paper.r, paper.g, paper.b, 55)
		surface.DrawRect(w * 0.05, h * 0.13, w * 0.9, h * 0.76)

		local m = Matrix()
		local cx, cy = w * 0.5, h * 0.72
		m:Translate(Vector(cx, cy, 0))
		m:Rotate(Angle(0, -14, 0))
		m:Translate(Vector(-cx, -cy, 0))

		cam.PushModelMatrix(m)
			draw.SimpleText("WANTED", "Framed_Stamp", cx, cy, Color(170, 20, 20, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.PopModelMatrix()
	end

	return pnl
end
--//

--\\ Round end, Remorse style: same black screen + sliding tilted text as the round start screens.
-- red = the killer got away, blue = the killer failed.
local COLOR_ESCAPED = Color(200, 25, 25)
local COLOR_FAILED = Color(60, 130, 255)

local function CreateEndFX(escaped, alias, nick, aliasColor)
	KillPanel("endfx")

	local pnl = MakeOverlay()
	Panels.endfx = pnl

	-- Stays inside 4s so it is gone before the round summary comes up.
	local D = 4.0
	local tilts = NewTilts()
	local mainText = escaped and MODE.EndTextEscaped or MODE.EndTextFailed
	local mainColor = escaped and COLOR_ESCAPED or COLOR_FAILED

	local reveal
	if alias == "Unknown" and nick == "disconnected" then
		reveal = "The killer left the game"
	else
		reveal = string.format("%s (%s) was the killer", alias, nick)
	end

	surface.PlaySound("ambient/alarms/warningbell1.wav")

	function pnl:Think()
		if CurTime() - self.Start >= D then
			self:Remove()
		end
	end

	function pnl:Paint(w, h)
		local t = CurTime() - self.Start
		local master = clamp01(t / 0.7) * clamp01((D - t) / 1.2)

		surface.SetDrawColor(0, 0, 0, 255 * master)
		surface.DrawRect(0, 0, w, h)

		DrawSlam(w, h, {
			{text = MODE.Title, font = "ZB_HomicideHeader", color = Color(255, 255, 255), x = w * 0.5, y = h * 0.1, dir = "left", delay = 0, plx = 0.9},
			{text = mainText, font = "ZB_HomicideMediumLarge", color = mainColor, x = w * 0.5, y = h * 0.5, dir = "right", delay = 0.3, plx = 1.1},
			{text = reveal, font = "ZB_HomicideMedium", color = aliasColor or Color(255, 255, 255), x = w * 0.5, y = h * 0.5 + ScreenScale(26), dir = "bottom", delay = 0.8, plx = 1.05, notilt = true},
		}, t, 1.3, master, tilts)
	end

	return pnl
end
--//

--\\ Network
net.Receive("framed_start", function()
    if not CurrentRound or CurrentRound() ~= MODE then return end
	KillPanel("intro")
	KillPanel("sketch")
	KillPanel("endfx")
	MusicStop()
	ResetState()

	local role = net.ReadUInt(2)
	local duration = net.ReadFloat()
	local targetCount = net.ReadUInt(4)

	State.role = role
	State.targetCount = targetCount

	if role == ROLE_KILLER then
		State.killTime = net.ReadFloat()
        local releaseAt, timeUpAt = net.ReadFloat(), net.ReadFloat()

		for i = 1, targetCount do
			State.targets[i] = {
				name = net.ReadString(),
				model = net.ReadString(),
				appearance = net.ReadTable(),
				ply = net.ReadEntity(),
				dead = net.ReadBool(),
			}
		end

		local now = CurTime()
		State.releaseAt = releaseAt
        State.timeUpAt = timeUpAt
		MODE.HoldUntil = State.releaseAt

		CreateKillerIntro(duration, State.targets)
	else
		MODE.HoldUntil = 0
		CreateCrewIntro(role, duration)
	end

	if zb and zb.RemoveFade then zb.RemoveFade() end
end)

net.Receive("framed_target", function()
    if not CurrentRound or CurrentRound() ~= MODE then return end
	local index = net.ReadUInt(4)
	local byKiller = net.ReadBool()

	local target = State.targets[index]
	if not target then return end

	target.dead = true

	if not byKiller then
		local lines = MODE.TargetDownLines
		local line = lines[math.random(#lines)]

		-- avoid the same line twice in a row
		if #lines > 1 and State.lastLine == line then
			line = lines[(table.KeyFromValue(lines, line) % #lines) + 1]
		end

		State.lastLine = line

		State.flavor[#State.flavor + 1] = {
			text = line,
			start = math.max(CurTime(), State.releaseAt + 0.4),
		}
	end
end)

net.Receive("framed_sketch", function()
    if not CurrentRound or CurrentRound() ~= MODE then return end
	local hasData = net.ReadBool()

	if hasData then
		local name = net.ReadString()
		local model = net.ReadString()
		local appearance = net.ReadTable()
		local killerIndex = net.ReadUInt(16)
        local killerEnt = Entity(killerIndex)
        State.killerIndex = killerIndex

		State.killerEnt = killerEnt
		State.sketchActive = true

		surface.PlaySound("buttons/button10.wav")
		chat.AddText(Color(50, 120, 255), "[Dispatch] ", Color(255, 255, 255), "A full sketch of the killer just came in. They are now highlighted in red.")

		CreateSketch(name, model, appearance, killerEnt)
	else
		surface.PlaySound("buttons/button10.wav")

		State.notice = {
			text = "TIME IS UP. The cops have your sketch and can see you in red.",
			start = CurTime(),
		}
	end
end)

net.Receive("framed_roundend", function()
    if not CurrentRound or CurrentRound() ~= MODE then return end
	local escaped = net.ReadBool()
	local alias = net.ReadString()
	local nick = net.ReadString()
	local aliasColor = net.ReadColor()

	KillPanel("intro")
	KillPanel("sketch")
	MusicStop()
	MODE.HoldUntil = 0
	State.role = nil
	State.sketchActive = false

	CreateEndFX(escaped, alias, nick, aliasColor)
end)
--//

--\\ Killer HUD
local function FormatTime(seconds)
	seconds = math.max(math.ceil(seconds), 0)

	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function MODE:HUDPaint()
	if State.role ~= ROLE_KILLER then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if zb and zb.ROUND_STATE == 3 then return end

	local now = CurTime()
	if now < State.releaseAt then return end

	local sw, sh = ScrW(), ScrH()

	-- Targets + clock (top left)
	local x, y = sw * 0.02, sh * 0.09
	local rowH = sh * 0.032

	draw.SimpleTextOutlined("TARGETS", "Framed_Tiny", x, y, Color(190, 190, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
	y = y + rowH

	for i, target in ipairs(State.targets) do
		local _, col = appearance_color(istable(target.appearance) and target.appearance.AColor)
		local alpha = target.dead and 90 or 255

		draw.SimpleTextOutlined(target.name or "Unknown", "Framed_Small", x, y, Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))

		if target.dead then
			surface.SetFont("Framed_Small")
			local tw = surface.GetTextSize(target.name or "Unknown")

			surface.SetDrawColor(190, 30, 30, 220)
			surface.DrawRect(x, y, tw, 2)
		end

		y = y + rowH
	end

	y = y + rowH * 0.3

	local remaining = State.timeUpAt - now

	if remaining > 0 then
		local urgent = remaining <= 60
		local pulse = urgent and (0.7 + 0.3 * math.sin(now * 6)) or 1
		local col = urgent and Color(255, 70, 70, 255 * pulse) or Color(235, 235, 235)

		draw.SimpleTextOutlined(FormatTime(remaining), "Framed_Header", x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
	else
		local pulse = 0.6 + 0.4 * math.sin(now * 4)

		draw.SimpleTextOutlined("SKETCH ISSUED", "Framed_Small", x, y, Color(255, 70, 70, 255 * pulse), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
	end

	-- "Someone did the job for me" lines (top right, white, small)
	local fy = sh * 0.06

	for i = #State.flavor, 1, -1 do
		local msg = State.flavor[i]
		local age = now - msg.start

		if age > 5.2 then
			table.remove(State.flavor, i)
		elseif age >= 0 then
			local a = 255 * clamp01(age / 0.3) * clamp01((5.2 - age) / 0.8)

			draw.SimpleTextOutlined(msg.text, "Framed_Small", sw * 0.975, fy, Color(255, 255, 255, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.8))
			fy = fy + sh * 0.034
		end
	end

	-- Time's up notice (top centre)
	if State.notice then
		local age = now - State.notice.start

		if age > 6 then
			State.notice = nil
		else
			local a = 255 * clamp01(age / 0.4) * clamp01((6 - age) / 1)

			draw.SimpleTextOutlined(State.notice.text, "Framed_Notice", sw / 2, sh * 0.12, Color(235, 40, 40, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a))
		end
	end
end
--//

--\\ Red highlight of the killer for the cops once the sketch is out
function MODE:PreDrawHalos()
	if State.role ~= ROLE_COP or not State.sketchActive then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	local killer = IsValid(State.killerEnt) and State.killerEnt or Entity(State.killerIndex or -1)
	if not IsValid(killer) or not killer:Alive() then return end

	-- when the killer is ragdolled the visible body is the ragdoll
	local body = (hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(killer)) or killer
	if not IsValid(body) then return end

	-- gentle pulse, never dim: the highlight has to stay easy to spot
	local pulse = 0.85 + 0.15 * math.sin(CurTime() * 5)

	halo.Add({body}, Color(255 * pulse, 25 * pulse, 25 * pulse), 4, 4, 3, true, true)
end
--//

net.Receive("framed_release", function()
    local released, deadline = net.ReadFloat(), net.ReadFloat()
    if not CurrentRound or CurrentRound() ~= MODE or State.role ~= ROLE_KILLER then return end
    State.releaseAt, State.timeUpAt = released, deadline
    MODE.HoldUntil = released
end)

hook.Add("Think", "Framed_ModeCleanup", function()
    if CurrentRound and CurrentRound() == MODE then return end
    if State.role ~= nil or next(Panels) ~= nil then
        for key in pairs(Panels) do KillPanel(key) end
        MusicStop()
        ResetState()
        MODE.HoldUntil = 0
    end
end)
