local MODE = MODE

MODE.name = "event"
MODE.PrintName = "Event"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.randomSpawns = true

MODE.ForBigMaps = true
MODE.Chance = 0

MODE.EndLogicType = 2
MODE.EventersList = MODE.EventersList or {}

-- Loot waves are driven by this mode (see sv_lootspawn "SpawnBoxes"),
-- so the global 8s box timer does not stack on top of our own rate.
MODE.ManualBoxWaves = true
MODE.InManualWave = false

local LOOT_MAX_ITEMS = 128
local LOOT_MIN_WEIGHT, LOOT_MAX_WEIGHT = 1, 1000
local LOOT_MIN_INTERVAL, LOOT_MAX_INTERVAL = 2, 120
local LOOT_MIN_PERWAVE, LOOT_MAX_PERWAVE = 1, 10

-- Persistent loot state (kept across hotloads via MODE.saved when possible)
MODE.LootItems = MODE.LootItems or {}        -- flat list: { {weight, class}, ... }
MODE.LootEnabled = false
MODE.LootInterval = MODE.LootInterval or 8
MODE.LootPerWave = MODE.LootPerWave or 1
MODE.NextLootWave = 0
MODE.WaveEnts = MODE.WaveEnts or {}

util.AddNetworkString("event_start")
util.AddNetworkString("event_end")
util.AddNetworkString("event_eventers_update")
util.AddNetworkString("event_loot_sync")
util.AddNetworkString("event_loot_open")
util.AddNetworkString("event_loot_action")
util.AddNetworkString("event_loot_notify")
util.AddNetworkString("event_loot_wave")

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
	game.CleanUpMap()

	for k, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			ApplyAppearance(ply)
			ply:SetupTeam(0)
		end
	end

	local rndpoints = zb.GetMapPoints("RandomSpawns")
	zonepoint = table.Random(rndpoints)

	net.Start("event_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	local AlivePlyTbl = {}
	for _, ply in player.Iterator() do
		if ply:Alive() and not (ply.organism and ply.organism.incapacitated) then
			AlivePlyTbl[#AlivePlyTbl + 1] = ply
		end
	end
	return AlivePlyTbl
end

function MODE:ShouldRoundEnd()
	if self.EndLogicType == 1 then
		local aliveCount = 0
		local eventerCount = 0

		for _, ply in ipairs(zb:CheckAlive(true)) do
			aliveCount = aliveCount + 1
			if self.EventersList[ply:SteamID()] then
				eventerCount = eventerCount + 1
			end
		end

		return (aliveCount == eventerCount)
	elseif self.EndLogicType == 2 then
		return (#zb:CheckAlive(true) <= 1)
	elseif self.EndLogicType == 3 then
		return false
	end

	return (#zb:CheckAlive(true) <= 1)
end

local function BroadcastEventers()
	net.Start("event_eventers_update")
	local data = {}
	for id, _ in pairs(MODE.EventersList) do
		table.insert(data, id)
	end
	net.WriteTable(data)
	net.Broadcast()
end

function MODE:RoundStart()
	self.EventersList = {}
	for _, ply in player.Iterator() do
		if ply:IsAdmin() then
			self.EventersList[ply:SteamID()] = true
		end
	end

	BroadcastEventers()

	for _, ply in player.Iterator() do
		if ply:Alive() then
			ply:SetSuppressPickupNotices(true)
			ply.noSound = true
			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			timer.Simple(0.1, function()
				if IsValid(ply) then ply.noSound = false end
			end)

			ply:SetSuppressPickupNotices(false)

			if self.EventersList[ply:SteamID()] then
				zb.GiveRole(ply, "Eventer", Color(50, 200, 50))
			else
				zb.GiveRole(ply, GetGlobalString("ZB_EventRole", "Player"), Color(190, 15, 15))
			end
		end
	end

	self.WaveEnts = {}
	self.NextLootWave = CurTime() + self.LootInterval
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundThink()
end

---------------------------------------------------------------------------
-- Default loot (used when the custom table is empty)
---------------------------------------------------------------------------

MODE.LootTable = {
	{50, {
		{4, "weapon_leadpipe"},
		{3, "weapon_hg_crowbar"},
		{2, "weapon_hatchet"},
		{1, "weapon_hg_axe"},
		{1, "weapon_hg_crossbow"},
	}},
	{50, {
		{9, "*ammo*"},
		{9, "weapon_hk_usp"},
		{8, "weapon_revolver357"},
		{8, "weapon_deagle"},
		{8, "weapon_doublebarrel_short"},
		{8, "weapon_doublebarrel"},
		{8, "weapon_remington870"},
		{8, "weapon_glock18c"},
		{7, "weapon_mp5"},
		{6, "weapon_xm1014"},
		{6, "ent_armor_vest3"},
		{5, "ent_armor_helmet1"},
		{5, "weapon_mp7"},
		{5, "weapon_sks"},
		{5, "ent_armor_vest4"},
		{5, "weapon_hg_molotov_tpik"},
		{5, "weapon_hg_pipebomb_tpik"},
		{5, "weapon_claymore"},
		{5, "weapon_hg_f1_tpik"},
		{5, "weapon_traitor_ied"},
		{5, "weapon_hg_slam"},
		{5, "weapon_hg_legacy_grenade_shg"},
		{5, "weapon_hg_grenade_tpik"},
		{5, "weapon_ptrd"},
		{5, "weapon_akm"},
		{5, "weapon_m98b"},
		{2, "weapon_hg_rpg"},
		{3, "weapon_sr25"},
	}},
}

function MODE:GetLootTable()
	if #self.LootItems > 0 then
		return self.LootItems
	end

	return self.LootTable[2][2]
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function CanEdit(ply)
	if not IsValid(ply) then return true end -- server console
	return ply:IsAdmin() or MODE.EventersList[ply:SteamID()] == true
end

local function IsValidLootClass(class)
	if not isstring(class) or class == "" or #class > 96 then return false end
	if class == "*ammo*" then return true end
	return scripted_ents.GetStored(class) ~= nil or weapons.GetStored(class) ~= nil
end

local function FindItem(class)
	for i, item in ipairs(MODE.LootItems) do
		if item[2] == class then return i, item end
	end
end

local function GetEditors()
	local recipients = {}
	for _, p in player.Iterator() do
		if CanEdit(p) then
			recipients[#recipients + 1] = p
		end
	end
	return recipients
end

local function IsEventActive()
	local round = CurrentRound and CurrentRound()
	return round ~= nil and round.name == MODE.name and zb.ROUND_STATE == 1
end

local function Notify(ply, msg, isError)
	if not IsValid(ply) then
		print("[Event Loot] " .. msg)
		return
	end
	net.Start("event_loot_notify")
	net.WriteString(msg)
	net.WriteBool(isError and true or false)
	net.Send(ply)
end

local PresetSummary -- defined in the presets section below

local function BuildState()
	return {
		items = MODE.LootItems,
		defaults = MODE.LootTable[2][2],
		enabled = MODE.LootEnabled,
		interval = MODE.LootInterval,
		perWave = MODE.LootPerWave,
		nextWave = MODE.NextLootWave,
		active = IsEventActive(),
		maxItems = LOOT_MAX_ITEMS,
		presets = PresetSummary and PresetSummary() or {},
	}
end

local function SyncTo(target)
	net.Start("event_loot_sync")
	net.WriteTable(BuildState())
	if target then
		net.Send(target)
	else
		net.Send(GetEditors())
	end
end

---------------------------------------------------------------------------
-- Saving / loading
---------------------------------------------------------------------------

local serverIdentifier = string.Trim(string.lower(GetConVar("hostname"):GetString()))
serverIdentifier = string.gsub(serverIdentifier, "[^%w]", "_")

local function SavePath()
	return "zbattle/event_loot/loot_table_" .. serverIdentifier .. ".txt"
end

function MODE:SaveLootTable()
	file.CreateDir("zbattle/event_loot")

	local data = util.TableToJSON({
		version = 2,
		items = self.LootItems,
		interval = self.LootInterval,
		perWave = self.LootPerWave,
	}, true)

	file.Write(SavePath(), data)
end

function MODE:LoadLootTable()
	self.LootItems = {}

	if not file.Exists(SavePath(), "DATA") then
		print("[Event Loot] No saved loot table for server: " .. serverIdentifier)
		return
	end

	local raw = file.Read(SavePath(), "DATA")
	local ok, data = pcall(util.JSONToTable, raw or "")
	if not ok or not istable(data) then
		print("[Event Loot] Could not read saved loot table for server: " .. serverIdentifier)
		return
	end

	local list
	if data.version == 2 then
		list = data.items
		self.LootInterval = math.Clamp(tonumber(data.interval) or 8, LOOT_MIN_INTERVAL, LOOT_MAX_INTERVAL)
		self.LootPerWave = math.Clamp(tonumber(data.perWave) or 1, LOOT_MIN_PERWAVE, LOOT_MAX_PERWAVE)
	elseif istable(data[1]) and istable(data[1][2]) then
		list = data[1][2] -- legacy format: { {50, { {w, class}, ... }} }
	end

	local seen = {}
	for _, item in ipairs(list or {}) do
		local weight, class = tonumber(item[1]), item[2]
		if weight and isstring(class) and not seen[class] and #self.LootItems < LOOT_MAX_ITEMS then
			seen[class] = true
			self.LootItems[#self.LootItems + 1] = {math.Clamp(math.floor(weight), LOOT_MIN_WEIGHT, LOOT_MAX_WEIGHT), class}
		end
	end

	print("[Event Loot] Loaded " .. #self.LootItems .. " items for server: " .. serverIdentifier)
end

---------------------------------------------------------------------------
-- Saved loot tables (presets)
---------------------------------------------------------------------------

local PRESET_MAX = 50
local PRESET_NAME_MAX = 32

MODE.LootPresets = MODE.LootPresets or {} -- [name] = { items = {...}, saved = os.time() }

local function PresetPath()
	return "zbattle/event_loot/presets_" .. serverIdentifier .. ".txt"
end

local function SavePresets()
	file.CreateDir("zbattle/event_loot")
	file.Write(PresetPath(), util.TableToJSON(MODE.LootPresets, true))
end

local function LoadPresets()
	MODE.LootPresets = {}
	if not file.Exists(PresetPath(), "DATA") then return end

	local ok, data = pcall(util.JSONToTable, file.Read(PresetPath(), "DATA") or "")
	if not ok or not istable(data) then
		print("[Event Loot] Could not read saved loot tables for server: " .. serverIdentifier)
		return
	end

	for name, preset in pairs(data) do
		if isstring(name) and istable(preset) and istable(preset.items) then
			MODE.LootPresets[name] = {items = preset.items, saved = tonumber(preset.saved) or 0}
		end
	end
end

local function CleanPresetName(name)
	if not isstring(name) then return end
	name = string.Trim(string.gsub(name, "[%c\"\\]", ""))
	if name == "" or #name > PRESET_NAME_MAX then return end
	return name
end

PresetSummary = function()
	local list = {}
	for name, preset in pairs(MODE.LootPresets) do
		list[#list + 1] = {name = name, count = #preset.items, saved = preset.saved}
	end
	table.sort(list, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
	return list
end

hook.Add("Initialize", "ZB_EventLoadLootTable", function()
	timer.Simple(1, function()
		MODE:LoadLootTable()
		LoadPresets()
	end)
end)

-- Hotload: reload from disk so the table is never lost
if GAMEMODE then
	MODE:LoadLootTable()
	LoadPresets()
end

---------------------------------------------------------------------------
-- Loot waves
---------------------------------------------------------------------------

hook.Add("OnEntityCreated", "ZB_EventTrackWaveLoot", function(ent)
	if MODE.InManualWave then
		MODE.WaveEnts[#MODE.WaveEnts + 1] = ent
	end
end)

local function SpawnLootWave(count)
	MODE.LootSpawn = true
	for i = 1, count do
		MODE.InManualWave = true
		local ok, err = pcall(hook.Run, "Boxes Think")
		MODE.InManualWave = false
		if not ok then
			ErrorNoHalt("[Event Loot] wave error: " .. tostring(err) .. "\n")
			break
		end
	end
	MODE.LootSpawn = MODE.LootEnabled
end

local function ClearWaveLoot()
	local removed = 0
	for _, ent in ipairs(MODE.WaveEnts) do
		if IsValid(ent) and not IsValid(ent:GetOwner()) and not ent:IsPlayer() then
			ent:Remove()
			removed = removed + 1
		end
	end
	MODE.WaveEnts = {}
	return removed
end

timer.Create("ZB_EventLootWaves", 1, 0, function()
	if not MODE.LootEnabled or not IsEventActive() then return end
	if CurTime() < (MODE.NextLootWave or 0) then return end

	SpawnLootWave(MODE.LootPerWave)
	MODE.NextLootWave = CurTime() + MODE.LootInterval

	net.Start("event_loot_wave")
	net.WriteFloat(MODE.NextLootWave)
	net.Send(GetEditors())
end)

local function SetLootEnabled(enabled)
	MODE.LootEnabled = enabled
	MODE.LootSpawn = enabled
	MODE.NextLootWave = CurTime() + (enabled and 1 or 0)
end

---------------------------------------------------------------------------
-- Menu actions
---------------------------------------------------------------------------

local Actions = {}

Actions.add = function(ply)
	local class = net.ReadString()
	local weight = math.Clamp(net.ReadUInt(16), LOOT_MIN_WEIGHT, LOOT_MAX_WEIGHT)

	if not IsValidLootClass(class) then
		return Notify(ply, "'" .. class .. "' isn't a weapon or entity on this server.", true)
	end
	if FindItem(class) then
		return Notify(ply, class .. " is already in the loot table.", true)
	end
	if #MODE.LootItems >= LOOT_MAX_ITEMS then
		return Notify(ply, "Loot table is full (" .. LOOT_MAX_ITEMS .. " items).", true)
	end

	table.insert(MODE.LootItems, {weight, class})
	MODE:SaveLootTable()
	Notify(ply, "Added " .. class .. " (weight " .. weight .. ")")
	return true
end

Actions.remove = function(ply)
	local class = net.ReadString()
	local i = FindItem(class)
	if not i then return end

	table.remove(MODE.LootItems, i)
	MODE:SaveLootTable()
	Notify(ply, "Removed " .. class)
	return true
end

Actions.weight = function(ply)
	local class = net.ReadString()
	local weight = math.Clamp(net.ReadUInt(16), LOOT_MIN_WEIGHT, LOOT_MAX_WEIGHT)
	local _, item = FindItem(class)
	if not item then return end

	item[1] = weight
	MODE:SaveLootTable()
	return true
end

Actions.toggle = function(ply)
	SetLootEnabled(net.ReadBool())
	Notify(ply, "Event loot spawning " .. (MODE.LootEnabled and "ON" or "OFF"))
	return true
end

Actions.interval = function(ply)
	MODE.LootInterval = math.Clamp(net.ReadUInt(8), LOOT_MIN_INTERVAL, LOOT_MAX_INTERVAL)
	MODE.NextLootWave = math.min(MODE.NextLootWave or 0, CurTime() + MODE.LootInterval)
	MODE:SaveLootTable()
	return true
end

Actions.perwave = function(ply)
	MODE.LootPerWave = math.Clamp(net.ReadUInt(8), LOOT_MIN_PERWAVE, LOOT_MAX_PERWAVE)
	MODE:SaveLootTable()
	return true
end

Actions.import = function(ply)
	local added = 0
	for _, item in ipairs(MODE.LootTable[2][2]) do
		if #MODE.LootItems >= LOOT_MAX_ITEMS then break end
		if not FindItem(item[2]) then
			table.insert(MODE.LootItems, {item[1], item[2]})
			added = added + 1
		end
	end
	MODE:SaveLootTable()
	Notify(ply, "Imported " .. added .. " items from the default table")
	return true
end

Actions.reset = function(ply)
	MODE.LootItems = {}
	MODE:SaveLootTable()
	Notify(ply, "Loot table cleared. Events will use the default table.")
	return true
end

Actions.spawnnow = function(ply)
	if not IsEventActive() then
		return Notify(ply, "Waves only spawn during an event round.", true)
	end
	if not MODE.LootEnabled then
		return Notify(ply, "Turn loot spawning on first (boxes need it to contain loot).", true)
	end
	SpawnLootWave(MODE.LootPerWave)
	MODE.NextLootWave = CurTime() + MODE.LootInterval
	Notify(ply, "Spawned a loot wave")
	return true
end

Actions.preset_save = function(ply)
	local name = CleanPresetName(net.ReadString())
	if not name then
		return Notify(ply, "Give the table a name (1-" .. PRESET_NAME_MAX .. " characters).", true)
	end
	if #MODE.LootItems == 0 then
		return Notify(ply, "The loot table is empty - add items before saving.", true)
	end

	local existed = MODE.LootPresets[name] ~= nil
	if not existed and table.Count(MODE.LootPresets) >= PRESET_MAX then
		return Notify(ply, "Too many saved tables (" .. PRESET_MAX .. "). Delete one first.", true)
	end

	MODE.LootPresets[name] = {items = table.Copy(MODE.LootItems), saved = os.time()}
	SavePresets()
	Notify(ply, (existed and "Overwrote '" or "Saved '") .. name .. "' (" .. #MODE.LootItems .. " items)")
	return true
end

Actions.preset_load = function(ply)
	local name = net.ReadString()
	local preset = MODE.LootPresets[name]
	if not preset then return Notify(ply, "That saved table no longer exists.", true) end

	MODE.LootItems = {}
	local seen = {}
	for _, item in ipairs(preset.items) do
		local weight, class = tonumber(item[1]), item[2]
		if weight and isstring(class) and not seen[class] and #MODE.LootItems < LOOT_MAX_ITEMS then
			seen[class] = true
			MODE.LootItems[#MODE.LootItems + 1] = {math.Clamp(math.floor(weight), LOOT_MIN_WEIGHT, LOOT_MAX_WEIGHT), class}
		end
	end

	MODE:SaveLootTable()
	Notify(ply, "Loaded '" .. name .. "' (" .. #MODE.LootItems .. " items)")
	return true
end

Actions.preset_delete = function(ply)
	local name = net.ReadString()
	if not MODE.LootPresets[name] then return end

	MODE.LootPresets[name] = nil
	SavePresets()
	Notify(ply, "Deleted '" .. name .. "'")
	return true
end

Actions.clearloot = function(ply)
	Notify(ply, "Removed " .. ClearWaveLoot() .. " spawned loot entities")
end

net.Receive("event_loot_action", function(len, ply)
	if not CanEdit(ply) then return end

	ply.ZB_NextLootAction = ply.ZB_NextLootAction or 0
	if ply.ZB_NextLootAction > SysTime() then return end
	ply.ZB_NextLootAction = SysTime() + 0.05

	local action = Actions[net.ReadString()]
	if not action then return end

	if action(ply) then
		SyncTo()
	end
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

concommand.Add("zb_event_lootpoll", function(ply)
	if not CanEdit(ply) then
		ply:ChatPrint("You don't have access to this command")
		return
	end
	if not IsValid(ply) then return end

	SyncTo(ply)
	net.Start("event_loot_open")
	net.Send(ply)
end)

concommand.Add("zb_event_loot_reset", function(ply)
	if not CanEdit(ply) then return end
	MODE.LootItems = {}
	MODE:SaveLootTable()
	SyncTo()
	Notify(ply, "Loot table has been reset")
end)

concommand.Add("zb_event_loot_save", function(ply)
	if not CanEdit(ply) then return end
	MODE:SaveLootTable()
	Notify(ply, "Loot table saved for server: " .. serverIdentifier)
end)

concommand.Add("zb_event_loot", function(ply, _, args)
	if not CanEdit(ply) then return end
	SetLootEnabled(tonumber(args[1]) == 1)
	SyncTo()
	Notify(ply, "Event loot " .. (MODE.LootEnabled and "enabled" or "disabled"))
end)

concommand.Add("zb_event_name", function(ply, _, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	SetGlobalString("ZB_EventName", args)
end)

concommand.Add("zb_event_role", function(ply, _, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	SetGlobalString("ZB_EventRole", args)
end)

concommand.Add("zb_event_objective", function(ply, _, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	SetGlobalString("ZB_EventObjective", args)
end)

concommand.Add("zb_event_endlogic", function(ply, _, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local logicType = math.Clamp(tonumber(args) or 2, 1, 3)
	MODE.EndLogicType = logicType
	if IsValid(ply) then ply:ChatPrint("Event end logic set to: " .. logicType) end
end)

hook.Add("PlayerInitialSpawn", "ZB_EventLootSync", function(ply)
	timer.Simple(5, function()
		if IsValid(ply) and CanEdit(ply) then
			SyncTo(ply)
		end
	end)
end)

hook.Add("HG_PlayerSay", "ZB_EventLootCommand", function(ply, txtTbl, text)
	if string.lower(text) == "!eventloot" and CanEdit(ply) then
		ply:ConCommand("zb_event_loot_menu")
		txtTbl[1] = ""
	end
end)

concommand.Add("zb_event_eventer_add", function(ply, _, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local target = player.GetBySteamID(args) or player.GetByID(tonumber(args) or 0)

	if IsValid(target) then
		MODE.EventersList[target:SteamID()] = true
		if IsValid(ply) then ply:ChatPrint("Added " .. target:Nick() .. " as an eventer") end

		if zb.ROUND_PLAYING then
			zb.GiveRole(target, "Eventer", Color(50, 200, 50))
		end

		BroadcastEventers()
		SyncTo(target)
	end
end)

concommand.Add("zb_event_eventer_remove", function(ply, _, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local target = player.GetBySteamID(args) or player.GetByID(tonumber(args) or 0)

	if IsValid(target) then
		MODE.EventersList[target:SteamID()] = nil
		if IsValid(ply) then ply:ChatPrint("Removed " .. target:Nick() .. " as an eventer") end

		if zb.ROUND_PLAYING then
			zb.GiveRole(target, GetGlobalString("ZB_EventRole", "Player"), Color(190, 15, 15))
		end

		BroadcastEventers()
	end
end)

concommand.Add("zb_event_end", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	if zb.ROUND_PLAYING then
		MODE:EndRound()
		if IsValid(ply) then ply:ChatPrint("Ending the event round...") end
	elseif IsValid(ply) then
		ply:ChatPrint("No event round is currently active.")
	end
end)

function MODE:PlayerDeath()
end

function MODE:CanSpawn()
end

function MODE:EndRound()
	timer.Simple(2, function()
		net.Start("event_end")
		local ent = zb:CheckAlive(true)[1]
		net.WriteEntity(IsValid(ent) and ent:Alive() and ent or NULL)
		net.Broadcast()
	end)
end
