-- ZAC INTEGRITY / EXPLOIT CHECKS - FLAGS ONLY (logged + posted to Discord, nobody is banned or kicked).
--   cheat_signature  Lua on their PC registered hooks / net receivers / commands from a file this server never
--                    sent them = injected Lua (the usual Lua cheat / menu)
--   integrity        a game function that should be the engine's own was replaced (detoured) by Lua -
--                    render.Capture (hides from screengrabs), net.Start (hides what they send), debug.getinfo
--                    (hides itself)... A replacement from a file the server sent is an addon and only logged.
--   cvar             sv_allowcslua / sv_cheats on their side don't match the server (forced to run their own
--                    Lua), or wallhack cvars (r_drawothermodels 2, mat_wireframe, mat_fullbright) set
--   no_reply         stops answering the checks (something is blocking ZAC)
--   exploit_net      sent a known backdoor / exploit net message (honeypots: these exist only to catch that)
--   unknown_net      sent a net message nothing on the server listens for (exploit menus scanning for backdoors)
--   net_flood        hundreds of net messages a second (lag / crash exploits)
--   cmd_flood        console commands spammed at the server
-- Settings (server console): zac_integrity 0/1   zac_integrity_every <seconds>   zac_netflood <msgs per sec>
-- Check one player now: zac integrity <name>
local cvOn = CreateConVar("zac_integrity", "1", FCVAR_ARCHIVE, "ZAC integrity / exploit checks (flags only)", 0, 1)
local cvEvery = CreateConVar("zac_integrity_every", "120", FCVAR_ARCHIVE, "Seconds between integrity checks per player", 30, 3600)
-- old DirectX (dxlevel 70 / 80 / 81) breaks shaders in ways old wallhacks rely on: players on it are kicked with
-- how to fix it (this one isn't a cheat flag - it's a game setting; 0 turns it off)
local cvDX = CreateConVar("zac_min_dxlevel", "90", FCVAR_ARCHIVE, "Kick players running DirectX below this level (0 = off)", 0, 120)
local cvFlood = CreateConVar("zac_netflood", "300", FCVAR_ARCHIVE, "Net messages per second from one player that counts as a flood", 50, 5000)

util.AddNetworkString("zac_int_req")
util.AddNetworkString("zac_int_rep")

-- one log line + Discord post per player per check, at most this often (seconds)
local SEEN = {}
local function flag(ply, kind, msg, extra)
	if not IsValid(ply) then return end
	local key = ply:SteamID() .. "|" .. kind .. "|" .. msg
	if (SEEN[key] or 0) > CurTime() then return end
	SEEN[key] = CurTime() + 600
	local full = ZAC.Who(ply) .. ": " .. kind .. " [" .. msg .. "]"
	ZAC.Log("integrity", full, extra, ply)
	MsgC(Color(255, 90, 60), "[ZAC] " .. full .. "\n")
	if ZAC.Discord then
		ZAC.Discord("Cheat flag: " .. ply:Nick(), kind .. " [" .. msg .. "]" .. (extra and ("\n" .. string.sub(extra, 1, 900)) or "")
			.. "\n\nNot banned (flags only). Check them: zac spectate / zac screengrab - ban: zac ban " .. ply:SteamID(),
			15158332, { ZAC.DiscordPlayerField and ZAC.DiscordPlayerField({ name = ply:Nick(), sid = ply:SteamID() }) or nil })
	end
	hook.Run("ZACIntegrityFlag", ply, kind, msg)
end
ZAC.IntegrityFlag = flag

-- ---------- is this Lua file one the server sent? ----------
-- cached per file name (file.Exists hits the disk). A report full of made-up names can't flood it: at most
-- LOOKUPS_PER_REPORT new names are looked up per report (the rest next time), and the cache is capped.
local known, knownN = {}, 0
local LOOKUPS_PER_REPORT = 60
local lookupsLeft = math.huge
local function isServerFile(src)
	if known[src] ~= nil then return known[src] end
	if lookupsLeft <= 0 then return nil end -- not looked up yet: neither fine nor flagged this time
	lookupsLeft = lookupsLeft - 1
	if knownN > 8000 then known, knownN = {}, 0 end
	knownN = knownN + 1
	local ok = false
	if src == "[C]" or src == "=[C]" then ok = true
	else
		local s = string.gsub(src, "\\", "/")
		s = string.gsub(s, "^@", "")
		local rel = string.match(s, "^addons/[^/]+/lua/(.+)$") or string.match(s, "^lua/(.+)$")
		if rel and file.Exists(rel, "LUA") then ok = true
		elseif string.match(s, "^gamemodes/") and file.Exists(s, "GAME") then ok = true
		elseif string.match(s, "^addons/[^/]+/gamemodes/") and file.Exists(string.gsub(s, "^addons/[^/]+/", ""), "GAME") then ok = true
		elseif string.match(s, "^[%w_/%.%-]+%.lua$") and (file.Exists(s, "LUA") or file.Exists("lua/" .. s, "GAME")) then ok = true
		end
	end
	known[src] = ok
	return ok
