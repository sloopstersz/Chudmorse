local MODE = MODE

MODE.name = "zzombies"

-- Startup screen timing (seconds). The whole screen lasts MODE.IntroDuration (7).
local FADE_IN = 1.0     -- world fades to black
local FADE_OUT = 2.5    -- everything fades away at the end
local SLIDE_TIME = 1.6  -- how long each line takes to slide into place

local SLIDE_X = function() return ScreenScale(220) end
local SLIDE_Y = function() return ScreenScale(120) end

local SURVIVOR_COLOR = Color(90, 200, 110)
local INFECTED_COLOR = Color(200, 30, 30)

-- Phase text at the top of the screen.
local PHASE_TEXT_HOLD = 30  -- seconds into a phase before the text starts fading
local PHASE_TEXT_FADE = 2   -- how long the fade takes

-- shake is in ScreenScale units (pixels at 1080p are about 3x that), rot is degrees.
-- shake/rot are used for the cooldown announcement; roundShake/roundRot once the phase
-- is actually running (Phase Three's red text calms down after its cooldown ends).
local PHASE_STYLES = {
	[1] = {color = Color(235, 235, 235), shake = 0,   rot = 0,   roundShake = 0,   roundRot = 0},     -- plain
	[2] = {color = Color(255, 210, 40),  shake = 0.4, rot = 0,   roundShake = 0.4, roundRot = 0},     -- yellow, slight shaking
	[3] = {color = Color(230, 35, 35),   shake = 1.4, rot = 1.5, roundShake = 0.6, roundRot = 0.4}    -- red, full shaking, then less
}

local introStart = -math.huge
local introTilts = {}
local introFirstInfected = false

local function easeOut(x)
	return 1 - (1 - x) ^ 3
end

-- Cheap deterministic noise in -1..1.
local function noise(seed)
	local x = math.sin(seed * 127.1) * 43758.5453
	return (x - math.floor(x)) * 2 - 1
end

local function drawTilted(text, font, x, y, col, alpha, ang)
	local m = Matrix()
	m:Translate(Vector(x, y, 0))
	m:Rotate(Angle(0, ang, 0))
	m:Translate(Vector(-x, -y, 0))

	cam.PushModelMatrix(m)
		draw.SimpleText(text, font, x, y, Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.PopModelMatrix()
end

-- Returns time since the intro began and its total length, or nil when it isn't showing.
local function IntroTimes()
	local duration = MODE.IntroDuration or 7
	local t = CurTime() - introStart

	if t < 0 or t > duration then return nil end

	return t, duration
end

net.Receive("zzombies_start", function()
	introFirstInfected = net.ReadBool()
	introStart = CurTime()

	introTilts = {}
	for i = 1, 8 do
		introTilts[i] = (math.random() < 0.5) and 3 or -3
	end

	if zb and zb.RemoveFade then
		zb.RemoveFade()
	end
end)

--------------------------------------------------------------------------------
-- National Guard intro (only the players picked as guard see and hear this)
--
-- Black screen, MW3-style typed text, their model turning slowly beside it, and the song
-- from 2:10 to 2:20. The song starts a couple of seconds early and fades in, and fades out
-- at the end. The server spawns them the moment it is over.
--------------------------------------------------------------------------------

local GUARD_SONG_PATH = "sound/zzombies/guard_intro.mp3"
local GUARD_SONG_POS = 130         -- 2:10, where the intro text starts
local GUARD_SONG_FADE_OUT = 1.5

local guardIntro = nil
local guardChan = nil
local guardPanel = nil

local function GuardIntroTime()
	if not guardIntro then return nil end

	local t = CurTime() - guardIntro.start
	if t > guardIntro.duration + 0.7 then return nil end

	return t
end

local function StopGuardIntro()
	if IsValid(guardChan) then guardChan:Stop() end
	if IsValid(guardPanel) then guardPanel:Remove() end

	guardChan, guardPanel, guardIntro = nil, nil, nil
end

local function CreateGuardPanel()
	local sw, sh = ScrW(), ScrH()

	local panel = vgui.Create("DModelPanel")
	panel:SetSize(sw * 0.36, sh * 0.8)
	panel:SetPos(sw * 0.58, sh * 0.1)
	panel:SetModel(guardIntro.model)
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
	panel:SetFOV(30)

	local ent = panel.Entity

	if IsValid(ent) then
		ent:SetBodygroup(0, 14)
		ent.GetPlayerColor = function() return Vector(5 / 255, 65 / 255, 0) end

		local seq = ent:SelectWeightedSequence(ACT_HL2MP_IDLE)
		if seq > -1 then ent:SetSequence(seq) end

		local mn, mx = ent:GetRenderBounds()
		local center = (mn + mx) * 0.5
		local radius = (mx - mn):Length()

		panel:SetLookAt(center)
		panel:SetCamPos(center + Vector(radius * 1.35, 0, radius * 0.05))
	end

	local start = guardIntro.start

	function panel:LayoutEntity(e)
		e:SetAngles(Angle(0, (CurTime() - start) * 22, 0))
	end

	guardPanel = panel
end

net.Receive("zzombies_guard_intro", function()
	StopGuardIntro()

	local ply = LocalPlayer()
	local info = {
		start = net.ReadFloat(),
		duration = net.ReadFloat(),
		rank = net.ReadString(),
		model = "models/dejtriyev/enhancednatguard/male_0" .. net.ReadUInt(4) .. ".mdl",
		name = string.upper((ply.SteamName and ply:SteamName()) or ply:Nick()),
		clock = os.date("%H:%M:%S")
	}

	guardIntro = info

	sound.PlayFile(GUARD_SONG_PATH, "noplay", function(ch, _, errStr)
		if not IsValid(ch) then
			print("[Z-Zombies] Could not play " .. GUARD_SONG_PATH .. " (" .. tostring(errStr) .. ")")
			return
		end

		if guardIntro ~= info then
			ch:Stop()
			return
		end

		-- Jump to where the song should be right now (it starts before the intro does).
		ch:SetTime(math.max(GUARD_SONG_POS + (CurTime() - info.start), 0))
		ch:SetVolume(0)
		ch:Play()

		guardChan = ch
	end)
end)

hook.Add("Think", "ZZombies_GuardIntro", function()
	if not guardIntro then return end

	if (zb.CROUND_MAIN or zb.CROUND) ~= "zzombies" then
		StopGuardIntro()
		return
	end

	local t = CurTime() - guardIntro.start
	local duration = guardIntro.duration
	local preroll = MODE.GuardPreroll or 2

	if IsValid(guardChan) then
		if t >= duration then
			guardChan:Stop()
			guardChan = nil
		else
			local cv = GetConVar("zzombies_music_volume")
			local fade = math.Clamp(math.min((t + preroll) / preroll, (duration - t) / GUARD_SONG_FADE_OUT), 0, 1)

			guardChan:SetVolume(fade * (cv and cv:GetFloat() or 1))
		end
	end

	if t >= 0 and not guardIntro.panelMade then
		guardIntro.panelMade = true
		CreateGuardPanel()
	end

	if IsValid(guardPanel) then
		guardPanel:SetAlpha(255 * math.Clamp(math.min(t / 0.8, (duration + 0.6 - t) / 0.6), 0, 1))
	end

	if t > duration + 0.7 then
		StopGuardIntro()
	end
end)

local function DrawGuardOverlay()
	local t = GuardIntroTime()
	if not t or t < 0 then return end

	if zb and zb.RemoveFade then
		zb.RemoveFade()
	end

	local alpha = 255 * math.Clamp(math.min(t / 0.4, (guardIntro.duration + 0.6 - t) / 0.6), 0, 1)

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

local function WrapText(text, font, maxWidth)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(text, "%S+") do
		local try = (line == "") and word or (line .. " " .. word)

		if line ~= "" and surface.GetTextSize(try) > maxWidth then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if line ~= "" then lines[#lines + 1] = line end

	return lines
end

local GUARD_ORDERS = "You are a National Guard. Your main priority is to safely evacuate the remaining survivors to the extraction point. You have two minutes."

local function DrawGuardText()
	local t = GuardIntroTime()
	if not t or t < 0 then return end

	local info = guardIntro
	local sw = ScrW()
	local alpha = 255 * math.Clamp((info.duration + 0.5 - t) / 0.5, 0, 1)
	local blink = math.floor(t * 3) % 2 == 0
	local x = sw * 0.07
	local y = ScrH() * 0.26

	-- Typed lines, one after another: {text, font, delay, characters per second, color}.
	local lines = {
		{"NATIONAL GUARD", "ZB_HomicideMedium", 0.6, 22, Color(255, 255, 255)},
		{"Operation Z-Zombies", "ZCity_Menu_Settings_Small", 1.5, 30, Color(210, 210, 210)},
		{info.rank .. " " .. info.name, "ZCity_Menu_Settings_Small", 2.4, 30, Color(210, 210, 210)},
		{info.clock .. "  -  Extraction Zone", "ZCity_Menu_Settings_Small", 3.3, 30, Color(210, 210, 210)}
	}

	for _, l in ipairs(lines) do
		local text, font, delay, cps, col = l[1], l[2], l[3], l[4], l[5]

		surface.SetFont(font)
		local _, h = surface.GetTextSize("A")

		local shown = math.Clamp(math.floor((t - delay) * cps), 0, #text)

		if shown > 0 then
			local typing = shown < #text
			draw.SimpleText(string.sub(text, 1, shown) .. ((typing and blink) and "_" or ""), font, x, y, Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		y = y + h + ScreenScale(3)
	end

	-- The orders, typed out below.
	y = y + ScreenScale(10)

	local font = "ZB_HomicideMedium"
	local wrapped = WrapText(GUARD_ORDERS, font, sw * 0.46)
	local revealed = math.floor((t - 4.6) * 38)

	surface.SetFont(font)
	local _, h = surface.GetTextSize("A")

	for _, line in ipairs(wrapped) do
		if revealed <= 0 then break end

		local shown = math.min(revealed, #line)

		draw.SimpleText(string.sub(line, 1, shown) .. ((shown < #line and blink) and "_" or ""), font, x, y, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		revealed = revealed - #line - 1
		y = y + h + ScreenScale(2)
	end
end

-- The helicopter arrives (everyone who isn't going to be guard).
local HELI_PATH = "sound/zzombies/helicopter.mp3"
local heliChan = nil

local function PlayHelicopter()
	sound.PlayFile(HELI_PATH, "", function(ch, _, errStr)
		if IsValid(ch) then
			heliChan = ch -- keep a reference so it isn't collected mid-sound
			ch:SetVolume(1)
			ch:Play()
		else
			print("[Z-Zombies] Could not play " .. HELI_PATH .. " (" .. tostring(errStr) .. "), trying the fallback")
			surface.PlaySound("zzombies/helicopter.mp3")
		end
	end)
end

net.Receive("zzombies_heli", PlayHelicopter)

-- Test for the two sounds on your own machine, no round needed: the helicopter now, then the
-- National Guard song (2:08 to 2:20, fading in and out) 11 seconds later.
-- If you hear nothing, check the console: it says whether the files could be loaded.
concommand.Add("zzombies_testaudio", function()
	print("[Z-Zombies] Audio test: helicopter now, guard song in 11 seconds")
	PlayHelicopter()

	timer.Simple(11, function()
		sound.PlayFile(GUARD_SONG_PATH, "noplay", function(ch, _, errStr)
			if not IsValid(ch) then
				print("[Z-Zombies] Could not play " .. GUARD_SONG_PATH .. " (" .. tostring(errStr) .. ")")
				return
			end

			local span = 12 -- 2:08 to 2:20
			local start = CurTime()

			ch:SetTime(GUARD_SONG_POS - 2)
			ch:SetVolume(0)
			ch:Play()

			hook.Add("Think", "ZZombies_TestAudio", function()
				local t = CurTime() - start

				if not IsValid(ch) or t >= span then
					if IsValid(ch) then ch:Stop() end
					hook.Remove("Think", "ZZombies_TestAudio")
					return
				end

				ch:SetVolume(math.Clamp(math.min(t / 2, (span - t) / GUARD_SONG_FADE_OUT), 0, 1))
			end)
		end)
	end)
end)

-- Extraction zones. The server sends them when the helicopter arrives.
local zones = {}
local zoneRadius = 100

net.Receive("zzombies_zones", function()
	zoneRadius = net.ReadFloat()
	zones = {}

	for i = 1, net.ReadUInt(8) do
		zones[i] = net.ReadVector()
	end
end)

local function ZonesOpen()
	local eta = GetGlobalFloat("ZZ_ExtractETA", 0)

	return #zones > 0 and eta > 0 and CurTime() >= eta
end

-- The zone itself: a soft, faint red haze. It is built from many very transparent shells
-- of different sizes, so it has no hard edge and gets a little denser toward the middle.
-- It is depth tested, so walls hide it; the "Extraction" label is what shows where it is.
local ZONE_SHELLS = 8

hook.Add("PostDrawTranslucentRenderables", "ZZGroundExtractionZones", function(depth, sky)
    if depth or sky or not zb or zb.CROUND ~= "zzombies" or zb.ROUND_STATE ~= 1
        or not GetGlobalBool("ZZ_GroundExtraction", false) or not ZonesOpen() then return end
    render.SetColorMaterial()
    for _, point in ipairs(zones) do
        render.DrawWireframeSphere(point + Vector(0, 0, 8), zoneRadius, 24, 8, Color(70, 220, 180, 150), false)
    end
end)
hook.Add("HUDPaint", "ZZGroundExtractionLabels", function()
    if not zb or zb.CROUND ~= "zzombies" or zb.ROUND_STATE ~= 1
        or not GetGlobalBool("ZZ_GroundExtraction", false) or not ZonesOpen() then return end
    for _, point in ipairs(zones) do
        local screen = (point + Vector(0, 0, 48)):ToScreen()
        if screen.visible then
            draw.SimpleTextOutlined("EXTRACTION - STAY 10 SECONDS", "ZCity_Menu_Settings_Small",
                screen.x, screen.y, Color(70, 220, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        end
    end
end)


-- The loading bar at the bottom while you stand in a zone.
local function DrawExtractBar()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	local start = ply:GetNetVar("ZZ_ExtractStart", 0)
	if start <= 0 then return end

	local p = math.Clamp((CurTime() - start) / (MODE.ExtractionHold or 10), 0, 1)
	local sw, sh = ScrW(), ScrH()
	local w, h = sw * 0.24, ScreenScale(5)
	local x, y = sw * 0.5 - w * 0.5, sh * 0.9

	draw.SimpleTextOutlined("EXTRACTING...", "ZCity_Menu_Settings_Small", sw * 0.5, y - ScreenScale(4), Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 200))

	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(x - 2, y - 2, w + 4, h + 4)

	surface.SetDrawColor(230, 35, 35, 230)
	surface.DrawRect(x, y, w * p, h)
end

-- Small countdown in the top right. In the last phase it first counts down to the
-- helicopter, then (once the National Guard are in) to the end of the extraction window.
local function DrawExtractionTimer()
	if GuardIntroTime() then return end

	local now = CurTime()
	local eta = GetGlobalFloat("ZZ_ExtractETA", 0)
	local deadline = GetGlobalFloat("ZZ_ExtractDeadline", 0)
	local label, remaining

	if deadline > now then
		label, remaining = "EXTRACTION", deadline - now
	elseif eta > now then
		label, remaining = "EXTRACTION ARRIVES", eta - now
	else
		return
	end

	local secs = math.ceil(remaining)
	local text = string.format("%s  %d:%02d", label, math.floor(secs / 60), secs % 60)
	local col = Color(235, 235, 235)

	if remaining <= 10 or (deadline > now and remaining <= 60) then
		local pulse = 0.5 + 0.5 * math.sin(now * 8)
		col = Color(255, 80 + pulse * 100, 80 + pulse * 100)
	end

	draw.SimpleTextOutlined(text, "ZCity_Menu_Settings_Small", ScrW() - ScreenScale(8), ScrH() * 0.03, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
end

-- Black backdrop for the startup screen, same approach as the riot intro.
function MODE:RenderScreenspaceEffects()
	DrawGuardOverlay()

	local t, duration = IntroTimes()
	if not t then return end

	if zb and zb.RemoveFade then
		zb.RemoveFade()
	end

	local fadeIn = math.Clamp(t / FADE_IN, 0, 1)
	local fadeOut = math.Clamp((duration - t) / FADE_OUT, 0, 1)

	surface.SetDrawColor(0, 0, 0, 255 * fadeIn * fadeOut)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

-- One line of phase text, tinted and shaken by the phase's style. y is the top of the line.
local function DrawPhaseLine(text, font, x, y, style, alpha, inRound)
	surface.SetFont(font)
	local _, h = surface.GetTextSize(text)

	local now = CurTime()
	local step = math.floor(now * 40)
	local amp = ScreenScale(inRound and style.roundShake or style.shake)

	local cx = x + noise(step) * amp
	local cy = y + h * 0.5 + noise(step + 101) * amp
	local ang = noise(step + 211) * (inRound and style.roundRot or style.rot)

	local m = Matrix()
	m:Translate(Vector(cx, cy, 0))
	m:Rotate(Angle(0, ang, 0))
	m:Translate(Vector(-cx, -cy, 0))

	local col = style.color

	cam.PushModelMatrix(m)
		draw.SimpleTextOutlined(text, font, cx, cy, Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha * 0.8))
	cam.PopModelMatrix()
end

-- Top of screen: the phase cooldown between rounds, or the current phase name during one.
local function DrawPhaseHUD()
	if zb.ROUND_STATE == 3 then return end
	if IntroTimes() or GuardIntroTime() then return end

	local sw, sh = ScrW(), ScrH()
	local now = CurTime()
	local phase = GetGlobalInt("ZZ_Phase", 1)
	local phases = MODE.Phases or {}
	local data = phases[phase]
	local phaseLine = data and ("Phase " .. data.number .. ": " .. data.name) or nil
	local style = PHASE_STYLES[phase] or PHASE_STYLES[1]
	local outline = Color(0, 0, 0, 200)
	local y = sh * 0.03

	local cooldownEnd = GetGlobalFloat("ZZ_CooldownEnd", 0)

	if cooldownEnd > now then
		local remaining = cooldownEnd - now
		local secs = math.ceil(remaining)
		local timerText = string.format("%d:%02d", math.floor(secs / 60), secs % 60)
		local message = "Prepare for the next Phase"

		surface.SetFont("ZB_HomicideMedium")
		local timerW, textH = surface.GetTextSize(timerText)
		local messageW = surface.GetTextSize(message)
		local gap = ScreenScale(8)

		local x = sw * 0.5 - (timerW + gap + messageW) * 0.5

		-- Last 10 seconds the timer pulses red.
		local timerColor = color_white
		if remaining <= 10 then
			local pulse = 0.5 + 0.5 * math.sin(now * 8)
			timerColor = Color(255, 90 + pulse * 100, 90 + pulse * 100)
		end

		draw.SimpleTextOutlined(timerText, "ZB_HomicideMedium", x, y, timerColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, outline)
		draw.SimpleTextOutlined(message, "ZB_HomicideMedium", x + timerW + gap, y, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, outline)

		-- The phase that is about to start, in that phase's color.
		if phaseLine then
			DrawPhaseLine(phaseLine, "ZCity_Menu_Settings_Small", sw * 0.5, y + textH + ScreenScale(2), style, 255)
		end

		return
	end

	-- Keep the phase clock visible instead of fading away with the phase title.
	local phaseEnd = GetGlobalFloat("ZZ_PhaseEnd", 0)
	if phaseEnd <= 0 then return end
	local secs = math.max(0, math.ceil(phaseEnd - now))
	local timerText = string.format("%d:%02d", math.floor(secs / 60), secs % 60)
	local timerColor = secs <= 10 and Color(255, 90, 90) or color_white
	draw.SimpleTextOutlined(timerText, "ZB_HomicideMedium", sw * 0.5, y,
		timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, outline)
	if phaseLine then
		surface.SetFont("ZB_HomicideMedium")
		local _, textH = surface.GetTextSize(timerText)
		DrawPhaseLine(phaseLine, "ZCity_Menu_Settings_Small", sw * 0.5,
			y + textH + ScreenScale(2), style, 255)
	end
end

-- The sliding-text startup screen (same style as the riot intro), 7 seconds.
local function DrawIntro()
	local lply = LocalPlayer()
	if not IsValid(lply) or lply:Team() == TEAM_SPECTATOR then return end

	local t, duration = IntroTimes()
	if not t then return end

	local sw, sh = ScrW(), ScrH()
	local fadeIn = math.Clamp(t / FADE_IN, 0, 1)
	local fadeOut = math.Clamp((duration - t) / FADE_OUT, 0, 1)

	-- The first infected gets their own role lines, in red. Same slide-in for everyone.
	local roleText = introFirstInfected and "You are the first infected" or "You are a survivor..."
	local roleColor = introFirstInfected and INFECTED_COLOR or SURVIVOR_COLOR
	local objectiveText = introFirstInfected and "brainssss" or "Gather whatever gear you can, stick together, and survive the surge"
	local objectiveColor = introFirstInfected and INFECTED_COLOR or Color(255, 255, 255)

	local elements = {
		{text = "Z-Zombies", font = "ZB_HomicideHeader", color = Color(255, 255, 255), y = sh * 0.1, dir = "left", delay = 0, tilt = true},
		{text = "Survive the 3 phases of zombie hordes until the end", font = "ZCity_Menu_Settings_Small", color = Color(225, 225, 225), y = sh * 0.2, dir = "left", delay = 0.25, tilt = false},
		{text = roleText, font = "ZB_HomicideMediumLarge", color = roleColor, y = sh * 0.5, dir = "right", delay = 0.7, tilt = true},
		{text = objectiveText, font = "ZB_HomicideMedium", color = objectiveColor, y = sh * 0.9, dir = "bottom", delay = 1.3, tilt = false}
	}

	for i, el in ipairs(elements) do
		local appear = easeOut(math.Clamp((t - el.delay) / SLIDE_TIME, 0, 1))
		local alpha = 255 * appear * fadeIn * fadeOut

		if alpha > 1 then
			local slide = 1 - appear
			local x, y = sw * 0.5, el.y

			if el.dir == "left" then
				x = x - slide * SLIDE_X()
			elseif el.dir == "right" then
				x = x + slide * SLIDE_X()
			elseif el.dir == "bottom" then
				y = y + slide * SLIDE_Y()
			end

			local tilt = el.tilt and (introTilts[i] or 3) * appear or 0

			drawTilted(el.text, el.font, x, y, el.color, alpha, tilt)
		end
	end
end

-- Small text popups sent by the server (supply drop notice, extraction, National Guard).
-- position 0 = upper middle, 1 = top right.
local POPUP_FADE_IN = 0.25
local POPUP_FADE_OUT = 1.5

local popups = {}

net.Receive("zzombies_popup", function()
	popups[#popups + 1] = {
		text = net.ReadString(),
		duration = net.ReadFloat(),
		position = net.ReadUInt(2),
		start = CurTime()
	}
end)

local function DrawPopups()
	local now = CurTime()

	for i = #popups, 1, -1 do
		if now - popups[i].start > popups[i].duration then
			table.remove(popups, i)
		end
	end

	if #popups == 0 then return end

	local sw, sh = ScrW(), ScrH()
	local font = "ZCity_Menu_Settings_Small"

	surface.SetFont(font)
	local _, lineH = surface.GetTextSize("A")
	lineH = lineH + ScreenScale(2)

	local slots = {}

	for _, p in ipairs(popups) do
		local t = now - p.start
		local alpha = 255 * math.Clamp(math.min(t / POPUP_FADE_IN, (p.duration - t) / POPUP_FADE_OUT), 0, 1)

		local slot = slots[p.position] or 0
		slots[p.position] = slot + 1

		if alpha > 1 then
			local outline = Color(0, 0, 0, alpha * 0.8)

			if p.position == 2 then
				local pulse = 0.75 + 0.25 * math.sin(now * 10)
				draw.SimpleTextOutlined(p.text, "ZB_HomicideMedium", sw * 0.5, sh * 0.07 + slot * lineH * 2, Color(230, 35, 35, alpha * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0, 0, 0, alpha))
			elseif p.position == 1 then
				draw.SimpleTextOutlined(p.text, font, sw - ScreenScale(8), sh * 0.03 + slot * lineH, Color(235, 235, 235, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, outline)
			else
				draw.SimpleTextOutlined(p.text, font, sw * 0.5, sh * 0.17 + slot * lineH, Color(235, 235, 235, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, outline)
			end
		end
	end
end

function MODE:HUDPaint()
	DrawPhaseHUD()
	DrawExtractionTimer()

	if GetGlobalBool("ZZ_GroundExtraction", false) then DrawExtractBar() end
	DrawPopups()
	DrawIntro()
	DrawGuardText()
end


function MODE:EndRound()
	introStart = -math.huge
end

--------------------------------------------------------------------------------
-- Music
--
-- One song, played in pieces. Which piece plays (and where in the song it is) is
-- worked out every frame from the synced phase/round timers, so someone joining
-- mid-phase hears the right part.
--
--   Phase One   starts with the startup screen: plays 30s, then fades out.
--   Cooldowns   (1:00 before Phase Two and Phase Three): the song continues from
--               where the last piece stopped, so it keeps going across phases.
--   Phase Three plays the last minute of the song when the round starts.
--   Phase Two itself is silent.
--------------------------------------------------------------------------------

local TRACK_PATH = "sound/zzombies/theme.mp3"

local OPENING_HOLD = 30        -- Phase One: seconds at full volume
local OPENING_FADE = 3         -- ...then this long fading out
local OPENING_END = OPENING_HOLD + OPENING_FADE  -- where in the song the next piece picks up

local COOLDOWN_FADE_IN = 1.5
local COOLDOWN_FADE_OUT = 3

local FINAL_LENGTH = 60        -- last round plays this many seconds from the end of the song
local FINAL_FADE_IN = 1
local FINAL_FADE_OUT = 3

local VOLUME_NORMAL = 0.7
local VOLUME_FINAL = 1.0       -- loudest for the last minute

local songLength = 201.8       -- replaced by the real length once the file loads

local musicVolume = CreateClientConVar("zzombies_music_volume", "1", true, false, "Z-Zombies music volume (0-1).", 0, 1)

-- Returns which piece should be playing right now: id, position in the song (seconds),
-- fade envelope (0-1) and base volume. Returns nil when nothing should play.
local function GetMusicCue()
	local state = zb.ROUND_STATE
	if state == 3 then return nil end

	local now = CurTime()
	local phase = GetGlobalInt("ZZ_Phase", 1)
	local phaseCount = MODE.PhaseCount or 3

	if phase == 1 then
		local e = now - GetGlobalFloat("ZZ_PhaseStart", 0)

		if e >= 0 and e < OPENING_END then
			local env = math.min(1, e / 0.4, (OPENING_END - e) / OPENING_FADE)
			return "opening", e, env, VOLUME_NORMAL
		end

		return nil
	end

	local cooldownEnd = GetGlobalFloat("ZZ_CooldownEnd", 0)

	if cooldownEnd > now then
		local cooldown = MODE.PhaseCooldown or 60
		local e = math.Clamp(cooldown - (cooldownEnd - now), 0, cooldown)
		local startPos = OPENING_END + (phase - 2) * cooldown
		local env = math.min(1, e / COOLDOWN_FADE_IN, (cooldown - e) / COOLDOWN_FADE_OUT)

		return "cooldown" .. phase, startPos + e, env, VOLUME_NORMAL
	end

	if phase >= phaseCount and state == 1 then
		local e = now - GetGlobalFloat("ZZ_RoundStart", now)

		if e >= 0 and e < FINAL_LENGTH then
			local startPos = math.max(songLength - FINAL_LENGTH, 0)
			local env = math.min(1, e / FINAL_FADE_IN, (FINAL_LENGTH - e) / FINAL_FADE_OUT)

			return "final", startPos + e, env, VOLUME_FINAL
		end
	end

	return nil
end

local chan, chanCue, chanBase
local loadingCue
local curVolume = 0
local nextTry = 0
local warned = false

local function StopMusic()
	if IsValid(chan) then chan:Stop() end

	chan, chanCue, chanBase = nil, nil, nil
	loadingCue = nil
	curVolume = 0
end

hook.Add("Think", "LastStand_Music", function()
	if (zb.CROUND_MAIN or zb.CROUND) ~= "zzombies" then
		if chan or loadingCue then StopMusic() end
		return
	end

	local cue, _, env, base = GetMusicCue()

	-- A different piece is needed: load the song and jump to the right spot.
	if cue and chanCue ~= cue and loadingCue ~= cue and CurTime() >= nextTry then
		if IsValid(chan) then chan:Stop() end
		chan, chanCue, chanBase = nil, nil, nil
		curVolume = 0
		loadingCue = cue

		sound.PlayFile(TRACK_PATH, "noplay", function(ch, errCode, errStr)
			if loadingCue ~= cue then
				if IsValid(ch) then ch:Stop() end
				return
			end

			loadingCue = nil

			if not IsValid(ch) then
				nextTry = CurTime() + 5

				if not warned then
					warned = true
					print("[Z-Zombies] Could not play " .. TRACK_PATH .. " (" .. tostring(errStr) .. ")")
				end

				return
			end

			local len = ch:GetLength()
			if len and len > 1 then songLength = len end

			-- Loading takes a moment, so ask again where we should be now.
			local nowCue, pos, _, nowBase = GetMusicCue()
			if nowCue ~= cue then
				ch:Stop()
				return
			end

			ch:SetTime(pos)
			ch:SetVolume(0)
			ch:Play()

			chan, chanCue, chanBase = ch, cue, nowBase
			curVolume = 0
		end)
	end

	if IsValid(chan) then
		local target = (cue and cue == chanCue) and env or 0
		local dt = FrameTime()

		if target > curVolume then
			curVolume = math.min(target, curVolume + dt / 0.5)
		else
			curVolume = math.max(target, curVolume - dt / 1.2)
		end

		chan:SetVolume(curVolume * (base or chanBase or VOLUME_NORMAL) * musicVolume:GetFloat())

		if not cue and curVolume <= 0.001 then
			StopMusic()
		end
	end
end)
