-- DISCORD ALERTS: the cheat-bot log channel. Posts (as embeds) when:
--   * a player's cheat rating goes up to SUSPECT / CHEATING (with the reasons)
--   * anyone is banned (by an admin, the rating auto-ban, the Steam checks...)
--   * aim flags (at most one post per player every 2 minutes, with how many flags came in since)
--   * a screengrab fails or a player's screen functions were replaced
--   * airstuck / tick manipulation, Steam check results, admin spectating
-- The webhook URL lives in sv_secrets.lua (server only) and is never sent to players.
-- Console:  zac discord_test       sends a test post
local cfg = ZAC.Config
local D = cfg.Discord or {}

local COL = { red = 0xD64034, orange = 0xE8AC3C, yellow = 0xE8D43C, green = 0x78C864, blue = 0x5A8CDC, grey = 0xC8C6B8 }
ZAC.DiscordColors = COL

-- GMod's own HTTP is refused by Discord on some hosts; a reqwest / CHTTP binary module in
-- garrysmod/lua/bin is used instead when one is installed (same as the EFZ Discord posts).
local httpFn, httpName = HTTP, "GMod HTTP"
do
	for _, name in ipairs({ "reqwest", "chttp" }) do
		if util.IsBinaryModuleInstalled and util.IsBinaryModuleInstalled(name) then
			local ok = pcall(require, name)
			local fn = ok and (name == "reqwest" and reqwest or CHTTP) or nil
			if fn then httpFn, httpName = fn, name break end
		end
	end
end

local function webhook()
	local s = ZAC.Secrets and ZAC.Secrets.DiscordWebhook or ""
	return string.Trim(tostring(s or ""))
end

local function clean(s, max)
	s = tostring(s or "")
	s = string.gsub(s, "@", "@\226\128\139") -- no pings from player names
	if #s > max then s = string.sub(s, 1, max - 3) .. "..." end
	return s
end

local queue, busy, retryAt, busySince = {}, false, 0, 0

-- zac_discord_relay 1: send through the webhook relay (webhook.lewisakura.moe) instead of discord.com - for hosts
-- whose IP Discord refuses (403 / 40333). Off by default (the relay sees the webhook link).
local cvRelay = CreateConVar("zac_discord_relay", "0", FCVAR_ARCHIVE + FCVAR_PROTECTED, "Send Discord posts through webhook.lewisakura.moe (for blocked hosts)")
local function realURL(u)
	if cvRelay:GetBool() then
		u = string.gsub(u, "^https://discord%.com/api/webhooks/", "https://webhook.lewisakura.moe/api/webhooks/")
		u = string.gsub(u, "^https://discordapp%.com/api/webhooks/", "https://webhook.lewisakura.moe/api/webhooks/")
	end
	return u
end

-- GMod's JSON can write whole numbers as 123.0; Discord wants integers (embed colour)
local function toJSON(t)
	local j = util.TableToJSON(t) or "{}"
	j = string.gsub(j, '("color"%s*:%s*)(%d+)%.0+([,}])', "%1%2%3")
	return j
end

