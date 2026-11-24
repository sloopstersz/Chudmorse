local cfg = ZAC.Config
local PATH = "zac/access.json"

-- Bans and the whitelist are saved by SteamID (STEAM_0:1:2345), not SteamID64: a SteamID is
-- plain text, so it never gets rounded when the file is read back (the old SteamID64 keys did,
-- which is how bans could stop matching after a restart). Everything that calls in here may pass
-- either form - ZAC.SID turns it into a SteamID.
function ZAC.SID(id)
	id = string.Trim(tostring(id or ""))
	if string.match(id, "^STEAM_%d:%d:%d+$") then return "STEAM_0:" .. string.sub(id, 9) end
	if string.match(id, "^7656%d+$") then
		local s = util.SteamIDFrom64(id)
		if s and s ~= "STEAM_0:0:0" then return s end
	end
	return nil
end
function ZAC.SID64(id)
	local s = ZAC.SID(id)
	return s and util.SteamIDTo64(s) or nil
end

local A = { ips = {}, bans = {}, ipbans = {}, wl = {} }
local migrated = 0
do
	local raw = file.Read(PATH, "DATA")
	local t = raw and ZAC.JSONLoadIDs(raw)
	if raw and raw ~= "" and not istable(t) then
		-- never overwrite a file we couldn't read: keep a copy for an admin to look at
		file.Write("zac/access_unreadable_" .. os.time() .. ".json", raw)
		ErrorNoHalt("[ZAC] data/" .. PATH .. " couldn't be read - a copy was kept next to it\n")
	end
	if istable(t) then
		A.ips = t.ips or {}
		A.bans = t.bans or {}
		A.ipbans = t.ipbans or {}
		A.wl = t.wl or {}
	end
	-- old files: SteamID64 keys -> SteamID
	for _, tbl in ipairs({ A.bans, A.wl }) do
		local moves = {}
		for k, v in pairs(tbl) do
			local key = tostring(k)
			if not string.match(key, "^STEAM_") and not string.match(key, "^%d+%.%d+%.%d+%.%d+$") then moves[#moves + 1] = { k, v } end
		end
		for _, m in ipairs(moves) do
			local sid = ZAC.SID(tostring(m[1]))
			-- (anything that isn't a SteamID64 is left exactly as it was - never dropped)
			if sid then
				tbl[m[1]] = nil
				if tbl[sid] == nil then tbl[sid] = m[2] end
				migrated = migrated + 1
			end
		end
	end
end
ZAC.Access = A

do
	local lifted = 0
	for sid, b in pairs(A.bans) do
		if b.by == "alt check" or b.by == "ip ban" then A.bans[sid] = nil lifted = lifted + 1 end
	end
	local hadIPs = next(A.ipbans) ~= nil or next(A.ips) ~= nil
	A.ipbans, A.ips = {}, {}
	if lifted > 0 or hadIPs then
		file.Write(PATH, util.TableToJSON(A, true))
		ExtLogZ("[ZAC] alt check removed: lifted " .. lifted .. " alt ban(s)")
	end
end

-- written straight away (a ban must never be lost to a crash or a map change), with the previous
-- file kept as access_backup.json
local function save()
	local json = util.TableToJSON(A, true)
	if not json then ErrorNoHalt("[ZAC] couldn't encode the ban list - not saved\n") return end
	local old = file.Read(PATH, "DATA")
	if old and old ~= "" then file.Write("zac/access_backup.json", old) end
	file.Write(PATH, json)
end
ZAC.SaveAccess = save
if migrated > 0 then save() print("[ZAC] moved " .. migrated .. " ban / whitelist entr" .. (migrated == 1 and "y" or "ies") .. " to SteamID keys") end
hook.Add("ShutDown", "zac_access_save", function() save() end)

local function ipOnly(addr) return string.match(tostring(addr or ""), "^([^:]+)") or "" end

local function sidLabel(sid, name)
	return string.format("%s (%s)", name or "?", sid)
end

-- ===== ULX / ULib sync =====
-- Every ZAC ban is also added to ULib's ban list (so it shows in ULX / xgui), and unbanning in
-- ZAC lifts it there too. Unbanning in ULX lifts the ZAC ban on that player's next join.
-- ULX bans are listed in the ZAC menu's BANS tab as well.
local function hasULib() return ULib ~= nil and ULib.addBan ~= nil and istable(ULib.bans) end

local function ulxBan(sid, reason, name, admin, minutes)
	if not hasULib() then return false end
	ZAC.InUlxBan = true -- sv_discord.lua: ZAC posts its own ban, not the ULX copy
	local ok, err = pcall(ULib.addBan, sid, math.max(0, math.ceil(tonumber(minutes) or 0)), reason, name, IsValid(admin) and admin or nil)
	ZAC.InUlxBan = nil
	if not ok then ErrorNoHalt("[ZAC] couldn't add the ban to ULX: " .. tostring(err) .. "\n") end
	return ok
end

local function ulxUnban(sid, admin)
	if not (hasULib() and ULib.unban) then return end
	local steamid = ZAC.SID(sid)
	if not (steamid and ULib.bans[steamid]) then return end
	local ok, err = pcall(ULib.unban, steamid, IsValid(admin) and admin or nil)
	if not ok then ErrorNoHalt("[ZAC] couldn't lift the ULX ban: " .. tostring(err) .. "\n") end
end
ZAC.ULXUnban = ulxUnban

-- minutes: nil / 0 = permanent, otherwise the ban lifts itself after that long (here and in ULX)
-- id = SteamID or SteamID64
-- MANUAL MODE (zac_manual 1, the default): ZAC never bans or kicks anyone by itself. Everything it would
-- have done (rating / Steam check / alt / slur bans, family-share kicks) is logged + posted to Discord with
-- the command to do it by hand. zac_manual 0 turns the automatic bans back on.
local cvManual = CreateConVar("zac_manual", "1", { FCVAR_ARCHIVE }, "1 = ZAC never bans / kicks on its own (only logs); 0 = automatic bans on", 0, 1)
function ZAC.ManualOnly() return cvManual:GetBool() end
local AUTO_BY = { ["auto-ban"] = true, ["steam check"] = true, ["alt detection"] = true, ["ZAC (auto)"] = true }
-- alts of an account an admin ALREADY banned (same PC / family share of a banned owner) are banned even in manual
-- mode: the ban decision was already made by a person. zac_alt_autoban 0 = only log them like the rest.
local cvAltAuto = CreateConVar("zac_alt_autoban", "1", { FCVAR_ARCHIVE }, "1 = ban alts of banned accounts even in manual mode (same PC / family share)", 0, 1)
local function autoAllowed(by)
	if by == "steam check" then return ZAC.SteamAutoBan and ZAC.SteamAutoBan() end
	if by == "alt detection" then return cvAltAuto:GetBool() end
	return false
end

-- what banned / kicked players are told (zac_ban_message): never the real reason
local cvPublic = CreateConVar("zac_ban_message", "Invalid battlepass", { FCVAR_ARCHIVE }, "What a banned player sees when refused / kicked (the real reason is only in the logs)")
function ZAC.PublicMessage() local m = cvPublic:GetString() return m ~= "" and m or "Invalid battlepass" end

function ZAC.Ban(id, reason, name, ip, by, admin, minutes)
	local sid = ZAC.SID(id)
	if not sid then ErrorNoHalt("[ZAC] ban: not a SteamID: " .. tostring(id) .. "\n") return end
	if AUTO_BY[by] and ZAC.ManualOnly() and not autoAllowed(by) then
		ZAC.Log("access", "NOT BANNED (manual mode): " .. (name or sid) .. " " .. sid .. " - " .. tostring(reason),
			"ZAC would have banned them (" .. tostring(by) .. "). To ban by hand: zac ban " .. sid .. " <reason>", { name = name or "?", sid = sid })
		return
	end
	minutes = tonumber(minutes)
	if minutes and minutes <= 0 then minutes = nil end
	A.bans[sid] = { reason = reason, time = os.time(), name = name, ip = ip, by = by, expires = minutes and (os.time() + math.ceil(minutes * 60)) or nil }
	save() -- saved before anything else can go wrong
	-- the banned player (and ULX's own "you're banned" screen) only ever sees ZAC.PublicMessage: telling them
	-- WHY (alt, family share, VAC...) tells them what to get round. The real reason stays in ZAC's log / bans.
	if ulxBan(sid, ZAC.PublicMessage(), name, admin, minutes) then A.bans[sid].ulx = true save() end
	local ply = player.GetBySteamID(sid)
	if IsValid(ply) then ply:Kick(ZAC.PublicMessage()) end
	return true
end

-- older ZAC bans (from before the sync) are copied into ULX once
hook.Add("InitPostEntity", "zac_ulx_sync", function()
	timer.Simple(5, function()
		if not hasULib() then return end
		local n = 0
		for sid, b in pairs(A.bans) do
			if not b.ulx and not ULib.bans[sid] then
				if ulxBan(sid, b.reason or cfg.BanMessage, b.name) then b.ulx = true n = n + 1 end
			elseif not b.ulx then
				b.ulx = true
			end
		end
		save()
		if n > 0 then print("[ZAC] copied " .. n .. " ban(s) into ULX") end
	end)
end)

hook.Add("CheckPassword", "zac_access", function(sid64, ipport, _, _, name)
	local sid = ZAC.SID(sid64)
	if not sid then return end
	local ban = A.bans[sid]
	-- timed ban that has run out: lift it (and in ULX)
	if ban and ban.expires and os.time() >= ban.expires then
		A.bans[sid] = nil
		save()
		if ban.ulx then ulxUnban(sid) end
		ZAC.Log("access", "Timed ban on " .. sidLabel(sid, name) .. " ran out - let in", nil, { name = name, sid = sid })
		return
	end
	-- synced ban that an admin lifted in ULX: lift it here too
	if ban and ban.ulx and hasULib() and not ULib.bans[sid] then
		A.bans[sid] = nil
		save()
		ZAC.Log("access", "Ban on " .. sidLabel(sid, name) .. " was lifted in ULX - lifted in ZAC too", nil, { name = name, sid = sid })
		return
	end
	if ban then
		ZAC.Log("access", "Refused banned account " .. sidLabel(sid, name) .. ": " .. tostring(ban.reason), nil, { name = name, sid = sid })
		return false, ZAC.PublicMessage() -- not the reason (see ZAC.Ban)
	end
end)

-- family shared accounts are NEVER banned or kicked (owner banned or not): ZAC only notes it in its log
local function checkFamilyShare(ply)
	if not IsValid(ply) or ply:IsBot() then return end
	local owner = ply:OwnerSteamID64()
	if not owner or owner == "0" or owner == "" or owner == ply:SteamID64() then return end
	local banned = ZAC.IsBannedSid and ZAC.IsBannedSid(owner)
	ZAC.Log("access", ZAC.Who(ply) .. " is on a family shared account" .. (banned and " (the owner is banned)" or "") .. " - allowed",
		"Game owner: " .. util.SteamIDFrom64(owner) .. " (" .. owner .. ")", ply)
end

hook.Add("PlayerAuthed", "zac_familyshare", function(ply)
	timer.Simple(0, function() checkFamilyShare(ply) end)
end)
hook.Add("PlayerInitialSpawn", "zac_familyshare", function(ply)
	timer.Simple(5, function() checkFamilyShare(ply) end)
end)

local function reply(admin, text)
	if IsValid(admin) then admin:ChatPrint("[AC] " .. text) else print("[AC] " .. text) end
end

-- name / SteamID / SteamID64 -> SteamID
local function toSid(s)
	s = string.Trim(s or "")
	local sid = ZAC.SID(s)
	if sid then return sid end
	local p = ZAC.FindPlayer(s)
	return IsValid(p) and not p:IsBot() and p:SteamID() or nil
end

ZAC.AdminActions.ban = function(admin, target, reason)
	local sid = toSid(target)
	if not sid then return reply(admin, "No player / SteamID '" .. tostring(target) .. "'.") end
	local p = player.GetBySteamID(sid)
	reason = (reason and reason ~= "") and (reason .. " - please appeal in the discord") or cfg.BanMessage
	ZAC.Ban(sid, reason, IsValid(p) and p:Nick() or nil, IsValid(p) and ipOnly(p:IPAddress()) or nil, ZAC.Who(admin), admin)
	ZAC.Log("admin", ZAC.Who(admin) .. " banned " .. sid .. (IsValid(p) and (" " .. p:Nick()) or ""), "Reason: " .. reason,
		{ name = IsValid(p) and p:Nick() or "?", sid = sid })
	reply(admin, "Banned " .. sid .. ".")
end

ZAC.AdminActions.kick = function(admin, target, reason)
	local p = ZAC.FindPlayer and ZAC.FindPlayer(target)
	if not IsValid(p) then return reply(admin, "No player '" .. tostring(target) .. "' online.") end
	reason = (reason and reason ~= "") and reason or "Kicked by an admin"
	ZAC.Log("admin", ZAC.Who(admin) .. " kicked " .. ZAC.Who(p), "Reason: " .. reason, p)
	p:Kick(reason)
	reply(admin, "Kicked " .. p:Nick() .. ".")
end

ZAC.AdminActions.unban = function(admin, target)
	local sid = toSid(target)
	local inULX = sid and hasULib() and ULib.bans[sid] ~= nil
	if not sid or not (A.bans[sid] or inULX) then return reply(admin, "That account isn't banned.") end
	local b = A.bans[sid] or {}
	local ip, bannedName = b.ip, b.name or (inULX and ULib.bans[sid].name)
	A.bans[sid] = nil
	if ip and A.ipbans[ip] then A.ipbans[ip] = nil end
	save()
	ulxUnban(sid, admin)
	ZAC.Log("admin", ZAC.Who(admin) .. " unbanned " .. sid, nil, { name = bannedName or "?", sid = sid })
	reply(admin, "Unbanned " .. sid .. ".")
end

ZAC.AdminActions.whitelist = function(admin, target)
	target = string.Trim(target or "")
	local key = string.match(target, "^%d+%.%d+%.%d+%.%d+$") and target or toSid(target)
	if not key then return reply(admin, "Give a name, a SteamID or an IP.") end
	A.wl[key] = true
	save()
	ZAC.Log("admin", ZAC.Who(admin) .. " whitelisted " .. key)
	reply(admin, "Whitelisted " .. key .. ".")
end

ZAC.AdminActions.unwhitelist = function(admin, target)
	target = string.Trim(target or "")
	local key = string.match(target, "^%d+%.%d+%.%d+%.%d+$") and target or toSid(target)
	if not key or not A.wl[key] then return reply(admin, "Not whitelisted.") end
	A.wl[key] = nil
	save()
	ZAC.Log("admin", ZAC.Who(admin) .. " removed " .. key .. " from the whitelist")
	reply(admin, "Removed " .. key .. " from the whitelist.")
end

ZAC.AdminActions.bans = function(admin)
	local n = 0
	for sid, b in pairs(A.bans) do
		n = n + 1
		local line = string.format("%s  %s  %s  %s", sid, b.name or "?", os.date("%Y-%m-%d", b.time or 0), b.reason or "")
		if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, line) else print(line) end
	end
	reply(admin, n .. " bans (listed in console).")
end

net.Receive("zac_bans_req", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	local list = {}
	for sid, b in pairs(A.bans) do list[#list + 1] = { sid, b } end
	-- bans made in ULX show up here too
	if hasULib() then
		for steamid, u in pairs(ULib.bans) do
			local sid = ZAC.SID(steamid)
			if sid and not A.bans[sid] and istable(u) then
				local left = tonumber(u.unban) or 0
				local reason = tostring(u.reason or "")
				if left > 0 then reason = reason .. " (until " .. os.date("%Y-%m-%d %H:%M", left) .. ")" end
				list[#list + 1] = { sid, { name = u.name, reason = reason, time = tonumber(u.time) or 0, by = "ULX: " .. tostring(u.admin or "?") } }
			end
		end
	end
	table.sort(list, function(a, b) return (a[2].time or 0) > (b[2].time or 0) end)
	net.Start("zac_bans")
	net.WriteUInt(math.min(#list, 500), 10)
	for i = 1, math.min(#list, 500) do
		local sid, b = list[i][1], list[i][2]
		net.WriteString(sid)
		net.WriteString(b.name or "?")
		net.WriteString(b.reason or "")
		net.WriteUInt(b.time or 0, 32)
		net.WriteString(b.by or "")
	end
	net.Send(ply)
end)
