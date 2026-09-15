local MODE = MODE

MODE.name = "event"
MODE.PrintName = "Event"
MODE.LootSpawn = true
MODE.GuiltDisabled = true
MODE.randomSpawns = true

MODE.ForBigMaps = true
MODE.Chance = 0

MODE.EndLogicType = 2 
MODE.EventersList = {} 
MODE.LootEnabled = true

local radius = nil
local mapsize = 7500

util.AddNetworkString("event_start")
util.AddNetworkString("event_end")
util.AddNetworkString("event_eventers_update")
util.AddNetworkString("event_loot_update")
util.AddNetworkString("event_loot_sync")
util.AddNetworkString("event_loot_add")
util.AddNetworkString("event_loot_remove")
util.AddNetworkString("event_loot_request")

function MODE:CanLaunch()
    return true
end

function MODE:Intermission()
	game.CleanUpMap()

	for k, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then
			continue
		end
		
		ApplyAppearance(ply)
		ply:SetupTeam(0)
	end

	local rndpoints = zb.GetMapPoints("RandomSpawns")
	zonepoint = table.Random(rndpoints)

	net.Start("event_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	local AlivePlyTbl = {}
	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if ply.organism and ply.organism.incapacitated then continue end
		AlivePlyTbl[#AlivePlyTbl + 1] = ply
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

function MODE:RoundStart()
    self.EventersList = {}
    for _, ply in player.Iterator() do
        if ply:IsAdmin() then
            self.EventersList[ply:SteamID()] = true
        end
    end
    
    net.Start("event_eventers_update")
    local data = {}
    for id, _ in pairs(self.EventersList) do
        table.insert(data, id)
    end
    net.WriteTable(data)
    net.Broadcast()

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		ply:SetSuppressPickupNotices(true)
		ply.noSound = true
		local hands = ply:Give("weapon_hands_sh")
		ply:SelectWeapon("weapon_hands_sh")

		timer.Simple(0.1,function()
			ply.noSound = false
		end)

		ply:SetSuppressPickupNotices(false)
        
        if self.EventersList[ply:SteamID()] then
            zb.GiveRole(ply, "Eventer", Color(50, 200, 50))
        else
            zb.GiveRole(ply, GetGlobalString("ZB_EventRole","Player"), Color(190,15,15))
        end
	end

    -- Chudmorse: Event uses the normal Z-City loot-spawn system.
    -- Load the saved Event table when the round starts, then let
    -- sv_lootspawn.lua handle spawning through MODE.LootSpawn.
    if not self._LootTableLoaded then
        self:LoadLootTable()
    end
    self.LootSpawn = self.LootEnabled
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundThink()
    -- The shared SpawnTheBoxes timer in sv_lootspawn.lua handles Event loot.
    -- Keeping this synced allows zb_event_loot to toggle it live.
    self.LootSpawn = self.LootEnabled
    
	if (zb.ROUND_START or 0) + 20 < CurTime() then
		-- radius = (mapsize * math.max(( (zb.ROUND_START + 300) - CurTime()) / 300,0.025))
		-- for _, ent in ents.Iterator() do
		-- 	if ent:GetPos():Distance( zonepoint and zonepoint.pos or Vector(0,0,0)) > radius then
		-- 		MakeDissolver( ent, ent:GetPos(), 0 )
		-- 	end
		-- end
	end
end

MODE.LootTable = {
    {50, {
        {4,"weapon_leadpipe"},
        {3,"weapon_hg_crowbar"},
        {2,"weapon_hatchet"},
        {1,"weapon_hg_axe"},
        {1,"weapon_hg_crossbow"},
    }},
    {50, {
        {9,"*ammo*"},
        {9,"weapon_hk_usp"},
        {8,"weapon_revolver357"},
        {8,"weapon_deagle"},
        {8,"weapon_doublebarrel_short"},
        {8,"weapon_doublebarrel"},
        {8,"weapon_remington870"},
        {8,"weapon_glock18c"},
        {7,"weapon_mp5"},
        {6,"weapon_xm1014"},
        {6,"ent_armor_vest3"},
        {5,"ent_armor_helmet1"},
        {5,"weapon_mp7"},
        {5,"weapon_sks"},
        {5,"ent_armor_vest4"},
        {5,"weapon_hg_molotov_tpik"},
        {5,"weapon_hg_pipebomb_tpik"},
        {5,"weapon_claymore"},
        {5,"weapon_hg_f1_tpik"},
        {5,"weapon_traitor_ied"},
        {5,"weapon_hg_slam"},
        {5,"weapon_hg_legacy_grenade_shg"},
        {5,"weapon_hg_grenade_tpik"},
        {5,"weapon_ptrd"},
        {5,"weapon_akm"},
        {5,"weapon_m98b"},
        {2,"weapon_hg_rpg"},
        {3,"weapon_sr25"},
    }},
}

MODE.CustomLootTable = {
    {50, {}}
}

function MODE:GetCustomLootEntries()
    self.CustomLootTable = istable(self.CustomLootTable) and self.CustomLootTable or {{50, {}}}
    self.CustomLootTable[1] = istable(self.CustomLootTable[1]) and self.CustomLootTable[1] or {50, {}}
    self.CustomLootTable[1][2] = istable(self.CustomLootTable[1][2]) and self.CustomLootTable[1][2] or {}
    return self.CustomLootTable[1][2]
end

function MODE:GetLootTable()
    local custom = self:GetCustomLootEntries()
    if #custom > 0 then
        return custom
    end
    
    return self.LootTable[2][2]
end

net.Receive("event_loot_request", function(len, ply)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE:GetCustomLootEntries())
    net.Send(ply)
end)

local serverIdentifier = string.Trim(string.lower(GetConVar("hostname"):GetString()))
serverIdentifier = string.gsub(serverIdentifier, "[^%w]", "_")

function MODE:SaveLootTable()
    if not file.Exists("zbattle", "DATA") then
        file.CreateDir("zbattle")
    end
    
    if not file.Exists("zbattle/event_loot", "DATA") then
        file.CreateDir("zbattle/event_loot")
    end
    
    local data = util.TableToJSON(self.CustomLootTable)
    file.Write("zbattle/event_loot/loot_table_" .. serverIdentifier .. ".txt", data)
    print("[Event Mode] Loot table saved for server: " .. serverIdentifier)
end

function MODE:LoadLootTable()
    local path = "zbattle/event_loot/loot_table_" .. serverIdentifier .. ".txt"

    if not file.Exists(path, "DATA") then
        print("[Event Mode] No saved loot table found for server: " .. serverIdentifier)
        self.CustomLootTable = {{50, {}}}
        self._LootTableLoaded = true
        return
    end
    
    local data = file.Read(path, "DATA")
    if not data or data == "" then
        print("[Event Mode] Empty or corrupt loot table file for server: " .. serverIdentifier)
        self.CustomLootTable = {{50, {}}}
        self._LootTableLoaded = true
        return
    end
    
    local success, loadedTable = pcall(util.JSONToTable, data)
    if not success or not istable(loadedTable) then
        print("[Event Mode] Failed to parse loot table JSON for server: " .. serverIdentifier)
        self.CustomLootTable = {{50, {}}}
        self._LootTableLoaded = true
        return
    end

    -- Accept both the current nested format and a plain weighted-item list.
    if istable(loadedTable[1]) and istable(loadedTable[1][2]) then
        self.CustomLootTable = loadedTable
    elseif istable(loadedTable[1]) and isnumber(loadedTable[1][1]) and isstring(loadedTable[1][2]) then
        self.CustomLootTable = {{50, loadedTable}}
    else
        print("[Event Mode] Saved loot table has an unsupported format; using defaults")
        self.CustomLootTable = {{50, {}}}
    end

    self._LootTableLoaded = true
    print("[Event Mode] Loot table loaded for server: " .. serverIdentifier .. " with " .. #self:GetCustomLootEntries() .. " items")
end

timer.Simple(0, function()
    if MODE and MODE.LoadLootTable then
        MODE:LoadLootTable()
    end
end)

net.Receive("event_loot_add", function(len, ply)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    local itemData = net.ReadTable()
    
    if not itemData or not itemData.weight or not itemData.class then return end
	if #MODE:GetCustomLootEntries() >= 128 then return end
	if not isnumber(itemData.weight) or itemData.weight < 1 or itemData.weight > 1000 then return end
	if not isstring(itemData.class) or #itemData.class > 96 or (not scripted_ents.GetStored(itemData.class) and not weapons.GetStored(itemData.class)) then return end
    
    table.insert(MODE:GetCustomLootEntries(), {itemData.weight, itemData.class})
    
    MODE:SaveLootTable()
    
    local recipients = {}
    for _, p in player.Iterator() do
        if p:IsAdmin() or MODE.EventersList[p:SteamID()] then
            table.insert(recipients, p)
        end
    end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE:GetCustomLootEntries())
    net.Send(recipients)
    
    ply:ChatPrint("Added item: " .. itemData.class .. " with weight " .. itemData.weight)
end)

net.Receive("event_loot_remove", function(len, ply)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    local itemIndex = net.ReadUInt(16)
    
    local customLoot = MODE:GetCustomLootEntries()
    if not customLoot[itemIndex] then return end
    
    local removedItem = customLoot[itemIndex][2]
    table.remove(customLoot, itemIndex)
    
    MODE:SaveLootTable()
    
    local recipients = {}
    for _, p in player.Iterator() do
        if p:IsAdmin() or MODE.EventersList[p:SteamID()] then
            table.insert(recipients, p)
        end
    end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE:GetCustomLootEntries())
    net.Send(recipients)
    
    ply:ChatPrint("Removed item: " .. removedItem)
end)

