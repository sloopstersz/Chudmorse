MODE.name = "president"
local MODE = MODE

surface.CreateFont("PresidentHUDXL", {
    font = "Roboto",
    size = 42,
    weight = 900,
    extended = true
})

surface.CreateFont("PresidentHUDLarge", {
    font = "Roboto",
    size = 28,
    weight = 800,
    extended = true
})

surface.CreateFont("PresidentHUDMedium", {
    font = "Roboto",
    size = 22,
    weight = 700,
    extended = true
})

surface.CreateFont("PresidentHUDSmall", {
    font = "Roboto",
    size = 18,
    weight = 600,
    extended = true
})

-- Match the working Juggernaut/Homicide intro typography exactly.
-- This uses the same configurable hg_font value, falling back to Lora.
local function president_intro_font()
    local convar = GetConVar("hg_font")
    local value = convar and convar:GetString() or ""
    return value ~= "" and value or "Lora"
end

surface.CreateFont("PresidentHUDIntroTitle", {
    font = president_intro_font(),
    size = ScreenScale(45),
    weight = 400,
    antialias = true
})

surface.CreateFont("PresidentHUDIntroRole", {
    font = president_intro_font(),
    size = ScreenScale(25),
    weight = 400,
    antialias = true
})

surface.CreateFont("PresidentHUDIntroObjective", {
    font = president_intro_font(),
    size = ScreenScale(15),
    weight = 400,
    antialias = true
})

surface.CreateFont("PresidentHUDIntroSmall", {
    font = president_intro_font(),
    size = ScreenScale(15),
    weight = 400,
    antialias = true
})

local PRESIDENT_COLOR = Color(0, 255, 65)
local BODYGUARD_COLOR = Color(0, 100, 255)
local CITIZEN_COLOR = Color(255, 60, 60)
local TASK_COLOR = Color(255, 210, 40)

local START_SOUND_PATH = "zcity_president/president_start.mp3"
local PRESIDENT_INTRO_DURATION = 9.6

local taskData = nil
local introRoleInfo = nil
local introStartTime = -math.huge
local introEndTime = -math.huge
local introCleanupUntil = -math.huge
local introSoundRoundStamp = -1

local glowMat = Material("sprites/glow04_noz")


local function StopIntroSound()
    if MODE.RoundBeginSound then
        MODE.RoundBeginSound:Stop()
        MODE.RoundBeginSound = nil
    end
end

-- The core round system also uses Player:ScreenFade, which is separate from
-- the removable ZB_ScreenFade hook. Clear both so the VIC intro cannot leave
-- an engine-level black screen behind after its HUD card disappears.
local function ClearPresidentBlackFade()
    if zb and zb.RemoveFade then
        zb.RemoveFade()
    end

    local ply = LocalPlayer()
    if IsValid(ply) then
        ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 0.2, 0)
    end
end

local function PresidentEaseOut(x)
    return 1 - (1 - x) ^ 3
end

local function PresidentDrawIntroText(text, fontname, x, y, color, alpha, angle)
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
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    cam.PopModelMatrix()
end

local function PlayIntroSoundOnce()
    local stamp = zb.ROUND_START or 0
    if introSoundRoundStamp == stamp then return end

    introSoundRoundStamp = stamp
    StopIntroSound()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    MODE.RoundBeginSound = CreateSound(ply, START_SOUND_PATH)
    if MODE.RoundBeginSound then
        MODE.RoundBeginSound:PlayEx(1, 100)
    end
end

local function GetRoleInfo(ply)
    if not IsValid(ply) then
        return {
            name = "Unknown",
            color = color_white,
            objective = ""
        }
    end

    local tasks = MODE.GetTaskInfo()

    if MODE.IsPresident(ply) then
        local objective

        if MODE.GetTasksEnabled() and tasks.shouldend and tasks.need > 0 then
            objective = "Survive and complete the required tasks."
        elseif MODE.GetTasksEnabled() and tasks.need > 0 then
            objective = "Survive until the round ends or complete tasks."
        else
            objective = "Survive until the round ends."
        end

        return {
            name = "VIC (Very Important Chud)",
            color = PRESIDENT_COLOR,
            objective = objective
        }
    end

    if MODE.IsBodyguard(ply) then
        return {
            name = "Chud Protector",
            color = BODYGUARD_COLOR,
            objective = "Protect the VIC at all costs."
        }
    end

    return {
        name = "Angry Chud",
        color = CITIZEN_COLOR,
        objective = "Kill the VIC."
    }
