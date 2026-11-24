-- ALT / BAN EVASION DETECTION
-- Every player's PC gets a hidden random ID (saved in their GMod data folder + cookies, cl_alts.lua).
-- We remember which accounts have used which PC. Then:
--   * an account joins from a PC that a BANNED account has used  -> it's auto-banned too ("ban evasion")
--   * an account gets banned (ZAC or ULX)                         -> every other account seen on that PC
--                                                                    is banned with it
--   * family-shared accounts are NEVER banned for it (owner banned or not) - only noted in the log
-- Saved in data/zac/devices.json. Unban an alt as normal (zac unban / ULX); to stop an account being
-- linked again, also run:  zac unlink <steamid>
-- Accounts are stored by SteamID (STEAM_0:x:y); old SteamID64 entries are converted on load.
local PATH = "zac/devices.json"
local D = { tags = {}, bySid = {} }
do
	local t = ZAC.JSONLoadIDs(file.Read(PATH, "DATA") or "")
	if istable(t) then D.tags = istable(t.tags) and t.tags or {} D.bySid = istable(t.bySid) and t.bySid or {} end
end
ZAC.Devices = D
local function save() timer.Create("zac_devices_save", 2, 1, function() file.CreateDir("zac") file.Write(PATH, util.TableToJSON(D)) end) end
hook.Add("ShutDown", "zac_devices_save", function() file.Write(PATH, util.TableToJSON(D)) end)
do -- old SteamID64 keys -> SteamID
	local n = 0
	local by = {}
	for k, v in pairs(D.bySid) do
		local sid = ZAC.SID(tostring(k)) or tostring(k)
		if sid ~= k then n = n + 1 end
		by[sid] = by[sid] or {}
		if istable(v) then for tag in pairs(v) do by[sid][tag] = true end end
	end
	D.bySid = by
	for tag, set in pairs(D.tags) do
		local ns = {}
		if istable(set) then
			for k in pairs(set) do
				local sid = ZAC.SID(tostring(k)) or tostring(k)
				if sid ~= k then n = n + 1 end
				ns[sid] = true
			end
		end
		D.tags[tag] = ns
	end
	if n > 0 then save() end
end

util.AddNetworkString("zac_dev")
util.AddNetworkString("zac_dev_set")

local function hasULib() return ULib ~= nil and istable(ULib.bans) end
-- id = SteamID or SteamID64
local function isBanned(id)
	local sid = ZAC.SID(id)
	if not sid then return false end
	local b = ZAC.Access and ZAC.Access.bans and ZAC.Access.bans[sid]
	if b and b.expires and os.time() >= b.expires then b = nil end -- timed ban already over
	if b then return true, b.reason, b.expires end
	if hasULib() then
		local u = ULib.bans[sid]
		if u then
			local unb = tonumber(u.unban) or 0
			if unb == 0 or unb > os.time() then return true, u.reason end
		end
	end
	return false
end
ZAC.IsBannedSid = isBanned

local function link(tag, sid)
	D.tags[tag] = D.tags[tag] or {}
	D.bySid[sid] = D.bySid[sid] or {}
	if D.tags[tag][sid] and D.bySid[sid][tag] then return end
	D.tags[tag][sid] = true
	D.bySid[sid][tag] = true
	save()
end

-- every account (SteamID) that has shared a PC with this one (not including it)
function ZAC.LinkedAccounts(id)
	local sid = ZAC.SID(id) or id
	local out = {}
	for tag in pairs(D.bySid[sid] or {}) do
		for other in pairs(D.tags[tag] or {}) do if other ~= sid then out[other] = true end end
	end
	return out
end

local function newTag()
	local t = {}
	for i = 1, 32 do t[i] = string.format("%x", math.random(0, 15)) end
	return table.concat(t)
end

