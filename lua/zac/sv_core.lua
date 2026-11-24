local cfg = ZAC.Config

for _, n in ipairs({
	"zac_key", "zac_open", "zac_logs_req", "zac_logs", "zac_log_live", "zac_menu_closed",
	"zac_sg_req", "zac_sg_chunk", "zac_sg_view", "zac_sg_list_req", "zac_sg_list", "zac_sg_open",
	"zac_admin_cmd", "zac_bans_req", "zac_bans", "zac_cmd",
}) do util.AddNetworkString(n) end

file.CreateDir("zac")
file.CreateDir("zac/logs")
file.CreateDir("zac/screens")

ZAC.Logs = ZAC.Logs or {}
ZAC.NextId = ZAC.NextId or 0
ZAC.AdminActions = ZAC.AdminActions or {}

-- Saved tables keyed by SteamID64: util.JSONToTable turns "76561198012345678" into a Lua number,
-- which is too small to hold it exactly, so the key comes back rounded and stops matching after a
-- map change / restart (whitelist, bans, ratings). These keep the keys as exact strings.
function ZAC.JSONLoadIDs(raw)
	if not isstring(raw) or raw == "" then return nil end
	local t = util.JSONToTable(raw, false, true) -- 3rd arg: keep keys as strings
	if not istable(t) then return nil end
	local lookup
	local function fix(tbl, depth)
		if depth > 6 then return end
		local moves
		for k, v in pairs(tbl) do
			if isnumber(k) and k > 1e15 then moves = moves or {} moves[#moves + 1] = k end
			if istable(v) then fix(v, depth + 1) end
		end
		if not moves then return end
		if not lookup then
			lookup = {}
			for str in string.gmatch(raw, '"(7656%d+)"%s*:') do local n = tonumber(str) if n and not lookup[n] then lookup[n] = str end end
		end
		for _, k in ipairs(moves) do
			local str = lookup[k]
			if str and tbl[str] == nil then tbl[str] = tbl[k] tbl[k] = nil end
		end
	end
	fix(t, 0)
	return t
end

-- look up sid64 in tbl; an entry saved before the fix may sit under a rounded key - move it over
function ZAC.SIDGet(tbl, sid64)
	if not istable(tbl) or not isstring(sid64) then return nil end
	if tbl[sid64] ~= nil then return tbl[sid64] end
	local n = tonumber(sid64)
	if not n then return nil end
	for k, v in pairs(tbl) do
		if k ~= sid64 and tonumber(k) == n then tbl[sid64] = v tbl[k] = nil return v, true end
	end
	return nil
end

function ZAC.IsAdmin(ply) return IsValid(ply) and cfg.IsAdmin(ply) == true end

function ZAC.Who(ent)
	if not IsValid(ent) then return "World" end
	if not ent:IsPlayer() then return ent:GetClass() end
	return string.format("%s (%s)", ent:Nick(), ent:SteamID())
end

local function person(p)
	if istable(p) and not IsEntity(p) then return { name = tostring(p.name or "?"), sid = tostring(p.sid or "") } end
	if IsValid(p) and p:IsPlayer() then return { name = p:Nick(), sid = p:SteamID() } end
end
ZAC.Person = person

local function writePerson(p)
	net.WriteString(p and p.name or "")
	net.WriteString(p and p.sid or "")
end

-- a log line / its details are cut to this length when sent to the menu (one huge integrity report could
-- overflow the 64 KB net message on its own); the full text stays in the log file / Discord
local MAX_M, MAX_X = 1500, 6000
local function cut(str, n) str = str or "" return #str > n and (string.sub(str, 1, n - 3) .. "...") or str end
local function entryBytes(e)
	local a, v = e.a or {}, e.v or {}
	return math.min(#e.m, MAX_M) + math.min(#(e.x or ""), MAX_X) + #(a.name or "") + #(a.sid or "") + #(v.name or "") + #(v.sid or "") + 24
end
ZAC.EntryBytes = entryBytes
local function writeEntry(e)
	net.WriteUInt(e.id, 32)
	net.WriteUInt(e.t, 32)
	net.WriteUInt(ZAC.KindIndex[e.k] or 1, 4)
	net.WriteString(cut(e.m, MAX_M))
	net.WriteString(cut(e.x, MAX_X))
	writePerson(e.a)
	writePerson(e.v)
end

function ZAC.Log(kind, msg, extra, offender, victim)
	ZAC.NextId = ZAC.NextId + 1
	local e = { id = ZAC.NextId, t = os.time(), k = kind, m = tostring(msg), x = extra, a = person(offender), v = person(victim) }
	local L = ZAC.Logs
	L[#L + 1] = e
	if #L > cfg.LogMemory + (cfg.ChatMemory or 0) + 500 then
		local keepIdx, other, chat = {}, 0, 0
		for i = #L, 1, -1 do
			if L[i].k == "chat" then
				if chat < (cfg.ChatMemory or 0) then chat = chat + 1 keepIdx[i] = true end
			elseif other < cfg.LogMemory then
				other = other + 1 keepIdx[i] = true
			end
		end
		local keep = {}
		for i = 1, #L do if keepIdx[i] then keep[#keep + 1] = L[i] end end
		ZAC.Logs = keep
	end

	if cfg.LogToFile then
		file.Append("zac/logs/" .. os.date("%Y-%m-%d") .. ".txt",
			os.date("[%H:%M:%S] ") .. string.upper(kind) .. "  " .. e.m .. (extra and ("\n" .. extra) or "") .. "\n")
	end
	if cfg.PrintToConsole and (not cfg.ConsoleKinds or cfg.ConsoleKinds[kind]) then MsgN("[ZAC] [", string.upper(kind), "] ", e.m) end

	local live = {}
	for _, p in player.Iterator() do
		if p.ZACLive and ZAC.IsAdmin(p) then live[#live + 1] = p end
	end
	if #live > 0 then
		net.Start("zac_log_live")
		writeEntry(e)
		net.Send(live)
	end
	hook.Run("ZACLogged", e)
	return e
end

function ZAC.AdminChat(text)
	for _, p in player.Iterator() do
		if ZAC.IsAdmin(p) then p:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. text) end
	end
end

function ZAC.FindPlayer(s)
	s = string.Trim(tostring(s or ""))
	if s == "" then return end
	for _, p in player.Iterator() do
		if p:SteamID() == s or p:SteamID64() == s then return p end
	end
	local low = string.lower(s)
	for _, p in player.Iterator() do
		if string.lower(p:Nick()) == low then return p end
	end
	for _, p in player.Iterator() do
		if string.find(string.lower(p:Nick()), low, 1, true) then return p end
	end
end

net.Receive("zac_logs_req", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACReqNext or 0) > CurTime() then return end
	ply.ZACReqNext = CurTime() + 0.4

	local mask = net.ReadUInt(8)
	local search = string.lower(string.sub(net.ReadString(), 1, 64))
	ply.ZACLive = net.ReadBool()

	local out, bytes = {}, 0
	for i = #ZAC.Logs, 1, -1 do
		local e = ZAC.Logs[i]
		local ki = ZAC.KindIndex[e.k] or 1
		if bit.band(mask, bit.lshift(1, ki - 1)) ~= 0 and (search == ""
			or string.find(string.lower(e.m), search, 1, true)
			or (e.x and string.find(string.lower(e.x), search, 1, true))
			or (e.a and string.find(string.lower(e.a.sid), search, 1, true))
			or (e.v and string.find(string.lower(e.v.sid), search, 1, true))) then
			local b = entryBytes(e)
			if bytes + b > 48000 or #out >= cfg.MaxSend then break end
			out[#out + 1] = e
			bytes = bytes + b
		end
	end

	net.Start("zac_logs")
	net.WriteUInt(#out, 12)
	for i = #out, 1, -1 do writeEntry(out[i]) end
	net.Send(ply)
end)

net.Receive("zac_menu_closed", function(_, ply) ply.ZACLive = nil end)

local function openFor(ply, tab)
	if not ZAC.IsAdmin(ply) then ply:ChatPrint("[AC] Admins only.") return end
	net.Start("zac_open")
	net.WriteString(tab or "logs")
	net.Send(ply)
end
concommand.Add("zac_menu", function(ply) if IsValid(ply) then openFor(ply, "logs") end end)
concommand.Add("zac_sg", function(ply) if IsValid(ply) then openFor(ply, "screengrabs") end end)
hook.Add("PlayerSay", "zac_chat", function(ply, text)
	local t = string.lower(string.Trim(text))
	if cfg.ChatCommands[t] then openFor(ply, "logs") return "" end
	if cfg.ScreengrabChatCommands[t] then openFor(ply, "screengrabs") return "" end
end)

net.Receive("zac_admin_cmd", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACCmdNext or 0) > CurTime() then return end
	ply.ZACCmdNext = CurTime() + 0.3
	local act = net.ReadString()
	local arg = string.sub(net.ReadString(), 1, 64)
	local arg2 = string.sub(net.ReadString(), 1, 200)
	if cfg.AdminOnlyActions and cfg.AdminOnlyActions[act] and not ply:IsAdmin() then ply:ChatPrint("[AC] Only admins can do that.") return end
	local h = ZAC.AdminActions[act]
	if h then
		MsgN("[ZAC] [CMD] ", ply:Nick(), " (", ply:SteamID(), ") ran: zac ", act, " ", arg, arg2 ~= "" and (" " .. arg2) or "")
		h(ply, arg, arg2)
	end
end)

function ZAC.RunCmd(ply, args)
	if IsValid(ply) and not ZAC.IsAdmin(ply) then return end
	local act = args[1]
	local h = act and ZAC.AdminActions[act]
	local function say(t) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, t) else print(t) end end
	if not h then
		say("---- ZAC commands (work in the server console too) ----")
		say("zac screengrab <name|steamid>      take a screenshot of a player's screen")
		say("zac_manual 0/1                     1 = ZAC never bans / kicks by itself, only logs (now " .. GetConVarNumber("zac_manual") .. ")")
		say("zac_alt_autoban 0/1                1 = alts of banned accounts are banned even in manual mode (now " .. GetConVarNumber("zac_alt_autoban") .. ")")
		say("zac kick <name|steamid> [reason]")
		say("zac integrity <name>               check their PC now for injected Lua / replaced functions (flags only)")
		say("zac netwatch <name> [seconds]      print every net message they send to the server (0 = stop)")
		say("zac ban <name|steamid|steamid64> [reason]")
		say("zac unban <steamid>")
		say("zac whitelist <name|steamid>     let this family-shared account play (never kicked for family share)")
		say("zac unwhitelist <steamid>")
		say("zac bans                           list bans")
		say("zac rating_clear <steamid|steamid64|name|all>   clear a suspicion rating back to CLEAN")
		say("zac alts <name|steamid>            accounts that have played on the same PC")
		say("zac unlink <steamid>               forget an account's PC links (wrong alt match)")
		say("zac spectate <name|steamid>        watch a player live through their eyes (also !spec <name>)")
		say("zac unspectate                     stop watching (also !spec, or SPACE)")
		say("zac steamcheck <name|steamid>      run the Steam VAC / level check now and print it")
		say("zac discord_test                   send a test post to the Discord cheat log")
		say("zac_menu                           open the anti-cheat menu (in game)")
		say("zac_sg                             open the screengrab tab (in game)")
		say("zac_wordban 0/1                    auto-ban slurs in chat (now " .. GetConVarNumber("zac_wordban") .. ")")
		say("zac_wordban_show <0-10>            seconds of firework before the ban")
		say("zac_wordban_test <text|name>       test the word filter / run it on a player")
		say("zac_firework_test [name]           firework someone without banning")
		return
	end
	if IsValid(ply) and cfg.AdminOnlyActions and cfg.AdminOnlyActions[act] and not ply:IsAdmin() then say("Only admins can do that.") return end
	local who = IsValid(ply) and (ply:Nick() .. " (" .. ply:SteamID() .. ")") or "Console"
	MsgN("[ZAC] [CMD] ", who, " ran: zac ", table.concat(args, " "))
	h(ply, args[2] or "", table.concat(args, " ", 3))
end
concommand.Add("zac", function(ply, _, args) ZAC.RunCmd(ply, args) end)

-- "zac ..." typed in an admin's own console: the client command (cl_cmd.lua, it has the name
-- autocomplete) sends the words here
net.Receive("zac_cmd", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACCmdNext or 0) > CurTime() then return end
	ply.ZACCmdNext = CurTime() + 0.3
	local n, args = math.min(net.ReadUInt(4), 12), {}
	for i = 1, n do args[i] = string.sub(net.ReadString(), 1, 200) end
	ZAC.RunCmd(ply, args)
end)

hook.Add("PlayerInitialSpawn", "zac_join", function(ply)
	ZAC.Log("access", ZAC.Who(ply) .. " joined", "SteamID64: " .. ply:SteamID64() .. "\nIP: " .. tostring(ply:IPAddress()), ply)
end)
hook.Add("PlayerDisconnected", "zac_leave", function(ply)
	ZAC.Log("access", ZAC.Who(ply) .. " left", nil, ply)
end)
