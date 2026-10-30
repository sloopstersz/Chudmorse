local MODE = MODE

zb = zb or {}
--[[zb.Points = zb.Points or {}

zb.Points.HMCD_TDM_CT = zb.Points.HMCD_TDM_CT or {}
zb.Points.HMCD_TDM_CT.Color = Color(0,0,150)
zb.Points.HMCD_TDM_CT.Name = "HMCD_TDM_CT"

zb.Points.HMCD_TDM_T = zb.Points.HMCD_TDM_T or {}
zb.Points.HMCD_TDM_T.Color = Color(150,95,0)
zb.Points.HMCD_TDM_T.Name = "HMCD_TDM_T"]]

-- The two choices on the vote screen (index = the number sent over the network)
TURFWARS_VARIANTS = {
	[1] = {
		id = "PLANNED",
		name = "Planned",
		color = Color(255, 90, 90),
		description = "Choose your class. SWAT rolls in after two minutes."
	},
	[2] = {
		id = "UNEXPECTED",
		name = "Unexpected",
		color = Color(255, 190, 90),
		description = "No warning. Melee, scraps and a few guns."
	}
}

-- ===== Planned: class selection =====
-- After Planned wins the vote, everyone gets TURFWARS_SELECT_TIME seconds to pick a class (their weapon).
-- No pick = a random class. The classes are the old random weapon pool, grouped by role, and they are
-- the same for both gangs. Everyone also gets the medical kit and hands, like before.
TURFWARS_SELECT_TIME = 10

TURFWARS_CLASSES = {
	[1] = {
		id = "SHOTGUNNER",
		name = "Shotgunner",
		description = "Close range. One blast ruins somebody's day.",
		weapons = {"weapon_doublebarrel_short"},
		items = "Short Double-Barrel",
	},
	[2] = {
		id = "FULLAUTO",
		name = "Full Auto",
		description = "Full-auto pistol. Hold the trigger down.",
		weapons = {"weapon_glock18c"},
		items = "Glock 18C (full auto)",
	},
	[3] = {
		id = "SMG",
		name = "SMG",
		description = "Spray it. Fast fire, small caliber.",
		weapons = {"weapon_mac11", "weapon_skorpion"},
		items = "MAC-11 or Skorpion (random)",
	},
	[4] = {
		id = "GUNSLINGER",
		name = "Gunslinger",
		description = "Revolver. Few shots, make them count.",
		weapons = {"weapon_revolver2"},
		items = "Revolver",
	},
	[5] = {
		id = "MARKSMAN",
		name = "Marksman",
		description = "Heavy pistol. Hits hard, kicks harder.",
		weapons = {"weapon_deagle"},
		items = "Desert Eagle",
	},
	[6] = {
		id = "STANDARD",
		name = "Standard",
		description = "A normal sidearm. Reliable and easy to handle.",
		weapons = {"weapon_cz75", "weapon_glock17", "weapon_hk_usp", "weapon_p22"},
		items = "CZ-75, Glock 17, HK USP or P22 (random)",
	},
}

-- every class also gets this
TURFWARS_CLASS_KIT = "Bandage, Tourniquet, Fentanyl"

-- The playermodels the Bloodz / Groove classes pick from (copied from sh_bloodz.lua / sh_groove.lua).
-- The server picks one per player when class selection starts, so the screen shows the model you will
-- really spawn with. You never choose it: it is random.
TURFWARS_MODELS = {
	[0] = {
		"models/gang_ballas_chem/gang_ballas_chem.mdl",
		"models/gang_ballas/gang_ballas_2.mdl",
		"models/gang_ballas/gang_ballas_1.mdl",
	},
	[1] = {
		"models/gang_groove/gang_1.mdl",
		"models/gang_groove/gang_2.mdl",
		"models/gang_chem/gang_groove_chem.mdl",
	},
}
