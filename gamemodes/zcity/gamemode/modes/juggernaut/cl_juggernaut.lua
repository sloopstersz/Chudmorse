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

function MODE:HUDPaint()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local elapsed = CurTime() - introStartTime
    if elapsed < 0 then return end

    if elapsed > JUG_INTRO_DURATION then
        stopIntroSound()
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
