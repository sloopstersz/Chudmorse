local MODE = MODE
local introStart, introDuration, juggernaut, music, result
local generation = 0

local function StopIntro()
    generation = generation + 1
    if IsValid(music) then music:Stop() end
    music = nil
    introStart = nil
end

net.Receive("rem_juggernaut_intro", function()
    StopIntro()
    juggernaut = net.ReadBool()
    introDuration = net.ReadFloat()
    introStart = CurTime()
    result = nil
    zb.RemoveFade()
    local request = generation
    sound.PlayFile("sound/rem_juggernaut.mp3", "noplay", function(channel)
        if not IsValid(channel) then return end
        if request ~= generation or not introStart then channel:Stop() return end
        music = channel
        music:SetVolume(0.8)
        music:Play()
    end)
end)

hook.Add("Think", "rem_juggernaut_audio_cleanup", function()
    if not introStart then return end
    if not CurrentRound() or CurrentRound().name ~= "juggernaut" or CurTime() >= introStart + introDuration then
        StopIntro()
    elseif IsValid(music) then
        music:SetVolume(0.8 * math.Clamp((introStart + introDuration - CurTime()) / 2, 0, 1))
    end
end)

function MODE:HUDPaint()
    local w, h = ScrW(), ScrH()
    if result and zb.ROUND_STATE == 3 then
        draw.SimpleTextOutlined(result, "ZB_HomicideMediumLarge", w / 2, h * 0.4,
            Color(190, 30, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
        return
    end
    if not introStart then return end
    local t = CurTime() - introStart
    local fade = math.Clamp((introDuration - t) / 2, 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(0, 0, w, h)
    local parallax = math.Clamp((gui.MouseX() - w / 2) / w, -0.5, 0.5) * ScreenScale(10)
    local function Line(text, font, y, delay, direction, red)
        local appear = 1 - (1 - math.Clamp((t - delay) / 1.5, 0, 1)) ^ 3
        local x = w / 2 + (1 - appear) * direction * w * 0.35 + parallax
        local color = red and Color(190, 30, 30, 255 * appear * fade) or Color(235, 235, 235, 255 * appear * fade)
        draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    Line("JUGGERNAUT", "ZB_HomicideHeader", h * 0.15, 0, -1, false)
    Line(juggernaut and "You are the Juggernaut" or "You are a Survivor",
        "ZB_HomicideMediumLarge", h * 0.5, 0.6, 1, true)
    Line(juggernaut and "Hunt them down. Leave no one standing." or "Stay together. Take down the Juggernaut.",
        "ZB_HomicideMedium", h * 0.85, 1.2, -1, false)
end
