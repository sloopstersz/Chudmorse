-- "zac" in an admin's console, with autocomplete: type  zac integrity  (or kick / ban / netwatch...)
-- and a space, and every online player shows up in the list - keep typing to filter, TAB / arrows to pick.
-- The words go to the server (sv_core.lua ZAC.RunCmd), which checks you're an admin.
local SUBS = {
	"integrity", "netwatch", "screengrab", "steamcheck", "alts", "spectate", "unspectate",
	"kick", "ban", "unban", "bans", "whitelist", "unwhitelist", "rating_clear", "unlink", "discord_test",
}
-- these take a player as the next word
local TARGET = {
	integrity = true, netwatch = true, screengrab = true, steamcheck = true, alts = true, spectate = true,
	kick = true, ban = true, whitelist = true, rating_clear = true, unlink = true, unban = false,
}
-- these want a SteamID rather than a name (the player may have names with spaces / copies)
local BYID = { rating_clear = true, unlink = true }

local function q(s) return '"' .. string.Replace(s, '"', "'") .. '"' end

local function players(sub, filter)
	local out = {}
	filter = string.lower(filter or "")
	local list = player.GetAll()
	table.sort(list, function(a, b) return string.lower(a:Nick()) < string.lower(b:Nick()) end)
	for _, p in ipairs(list) do
		local nick, sid = p:Nick(), p:SteamID()
		if filter == "" or string.find(string.lower(nick), filter, 1, true) or string.find(string.lower(sid), filter, 1, true) then
			out[#out + 1] = "zac " .. sub .. " " .. (BYID[sub] and sid or q(nick))
		end
	end
	return out
end

local function complete(_, argStr)
	local str = string.TrimLeft(argStr or "")
	local sub, rest = string.match(str, "^(%S+)%s+(.*)$")
	if not sub then
		local out, low = {}, string.lower(str)
		for _, s in ipairs(SUBS) do
			if string.sub(s, 1, #low) == low then out[#out + 1] = "zac " .. s end
		end
		return out
	end
	sub = string.lower(sub)
	if not TARGET[sub] then return {} end
	return players(sub, string.Trim(string.gsub(rest, '"', "")))
end

concommand.Add("zac", function(_, _, args)
	local sub = args[1] and string.lower(args[1])
	-- a command that needs a player but none given: print everyone, ready to copy
	if sub and TARGET[sub] and not args[2] then
		print("---- zac " .. sub .. ": pick a player (or type  zac " .. sub .. "  + space for the list) ----")
		for _, line in ipairs(players(sub, "")) do print("  " .. line) end
		return
	end
	net.Start("zac_cmd")
	local n = math.min(#args, 12)
	net.WriteUInt(n, 4)
	for i = 1, n do net.WriteString(string.sub(args[i], 1, 200)) end
	net.SendToServer()
end, complete, "ZAC anti-cheat. Type  zac integrity  + space to pick a player.")
