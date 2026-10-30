local Z = ZZInfection
local paranoiaUntil = 0
net.Receive("ZZInfectionSymptom", function()
    net.ReadUInt(3)
    if not Z.Active() then return end
    paranoiaUntil = CurTime() + 4
    surface.PlaySound("ambient/levels/citadel/strange_talk1.wav")
end)

-- Native organism effects handle blur, fever, seizures and disorientation.
hook.Remove("RenderScreenspaceEffects", "ZZInfectionDisorientation")
local infectionEdges = Material("zzombies/infection_edges.png", "smooth")
hook.Add("HUDPaintBackground", "ZZInfectionEdges", function()
    if not Z.Active() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or ZZIsZombie(ply) then return end
    local intensity = math.Clamp(ply:GetNWFloat("ZZInfectionOverlay", 0), 0, 1)
    if intensity <= 0 or infectionEdges:IsError() then return end
    surface.SetMaterial(infectionEdges)
    surface.SetDrawColor(210, 185, 165, intensity * 210)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)

hook.Add("HUDPaint", "ZZInfectionHUD", function()
    if not Z.Active() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local red = Color(210, 55, 45)
    if ZZIsZombie(ply) then
        draw.SimpleText("ZOMBIE POINTS: " .. ply:GetNWInt("ZZZombiePoints", 0), "DermaLarge", 24, ScrH() * 0.72, red)
        local controls = Z.BiteOnly(ply) and "LMB: bite" or (Z.CanBite(ply) and "LMB: claws | R + LMB: bite" or "LMB: claws")
        draw.SimpleText(controls .. "   |   Hold E on a human body: consume", "DermaDefaultBold", 24, ScrH() * 0.72 + 34, color_white)
        local progress = ply:GetNWFloat("ZZConsumeProgress", 0)
        if progress > 0 then
            local w, h = 300, 12
            surface.SetDrawColor(20, 20, 20, 220) surface.DrawRect(ScrW() / 2 - w / 2, ScrH() * 0.8, w, h)
            surface.SetDrawColor(red) surface.DrawRect(ScrW() / 2 - w / 2, ScrH() * 0.8, w * progress, h)
            draw.SimpleText("CONSUMING — " .. ply:GetNWInt("ZZConsumeCount", 1) .. " eater(s)", "DermaDefaultBold",
                ScrW() / 2, ScrH() * 0.8 - 20, color_white, TEXT_ALIGN_CENTER)
        end
    else
        if ply:GetNWInt("ZZConsumeCount", 0) >= 2 then
            draw.SimpleText("You are pinned down!", "DermaLarge", ScrW() / 2, ScrH() * 0.8, red, TEXT_ALIGN_CENTER)
        end
        if paranoiaUntil > CurTime() and ply:GetNWFloat("ZZInfectionSymptoms", 0) > 0 then
            draw.SimpleText("Something is behind you...", "DermaLarge", ScrW() * 0.65, ScrH() * 0.4, Color(170, 170, 170, 150))
        end
    end
end)
