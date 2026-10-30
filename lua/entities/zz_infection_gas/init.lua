AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self.ExpiresAt = self.ExpiresAt or CurTime() + 30
    self:SetNWFloat("ExpiresAt", self.ExpiresAt)
end

function ENT:CanInfect(ply)
    if not IsValid(ply) or not ply:Alive() or ply:Team() == TEAM_SPECTATOR or ZZIsZombie(ply)
        or ply.ZZ_Extracted or ply.ZZExfilBoarded or ZZAbilities.HasGasMask(ply) then return false end
    local body = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
    local delta = body:GetPos() - self:GetPos()
    if delta:Length2DSqr() > ZZAbilities.Airborne.radius ^ 2 or delta.z < -24 or delta.z > 110 then return false end
    -- The cloud does not infect through walls or floors.
    local tr = util.TraceLine({start = self:GetPos() + Vector(0, 0, 40),
        endpos = body:WorldSpaceCenter(), filter = {self, ply, body, self:GetOwner()}, mask = MASK_SOLID_BRUSHONLY})
    return not tr.Hit
end

function ENT:Think()
    if not ZZInfection or not ZZInfection.Active() or CurTime() >= self.ExpiresAt then self:Remove() return end
    for _, ply in player.Iterator() do
        if self:CanInfect(ply) then ZZInfection.Infect(ply) end
    end
    self:NextThink(CurTime() + 0.2)
    return true
end
