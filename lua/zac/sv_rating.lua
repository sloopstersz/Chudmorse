local cfg = ZAC.Config
local R = cfg.Rating

util.AddNetworkString("zac_ratings_req")
util.AddNetworkString("zac_ratings")

ZAC.Ratings = ZAC.Ratings or {}
local SAVE = "zac/ratings.json"

local LEVELS = { "LEGIT", "SUSPECT", "CHEATING" }
ZAC.RatingLevels = LEVELS

local KIND_NAME = { headkill = "headshot kills", chain = "fast head-kill chains", snap = "snap-to-head hits", onetap = "one-tap head kills at range", hsrate = "headshot rate", speed = "speedhack", silent = "silent aim (off-angle shots)", walltrack = "tracking players through walls", airstuck = "airstuck / held movement", tickbase = "tick manipulation" }

do
	local t = file.Exists(SAVE, "DATA") and ZAC.JSONLoadIDs(file.Read(SAVE, "DATA") or "") or nil
	if istable(t) then for sid, p in pairs(t) do if not ZAC.Ratings[sid] then ZAC.Ratings[sid] = p end end end
end

local saveAt = 0
local function save() saveAt = CurTime() + 5 end
timer.Create("zac_ratings_save", 5, 0, function()
	if saveAt == 0 or CurTime() < saveAt then return end
	saveAt = 0
	local now, out = os.time(), {}
	for sid, p in pairs(ZAC.Ratings) do
		if #(p.ev or {}) > 0 or #(p.hits or {}) > 0 or (p.last or 0) > now - 86400 * 3 then out[sid] = p end
	end
	file.Write(SAVE, util.TableToJSON(out))
end)

local function profile(ply)
	local sid = ply:SteamID()
	local p = ZAC.Ratings[sid]
	if not p then
		p = { name = ply:Nick(), ev = {}, hits = {}, kills = {}, level = 1 }
		ZAC.Ratings[sid] = p
	end
	p.name, p.last = ply:Nick(), os.time()
	p.ev, p.hits, p.kills = p.ev or {}, p.hits or {}, p.kills or {}
	return p
end

local function decay(age) return 0.5 ^ (math.max(age, 0) / R.HalfLife) end

