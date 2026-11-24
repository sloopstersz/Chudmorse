local cfg = ZAC.Config
local VIEW_MEMORY = cfg.ViewMemory or 4000

util.AddNetworkString("zac_view_req")
util.AddNetworkString("zac_view")

ZAC.Views = ZAC.Views or {}
ZAC.ViewOrder = ZAC.ViewOrder or {}

local ORGAN_NAMES = {
	brain = "Brain", skull = "Skull", jaw = "Jaw", eyes = "Eyes", heart = "Heart", lungsL = "Left lung", lungsR = "Right lung",
	trachea = "Trachea", liver = "Liver", stomach = "Stomach", intestines = "Intestines", chest = "Ribs",
	spine1 = "Lower spine", spine2 = "Mid spine", spine3 = "Upper spine", pelvis = "Pelvis",
	larm = "Left arm", rarm = "Right arm", lleg = "Left leg", rleg = "Right leg",
	arteria = "Neck artery", larmartery = "Left arm artery", rarmartery = "Right arm artery",
	llegartery = "Left leg artery", rlegartery = "Right leg artery", spineartery = "Spine artery",
}
local function organName(id)
	id = tostring(id or "")
	if ORGAN_NAMES[id] then return ORGAN_NAMES[id] end
	local low = string.lower(id)
	if string.find(low, "vest", 1, true) then return "Body armor" end
	if string.find(low, "helmet", 1, true) then return "Helmet" end
	if string.find(low, "mask", 1, true) then return "Mask" end
	return (string.gsub(id, "^%l", string.upper))
end
ZAC.OrganName = organName

