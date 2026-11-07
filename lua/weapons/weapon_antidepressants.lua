if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Antidepressants"
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Instructions = "LMB: take pills. RMB: give to a nearby ragdolled player. Gradually reduces depression for 60 seconds. Three doses within two minutes cause an overdose."
SWEP.modeNames = {[1] = "antidepressants"}
-- Keep the existing pills' appearance, sounds and optional consumption animation.
function SWEP:OwnerChanged() end
function SWEP:CanBePickedUpByNPCs() return false end
function SWEP:Think()
    self:SetBodyGroups("111")
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local animations = GetConVar("hg_healanims")
    if not owner:KeyDown(IN_ATTACK) and animations and animations:GetBool() then
        self:SetHolding(math.max(self:GetHolding() - 4, 0))
    end
end
if SERVER then
    function SWEP:Heal(ent)
        local owner = self:GetOwner()
        if self.Consumed or not IsValid(owner) or not owner:Alive() or not IsValid(ent) then return end
        if not self.modeValues or (self.modeValues[1] or 0) <= 0 then return end
        local org = ent.organism
        local target = ent:IsPlayer() and ent or (org and org.owner)
        if not IsValid(target) or not target:IsPlayer() or not target:Alive() or not org or target.organism ~= org then return end
        if target ~= owner then
            if not IsValid(target.FakeRagdoll) or ent ~= target.FakeRagdoll then return end
            if owner:GetShootPos():DistToSqr(ent:NearestPoint(owner:GetShootPos())) > 80 * 80 then return end
        end
        local animations = GetConVar("hg_healanims")
        if target == owner and animations and animations:GetBool() then
            self:SetHolding(math.min(self:GetHolding() + 4, 100))
            if self:GetHolding() < 100 then return end
        end
        if not ChudAntidepressants or not ChudAntidepressants.Take(target) then return end
        self.Consumed = true
        self.modeValues[1] = 0
        ent:EmitSound("snd_jack_hmcd_pillsuse.wav", 60, math.random(95, 105))
        owner:SelectWeapon("weapon_hands_sh")
        self:Remove()
        return true
    end
    function SWEP:SecondaryAttack()
        local owner = self:GetOwner()
        if not IsValid(owner) or IsValid(self:GetNWEntity("fakeGun")) then return end
        local trace = hg.eyeTrace(owner)
        if not trace or not IsValid(trace.Entity) then return end
        self:Heal(trace.Entity)
    end
end
