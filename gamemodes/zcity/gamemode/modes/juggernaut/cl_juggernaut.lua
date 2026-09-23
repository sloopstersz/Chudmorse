local MODE = MODE
MODE.name = "juggernaut"

local JUG_INTRO_DURATION = 7.68
local JUG_INTRO_SOUND = "juggernaut/juggernaut_intro.mp3"
local introStartTime = -math.huge
local introRole = 0

-- Keep the Juggernaut intro self-contained instead of depending on Homicide
-- having already created its fonts.
local function juggernaut_font()
    local convar = GetConVar("hg_font")
    local value = convar and convar:GetString() or ""
    return value ~= "" and value or "Lora"
end

surface.CreateFont("ZB_JuggernautMedium", {
    font = juggernaut_font(),
    size = ScreenScale(15),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_JuggernautMediumLarge", {
    font = juggernaut_font(),
    size = ScreenScale(25),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_JuggernautHeader", {
    font = juggernaut_font(),
    size = ScreenScale(45),
    weight = 400,
    antialias = true
})

local teams = {
    [0] = {
        objective = "Work together, kill the Bulldozer, and survive.",
        name = "a Scared Chud",
        color1 = Color(0, 255, 64),
        color2 = Color(255, 255, 255)
    },
    [1] = {
        objective = "Crush every Scared Chud. You are stronger, tougher, and heavily armed.",
        name = "the Fat Chud",
        color1 = Color(190, 0, 0),
        color2 = Color(255, 255, 255)
    },
}

local function juggernaut_ease_out(x)
    return 1 - (1 - x) ^ 3
end

local function juggernaut_draw_text(text, fontname, x, y, color, alpha, angle, xalign, yalign)
    local matrix = Matrix()
    matrix:Translate(Vector(x, y, 0))
    matrix:Rotate(Angle(0, angle or 0, 0))
    matrix:Translate(Vector(-x, -y, 0))

    cam.PushModelMatrix(matrix)
        draw.SimpleText(
            text,
            fontname,
            x,
            y,
            Color(color.r, color.g, color.b, alpha),
            xalign or TEXT_ALIGN_CENTER,
            yalign or TEXT_ALIGN_CENTER
        )
    cam.PopModelMatrix()
end

local function stopIntroSound()
    if MODE.RoundBeginSound then
        MODE.RoundBeginSound:Stop()
        MODE.RoundBeginSound = nil
    end
end

net.Receive("juggernaut_start", function()
    stopIntroSound()

    -- The server sends the role explicitly after GiveEquipment has completed.
    -- 0 = Scared Chud, 1 = Fat Chud/Juggernaut.
    introRole = net.ReadUInt(1)

    introStartTime = CurTime()
    MODE.DynamicFadeScreenEndTime = CurTime() + JUG_INTRO_DURATION
    MODE.CursorLerpX = 0
    MODE.CursorLerpY = 0
    MODE.RoundTextTilts = {}

    for i = 1, 8 do
        MODE.RoundTextTilts[i] = (math.random() < 0.5) and 3 or -3
    end

    local ply = LocalPlayer()
    if IsValid(ply) then
        MODE.RoundBeginSound = CreateSound(ply, JUG_INTRO_SOUND)
        if MODE.RoundBeginSound then
            MODE.RoundBeginSound:PlayEx(1, 100)
        end
    end

    if zb and zb.RemoveFade then
        zb.RemoveFade()
    end
end)

-- The intro fade is drawn inside HUDPaint before the text. This guarantees
-- the black overlay can never render over the role/title text.
function MODE:RenderScreenspaceEffects()
end


-- Survival-horror style Fat Chud vital monitor.
-- Drawn entirely in Lua so there are no GIF/material dependencies to maintain.
surface.CreateFont("ZB_JuggernautVitalsTitle", {
    font = "Trebuchet MS",
    size = 18,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZB_JuggernautVitalsHP", {
    font = "Trebuchet MS",
    size = 22,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZB_JuggernautVitalsSmall", {
    font = "Trebuchet MS",
    size = 14,
    weight = 700,
    antialias = true
})

local VITALS_W = 330
local VITALS_H = 108
local VITALS_MARGIN_X = 24
local VITALS_MARGIN_Y = 24