local function send(body)
	local u = body._url or webhook()
	local test, tply = body._test, body._ply
	body._url, body._test, body._ply = nil, nil, nil
	local function report(msg) if test and ZAC.DiscordTestResult then ZAC.DiscordTestResult(tply, test, msg) end end
	if u == "" then busy = false return end
	busy, busySince = true, SysTime()
	local ok, err = pcall(httpFn, {
		url = realURL(u), method = "POST", type = "application/json", body = toJSON(body),
		-- Discord's Cloudflare refuses requests without a proper bot User-Agent (403, code 40333)
		headers = { ["Content-Type"] = "application/json", ["User-Agent"] = "DiscordBot (https://github.com/DJfarent/ESCAPE-FROM-ZCITY, 1.0)" },
		success = function(code, resp)
			busy = false
			if test then print("[ZAC] " .. test .. ": Discord answered " .. tostring(code) .. (code == 204 and " = posted OK" or "")) end
			if code == 204 or code == 200 then report("OK - posted (" .. tostring(code) .. ")")
			elseif code == 403 then report("403 - Discord blocks this server's IP. Turn the relay on and test again.")
			elseif code == 404 or code == 401 then report(code .. " - the webhook link is wrong or was deleted.")
			elseif code ~= 429 then report(tostring(code) .. " - " .. string.sub(tostring(resp or ""), 1, 120)) end
			if code == 429 then
				-- rate limited: put it back and wait
				table.insert(queue, 1, body)
				local t = util.JSONToTable(resp or "") or {}
				retryAt = SysTime() + math.Clamp(tonumber(t.retry_after) or 2, 1, 30)
			elseif code and code >= 400 then
				print("[ZAC] Discord said " .. tostring(code) .. " (" .. httpName .. "): " .. string.sub(tostring(resp or ""), 1, 300))
				if code == 403 then
					print("[ZAC] 403 = Discord is refusing this server's connection (host IP blocked). Fix: zac_discord_relay 1 (sends through webhook.lewisakura.moe), or install the reqwest / CHTTP module in garrysmod/lua/bin.")
				elseif code == 404 or code == 401 then
					print("[ZAC] " .. code .. " = that webhook link is wrong or was deleted: make a new webhook and put it in sv_secrets.lua.")
				elseif code == 400 then
					print("[ZAC] 400 = Discord didn't like the message itself (tell Claude the text above).")
				end
			end
		end,
		failed = function(reason)
			busy = false
			report("FAILED - " .. tostring(reason) .. " (the host may block outgoing HTTPS: try the relay)")
			print("[ZAC] Discord post failed (" .. httpName .. "): " .. tostring(reason)
				.. (test and (" - " .. test) or "") .. ". 'unsuccessful' usually = the host blocks outgoing HTTPS or Discord: try zac_discord_relay 1.")
		end,
	})
	if not ok then busy = false print("[ZAC] Discord post error: " .. tostring(err)) end
end

timer.Create("zac_discord", 1.2, 0, function()
	if busy and SysTime() - busySince > 20 then busy = false print("[ZAC] Discord post got no answer in 20 s, moving on") end
	if busy or #queue == 0 or SysTime() < retryAt then return end
	send(table.remove(queue, 1))
end)

-- who = a player, or { name = , sid = }
function ZAC.DiscordPlayerField(who, label)
	local name, sid
	if IsEntity(who) and IsValid(who) and who:IsPlayer() then name, sid = who:Nick(), who:SteamID()
	elseif istable(who) then name, sid = who.name, who.sid end
	if not sid then return nil end
	local sid64 = ZAC.SID64 and ZAC.SID64(sid) or util.SteamIDTo64(sid)
	return { name = label or "Player", inline = true,
		value = clean(name or "?", 100) .. "\n`" .. sid .. "`\n[Steam profile](https://steamcommunity.com/profiles/" .. tostring(sid64) .. ")" }
end

