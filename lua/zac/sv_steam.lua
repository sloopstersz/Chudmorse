-- STEAM ACCOUNT CHECKS on join (Steam Web API):
--   * VAC ban on an account under Steam level 3 (a throwaway cheat account) -> permanent ban, appeal in the
--     Discord. Stays automatic even in manual mode (zac_steam_autoban 0 turns it off)
--   * account younger than 120 days (zac_min_account_days; 0 = off) -> permanent ban, appeal in the Discord
--   * a VAC ban on a level 3+ account, a hidden level, a family-share owner's VAC ban -> only logged
-- Admins (ZAC admin check) and whitelisted accounts (zac whitelist <steamid>) are never banned by this.
-- Needs a Steam Web API key: ZAC.Secrets.SteamAPIKey in sv_secrets.lua (or zac_steam_apikey in the
-- server console / server.cfg). Without a key the checks are skipped (logged once).
-- Results are cached for 12 hours per account (data/zac/steam_cache.json).
-- Console: zac steamcheck <name|steamid>   runs the check now and prints the result (no ban for admins / whitelisted)
local cfg = ZAC.Config
local S = cfg.SteamCheck or {}

local cvAuto = CreateConVar("zac_steam_autoban", "1", { FCVAR_ARCHIVE }, "1 = auto-ban VAC banned accounts under Steam level 3 (even in manual mode); admins never", 0, 1)
ZAC.SteamAutoBan = function() return cvAuto:GetBool() end
local cvDays = CreateConVar("zac_min_account_days", "120", { FCVAR_ARCHIVE }, "Steam accounts younger than this many days are banned on join (0 = off); admins never", 0, 3650)
local cvKey = CreateConVar("zac_steam_apikey", "", { FCVAR_ARCHIVE, FCVAR_PROTECTED, FCVAR_DONTRECORD, FCVAR_UNLOGGED }, "Steam Web API key for the ZAC VAC / Steam level checks")

local CACHE = "zac/steam_cache.json"
local cache = {}
do
	local t = util.JSONToTable(file.Read(CACHE, "DATA") or "")
	if istable(t) then cache = t end
end
local saveAt = 0
timer.Create("zac_steam_save", 10, 0, function()
	if saveAt == 0 or CurTime() < saveAt then return end
	saveAt = 0
	local now, out = os.time(), {}
	for k, v in pairs(cache) do if istable(v) and now - (v.t or 0) < 86400 * 7 then out[k] = v end end
	cache = out
	file.CreateDir("zac")
	file.Write(CACHE, util.TableToJSON(out))
end)

local function key()
	local k = string.Trim(cvKey:GetString())
	if k == "" then k = string.Trim(tostring(ZAC.Secrets and ZAC.Secrets.SteamAPIKey or "")) end
	return k
end

local warned = false
local function noKey()
	if warned then return end
	warned = true
	ZAC.Log("access", "Steam checks (VAC / level) are OFF: no Steam Web API key. Put one in lua/zac/sv_secrets.lua (https://steamcommunity.com/dev/apikey)")
end

local function exempt(ply)
	if not IsValid(ply) or ply:IsBot() then return true end
	if ply:IsAdmin() then return true end -- real admins only (moderators can be whitelisted)
	local wl = ZAC.Access and ZAC.Access.wl or {}
	if wl[ply:SteamID()] or wl[ply:SteamID64()] then return true end
	for _, sid in ipairs(S.Exempt or {}) do
		if ZAC.SID(sid) == ply:SteamID() then return true end
	end
	return false
end
ZAC.SteamExempt = exempt

local function get(url, done)
	http.Fetch(url, function(body, _, _, code)
		if code ~= 200 then return done(nil, "HTTP " .. tostring(code)) end
		local t = util.JSONToTable(body or "")
		if not istable(t) then return done(nil, "bad reply") end
		done(t)
	end, function(err) done(nil, tostring(err)) end)
end

-- result: { t, vac (bool), vacs, gamebans, days, level (number or nil = private / unknown) }
local function lookup(sid64, done)
	local c = cache[sid64]
	if c and os.time() - (c.t or 0) < (S.CacheHours or 12) * 3600 then return done(c) end
	local k = key()
	if k == "" then noKey() return done(nil, "no API key") end
	local res = { t = os.time() }
	get("https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=" .. k .. "&steamids=" .. sid64, function(t, err)
		local p = t and t.players and t.players[1]
		if not p then return done(nil, "bans: " .. tostring(err or "no data")) end
		res.vac = p.VACBanned == true or (tonumber(p.NumberOfVACBans) or 0) > 0
		res.vacs = tonumber(p.NumberOfVACBans) or 0
		res.gamebans = tonumber(p.NumberOfGameBans) or 0
		res.days = tonumber(p.DaysSinceLastBan) or 0
		res.community = p.CommunityBanned == true
		get("https://api.steampowered.com/IPlayerService/GetSteamLevel/v1/?key=" .. k .. "&steamid=" .. sid64, function(t2)
			local r = t2 and t2.response
			res.level = r and tonumber(r.player_level) or nil -- nil: private profile / unknown
			-- account age (only shown for public profiles)
			get("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=" .. k .. "&steamids=" .. sid64, function(t3)
				local pl = t3 and t3.response and t3.response.players and t3.response.players[1]
				res.created = pl and tonumber(pl.timecreated) or nil
				cache[sid64] = res
				saveAt = CurTime() + 5
				done(res)
			end)
		end)
	end)
