if SERVER then AddCSLuaFile() end
local function Zombie(ply)
    return IsValid(ply) and ply:Alive() and ZZIsZombie and ZZIsZombie(ply)
end
if SERVER then
    util.AddNetworkString("ZZPropHealth")
    function ZZShowPropHealth(ply, ent, health, maximum)
        if not Zombie(ply) or not IsValid(ent) or maximum <= 0 then return end
        net.Start("ZZPropHealth")
        net.WriteFloat(math.Clamp(health / maximum, 0, 1))
        net.Send(ply)
    end
    function ZZTrackPropHit(ply, ent)
        if not Zombie(ply) or not IsValid(ent) or ent:IsWorld() or ent:IsPlayer()
            or ent:IsNPC() or ent:IsRagdoll() or (hgIsDoor and hgIsDoor(ent)) then return end
        local before = ent:Health()
        if before <= 0 then return end -- No invented HP for indestructible scenery.
        ent.ZZPropMaxHealth = math.max(ent.ZZPropMaxHealth or 0, ent:GetMaxHealth(), before)
        local maximum = ent.ZZPropMaxHealth
        timer.Simple(0, function()
            if not Zombie(ply) then return end
            local health = IsValid(ent) and ent:Health() or 0
            net.Start("ZZPropHealth")
            net.WriteFloat(math.Clamp(health / maximum, 0, 1))
            net.Send(ply)
        end)
    end
    return
end
local amount, expires = 0, 0
net.Receive("ZZPropHealth", function()
    amount = math.Clamp(net.ReadFloat(), 0, 1)
    expires = CurTime() + 2
end)
hook.Add("HUDPaint", "ZZAttackedPropHealth", function()
    if not Zombie(LocalPlayer()) then expires = 0 return end
    if CurTime() >= expires then return end
    local alpha = math.Clamp((expires - CurTime()) / 0.4, 0, 1) * 230
    local w, h = 150, 8
    local x, y = math.floor((ScrW() - w) / 2), math.floor(ScrH() * 0.60)
    surface.SetDrawColor(10, 10, 10, alpha)
    surface.DrawRect(x - 2, y - 2, w + 4, h + 4)
    surface.SetDrawColor(170, 35, 30, alpha)
    surface.DrawRect(x, y, w * amount, h)
    surface.SetDrawColor(220, 215, 210, alpha)
    surface.DrawOutlinedRect(x - 2, y - 2, w + 4, h + 4)
end)
