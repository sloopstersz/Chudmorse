MODE.name = "turfwars"

local MODE = MODE

local playstart

-- Round state comes straight from zb.ROUND_STATE, which the server keeps in sync with every
-- RoundInfo message. (A separate "ended" flag set by a delayed net message could land in the
-- NEXT round and switch the lights and sound off, so it is not used anymore.)
local function RoundActive()
	return zb.ROUND_STATE == 1
end

local function RoundEnded()
	return zb.ROUND_STATE == 3
end

local MusicVolume = GetConVar("snd_musicvolume")

-- Which variant this round is: 1 = Planned, 2 = Unexpected (see TURFWARS_VARIANTS in sh_turfwars.lua)
local shownVariant = nil

-- Vote state
local voteEndTime = 0
local selectedVote = 0
local voteResults = {[1] = 0, [2] = 0}
local TurfVoteFadeStart = 0
local TurfVoteFadeEnd = 0
local tex_gradient_r = Material("vgui/gradient-r")
local tex_gradient_l = Material("vgui/gradient-l")
local tex_gradient_d = Material("vgui/gradient-d")

-- Planned class selection state
local classEndTime = 0
local selectedClass = 0
local selectTeam = 0
local selectModel = ""

-- Riot-style startup intro state
local turfIntroTeam = nil
local turfIntroRoleName = nil
local turfIntroSubtitle = ""
local turfIntroDescription = ""
local TurfIntroStartTime = 0
local TurfIntroDuration = 10

-- Planned only: SWAT warning lights (red/blue) state
local cvLights = CreateClientConVar("turfwars_lights", "1", true, false, "Show the Turf Wars SWAT warning lights (1 = on, 0 = off)", 0, 1)
local matGlow = Material("sprites/light_glow02_add")
local lightPhase = 0
local beamAngle = 0

-- Planned only: SWAT countdown sting. Plays once when the timer hits the last WARN_TRIGGER seconds,
-- stays at full volume for WARN_HOLD seconds, then fades down to WARN_FLOOR over
-- WARN_FADE_TIME seconds, and finally to silence by WARN_END seconds after it started.
local WARN_SOUND = "sound/turfwars/crisis_response.mp3"
local WARN_TRIGGER = 10
local WARN_HOLD = 10
local WARN_FLOOR = 0.2
local WARN_FADE_TIME = 8
local WARN_END = 36

-- Round music (the ghetto loop, the same for both variants): this much louder than before.
-- It is added to the loop's level, so it still follows fear and still fades to silence at round end.
local ROUND_MUSIC_BOOST = 0.3

-- SWAT music (Planned only, the police track that takes over when SWAT arrives): it comes in louder
-- (POLICE_BOOST times the old level), holds for POLICE_HOLD seconds, then fades out over POLICE_FADE
-- seconds and stops.
local POLICE_BOOST = 1.3
local POLICE_HOLD = 8
local POLICE_FADE = 22

local warnStation
local warnStart = 0
local warnPlayedFor -- zb.ROUND_START of the round the sting already played in
local endedAt
local cvDebug = CreateClientConVar("turfwars_debug", "0", false, false, "Print Turf Wars sting/lights/music debug info to the console (1/0)", 0, 1)

local function DebugPrint(...)
	if cvDebug:GetBool() then
		print("[TurfWars]", ...)
	end
end

-- Vote song ("Gang War"): plays ONLY on the vote screen. As soon as the vote is done it fades out
-- fast (about a second) and it is hard-stopped before the startup music begins, so it never
-- overlaps the startup songs. Level is 0 to 1 of the file's own loudness. By default it ignores the
-- game's music volume slider (snd_musicvolume), like riot's music does; set MUSIC_USE_GAME_VOLUME = true to follow it.
local MUSIC_SOUND = "sound/turfwars/gang_war.mp3"
local MUSIC_VOTE_VOLUME = 0.7
local MUSIC_FADE_RATE = 5        -- bigger = faster fade out once the vote is done
local MUSIC_MAX_AFTER_VOTE = 2   -- hard stop this many seconds after the vote result, whatever the fade did
local MUSIC_USE_GAME_VOLUME = false
local musicStation
local musicVolume = 0
local musicTarget = 0
local musicToken = 0
local voteResultTime = 0

local function StopVoteMusic()
	musicToken = musicToken + 1 -- invalidates a file that is still loading

	if IsValid(musicStation) then
		musicStation:Stop()
	end

	musicStation = nil
	musicVolume = 0
	musicTarget = 0
end

local function StartVoteMusic()
	StopVoteMusic()

	local token = musicToken
	musicTarget = MUSIC_VOTE_VOLUME

	sound.PlayFile(MUSIC_SOUND, "noblock noplay", function(station, errorID, errorName)
		if not IsValid(station) then
			DebugPrint("music failed to load:", errorID, errorName)
			return
		end

		-- a newer vote started, the music was stopped, or the vote is already over while the file was loading
		if token ~= musicToken or voteResultTime > 0 then
			station:Stop()
			return
		end

		station:EnableLooping(true)
		station:SetVolume(0)
		station:Play()
		musicStation = station
	end)
end

