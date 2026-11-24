local cfg = ZAC.Config
local UNITS_TO_M = 0.01905

local BONE_PART = {
	["ValveBiped.Bip01_Head1"] = "Head", ["ValveBiped.Bip01_Neck1"] = "Neck",
	["ValveBiped.Bip01_Spine4"] = "Upper chest", ["ValveBiped.Bip01_Spine2"] = "Chest",
	["ValveBiped.Bip01_Spine1"] = "Stomach", ["ValveBiped.Bip01_Spine"] = "Stomach", ["ValveBiped.Bip01_Pelvis"] = "Pelvis",
	["ValveBiped.Bip01_L_Clavicle"] = "Left shoulder", ["ValveBiped.Bip01_L_UpperArm"] = "Left upper arm",
	["ValveBiped.Bip01_L_Forearm"] = "Left forearm", ["ValveBiped.Bip01_L_Hand"] = "Left hand",
	["ValveBiped.Bip01_R_Clavicle"] = "Right shoulder", ["ValveBiped.Bip01_R_UpperArm"] = "Right upper arm",
	["ValveBiped.Bip01_R_Forearm"] = "Right forearm", ["ValveBiped.Bip01_R_Hand"] = "Right hand",
	["ValveBiped.Bip01_L_Thigh"] = "Left thigh", ["ValveBiped.Bip01_L_Calf"] = "Left calf",
	["ValveBiped.Bip01_L_Foot"] = "Left foot", ["ValveBiped.Bip01_L_Toe0"] = "Left foot",
	["ValveBiped.Bip01_R_Thigh"] = "Right thigh", ["ValveBiped.Bip01_R_Calf"] = "Right calf",
	["ValveBiped.Bip01_R_Foot"] = "Right foot", ["ValveBiped.Bip01_R_Toe0"] = "Right foot",
}
ZAC.HeadParts = { Head = true, Neck = true }
ZAC.HeadOrgans = { Brain = true, Skull = true, Jaw = true }

local function hitPart(ent, pos)
	if not pos or pos:IsZero() or not IsValid(ent) then return nil end
	local best, bd
	for i = 0, (ent:GetBoneCount() or 0) - 1 do
		local part = BONE_PART[ent:GetBoneName(i) or ""]
		if part then
			local bp = ent:GetBonePosition(i)
			if bp then
				local d = bp:DistToSqr(pos)
				if not bd or d < bd then best, bd = part, d end
			end
		end
	end
	if bd and bd > 60 * 60 then return nil end
	return best
end

local DMG_NAMES = {
	{ DMG_BULLET, "bullet" }, { DMG_BUCKSHOT, "buckshot" }, { DMG_BLAST, "explosion" }, { DMG_SLASH, "slash" },
	{ DMG_CLUB, "blunt" }, { DMG_BURN, "fire" }, { DMG_FALL, "fall" }, { DMG_CRUSH, "crush" }, { DMG_DROWN, "drown" },
	{ DMG_SHOCK, "shock" }, { DMG_POISON, "poison" }, { DMG_ACID, "acid" }, { DMG_NERVEGAS, "gas" },
	{ DMG_VEHICLE, "vehicle" }, { DMG_SONIC, "sonic" }, { DMG_PHYSGUN, "physgun" },
}
local function dmgName(t)
	for _, d in ipairs(DMG_NAMES) do
		if bit.band(t, d[1]) ~= 0 then return d[2] end
	end
	return "generic"
end

local function weaponOf(att, inf)
	if IsValid(inf) and inf:IsWeapon() then return inf end
	if IsValid(att) and att:IsPlayer() then
		local w = att:GetActiveWeapon()
		if IsValid(w) then return w end
	end
	if IsValid(inf) and inf ~= att then return inf end
end
local function weaponName(w)
	if not IsValid(w) then return "" end
	local name = w.PrintName
	if not isstring(name) or name == "" or string.sub(name, 1, 1) == "#" then name = w:GetClass() end
	return name
end

local function victimOf(ent)
	if ent:IsPlayer() then return ent end
	local owner = hg and hg.RagdollOwner and hg.RagdollOwner(ent)
	if IsValid(owner) and owner:IsPlayer() then return owner end
	if IsValid(ent.ply) and ent.ply:IsPlayer() and ent.ply.FakeRagdoll == ent then return ent.ply end
end
local function attackerOf(att)
	if not IsValid(att) then return att end
	if att:IsPlayer() then return att end
	return victimOf(att) or att
end
ZAC.VictimOf = victimOf

hook.Add("PlayerSpawn", "zac_hits_reset", function(ply)
	ply.ZACHits = {}
	ply.ZACDeathDone = nil
	ply.ZACPending = nil
end)

