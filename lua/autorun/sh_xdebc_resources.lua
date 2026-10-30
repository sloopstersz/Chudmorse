if SERVER then
	AddCSLuaFile()
end

XDEBC_MATERIAL_CAP = 40
XDEBC_NAIL_CAP = 50
XDEBC_RESOURCE_PACK = 25
XDEBC_BARRICADE_MATERIAL_COST = 5
XDEBC_BARRICADE_NAIL_COST = 1
XDEBC_SUPPLY_CRATE_MATERIALS = 20
XDEBC_SUPPLY_CRATE_NAILS = 8

if CLIENT then
	local resourceLanguage = string.lower( GetConVar( "gmod_language" ):GetString() ) == "ru" and "ru" or "en"
	language.Add( "xdebc.Category", resourceLanguage == "ru" and "Баррикады" or "Barricade" )
	language.Add( "xdebc.EntityMaterials", resourceLanguage == "ru" and "Материалы для баррикад" or "Barricade Materials" )
	language.Add( "xdebc.EntityNails", resourceLanguage == "ru" and "Гвозди для баррикад" or "Barricade Nails" )
	language.Add( "xdebc.EntitySupplyCrate", resourceLanguage == "ru" and "Ящик припасов" or "Supply Crate" )
end

if SERVER then

	local resourceFlags = bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER )
	CreateConVar( "xdebc_materialcap", tostring( XDEBC_MATERIAL_CAP ), resourceFlags,
		"Maximum materials a player can carry", 1, 200 )
	CreateConVar( "xdebc_nailcap", tostring( XDEBC_NAIL_CAP ), resourceFlags,
		"Maximum nails a player can carry", 1, 200 )
	CreateConVar( "xdebc_crate_materials", tostring( XDEBC_SUPPLY_CRATE_MATERIALS ), resourceFlags,
		"Materials stored in a supply crate", 0, 200 )
	CreateConVar( "xdebc_crate_nails", tostring( XDEBC_SUPPLY_CRATE_NAILS ), resourceFlags,
		"Nails stored in a supply crate", 0, 100 )
	CreateConVar( "xdebc_infinite_resources", "0", resourceFlags,
		"Do not consume materials or nails when building", 0, 1 )

end

local function xdebc_GetResourceCap( resource )
	local cvarName = resource == "Nails" and "xdebc_nailcap" or "xdebc_materialcap"
	local cvar = GetConVar( cvarName )
	return cvar and cvar:GetInt() or ( resource == "Nails" and XDEBC_NAIL_CAP or XDEBC_MATERIAL_CAP )
end

function XDEBC_GetResourceCap( resource )
	return xdebc_GetResourceCap( resource )
end

local function xdebc_GetResourceKey( resource )
	return resource == "Nails" and "XDEBC_Nails" or "XDEBC_Materials"
end

function XDEBC_GetPlayerResource( ply, resource )
	if !IsValid( ply ) or !ply:IsPlayer() then return 0 end
	return math.Clamp( ply:GetNWInt( xdebc_GetResourceKey( resource ), 0 ), 0, xdebc_GetResourceCap( resource ) )
end

function XDEBC_SetPlayerResource( ply, resource, amount )
	if !IsValid( ply ) or !ply:IsPlayer() then return 0 end
	amount = math.Clamp( math.floor( tonumber( amount ) or 0 ), 0, xdebc_GetResourceCap( resource ) )
	ply:SetNWInt( xdebc_GetResourceKey( resource ), amount )
	return amount
end

function XDEBC_AddPlayerResource( ply, resource, amount )
	if !IsValid( ply ) or !ply:IsPlayer() then return 0 end
	local current = XDEBC_GetPlayerResource( ply, resource )
	local added = math.Clamp( math.floor( tonumber( amount ) or 0 ), 0, xdebc_GetResourceCap( resource ) -current )
	XDEBC_SetPlayerResource( ply, resource, current +added )
	return added
end

function XDEBC_TakePlayerResource( ply, resource, amount )
	if !IsValid( ply ) or !ply:IsPlayer() then return false end
	amount = math.max( 0, math.floor( tonumber( amount ) or 0 ) )
	local current = XDEBC_GetPlayerResource( ply, resource )
	if current < amount then return false end
	XDEBC_SetPlayerResource( ply, resource, current -amount )
	return true
end

if SERVER then
	local function xdebc_ClampAllPlayerResources()
		for _, ply in ipairs( player.GetAll() ) do
			XDEBC_SetPlayerResource( ply, "Materials", XDEBC_GetPlayerResource( ply, "Materials" ) )
			XDEBC_SetPlayerResource( ply, "Nails", XDEBC_GetPlayerResource( ply, "Nails" ) )
		end
	end

	cvars.AddChangeCallback( "xdebc_materialcap", xdebc_ClampAllPlayerResources, "xdebc_clamp_material_resources" )
	cvars.AddChangeCallback( "xdebc_nailcap", xdebc_ClampAllPlayerResources, "xdebc_clamp_nail_resources" )

	local function xdebc_InitializePlayerResources( ply )
		if !IsValid( ply ) or !ply:IsPlayer() or ply:GetNWBool( "XDEBC_ResourcesInitialized" ) then return end
		XDEBC_SetPlayerResource( ply, "Materials", XDEBC_GetResourceCap( "Materials" ) )
		XDEBC_SetPlayerResource( ply, "Nails", XDEBC_GetResourceCap( "Nails" ) )
		ply:SetNWBool( "XDEBC_ResourcesInitialized", true )
	end

	-- Restore both supplies on death, before the next respawn. This keeps the
	-- behavior independent of the gamemode's respawn delay.
	hook.Add( "PlayerDeath", "xdebc_restore_resources_on_death", function( ply )
		if !IsValid( ply ) or !ply:IsPlayer() then return end
		XDEBC_SetPlayerResource( ply, "Materials", XDEBC_GetResourceCap( "Materials" ) )
		XDEBC_SetPlayerResource( ply, "Nails", XDEBC_GetResourceCap( "Nails" ) )
	end )

	hook.Add( "PlayerInitialSpawn", "xdebc_initialize_resources", function( ply )
		xdebc_InitializePlayerResources( ply )
	end )

	hook.Add( "PlayerSpawn", "xdebc_initialize_resources_existing", function( ply )
		xdebc_InitializePlayerResources( ply )
	end )
end
