if SERVER then AddCSLuaFile() end
-- Same animated bottle as the antidote, with green pills.
SWEP.Base = "weapon_zz_antidote"
SWEP.PrintName = "Recovery Pills"
SWEP.Instructions = "LMB: take pills. RMB: give to a nearby survivor. Symptoms ease over 30 seconds; relief lasts 120 seconds. Does not cure infection."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Antidote = false
SWEP.modeNames = {[1] = "symptom relief"}

SWEP.WMSkin = 3 -- green pills (check in-game with: chud_pillskin)
SWEP.WMSkinV = 3
SWEP.WMFallbackColor = Color(90, 230, 110) -- tints the bottle green if skin 3 doesn't exist
