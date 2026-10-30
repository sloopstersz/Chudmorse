zb = zb or {}
hg = hg or {}
zb.ROUND_STATE = zb.ROUND_STATE or 0
--0 = players can join, 1 = round is active, 2 = endround

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
AddCSLuaFile("loader.lua")
include("loader.lua")

local PLAYER = FindMetaTable("Player")
function PLAYER:CanSpawn()
	return ( CurrentRound and CurrentRound() and CurrentRound().CanSpawn and CurrentRound():CanSpawn(self)) or (zb.ROUND_STATE == 0)
end

util.AddNetworkString("ZB_SpectatePlayer")

function PLAYER:GiveEquipment(team_)
end

local default_spawns = {
	"info_player_deathmatch", "info_player_combine", "info_player_rebel",
	"info_player_counterterrorist", "info_player_terrorist", "info_player_axis",
	"info_player_allies", "gmod_player_start", "info_player_teamspawn",
	"ins_spawnpoint", "aoc_spawnpoint", "dys_spawn_point", "info_player_pirate",
	"info_player_viking", "info_player_knight", "diprip_start_team_blue", "diprip_start_team_red",
	"info_player_red", "info_player_blue", "info_player_coop", "info_player_human", "info_player_zombie",
	"info_player_zombiemaster", "info_player_fof", "info_player_desperado", "info_player_vigilante", "info_survivor_rescue"
}

local vecup = Vector(0, 0, 64)

local spawners = {}