end

local function GetImmediateIntroRoleInfo()
    local lply = LocalPlayer()
    if not IsValid(lply) then return nil end
    if zb.CROUND ~= MODE.name then return nil end

    if MODE.IsPresident(lply) then
        return {
            name = "VIC (Very Important Chud)",
            color = PRESIDENT_COLOR,
            objective = GetRoleInfo(lply).objective
        }
    end

    if MODE.IsBodyguard and MODE.IsBodyguard(lply) then
        return {
            name = "Chud Protector",
            color = BODYGUARD_COLOR,
            objective = "Protect the VIC at all costs."
        }
    end

    if lply:Team() == 1 then
        return {
            name = "Chud Protector",
            color = BODYGUARD_COLOR,
            objective = "Protect the VIC at all costs."
        }
    end

    if lply:Team() == 0 then
        return {
            name = "Angry Chud",
            color = CITIZEN_COLOR,
            objective = "Kill the VIC."
        }
    end

    return nil
end

local function GetResolvedIntroRoleInfo()
    local fallback = GetImmediateIntroRoleInfo()

    if introRoleInfo and introRoleInfo.name and introRoleInfo.name ~= "" then
        return {
            name = introRoleInfo.name,
            color = introRoleInfo.color or (fallback and fallback.color or color_white),
            objective = (introRoleInfo.objective and introRoleInfo.objective ~= "")
                and introRoleInfo.objective
                or (fallback and fallback.objective or "Synchronizing objective...")
        }
    end

    if fallback then
        return fallback
    end

    return {
        name = "Loading Role",
        color = Color(255, 255, 255),
        objective = "Synchronizing round data..."
    }
end

local function GetIntroRoleLine(roleInfo)
    local name = roleInfo and roleInfo.name or "Unknown"

    if name == "Chud Protector" then
        return "You are the Chud Protector"
    elseif name == "Angry Chud" then
        return "You are an Angry Chud"
    elseif string.StartWith(name, "VIC") then
        return "You are the " .. name
    end

    return "You are " .. name
end

local function GetTaskText(task)
    if not task then return "No active task." end

    if task.kind == "stay" then
        return "Stay inside the marked area: " .. math.floor(task.progress or 0) .. "/" .. (task.staytime or 15) .. "s"
    elseif task.kind == "move" then
        return task.reachedA and "Reach point B." or "Reach point A first."
    elseif task.kind == "prop" then
        return "Move the highlighted prop into the marked area."
    end

    return "Unknown task."
end

local function DrawTextOutlined(text, font, x, y, color, ax, ay, outline)
    draw.SimpleTextOutlined(text, font, x, y, color, ax, ay, outline or 2, Color(0, 0, 0, 255))
end