local function playerBehind(att)
	att = attackerOf(att)
	if IsValid(att) and not att:IsPlayer() then
		local owner = att.GetOwner and att:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then return owner end
	end
	return att
end

local function sighting(target, victim, dmg, attacker, hitPos, organs)
	local att = playerBehind(attacker or dmg:GetAttacker())
	local wep = weaponOf(dmg:GetAttacker(), dmg:GetInflictor())
	if IsValid(wep) and IsValid(wep.weapon) then wep = wep.weapon end
	local pos = hitPos or dmg:GetDamagePosition()
	if pos and pos:IsZero() then pos = nil end
	return {
		att = att, wep = wep, amount = dmg:GetDamage(), isBullet = dmg:IsBulletDamage(), kind = dmgName(dmg:GetDamageType()),
		part = hitPart(target, pos or dmg:GetDamagePosition()), target = target, organs = organs,
		snap = ZAC.Snapshot and ZAC.Snapshot(att, victim, target, pos) or nil,
	}
end

local flushPending

local function queue(victim, src, s)
	local p = victim.ZACPending
	if not p or p.t ~= CurTime() then
		if p then flushPending(victim) end
		p = { t = CurTime(), etd = {}, hd = {} }
		victim.ZACPending = p
		timer.Simple(0, function() if IsValid(victim) then flushPending(victim) end end)
	end
	table.insert(p[src], s)
end

local function better(a, b)
	if not a then return b end
	if not b then return a end
	local function isPly(s) return IsValid(s.att) and s.att:IsPlayer() end
	local m = {}
	for k, v in pairs(b) do m[k] = v end
	if isPly(a) and not isPly(b) then m.att = a.att end
	if not IsValid(m.wep) or (IsValid(a.wep) and a.wep:IsWeapon() and not m.wep:IsWeapon()) then m.wep = a.wep end
	m.snap = (b.snap and b.att == m.att and b.snap) or (a.snap and a.att == m.att and a.snap) or b.snap or a.snap
	if m.snap and not m.snap.hit then m.snap.hit = (b.snap and b.snap.hit) or (a.snap and a.snap.hit) end
	m.organs = b.organs or a.organs
	m.amount = math.max(a.amount or 0, b.amount or 0)
	m.part = b.part or a.part
	m.isBullet = a.isBullet or b.isBullet
	if m.kind == "generic" then m.kind = a.kind end
	return m
end

