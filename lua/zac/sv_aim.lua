local cfg = ZAC.Config
local N = 24
local CurTime, sqrt, AngleDifference = CurTime, math.sqrt, math.AngleDifference

hook.Add("StartCommand", "zac_aim", function(ply, cmd)
	if not cfg.AimCheck or ply:IsBot() or not ply:Alive() then return end
	local ang = cmd:GetViewAngles()
	local p, y = ang.p, ang.y
	local lp, ly = ply.ZACLastP, ply.ZACLastY
	ply.ZACLastP, ply.ZACLastY = p, y
	if not lp then return end
	local dp, dy = AngleDifference(p, lp), AngleDifference(y, ly)
	local bt, bd = ply.ZACAimT, ply.ZACAimD
	if not bt then
		bt, bd = {}, {}
		for i = 1, N do bt[i], bd[i] = -1, 0 end
		ply.ZACAimT, ply.ZACAimD, ply.ZACAimI = bt, bd, 0
	end
	local i = ply.ZACAimI % N + 1
	ply.ZACAimI = i
	bt[i], bd[i] = CurTime(), sqrt(dp * dp + dy * dy)
end)

hook.Add("PlayerSpawn", "zac_aim_reset", function(ply) ply.ZACLastP, ply.ZACLastY, ply.ZACAimT, ply.ZACAimD = nil, nil, nil, nil end)

local function flag(att, text, victim)
	att.ZACAimFlags = (att.ZACAimFlags or 0) + 1
	ZAC.Log("aim", string.format("%s %s  (flag #%d)", ZAC.Who(att), text, att.ZACAimFlags), nil, att, victim)
	if cfg.AlertAdmins then ZAC.AdminChat(att:Nick() .. " " .. text .. " (flag #" .. att.ZACAimFlags .. ")") end
end

function ZAC.AimOnHit(att, victim, hit, isBullet)
	if not cfg.AimCheck or not isBullet or att:IsBot() then return end

	att.ZACBulletHits = (att.ZACBulletHits or 0) + 1
	if hit.head or ZAC.HeadParts[hit.part] then att.ZACHeadHits = (att.ZACHeadHits or 0) + 1 end
	local n, h = att.ZACBulletHits, att.ZACHeadHits or 0
	if n >= cfg.HeadshotMinHits and h / n >= cfg.HeadshotRatio and n >= (att.ZACHSNextCheck or 0) then
		att.ZACHSNextCheck = n + 25
		flag(att, string.format("has a %d%% headshot rate (%d of %d bullet hits)", math.Round(h / n * 100), h, n))
	end

	if (att.ZACSnapNext or 0) > CurTime() then return end
	local bt, bd, head = att.ZACAimT, att.ZACAimD, att.ZACAimI
	if not bt then return end
	local now = CurTime()
	local snap, snapK
	for k = 0, N - 1 do
		local i = (head - 1 - k) % N + 1
		if bt[i] < 0 or now - bt[i] > cfg.SnapWindow then break end
		if bd[i] >= cfg.SnapDegrees and (not snap or bd[i] > snap) then snap, snapK = bd[i], k end
	end
	if not snap then return end
	local after = 0
	for k = 0, snapK - 1 do
		local i = (head - 1 - k) % N + 1
		if bd[i] > after then after = bd[i] end
	end
	if after > cfg.SnapSettle then return end

	att.ZACSnapNext = now + cfg.SnapCooldown
	if ZAC.RatingOnSnap then ZAC.RatingOnSnap(att, victim, hit, snap) end
	flag(att, string.format("snapped %.0f deg onto %s's %s and hit (%.0f m)", snap, victim:Nick(), string.lower(hit.part), hit.dist), victim)
end

-- SILENT AIM: a bullet landed on the victim while the shooter's view pointed elsewhere.
-- snap.aEye = where the shooter's eyes were, snap.aAng = the view angle the client sent us, snap.hit =
-- where the bullet actually hit. A legit hitscan shot goes along the view vector (plus a little gun
-- spread / recoil); "server silent" aim fires at the target without moving the view, so the angle
-- between the two is large. All of this is on the server - the cheat can't take it back.
function ZAC.SilentOnHit(att, victim, hit, snap, isBullet)
	if not cfg.SilentCheck or not isBullet or att:IsBot() then return end
	if not (snap and isvector(snap.aEye) and isangle(snap.aAng) and isvector(snap.hit)) then return end
	if hit.kind == "buckshot" then return end                    -- shotguns spread too wide to judge
	local dir = snap.hit - snap.aEye
	local d = dir:Length()
	if d < cfg.SilentMinDist then return end                     -- too close: hitbox offset looks like a big angle
	local off = math.deg(math.acos(math.Clamp(snap.aAng:Forward():Dot(dir / d), -1, 1)))
	if off < cfg.SilentDegrees then return end

	local b = att.ZACSilent
	if not b or CurTime() - b.first > cfg.SilentWindow then b = { first = CurTime(), n = 0, sum = 0, worst = 0 } att.ZACSilent = b end
	b.n = b.n + 1
	b.sum = b.sum + off
	b.worst = math.max(b.worst, off)
	if b.n < cfg.SilentMinHits then return end
	if (att.ZACSilentNext or 0) > CurTime() then return end
	att.ZACSilentNext = CurTime() + cfg.SilentCooldown
	local avg = b.sum / b.n
	att.ZACSilent = nil
	if ZAC.RatingEvidence then
		ZAC.RatingEvidence(att, "silent", cfg.SilentPoints,
			string.format("%d shots hit while aiming %.0f deg off target (worst %.0f, ~%.0f m)", b.n, avg, b.worst, hit.dist), victim)
	end
	flag(att, string.format("hit %s while looking %.0f deg off target - silent aim (%d shots, worst %.0f deg)", victim:Nick(), avg, b.n, b.worst), victim)
end