-- title, description, colour (number), fields (list of { name, value, inline })
function ZAC.Discord(title, desc, color, fields)
	if D.Enabled == false or webhook() == "" then return end
	if #queue > 60 then table.remove(queue, 1) end
	local f = {}
	for _, x in ipairs(fields or {}) do
		if x and x.value and x.value ~= "" then
			f[#f + 1] = { name = clean(x.name or "-", 250), value = clean(x.value, 1000), inline = x.inline == true }
		end
	end
	queue[#queue + 1] = {
		username = D.Username or "ZAC Anti-Cheat",
		allowed_mentions = { parse = {} },
		embeds = { {
			title = clean(title, 250),
			description = clean(desc or "", 3800),
			color = color or COL.red,
			fields = #f > 0 and f or nil,
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			footer = { text = clean(GetHostName(), 100) },
		} },
	}
end

-- ===== what gets posted =====

local LEVELS = { "LEGIT", "SUSPECT", "CHEATING" }

hook.Add("ZACRatingRaised", "zac_discord", function(ply, level)
	if not IsValid(ply) or level < 2 then return end
	local p = ZAC.Ratings and ZAC.Ratings[ply:SteamID()]
	local _, score, reasons = 0, 0, {}
	if p and ZAC.RatingOf then _, score, reasons = ZAC.RatingOf(p) end
	ZAC.Discord((level >= 3 and "CHEATING: " or "Suspect: ") .. ply:Nick(),
		"Cheat rating went up to **" .. LEVELS[level] .. "** (score " .. tostring(score) .. ").\n\n" .. table.concat(reasons or {}, "\n"),
		level >= 3 and COL.red or COL.orange,
		{ ZAC.DiscordPlayerField(ply), { name = "Ping", value = tostring(ply:Ping()) .. " ms", inline = true } })
end)

-- every ban (admins, auto-bans, Steam checks) goes through ZAC.Ban
if ZAC.Ban and not ZAC.BanUnwrapped then
	ZAC.BanUnwrapped = ZAC.Ban
	ZAC.Ban = function(id, reason, name, ip, by, admin, minutes)
		local r = ZAC.BanUnwrapped(id, reason, name, ip, by, admin, minutes)
		local sid = ZAC.SID(id)
		-- (manual mode: a ban ZAC only logged is not posted as "Banned")
		if sid and r == true then
			local mins = tonumber(minutes)
			local length = (mins and mins > 0) and (mins >= 1440 and string.format("%.0f day(s)", mins / 1440) or (math.ceil(mins) .. " minute(s)")) or "Permanent"
			ZAC.Discord("Banned: " .. tostring(name or sid), tostring(reason or ""), COL.red, {
				ZAC.DiscordPlayerField({ name = name or "?", sid = sid }),
				{ name = "Length", value = length, inline = true },
				{ name = "By", value = IsValid(admin) and (admin:Nick() .. " (" .. admin:SteamID() .. ")") or tostring(by or "ZAC"), inline = true },
			})
		end
		return r
	end
end

-- bans / unbans made in ULX (ulx ban, ulx banid, xgui, ulx unban...) - posted too, with who did it
local function ulxWho(admin) return IsValid(admin) and (admin:Nick() .. " (" .. admin:SteamID() .. ")") or "Console" end
local function wrapULib()
	if not (ULib and ULib.addBan) or ZAC.ULibWrapped then return end
	ZAC.ULibWrapped = true
	local addBan = ULib.addBan
	ULib.addBan = function(steamid, time, reason, name, admin, ...)
		local r = { addBan(steamid, time, reason, name, admin, ...) }
		if not ZAC.InUlxBan then
			local mins = tonumber(time) or 0
			local length = mins > 0 and (mins >= 1440 and string.format("%.0f day(s)", mins / 1440) or (math.ceil(mins) .. " minute(s)")) or "Permanent"
			local sid = ZAC.SID(steamid) or tostring(steamid)
			ZAC.Discord("Banned (ULX): " .. tostring(name or sid), tostring(reason or "(no reason)"), COL.red, {
				ZAC.DiscordPlayerField({ name = name or "?", sid = sid }),
				{ name = "Length", value = length, inline = true },
				{ name = "By", value = ulxWho(admin), inline = true },
			})
		end
		return unpack(r)
	end
	if ULib.unban then
		local unban = ULib.unban
		ULib.unban = function(steamid, admin, ...)
			local had = istable(ULib.bans) and ULib.bans[steamid]
			local r = { unban(steamid, admin, ...) }
			if had then
				ZAC.Discord("Unbanned: " .. tostring(had.name or steamid), "", COL.green or COL.red, {
					ZAC.DiscordPlayerField({ name = had.name or "?", sid = tostring(steamid) }),
					{ name = "By", value = ulxWho(admin), inline = true },
				})
			end
			return unpack(r)
		end
	end
end
hook.Add("InitPostEntity", "zac_discord_ulx", function() timer.Simple(2, wrapULib) end)
timer.Simple(5, wrapULib)

-- aim flags: one post per player per 2 minutes (the rest are counted into the next one)
local aimSeen = {}
hook.Add("ZACLogged", "zac_discord", function(e)
	if e.k == "aim" and e.a and e.a.sid ~= "" then
		if string.find(e.m, " is now rated ", 1, true) then return end -- posted by ZACRatingRaised
		-- single airstuck incidents only go to the log; Discord gets the flag when they repeat (sv_airstuck.lua)
		if string.find(e.m, " held movement for ", 1, true) then return end
		local s = aimSeen[e.a.sid] or { next = 0, n = 0 }
		aimSeen[e.a.sid] = s
		s.n = s.n + 1
		if CurTime() < s.next then return end
		s.next = CurTime() + (D.AimEvery or 120)
		local extra = s.n > 1 and ("\n\n(+" .. (s.n - 1) .. " more flag(s) on this player in the last few minutes)") or ""
		s.n = 0
		ZAC.Discord("Aim flag: " .. e.a.name, e.m .. extra, COL.yellow, { ZAC.DiscordPlayerField(e.a) })
	elseif e.k == "screen" then
		local low = string.lower(e.m)
		if string.find(low, "failed", 1, true) or string.find(low, "replaced", 1, true) or string.find(low, "isn't the game's own", 1, true)
			or string.find(low, "swapped", 1, true) then
			ZAC.Discord("Screengrab warning", e.m, COL.orange, { e.a and ZAC.DiscordPlayerField(e.a) or nil })
		end
	end
end)

ZAC.AdminActions.discord_test = function(admin)
	if webhook() == "" then
		local t = "No webhook set (lua/zac/sv_secrets.lua)."
		if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. t) else print("[AC] " .. t) end
		return
	end
	ZAC.Discord("ZAC test post", "If you can read this, the cheat-bot log channel works. (sent with " .. httpName .. ")", COL.green,
		{ IsValid(admin) and ZAC.DiscordPlayerField(admin, "Sent by") or { name = "Sent by", value = "Server console", inline = true } })
	local t = "Test post queued."
	if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. t) else print("[AC] " .. t) end