local function DrawTaskBeacon(pos, radius, color, title, subtitle, opts)
    if not isvector(pos) then return end

    opts = opts or {}

    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    local drawSphere = opts.drawSphere ~= false
    local drawLine = opts.drawLine ~= false
    local showText = opts.showText ~= false
    local lineHeight = opts.lineHeight or 72
    local textHeight = opts.textHeight or (math.max(radius * 0.35, 18) + 18)

    cam.IgnoreZ(true)
        render.SetColorMaterial()

        if drawSphere and (radius or 0) > 0 then
            render.DrawWireframeSphere(pos, radius, 20, 20, color, true)
        end

        if drawLine then
            render.DrawLine(pos, pos + Vector(0, 0, lineHeight), color, true)
            render.SetMaterial(glowMat)
            render.DrawSprite(pos + Vector(0, 0, lineHeight), 24, 24, color)
        end
    cam.IgnoreZ(false)

    if not showText then return end

    local textPos = pos + Vector(0, 0, textHeight)
    local ang = Angle(0, lply:EyeAngles().y - 90, 90)
    local dist = lply:GetPos():Distance(textPos)
    local scale = math.Clamp(dist / 1200, 0.8, 2.2) * 0.09

    cam.Start3D2D(textPos, ang, scale)
        surface.SetDrawColor(0, 0, 0, 220)
        surface.DrawRect(-170, -26, 340, 54)

        surface.SetDrawColor(color.r, color.g, color.b, 255)
        surface.DrawOutlinedRect(-170, -26, 340, 54, 2)

        DrawTextOutlined(title or "", "PresidentHUDMedium", 0, -8, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
        DrawTextOutlined(subtitle or "", "PresidentHUDSmall", 0, 16, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
    cam.End3D2D()
end

-- Legacy Z-City round-results/player-list panel removed for Remorse compatibility.

net.Receive("president_intermission", function()
    StopIntroSound()
    introRoleInfo = nil
    introStartTime = -math.huge
    introEndTime = -math.huge
    introCleanupUntil = CurTime() + 1
    introSoundRoundStamp = -1
    MODE.DynamicFadeScreenEndTime = -math.huge

    ClearPresidentBlackFade()
end)

net.Receive("president_start", function()
    local roleName = net.ReadString()
    local objective = net.ReadString()
    local r = net.ReadUInt(8)
    local g = net.ReadUInt(8)
    local b = net.ReadUInt(8)
    local restartIntro = net.ReadBool()

    introRoleInfo = {
        name = roleName,
        objective = objective,
        color = Color(r, g, b)
    }

    if restartIntro then
        introStartTime = CurTime()
        introEndTime = CurTime() + PRESIDENT_INTRO_DURATION
        -- Remorse's global ZB_ScreenFade can be installed by a delayed timer.
        -- Keep clearing it for a short period after this intro finishes so it
        -- cannot leave the player's screen black after the VIC card disappears.
        introCleanupUntil = introEndTime + 4
        MODE.DynamicFadeScreenEndTime = introEndTime
        PlayIntroSoundOnce()
    else
        -- Updating the VIC objective must not restart or extend the visual intro.
        -- It only updates the already-resolved role data.
    end

    ClearPresidentBlackFade()
end)

net.Receive("president_task", function()
    local hasTask = net.ReadBool()

    if hasTask then
        taskData = net.ReadTable()
    else
        taskData = nil
    end
end)

net.Receive("president_end", function()
    StopIntroSound()

    local president = net.ReadEntity()
    local presidentSideWon = net.ReadBool()
    local byTasks = net.ReadBool()

    if presidentSideWon then
        if byTasks then
            chat.AddText(PRESIDENT_COLOR, "President side wins by completing the tasks!")
        else
            chat.AddText(PRESIDENT_COLOR, "President side wins!")
        end
    else
        chat.AddText(CITIZEN_COLOR, "Angry Chuds win!")
    end
end)
local PRESIDENT_UNIT_TO_METER = 0.0254

local function GetPresidentTrackedEntity(ent)
    if not IsValid(ent) then return nil end

    if ent:IsPlayer() then
        local tracked = nil

        if hg and hg.GetCurrentCharacter then
            tracked = hg.GetCurrentCharacter(ent)
        end

        if not IsValid(tracked) and hg and hg.RagdollOwner then
            local rag = hg.RagdollOwner(ent)
            if IsValid(rag) and rag ~= ent then
                tracked = rag
            end
        end

        if IsValid(tracked) then
            return tracked
        end
    end

    return ent
end

local function GetPresidentMarkerPos(ent)
    local tracked = GetPresidentTrackedEntity(ent)
    if not IsValid(tracked) then return nil end

    local pos = tracked:LocalToWorld(tracked:OBBCenter())

    if tracked:IsPlayer() then
        pos = pos + Vector(0, 0, 6)
    end

    return pos, tracked
end

local function DrawPresidentDiamond(x, y, size, col)
    draw.NoTexture()

    surface.SetDrawColor(0, 0, 0, 220)
    surface.DrawPoly({
        { x = x,            y = y - size - 2 },
        { x = x + size + 2, y = y           },
        { x = x,            y = y + size + 2 },
        { x = x - size - 2, y = y           }
    })

    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawPoly({
        { x = x,          y = y - size },
        { x = x + size,   y = y        },
        { x = x,          y = y + size },
        { x = x - size,   y = y        }
    })
end

local function DrawPresidentMarker(lply, ent, col, label, yOffset)
    if not IsValid(lply) then return end
    if not IsValid(ent) then return end

    local pos, tracked = GetPresidentMarkerPos(ent)
    if not pos then return end

    if ent == lply or tracked == lply then return end

    if yOffset then
        pos = pos + Vector(0, 0, yOffset)
    end

    local scr = pos:ToScreen()
    if not scr.visible then return end

    local dist = lply:GetPos():Distance(pos)
    local size = math.Clamp(22 - dist * 0.0025, 7, 16)
    local meters = math.max(1, math.Round(dist * PRESIDENT_UNIT_TO_METER))
    local distText = "~" .. meters .. "m"

    DrawPresidentDiamond(scr.x, scr.y, size, col)

    if label and label ~= "" then
        draw.SimpleText(
            label,
            "DermaDefaultBold",
            scr.x + 1,
            scr.y + size + 6 + 1,
            Color(0, 0, 0, 220),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )

        draw.SimpleText(
            label,
            "DermaDefaultBold",
            scr.x,
            scr.y + size + 6,
            Color(255, 255, 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )

        draw.SimpleText(
            distText,
            "DermaDefaultBold",
            scr.x + 1,
            scr.y + size + 20 + 1,
            Color(0, 0, 0, 220),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )

        draw.SimpleText(
            distText,
            "DermaDefaultBold",
            scr.x,
            scr.y + size + 20,
            Color(255, 255, 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
    else
        draw.SimpleText(
            distText,
            "DermaDefaultBold",
            scr.x + 1,
            scr.y + size + 8 + 1,
            Color(0, 0, 0, 220),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )

        draw.SimpleText(
            distText,
            "DermaDefaultBold",
            scr.x,
            scr.y + size + 8,
            Color(255, 255, 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
    end
end

hook.Add("HUDPaint", "president_wall_markers", function()
    if zb.CROUND ~= MODE.name then return end
    if zb.ROUND_STATE ~= 1 then return end

    local lply = LocalPlayer()
    if not IsValid(lply) then return end
    if lply:Team() == TEAM_SPECTATOR then return end

    if MODE.GetHaloEnabled() and (MODE.IsBodyguard(lply) or MODE.IsPresident(lply)) then
        local renderTargets = table.Copy(MODE.GetPresidentRenderEntities() or {})

        if #renderTargets <= 0 then
            local president = MODE.GetPresident and MODE.GetPresident() or nil
            if IsValid(president) then
                renderTargets[#renderTargets + 1] = president
            end
        end

        local seen = {}

        for _, ent in ipairs(renderTargets) do
            if IsValid(ent) and ent ~= lply and not seen[ent] then
                seen[ent] = true
                DrawPresidentMarker(lply, ent, PRESIDENT_COLOR, "VIC")
            end
        end
    end

    if MODE.IsPresident(lply) and taskData and taskData.kind == "prop" and IsValid(taskData.targetEnt) then
        DrawPresidentMarker(lply, taskData.targetEnt, TASK_COLOR, "PROP")
    end
end)


hook.Add("PostDrawTranslucentRenderables", "president_task_render", function(bDepth, bSkybox, isDraw3DSkybox)
    if bSkybox or isDraw3DSkybox then return end
    if zb.CROUND ~= MODE.name then return end
    if zb.ROUND_STATE ~= 1 then return end
    if not taskData then return end

    local lply = LocalPlayer()
    if not IsValid(lply) or not MODE.IsPresident(lply) then return end

    if taskData.kind == "stay" and isvector(taskData.pos) then
        DrawTaskBeacon(
            taskData.pos,
            taskData.radius or 300,
            Color(40, 255, 100),
            "Stay Zone",
            math.floor(taskData.progress or 0) .. "/" .. (taskData.staytime or 15) .. " sec",
            {
                textHeight = math.max((taskData.radius or 300) * 0.30, 18) + 14
            }
        )
    elseif taskData.kind == "move" then
        if not taskData.reachedA and isvector(taskData.posA) then
            DrawTaskBeacon(
                taskData.posA,
                taskData.radius or 200,
                Color(255, 180, 60),
                nil,
                nil,
                {
                    drawLine = false,
                    showText = false
                }
            )
        elseif taskData.reachedA and isvector(taskData.posB) then
            DrawTaskBeacon(
                taskData.posB,
                taskData.radius or 200,
                Color(40, 255, 100),
                nil,
                nil,
                {
                    drawLine = false,
                    showText = false
                }
            )
        end
    elseif taskData.kind == "prop" then
        if isvector(taskData.pos) then
            DrawTaskBeacon(
                taskData.pos,
                taskData.radius or 220,
                TASK_COLOR,
                "Drop Zone",
                "Bring the highlighted prop here",
                {
                    textHeight = math.max((taskData.radius or 220) * 0.30, 18) + 14
                }
            )
        end

        if IsValid(taskData.targetEnt) then
            local propPos = taskData.targetEnt:GetPos() + Vector(0, 0, 18)

            DrawTaskBeacon(
                propPos,
                0,
                TASK_COLOR,
                "Target Prop",
                "Drag this object",
                {
                    drawSphere = false,
                    drawLine = false,
                    showText = true,
                    textHeight = 20
                }
            )
        end
    end
end)

-- Intro fade/background is handled entirely in HUDPaint so it can never
-- render over the VIC/role text.
function MODE:RenderScreenspaceEffects()
end

function MODE:HUDPaint()
    if zb.CROUND ~= MODE.name then return end

    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    local sw, sh = ScrW(), ScrH()

    -- ZB_ScreenFade is created from a delayed timer in the core round system.
    -- Continue removing it after the VIC intro ends so a late timer cannot put
    -- a permanent black layer back over the player's view.
    if introCleanupUntil > CurTime() and zb and zb.RemoveFade then
        zb.RemoveFade()
    end

    local introActive = introEndTime > CurTime()
    if introActive then
        if zb.RemoveFade then
            zb.RemoveFade()
        end

        local roleInfo = GetResolvedIntroRoleInfo()
        local col = roleInfo.color or color_white
        local elapsed = CurTime() - introStartTime
        local timeLeft = introEndTime - CurTime()
        local backgroundFade = math.min(math.max(timeLeft, 0) / 2.5, 1)
        local outFade = math.Clamp(timeLeft / 1.5, 0, 1)

        -- Background first, then all intro text. Keeping both in this HUD pass
        -- prevents the normal round fade from covering the VIC intro.
        surface.SetDrawColor(0, 0, 0, 255 * backgroundFade)
        surface.DrawRect(-1, -1, sw + 1, sh + 1)

        if MODE.RoundBeginSound then
            MODE.RoundBeginSound:ChangeVolume(outFade, 0)
        end

        MODE.PresidentCursorLerpX = Lerp(FrameTime() * 6, MODE.PresidentCursorLerpX or 0, (gui.MouseX() - sw * 0.5) / (sw * 0.5))
        MODE.PresidentCursorLerpY = Lerp(FrameTime() * 6, MODE.PresidentCursorLerpY or 0, (gui.MouseY() - sh * 0.5) / (sh * 0.5))

        local cursorReach = ScreenScale(7)
        local cursorOffsetX = math.Clamp(MODE.PresidentCursorLerpX or 0, -1, 1) * cursorReach
        local cursorOffsetY = math.Clamp(MODE.PresidentCursorLerpY or 0, -1, 1) * cursorReach

        MODE.PresidentTextTilts = MODE.PresidentTextTilts or { -3, 3, -2 }

        local elements = {
            {
                text = "VIC",
                font = "PresidentHUDIntroTitle",
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
                text = GetIntroRoleLine(roleInfo),
                font = "PresidentHUDIntroRole",
                color = col,
                x = sw * 0.5,
                y = sh * 0.5,
                direction = "right",
                delay = 0.15,
                fadeIn = 0.35,
                parallax = 1.1,
                tilt = true
            },
            {
                text = roleInfo.objective or "",
                font = "PresidentHUDIntroObjective",
                color = Color(255, 255, 255),
                x = sw * 0.5,
                y = sh * 0.9,
                direction = "bottom",
                delay = 0.45,
                fadeIn = 0.35,
                parallax = 1.3,
                tilt = false
            }
        }

        for index, element in ipairs(elements) do
            local fadeIn = element.fadeIn or 0.35
            local appear

            if fadeIn <= 0 then
                appear = elapsed >= element.delay and 1 or 0
            else
                appear = PresidentEaseOut(math.Clamp((elapsed - element.delay) / fadeIn, 0, 1))
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
                end

                x = x + cursorOffsetX * element.parallax
                y = y + cursorOffsetY * element.parallax

                local angle = element.tilt and ((MODE.PresidentTextTilts[index] or 3) * appear) or 0
                PresidentDrawIntroText(element.text, element.font, x, y, element.color, alpha, angle)
            end
        end

        return
    elseif introEndTime > -math.huge then
        -- Hard-finalize the intro exactly once. This clears our state and any
        -- external fade hook that may have been scheduled during round start.
        StopIntroSound()
        introEndTime = -math.huge
        introStartTime = -math.huge
        MODE.DynamicFadeScreenEndTime = -math.huge

        ClearPresidentBlackFade()
    elseif MODE.RoundBeginSound then
        StopIntroSound()
    end

    local role = GetRoleInfo(lply)
    local president = MODE.GetPresident()
    local presidentAlive = IsValid(president) and president:Alive() and (not president.organism or not president.organism.incapacitated)
    local tasks = MODE.GetTaskInfo()
    local roundTime = MODE.ROUND_TIME or 0
    local timeLeft = math.max(math.ceil((zb.ROUND_START or CurTime()) + roundTime - CurTime()), 0)

    DrawTextOutlined(
        string.FormattedTime(timeLeft, "%02i:%02i"),
        "PresidentHUDSmall",
        sw * 0.5,
        16,
        Color(255, 255, 255),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1
    )

    surface.SetDrawColor(0, 0, 0, 190)
    surface.DrawRect(sw * 0.5 - 260, 32, 520, 92)

    surface.SetDrawColor(role.color.r, role.color.g, role.color.b, 255)
    surface.DrawOutlinedRect(sw * 0.5 - 260, 32, 520, 92, 2)

    DrawTextOutlined(role.name, "PresidentHUDLarge", sw * 0.5, 56, role.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)

    local presidentLine
    if presidentAlive and IsValid(president) then
        presidentLine = "President: " .. president:Name()
    else
        presidentLine = "President: DEAD / MISSING"
    end

    DrawTextOutlined(
        presidentLine,
        "PresidentHUDSmall",
        sw * 0.5,
        84,
        presidentAlive and PRESIDENT_COLOR or CITIZEN_COLOR,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1
    )

    DrawTextOutlined(
        role.objective,
        "PresidentHUDSmall",
        sw * 0.5,
        108,
        Color(235, 235, 235),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1
    )

    if MODE.IsPresident(lply) and MODE.GetTasksEnabled() then
        surface.SetDrawColor(0, 0, 0, 190)
        surface.DrawRect(sw * 0.5 - 320, sh - 150, 640, 98)

        surface.SetDrawColor(TASK_COLOR.r, TASK_COLOR.g, TASK_COLOR.b, 255)
        surface.DrawOutlinedRect(sw * 0.5 - 320, sh - 150, 640, 98, 2)

        local modeText
        if tasks.need <= 0 then
            modeText = "Tasks unavailable on this map this round."
        elseif tasks.shouldend then
            modeText = "Task mode: REQUIRED"
        else
            modeText = "Task mode: OPTIONAL"
        end

        DrawTextOutlined(modeText, "PresidentHUDMedium", sw * 0.5, sh - 124, TASK_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
        DrawTextOutlined("Progress: " .. tasks.done .. "/" .. tasks.need, "PresidentHUDSmall", sw * 0.5, sh - 96, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
        DrawTextOutlined(GetTaskText(taskData), "PresidentHUDSmall", sw * 0.5, sh - 70, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
    end
end

function MODE:RoundStart()
    taskData = nil
    introRoleInfo = nil
    introStartTime = -math.huge
    introEndTime = -math.huge
    introCleanupUntil = -math.huge
    introSoundRoundStamp = -1
    MODE.PresidentCursorLerpX = 0
    MODE.PresidentCursorLerpY = 0
    MODE.PresidentTextTilts = {
        (math.random() < 0.5) and 3 or -3,
        (math.random() < 0.5) and 3 or -3,
        (math.random() < 0.5) and 3 or -3
    }

    -- The actual intro starts only when president_start arrives from the
    -- server, after VIC/Chud Protector/Angry Chud roles are assigned.
    ClearPresidentBlackFade()
end
