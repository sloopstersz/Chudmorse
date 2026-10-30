if not SERVER then return end

RemSpawnGuard = RemSpawnGuard or {}

local CurTime = CurTime
local istable = istable
local isfunction = isfunction
local IsValid = IsValid

local TAG = "[RemSpawnGuard] "

local cvEnabled = CreateConVar( "rem_spawnguard_enabled", "1", FCVAR_ARCHIVE, TAG .. "master switch for the spawnmenu guard", 0, 1 )
local cvKick = CreateConVar( "rem_spawnguard_kick", "1", FCVAR_ARCHIVE, TAG .. "kick players that keep spamming spawn requests", 0, 1 )
local cvWindow = CreateConVar( "rem_spawnguard_window", "10", FCVAR_ARCHIVE, TAG .. "seconds of the spam counting window", 1, 300 )
local cvCmdKick = CreateConVar( "rem_spawnguard_cmdkick", "300", FCVAR_ARCHIVE, TAG .. "spawn commands a normal player may run per window", 10, 100000 )
local cvCmdRate = CreateConVar( "rem_spawnguard_cmdrate", "40", FCVAR_ARCHIVE, TAG .. "spawn commands a normal player may run per second", 1, 10000 )
local cvHookKick = CreateConVar( "rem_spawnguard_hookkick", "600", FCVAR_ARCHIVE, TAG .. "blocked spawn hook calls per window before a kick", 10, 100000 )

local SpawnHooks = {
	"PlayerGiveSWEP",
	"PlayerSpawnEffect",
	"PlayerSpawnNPC",
	"PlayerSpawnObject",
	"PlayerSpawnProp",
	"PlayerSpawnRagdoll",
	"PlayerSpawnSENT",
	"PlayerSpawnSWEP",
	"PlayerSpawnVehicle",
}

local SpawnCommands = {
	"gm_save",
	"gm_spawn",
	"gm_spawnswep",
	"gm_giveswep",
	"gm_spawnsent",
	"gm_spawnvehicle",
	"gmod_spawnnpc",
}

local function IsPrivileged( ply )
	if not IsValid( ply ) then return true end
	if ply:IsBot() then return true end

	return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function GetState( ply, now )
	local state = ply.rem_spawnguard

	if not istable( state ) then
		state = { tick = now, cmdCount = 0, windowStart = now, windowCount = 0, kicked = false }
		ply.rem_spawnguard = state
	end

	if now - state.tick >= 1 then
		state.tick = now
		state.cmdCount = 0
	end

	if now - state.windowStart > cvWindow:GetInt() then
		state.windowStart = now
		state.windowCount = 0
		state.kicked = false
	end

	return state
end

function RemSpawnGuard.Check( ply, kickLimit, rateLimit )
	if not cvEnabled:GetBool() then return true end
	if IsPrivileged( ply ) then return true end

	local now = CurTime()
	local state = GetState( ply, now )

	state.windowCount = state.windowCount + 1

	if state.windowCount > kickLimit then
		if not state.kicked then
			state.kicked = true

			MsgN( TAG .. ply:Name() .. " (" .. ply:SteamID() .. ") exceeded " .. state.windowCount .. " spawn attempts in " .. cvWindow:GetInt() .. "s" )

			if cvKick:GetBool() then ply:Kick( "Spawn spam" ) end
		end

		return false
	end

	if rateLimit then
		if state.cmdCount >= rateLimit then
			return false
		end

		state.cmdCount = state.cmdCount + 1
	end

	return true
end

hook.Add( "InitPostEntity", "RemSpawnGuard_WrapCommands", function()
	local registered = concommand.GetTable()

	for _, name in ipairs( SpawnCommands ) do
		local original = registered[ name ]

		if not isfunction( original ) then continue end

		concommand.Remove( name )

		concommand.Add( name, function( ply, cmd, args, argsStr )
			if not RemSpawnGuard.Check( ply, cvCmdKick:GetInt(), cvCmdRate:GetInt() ) then return end

			original( ply, cmd, args, argsStr )
		end )
	end
end )

hook.Add( "RemSpawnGuard_Release", "RemSpawnGuard_HooksInit", function()
	for _, name in ipairs( SpawnHooks ) do
		hook.Add( name, "rem_spawnguard_" .. name, function( ply )
			if RemSpawnGuard.Check( ply, cvHookKick:GetInt(), nil ) then return nil end

			return false
		end )
	end
end )

hook.Run( "RemSpawnGuard_Release", true )
