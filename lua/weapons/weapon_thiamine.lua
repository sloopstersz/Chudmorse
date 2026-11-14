if SERVER then AddCSLuaFile() end
-- Animated pill bottle (weapon_painkillers base), judge's thiamine bottle skin.
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Thiamine"
SWEP.Instructions = "A water-soluble vitamin (B1) that plays a big part in the organism's metabolism of carbohydrates, fats and proteins. RMB to give to someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.modeNames = {[1] = "thiamine"}

SWEP.WMSkin = 0
SWEP.WMSkinV = 0

if SERVER then
	-- Old Chudmorse thiamine could be given to anyone, not just knocked-down players.
	function SWEP:CanFeed(ent)
		return ent.organism ~= nil
	end

	function SWEP:Heal(ent)
		local org = ent.organism
		if not org or not self.modeValues or not self.modeValues[1] then return end

		org.thiamine = math.min((org.thiamine or 0) + 1, 1)
		self.modeValues[1] = 0
		return self:FinishPills()
	end
end
