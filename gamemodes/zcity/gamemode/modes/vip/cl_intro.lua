local MODE = MODE
-- Music continues from selection through the role intro, fading over its last four seconds.
local channel, pending, activeEnd, nextRetry, generation = nil, false, nil, 0, 0
local function MusicVolume(station, ends)
    local remaining = ends + (MODE.IntroDuration or 10) - CurTime()
    -- A shorter MP3 must fade before its natural ending too.
    if IsValid(station) then
        local length = station:GetLength()
        if length and length > 0 then remaining = math.min(remaining, length - station:GetTime()) end
    end
    local volume = GetConVar("snd_musicvolume")
    return math.Clamp((volume and volume:GetFloat() or 1) * 1.5, 0, 1)
        * math.Clamp(remaining / 4, 0, 1)
end
local path = "sound/chudmorse/vip/rem_vip.mp3"
local function StopMusic()
    generation = generation + 1
    if IsValid(channel) then channel:Stop() end
    channel, pending, activeEnd, nextRetry = nil, false, nil, 0
end
hook.Add("Think", "ChudVIPIntroSound", function()
    local ends = math.max(ChudVIPMusicEnd or 0, GetGlobalFloat("ChudVIPLoadoutEnds", 0))
    local now = CurTime()
    if not zb or zb.CROUND ~= "vip" or (zb.ROUND_STATE ~= 0 and zb.ROUND_STATE ~= 1)
        or ends <= 0 or now >= ends + (MODE.IntroDuration or 10) then
        if channel or pending or activeEnd then StopMusic() end
        return
    end
    if activeEnd ~= ends then
        StopMusic()
        activeEnd = ends
    end
    if not IsValid(channel) and not pending and now >= nextRetry then
        pending = true
        local request = generation
        if hg and hg.DynaMusic then hg.DynaMusic:Stop() end
        sound.PlayFile(path, "noplay noblock", function(station, errorID, errorName)
            if request ~= generation or activeEnd ~= ends or not zb or zb.CROUND ~= "vip"
                or (zb.ROUND_STATE ~= 0 and zb.ROUND_STATE ~= 1) or CurTime() >= ends + (MODE.IntroDuration or 10) then
                if IsValid(station) then station:Stop() end
                return
            end
            pending = false
            if not IsValid(station) then
                nextRetry = CurTime() + 2
                ErrorNoHalt("[VIP music] " .. path .. ": " .. tostring(errorName or errorID) .. "\n")
                return
            end
            channel = station
            local volume = GetConVar("snd_musicvolume")
            station:SetVolume(MusicVolume(station, ends))
            station:Play()
        end)
    end
    if IsValid(channel) then
        local volume = GetConVar("snd_musicvolume")
        channel:SetVolume(MusicVolume(channel, ends))
    end
end)
hook.Add("ShutDown", "ChudVIPIntroStop", StopMusic)


-- Turf War-style role reveal. This is presentation only: no camera or movement lock.
function MODE:DrawDeploymentIntro()
    if not zb or zb.CROUND ~= "vip" or zb.ROUND_STATE ~= 1 then return false end
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    local role = ply:GetNWString("ChudVIPRole", "")
    if role == "" then return false end
    local roundEnd = GetGlobalFloat("ChudVIPEndAt", 0)
    if roundEnd <= 0 then return false end
    local started = roundEnd - self.ROUND_TIME
    local duration = self.IntroDuration or 10
    local elapsed = CurTime() - started
    if elapsed < 0 or elapsed >= duration then return false end
    if zb.RemoveFade then zb.RemoveFade() end
    local sw, sh = ScrW(), ScrH()
    local fadeIn = math.Clamp(elapsed / 1.25, 0, 1)
    local fadeOut = math.Clamp((duration - elapsed) / 4, 0, 1)
    local attacker = role == "Attacker"
    local label = role == "VIP" and "YOU ARE THE VIP" or attacker and "YOU ARE AN ANGRY CHUD" or "YOU ARE SWAT"
    local color = attacker and Color(190, 35, 35) or Color(60, 130, 255)
    local objective = role == "VIP" and "Reach all three marked locations."
        or attacker and "Stop the VIP from completing the route."
        or "Protect the VIP through all three locations."
    surface.SetDrawColor(0, 0, 0, 190 * fadeOut)
    surface.DrawRect(0, 0, sw, sh)
    local function Line(text, font, y, tint, delay, direction)
        local fraction = math.Clamp((elapsed - delay) / 2, 0, 1)
        local appear = 1 - (1 - fraction) ^ 3
        local x = sw * 0.5 + (1 - appear) * sw * 0.35 * direction
        draw.SimpleTextOutlined(text, font, x, sh * y,
            Color(tint.r, tint.g, tint.b, 255 * appear * fadeIn * fadeOut),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200 * fadeOut))
    end
    Line("VIP ESCORT", "ZB_HomicideHeader", 0.14, color_white, 0, -1)
    Line("PRESIDENT", "ZB_HomicideMediumLarge", 0.25, color_white, 0.25, -1)
    Line(label, "ZB_HomicideMediumLarge", 0.5, color, 0.7, 1)
    Line(objective, "ZCity_Menu_Settings_Small", 0.85, color_white, 1.4, -1)
    return true
end
