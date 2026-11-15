local MODE = MODE

---------------------------------------------------------------------------
-- Event Setup (Chudmorse style) - server side
--   open with !eventsetup or zb_event_setup
--   (locals only: any function put on MODE becomes a gamemode hook)
---------------------------------------------------------------------------

util.AddNetworkString("event_setup_sync")
util.AddNetworkString("event_setup_open")
util.AddNetworkString("event_setup_action")
util.AddNetworkString("event_setup_notify")

local NAME_MAX, ROLE_MAX, OBJECTIVE_MAX = 48, 32, 160

-- Pre-round eventer picks, merged in by MODE:RoundStart (sv_event.lua)
MODE.QueuedEventers = MODE.QueuedEventers or {}   -- [steamid] = true -> eventer even if not admin
MODE.ExcludedEventers = MODE.ExcludedEventers or {} -- [steamid] = true -> admin that should NOT be an eventer

local function CanSetup(ply)
	if not IsValid(ply) then return true end -- server console
	return ply:IsAdmin()
end

local function IsEventActive()
	local round = CurrentRound and CurrentRound()
	return round ~= nil and round.name == MODE.name and zb.ROUND_STATE == 1
end

local function Clean(text, maxLen)
	if not isstring(text) then return "" end
	text = string.gsub(text, "%c", " ")
	text = string.Trim(text)
	if #text > maxLen then text = string.sub(text, 1, maxLen) end
	return text
end

local function Notify(ply, msg, isError)
	if not IsValid(ply) then
		print("[Event Setup] " .. msg)
		return
	end
	net.Start("event_setup_notify")
	net.WriteString(msg)
	net.WriteBool(isError and true or false)
	net.Send(ply)
end

---------------------------------------------------------------------------
-- Saving (name / role / objective / end logic survive restarts)
---------------------------------------------------------------------------

local SAVE_PATH = "zbattle/event_setup.txt"

local function SaveSetup()
	file.CreateDir("zbattle")
	file.Write(SAVE_PATH, util.TableToJSON({
		name = GetGlobalString("ZB_EventName", "Event"),
		role = GetGlobalString("ZB_EventRole", "Player"),
		objective = GetGlobalString("ZB_EventObjective", ""),
		endLogic = MODE.EndLogicType or 2,
	}, true))
end

local function LoadSetup()
	if not file.Exists(SAVE_PATH, "DATA") then return end
	local ok, data = pcall(util.JSONToTable, file.Read(SAVE_PATH, "DATA") or "")
	if not ok or not istable(data) then return end

	if isstring(data.name) and data.name ~= "" then SetGlobalString("ZB_EventName", Clean(data.name, NAME_MAX)) end
	if isstring(data.role) and data.role ~= "" then SetGlobalString("ZB_EventRole", Clean(data.role, ROLE_MAX)) end
	if isstring(data.objective) then SetGlobalString("ZB_EventObjective", Clean(data.objective, OBJECTIVE_MAX)) end
	MODE.EndLogicType = math.Clamp(math.floor(tonumber(data.endLogic) or 2), 1, 3)
end

hook.Add("Initialize", "ZB_EventSetupLoad", function()
	timer.Simple(1, LoadSetup)
end)
if GAMEMODE then LoadSetup() end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

-- Who will be (or is) an eventer
local function IsEventer(ply)
	local sid = ply:SteamID()
	if IsEventActive() then
		return MODE.EventersList[sid] == true
	end
	if MODE.QueuedEventers[sid] then return true end
	return ply:IsAdmin() and not MODE.ExcludedEventers[sid]
end

local function BuildState()
	local players = {}
	for _, ply in player.Iterator() do
		if not ply:IsBot() then
			players[#players + 1] = {
				sid = ply:SteamID(),
				nick = ply:Nick(),
				admin = ply:IsAdmin(),
				eventer = IsEventer(ply),
				alive = ply:Alive(),
				spectator = ply:Team() == TEAM_SPECTATOR,
			}
		end
	end

	return {
		name = GetGlobalString("ZB_EventName", "Event"),
		role = GetGlobalString("ZB_EventRole", "Player"),
		objective = GetGlobalString("ZB_EventObjective", ""),
		endLogic = MODE.EndLogicType or 2,
		active = IsEventActive(),
		current = zb.CROUND or "",
		nextRound = zb.nextround or "",
		players = players,
	}
end