concommand.Add("zb_event_loot_reset", function(ply, _, _, _)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then return end
    
    MODE.CustomLootTable = {
        {50, {}}
    }
    
    MODE:SaveLootTable()
    
    local recipients = {}
    for _, p in player.Iterator() do
		if p:IsAdmin() or MODE.EventersList[p:SteamID()] then
            table.insert(recipients, p)
        end
    end
    
    net.Start("event_loot_sync")
    net.WriteTable(MODE:GetCustomLootEntries())
    net.Send(recipients)
    
    ply:ChatPrint("Loot table has been reset")
end)

concommand.Add("zb_event_loot_save", function(ply, _, _, _)
    if not ply:IsAdmin() then return end
    
    MODE:SaveLootTable()
    ply:ChatPrint("Loot table saved for server: " .. serverIdentifier)
end)

concommand.Add("zb_event_lootpoll", function(ply, _, _, _)
    if not ply:IsAdmin() and not MODE.EventersList[ply:SteamID()] then
        ply:ChatPrint("You don't have access to this command")
        return
    end
    
    net.Start("event_loot_request")
    net.Send(ply)
end)

concommand.Add("zb_event_name", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    SetGlobalString("ZB_EventName", args)
end)

concommand.Add("zb_event_role", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    SetGlobalString("ZB_EventRole", args)
end)

