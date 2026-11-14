if SERVER then AddCSLuaFile() end
-- Animated pill bottle (weapon_painkillers base), judge's beta-blocker bottle skin.
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Beta-Blocker"
SWEP.Instructions = "Beta blockers can help in stressful situations, will reduce your panic and adrenaline. Very useful in combat at certain doses. RMB to give to someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Slot = 5
SWEP.modeNames = {[1] = "beta-blocker"}

SWEP.WMSkin = 1
SWEP.WMSkinV = 1

if SERVER then
	function SWEP:CanFeed(ent)
		return ent.organism ~= nil
	end

	function SWEP:Heal(ent)
		local org = ent.organism
		if not org then return end

		local mode = self.modeValues and self.modeValues[1] or 1
		org.adrenalineAdd = math.Approach(org.adrenalineAdd or 0, -4, mode * 2)
		org.panicattackadd = math.max((org.panicattackadd or 0) - mode * 0.65, 0)
		org.panicattack = math.max((org.panicattack or 0) - mode * 0.2, 0)

		self.modeValues[1] = 0
		return self:FinishPills()
	end
end
