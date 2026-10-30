local MODE = MODE
MODE.name = "vip"
MODE.PrintName = "VIP Escort"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.DisableMental = true
MODE.randomSpawns = true
MODE.shouldfreeze = false -- Full engine freeze also locks the camera.
MODE.Chance = 0.03
MODE.start_time = 15
MODE.OverrideSpawn = true
MODE.end_time = 8
MODE.ROUND_TIME = 600
MODE.HoldTime = 15
MODE.HoldRadius = 160

-- The existing zpoint/Point Editor lists registered groups automatically.
zb.Points = zb.Points or {}
local groups = {
    President_Defenders = {"President: VIC and SWAT spawn", Color(50, 120, 255)},
    President_Attackers = {"President: Angry Chuds spawn", Color(190, 35, 35)},
    President_Task1 = {"President: first hold location", Color(230, 210, 90)},
    President_Task2 = {"President: second hold location", Color(230, 170, 70)},
    President_Task3 = {"President: final hold location", Color(230, 130, 60)}
}
for key, info in pairs(groups) do
    zb.Points[key] = zb.Points[key] or {}
    zb.Points[key].Name = info[1]
    zb.Points[key].Color = info[2]
end

ChudVIPLoadoutSlots = {} -- Fixed class kits; clients choose only the class.
ChudVIPClassOrder = {"Assault", "Rusher", "Marksman", "Breacher", "Medic", "Attacker", "Speedster", "Shotgunner", "Sniper", "Melee Fighter"}
ChudVIPClasses = {
    ["Assault"] = {name = "Assault", role = "Guard", weapons = {"weapon_m16a1_30", "weapon_m9beretta", "weapon_combatknife", "weapon_medkit_sh"}, armor = {"ent_armor_vest2", "ent_armor_helmet6", "ent_armor_headphones1"}, attachments = {}},
    ["Rusher"] = {name = "Rusher", role = "Guard", weapons = {"weapon_mp7", "weapon_m9beretta", "weapon_combatknife", "weapon_medkit_sh"}, armor = {"ent_armor_vest2", "ent_armor_helmet6", "ent_armor_headphones1"}, attachments = {}},
    ["Marksman"] = {name = "Marksman", role = "Guard", weapons = {"weapon_sr25", "weapon_m9beretta", "weapon_combatknife", "weapon_medkit_sh"}, armor = {"ent_armor_vest2", "ent_armor_helmet6", "ent_armor_headphones1"}, attachments = {["weapon_sr25"] = {"optic6"}}},
    ["Breacher"] = {name = "Breacher", role = "Guard", weapons = {"weapon_spas12_modern", "weapon_m9beretta", "weapon_ram", "weapon_medkit_sh"}, armor = {"ent_armor_vest2", "ent_armor_helmet6", "ent_armor_headphones1"}, attachments = {}},
    ["Medic"] = {name = "Medic", role = "Guard", weapons = {"weapon_m9beretta", "weapon_ballistic_shield", "weapon_defibrillator", "weapon_bigbandage_sh", "weapon_morphine", "weapon_mannitol", "weapon_adrenaline", "weapon_tourniquet", "weapon_naloxone", "weapon_fentanyl", "weapon_tourniquet", "weapon_bloodbag", "weapon_betablock"}, armor = {}, attachments = {}},
    ["Attacker"] = {name = "Attacker", role = "Attacker", weapons = {"weapon_akmwreked", "weapon_makarov", "weapon_pocketknife", "weapon_bigbandage_sh", "weapon_tourniquet", "weapon_fentanyl"}, armor = {"ent_armor_vest4", "ent_armor_helmet1"}, attachments = {}},
    ["Speedster"] = {name = "Speedster", role = "Attacker", weapons = {"weapon_mac11", "weapon_px4beretta", "weapon_bigbandage_sh", "weapon_tourniquet", "weapon_fentanyl"}, armor = {"ent_armor_helmet2"}, attachments = {}},
    ["Shotgunner"] = {name = "Shotgunner", role = "Attacker", weapons = {"weapon_remington870_sawed_off", "weapon_tec9", "weapon_pocketknife", "weapon_bigbandage_sh", "weapon_tourniquet", "weapon_fentanyl"}, armor = {"ent_armor_vest4", "ent_armor_helmet1"}, attachments = {}},
    ["Sniper"] = {name = "Sniper", role = "Attacker", weapons = {"weapon_kar98", "weapon_revolver2", "weapon_pocketknife", "weapon_bigbandage_sh", "weapon_tourniquet", "weapon_fentanyl"}, armor = {"ent_armor_vest4", "ent_armor_helmet1"}, attachments = {["weapon_kar98"] = {"optic12"}}},
    ["Melee Fighter"] = {name = "Melee Fighter", role = "Attacker", weapons = {"weapon_hg_spear_knife", "weapon_fentanyl"}, armor = {"ent_armor_vest4", "ent_armor_helmet1", "ent_armor_mask3"}, attachments = {}},
}
ChudVIPFixedVIP = {weapons = {"weapon_p22"}, armor = {"ent_armor_vest7"}}
function ChudVIPClassAllowed(ply, key)
    local class = ChudVIPClasses[key]
    local role = ply:GetNWString("ChudVIPRole", "")
    if role == "SWAT" then role = "Guard" end
    return class ~= nil and class.role == role
end
function ChudVIPClassesFor(ply)
    local result = {}
    for _, key in ipairs(ChudVIPClassOrder) do
        if ChudVIPClassAllowed(ply, key) then result[#result + 1] = key end
    end
    return result
end
MODE.IntroDuration = 10
MODE.LoadoutDuration = 15

