if not SERVER then return end
local MODE = MODE
MODE.name = "chaos"
MODE.PrintName = "CHAOS"
MODE.Chance = 0
MODE.SubModes = false
MODE.LootSpawn = true
MODE.LootOnTime = false
MODE.LootAmountMul = 1
MODE.LootLooseSkip = 0
MODE.EmptyBoxChance = 0
function MODE:SetupChances()
    zb.ModesChances.chaos = zb.ModesChances.chaos or 0
end
local intermission = MODE.Intermission
function MODE:Intermission()
    self:BuildChaosLoot()
    return intermission(self)
end

-- Register all private channels, including ones the base game registers globally.
util.AddNetworkString("CHAOS(EndPlayersRoleSelection)")
util.AddNetworkString("CHAOS(SetSubRole)")
util.AddNetworkString("CHAOS(StartPlayersRoleSelection)")
util.AddNetworkString("CHAOSPoliceRole")
util.AddNetworkString("CHAOS_BeingVictimOfDisarmament")
util.AddNetworkString("CHAOS_BeingVictimOfNeckBreak")
util.AddNetworkString("CHAOS_BreakingOtherNeck")
util.AddNetworkString("CHAOS_DisarmingOther")
util.AddNetworkString("CHAOS_Professions_Abilities_AddFootstep")
util.AddNetworkString("CHAOS_Professions_Abilities_DisplayOrganismInfo")
util.AddNetworkString("CHAOS_RequestTraitorStatuses")
util.AddNetworkString("CHAOS_RoundStart")
util.AddNetworkString("CHAOS_SetNextTraitorRole")
util.AddNetworkString("CHAOS_TraitorDeathState")
util.AddNetworkString("CHAOS_TraitorOutlineRoster")
util.AddNetworkString("CHAOS_UpdateChemicalResistance")
util.AddNetworkString("CHAOS_UpdateTraitorAssistants")
util.AddNetworkString("CHAOS_announce_traitor_lose")
util.AddNetworkString("CHAOS_roundend")