end
ZAC.SteamLookup = lookup

local function describe(r)
	local lv = r.level and tostring(r.level) or "hidden (private profile)"
	local age = r.created and (math.floor((os.time() - r.created) / 86400) .. " days old") or "age hidden"
	return string.format("Steam level %s, account %s, VAC bans %d, game bans %d%s", lv, age, r.vacs or 0, r.gamebans or 0,
		(r.vacs or 0) + (r.gamebans or 0) > 0 and (" (last " .. (r.days or 0) .. " days ago)") or "")
end

local function ban(ply, why, text)
	if not IsValid(ply) or ply.ZACSteamBanned then return end
	ply.ZACSteamBanned = true
	-- this one ban stays automatic even in manual mode (zac_steam_autoban 0 to stop it)
	if not cvAuto:GetBool() then
		ZAC.Log("access", ZAC.Who(ply) .. " flagged by the Steam check: " .. why .. " - NOT banned (zac_steam_autoban 0). Ban: zac ban " .. ply:SteamID(), text, ply)
		return
	end
	ZAC.Log("access", ZAC.Who(ply) .. " banned by the Steam check: " .. why .. "  (" .. text .. ")", nil, ply)
	ZAC.Ban(ply:SteamID(), (S.BanMessage or "Your Steam account isn't allowed here please appeal in the discord") .. " (" .. why .. ")",
		ply:Nick(), ply:IPAddress(), "steam check", nil, nil)
end

local function check(ply, force, reportTo)
	if not IsValid(ply) or ply:IsBot() then return end
	local function report(t) if isentity(reportTo) and IsValid(reportTo) then reportTo:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. t) elseif reportTo == true then print("[AC] " .. t) end end
	if force then cache[ply:SteamID64()] = nil end
	lookup(ply:SteamID64(), function(r, err)
		if not IsValid(ply) then return end
		if not r then report("Steam check failed for " .. ply:Nick() .. ": " .. tostring(err)) return end
		local text = describe(r)
		report(ply:Nick() .. ": " .. text)
		local skip = exempt(ply)
		local why
		-- the rule: a VAC ban on an account under Steam level 3 (a throwaway cheat account) = banned, appeal in
		-- the Discord. A VAC ban on a real, levelled account, or a low level with no VAC ban, is only logged.
		local minLv = S.VACLevelUnder or 3
		if S.BanVAC ~= false and r.vac and r.level and r.level < minLv then why = "VAC banned + Steam level " .. r.level end
		-- brand new accounts (throwaways): younger than zac_min_account_days = banned
		local minDays = cvDays:GetInt()
		if not why and minDays > 0 and r.created then
			local days = math.floor((os.time() - r.created) / 86400)
			if days < minDays then why = "Steam account only " .. days .. " days old (needs " .. minDays .. ")" end
		end
		if not why and minDays > 0 and not r.created then ZAC.Log("access", ZAC.Who(ply) .. " - account age hidden (private profile), not checked", text, ply) end
		if not why and r.vac then ZAC.Log("access", ZAC.Who(ply) .. " has a VAC ban (Steam level " .. tostring(r.level or "hidden") .. ") - not banned (level " .. minLv .. "+ or hidden)", text, ply) end
		if why then
			if skip then
				ZAC.Log("access", ZAC.Who(ply) .. " would be banned by the Steam check (" .. why .. ") but is an admin / whitelisted", text, ply)
			else
				ban(ply, why, text)
			end
		elseif not r.level then
			ZAC.Log("access", ZAC.Who(ply) .. " has a private Steam profile (level unknown) - not banned", text, ply)
		end

		-- family share: the owner's account is the one that cheated before
		local owner = ply:OwnerSteamID64()
		if not why and S.BanVAC ~= false and owner and owner ~= "0" and owner ~= ply:SteamID64() then
			lookup(owner, function(o)
				if not (IsValid(ply) and o and o.vac) then return end
				ZAC.Log("access", ZAC.Who(ply) .. " plays on a family-shared copy whose owner " .. util.SteamIDFrom64(owner) .. " is VAC banned (not banned)", describe(o), ply)
			end)
		end
	end)
end
ZAC.SteamCheck = check

hook.Add("PlayerInitialSpawn", "zac_steam", function(ply)
	if S.Enabled == false then return end
	-- a few seconds in, so ULX / SAM have given admins their group first
	timer.Simple(S.Delay or 6, function() if IsValid(ply) then check(ply) end end)
end)

ZAC.AdminActions.steamcheck = function(admin, target)
	local p = ZAC.FindPlayer(target)
	local function say(t) if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, "[AC] " .. t) else print("[AC] " .. t) end end
	if not p then return say("No player '" .. tostring(target) .. "' online.") end
	if key() == "" then return say("No Steam Web API key set (lua/zac/sv_secrets.lua).") end
	say("Checking " .. p:Nick() .. "...")
	check(p, true, IsValid(admin) and admin or true)
end