local function record(victim, s)
	local amount = s.amount or 0
	if amount <= 0 and not s.isBullet then return end
	local att = s.att
	local byPlayer = IsValid(att) and att:IsPlayer() and att ~= victim
	local dist = (IsValid(att) and att ~= victim) and att:GetPos():Distance(victim:GetPos()) * UNITS_TO_M or 0

	local hit = {
		t = CurTime(), clock = os.time(), part = s.part or "Body", dmg = amount, kind = s.kind,
		att = byPlayer and att or nil, attName = byPlayer and att:Nick() or (IsValid(att) and att ~= victim and att:GetClass() or (att == victim and "Self" or "World")),
		attSid = byPlayer and att:SteamID() or nil, weapon = weaponName(s.wep), dist = dist,
	}
	hit.head = ZAC.HeadParts[hit.part] == true
	for _, o in ipairs(s.organs or {}) do
		if ZAC.HeadOrgans[o.name] then hit.head = true hit.headOrgan = o.name break end
	end
	victim.ZACHits = victim.ZACHits or {}
	table.insert(victim.ZACHits, hit)
	if #victim.ZACHits > 60 then table.remove(victim.ZACHits, 1) end

	if byPlayer and ZAC.AimOnHit then ZAC.AimOnHit(att, victim, hit, s.isBullet) end
	if byPlayer and ZAC.SilentOnHit then ZAC.SilentOnHit(att, victim, hit, s.snap, s.isBullet) end
	if byPlayer and ZAC.RatingOnHit then ZAC.RatingOnHit(att, victim, hit, s.isBullet) end

	if not byPlayer then
		victim.ZACEnvLog = victim.ZACEnvLog or {}
		if (victim.ZACEnvLog[s.kind] or 0) > CurTime() then return end
		victim.ZACEnvLog[s.kind] = CurTime() + cfg.EnvDamageLogEvery
	end

	local organs = s.organs and #s.organs > 0 and s.organs or nil
	local organText = ""
	if organs then
		local t = {}
		for _, o in ipairs(organs) do t[#t + 1] = o.name end
		organText = "  -> " .. table.concat(t, " > ")
	end
	local e = ZAC.Log("damage", string.format("%s -> %s  %s  %.1f %s%s%s%s",
		byPlayer and ZAC.Who(att) or hit.attName, ZAC.Who(victim), hit.part, amount, s.kind,
		hit.weapon ~= "" and ("  [" .. hit.weapon .. "]") or "",
		dist > 0 and string.format("  %.0fm", dist) or "", organText), nil, byPlayer and att or nil, victim)

	if byPlayer and s.snap and e and ZAC.StoreView then
		ZAC.StoreView(e.id, { attName = att:Nick(), attSid = att:SteamID(), vicName = victim:Nick(), vicSid = victim:SteamID(),
			weapon = hit.weapon, part = hit.part, kind = s.kind, dmg = amount, dist = dist, clock = hit.clock,
			snap = s.snap, organs = organs })
		hit.viewId = e.id
	end
end

flushPending = function(victim)
	local p = victim.ZACPending
	if not p then return end
	victim.ZACPending = nil
	for i = 1, math.max(#p.etd, #p.hd) do
		record(victim, better(p.etd[i], p.hd[i]))
	end
end
ZAC.FlushHits = flushPending

hook.Add("EntityTakeDamage", "zac_damage", function(target, dmg)
	if not IsValid(target) then return end
	local victim = victimOf(target)
	if not IsValid(victim) or not victim:Alive() then return end
	queue(victim, "etd", sighting(target, victim, dmg))
end)

hook.Add("HomigradDamage", "zac_damage", function(ply, dmg, _, ent, _, _, inputHole)
	local victim = IsValid(ply) and victimOf(ply)
	if not IsValid(victim) or not victim:Alive() then return end
	local attacker = dmg:GetAttacker()
	if not (IsValid(attacker) and attackerOf(attacker):IsPlayer()) then
		local phys = victim.GetPhysicsAttacker and victim:GetPhysicsAttacker()
		if IsValid(phys) then attacker = phys end
	end
	local entry = istable(inputHole) and isvector(inputHole[1]) and inputHole[1] or nil
	local organs = ZAC.TakeOrgans and ZAC.TakeOrgans(victim) or nil
	queue(victim, "hd", sighting(IsValid(ent) and ent or ply, victim, dmg, attacker, entry, organs))
end)

local ORGANS = {
	{ "brain", "Brain" }, { "skull", "Skull" }, { "jaw", "Jaw" }, { "heart", "Heart" },
	{ "lungsL", "Left lung" }, { "lungsR", "Right lung" }, { "trachea", "Trachea" }, { "liver", "Liver" },
	{ "stomach", "Stomach" }, { "intestines", "Intestines" }, { "chest", "Ribs" },
	{ "spine1", "Lower spine" }, { "spine2", "Mid spine" }, { "spine3", "Upper spine" }, { "pelvis", "Pelvis" },
	{ "larm", "Left arm" }, { "rarm", "Right arm" }, { "lleg", "Left leg" }, { "rleg", "Right leg" },
}
local FLAGS = {
	{ "headamputated", "Head cut off" }, { "larmamputated", "Left arm amputated" }, { "rarmamputated", "Right arm amputated" },
	{ "llegamputated", "Left leg amputated" }, { "rlegamputated", "Right leg amputated" },
	{ "heartstop", "Heart stopped" }, { "pneumothorax", "Collapsed lung" },
}
local ARTERIES = { arteria = "Neck artery", larmartery = "Left arm artery", rarmartery = "Right arm artery",
	llegartery = "Left leg artery", rlegartery = "Right leg artery", spineartery = "Spine artery" }

local function num(v)
	if isnumber(v) then return v end
	if istable(v) and isnumber(v[1]) then return v[1] end
	if isbool(v) then return v and 1 or 0 end
end

local function organReport(ply)
	local org = ply.organism
	if not istable(org) then return {}, {}, nil, nil end
	local organs, flags = {}, {}
	for _, o in ipairs(ORGANS) do
		local v = num(org[o[1]])
		if v and v > 0.02 then organs[#organs + 1] = { o[2], math.Clamp(math.Round(v * 100), 1, 100) } end
	end
	for _, f in ipairs(FLAGS) do
		local v = org[f[1]]
		if v == true or (isnumber(v) and v > 0.5) then flags[#flags + 1] = f[2] end
	end
	for k, label in SortedPairs(ARTERIES) do
		local v = num(org[k])
		if v and v > 0 then flags[#flags + 1] = label .. " cut" end
	end
	local blood = num(org.blood)
	local o2 = num(org.o2)

	local cause
	if org.headamputated then cause = "Decapitated"
	elseif (num(org.brain) or 0) >= 1 then cause = "Brain destroyed"
	elseif blood and blood < 2500 then cause = "Blood loss"
	elseif o2 and o2 < 5 then cause = "No oxygen (suffocation)"
	elseif (num(org.heart) or 0) >= 1 or org.heartstop then cause = "Heart failure"
	end
	return organs, flags, blood, cause
end

local function onDeath(victim, attacker)
	if not IsValid(victim) or victim.ZACDeathDone then return end
	victim.ZACDeathDone = true
	flushPending(victim)

	local hits = {}
	for _, h in ipairs(victim.ZACHits or {}) do
		if CurTime() - h.t <= math.max(60, cfg.HitMemory) then hits[#hits + 1] = h end
	end

	attacker = attackerOf(attacker)
	local killer = (IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim) and attacker or nil
	local killHit
	for i = #hits, 1, -1 do
		local h = hits[i]
		if h.att and (not killer or h.att == killer) and CurTime() - h.t <= cfg.HitMemory then
			killer, killHit = IsValid(h.att) and h.att or killer, h
			break
		end
	end
	local last = hits[#hits]

	local organs, flags, blood, cause = organReport(victim)
	cause = cause or (last and (last.kind == "bullet" and ("Shot in the " .. string.lower(last.part)) or (last.kind .. " damage"))) or "Unknown"

	local weapon = killHit and killHit.weapon or ""
	local dist = killHit and killHit.dist or 0
	local shooters, order = {}, {}
	for _, h in ipairs(hits) do
		if h.attSid then
			if not shooters[h.attSid] then shooters[h.attSid] = { name = h.attName, n = 0, dmg = 0 } order[#order + 1] = h.attSid end
			shooters[h.attSid].n = shooters[h.attSid].n + 1
			shooters[h.attSid].dmg = shooters[h.attSid].dmg + h.dmg
		end
	end
	local shotBy = {}
	for _, sid in ipairs(order) do
		local s = shooters[sid]
		shotBy[#shotBy + 1] = string.format("%s (%s) %d hit%s", s.name, sid, s.n, s.n == 1 and "" or "s")
	end

	local msg
	if killer then
		msg = string.format("%s killed %s%s%s  (%s)", ZAC.Who(killer), ZAC.Who(victim),
			weapon ~= "" and (" with " .. weapon) or "", dist > 0 and string.format(" at %.0fm", dist) or "", cause)
	else
		msg = string.format("%s died  (%s)", ZAC.Who(victim), cause)
	end
	if #shotBy > 0 then msg = msg .. "  |  shot by: " .. table.concat(shotBy, ", ") end

	local L = { "DEATH REPORT  " .. os.date("%Y-%m-%d %H:%M:%S"),
		"Victim:  " .. ZAC.Who(victim),
		"Killer:  " .. (killer and ZAC.Who(killer) or "none (world / self)"),
		"Shot by: " .. (#shotBy > 0 and table.concat(shotBy, ", ") or "nobody"),
		"Cause:   " .. cause }
	if weapon ~= "" then L[#L + 1] = "Weapon:  " .. weapon .. (dist > 0 and string.format("  (%.0f m)", dist) or "") end
	if blood then L[#L + 1] = string.format("Blood:   %d / 5000 ml", blood) end
	L[#L + 1] = "Hits (last " .. math.max(60, cfg.HitMemory) .. " s):"
	if #hits == 0 then L[#L + 1] = "  none recorded" end
	for _, h in ipairs(hits) do
		L[#L + 1] = string.format("  %s  %-15s %6.1f  %-9s %s%s%s", os.date("%H:%M:%S", h.clock), h.part, h.dmg, h.kind,
			h.attSid and (h.attName .. " (" .. h.attSid .. ")") or h.attName,
			h.weapon ~= "" and ("  " .. h.weapon) or "", h.dist > 0 and string.format("  %.0fm", h.dist) or "")
	end
	if #organs > 0 then
		local t = {}
		for _, o in ipairs(organs) do t[#t + 1] = o[1] .. " " .. o[2] .. "%" end
		L[#L + 1] = "Damaged: " .. table.concat(t, ", ")
	end
	if #flags > 0 then L[#L + 1] = "Also:    " .. table.concat(flags, ", ") end
	if killer and ZAC.RatingOnKill then pcall(ZAC.RatingOnKill, killer, victim, hits, killHit) end
	local de = ZAC.Log("death", msg, table.concat(L, "\n"), killer, victim)
	if de and killHit and killHit.viewId and ZAC.LinkView then ZAC.LinkView(de.id, killHit.viewId) end
end

hook.Add("PlayerDeath", "zac_death", function(victim, _, attacker) onDeath(victim, attacker) end)
hook.Add("PostPlayerDeath", "zac_death", function(victim) onDeath(victim) end)
timer.Create("zac_death_watch", 0.25, 0, function()
	for _, p in player.Iterator() do
		if not p:Alive() and not p.ZACDeathDone and p:Team() ~= TEAM_SPECTATOR and p.ZACHits then onDeath(p) end
	end
end)
