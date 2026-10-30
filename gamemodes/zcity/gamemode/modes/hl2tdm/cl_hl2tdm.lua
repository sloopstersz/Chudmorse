local MODE = MODE
local voteEndTime, selectedVote = 0, 0
local voteResults = {0, 0, 0, 0}
local HL2TDMVoteMenu
local shownScenario = 0
local introTeam, introRole
local IntroStart, IntroDuration = 0, 10
local VoteFadeStart, VoteFadeEnd = 0, 0
local IntroMusic
local resultReceived = false
local function StopMusic()
    if IntroMusic then IntroMusic:Stop() IntroMusic = nil end
end
local function PlayMusic(path)
    StopMusic()
    IntroMusic = CreateSound(LocalPlayer(), path)
    IntroMusic:PlayEx(1.5, 100)
end
local tex_gradient_r = Material("vgui/gradient-r")
local tex_gradient_l = Material("vgui/gradient-l")
local tex_gradient_d = Material("vgui/gradient-d")
local function GetVoteTotal()
    return (voteResults[1] or 0) + (voteResults[2] or 0) + (voteResults[3] or 0) + (voteResults[4] or 0)
end

local function OpenVoteMenu()
    if IsValid(HL2TDMVoteMenu) then HL2TDMVoteMenu:Remove() end

    HL2TDMVoteMenu = vgui.Create("DFrame")
    HL2TDMVoteMenu:SetSize(ScrW(), ScrH())
    HL2TDMVoteMenu:SetPos(0, 0)
    HL2TDMVoteMenu:SetTitle("")
    HL2TDMVoteMenu:ShowCloseButton(false)
    HL2TDMVoteMenu:SetDraggable(false)
    HL2TDMVoteMenu:MakePopup()
    HL2TDMVoteMenu.OpenTime = CurTime()
    HL2TDMVoteMenu.Paint = function(self, w, h)
        local elapsed = CurTime() - (self.OpenTime or CurTime())
        local titleFrac = math.Clamp(elapsed / 0.4, 0, 1)
        local pulse = 0.5 + math.sin(CurTime() * 4) * 0.5
        local titleY = h * 0.12 - (1 - titleFrac) * 24
        local timerLeft = math.max(math.ceil(voteEndTime - CurTime()), 0)
        local timerColor = timerLeft <= 5 and Color(255, 120 + pulse * 80, 120 + pulse * 80) or Color(225, 225, 225)

        hg.DrawBlur(self, 5)
        draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 19, 165))
        surface.SetDrawColor(18, 18, 18, 65)
        surface.SetMaterial(tex_gradient_r)
        surface.DrawTexturedRect(0, 0, w, h)
        surface.SetMaterial(tex_gradient_l)
        surface.DrawTexturedRect(0, 0, w, h)
        surface.SetDrawColor(100, 100, 100, 35)
        surface.SetMaterial(tex_gradient_d)
        surface.DrawTexturedRect(0, 0, w, h)
        draw.SimpleText("HALF LIFE 2 TDM", "ZCity_Menu_Small", w * 0.5, titleY, Color(225, 225, 225, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Vote before the round starts", "ZCity_Menu_Settings_Small", w * 0.5, h * 0.16 - (1 - titleFrac) * 18, Color(200, 200, 200, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("TIME LEFT: " .. timerLeft, "ZCity_Menu_Small", w * 0.5, h * 0.90, timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    HL2TDMVoteMenu.Think = function()
        if CurTime() >= voteEndTime and IsValid(HL2TDMVoteMenu) then
            HL2TDMVoteMenu:Remove()
            HL2TDMVoteMenu = nil
        end
    end

    for i = 1, 4 do
        local data = MODE.Scenarios[i]
        local button = vgui.Create("DButton", HL2TDMVoteMenu)
        button:SetSize(ScrW() * 0.88, ScrH() * 0.13)
        button.TargetX = ScrW() * 0.06
        button.TargetY = ScrH() * (0.23 + (i - 1) * 0.145)
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
            net.Start("HL2TDMVote")
            net.WriteUInt(i, 3)
            net.SendToServer()
        end
    end
end

net.Receive("HL2TDMState", function()
    local voting = net.ReadBool()
    local deadline = net.ReadFloat()
    local selected = net.ReadUInt(3)
    for i = 1, 4 do voteResults[i] = net.ReadUInt(16) end
    local mode = CurrentRound()
    if not mode or mode.name ~= "hl2tdm" then return end
    if voting then
        if deadline ~= voteEndTime then
            selectedVote, shownScenario = 0, 0
            IntroStart, VoteFadeStart, VoteFadeEnd = 0, 0, 0
            introTeam, introRole = nil, nil
            resultReceived = false
            PlayMusic("rem_track1.mp3")
        end
        voteEndTime = deadline
        if not IsValid(HL2TDMVoteMenu) and CurTime() < deadline then
            zb.RemoveFade()
            OpenVoteMenu()
        end
    else
        if IsValid(HL2TDMVoteMenu) then HL2TDMVoteMenu:Remove() end
        -- State is also sent on round end / joining. Only a live vote result starts the transition.
        if not resultReceived and voteEndTime == deadline and selected > 0 and zb.ROUND_STATE ~= 2 then
            resultReceived = true
            shownScenario = selected
            if IntroMusic then IntroMusic:ChangeVolume(0, 3) end
            VoteFadeStart, VoteFadeEnd = CurTime(), CurTime() + 3
            surface.PlaySound("buttons/combine_button1.wav")
        end
    end
end)

net.Receive("HL2TDMIntro", function()
    local scenario, side, role = net.ReadUInt(3), net.ReadUInt(1), net.ReadString()
    local mode = CurrentRound()
    if not mode or mode.name ~= "hl2tdm" then return end
    shownScenario, introTeam, introRole = scenario, side, role
    if IsValid(HL2TDMVoteMenu) then HL2TDMVoteMenu:Remove() end
    IntroStart = CurTime()
    VoteFadeEnd = 0
    PlayMusic("rem_track2.mp3")
    MODE.RoundTextTilts = {}
    for i = 1, 64 do MODE.RoundTextTilts[i] = math.random() < 0.5 and 3 or -3 end
    MODE.CursorLerpX, MODE.CursorLerpY = 0, 0
    zb.RemoveFade()
end)

hook.Add("Think", "HL2TDMIntroCleanup", function()
    local mode = CurrentRound()
    if not mode or mode.name ~= "hl2tdm" or zb.ROUND_STATE == 2 then
        if IsValid(HL2TDMVoteMenu) then HL2TDMVoteMenu:Remove() end
        StopMusic()
        IntroStart, VoteFadeStart, VoteFadeEnd = 0, 0, 0
        return
    end
    if IntroMusic and IntroStart > 0 then
        local elapsed = CurTime() - IntroStart
        if elapsed > IntroDuration then StopMusic() return end
        local fade = math.Clamp(elapsed / 1.25, 0, 1) * math.Clamp((IntroDuration - elapsed) / 4, 0, 1)
        IntroMusic:ChangeVolume(math.min(fade * 1.5, 1.5), 0)
    end
end)
local function riot_ease_out(x)
    return 1 - (1 - x) ^ 3
end

local function riot_draw_text(text, fontname, x, y, r, g, b, a, ang, xalign, yalign)
    local base = Matrix()
    base:Translate(Vector(x, y, 0))
    base:Rotate(Angle(0, ang, 0))
    base:Translate(Vector(-x, -y, 0))

    cam.PushModelMatrix(base)
        draw.SimpleText(text, fontname, x, y, Color(r, g, b, a), xalign, yalign)
    cam.PopModelMatrix()
end

function MODE:RenderScreenspaceEffects()
    local ct = CurTime()

    if VoteFadeEnd > ct then
        local frac = math.Clamp((ct - VoteFadeStart) / math.max(VoteFadeEnd - VoteFadeStart, 0.001), 0, 1)
        surface.SetDrawColor(0, 0, 0, 255 * frac)
        surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
        return
    end

    if IntroStart <= 0 then return end

    local introTime = ct - IntroStart
    if introTime > IntroDuration then return end

    zb.RemoveFade()

    local introFade = math.Clamp(introTime / 1.25, 0, 1)
    local outFade = math.Clamp((IntroDuration - introTime) / 4, 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * introFade * outFade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

function MODE:HUDPaint()
    if not IntroStart or IntroStart <= 0 then return end
    local lply = LocalPlayer()
    if not IsValid(lply) or lply:Team() == TEAM_SPECTATOR then return end
    local sw, sh = ScrW(), ScrH()

    local t = CurTime() - IntroStart
    if t > IntroDuration then return end

    zb.RemoveFade()

    local intro_fade = math.Clamp(t / 1.25, 0, 1)
    local out_fade = math.Clamp((IntroDuration - t) / 4, 0, 1)
    local team_ = introTeam or lply:Team()
    local scenario = self.Scenarios[shownScenario] or self.Scenarios[3]
    local teamData = {
        name = introRole or (team_ == 1 and "Combine" or scenario.opposition),
        color1 = team_ == 1 and Color(80, 190, 230) or Color(230, 145, 60),
        objective = team_ == 1 and ("Eliminate the " .. scenario.opposition .. " and survive.")
            or ("Defeat " .. (shownScenario == 2 and "Civil Protection" or "the Combine") .. " and survive.")
    }
    local intensityData = self.Scenarios[shownScenario] or self.Scenarios[3]
    local ColorRole = teamData.color1


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

    add("Half-Life 2 TDM", "ZB_HomicideHeader", Color(255, 255, 255), sw * 0.5, sh * 0.1, "left", 0, 0.9)
    add(intensityData.name, "ZB_HomicideMediumLarge", Color(255, 255, 255), sw * 0.5, sh * 0.2, "left", 0.25, 0.95)
    add(intensityData.description, "ZCity_Menu_Settings_Small", Color(225, 225, 225), sw * 0.5, sh * 0.26, "left", 0.45, 1, true)
    add("You are " .. (introRole or teamData.name), "ZB_HomicideMediumLarge", ColorRole, sw * 0.5, sh * 0.5, "right", 0.7, 1.1)
    add(teamData.objective, "ZB_HomicideMedium", Color(255, 255, 255), sw * 0.5, sh * 0.9, "bottom", 1.4, 1.3, true)

    local tilts = MODE.RoundTextTilts or {}
    for i, el in ipairs(elements) do
        local appear = riot_ease_out(math.Clamp((t - el.delay) / 2.0, 0, 1))
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
            riot_draw_text(el.text, el.font, x, y, el.r, el.g, el.b, a, tilt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

	if hg.PluvTown.Active then
        local pluv_appear = riot_ease_out(math.Clamp(t / 1.0, 0, 1))
        local pluv_a = pluv_appear * out_fade

        surface.SetMaterial(hg.PluvTown.PluvMadness)
        surface.SetDrawColor(255, 255, 255, math.random(175, 255) * pluv_a / 2)
        surface.DrawTexturedRect(sw * 0.25 + cox, sh * 0.44 - ScreenScale(15) + coy, sw / 2, ScreenScale(30))

        draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2 + cox, sh * 0.44 - ScreenScale(2) + coy, Color(0, 0, 0, 255 * pluv_a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end


function MODE:RoundStart()
    if IsValid(HL2TDMVoteMenu) then HL2TDMVoteMenu:Remove() end
    -- The role intro began at spawn; keep it running through the round-start event.
    zb.RemoveFade()
end