hook.Add("PreTraceOrganBulletDamage", "zac_view_organs", function(org, _, _, _, _, _, hit, _, organ)
	if not (istable(org) and istable(organ) and organ[1]) then return end
	local victim = IsValid(org.owner) and ZAC.VictimOf and ZAC.VictimOf(org.owner)
	if not IsValid(victim) then return end
	local list = victim.ZACOrganHits
	if not list or list.t ~= CurTime() then
		list = { t = CurTime() }
		victim.ZACOrganHits = list
	end
	local name = organName(organ[1])
	if list[#list] and list[#list].name == name then return end
	list[#list + 1] = { name = name, pos = isvector(hit) and Vector(hit) or nil }
end)

function ZAC.TakeOrgans(victim)
	local list = victim.ZACOrganHits
	victim.ZACOrganHits = nil
	if not list or list.t ~= CurTime() then return nil end
	return list
end

local function character(p)
	if hg and hg.GetCurrentCharacter then
		local c = hg.GetCurrentCharacter(p)
		if IsValid(c) then return c end
	end
	return p
end

local function eyeOf(p, body)
	if body ~= p then
		local bone = body:LookupBone("ValveBiped.Bip01_Head1")
		local pos = bone and body:GetBonePosition(bone)
		if pos then return pos end
	end
	return p:EyePos()
end

function ZAC.Snapshot(att, victim, target, hitPos)
	if not (IsValid(att) and att:IsPlayer() and IsValid(victim) and att ~= victim) then return nil end
	local aBody = character(att)
	local vBody = (IsValid(target) and target ~= victim and target:GetClass() == "prop_ragdoll") and target or character(victim)
	local aMin, aMax = aBody:WorldSpaceAABB()
	local vMin, vMax = vBody:WorldSpaceAABB()
	return {
		aEye = eyeOf(att, aBody), aAng = att:EyeAngles(), aMin = aMin, aMax = aMax, aRag = aBody ~= att,
		vMin = vMin, vMax = vMax, vRag = vBody ~= victim, hit = hitPos and Vector(hitPos) or nil,
	}
end

local function trim()
	while #ZAC.ViewOrder > VIEW_MEMORY do
		ZAC.Views[table.remove(ZAC.ViewOrder, 1)] = nil
	end
end

function ZAC.StoreView(id, v)
	ZAC.Views[id] = v
	ZAC.ViewOrder[#ZAC.ViewOrder + 1] = id
	trim()
end

function ZAC.LinkView(id, hitId)
	local v = ZAC.Views[hitId]
	if not v then return end
	local k = table.Copy(v)
	k.killed = true
	ZAC.StoreView(id, k)
end

net.Receive("zac_view_req", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACViewNext or 0) > CurTime() then return end
	ply.ZACViewNext = CurTime() + 0.3
	local id = net.ReadUInt(32)
	local v = ZAC.Views[id]

	net.Start("zac_view")
	net.WriteUInt(id, 32)
	net.WriteBool(v ~= nil)
	if v then
		net.WriteBool(v.killed == true)
		net.WriteString(v.attName or "") net.WriteString(v.attSid or "")
		net.WriteString(v.vicName or "") net.WriteString(v.vicSid or "")
		net.WriteString(v.weapon or "") net.WriteString(v.part or "") net.WriteString(v.kind or "")
		net.WriteFloat(v.dmg or 0) net.WriteFloat(v.dist or 0) net.WriteUInt(v.clock or 0, 32)
		local s = v.snap
		net.WriteVector(s.aEye) net.WriteAngle(s.aAng) net.WriteVector(s.aMin) net.WriteVector(s.aMax) net.WriteBool(s.aRag)
		net.WriteVector(s.vMin) net.WriteVector(s.vMax) net.WriteBool(s.vRag)
		net.WriteBool(s.hit ~= nil)
		if s.hit then net.WriteVector(s.hit) end
		local organs = v.organs or {}
		net.WriteUInt(math.min(#organs, 15), 4)
		for i = 1, math.min(#organs, 15) do
			net.WriteString(organs[i].name)
			net.WriteBool(organs[i].pos ~= nil)
			if organs[i].pos then net.WriteVector(organs[i].pos) end
		end
	end
	net.Send(ply)
end)

util.AddNetworkString("zac_view_goto")
util.AddNetworkString("zac_view_goto_result")

local function result(ply, ok, text)
	net.Start("zac_view_goto_result")
	net.WriteBool(ok)
	net.WriteString(text)
	net.Send(ply)
end

local function freeSpot(ply, base, toward)
	local mins, maxs = ply:OBBMins(), ply:OBBMaxs()
	local function free(pos)
		local tr = util.TraceHull({ start = pos, endpos = pos, mins = mins, maxs = maxs, filter = ply, mask = MASK_PLAYERSOLID })
		return not tr.StartSolid and not tr.Hit
	end
	local function ground(pos)
		local tr = util.TraceHull({ start = pos, endpos = pos - Vector(0, 0, 200), mins = mins, maxs = maxs, filter = ply, mask = MASK_PLAYERSOLID })
		return tr.HitPos
	end
	local dir = toward - base
	dir.z = 0
	if dir:IsZero() then dir = Vector(1, 0, 0) end
	dir:Normalize()
	local candidates = { base + Vector(0, 0, 8) }
	for _, r in ipairs({ 48, 96, 144 }) do
		for i = 0, 7 do
			local a = math.rad(i * 45)
			local d = Vector(dir.x * math.cos(a) - dir.y * math.sin(a), dir.x * math.sin(a) + dir.y * math.cos(a), 0)
			candidates[#candidates + 1] = base + d * r + Vector(0, 0, 8)
		end
	end
	for _, c in ipairs(candidates) do
		if free(c) then return ground(c) end
	end
	return nil
end

net.Receive("zac_view_goto", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACGotoNext or 0) > CurTime() then return end
	ply.ZACGotoNext = CurTime() + 1
	local id, which = net.ReadUInt(32), net.ReadUInt(2)
	local v = ZAC.Views[id]
	if not v then return result(ply, false, "That view is gone (server restarted or too old).") end
	if not ply:Alive() then return result(ply, false, "You're dead - respawn first.") end

	local s = v.snap
	local vBase = Vector((s.vMin.x + s.vMax.x) / 2, (s.vMin.y + s.vMax.y) / 2, s.vMin.z)
	local aBase = Vector((s.aMin.x + s.aMax.x) / 2, (s.aMin.y + s.aMax.y) / 2, s.aMin.z)
	local base, other, who = vBase, aBase, "the victim (" .. (v.vicName or "?") .. ")"
	if which == 2 then base, other, who = aBase, vBase, "the shooter (" .. (v.attName or "?") .. ")" end

	if ply:InVehicle() then ply:ExitVehicle() end
	if IsValid(ply.FakeRagdoll) and hg and hg.FakeUp then pcall(hg.FakeUp, ply, true, true) end

	local spot = freeSpot(ply, base, other)
	if not spot then return result(ply, false, "No free spot to stand near " .. who .. " (walls / players in the way).") end
	ply:SetPos(spot)
	ply:SetVelocity(-ply:GetVelocity())
	local look = (which == 2 and (s.hit or vBase) or s.aEye) - (spot + Vector(0, 0, 64))
	ply:SetEyeAngles(look:Angle())
	ZAC.Log("admin", ZAC.Who(ply) .. " teleported to " .. who .. " of a logged hit (View)", nil, ply)
	result(ply, true, "Teleported to " .. who .. ". The boxes stay drawn: walk around them, or pick Free camera again.")
end)
