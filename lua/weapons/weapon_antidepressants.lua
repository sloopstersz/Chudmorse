if SERVER then AddCSLuaFile() end
-- Uses the animated pill bottle from weapon_painkillers, in the beta-blocker colour.
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Antidepressants"
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Instructions = "LMB: take pills. RMB: give to a nearby ragdolled player. Gradually reduces depression for 60 seconds. Three doses within two minutes cause an overdose."
SWEP.modeNames = {[1] = "antidepressants"}

SWEP.WMSkin = 1 -- beta-blocker bottle underneath, with the "Feel Better" label on top
SWEP.WMSkinV = 1
SWEP.WMBottleMaterial = "models/chudmorse/pills/antidepressants"
if SERVER then resource.AddFile("materials/models/chudmorse/pills/antidepressants.vmt") end

SWEP.NPCUsable = false
function SWEP:CanBePickedUpByNPCs() return false end

if SERVER then
	function SWEP:CanFeed(ent)
		local owner = self:GetOwner()
		local org = ent.organism
		local target = org and org.owner
		if not IsValid(target) or not target:IsPlayer() or not IsValid(target.FakeRagdoll) or ent ~= target.FakeRagdoll then return false end
		return owner:GetShootPos():DistToSqr(ent:NearestPoint(owner:GetShootPos())) <= 80 * 80
	end

	function SWEP:Heal(ent)
		local owner = self:GetOwner()
		if self.Consumed or not IsValid(owner) or not owner:Alive() or not IsValid(ent) then return end
		if not self.modeValues or (self.modeValues[1] or 0) <= 0 then return end
		local org = ent.organism
		local target = ent:IsPlayer() and ent or (org and org.owner)
		if not IsValid(target) or not target:IsPlayer() or not target:Alive() or not org or target.organism ~= org then return end
		if target ~= owner and not self:CanFeed(ent) then return end
		if not ChudAntidepressants or not ChudAntidepressants.Take(target) then return end

		self.Consumed = true
		self.modeValues[1] = 0
		return self:FinishPills()
	end
end