end

hook.Add("InitPostEntity", "zac_discord_online", function()
	timer.Simple(10, function()
		if D.PostOnStart == false then return end
		ZAC.Discord("Anti-cheat online", "Map: " .. game.GetMap(), COL.blue)
	end)
end)


-- SERVER STATUS channel (second webhook: ZAC.Secrets.StatusWebhook): ONE message that keeps editing itself (no
-- spam): map, players, mode, who's online, the last event (online / round started / map change). The message id is
-- remembered in data/zac/status_msg.json, so after a restart the same message is edited again. Deleted in Discord =
-- a new one is posted and that one is edited from then on.
local function statusHook() return string.Trim(tostring(ZAC.Secrets and ZAC.Secrets.StatusWebhook or "")) end
local STATUS_FILE = "zac/status_msg.txt"
-- (stored as plain "webhookid=messageid" lines: GMod's JSON turns the long ids into rounded numbers, the edit
-- then pointed at a message that doesn't exist and a NEW one got posted on every map change)
local statusMsg = {}
for k, v in string.gmatch(file.Read(STATUS_FILE, "DATA") or "", "(%d+)=(%d+)") do statusMsg[k] = v end
local function msgIdOf(resp) return string.match(resp or "", '"id"%s*:%s*"(%d+)"') end
local function hookKey(u) return string.match(u, "/webhooks/(%d+)/") or "x" end
local function saveStatusMsg()
	file.CreateDir("zac")
	local out = {}
	for k, v in pairs(statusMsg) do out[#out + 1] = tostring(k) .. "=" .. tostring(v) end
	file.Write(STATUS_FILE, table.concat(out, "\n"))
end
local HEADERS = { ["Content-Type"] = "application/json", ["User-Agent"] = "DiscordBot (https://github.com/DJfarent/ESCAPE-FROM-ZCITY, 1.0)" }

local statusPending, statusBusy, statusNext = nil, false, 0
local lastEvent, lastEventT = "Server online", os.time()

-- round stats for the status message: rounds today / all time and the last 5 rounds (data/zac/status_stats.txt)
local STATS_FILE = "zac/status_stats.txt"
local stats = util.JSONToTable(file.Read(STATS_FILE, "DATA") or "") or {}
stats.total = tonumber(stats.total) or 0
stats.today = tonumber(stats.today) or 0
stats.day = stats.day or os.date("%Y-%m-%d")
stats.last = istable(stats.last) and stats.last or {}
local function saveStats() file.CreateDir("zac") file.Write(STATS_FILE, util.TableToJSON(stats)) end
local roundStartT, roundMap, roundMode = 0, nil, nil

local function modeName(id)
	local m = zb and zb.modes and zb.modes[id or ""]
	return m and m.PrintName or tostring(id or "?")
end
local function xpShort(x)
	x = tonumber(x) or 0
	if x >= 1000000 then return string.format("%.1fm", x / 1000000) end
	if x >= 1000 then return string.format("%.1fk", x / 1000) end
	return tostring(math.floor(x))
end
local function pad(s, n) s = tostring(s) return string.rep(" ", math.max(0, n - #s)) .. s end
local function plain(s) return (string.gsub(tostring(s or ""), "[`*_~|>]", "")) end

local function statusFields()
	local plys = {}
	for _, p in player.Iterator() do if not p:IsBot() then plys[#plys + 1] = p end end
	local n = #plys
	local inRound = zb and zb.ROUND_STATE == 1
	-- who's playing: highest XP first, with what they're doing
	table.sort(plys, function(a, b) return (tonumber(a.GetExp and a:GetExp()) or 0) > (tonumber(b.GetExp and b:GetExp()) or 0) end)
	local who = {}
	for i, p in ipairs(plys) do
		if i > 20 then who[#who + 1] = "*+" .. (n - 20) .. " more*" break end
		local state = p:Team() == TEAM_SPECTATOR and "spectating" or (not inRound and "waiting") or (p:Alive() and "alive") or "dead"
		who[#who + 1] = "`" .. pad(xpShort(p.GetExp and p:GetExp()), 6) .. " XP` " .. plain(p:Nick()) .. " - " .. state
	end
	local last = {}
	for i = 1, math.min(5, #stats.last) do
		local r = stats.last[i]
		last[#last + 1] = "`#" .. r.n .. "` " .. r.when .. "  **" .. plain(r.mode) .. "** on " .. plain(r.map) .. " - " .. r.len .. ", " .. r.players .. " players"
	end
	local stage = "Between rounds"
	if inRound then
		local left = (zb.ROUND_START or 0) + (zb.ROUND_TIME or 0) - CurTime()
		stage = modeName(zb.CROUND) .. (left > 0 and left < 36000 and string.format(" (%d:%02d left)", left / 60, left % 60) or "")
	end
	return {
		{ name = "Map", value = game.GetMap(), inline = true },
		{ name = "Round", value = stage, inline = true },
		{ name = "Players", value = n .. " / " .. game.MaxPlayers(), inline = true },
		{ name = "Played today", value = stats.today .. " rounds (" .. stats.total .. " all time)", inline = false },
		{ name = "Who's playing", value = #who > 0 and table.concat(who, "\n") or "*nobody right now*", inline = false },
		{ name = "Last rounds", value = table.concat(last, "\n"), inline = false },
		{ name = "Join", value = "`connect " .. game.GetIPAddress() .. "`", inline = false },
	}
end

-- the line under the title: what's going on right now
local function statusDesc()
	if zb and zb.ROUND_STATE == 1 then
		local alive = 0
		for _, p in player.Iterator() do if p:Alive() and p:Team() ~= TEAM_SPECTATOR then alive = alive + 1 end end
		return "**Round #" .. stats.total .. " - " .. modeName(zb.CROUND) .. " in progress**\n" .. alive .. " alive on **" .. game.GetMap() .. "**"
	end
	return "**Waiting for the next round** on **" .. game.GetMap() .. "**\nLast: " .. lastEvent .. " <t:" .. lastEventT .. ":R>"
end

hook.Add("ZB_StartRound", "zac_status_stats", function()
	local d = os.date("%Y-%m-%d")
	if stats.day ~= d then stats.day, stats.today = d, 0 end
	stats.today = stats.today + 1
	stats.total = stats.total + 1
	roundStartT, roundMap, roundMode = CurTime(), game.GetMap(), zb and zb.CROUND
	saveStats()
end)
hook.Add("ZB_EndRound", "zac_status_stats", function()
	if not roundMode then return end
	local len = math.max(0, CurTime() - roundStartT)
	local n = 0
	for _, p in player.Iterator() do if not p:IsBot() then n = n + 1 end end
	table.insert(stats.last, 1, { n = stats.total, when = os.date("%d/%m %H:%M"), mode = modeName(roundMode), map = roundMap or game.GetMap(),
		len = string.format("%d:%02d", len / 60, len % 60), players = n })
	while #stats.last > 5 do table.remove(stats.last) end
	roundMode = nil
	saveStats()
	timer.Simple(1, function() if ZAC.DiscordStatus then ZAC.DiscordStatus("Round over") end end)
end)

local function statusBody(title, desc, color, fields)
	local f = {}
	for _, x in ipairs(fields or {}) do
		if x and x.value and x.value ~= "" then f[#f + 1] = { name = clean(x.name or "-", 250), value = clean(x.value, 1000), inline = x.inline == true } end
	end
	return { username = "Server Status", allowed_mentions = { parse = {} }, embeds = { {
		title = clean(GetHostName(), 250), description = clean(desc or statusDesc(), 2000), color = color or 0x2ecc71, fields = f,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"), footer = { text = "updates every minute" },
	} } }
end

-- edit the status message (or post it the first time); at most one request every 3 s, the newest state wins
local function statusSend(body, now)
	local u = statusHook()
	if u == "" then return end
	local key = hookKey(u)
	local id = statusMsg[key]
	local function post()
		statusBusy = true
		httpFn({ url = realURL(u) .. "?wait=true", method = "POST", type = "application/json", headers = HEADERS, body = toJSON(body),
			success = function(code, resp)
				statusBusy = false
				local id = msgIdOf(resp)
				if (code == 200 or code == 204) and id then statusMsg[key] = id saveStatusMsg()
				elseif code and code >= 400 then print("[ZAC] Status webhook: Discord said " .. code .. ": " .. string.sub(tostring(resp or ""), 1, 200)) end
			end,
			failed = function(r) statusBusy = false print("[ZAC] Status webhook failed: " .. tostring(r)) end })
	end
	if not id then post() return end
	statusBusy = true
	httpFn({ url = realURL(u) .. "/messages/" .. id, method = "PATCH", type = "application/json", headers = HEADERS, body = toJSON(body),
		success = function(code, resp)
			statusBusy = false
			if code == 404 then statusMsg[key] = nil saveStatusMsg() if not now then post() end -- deleted: post a new one
			elseif code and code >= 400 then print("[ZAC] Status webhook edit: Discord said " .. code .. ": " .. string.sub(tostring(resp or ""), 1, 200)) end
		end,
		failed = function(r) statusBusy = false print("[ZAC] Status webhook edit failed: " .. tostring(r)) end })
end

function ZAC.DiscordStatus(title, desc, color, fields)
	if title and title ~= "Server status" then lastEvent, lastEventT = title, os.time() end
	statusPending = statusBody("Server status", nil, color, fields or statusFields())
end
timer.Create("zac_status_flush", 3, 0, function()
	if not statusPending or statusBusy or SysTime() < statusNext then return end
	local b = statusPending
	statusPending = nil
	statusNext = SysTime() + 3
	pcall(statusSend, b)
end)

hook.Add("InitPostEntity", "zac_status_online", function()
	timer.Simple(10, function() ZAC.DiscordStatus("Server online", "**Online** on " .. game.GetMap(), 0x2ecc71) end)
end)
hook.Add("ShutDown", "zac_status_off", function()
	-- (no time to queue: edit it straight away)
	lastEvent, lastEventT = "Map change / restart", os.time()
	pcall(statusSend, statusBody("Server status", "**Changing map / restarting**\nwas on **" .. game.GetMap() .. "**", 0xe67e22, statusFields()), true)
end)
hook.Add("ZB_StartRound", "zac_status_round", function()
	timer.Simple(2, function() ZAC.DiscordStatus("Round started: " .. tostring(zb and zb.CROUND or "?"), "**Online** on " .. game.GetMap(), 0x3498db) end)
end)
-- keeps the player list fresh (it's an edit, so no spam)
timer.Create("zac_status_periodic", 60, 0, function() ZAC.DiscordStatus("Server status", "**Online** on " .. game.GetMap(), 0x2ecc71) end)
hook.Add("PlayerInitialSpawn", "zac_status_join", function() timer.Simple(5, function() ZAC.DiscordStatus("Server status", "**Online** on " .. game.GetMap(), 0x2ecc71) end) end)
hook.Add("PlayerDisconnected", "zac_status_leave", function() timer.Simple(1, function() ZAC.DiscordStatus("Server status", "**Online** on " .. game.GetMap(), 0x2ecc71) end) end)

-- the "anti-cheat online" post on every map load was spam: it's in the status message now
D.PostOnStart = false

-- zac_discord_check (server console or a superadmin): what's set up + a test post to BOTH webhooks, with the answer
local function mask(u)
	if u == "" then return "NOT SET" end
	local id = string.match(u, "/webhooks/(%d+)/") or "?"
	return "set (webhook " .. id .. ", token hidden)"
end
function ZAC.DiscordInfo()
	return {
		secrets = ZAC.Secrets ~= nil, cheat = mask(webhook()), status = mask(statusHook and statusHook() or ""),
		via = httpName, relay = cvRelay:GetBool(), enabled = D.Enabled ~= false,
	}
end
function ZAC.DiscordTest(ply, which)
	if (which == nil or which == "cheat") and webhook() ~= "" then
		queue[#queue + 1] = { _test = "Cheat log", _ply = ply, username = D.Username or "ZAC Anti-Cheat", embeds = { { title = "ZAC test post", description = "The cheat log webhook works." .. (IsValid(ply) and ("\nSent by " .. ply:Nick()) or ""), color = 0x78C864 } } }
	elseif which == "cheat" and IsValid(ply) and ZAC.DiscordTestResult then ZAC.DiscordTestResult(ply, "Cheat log", "NOT SET - no webhook in sv_secrets.lua") end
	local su = statusHook and statusHook() or ""
	if (which == nil or which == "status") and su ~= "" then
		-- (the status channel is one self-editing message: the test edits it too)
		local key = hookKey(su)
		local id = statusMsg[key]
		local body = statusBody("Server status", nil, 0x2ecc71, statusFields())
		httpFn({ url = realURL(su) .. (id and ("/messages/" .. id) or "?wait=true"), method = id and "PATCH" or "POST", type = "application/json", headers = HEADERS, body = toJSON(body),
			success = function(code, resp)
				local newId = msgIdOf(resp)
				if not id and newId then statusMsg[key] = newId saveStatusMsg() end
				if code == 404 and id then statusMsg[key] = nil saveStatusMsg() end
				local msg = (code == 200 or code == 204) and ("OK - status message " .. (id and "edited" or "posted") .. " (" .. code .. ")")
					or (code == 404 and "404 - the status message was deleted: test again to post a new one")
					or (code == 403 and "403 - Discord blocks this server's IP. Turn the relay on and test again.")
					or (tostring(code) .. " - " .. string.sub(tostring(resp or ""), 1, 120))
				print("[ZAC] Status test: " .. msg)
				if ZAC.DiscordTestResult then ZAC.DiscordTestResult(ply, "Status", msg) end
			end,
			failed = function(r)
				local msg = "FAILED - " .. tostring(r) .. " (the host may block outgoing HTTPS: try the relay)"
				print("[ZAC] Status test: " .. msg)
				if ZAC.DiscordTestResult then ZAC.DiscordTestResult(ply, "Status", msg) end
			end })
	elseif which == "status" and IsValid(ply) and ZAC.DiscordTestResult then ZAC.DiscordTestResult(ply, "Status", "NOT SET - no webhook in sv_secrets.lua") end
end
function ZAC.DiscordSetRelay(on) RunConsoleCommand("zac_discord_relay", on and "1" or "0") end

concommand.Add("zac_discord_check", function(ply)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local function say(t) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[ZAC] " .. t) end print("[ZAC] " .. t) end
	say("sv_secrets.lua loaded: " .. tostring(ZAC.Secrets ~= nil))
	say("Cheat log webhook: " .. mask(webhook()))
	say("Status webhook:    " .. mask(statusHook and statusHook() or ""))
	say("Sending with: " .. httpName .. (cvRelay:GetBool() and " through the relay (zac_discord_relay 1)" or " straight to discord.com"))
	say("Discord posts enabled in config: " .. tostring(D.Enabled ~= false))
	ZAC.DiscordTest(ply)
	say("Test posts queued - the answers print in the server console in a few seconds.")
end)
