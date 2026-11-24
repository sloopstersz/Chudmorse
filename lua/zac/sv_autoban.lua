-- AUTO-BANS from the cheat rating (sv_rating.lua):
--   * rated CHEATING (score 60+ from 2+ different kinds of evidence)         -> permanent ban
--   * "very close": score NearScore+ (default 50) from 2+ kinds of evidence   -> NearMinutes ban (default 7 days)
-- Admins and whitelisted accounts are never auto-banned (they still get rated and logged).
-- Settings: AutoBan in sv_config.lua. Every ban is posted to Discord with the reasons.
local cfg = ZAC.Config
local A = cfg.AutoBan or {}
local R = cfg.Rating
local LEVELS = { "LEGIT", "SUSPECT", "CHEATING" }

local function exempt(ply)
	if ply:IsAdmin() then return true end -- real admins only, not moderators
	local wl = ZAC.Access and ZAC.Access.wl or {}
	return wl[ply:SteamID()] ~= nil or wl[ply:SteamID64()] ~= nil
end

local function kinds(byKind)
	local n = 0
	for _, v in pairs(byKind or {}) do if v >= (R.KindMin or 8) then n = n + 1 end end
	return n
end

local function reasonsOf(ply)
	local p = ZAC.Ratings and ZAC.Ratings[ply:SteamID()]
	if not p then return "" end
	local _, _, reasons = ZAC.RatingOf(p)
	return table.concat(reasons or {}, "\n")
end

hook.Add("ZACRatingEvidence", "zac_autoban", function(ply, level, score, byKind)
	if A.Enabled == false or not IsValid(ply) or ply:IsBot() or ply.ZACAutoBanned then return end
	local permanent = A.Cheating ~= false and level >= 3
	local near = not permanent and A.NearScore and score >= A.NearScore and kinds(byKind) >= (A.NearKinds or R.CheatingKinds or 2)
	if not (permanent or near) then return end
	local reasons = reasonsOf(ply)
	if exempt(ply) then
		if not ply.ZACAutoBanSkipLogged then
			ply.ZACAutoBanSkipLogged = true
			ZAC.Log("aim", ZAC.Who(ply) .. " would be auto-banned (score " .. score .. ") but is an admin / whitelisted", reasons, ply)
		end
		return
	end
	local label = permanent and "rated CHEATING" or ("score " .. score .. ", close to CHEATING")
	if ZAC.ManualOnly and ZAC.ManualOnly() then
		if not ply.ZACAutoBanSkipLogged then
			ply.ZACAutoBanSkipLogged = true
			ZAC.Log("aim", ZAC.Who(ply) .. " " .. label .. " - NOT banned (manual mode). Check them: zac spectate / zac screengrab, ban: zac ban " .. ply:SteamID(), reasons, ply)
		end
		return
	end
	ply.ZACAutoBanned = true
	local minutes = permanent and nil or (A.NearMinutes or 10080)
	ZAC.Log("aim", ZAC.Who(ply) .. " auto-banned (" .. label .. ")", reasons, ply)
	-- a moment's delay so the evidence that tipped it over is logged / posted first
	local sid, name, ip = ply:SteamID(), ply:Nick(), ply:IPAddress()
	timer.Simple(1, function()
		ZAC.Ban(sid, (A.Message or "Cheating") .. " (auto-ban: " .. label .. ") please appeal in the discord", name, ip, "auto-ban", nil, minutes)
	end)
end)