concommand.Add("zb_event_objective", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    SetGlobalString("ZB_EventObjective", args)
end)

concommand.Add("zb_event_endlogic", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    local logicType = tonumber(args) or 2
    logicType = math.Clamp(logicType, 1, 3)
    MODE.EndLogicType = logicType
    ply:ChatPrint("Event end logic set to: " .. logicType)
end)

concommand.Add("zb_event_loot", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    
    local enabled = tonumber(args) == 1
    MODE.LootEnabled = enabled
    MODE.LootSpawn = enabled
    
    ply:ChatPrint("Event loot " .. (enabled and "enabled" or "disabled"))
end)

hook.Add("PlayerInitialSpawn", "ZB_EventLootSync", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) and (ply:IsAdmin() or MODE.EventersList[ply:SteamID()]) then
            net.Start("event_loot_sync")
            net.WriteTable(MODE:GetCustomLootEntries())
            net.Send(ply)
            
        end
    end)
end)

hook.Add("HG_PlayerSay", "ZB_EventLootCommand", function(ply, txtTbl, text)
    if string.lower(text) == "!eventloot" and (ply:IsAdmin() or MODE.EventersList[ply:SteamID()]) then
        ply:ConCommand("zb_event_loot_menu")
        txtTbl[1] = ""
    end
end)

hook.Add("InitPostEntity", "ZB_EventLootInitCheck", function()
    timer.Simple(0, function()
        if MODE and not MODE._LootTableLoaded then
            MODE:LoadLootTable()
        end
    end)
end)

concommand.Add("zb_event_eventer_add", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    local target = player.GetBySteamID(args) or player.GetByID(tonumber(args) or 0)
    
    if IsValid(target) then
        MODE.EventersList[target:SteamID()] = true
        ply:ChatPrint("Added " .. target:Nick() .. " as an eventer")
        
        if zb.ROUND_PLAYING then
            zb.GiveRole(target, "Eventer", Color(50, 200, 50))
        end
        
        net.Start("event_eventers_update")
        local data = {}
        for id, _ in pairs(MODE.EventersList) do
            table.insert(data, id)
        end
        net.WriteTable(data)
        net.Broadcast()
    end
end)

concommand.Add("zb_event_eventer_remove", function(ply, _, _, args)
    if not ply:IsAdmin() then return end
    local target = player.GetBySteamID(args) or player.GetByID(tonumber(args) or 0)
    
    if IsValid(target) then
        MODE.EventersList[target:SteamID()] = nil
        ply:ChatPrint("Removed " .. target:Nick() .. " as an eventer")
        
        if zb.ROUND_PLAYING then
            zb.GiveRole(target, GetGlobalString("ZB_EventRole","Player"), Color(190,15,15))
        end
        
        net.Start("event_eventers_update")
        local data = {}
        for id, _ in pairs(MODE.EventersList) do
            table.insert(data, id)
        end
        net.WriteTable(data)
        net.Broadcast()
    end
end)

concommand.Add("zb_event_end", function(ply, _, _, _)
    if not ply:IsAdmin() then return end
    
    if zb.ROUND_PLAYING then
        MODE:EndRound()
        ply:ChatPrint("Ending the event round...")
    else
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