local ecgShape = {
    {0.00, 0.00},
    {0.12, 0.00},
    {0.17, 0.10},
    {0.22, 0.00},
    {0.28, -0.12},
    {0.32, 1.00},
    {0.36, -0.38},
    {0.41, 0.00},
    {0.56, 0.00},
    {0.63, 0.18},
    {0.71, 0.00},
    {1.00, 0.00}
}

local function sampleECG(t)
    t = t % 1

    for i = 1, #ecgShape - 1 do
        local a = ecgShape[i]
        local b = ecgShape[i + 1]

        if t >= a[1] and t <= b[1] then
            local span = b[1] - a[1]
            local frac = span > 0 and ((t - a[1]) / span) or 0
            return Lerp(frac, a[2], b[2])
        end
    end

    return 0
end

local function findFatChud()
    local teamPlayers = team.GetPlayers(1)

    -- Prefer the actual class when it has replicated to this client.
    for _, target in ipairs(teamPlayers) do
        if not IsValid(target) then continue end

        if target.GetPlayerClass and target:GetPlayerClass() == "juggernaut" then
            return target
        end

        if target.PlayerClassName == "juggernaut" then
            return target
        end
    end

    -- During the Juggernaut mode, team 1 is reserved for the Fat Chud.
    for _, target in ipairs(teamPlayers) do
        if IsValid(target) then return target end
    end
end

local function getVitalsColor(hpFrac, alive)
    if not alive or hpFrac <= 0 then
        return Color(110, 25, 25), "FLATLINE"
    elseif hpFrac <= 0.30 then
        return Color(235, 55, 45), "DANGER"
    elseif hpFrac <= 0.65 then
        return Color(225, 165, 45), "CAUTION"
    end

    return Color(80, 225, 105), "FINE"
end