-- Fades the vote song in, holds it during the vote, and fades it out fast once the vote is done
local function UpdateVoteMusic()
	if not IsValid(musicStation) then return end

	local fadeRate = 1.2

	if voteResultTime > 0 then
		musicTarget = 0
		fadeRate = MUSIC_FADE_RATE

		-- belt and braces: it can never outlive the vote by more than a moment
		if CurTime() - voteResultTime >= MUSIC_MAX_AFTER_VOTE then
			StopVoteMusic()
			return
		end
	end

	musicVolume = Lerp(math.Clamp(FrameTime() * fadeRate, 0, 1), musicVolume, musicTarget)

	if musicTarget <= 0 and musicVolume < 0.01 then
		StopVoteMusic()
		return
	end

	musicStation:SetVolume(musicVolume * (MUSIC_USE_GAME_VOLUME and MusicVolume:GetFloat() or 1))
end

-- Planned only: stops the ghetto loops and the countdown sting
local function StopTurfMusic()
	if IsValid(warnStation) then
		warnStation:Stop()
	end
	warnStation = nil

	if IsValid(TURFWARS_LoopStation) then
		TURFWARS_LoopStation:Stop()
	end
	TURFWARS_LoopStation = nil

	if IsValid(TURFWARS_LoopStation2) then
		TURFWARS_LoopStation2:Stop()
	end
	TURFWARS_LoopStation2 = nil
end

local function GetVariant(index)
	local variants = TURFWARS_VARIANTS or {}
	return variants[index] or variants[1] or {name = "Planned", description = "", color = Color(255, 255, 255)}
end

local function GetVoteTotal()
	return (voteResults[1] or 0) + (voteResults[2] or 0)
end

local function CloseVoteMenu()
	if IsValid(TurfWarsVoteMenu) then
		TurfWarsVoteMenu:Remove()
	end
	TurfWarsVoteMenu = nil
end