end

-- how many lines the real file has (to catch code that only borrows a real file's name)
local lineCache, readsLeft = {}, 20
local function realLines(src)
	if lineCache[src] ~= nil then return lineCache[src] end
	if readsLeft <= 0 then return nil end
	readsLeft = readsLeft - 1
	local s = string.gsub(string.gsub(src, "\\", "/"), "^@", "")
	local rel = string.match(s, "^addons/[^/]+/lua/(.+)$") or string.match(s, "^lua/(.+)$")
	local txt = (rel and file.Read(rel, "LUA")) or (string.match(s, "^gamemodes/") and file.Read(s, "GAME"))
		or (string.match(s, "^addons/[^/]+/gamemodes/") and file.Read(string.gsub(s, "^addons/[^/]+/", ""), "GAME")) or file.Read(s, "LUA")
	local n = false
	if isstring(txt) then n = select(2, string.gsub(txt, "\n", "")) + 1 end
	lineCache[src] = n
	return n
end
-- a file of the server's, but the code ends further down than the file goes = it isn't that file
local function spoofed(src, line)
	line = tonumber(line) or 0
	if line <= 0 then return false end
	local n = realLines(src)
	return (n and line > n + 2) and true or false
end

-- ---------- the periodic check ----------
local pending = {}
local function ask(ply, forced)
	if not IsValid(ply) or ply:IsBot() then return end
	if not forced and not cvOn:GetBool() then return end
	local p = pending[ply] or { miss = 0 }
	pending[ply] = p
	if p.token then
		p.miss = p.miss + 1
		if p.miss >= 3 then flag(ply, "no_reply", "stopped answering " .. p.miss .. " integrity checks in a row") end
	end
	p.token = math.random(1, 2 ^ 31 - 1)
	p.at = CurTime()
	net.Start("zac_int_req") net.WriteUInt(p.token, 32) net.Send(ply)
end
ZAC.IntegrityAsk = ask

-- EVERY PLAYER, EVERY zac_integrity_every SECONDS (default 120), SPREAD OUT: one player per step, with the
-- steps spaced so everyone is done once per period (20 players / 120 s = one check every 6 s). Never a burst of
-- requests / reports in the same tick.
local function step()
	local every = cvEvery:GetFloat()
	local humans = player.GetHumans()
	local gap = math.Clamp(every / math.max(1, #humans), 1, 15)
	timer.Adjust("zac_integrity", gap, 0)
	if not cvOn:GetBool() then return end
	local now, pick, pickAt = CurTime(), nil, math.huge
	for _, ply in ipairs(humans) do
		if ply.ZACIntNext == nil then
			-- new player: first check somewhere in the next period (not all at map start)
			ply.ZACIntNext = now + 20 + math.random() * every
		end
		if ply.ZACIntNext <= now and ply.ZACIntNext < pickAt then pick, pickAt = ply, ply.ZACIntNext end
	end
	if pick then
		pick.ZACIntNext = now + every
		ask(pick)
	end
end
timer.Create("zac_integrity", 5, 0, step)
hook.Add("PlayerDisconnected", "zac_integrity", function(ply) pending[ply] = nil end)

local function srv(name) local c = GetConVar(name) return c and c:GetString() or "?" end

net.Receive("zac_int_rep", function(len, ply)
	local token = net.ReadUInt(32)
	local p = pending[ply]
	if not (p and p.token == token) then return end
	p.token, p.miss = nil, 0
	local n = net.ReadUInt(16)
	if n <= 0 or n > 65000 then return end
	-- one report per player per 20 s at most (a forced "zac integrity" is always taken)
	if not p.reportTo and (p.lastRep or 0) > CurTime() - 20 then return end
	p.lastRep = CurTime()
	local raw = util.Decompress(net.ReadData(n) or "", 1000000)
	local t = raw and util.JSONToTable(raw)
	if not istable(t) then return flag(ply, "integrity", "sent a broken integrity report") end
	-- who asked: an admin (player), or true = the server console (IsValid(true) errors, so it's checked like this)
	local reportTo = p.reportTo
	p.reportTo = nil
	local wantReport = reportTo ~= nil
	if wantReport and not (isentity(reportTo) and IsValid(reportTo)) then reportTo = nil end
	local found = {}
	local realFlag = flag
	local flag = function(pl, kind, msg, extra) found[#found + 1] = kind .. " [" .. msg .. "]" return realFlag(pl, kind, msg, extra) end

	-- detours (few, always looked up)
	lookupsLeft = math.huge
	readsLeft = 20
	local detourLines = {}
	for i, d in ipairs(t.detours or {}) do
		if i > 40 then break end
		if not istable(d) then continue end
		local path, src = tostring(d[1] or "?"), tostring(d[2] or "?")
		detourLines[#detourLines + 1] = path .. " <- " .. src .. ((tonumber(d[3]) or 0) > 0 and (":" .. d[3]) or "")
		if src == "(missing)" then
			flag(ply, "integrity", "int:removed " .. path)
		elseif isServerFile(src) and spoofed(src, d[3]) then
			flag(ply, "cheat_signature", "int:detour " .. path .. " from code posing as " .. src, "Its code ends on line " .. tostring(d[3]) .. ", the real file is shorter")
		elseif isServerFile(src) then
			-- an addon of ours wraps it: only noted in the log (not Discord)
			if not SEEN["addon|" .. path .. src] then
				SEEN["addon|" .. path .. src] = math.huge
				ZAC.Log("integrity", "note: " .. path .. " is wrapped by " .. src .. " (a server addon, fine)", nil, ply)
			end
		else
			flag(ply, "integrity", "int:detour " .. path, "Replaced by: " .. src)
		end
	end

	-- injected Lua: sources the server never sent
	local bad = {}
	lookupsLeft = LOOKUPS_PER_REPORT
	local seenSrc = 0
	for src, c in pairs(t.sources or {}) do
		seenSrc = seenSrc + 1
		if seenSrc > 800 then break end
		if not isstring(src) or #src > 260 then continue end
		if not istable(c) then c = {} end
		if isServerFile(src) and spoofed(src, c[4]) then
			bad[#bad + 1] = string.format("sig:posing as %s (code down to line %d, the real file is shorter)", src, tonumber(c[4]) or 0)
		elseif isServerFile(src) == false then
			bad[#bad + 1] = string.format("sig:injected %s (%d hooks, %d events, %d commands)", src, c[1] or 0, c[2] or 0, c[3] or 0)
		end
	end
	table.sort(bad)
	if #bad > 0 then flag(ply, "cheat_signature", bad[1], table.concat(bad, "\n")) end
	-- injected Lua = banned on the spot (superadmins are only flagged, so a false hit can't lock the owner out)
	local injected
	for _, b in ipairs(bad) do if string.find(b, "sig:injected", 1, true) then injected = b break end end
	if injected and IsValid(ply) and not ply:IsSuperAdmin() then
		local sid, name = ply:SteamID(), ply:Nick()
		ZAC.Log("access", ZAC.Who(ply) .. " BANNED: injected Lua (" .. injected .. ")", table.concat(bad, "\n"), ply)
		ply:Kick("ZAC: injected cheats detected. Banned, you retard.")
		ZAC.Ban(sid, "Injected Lua: " .. injected, name, nil, "injection", nil, 0)
		return
	end

	-- convars
	local cv = t.cvars or {}
	local dx = tonumber(cv.mat_dxlevel)
	if dx and cvDX:GetInt() > 0 and dx < cvDX:GetInt() then
		ZAC.Log("access", ZAC.Who(ply) .. " kicked: running DirectX level " .. dx .. " (needs " .. cvDX:GetInt() .. "+)", nil, ply)
		MsgC(Color(255, 160, 60), "[ZAC] kicked " .. ply:Nick() .. ": old DirectX (mat_dxlevel " .. dx .. ")\n")
		ply:Kick("Old DirectX (level " .. dx .. ") isn't allowed here. Steam > GMod > Properties > Launch options: remove -dxlevel, or set -dxlevel 95, then restart the game")
		return
	end
	for _, name in ipairs({ "sv_allowcslua", "sv_cheats" }) do
		if cv[name] and cv[name] ~= "?" and tonumber(cv[name]) ~= tonumber(srv(name)) then
			flag(ply, "cvar", name .. " is " .. tostring(cv[name]) .. " on their PC (server: " .. srv(name) .. ")")
		end
	end
	if srv("sv_cheats") == "0" then
		if cv.r_drawothermodels and cv.r_drawothermodels ~= "1" and cv.r_drawothermodels ~= "?" then flag(ply, "cvar", "r_drawothermodels " .. cv.r_drawothermodels .. " (wallhack)") end
		if cv.mat_wireframe and cv.mat_wireframe ~= "0" and cv.mat_wireframe ~= "?" then flag(ply, "cvar", "mat_wireframe " .. cv.mat_wireframe .. " (wallhack)") end
		if cv.mat_fullbright and cv.mat_fullbright ~= "0" and cv.mat_fullbright ~= "?" then flag(ply, "cvar", "mat_fullbright " .. cv.mat_fullbright) end
		if cv.host_timescale and tonumber(cv.host_timescale) and tonumber(cv.host_timescale) ~= 1 then flag(ply, "cvar", "host_timescale " .. cv.host_timescale .. " (speedhack)") end
	end

	-- a check someone asked for: the full result to their console and to Discord, clean or not
	if wantReport then
		local cv = t.cvars or {}
		local nSrc = 0
		for _ in pairs(t.sources or {}) do nSrc = nSrc + 1 end
		local lines = {
			"Integrity check: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")",
			#found > 0 and ("FOUND " .. #found .. ":") or "Nothing found.",
		}
		for _, f in ipairs(found) do lines[#lines + 1] = "  - " .. f end
		if #detourLines > 0 then
			lines[#lines + 1] = "Replaced game functions (by server addons = fine):"
			for _, l in ipairs(detourLines) do lines[#lines + 1] = "  " .. l end
		end
		lines[#lines + 1] = string.format("Lua sources checked: %d   replaced functions: %d   dxlevel %s   sv_allowcslua %s   sv_cheats %s",
			nSrc, #(t.detours or {}), tostring(cv.mat_dxlevel or "?"), tostring(cv.sv_allowcslua or "?"), tostring(cv.sv_cheats or "?"))
		for _, l in ipairs(lines) do
			if IsValid(reportTo) then reportTo:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. l) else print("[AC] " .. l) end
		end
		if IsValid(reportTo) then reportTo:ChatPrint("[AC] Integrity check on " .. ply:Nick() .. ": " .. (#found > 0 and (#found .. " flag(s) - see console") or "clean")) end
		if ZAC.Discord then
			ZAC.Discord("Integrity check: " .. ply:Nick(), table.concat(lines, "\n", 2), #found > 0 and 15158332 or 7915620,
				{ ZAC.DiscordPlayerField and ZAC.DiscordPlayerField({ name = ply:Nick(), sid = ply:SteamID() }) or nil })
		end
	end
end)

-- ---------- net messages: honeypots, unknown messages, floods ----------
-- names used by well-known server backdoors and exploit menus. Nothing real uses them, so anyone sending
-- one is probing for a backdoor. Only made if no addon already uses the name.
local HONEYPOTS = {
	"Sandbox_ArmDupe", "Sbox_darkrp", "Sbox_itemstore", "Ulib_Message", "ULogs_Info", "ITEM", "R8", "fix",
	"Fix_Keypads", "Remove_Exploiters", "noclipcloakaesp_chat_text", "_Defqon", "_CAC_ReadMemory", "nostrip",
	"LickMeOut", "MoonMan", "Im_SOCool", "fix_exploits", "Inj3", "nocheat", "SessionBackdoor", "DarkRP_AdminWeapons",
	"memeDoor", "Backdoor", "OdiumBackDoor", "cucked", "NoNerks", "kek", "ZimbaBackDoor", "killserver", "fuckserver",
	"cvaraccess", "rconadmin", "jesuslebg", "zilnix", "disablebackdoor", "blacksheep", "jeveuttonrconleul",
	"pjHabrp9EY", "_Raze", "NoOdium_ReadPing", "BackdoorPackets", "thefrenchenculer", "elfamosabackdoormdr",
	"xenoexistscl", "ZetaHook", "pwn_http_send", "pwn_wake", "pwn_http_answer", "Abcdefgh", "fourtwenty",
}
local honey = {}
for _, n in ipairs(HONEYPOTS) do
	if (util.NetworkStringToID(n) or 0) == 0 then
		util.AddNetworkString(n)
		honey[string.lower(n)] = n
	end
end

local rate = {}
NETWATCH = NETWATCH or {}
local origIncoming = net.Incoming
function net.Incoming(len, client)
	local i = net.ReadHeader()
	local name = util.NetworkIDToString(i)
	if not name then return end
	local lname = string.lower(name)

	if IsValid(client) and client:IsPlayer() and cvOn:GetBool() then
		local r = rate[client]
		local now = math.floor(CurTime())
		if not r or r.t ~= now then r = { t = now, n = 0 } rate[client] = r end
		r.n = r.n + 1
		if r.n == cvFlood:GetInt() then flag(client, "net_flood", r.n .. "+ net messages in one second", "Last one: " .. name) end
		if honey[lname] and not net.Receivers[lname] then
			flag(client, "exploit_net", "sent backdoor message " .. honey[lname])
			return
		end
	end

	if IsValid(client) and client:IsPlayer() then
		-- huge messages: real addons send small ones; exploit menus stuff them to lag / crash the server
		if cvOn:GetBool() and len > 64000 * 8 then flag(client, "net_flood", "sent a " .. math.floor(len / 8192) .. " KB " .. name .. " message") end
		-- zac netwatch: every message this player sends, to the console of whoever is watching
		local w = NETWATCH[client]
		if w then
			if CurTime() > w.untilT then NETWATCH[client] = nil
			else
				local line = string.format("[AC netwatch] %s -> %s (%d bytes)%s", client:Nick(), name, math.floor(len / 8), net.Receivers[lname] and "" or "  ** NOTHING LISTENS FOR THIS **")
				if IsValid(w.to) then w.to:PrintMessage(HUD_PRINTCONSOLE, line) else print(line) end
			end
		end
	end

	local func = net.Receivers[lname]
	if not func then
		if IsValid(client) and client:IsPlayer() and cvOn:GetBool() then flag(client, "unknown_net", "sent " .. name .. " (nothing on the server listens for it)") end
		return
	end
	len = len - 16
	func(len, client)
end
ZAC.OrigNetIncoming = origIncoming
hook.Add("PlayerDisconnected", "zac_netrate", function(ply) rate[ply] = nil end)

-- ---------- console command floods ----------
local cmdRate = {}
local origRun = concommand.Run
function concommand.Run(ply, cmd, args, argStr)
	if IsValid(ply) and ply:IsPlayer() and cvOn:GetBool() then
		local now = math.floor(CurTime())
		local r = cmdRate[ply]
		if not r or r.t ~= now then r = { t = now, n = 0 } cmdRate[ply] = r end
		r.n = r.n + 1
		if r.n == 60 then flag(ply, "cmd_flood", "60+ console commands in one second", "Last one: " .. tostring(cmd)) end
	end
	return origRun(ply, cmd, args, argStr)
end
hook.Add("PlayerDisconnected", "zac_cmdrate", function(ply) cmdRate[ply] = nil end)

ZAC.AdminActions.integrity = function(admin, target)
	local p = ZAC.FindPlayer(target)
	local function say(t) if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. t) else print("[AC] " .. t) end end
	if not IsValid(p) then return say("No player '" .. tostring(target) .. "' online.") end
	if p:IsBot() then return say(p:Nick() .. " is a bot - bots don't run Lua, nothing to check.") end
	-- forget earlier flags so this run reports everything it finds
	for k in pairs(SEEN) do if string.find(k, p:SteamID(), 1, true) == 1 then SEEN[k] = nil end end
	ask(p, true) -- runs even with zac_integrity 0
	if not pending[p] then return say("Couldn't ask " .. p:Nick() .. " for a report.") end
	pending[p].reportTo = IsValid(admin) and admin or true
	say("Asked " .. p:Nick() .. " for an integrity report - the result prints here and goes to Discord in a few seconds.")
end

-- zac netwatch <name> [seconds]: print every net message that player sends to the server (name, size, and a
-- warning if nothing on the server listens for it). The only way a client talks to the server is net messages,
-- so this shows exactly what an exploit menu is trying. Default 60 s; zac netwatch <name> 0 stops it.
ZAC.AdminActions.netwatch = function(admin, target, secs)
	local p = ZAC.FindPlayer(target)
	local function say(t) if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. t) else print("[AC] " .. t) end end
	if not IsValid(p) then return say("No player '" .. tostring(target) .. "' online.") end
	local n = tonumber(secs) or 60
	if n <= 0 then NETWATCH[p] = nil return say("Stopped watching " .. p:Nick() .. "'s net messages.") end
	NETWATCH[p] = { to = IsValid(admin) and admin or nil, untilT = CurTime() + math.min(n, 600) }
	say("Watching every net message " .. p:Nick() .. " sends for " .. math.min(n, 600) .. "s - they print here.")
	ZAC.Log("admin", ZAC.Who(admin) .. " is watching " .. ZAC.Who(p) .. "'s net messages", nil, p)
end