local function check(ply, tag)
	local me = ply:SteamID()
	for other in pairs(D.tags[tag] or {}) do
		if other ~= me then
			local banned, _, expires = isBanned(other)
			if banned then
				local who = (ZAC.Access.bans[other] and ZAC.Access.bans[other].name) or other
				local reason = "Ban evasion (alt of " .. who .. " " .. other .. ") - appeal in the discord"
				ZAC.Log("access", "Alt of a banned account: " .. ZAC.Who(ply) .. " shares a PC with " .. who .. " (" .. other .. ") - banned",
					"Device: " .. tag, ply)
				-- dodging a timed ban only earns the time that was left on it, not a permanent ban
				local left = expires and math.max(1, (expires - os.time()) / 60) or nil
				ZAC.Ban(me, reason, ply:Nick(), nil, "alt detection", nil, left)
				return true
			end
		end
	end
end

net.Receive("zac_dev", function(_, ply)
	if ply.ZACDevDone then return end
	ply.ZACDevDone = true
	local tag = string.lower(string.sub(net.ReadString() or "", 1, 64))
	if not string.match(tag, "^%x+$") or #tag ~= 32 then
		tag = newTag()
		net.Start("zac_dev_set") net.WriteString(tag) net.Send(ply)
	end
	if ply:IsBot() then return end
	local me = ZAC.SID(ply:SteamID())
	if not me then return end
	ply.ZACDevice = tag
	link(tag, me)
	check(ply, tag)
end)

-- banning someone bans every account seen on the same PC
local banning = false
local function banLinked(id, reason, minutes)
	local sid = ZAC.SID(id)
	if banning or not sid then return end
	banning = true
	for other in pairs(ZAC.LinkedAccounts(sid)) do
		if not isBanned(other) then
			ZAC.Log("access", "Banned " .. other .. " too: same PC as banned " .. sid)
			ZAC.Ban(other, "Ban evasion (same PC as " .. sid .. ") - appeal in the discord", nil, nil, "alt detection", nil, minutes)
		end
	end
	banning = false
end
local origBan = ZAC.Ban
ZAC.Ban = function(id, reason, name, ip, by, admin, minutes)
	origBan(id, reason, name, ip, by, admin, minutes)
	banLinked(id, reason, minutes) -- a timed ban stays timed on the linked accounts too
end
hook.Add("ULibPlayerBanned", "zac_alts", function(steamid)
	local sid = ZAC.SID(steamid)
	if sid then timer.Simple(0, function() banLinked(sid) end) end
end)

-- zac unlink <steamid|steamid64|name>: forget which PCs this account used (e.g. a wrongly linked sibling)
ZAC.AdminActions.unlink = function(admin, target)
	local s = string.Trim(target or "")
	if ZAC.SID(s) then s = ZAC.SID(s) else local p = ZAC.FindPlayer(s) s = IsValid(p) and p:SteamID() or s end
	local n = 0
	for tag in pairs(D.bySid[s] or {}) do
		if D.tags[tag] then D.tags[tag][s] = nil end
		n = n + 1
	end
	D.bySid[s] = nil
	save()
	local m = "Unlinked " .. tostring(s) .. " from " .. n .. " device(s)."
	if IsValid(admin) then admin:ChatPrint("[AC] " .. m) else print("[AC] " .. m) end
	ZAC.Log("admin", (IsValid(admin) and ZAC.Who(admin) or "Console") .. " unlinked devices of " .. tostring(s))
end
-- zac alts <name|steamid|steamid64>: list accounts that shared a PC with this one
ZAC.AdminActions.alts = function(admin, target)
	local s = string.Trim(target or "")
	if ZAC.SID(s) then s = ZAC.SID(s) else local p = ZAC.FindPlayer(s) s = IsValid(p) and p:SteamID() or s end
	local list = {}
	for other in pairs(ZAC.LinkedAccounts(s)) do list[#list + 1] = other .. (isBanned(other) and " (BANNED)" or "") end
	local m = (#list == 0) and ("No other accounts seen on " .. tostring(s) .. "'s PC.") or ("Same PC as " .. tostring(s) .. ": " .. table.concat(list, ", "))
	if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. m) admin:ChatPrint("[AC] Printed to console.") else print("[AC] " .. m) end
end
