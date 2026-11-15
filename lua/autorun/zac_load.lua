ZAC = ZAC or {}

function ExtLogZ(...)
	if ExtLog then ExtLog(...) end
end

local SHARED = { "zac/sh_config.lua" }
local SERVER_FILES = {
	"zac/sv_config.lua",
	"zac/sv_secrets.lua",
	"zac/sv_core.lua",
	"zac/sv_access.lua",
	"zac/sv_keys.lua",
	"zac/sv_damage.lua",
	"zac/sv_view.lua",
	"zac/sv_aim.lua",
	"zac/sv_rating.lua",
	"zac/sv_speed.lua",
	"zac/sv_screengrab.lua",
	"zac/sv_realnames.lua",
	"zac/sv_chat.lua",
	"zac/sv_wordban.lua",
	"zac/sv_alts.lua",
	"zac/sv_autosg.lua",
	"zac/sv_discord.lua",
	"zac/sv_steam.lua",
	"zac/sv_autoban.lua",
	"zac/sv_airstuck.lua",
	"zac/sv_walltrack.lua",
	"zac/sv_spectate.lua",
	"zac/sv_integrity.lua",
}
local CLIENT_FILES = {
	"zac/cl_ui.lua",
	"zac/cl_keys.lua",
	"zac/cl_screengrab.lua",
	"zac/cl_menu.lua",
	"zac/cl_view.lua",
	"zac/cl_alts.lua",
	"zac/cl_spectate.lua",
	"zac/cl_integrity.lua",
	"zac/cl_cmd.lua",
}

if SERVER then
	for _, f in ipairs(SHARED) do AddCSLuaFile(f) end
	for _, f in ipairs(CLIENT_FILES) do AddCSLuaFile(f) end
	for _, f in ipairs(SHARED) do include(f) end
	for _, f in ipairs(SERVER_FILES) do
		-- sv_secrets.lua holds the Discord webhooks + Steam key: server only, never AddCSLuaFile'd (players never get it)
		if file.Exists(f, "LUA") then include(f)
		elseif f ~= "zac/sv_secrets.lua" then ErrorNoHalt("[ZAC] missing " .. f .. "\n")
		else print("[ZAC] No sv_secrets.lua - copy sv_secrets.example.lua to sv_secrets.lua and fill it in (Discord + Steam checks are off until then)") end
	end
else
	for _, f in ipairs(SHARED) do include(f) end
	for _, f in ipairs(CLIENT_FILES) do include(f) end
end