local function GetAdmins()
	local list = {}
	for _, p in player.Iterator() do
		if CanSetup(p) then list[#list + 1] = p end
	end
	return list
end

local function SyncTo(target)
	net.Start("event_setup_sync")
	net.WriteTable(BuildState())
	net.Send(target or GetAdmins())
end

-- Keep open menus fresh when people join/leave/die
local function SyncSoon()
	timer.Create("ZB_EventSetupSync", 0.5, 1, function() SyncTo() end)
end
hook.Add("PlayerInitialSpawn", "ZB_EventSetupSync", SyncSoon)
hook.Add("PlayerDisconnected", "ZB_EventSetupSync", SyncSoon)
hook.Add("PostPlayerDeath", "ZB_EventSetupSync", SyncSoon)
hook.Add("PlayerSpawn", "ZB_EventSetupSync", SyncSoon)

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local Actions = {}

Actions.details = function(ply)
	local name = Clean(net.ReadString(), NAME_MAX)
	local role = Clean(net.ReadString(), ROLE_MAX)
	local objective = Clean(net.ReadString(), OBJECTIVE_MAX)
	local endLogic = math.Clamp(net.ReadUInt(2), 1, 3)

	SetGlobalString("ZB_EventName", name ~= "" and name or "Event")
	SetGlobalString("ZB_EventRole", role ~= "" and role or "Player")
	SetGlobalString("ZB_EventObjective", objective)
	MODE.EndLogicType = endLogic

	-- Re-label non-eventers if the role changed mid-event
	if IsEventActive() and zb.GiveRole then
		for _, p in player.Iterator() do
			if p:Alive() and not MODE.EventersList[p:SteamID()] then
				zb.GiveRole(p, GetGlobalString("ZB_EventRole", "Player"), Color(190, 15, 15))
			end
		end
	end

	SaveSetup()
	Notify(ply, "Event details saved")
	return true
end

Actions.eventer = function(ply)
	local sid = net.ReadString()
	local make = net.ReadBool()
	local target = player.GetBySteamID(sid)
	if not IsValid(target) or target:IsBot() then
		return Notify(ply, "That player isn't on the server anymore.", true)
	end

	if make then
		MODE.ExcludedEventers[sid] = nil
		if not target:IsAdmin() then MODE.QueuedEventers[sid] = true end
	else
		MODE.QueuedEventers[sid] = nil
		if target:IsAdmin() then MODE.ExcludedEventers[sid] = true end
	end

	if IsEventActive() then
		-- reuse the existing commands so roles/broadcasts stay identical
		concommand.Run(IsValid(ply) and ply or NULL, make and "zb_event_eventer_add" or "zb_event_eventer_remove", {sid}, sid)
	end

	Notify(ply, target:Nick() .. (make and " is now an eventer" or " is no longer an eventer"))
	return true
end

Actions.start = function(ply)
	local now = net.ReadBool()
	if not zb.modes or not zb.modes[MODE.name] then
		return Notify(ply, "Event mode isn't loaded.", true)
	end

	NextRound(MODE.name, true)

	if now then
		if zb.ROUND_STATE == 1 then
			zb:EndRound()
			Notify(ply, "Ending this round - the event starts next")
		else
			Notify(ply, "Event queued - it starts when the next round begins")
		end
	else
		Notify(ply, "Event set as the next round")
	end
	return true
end

Actions["end"] = function(ply)
	if not IsEventActive() then
		return Notify(ply, "No event round is running.", true)
	end
	zb:EndRound() -- also runs MODE:EndRound()
	Notify(ply, "Ending the event round")
	return true
end

Actions.refresh = function() return true end

net.Receive("event_setup_action", function(len, ply)
	if not CanSetup(ply) then return end

	ply.ZB_NextSetupAction = ply.ZB_NextSetupAction or 0
	if ply.ZB_NextSetupAction > SysTime() then return end
	ply.ZB_NextSetupAction = SysTime() + 0.1

	local action = Actions[net.ReadString()]
	if not action then return end

	if action(ply) then
		SyncTo()
	end
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

local function OpenFor(ply)
	if not IsValid(ply) then return end
	if not CanSetup(ply) then
		ply:ChatPrint("You don't have access to this command")
		return
	end
	SyncTo(ply)
	net.Start("event_setup_open")
	net.Send(ply)
end

concommand.Add("zb_event_setup", OpenFor)

hook.Add("HG_PlayerSay", "ZB_EventSetupCommand", function(ply, txtTbl, text)
	local cmd = string.lower(string.Trim(text))
	if cmd == "!eventsetup" or cmd == "/eventsetup" then
		OpenFor(ply)
		txtTbl[1] = ""
	end
end)