local function getRandSpawn()
	spawners = {}

	if #zb.GetMapPoints( "Spawnpoint" ) > 0 then
		for k, v in RandomPairs(zb.GetMapPoints( "Spawnpoint" )) do
			spawners[#spawners + 1] = v.pos
		end
	else
		for i, ent in RandomPairs(ents.FindByClass("info_player_start")) do
			spawners[#spawners + 1] = ent:GetPos()
		end
		
		for i, str in ipairs(default_spawns) do
			for k, v in RandomPairs(ents.FindByClass(str)) do
				spawners[#spawners + 1] = v:GetPos()
			end
		end

		--[[for k, v in ipairs(navmesh.GetAllNavAreas()) do
			local Randompos = v:GetCenter()
			local SpawnPos = Randompos + vecup

			spawners[#spawners + 1] = SpawnPos
		end--]]
	end
end

getRandSpawn()

hook.Add("InitPostEntity", "OwOmooooove", function()
	getRandSpawn()
end)

hook.Add("ZB_PreRoundStart", "reset_spawns", function()
	zb.ctspawn = nil
	zb.tspawn = nil
end)

function zb:GetTeamSpawn(ply)
	local team_ = ply:Team()

	local team0spawns, team1spawns = CurrentRound():GetTeamSpawn()
	
	if !team0spawns or !next(team0spawns) then
		team0spawns = {zb:GetRandomSpawn()}
	end

	if !team1spawns or !next(team1spawns) then
		team1spawns = {zb:GetRandomSpawn()}
	end

	local pos
	
	if team_ == 0 then
		if !zb.tspawn then
			zb.tspawn = table.Random(team0spawns)
			pos = zb.tspawn
		else
			pos = hg.tpPlayer(zb.tspawn, ply, math.Clamp(ply:EntIndex() % 24 + 1, 1, 24), 0)
		end

		return pos
	else
		if !zb.ctspawn then
			zb.ctspawn = table.Random(team1spawns)
			pos = zb.ctspawn
		else
			pos = hg.tpPlayer(zb.ctspawn, ply, math.Clamp(ply:EntIndex() % 24 + 1, 1, 24), 0)
		end

		return pos
	end

	ErrorNoHalt("TEAM SPAWN COULDN'T BE FOUND. INVALID TEAM")

	return team0spawns[1]
end

local check_playerspawns = function(SpawnPos, ply, tolerance)
	if !ply:Alive() then return true end
	
	local usedPos = ply:GetPos()

	local checkdist = (1024 / (math.pow(2, tolerance)))
	if usedPos:DistToSqr(SpawnPos) < checkdist * checkdist then
		return false
	end
	
	return true
end

function zb:GetRandomSpawn(target, spawns)
	if !spawns or table.IsEmpty(spawns) then
		spawns = spawners
	end
	
	return zb:FurthestFromEveryone(spawns, player.GetAll(), check_playerspawns)
end

function zb:FurthestFromEveryone(chooseTbl, restrictTbl, func, iStart, iEnd)
	if not chooseTbl or table.IsEmpty(chooseTbl) then
		chooseTbl = spawners
	end

	if not restrictTbl then
		restrictTbl = player.GetAll()

		func = check_playerspawns
	end
	
	for tolerance = (iStart or 1), (iEnd or 5) do
		for i, SpawnPos in RandomPairs(chooseTbl) do
			if not SpawnPos then continue end
			
			local allow

			for _, value in ipairs(restrictTbl) do
				allow = func(SpawnPos, value, tolerance)
				if allow == false then break end
			end
			
			if allow then
				return SpawnPos
			end
		end
	end
	
	local SpawnPos = table.Random(chooseTbl)
	
	return SpawnPos
end

function PLAYER:GetRandomSpawn()
	local spawnPos = zb:GetRandomSpawn(self)
	
	if not spawnPos then return end
	
	self:SetPos(spawnPos)
end

function GM:PlayerSelectSpawn(ply, transition)
end

local function PlayerSelectSpawn(ply, transition)
	if CurrentRound().randomSpawns then
		local randSpawn = zb:GetRandomSpawn()
		ply:SetPos(randSpawn)

		return
	end

	local spawnPos = zb:GetTeamSpawn(ply)

	if not spawnPos then
		local randSpawn = zb:GetRandomSpawn()
		ply:SetPos(randSpawn)
	else
		ply:SetPos(spawnPos)
	end
end

function PLAYER:SetupTeam(team_)
	self:SetTeam(team_)
	
	hg.CreateInv(self)

	PlayerSelectSpawn(self)
end

function GM:PlayerSpawn(ply)
    ply:SuppressHint("OpeningMenu")
    ply:SuppressHint("Annoy1")
    ply:SuppressHint("Annoy2")

    if OverrideSpawn then return end

    ply.viewmode = 3
    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_WALK)

    if ply.initialspawn then
        ply:KillSilent()
        ply:SetTeam(1001)
        ply.initialspawn = nil
        return
    end

    if CurrentRound() and not CurrentRound().OverrideSpawn then
        ply:SetTeam(1001)
        ApplyAppearance(ply,nil,nil,nil,true)
        ply:SetTeam(zb:BalancedChoice(0, 1))
    end

end

function GM:PlayerDisconnected()
end

RunConsoleCommand("mp_show_voice_icons", "0")

local hullscale = Vector(1, 1, 1)

util.AddNetworkString("ZB_ChooseSpecPly")

-- Explicitly distribute both client entry points from the dedicated server.
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("homigrad/cl_camera.lua")
util.AddNetworkString("ChudSpectatorStateV2")
util.AddNetworkString("ChudSpectatorInputV2")
util.AddNetworkString("ChudSpectatorReadyV2")

local function SpectatorTargets(observer)
    local targets = {}
    for _, target in player.Iterator() do
        if target ~= observer and target:Alive() and target:Team() ~= TEAM_SPECTATOR then
            targets[#targets + 1] = target
        end
    end
    table.sort(targets, function(a, b) return a:EntIndex() < b:EntIndex() end)
    return targets
end

local function UpdateSpectator(ply, key)
    if not IsValid(ply) or ply:Alive() then return end
    ply.ChudSpectating = true
    local targets = SpectatorTargets(ply)
    local previous = ply.chosenSpectEntity
    local index = table.KeyFromValue(targets, previous)
    local mode = math.Clamp(tonumber(ply.viewmode) or 1, 1, 3)
    if #targets == 0 then
        index, mode = nil, 3
    else
        if key == IN_ATTACK or key == IN_ATTACK2 then
            if index then
                index = ((index - 1 + (key == IN_ATTACK and 1 or -1)) % #targets) + 1
            else
                index = key == IN_ATTACK and 1 or #targets
            end
            -- Keep the chosen camera mode, as in version 3; R cycles modes.
        else
            index = index or math.Clamp(ply.chosenspect or 1, 1, #targets)
            if key == IN_RELOAD then mode = mode % 3 + 1 end
        end
    end
    local target = index and targets[index] or nil
    ply.chosenspect = index or 1
    ply.chosenSpectEntity = target
    ply.viewmode = mode
    ply:SetNWEntity("spect", target or NULL)
    ply:SetNWInt("viewmode", mode)


    if target ~= ply.lastSpectTarget or mode ~= ply.ChudLastSpectMode or (ply.ChudSpectatorSyncAt or 0) <= CurTime() then
        net.Start("ChudSpectatorStateV2")
        -- Indices resolve once distant targets enter the spectator's PVS.
        net.WriteUInt(IsValid(target) and target:EntIndex() or 0, 16)
        net.WriteUInt(IsValid(previous) and previous:EntIndex() or 0, 16)
        net.WriteUInt(mode, 2)
        net.Send(ply)
        ply.lastSpectTarget = target
        ply.ChudLastSpectMode = mode
        ply.ChudSpectatorSyncAt = CurTime() + 1
    end

    -- The shared camera handles follow modes; the engine only handles free flight.
    if ply:GetObserverMode() ~= OBS_MODE_ROAMING then ply:Spectate(OBS_MODE_ROAMING) end
    local moveType = mode == 3 and MOVETYPE_NOCLIP or MOVETYPE_NONE
    if ply:GetMoveType() ~= moveType then ply:SetMoveType(moveType) end
    if target and mode ~= 3 then
        local character = hg.GetCurrentCharacter(target)
        ply:SetPos(IsValid(character) and character:GetPos() or target:GetPos())
        if mode == 1 and target.organism and (ply.netsendtime or 0) < CurTime() then
            ply.netsendtime = CurTime() + 1
            hg.send_organism(target.organism, ply)
        end
    end

end

local function SafeUpdateSpectator(ply, key)
    local ok, err = pcall(UpdateSpectator, ply, key)
    if not ok and (ply.ChudSpectatorErrorAt or 0) <= CurTime() then
        ply.ChudSpectatorErrorAt = CurTime() + 5
        ErrorNoHalt("[Spectator] " .. tostring(err) .. "\n")
    end
end

local function SpectatorInput(ply, key)
    if not IsValid(ply) or ply:Alive() then return end
    if key ~= IN_ATTACK and key ~= IN_ATTACK2 and key ~= IN_RELOAD then return end
    ply.ChudSpectatorKeyTimes = ply.ChudSpectatorKeyTimes or {}
    if (ply.ChudSpectatorKeyTimes[key] or 0) > CurTime() then return end
    ply.ChudSpectatorKeyTimes[key] = CurTime() + 0.08
    SafeUpdateSpectator(ply, key)
end

-- Console commands travel separately from addon net-message limits.
concommand.Add("zb_spectator_input", function(ply, command, args)
    SpectatorInput(ply, tonumber(args[1]))
end)

net.Receive("ChudSpectatorInputV2", function(len, ply)
    if len < 32 then return end
    SpectatorInput(ply, net.ReadInt(32))
end)

hook.Add("SetupPlayerVisibility", "spectPVS", function(ply)
    if ply:Alive() or ply.viewmode == 3 then return end
    local target = ply.chosenSpectEntity
    if IsValid(target) then
        AddOriginToPVS(target:EyePos())
        local character = hg.GetCurrentCharacter(target)
        if IsValid(character) then AddOriginToPVS(character:GetPos()) end
    end
end)

-- PlayerDeathThink hooks may return false to prevent respawning. Do not depend on
-- their execution order for spectator networking, target recovery or movement.
hook.Remove("PlayerDeathThink", "spectNetwork")
timer.Create("ChudSharedSpectatorUpdate", 0.05, 0, function()
    for _, ply in player.Iterator() do
        if not ply:Alive() then
            SafeUpdateSpectator(ply)
        elseif ply.ChudSpectating then
            ply.ChudSpectating = nil
            ply.chosenSpectEntity, ply.lastSpectTarget, ply.ChudLastSpectMode = nil, nil, nil
            ply.ChudNextSpectatorInput = nil
            ply.ChudSpectatorKeyTimes = nil
            ply.ChudSpectatorSyncAt = nil
            ply:SetNWEntity("spect", NULL)
            ply:SetNWInt("viewmode", 3)
            ply:UnSpectate()
            if ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
        end
    end
end)

net.Receive("ZB_ChooseSpecPly", function(len, ply)
    if len >= 32 then SpectatorInput(ply, net.ReadInt(32)) end
end)

net.Receive("ChudSpectatorReadyV2", function(len, ply)
    if not IsValid(ply) or ply:Alive() then return end
    if (ply.ChudNextSpectatorReady or 0) > CurTime() then return end
    ply.ChudNextSpectatorReady = CurTime() + 0.5
    ply.ChudSpectatorSyncAt = 0
    SafeUpdateSpectator(ply)
end)

function GM:PlayerDeathThink(ply)
	if not ply:CanSpawn() then return false end
end

function GM:PlayerDeath(ply)
    ply.lastSpectTarget, ply.chosenSpectEntity, ply.ChudLastSpectMode = nil, nil, nil
    ply.chosenspect, ply.viewmode = 1, 1
    ply.ChudNextSpectatorInput = nil
    ply.ChudSpectatorKeyTimes = nil
    SafeUpdateSpectator(ply)
end

hg.addbot = hg.addbot or false

function GM:PlayerInitialSpawn(ply)
	ply.initialspawn = true

	if #player.GetAll() == 1 then
		RunConsoleCommand("bot")
		hg.addbot = true
		zb:EndRound()
	end

	if #player.GetHumans() > 1 and hg.addbot then
		for i,bot in pairs(player.GetListByName("bot")) do
			RunConsoleCommand("kick",bot:Name())
		end
		hg.addbot = false
	end
end

function GM:IsSpawnpointSuitable( pl, spawnpointent, bMakeSuitable )
	return true
end

util.AddNetworkString("ZB_SpecMode")
net.Receive("ZB_SpecMode",function(len,ply)
    local bool = net.ReadBool()
    if CurrentRound() and CurrentRound().name == "vip" then
        if bool and ply:Team() ~= TEAM_SPECTATOR then
            if ply:Alive() then ply:Kill() end
            ply:SetTeam(TEAM_SPECTATOR)
        elseif not bool and ply:Team() == TEAM_SPECTATOR then
            -- Join the participant pool for the next round, without spawning.
            ply:SetTeam(1)
        end
        return
    end

	local enable = !hook.Run("ZB_JoinSpectators", ply)

	if enable and bool and ply:Team() != TEAM_SPECTATOR then if ply:Alive() then ply:Kill() end ply:SetTeam(TEAM_SPECTATOR) PrintMessage(HUD_PRINTTALK,ply:Name().." joined the spectators.") 
	elseif ply:Team() != 1 then
		ply:SetTeam(1) PrintMessage(HUD_PRINTTALK,ply:Name().." joined the players.")  
	end
end)

--[[
local tbl = {}
local maps = file.Find( "maps/*.bsp", "GAME" )

for _, map in ipairs( maps ) do
	map = map:sub( 1, -5 )
	table.insert( tbl, map )
end

for i, map in ipairs(ents.FindByClass("coop_mapend")) do
	if table.HasValue(tbl, map.map) then
		print(map.map)
	end
end
--]]

util.AddNetworkString("updtime")

function hg.UpdateRoundTime(time, time2, time3)
	zb.ROUND_TIME = time or zb.ROUND_TIME
	zb.ROUND_START = time2 or zb.ROUND_START or CurTime()
	zb.ROUND_BEGIN = time3 or zb.ROUND_BEGIN or CurTime() + 5
	net.Start("updtime")
	net.WriteFloat(zb.ROUND_TIME)
	net.WriteFloat(zb.ROUND_START)
	net.WriteFloat(zb.ROUND_BEGIN)
	net.Broadcast()
end

local function getspawnpos()
    local tab = {}
    local tbl = ents.FindByClass("info_player_start")
    for k, v in pairs(tbl) do
        if not v:HasSpawnFlags(1) then continue end
        tab[#tab + 1] = v:GetPos()
    end
    return tab[1] or tbl[1]:GetPos()
end

local maps = {}

hook.Add("PostCleanupMap","changelevel_generate",function()
	if CurrentRound().name != "coop" then return end
	local player_pos = getspawnpos()
    local dist = 0
    local map
    
    local maps = {}
    for i, map in pairs(ents.FindByClass("trigger_changelevel")) do
        local min, max = map:WorldSpaceAABB()
        local tdmlPos = max - ((max - min) / 2)

        maps[map] = tdmlPos
    end
    
    for ent, pos in pairs(maps) do
		if ent.map == game.GetMap() then continue end
        local dist2 = pos:Distance(player_pos)
        --print(dist,dist2,ent.map,pos,player_pos)
        if dist2 > dist then
            dist = dist2
            map = ent
        end
    end--выбираем самый дальний ченджлевел

    if not IsValid(map) then map = select(2, table.Random(maps)) end
    
    print("Next map is: "..map.map)

    local min, max = map:WorldSpaceAABB()
    local tdmlPos = max - ((max - min) / 2)
    local tdml = ents.Create("coop_mapend")
    tdml:SetPos(tdmlPos)
	tdml:SetAngles(map:GetAngles())
    tdml.min = min
    tdml.max = max
    tdml.map = map.map
    tdml:Spawn()
    tdml:Activate()
	--map:Remove()
end)

function GM:EntityKeyValue( ent, key, value )

	if ( ( ent:GetClass() == "trigger_changelevel" ) && ( key == "map" ) ) then
		ent.map = value
		ent:AddEFlags(2)
		ent:AddFlags(2)
		--[[
		maps[ent] = true
		
		timer.Create("fuckmapchanges",4,1,function()
			local random_player = table.Random(player.GetAll())
			if not IsValid(random_player) then return end
			local player_pos = random_player:GetPos()
			local dist = 0
			local map
			
			for ent, i in pairs(maps) do
				--print(ent.map,i)
				local dist2 = ent:GetPos():Distance(player_pos)
				if dist2 > dist then
					dist = dist2
					map = ent
				end
			end--выбираем самый дальний ченджлевел
			print("Next map is: "..map.map)
			if not map then map = maps[1] end

			local min, max = map:WorldSpaceAABB()
			tdmlPos = max - ((max - min) / 2)
			local tdml = ents.Create("coop_mapend")
			tdml:SetPos(tdmlPos)
			tdml.min = min
			tdml.max = max
			tdml.map = map.map
			tdml:Spawn()
			tdml:Activate()

			maps = {}
		end)--]]
	end

	if ( ent:GetClass() == "npc_combine_s" ) then
		ent:SetLagCompensated(true)
	end

	if ( ( ent:GetClass() == "npc_combine_s" ) && ( key == "additionalequipment" ) && ( value == "weapon_shotgun" ) ) then
	
		ent:SetSkin( 1 )
	
	end

end

hook.Add("CanProperty", "AntiExploit", function(ply, property, ent)
	if(!ply:IsAdmin())then
		return false
	end
end)