-- Same screen as riot's intensity vote, with Turf Wars' two choices
local function OpenVoteMenu()
	CloseVoteMenu()

	TurfWarsVoteMenu = vgui.Create("DFrame")
	TurfWarsVoteMenu:SetSize(ScrW(), ScrH())
	TurfWarsVoteMenu:SetPos(0, 0)
	TurfWarsVoteMenu:SetTitle("")
	TurfWarsVoteMenu:ShowCloseButton(false)
	TurfWarsVoteMenu:SetDraggable(false)
	TurfWarsVoteMenu:MakePopup()
	TurfWarsVoteMenu.OpenTime = CurTime()
	TurfWarsVoteMenu.Paint = function(self, w, h)
		local elapsed = CurTime() - (self.OpenTime or CurTime())
		local titleFrac = math.Clamp(elapsed / 0.4, 0, 1)
		local pulse = 0.5 + math.sin(CurTime() * 4) * 0.5
		local titleY = h * 0.12 - (1 - titleFrac) * 24
		local timerLeft = math.max(math.ceil(voteEndTime - CurTime()), 0)
		local timerColor = timerLeft <= 5 and Color(255, 120 + pulse * 80, 120 + pulse * 80) or Color(225, 225, 225)

		hg.DrawBlur(self, 5)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 19, 235))
		surface.SetDrawColor(18, 18, 18, 65)
		surface.SetMaterial(tex_gradient_r)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetMaterial(tex_gradient_l)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetDrawColor(100, 100, 100, 35)
		surface.SetMaterial(tex_gradient_d)
		surface.DrawTexturedRect(0, 0, w, h)
		draw.SimpleText("TURF WARS", "ZCity_Menu_Small", w * 0.5, titleY, Color(225, 225, 225, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Vote before the round starts", "ZCity_Menu_Settings_Small", w * 0.5, h * 0.16 - (1 - titleFrac) * 18, Color(200, 200, 200, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("TIME LEFT: " .. timerLeft, "ZCity_Menu_Small", w * 0.5, h * 0.86, timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	TurfWarsVoteMenu.Think = function()
		if CurTime() >= voteEndTime and IsValid(TurfWarsVoteMenu) then
			CloseVoteMenu()
		end
	end

	for i = 1, 2 do
		local data = GetVariant(i)
		local button = vgui.Create("DButton", TurfWarsVoteMenu)
		button:SetSize(ScrW() * 0.7, ScrH() * 0.16)
		button.TargetX = ScrW() * 0.15
		button.TargetY = ScrH() * (0.31 + (i - 1) * 0.2)
		button:SetPos((i % 2 == 0) and ScrW() + 120 or -button:GetWide() - 120, button.TargetY)
		button:SetText("")
		button.OpenTime = CurTime() + (i - 1) * 0.08
		button.HoverFrac = 0
		button.SelectFrac = 0
		button.Think = function(self)
			local x, y = self:GetPos()
			local intro = math.Clamp((CurTime() - self.OpenTime) / 0.35, 0, 1)
			self.HoverFrac = Lerp(FrameTime() * 10, self.HoverFrac, self:IsHovered() and 1 or 0)
			self.SelectFrac = Lerp(FrameTime() * 10, self.SelectFrac, selectedVote == i and 1 or 0)
			self:SetPos(Lerp(FrameTime() * 10, x, self.TargetX + self.HoverFrac * 10), self.TargetY - (1 - intro) * 4 - self.HoverFrac * 6)
		end
		button.Paint = function(self, w, h)
			local total = GetVoteTotal()
			local votes = voteResults[i] or 0
			local percent = total > 0 and math.floor(votes / total * 100) or 0
			local glow = math.max(self.HoverFrac, self.SelectFrac)
			local alpha = 190 + glow * 35
			local borderColor = Color(225, 225, 225, 120 + glow * 80)
			local fillColor = Color(0, 0, 0, alpha)

			draw.RoundedBox(0, 0, 0, w, h, fillColor)
			surface.SetDrawColor(borderColor)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(data.name, "ZCity_Menu_Small", 24 + self.HoverFrac * 6, h * 0.32, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(data.description, "ZCity_Menu_Settings_Small", 24 + self.HoverFrac * 6, h * 0.7, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(percent .. "%", "ZCity_Menu_Small", w - 24 - self.HoverFrac * 6, h * 0.32, Color(225, 225, 225), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(votes .. " votes", "ZCity_Menu_Settings_Small", w - 24 - self.HoverFrac * 6, h * 0.7, Color(210, 210, 210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			local oldVote = selectedVote
			selectedVote = i
			surface.PlaySound("ui/rem_select.wav")
			net.Start("turfwars_change_vote")
			net.WriteInt(oldVote, 4)
			net.WriteInt(i, 4)
			net.SendToServer()
		end
	end
end

local function CloseClassMenu()
	if IsValid(TurfWarsClassMenu) then
		TurfWarsClassMenu:Remove()
	end
	TurfWarsClassMenu = nil
end

local function PickClass(index)
	selectedClass = index
	surface.PlaySound("ui/rem_select.wav")

	net.Start("turfwars_select_class")
	net.WriteInt(index, 8)
	net.SendToServer()
end

-- Picks the first font from the list whose text fits in maxW (so long lines never run off a row)
local function FitFont(text, maxW, fonts)
	for _, font in ipairs(fonts) do
		surface.SetFont(font)
		if surface.GetTextSize(text) <= maxW then
			return font
		end
	end

	return fonts[#fonts]
end

-- Planned: pick your weapon class. Same look as the vote screen. The character (gang and playermodel)
-- is random and only shown here; you choose the class. Keys 1-6 also pick.
-- Layout: a card on the left (your model + gang) and six evenly spaced rows on the right. Both span the
-- same height, and every size is relative to the screen so it fits any resolution.
local function OpenClassMenu()
	CloseClassMenu()

	local teamColor = (selectTeam == 0) and Color(190, 0, 0) or Color(0, 190, 0)
	local teamText = (selectTeam == 0) and "You are a Bloodz Member" or "You are a Groove Member"
	local count = #TURFWARS_CLASSES

	-- geometry
	local top = ScrH() * 0.17
	local gap = ScrH() * 0.012
	local rowH = ScrH() * 0.1
	local totalH = count * rowH + (count - 1) * gap
	local cardX, cardY = ScrW() * 0.03, top
	local cardW, cardH = ScrW() * 0.26, totalH
	local rowX = ScrW() * 0.32
	local rowW = ScrW() * 0.65

	-- fonts sized from the row height, so text never collides with the next line
	local function makeFont(name, factor, weight)
		surface.CreateFont(name, {
			font = "Courier Prime",
			size = math.max(math.floor(rowH * factor), 10),
			weight = weight or 500,
			extended = true,
			antialias = true,
		})
	end

	makeFont("TurfWars_ClassName", 0.28, 600)
	makeFont("TurfWars_ClassText", 0.15)
	makeFont("TurfWars_ClassTextSmall", 0.12)
	makeFont("TurfWars_ClassLabel", 0.26, 600)
	makeFont("TurfWars_ClassLabelSmall", 0.2, 600)

	TurfWarsClassMenu = vgui.Create("DFrame")
	TurfWarsClassMenu:SetSize(ScrW(), ScrH())
	TurfWarsClassMenu:SetPos(0, 0)
	TurfWarsClassMenu:SetTitle("")
	TurfWarsClassMenu:ShowCloseButton(false)
	TurfWarsClassMenu:SetDraggable(false)
	TurfWarsClassMenu:MakePopup()
	TurfWarsClassMenu.OpenTime = CurTime()
	TurfWarsClassMenu.Paint = function(self, w, h)
		local elapsed = CurTime() - (self.OpenTime or CurTime())
		local titleFrac = math.Clamp(elapsed / 0.4, 0, 1)
		local pulse = 0.5 + math.sin(CurTime() * 4) * 0.5
		local timerLeft = math.max(math.ceil(classEndTime - CurTime()), 0)
		local timerColor = timerLeft <= 3 and Color(255, 120 + pulse * 80, 120 + pulse * 80) or Color(225, 225, 225)

		hg.DrawBlur(self, 5)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 19, 235))
		surface.SetDrawColor(18, 18, 18, 65)
		surface.SetMaterial(tex_gradient_r)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetMaterial(tex_gradient_l)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetDrawColor(100, 100, 100, 35)
		surface.SetMaterial(tex_gradient_d)
		surface.DrawTexturedRect(0, 0, w, h)

		draw.SimpleText("CHOOSE YOUR CLASS", "ZCity_Menu_Small", w * 0.5, h * 0.075 - (1 - titleFrac) * 24, Color(225, 225, 225, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Pick your weapon. No pick means a random class.", "ZCity_Menu_Settings_Small", w * 0.5, h * 0.118 - (1 - titleFrac) * 18, Color(200, 200, 200, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- left card: same box style as the rows, spanning the same height
		draw.RoundedBox(0, cardX, cardY, cardW, cardH, Color(0, 0, 0, 190))
		surface.SetDrawColor(225, 225, 225, 110)
		surface.DrawOutlinedRect(cardX, cardY, cardW, cardH, 1)
		surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, 255)
		surface.DrawRect(cardX, cardY, cardW, math.max(3, h * 0.003))
		local labelFont = FitFont(teamText, cardW - 32, {"TurfWars_ClassLabel", "TurfWars_ClassLabelSmall", "TurfWars_ClassText"})
		draw.SimpleText(teamText, labelFont, cardX + cardW * 0.5, cardY + cardH * 0.93, teamColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText("TIME LEFT: " .. timerLeft, "ZCity_Menu_Small", w * 0.5, h * 0.92, timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	TurfWarsClassMenu.Think = function()
		if CurTime() >= classEndTime and IsValid(TurfWarsClassMenu) then
			CloseClassMenu()
		end
	end
	TurfWarsClassMenu.OnKeyCodePressed = function(self, key)
		local index = key - KEY_1 + 1
		if index >= 1 and index <= count then
			PickClass(index)
		end
	end

	-- the model you will spawn with (chosen by the server, you do not pick it), inside the card
	if selectModel ~= "" then
		local modelW = cardW - 16
		local modelH = cardH * 0.84 - 8

		local modelPanel = vgui.Create("DModelPanel", TurfWarsClassMenu)
		modelPanel:SetPos(cardX + 8, cardY + 8)
		modelPanel:SetSize(modelW, modelH)
		modelPanel:SetModel(selectModel)

		local ent = modelPanel:GetEntity()
		if IsValid(ent) then
			local sequence = ent:LookupSequence("idle_all_01")
			if sequence and sequence > 0 then
				ent:SetSequence(sequence)
			end

			-- Put the camera straight in front of the model, far enough that the whole body fills
			-- about 85% of the panel's height. (The panel's FOV is horizontal, so a tall narrow panel
			-- shows more vertically: visible height = 2 * dist * tan(fov / 2) * (panel height / panel width).)
			local mins, maxs = ent:GetRenderBounds()
			local height = math.max(maxs.z - mins.z, 1)
			local fov = 30
			local dist = (height * 1.18) / (2 * math.tan(math.rad(fov * 0.5)) * (modelH / modelW))
			local center = (mins + maxs) * 0.5

			modelPanel:SetFOV(fov)
			modelPanel:SetCamPos(center + Vector(dist, 0, 0))
			modelPanel:SetLookAt(center)
		end

		modelPanel.LayoutEntity = function(self, entity)
			self:RunAnimation()
			entity:SetAngles(Angle(0, 25 + math.sin(CurTime() * 0.7) * 12, 0))
		end
	end

	for i, class in ipairs(TURFWARS_CLASSES) do
		local button = vgui.Create("DButton", TurfWarsClassMenu)
		button:SetSize(rowW, rowH)
		button:SetPos(rowX, top + (i - 1) * (rowH + gap))
		button:SetText("")
		button.HoverFrac = 0
		button.SelectFrac = 0
		button.Think = function(self)
			self.HoverFrac = Lerp(FrameTime() * 10, self.HoverFrac, self:IsHovered() and 1 or 0)
			self.SelectFrac = Lerp(FrameTime() * 10, self.SelectFrac, selectedClass == i and 1 or 0)
		end
		button.Paint = function(self, w, h)
			local picked = selectedClass == i
			local glow = math.max(self.HoverFrac, self.SelectFrac)
			local pad = h * 0.22
			local nameX = pad + h * 0.45
			local textMax = w - pad * 2

			draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 190 + glow * 35))

			if picked then
				surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
				surface.DrawRect(0, 0, math.max(4, h * 0.05), h)
			else
				surface.SetDrawColor(225, 225, 225, 110 + glow * 120)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end

			draw.SimpleText(tostring(i), "TurfWars_ClassName", pad, h * 0.29, picked and teamColor or Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(class.name, "TurfWars_ClassName", nameX, h * 0.29, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if picked then
				draw.SimpleText("SELECTED", "TurfWars_ClassText", w - pad, h * 0.29, teamColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			local fonts = {"TurfWars_ClassText", "TurfWars_ClassTextSmall"}
			local itemsLine = "You get: " .. class.items .. ", " .. TURFWARS_CLASS_KIT

			draw.SimpleText(class.description, FitFont(class.description, textMax, fonts), nameX, h * 0.6, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(itemsLine, FitFont(itemsLine, textMax - (nameX - pad), fonts), nameX, h * 0.83, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			PickClass(i)
		end
	end
end

net.Receive("turfwars_start_select", function()
	classEndTime = net.ReadFloat()
	selectTeam = net.ReadInt(4)
	selectModel = net.ReadString()
	selectedClass = 0

	CloseVoteMenu()
	OpenClassMenu()
end)

net.Receive("turfwars_start_vote", function()
	voteEndTime = net.ReadFloat()
	selectedVote = 0
	voteResults = {[1] = 0, [2] = 0}
	shownVariant = nil
	turfIntroTeam = nil
	turfIntroRoleName = nil
	turfIntroSubtitle = ""
	turfIntroDescription = ""
	TurfIntroStartTime = 0
	TurfVoteFadeStart = 0
	TurfVoteFadeEnd = 0
	voteResultTime = 0
	playstart = nil
	selectedClass = 0
	CloseClassMenu()

	-- clean up the previous round's Planned sounds, then start the vote music
	StopTurfMusic()
	StartVoteMusic()
	OpenVoteMenu()
end)

net.Receive("turfwars_vote_update", function()
	voteResults = net.ReadTable() or {[1] = 0, [2] = 0}
end)

net.Receive("turfwars_vote_result", function()
	shownVariant = net.ReadInt(4)
	voteResults = net.ReadTable() or {[1] = 0, [2] = 0}

	CloseVoteMenu()

	-- voting is done: UpdateVoteMusic fades the vote song out right away
	voteResultTime = CurTime()

	TurfVoteFadeStart = CurTime()
	TurfVoteFadeEnd = CurTime() + 3
end)

net.Receive("turfwars_show_selected_mode", function()
	shownVariant = net.ReadInt(4)
	surface.PlaySound("buttons/combine_button1.wav")
end)

net.Receive("turfwars_start", function()
	shownVariant = net.ReadInt(4)
	turfIntroTeam = net.ReadInt(4)
	turfIntroRoleName = net.ReadString()
	turfIntroSubtitle = net.ReadString()
	turfIntroDescription = net.ReadString()

	CloseVoteMenu()
	CloseClassMenu()
	zb.RemoveFade()

	endedAt = nil
	lightPhase = 0
	beamAngle = 0

	-- same random tilt / cursor parallax setup as the riot intro
	TurfIntroStartTime = CurTime()
	MODE.RoundTextTilts = {}
	for i = 1, 64 do
		MODE.RoundTextTilts[i] = (math.random() < 0.5) and 3 or -3
	end
	MODE.CursorLerpX = 0
	MODE.CursorLerpY = 0

	StopTurfMusic()

	-- the vote song is finished; make sure it can never play under the startup music
	StopVoteMusic()

	-- Startup music, the SAME for both variants: the Gang Wars stinger now, the ghetto start sound
	-- 8 seconds in, then the ghetto loop from 12 seconds (see StartupMusicHUD).
	surface.PlaySound("zbattle/nigshit.mp3")
	playstart = true

	sound.PlayFile("sound/music_themes/ghetto_loop.wav", "noblock noplay", function(station)
		if IsValid(station) then
			TURFWARS_LoopStation = station
			station:SetVolume(1 * MusicVolume:GetFloat())
			station:EnableLooping(true)
		end
	end)

	-- the police track is the SWAT music, so only Planned (which has SWAT) loads it
	if shownVariant == 1 then
		sound.PlayFile("sound/music_themes/ghetto_police.wav", "noblock noplay", function(station)
			if IsValid(station) then
				TURFWARS_LoopStation2 = station
				station:SetVolume(1 * MusicVolume:GetFloat())
				station:EnableLooping(true)
			end
		end)
	end
end)

local teams = {
	[0] = {
		objective = "Kill all groove mazafakas",
		name = "a Bloodz Member",
		color1 = Color(180, 0, 0),
	},
	[1] = {
		objective = "Kill all bloodz mazafakas",
		name = "a Groove Member",
		color1 = Color(0, 180, 0),
	},
}

local function turf_ease_out(x)
	return 1 - (1 - x) ^ 3
end

local function turf_draw_text(text, fontname, x, y, r, g, b, a, ang, xalign, yalign)
	local base = Matrix()
	base:Translate(Vector(x, y, 0))
	base:Rotate(Angle(0, ang, 0))
	base:Translate(Vector(-x, -y, 0))

	cam.PushModelMatrix(base)
		draw.SimpleText(text, fontname, x, y, Color(r, g, b, a), xalign, yalign)
	cam.PopModelMatrix()
end

local lerpsnd = 0.3
local loopsnd = 0.3 + ROUND_MUSIC_BOOST

function MODE:RenderScreenspaceEffects()
	local ct = CurTime()

	-- black fade while the vote result is shown
	if TurfVoteFadeEnd > ct then
		local frac = math.Clamp((ct - TurfVoteFadeStart) / math.max(TurfVoteFadeEnd - TurfVoteFadeStart, 0.001), 0, 1)
		surface.SetDrawColor(0, 0, 0, 255 * frac)
		surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
		return
	end

	if TurfIntroStartTime <= 0 then return end

	local introTime = ct - TurfIntroStartTime
	if introTime > TurfIntroDuration then return end

	zb.RemoveFade()

	local introFade = math.Clamp(introTime / 1.25, 0, 1)
	local outFade = math.Clamp((TurfIntroDuration - introTime) / 4, 0, 1)
	surface.SetDrawColor(0, 0, 0, 255 * introFade * outFade)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

surface.CreateFont("timer_FontTurf", {
	font = "Courier Prime",
	size = ScreenScale(9),
	extended = true,
	weight = 650,
	antialias = true,
	italic = false
})

local COL_RED = Color(255, 35, 35)
local COL_BLUE = Color(45, 115, 255)

local function Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- One light. Only soft additive glow is used (no solid shapes, no backing panel).
--   p     0 -> 1 over the SWAT countdown (0 = wide, faint blur, 1 = SWAT is here)
--   sharp 0 -> 1 how much of the tight, bright light core has faded in
local function DrawBeacon(x, y, col, inten, p, sharp, beamDeg, master)
	local coreR = ScreenScale(4.5)

	surface.SetMaterial(matGlow)

	-- gentle light spill on the top edge of the screen
	surface.SetDrawColor(col.r, col.g, col.b, 255 * Lerp(p, 0.04, 0.26) * inten * master)
	surface.DrawTexturedRectRotated(x, 0, sw * 0.28, sh * 0.15, 0)

	-- blurry orb: wide and faint at the start, tighter and brighter as time runs out
	local glowSize = coreR * 2 * Lerp(p, 6, 3.4)
	surface.SetDrawColor(col.r, col.g, col.b, 255 * Lerp(p, 0.10, 0.75) * inten * master)
	surface.DrawTexturedRectRotated(x, y, glowSize, glowSize, 0)

	-- slow rotating streaks (thinner = sharper as p grows)
	local beamA = 255 * Smooth((p - 0.15) / 0.7) * inten * master * 0.55
	if beamA > 1 then
		local len = ScreenScale(Lerp(p, 45, 85))
		local thick = ScreenScale(Lerp(p, 16, 8))

		surface.SetDrawColor(col.r, col.g, col.b, beamA)
		surface.DrawTexturedRectRotated(x, y, len * 2, thick, -beamDeg)

		surface.SetDrawColor(col.r, col.g, col.b, beamA * 0.5)
		surface.DrawTexturedRectRotated(x, y, len * 1.3, thick * 0.8, -(beamDeg + 90))
	end

	-- the light "shows": a tight bright glow with a small white-hot centre, still soft edged
	if sharp > 0.01 then
		local a = 255 * sharp * inten * master

		surface.SetDrawColor(col.r, col.g, col.b, a)
		surface.DrawTexturedRectRotated(x, y, coreR * 2.6, coreR * 2.6, 0)

		surface.SetDrawColor(255, 255, 255, a * 0.8)
		surface.DrawTexturedRectRotated(x, y, coreR * 1.2, coreR * 1.2, 0)
	end
end

local function DrawSWATLights(timeLeft, master, y, offsetX)
	local p = 1 - math.Clamp(timeLeft / 120, 0, 1)
	local urgency = 1 - math.Clamp(timeLeft / 20, 0, 1) -- ramps up over the last 20 seconds
	local dt = math.min(FrameTime(), 0.05)

	-- Flash rate is capped at 3 cycles/sec (photosensitivity); the spin keeps accelerating.
	local flashHz = math.min(Lerp(p ^ 1.5, 0.5, 2) + urgency * 0.8, 3)
	local spinDeg = Lerp(p ^ 1.3, 40, 200) + urgency * 240

	lightPhase = lightPhase + dt * flashHz * math.pi * 2
	beamAngle = (beamAngle + dt * spinDeg) % 360

	local sharp = Smooth((p - 0.35) / 0.65)

	-- smooth sine pulse: gentle breathing at first, deeper alternating swell at the end
	local function Shape(f)
		return Lerp(sharp, 0.8 + 0.2 * f, 0.2 + 0.8 * f)
	end

	local fRed = 0.5 + 0.5 * math.sin(lightPhase)
	local fBlue = 0.5 + 0.5 * math.sin(lightPhase + math.pi)

	DrawBeacon(sw * 0.5 - offsetX, y, COL_RED, Shape(fRed), p, sharp, beamAngle, master)
	DrawBeacon(sw * 0.5 + offsetX, y, COL_BLUE, Shape(fBlue), p, sharp, -beamAngle, master)
end

-- Startup music, shared by both variants: the ghetto start sound 8 seconds into the intro, then the
-- ghetto loop from 12 seconds (its level follows fear). With a real SWAT countdown (Planned) it also
-- switches to the police track when SWAT arrives. Unexpected passes math.huge: no SWAT, no police track.
local function StartupMusicHUD(timeBeforeSWAT)
	if TurfIntroStartTime + 8 < CurTime() then
		if playstart then
			sound.PlayFile("sound/music_themes/ghetto_start.wav", "noblock noplay", function(station)
				if IsValid(station) then
					station:SetVolume(0.3 * MusicVolume:GetFloat())
					station:Play()
				end
			end)

			playstart = nil
		end

		local baseLevel = !RoundEnded() and (lply:Alive() and lply.organism and !lply.organism.otrub and lply.organism.fear and math.Clamp(lply.organism.fear + 0.3 + (timeBeforeSWAT <= 0 and 2 or 0), 0, 1) or 0.3) or 0
		lerpsnd = LerpFT(0.01, lerpsnd, baseLevel)

		-- the round music (ghetto loop) sits ROUND_MUSIC_BOOST higher, and still fades out when the round ends
		loopsnd = LerpFT(0.01, loopsnd, baseLevel > 0 and (baseLevel + ROUND_MUSIC_BOOST) or 0)

		if TurfIntroStartTime + 12 < CurTime() then
			if IsValid(TURFWARS_LoopStation) then
				TURFWARS_LoopStation:SetVolume(loopsnd * MusicVolume:GetFloat())
				TURFWARS_LoopStation:Play()

				if IsValid(TURFWARS_LoopStation2) then
					TURFWARS_LoopStation2:SetVolume(0)
					TURFWARS_LoopStation2:Play()
				end
			end
		end

		if IsValid(TURFWARS_LoopStation) and TURFWARS_LoopStation:GetState() == GMOD_CHANNEL_PLAYING then
			TURFWARS_LoopStation:SetVolume(loopsnd * MusicVolume:GetFloat())
		end

		if timeBeforeSWAT <= 0 then
			-- SWAT music: comes in louder, holds, then fades out and stops
			local sinceSWAT = -timeBeforeSWAT
			local swatLevel = POLICE_BOOST

			if sinceSWAT > POLICE_HOLD then
				swatLevel = POLICE_BOOST * (1 - Smooth((sinceSWAT - POLICE_HOLD) / POLICE_FADE))
			end

			if IsValid(TURFWARS_LoopStation2) then
				if sinceSWAT >= POLICE_HOLD + POLICE_FADE then
					TURFWARS_LoopStation2:Stop()
					TURFWARS_LoopStation2 = nil
				else
					TURFWARS_LoopStation2:SetVolume(lerpsnd * swatLevel * MusicVolume:GetFloat())
				end
			end

			if IsValid(TURFWARS_LoopStation) then
				TURFWARS_LoopStation:SetVolume(0)
			end
		end
	end
end

-- Planned only: SWAT countdown timer, red/blue lights and countdown sting (plus the shared startup music).
-- Unexpected has none of the SWAT parts (no timer, no sirens, no sting).
local function PlannedHUD()
	//if !lply.organism or !lply.organism.fear then return end

	-- SWAT spawns 120s after the round actually begins (server uses ROUND_BEGIN)
	local timeBeforeSWAT = (zb.ROUND_BEGIN + 120 - CurTime())
	local introEnd = TurfIntroStartTime + 10.5
	local introDone = introEnd < CurTime()

	-- text layout: digits are right-aligned to a fixed anchor and the label starts after a gap,
	-- so the two can never overlap no matter how wide the digits get
	local swatLabel = "time left before SWAT arrives!"
	surface.SetFont("timer_FontTurf")
	local digitsW, textH = surface.GetTextSize("00:00:00")
	local labelW = surface.GetTextSize(swatLabel)
	local gap = ScreenScale(4)
	local totalW = digitsW + gap + labelW
	local textY = sh * 0.05
	local anchorX = sw * 0.5 - totalW * 0.5 + digitsW

	-- one-shot countdown sting (once per round, keyed to the round's own start time)
	if introDone and RoundActive() and warnPlayedFor ~= zb.ROUND_START and timeBeforeSWAT > 0 and timeBeforeSWAT <= WARN_TRIGGER then
		warnPlayedFor = zb.ROUND_START
		DebugPrint("sting triggered, seconds left:", math.Round(timeBeforeSWAT, 1))

		sound.PlayFile(WARN_SOUND, "noblock noplay", function(station, errorID, errorName)
			if not IsValid(station) then
				DebugPrint("sting failed to load:", errorID, errorName)
				return
			end

			-- the round may have moved on while the file was loading
			if not RoundActive() then
				station:Stop()
				return
			end

			if IsValid(warnStation) then
				warnStation:Stop()
			end

			warnStation = station
			warnStart = CurTime()
			endedAt = nil
			station:SetVolume(MusicVolume:GetFloat())
			station:Play()
		end)
	end

	-- red/blue lights flanking the timer
	if introDone and RoundActive() and cvLights:GetBool() then
		local fadeIn = Smooth((CurTime() - introEnd) / 2)
		local fadeOut = (timeBeforeSWAT > 0) and 1 or (1 - Smooth(-timeBeforeSWAT / 8))
		local master = fadeIn * fadeOut

		if master > 0.01 then
			DrawSWATLights(timeBeforeSWAT, master, textY + textH * 0.5, totalW * 0.5 + ScreenScale(22))
		end
	end

	if timeBeforeSWAT > 0 and introDone then
		local time = string.FormattedTime(timeBeforeSWAT, "%02i:%02i:%02i")
		local outline = Color(0, 0, 0, 200)

		draw.SimpleTextOutlined(time, "timer_FontTurf", anchorX, textY, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, outline)
		draw.SimpleTextOutlined(swatLabel, "timer_FontTurf", anchorX + gap, textY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, outline)
	end

	StartupMusicHUD(timeBeforeSWAT)
end

local function DrawIntro()
	if not TurfIntroStartTime or TurfIntroStartTime <= 0 then return end
	if lply:Team() == TEAM_SPECTATOR then return end

	local t = CurTime() - TurfIntroStartTime
	if t > TurfIntroDuration then return end

	zb.RemoveFade()

	local intro_fade = math.Clamp(t / 1.25, 0, 1)
	local out_fade = math.Clamp((TurfIntroDuration - t) / 4, 0, 1)
	local team_ = turfIntroTeam or lply:Team()
	local teamData = teams[team_] or teams[0]
	local ColorRole = teamData.color1
	local variantData = GetVariant(shownVariant or 1)
	local introSubtitle = (turfIntroSubtitle ~= "") and turfIntroSubtitle or variantData.name
	local introDescription = (turfIntroDescription ~= "") and turfIntroDescription or variantData.description

	MODE.CursorLerpX = Lerp(FrameTime() * 6, MODE.CursorLerpX or 0, (gui.MouseX() - sw * 0.5) / (sw * 0.5))
	MODE.CursorLerpY = Lerp(FrameTime() * 6, MODE.CursorLerpY or 0, (gui.MouseY() - sh * 0.5) / (sh * 0.5))

	local cursor_reach = ScreenScale(7)
	local cox = math.Clamp(MODE.CursorLerpX, -1, 1) * cursor_reach
	local coy = math.Clamp(MODE.CursorLerpY, -1, 1) * cursor_reach

	local elements = {}
	local function add(text, fontname, col, x, y, dir, delay, plx, notilt)
		elements[#elements + 1] = {
			text = text,
			font = fontname,
			r = col.r, g = col.g, b = col.b,
			x = x, y = y,
			dir = dir, delay = delay, plx = plx or 1,
			notilt = notilt,
		}
	end

	add("Turf Wars", "ZB_HomicideHeader", Color(255, 255, 255), sw * 0.5, sh * 0.1, "left", 0, 0.9)
	add(introSubtitle, "ZB_HomicideMediumLarge", Color(255, 255, 255), sw * 0.5, sh * 0.2, "left", 0.25, 0.95)
	add(introDescription, "ZCity_Menu_Settings_Small", Color(225, 225, 225), sw * 0.5, sh * 0.26, "left", 0.45, 1, true)
	add("You are " .. (turfIntroRoleName or teamData.name), "ZB_HomicideMediumLarge", ColorRole, sw * 0.5, sh * 0.5, "right", 0.7, 1.1)
	add(teamData.objective, "ZB_HomicideMedium", Color(255, 255, 255), sw * 0.5, sh * 0.9, "bottom", 1.4, 1.3, true)

	local tilts = MODE.RoundTextTilts or {}
	for i, el in ipairs(elements) do
		local appear = turf_ease_out(math.Clamp((t - el.delay) / 2.0, 0, 1))
		local a = 255 * appear * intro_fade * out_fade

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

			x = x + cox * el.plx
			y = y + coy * el.plx

			local tilt = el.notilt and 0 or (tilts[i] or 3) * appear
			turf_draw_text(el.text, el.font, x, y, el.r, el.g, el.b, a, tilt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	if hg.PluvTown.Active then
		local pluv_appear = turf_ease_out(math.Clamp(t / 1.0, 0, 1))
		local pluv_a = pluv_appear * out_fade

		surface.SetMaterial(hg.PluvTown.PluvMadness)
		surface.SetDrawColor(255, 255, 255, math.random(175, 255) * pluv_a / 2)
		surface.DrawTexturedRect(sw * 0.25 + cox, sh * 0.44 - ScreenScale(15) + coy, sw / 2, ScreenScale(30))

		draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2 + cox, sh * 0.44 - ScreenScale(2) + coy, Color(0, 0, 0, 255 * pluv_a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function MODE:HUDPaint()
	if shownVariant == 1 then
		PlannedHUD()
	elseif shownVariant == 2 then
		-- Unexpected: the same startup music as Planned, but no SWAT: no timer, lights, sting or police track
		StartupMusicHUD(math.huge)
	end

	DrawIntro()
end

local function WarnVolume(e)
	local v = 1

	if e > WARN_HOLD then
		v = Lerp(Smooth((e - WARN_HOLD) / WARN_FADE_TIME), 1, WARN_FLOOR)

		local tailStart = WARN_HOLD + WARN_FADE_TIME
		if e > tailStart then
			v = Lerp(Smooth((e - tailStart) / (WARN_END - tailStart)), WARN_FLOOR, 0)
		end
	end

	-- quick fade if the round ends while it is still playing
	if endedAt then
		v = v * (1 - Smooth((CurTime() - endedAt) / 1.5))
	end

	return v
end


-- Keeps the music in order: stops everything when this is not a Turf Wars round, eases the
-- vote/round track toward its level, and drives the Planned countdown sting's volume
hook.Add("Think", "TurfWarsMusicCleanup", function()
	local mode = CurrentRound()

	if not mode or mode.name ~= "turfwars" then
		if musicStation or TURFWARS_LoopStation or TURFWARS_LoopStation2 or warnStation then
			StopTurfMusic()
			StopVoteMusic()
		end
		return
	end

	UpdateVoteMusic()

	if IsValid(warnStation) then
		-- round over (or back in pre-round): fade the sting out; round running again: no fade
		if RoundActive() then
			endedAt = nil
		elseif not endedAt then
			endedAt = CurTime()
		end

		local e = CurTime() - warnStart

		if e >= WARN_END or (endedAt and CurTime() - endedAt >= 1.5) then
			warnStation:Stop()
			warnStation = nil
		else
			warnStation:SetVolume(WarnVolume(e) * MusicVolume:GetFloat())
		end
	end
end)

-- No custom end screen here on purpose: Chudmorse's own round summary (stats screen) shows
-- at the end of the round, same as riot. The music and the sting follow zb.ROUND_STATE.

function MODE:RoundStart()
	CloseVoteMenu()
	CloseClassMenu()
	TurfVoteFadeStart = 0
	TurfVoteFadeEnd = 0

	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end
end