local function isJuggernautClass(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    if ply.PlayerClassName == "juggernaut" then
        return true
    end

    return ply.GetPlayerClass and ply:GetPlayerClass() == "juggernaut"
end

local function isJuggernautRoundActive()
    if not zb or zb.ROUND_STATE ~= 1 then return false end

    local currentMode = zb.CROUND_MAIN or zb.CROUND
    return currentMode == "juggernaut"
end

local function drawJuggernautHealthMonitor(privateJuggernaut)
    local jug

    if isJuggernautRoundActive() then
        -- In the real Juggernaut gamemode, everyone gets the Fat Chud's vitals.
        jug = findFatChud()
    else
        -- Outside the mode (for example, when the class is assigned through
        -- the context menu), only the Juggernaut client draws their own vitals.
        if not isJuggernautClass(privateJuggernaut) then return end
        jug = privateJuggernaut
    end

    if not IsValid(jug) then return end

    local maxHP = math.max(jug:GetMaxHealth(), 1)
    local hp = math.Clamp(jug:Health(), 0, maxHP)
    local hpFrac = math.Clamp(hp / maxHP, 0, 1)
    local alive = jug:Alive() and hp > 0

    local baseColor, status = getVitalsColor(hpFrac, alive)

    -- Lower health makes the monitor dimmer while the pulse itself accelerates.
    local brightness = Lerp(hpFrac, 0.52, 1.00)
    local monitorColor = Color(
        math.floor(baseColor.r * brightness),
        math.floor(baseColor.g * brightness),
        math.floor(baseColor.b * brightness),
        245
    )

    local w = math.min(VITALS_W, ScrW() * 0.38)
    local h = VITALS_H
    local x = ScrW() - w - VITALS_MARGIN_X
    local y = ScrH() - h - VITALS_MARGIN_Y

    -- Outer monitor housing.
    draw.RoundedBox(4, x, y, w, h, Color(9, 11, 10, 235))
    surface.SetDrawColor(48, 54, 50, 245)
    surface.DrawOutlinedRect(x, y, w, h, 2)
    surface.SetDrawColor(monitorColor.r, monitorColor.g, monitorColor.b, 100)
    surface.DrawOutlinedRect(x + 3, y + 3, w - 6, h - 6, 1)

    local vitalsName = "FAT CHUD"
    if not isJuggernautRoundActive() then
        -- Context-menu Juggernaut: show the existing RP/display name, not Steam username.
        local displayName = jug.GetPlayerName and jug:GetPlayerName() or jug:GetNWString("PlayerName", "")
        if displayName and displayName ~= "" then
            vitalsName = displayName
        end
    end

    draw.SimpleText(vitalsName .. " // VITALS", "ZB_JuggernautVitalsTitle", x + 12, y + 8, Color(215, 220, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(status, "ZB_JuggernautVitalsSmall", x + w - 12, y + 10, monitorColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    local graphX = x + 12
    local graphY = y + 34
    local graphW = w - 24
    local graphH = 48

    surface.SetDrawColor(5, 14, 9, 235)
    surface.DrawRect(graphX, graphY, graphW, graphH)

    -- Faint ECG grid.
    surface.SetDrawColor(monitorColor.r, monitorColor.g, monitorColor.b, 18)
    for gx = graphX, graphX + graphW, 16 do
        surface.DrawLine(gx, graphY, gx, graphY + graphH)
    end
    for gy = graphY, graphY + graphH, 12 do
        surface.DrawLine(graphX, gy, graphX + graphW, gy)
    end

    local centerY = graphY + graphH * 0.55
    local amplitude = graphH * 0.34

    if alive then
        -- Healthy: about 52 BPM. Near-death: about 135 BPM.
        local beatPeriod = Lerp(hpFrac, 60 / 135, 60 / 52)
        local phase = (CurTime() / beatPeriod) % 1
        local samples = math.max(70, math.floor(graphW / 2))
        local previousX, previousY

        surface.SetDrawColor(monitorColor.r, monitorColor.g, monitorColor.b, 235)

        for i = 0, samples do
            local screenFrac = i / samples
            -- Show a little over two cardiac cycles across the monitor.
            local waveT = (screenFrac * 2.15 + phase) % 1
            local value = sampleECG(waveT)
            local px = graphX + screenFrac * graphW
            local py = centerY - value * amplitude

            if previousX then
                surface.DrawLine(previousX, previousY, px, py)
            end

            previousX, previousY = px, py
        end
    else
        surface.SetDrawColor(monitorColor.r, monitorColor.g, monitorColor.b, 180)
        surface.DrawLine(graphX, centerY, graphX + graphW, centerY)
    end

    -- Numeric HP plus a thin physical-health bar under the ECG.
    local hpText = string.format("%d / %d HP", math.floor(hp + 0.5), math.floor(maxHP + 0.5))
    draw.SimpleText(hpText, "ZB_JuggernautVitalsHP", x + 12, y + h - 8, monitorColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    local barW = 118
    local barH = 5
    local barX = x + w - barW - 12
    local barY = y + h - 17
    surface.SetDrawColor(28, 31, 29, 255)
    surface.DrawRect(barX, barY, barW, barH)
    surface.SetDrawColor(monitorColor.r, monitorColor.g, monitorColor.b, 220)
    surface.DrawRect(barX, barY, barW * hpFrac, barH)
end

-- Context-menu / manually assigned Juggernaut class: private self-only vitals.
-- The active Juggernaut round is handled by MODE:HUDPaint below for everyone.
hook.Add("HUDPaint", "ZB_JuggernautPrivateVitals", function()
    if isJuggernautRoundActive() then return end

    local ply = LocalPlayer()
    if not isJuggernautClass(ply) then return end

    drawJuggernautHealthMonitor(ply)
end)

function MODE:HUDPaint()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local elapsed = CurTime() - introStartTime
    if elapsed < 0 then
        drawJuggernautHealthMonitor()
        return
    end

    if elapsed > JUG_INTRO_DURATION then
        stopIntroSound()
        drawJuggernautHealthMonitor()
        return
    end

    if zb and zb.RemoveFade then
        zb.RemoveFade()
    end

    local sw, sh = ScrW(), ScrH()
    local timeLeft = JUG_INTRO_DURATION - elapsed
    local backgroundFade = math.min(timeLeft / 2.5, 1)
    local outFade = math.Clamp(timeLeft / 1.5, 0, 1)

    -- Background first, text second.
    surface.SetDrawColor(0, 0, 0, 255 * backgroundFade)
    surface.DrawRect(-1, -1, sw + 1, sh + 1)

    if MODE.RoundBeginSound then
        MODE.RoundBeginSound:ChangeVolume(outFade, 0)
    end

    MODE.CursorLerpX = Lerp(FrameTime() * 6, MODE.CursorLerpX or 0, (gui.MouseX() - sw * 0.5) / (sw * 0.5))
    MODE.CursorLerpY = Lerp(FrameTime() * 6, MODE.CursorLerpY or 0, (gui.MouseY() - sh * 0.5) / (sh * 0.5))

    local cursorReach = ScreenScale(7)
    local cursorOffsetX = math.Clamp(MODE.CursorLerpX, -1, 1) * cursorReach
    local cursorOffsetY = math.Clamp(MODE.CursorLerpY, -1, 1) * cursorReach

    local teamData = teams[introRole] or teams[0]
    local elements = {
        {
            text = "Juggernaut",
            font = "ZB_JuggernautHeader",
            color = Color(255, 255, 255),
            x = sw * 0.5,
            y = sh * 0.1,
            direction = "left",
            delay = 0,
            fadeIn = 0,
            parallax = 0.9,
            tilt = true
        },
        {
            text = "You are " .. teamData.name,
            font = "ZB_JuggernautMediumLarge",
            color = teamData.color1,
            x = sw * 0.5,
            y = sh * 0.5,
            direction = "right",
            delay = 0.15,
            fadeIn = 0.35,
            parallax = 1.1,
            tilt = true
        },
        {
            text = teamData.objective,
            font = "ZB_JuggernautMedium",
            color = teamData.color2,
            x = sw * 0.5,
            y = sh * 0.9,
            direction = "bottom",
            delay = 0.45,
            fadeIn = 0.35,
            parallax = 1.3,
            tilt = false
        }
    }

    local tilts = MODE.RoundTextTilts or {}

    for index, element in ipairs(elements) do
        local fadeIn = element.fadeIn or 0.35
        local appear

        -- Never begin the intro with a black-only screen. The main title is
        -- visible on the first frame; supporting text follows almost immediately.
        if fadeIn <= 0 then
            appear = elapsed >= element.delay and 1 or 0
        else
            appear = juggernaut_ease_out(math.Clamp((elapsed - element.delay) / fadeIn, 0, 1))
        end

        local alpha = 255 * appear * outFade

        if alpha > 1 then
            local slide = 1 - appear
            local x, y = element.x, element.y

            if element.direction == "left" then
                x = x - slide * ScreenScale(220)
            elseif element.direction == "right" then
                x = x + slide * ScreenScale(220)
            elseif element.direction == "bottom" then
                y = y + slide * ScreenScale(120)
            elseif element.direction == "top" then
                y = y - slide * ScreenScale(120)
            end

            x = x + cursorOffsetX * element.parallax
            y = y + cursorOffsetY * element.parallax

            local angle = element.tilt and ((tilts[index] or 3) * appear) or 0
            juggernaut_draw_text(element.text, element.font, x, y, element.color, alpha, angle)
        end
    end

    if hg and hg.PluvTown and hg.PluvTown.Active then
        local pluvAppear = juggernaut_ease_out(math.Clamp(elapsed, 0, 1))
        local pluvAlpha = pluvAppear * outFade

        surface.SetMaterial(hg.PluvTown.PluvMadness)
        surface.SetDrawColor(255, 255, 255, math.random(175, 255) * pluvAlpha / 2)
        surface.DrawTexturedRect(sw * 0.25 + cursorOffsetX, sh * 0.44 - ScreenScale(15) + cursorOffsetY, sw / 2, ScreenScale(30))

        draw.SimpleText(
            "SOMEWHERE IN PLUVTOWN",
            "ZB_ScrappersLarge",
            sw / 2 + cursorOffsetX,
            sh * 0.44 - ScreenScale(2) + cursorOffsetY,
            Color(0, 0, 0, 255 * pluvAlpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
end

-- The legacy Z-City results/player-list panel was intentionally removed.
-- Round end now uses Remorse's normal transition without opening a separate menu.
function MODE:EndRound()
    stopIntroSound()
    introStartTime = -math.huge
    MODE.DynamicFadeScreenEndTime = -math.huge
end

function MODE:RoundStart()
    -- The intro is started after GiveEquipment assigns each player's role.
end
