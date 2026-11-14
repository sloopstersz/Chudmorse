if SERVER then AddCSLuaFile() end
-- Uses the animated pill bottle from weapon_painkillers with the blue pills.
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Antidote Pills"
SWEP.Instructions = "LMB: take pills. RMB: give to a nearby survivor. Cures infection in stages 1-3 only."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Antidote = true
SWEP.modeNames = {[1] = "antidote"}

SWEP.WMSkin = 0 -- blue pills (check in-game with: chud_pillskin)
SWEP.WMSkinV = 0
SWEP.WMFallbackColor = Color(90, 140, 255) -- only used if the model lacks the skin above

SWEP.NPCUsable = false

if SERVER then
	function SWEP:CanFeed(ent)
		if not ZZInfection then return false end
		local owner = self:GetOwner()
		if owner:GetShootPos():DistToSqr(ent:NearestPoint(owner:GetShootPos())) > 80 * 80 then return false end
		return IsValid(ZZInfection.Human(ent))
	end

	function SWEP:Heal(ent)
		if self.ZZUsed or not ZZInfection then return end
		local owner = self:GetOwner()
		if not IsValid(owner) or not IsValid(ent) then return end
		local patient = ZZInfection.Human(ent)
		if not IsValid(patient) then return end

		local success, message = ZZInfection.UsePill(patient, self.Antidote)
		if message then owner:ChatPrint(message) end
		if not success then return end -- bottle goes back to idle, pills are kept

		self.ZZUsed = true
		return self:FinishPills()
	end
end
