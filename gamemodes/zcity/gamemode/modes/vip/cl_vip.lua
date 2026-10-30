local MODE = MODE
local function Fonts()
    surface.CreateFont("ChudVIPTitle", {font = "Trebuchet MS", size = math.max(32, ScreenScale(28)), weight = 1000, antialias = true})
    surface.CreateFont("ChudVIPTimer", {font = "Courier Prime", size = ScreenScale(9), weight = 650, antialias = true, extended = true})
    surface.CreateFont("ChudVIPText", {font = "Verily Serif Mono", size = math.max(16, ScreenScale(6)), weight = 400, extended = true})
end
Fonts()
hook.Add("OnScreenSizeChanged", "ChudVIPFonts", Fonts)
local white, red, blue = Color(225, 225, 225), Color(200, 45, 45), Color(60, 130, 255)
local function Text(text, font, x, y, color)
    draw.SimpleTextOutlined(text, font, x, y, color or white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
end

function MODE:HUDPaint()
    if self.DrawDeploymentIntro and self:DrawDeploymentIntro() then return end
    if zb.ROUND_STATE == 0 then return end
    local x, y = ScrW() / 2, ScrH() * 0.05
    local step = math.max(24, ScreenScale(10))
    local endAt = GetGlobalFloat("ChudVIPEndAt", 0)
    local remaining = endAt > 0 and math.max(0, math.ceil(endAt - CurTime())) or self.ROUND_TIME
    local winner = GetGlobalInt("ChudVIPWinner", 0)
    if zb.ROUND_STATE == 3 then
        Text(winner == 1 and "THE VIP IS SAFE" or winner == 2 and "THE ATTACKERS WIN" or "VIP ESCORT ROUND CANCELLED", "ChudVIPTimer", x, y)
        return
    end
    Text(string.format("%02d:%02d  VIP ESCORT", math.floor(remaining / 60), remaining % 60), "ChudVIPTimer", x, y, remaining <= 60 and red or white)
    Text("VIP: " .. GetGlobalString("ChudVIPVICName", "Unassigned"), "ChudVIPText", x, y + step, blue)
    local stage = math.min(GetGlobalInt("ChudVIPStage", 1), 3)
    Text("LOCATION " .. stage .. " / 3", "ChudVIPText", x, y + step * 2)
    local holdEnd = GetGlobalFloat("ChudVIPHoldEnd", 0)
    if GetGlobalBool("ChudVIPContested", false) then
        Text("CONTESTED — CLEAR THE AREA", "ChudVIPText", x, y + step * 3, red)
    elseif holdEnd > 0 then
        local progress = math.Clamp(1 - (holdEnd - CurTime()) / self.HoldTime, 0, 1)
        local width = math.min(300, ScrW() * 0.4)
        surface.SetDrawColor(15, 15, 18, 220)
        surface.DrawRect(x - width / 2, y + step * 3, width, 8)
        surface.SetDrawColor(blue)
        surface.DrawRect(x - width / 2, y + step * 3, width * progress, 8)
        Text("HOLD: " .. math.max(0, math.ceil(holdEnd - CurTime())) .. "s", "ChudVIPText", x, y + step * 3 + 12)
    end
    if GetGlobalBool("ChudVIPHasObjective", false) then
        local point = GetGlobalVector("ChudVIPObjective", vector_origin)
        local screen = (point + Vector(0, 0, 48)):ToScreen()
        if screen.visible then
            Text("LOCATION " .. stage, "ChudVIPText", math.Clamp(screen.x, 90, ScrW() - 90), math.Clamp(screen.y, ScrH() * 0.3, ScrH() - 70), blue)
        end
    end
end

function MODE:PostDrawTranslucentRenderables(depth, skybox)
    if depth or skybox or zb.ROUND_STATE ~= 1 or not GetGlobalBool("ChudVIPHasObjective", false) then return end
    render.DrawWireframeSphere(GetGlobalVector("ChudVIPObjective", vector_origin), self.HoldRadius, 32, 8, Color(60, 130, 255, 150), false)
end