local function stateParts(p)
	local out = {}
	local n, head = 0, 0
	for _, h in ipairs(p.hits) do
		if not h.pellet then
			n = n + 1
			if h.head then head = head + 1 end
		end
	end
	if n >= R.HSMinHits then
		local smooth = (head + R.HSBaseline * R.HSPrior) / (n + R.HSPrior)
		local pts = math.Clamp((smooth - R.HSFloor) * R.HSScale, 0, R.HSMax)
		if pts > 0 then out[#out + 1] = { kind = "hsrate", pts = pts, text = string.format("%d%% headshots over %d bullet hits", math.Round(head / n * 100), n) } end
	end
	local far, tap = 0, 0
	for _, k in ipairs(p.kills) do
		if k.dist >= R.OneTapMinDist then
			far = far + 1
			if k.tap then tap = tap + 1 end
		end
	end
	if far >= R.OneTapMinKills then
		local f = tap / far
		local pts = math.Clamp((f - R.OneTapFloor) * R.OneTapScale, 0, R.OneTapMax)
		if pts > 0 then out[#out + 1] = { kind = "onetap", pts = pts, text = string.format("%d of %d kills past %dm were one-shot headshots", tap, far, R.OneTapMinDist) } end
	end
	return out
end

function ZAC.RatingOf(p)
	local now = os.time()
	local score, byKind, reasons = 0, {}, {}
	for i = #p.ev, 1, -1 do
		local e = p.ev[i]
		local v = e.pts * decay(now - e.t)
		if v >= 0.5 then
			score = score + v
			byKind[e.kind] = (byKind[e.kind] or 0) + v
			if #reasons < 6 then reasons[#reasons + 1] = string.format("%s  (+%d)  %s", os.date("%H:%M", e.t), math.Round(v), e.text) end
		end
	end
	for _, s in ipairs(stateParts(p)) do
		score = score + s.pts
		byKind[s.kind] = (byKind[s.kind] or 0) + s.pts
		table.insert(reasons, 1, string.format("now  (+%d)  %s", math.Round(s.pts), s.text))
	end
	local kinds = 0
	for _, v in pairs(byKind) do if v >= R.KindMin then kinds = kinds + 1 end end
	local level = 1
	if score >= R.Suspect then level = 2 end
	if score >= R.Cheating and kinds >= R.CheatingKinds then level = 3 end
	return level, math.Round(score), reasons, byKind
end

local function evidence(ply, kind, pts, text, victim)
	if pts <= 0 or not IsValid(ply) or (ply:IsBot() and not R.RateBots) then return end
	local p = profile(ply)
	p.ev[#p.ev + 1] = { t = os.time(), kind = kind, pts = math.Round(pts, 1), text = text }
	while #p.ev > R.MaxEvidence do table.remove(p.ev, 1) end
	local level, score, _, byKind = ZAC.RatingOf(p)
	if level > (p.level or 1) then
		local parts = {}
		for k, v in SortedPairsByValue(byKind, true) do parts[#parts + 1] = (KIND_NAME[k] or k) .. " " .. math.Round(v) end
		ZAC.Log("aim", string.format("%s is now rated %s (score %d: %s)", ZAC.Who(ply), LEVELS[level], score, table.concat(parts, ", ")), nil, ply, victim)
		hook.Run("ZACRatingRaised", ply, level)
	end
	p.level = level
	save()
	hook.Run("ZACRatingEvidence", ply, level, score, byKind)
end
ZAC.RatingEvidence = evidence

function ZAC.RatingOnHit(att, victim, hit, isBullet)
	if not isBullet or not IsValid(att) or (att:IsBot() and not R.RateBots) then return end
	local p = profile(att)
	local pellet = hit.kind == "buckshot"
	local last = p.hits[#p.hits]
	if last and last.vic == victim:SteamID() and CurTime() - (att.ZACLastHitT or 0) < 0.03 then return end
	att.ZACLastHitT = CurTime()
	p.hits[#p.hits + 1] = { head = hit.head == true or ZAC.HeadParts[hit.part] == true, pellet = pellet or nil, vic = victim:SteamID() }
	while #p.hits > R.HSWindow do table.remove(p.hits, 1) end
end

function ZAC.RatingOnKill(killer, victim, hits, killHit)
	if not (IsValid(killer) and killer:IsPlayer() and killHit) or killer == victim then return end
	if killer:IsBot() and not R.RateBots then return end
	local now = CurTime()
	local mine, lastT = 0, nil
	for _, h in ipairs(hits) do
		if h.att == killer and (h.kind == "bullet" or h.kind == "buckshot") and now - h.t <= R.EngageWindow then
			if not lastT or h.t - lastT > 0.05 then mine = mine + 1 end
			lastT = h.t
		end
	end
	local head = killHit.head == true or ZAC.HeadParts[killHit.part] == true
	local instant = now - killHit.t <= R.InstantDeath
	local tap = head and instant and mine <= 1 and killHit.kind == "bullet"
	local dist = killHit.dist or 0

	local p = profile(killer)
	p.kills[#p.kills + 1] = { tap = tap or nil, dist = math.Round(dist) }
	while #p.kills > R.KillWindow do table.remove(p.kills, 1) end

	if not (head and killHit.kind == "bullet") then save() return end
	local mult = 1
	for _, step in ipairs(R.HeadKillDistance or {}) do
		if dist < step[1] then mult = step[2] break end
		mult = step[2]
	end
	evidence(killer, "headkill", (R.HeadKillPoints or 5) * mult,
		string.format("headshot kill on %s (%.0fm)", IsValid(victim) and victim:Nick() or "?", dist), victim)
end

function ZAC.RatingOnSnap(att, victim, hit, snapDeg)
	local head = hit.head == true or ZAC.HeadParts[hit.part] == true
	local pts = (head and R.SnapHead or R.SnapBody) * ((hit.dist or 0) >= 20 and 1.3 or 1) * math.Clamp(snapDeg / 60, 0.7, 1.5)
	evidence(att, "snap", pts, string.format("snapped %.0f deg onto %s's %s and hit (%.0fm)", snapDeg, victim:Nick(), string.lower(hit.headOrgan or hit.part), hit.dist or 0), victim)
end

-- zac rating_clear <steamid | steamid64 | name of someone online | all>   (server console too)
-- wipes their suspicion rating back to CLEAN (a false alarm). Says what it did either way.
ZAC.AdminActions.rating_clear = function(admin, id)
	local function say(t) if IsValid(admin) then admin:PrintMessage(HUD_PRINTCONSOLE, t) admin:ChatPrint(t) else print(t) end end
	id = string.Trim(tostring(id or ""))
	if id == "" then return say("Usage: zac rating_clear <steamid | steamid64 | name | all>") end
	local function wipe(sid, p)
		p.ev, p.hits, p.kills, p.level = {}, {}, {}, 1
		ZAC.Log("admin", ZAC.Who(admin) .. " cleared the cheat rating of " .. (p.name or sid) .. " (" .. sid .. ")", nil, admin)
	end
	if string.lower(id) == "all" then
		local n = 0
		for sid, p in pairs(ZAC.Ratings) do if istable(p) then wipe(sid, p) n = n + 1 end end
		save()
		return say("[ZAC] Cleared the cheat rating of " .. n .. " player(s).")
	end
	local sid = ZAC.SID(id)
	if not sid and ZAC.FindPlayer then
		local pl = ZAC.FindPlayer(id)
		if IsValid(pl) then sid = pl:SteamID() end
	end
	if not sid then return say("[ZAC] No player / SteamID matches '" .. id .. "'. Use STEAM_0:X:Y or a SteamID64.") end
	local p = ZAC.Ratings[sid]
	if not p then return say("[ZAC] " .. sid .. " has no cheat rating (already clean).") end
	local before = select(2, ZAC.RatingOf(p))
	wipe(sid, p)
	save()
	say(string.format("[ZAC] Cleared the cheat rating of %s (%s) - was score %s, now CLEAN.", p.name or "?", sid, tostring(before or 0)))
end
ZAC.AdminActions.clearrating = ZAC.AdminActions.rating_clear

net.Receive("zac_ratings_req", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACRateNext or 0) > CurTime() then return end
	ply.ZACRateNext = CurTime() + 1
	local list = {}
	for _, p in player.Iterator() do
		local pr = ZAC.Ratings[p:SteamID()]
		if pr then
			local level, score, reasons = ZAC.RatingOf(pr)
			list[#list + 1] = { sid = p:SteamID(), level = level, score = score, reasons = reasons }
		else
			list[#list + 1] = { sid = p:SteamID(), level = 1, score = 0, reasons = {} }
		end
	end
	net.Start("zac_ratings")
	net.WriteUInt(#list, 8)
	for _, r in ipairs(list) do
		net.WriteString(r.sid)
		net.WriteUInt(r.level, 2)
		net.WriteUInt(math.Clamp(r.score, 0, 65535), 16)
		net.WriteUInt(math.min(#r.reasons, 8), 4)
		for i = 1, math.min(#r.reasons, 8) do net.WriteString(string.sub(r.reasons[i], 1, 200)) end
	end
	net.Send(ply)
end)
