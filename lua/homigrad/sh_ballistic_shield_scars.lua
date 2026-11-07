-- Cosmetic history belongs to the weapon, never to its disposable client model.
local shieldClass, message = "weapon_ballistic_shield", "hg_shield_scars_v3"
local limit = 128
local glassScale = 6 -- Additional scale specific to viewport cracks.
local decalScale = 2 -- Linear enlargement of metal impact marks.

if SERVER then
	util.AddNetworkString(message)
	local function send(shield, recipient)
		net.Start(message)
		net.WriteEntity(shield)
		net.WriteUInt(shield.ShieldScarEpoch, 32)
		net.WriteUInt(shield.ShieldScarRevision, 32)
		net.WriteUInt(#shield.ShieldScars, 8)
		for _, mark in ipairs(shield.ShieldScars) do
			net.WriteUInt(mark.id, 32)
			net.WriteVector(mark.pos)
			net.WriteNormal(mark.dir)
			net.WriteFloat(mark.travel)
			net.WriteBool(mark.penetrated)
			net.WriteUInt(mark.variant, 3)
			net.WriteFloat(mark.scale)
		end
		if recipient then
			net.Send(recipient)
		else
			local owner = shield:GetOwner()
			local character = IsValid(owner) and (owner:IsPlayer() and hg.GetCurrentCharacter(owner) or owner) or shield
			if not IsValid(character) then character = shield end
			net.SendPVS(character:GetPos())
		end
	end

	function hg.RecordShieldScar(trace)
		local shield = trace.Entity
		if not IsValid(shield) or shield:GetClass() ~= shieldClass or not trace.ShieldScar
			or trace.ShieldScarRecorded or not trace.ShieldOrigin or not trace.ShieldAngles then return end
		trace.ShieldScarRecorded = true
		if hg.BallisticShieldFeedback then hg.BallisticShieldFeedback(trace) end
		if shield.ShieldScarTick ~= CurTime() then shield.ShieldScarTick, shield.ShieldScarCount = CurTime(), 0 end
		-- Visual limits must never limit pellet damage, block tests or penetration.
		if shield.ShieldScarCount >= 16 then return end
		shield.ShieldScarCount = shield.ShieldScarCount + 1
		local pos = WorldToLocal(trace.HitPos, angle_zero, trace.ShieldOrigin, trace.ShieldAngles)
		local dir = WorldToLocal(trace.HitPos + trace.Normal, angle_zero, trace.ShieldOrigin, trace.ShieldAngles) - pos
		if dir:LengthSqr() < 0.5 then return end
		if not shield.ShieldScarEpoch then
			hg.ShieldScarEpoch = (hg.ShieldScarEpoch or 0) + 1
			shield.ShieldScarEpoch, shield.ShieldScarRevision, shield.ShieldScars = hg.ShieldScarEpoch, 0, {}
		end
		local ammo = isnumber(trace.ShieldAmmo) and game.GetAmmoName(trace.ShieldAmmo) or trace.ShieldAmmo
		local fragment = ammo == "Metal Debris" or ammo == "metal_debris"
		shield.ShieldScarRevision = shield.ShieldScarRevision + 1
		local mark = {id = shield.ShieldScarRevision, pos = pos, dir = dir:GetNormalized(),
			travel = math.Clamp(trace.ShieldTravel or 128, 0, 256), penetrated = trace.ShieldBlocked == false,
			variant = math.random(1, 5), scale = fragment and 0.5 or math.Rand(0.8, 1.15)}
		table.insert(shield.ShieldScars, mark)
		if #shield.ShieldScars > limit then table.remove(shield.ShieldScars, 1) end
		if shield.ShieldScarPending then return end
		shield.ShieldScarPending = true
		timer.Simple(0.1, function()
			if not IsValid(shield) then return end
			shield.ShieldScarPending = nil
			shield:SetNWInt("ShieldScarEpoch", shield.ShieldScarEpoch)
			shield:SetNWInt("ShieldScarRevision", shield.ShieldScarRevision)
			-- A full bounded snapshot also recovers packet gaps and first visibility.
			send(shield)
		end)
	end

	function hg.RecordDroppedShieldScar(trace, start, ammo)
		local shield = trace.Entity
		if not trace.Hit or trace.StartSolid or not IsValid(shield) or shield:GetClass() ~= shieldClass
			or IsValid(shield:GetOwner()) or not isfunction(shield.BlocksShieldAmmo) then return end
		-- SetupBones is client-only; server weapons may have no cached matrix yet.
		local bone = shield:LookupBone("shield")
		local matrix = bone and shield:GetBoneMatrix(bone)
		local direction = trace.HitPos - start
		if not matrix or direction:LengthSqr() < 0.0001 then return end
		hg.RecordShieldScar({Entity = shield, HitPos = trace.HitPos, Normal = direction:GetNormalized(), ShieldScar = true,
			ShieldOrigin = matrix:GetTranslation(), ShieldAngles = matrix:GetAngles(), ShieldAmmo = ammo,
			ShieldBlocked = shield:BlocksShieldAmmo(ammo), ShieldTravel = 128})
	end

	local requests = setmetatable({}, {__mode = "k"})
	net.Receive(message, function(_, ply)
		local shield = net.ReadEntity()
		if not IsValid(shield) or shield:GetClass() ~= shieldClass or not shield.ShieldScars then return end
		local now = CurTime()
		local state = requests[ply] or {at = now, tokens = 8, shields = setmetatable({}, {__mode = "k"})}
		requests[ply] = state
		state.tokens, state.at = math.min(8, state.tokens + (now - state.at) * 4), now
		if state.tokens < 1 or (state.shields[shield] or 0) > now then return end
		state.tokens, state.shields[shield] = state.tokens - 1, now + 0.5
		-- Different visible shields must not starve behind one global cooldown.
		send(shield, ply)
	end)
	return
end

local function releaseMeshes(history)
	if not history then return end
	for _, group in pairs(history.meshes or {}) do
		for _, cached in ipairs(group) do cached:Destroy() end
	end
	history.meshes = nil
end

net.Receive(message, function()
	local shield, epoch, revision, count = net.ReadEntity(), net.ReadUInt(32), net.ReadUInt(32), net.ReadUInt(8)
	if count > limit then return end
	local marks = {}
	for i = 1, count do
		marks[i] = {id = net.ReadUInt(32), pos = net.ReadVector(), dir = net.ReadNormal(), travel = net.ReadFloat(),
			penetrated = net.ReadBool(), variant = net.ReadUInt(3), scale = net.ReadFloat()}
	end
	if not IsValid(shield) or shield:GetClass() ~= shieldClass then return end
	local knownEpoch = shield:GetNWInt("ShieldScarEpoch", 0)
	if knownEpoch ~= 0 and epoch ~= knownEpoch then return end
	local old = shield.ShieldScarHistory
	if old and old.epoch == epoch and old.revision >= revision then return end
	if old and old.epoch ~= epoch then releaseMeshes(old); old = nil end
	-- Keep model identity and projections between snapshots. Losing `model`
	-- here used to invalidate every accumulated scar after every bullet.
	local history = old or {cache = {}}
	history.epoch, history.revision, history.marks, history.groups = epoch, revision, marks, nil
	shield.ShieldScarHistory = history
end)

-- Only read raw mesh/bind-pose data. Never call DecalEx, SetupBones, SetBoneMatrix,
-- RemoveAllDecals, SetRenderBounds or material overrides on the rendered shield.
local geometry, materials = {}, {}
local function modelTriangles(model)
	local path = model:GetModel()
	local bone = model:LookupBone("shield")
	if not path or not bone then return end
	local key = path .. ":" .. bone
	if geometry[key] then return geometry[key] end
	local meshes, binds = util.GetModelMeshes(path, 0, 0)
	local bind = binds and binds[bone] and binds[bone].matrix
	if not meshes or not bind then return end -- Missing Workshop data can arrive later.
	local triangles = {}
	for _, part in ipairs(meshes) do
		for i = 1, #part.triangles, 3 do
			local va, vb, vc = part.triangles[i], part.triangles[i + 1], part.triangles[i + 2]
			local a, b, c = bind * va.pos, bind * vb.pos, bind * vc.pos
			local normal = (b - a):Cross(c - a):GetNormalized()
			local expected = bind * (va.pos + va.normal) - a
			-- Source mesh winding is clockwise. Preserve its vertex order; the
			-- outward normal is independent of the cross product's sign.
			if normal:Dot(expected) < 0 then normal = -normal end
			if normal:LengthSqr() > 0.5 then
				triangles[#triangles + 1] = {a = a, b = b, c = c, ab = b - a, ac = c - a, n = normal,
					xmin = math.min(a.x, b.x, c.x), xmax = math.max(a.x, b.x, c.x),
					ymin = math.min(a.y, b.y, c.y), ymax = math.max(a.y, b.y, c.y),
					zmin = math.min(a.z, b.z, c.z), zmax = math.max(a.z, b.z, c.z)}
			end
		end
	end
	geometry[key] = triangles
	return triangles
end

local function rayTriangle(start, dir, tri)
	local ab, ac = tri.ab, tri.ac
	local px, py, pz = dir.y * ac.z - dir.z * ac.y, dir.z * ac.x - dir.x * ac.z, dir.x * ac.y - dir.y * ac.x
	local det = ab.x * px + ab.y * py + ab.z * pz
	if math.abs(det) < 0.000001 then return end
	local x, y, z = start.x - tri.a.x, start.y - tri.a.y, start.z - tri.a.z
	local u = (x * px + y * py + z * pz) / det
	if u < -0.00001 or u > 1.00001 then return end
	local qx, qy, qz = y * ab.z - z * ab.y, z * ab.x - x * ab.z, x * ab.y - y * ab.x
	local v = (dir.x * qx + dir.y * qy + dir.z * qz) / det
	if v < -0.00001 or u + v > 1.00001 then return end
	return (ac.x * qx + ac.y * qy + ac.z * qz) / det
end

-- Clip projected texture coordinates to each actual surface triangle. There are
-- no floating quads over the window, rounded corners, plate edges or handles.
local function clip(poly, axis, bound, sign)
	local result = {}
	local previous = poly[#poly]
	for _, current in ipairs(poly) do
		local a, b = (previous[axis] - bound) * sign, (current[axis] - bound) * sign
		if (a >= 0) ~= (b >= 0) then
			local t = a / (a - b)
			result[#result + 1] = {pos = LerpVector(t, previous.pos, current.pos),
				u = Lerp(t, previous.u, current.u), v = Lerp(t, previous.v, current.v),
				normal = previous.normal, color = previous.color}
		end
		if b >= 0 then result[#result + 1] = current end
		previous = current
	end
	return result
end

local scarColor = Color(255, 255, 255, 255)
local clipPlanes = {{"u", 0, 1}, {"u", 1, -1}, {"v", 0, 1}, {"v", 1, -1}}
local function coordinates(pos, point, u, v, normal, scale)
	local x, y, z = pos.x - point.x, pos.y - point.y, pos.z - point.z
	return (x * u.x + y * u.y + z * u.z) * scale + 0.5,
		(x * v.x + y * v.y + z * v.z) * scale + 0.5, x * normal.x + y * normal.y + z * normal.z
end

local function project(triangles, point, normal, radius, rotation, output, lift)
	local reference = math.abs(normal.z) < 0.9 and Vector(0, 0, 1) or Vector(0, 1, 0)
	local u = normal:Cross(reference):GetNormalized()
	local v = normal:Cross(u)
	u, v = u * math.cos(rotation) + v * math.sin(rotation), v * math.cos(rotation) - u * math.sin(rotation)
	for _, tri in ipairs(triangles) do
		if tri.n:Dot(normal) > 0.65 then
			local au, av, ad = coordinates(tri.a, point, u, v, normal, 1 / (radius * 2))
			local bu, bv, bd = coordinates(tri.b, point, u, v, normal, 1 / (radius * 2))
			local cu, cv, cd = coordinates(tri.c, point, u, v, normal, 1 / (radius * 2))
			if math.min(ad, bd, cd) <= 0.3 and math.max(ad, bd, cd) >= -0.3
				and math.min(au, bu, cu) <= 1 and math.max(au, bu, cu) >= 0
				and math.min(av, bv, cv) <= 1 and math.max(av, bv, cv) >= 0 then
				-- Allocate polygons only for nearby intersecting triangles, not for
				-- the entire model four times per penetrating bullet.
				local offset = tri.n * (lift or 0.025)
				local poly = {{pos = tri.a + offset, u = au, v = av, normal = tri.n, color = scarColor},
					{pos = tri.b + offset, u = bu, v = bv, normal = tri.n, color = scarColor},
					{pos = tri.c + offset, u = cu, v = cv, normal = tri.n, color = scarColor}}
				for _, plane in ipairs(clipPlanes) do
					if #poly > 0 then poly = clip(poly, plane[1], plane[2], plane[3]) end
				end
				for i = 2, #poly - 1 do
					output[#output + 1], output[#output + 2], output[#output + 3] = poly[1], poly[i], poly[i + 1]
				end
			end
		end
	end
end

-- The model has an open, curved viewport. Match its inner rim in shield-bone
-- coordinates; cosmetic laminated glass does not change the existing bullet OBB.
local windowHalfWidth, windowBottom, windowTop = 9.67, 14.46, 18.81
local windowCurve, windowCentre = 0.01446, 2.47
local function windowHit(start, dir, travel)
	local a = windowCurve * dir.y * dir.y
	local b = dir.x + 2 * windowCurve * start.y * dir.y
	local c = start.x - windowCentre + windowCurve * start.y * start.y
	local first, second
	if math.abs(a) < 0.0000001 then
		if math.abs(b) < 0.0000001 then return end
		first = -c / b
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return end
		first, second = (-b - math.sqrt(discriminant)) / (2 * a), (-b + math.sqrt(discriminant)) / (2 * a)
		if first > second then first, second = second, first end
	end
	for _, distance in ipairs({first, second}) do
		if distance >= 0 and distance <= travel then
			local point = start + dir * distance
			if math.abs(point.y) < windowHalfWidth and point.z > windowBottom and point.z < windowTop then return point, distance end
		end
	end
end

-- Reuse the immutable decal geometry for particles: the protective OBB is
-- thicker and flatter than the curved visible plate. Never pose a model here.
function hg.GetShieldParticleSurfaces(shield, point, direction, origin, angles)
	if not IsValid(shield) then return end
	local model = IsValid(shield.worldModel) and shield.worldModel or shield
	if not isfunction(model.GetModel) or not isfunction(model.LookupBone) then return end
	local triangles = modelTriangles(model)
	if not triangles then return end
	local localPoint = WorldToLocal(point, angle_zero, origin, angles)
	local dir = WorldToLocal(point + direction, angle_zero, origin, angles) - localPoint
	if dir:LengthSqr() < 0.5 then return end
	dir = dir:GetNormalized()
	local start = localPoint - dir * 8
	local finish = start + dir * 48
	local xmin, xmax = math.min(start.x, finish.x), math.max(start.x, finish.x)
	local ymin, ymax = math.min(start.y, finish.y), math.max(start.y, finish.y)
	local zmin, zmax = math.min(start.z, finish.z), math.max(start.z, finish.z)
	local first, last, entry, exit = math.huge, math.huge
	for _, tri in ipairs(triangles) do
		if tri.xmax >= xmin and tri.xmin <= xmax and tri.ymax >= ymin and tri.ymin <= ymax
			and tri.zmax >= zmin and tri.zmin <= zmax then
			local distance = rayTriangle(start, dir, tri)
			if distance and distance >= 0 and distance <= 48 then
				local facing = tri.n:Dot(dir)
				if facing < -0.01 and distance < first then first, entry = distance, tri end
				if facing > 0.01 and distance < last then last, exit = distance, tri end
			end
		end
	end
	local glass, glassDistance = windowHit(start, dir, 48)
	local front, normal, rear, rearNormal
	if glass and glassDistance < first then
		normal = Vector(1, 2 * windowCurve * glass.y, 0):GetNormalized()
		if normal:Dot(dir) > 0 then normal = -normal end
		front, rear, rearNormal = glass, glass - normal * 0.3, -normal
	elseif entry then
		front, normal = start + dir * first, entry.n
		if exit and last > first + 0.01 then rear, rearNormal = start + dir * last, exit.n
		else rear, rearNormal = front - normal * 0.7, -normal end
	else return end
	local worldFront = LocalToWorld(front, angle_zero, origin, angles)
	local worldNormal = LocalToWorld(normal, angle_zero, vector_origin, angles)
	local worldRear = LocalToWorld(rear, angle_zero, origin, angles)
	local worldRearNormal = LocalToWorld(rearNormal, angle_zero, vector_origin, angles)
	return worldFront, worldNormal, worldRear, worldRearNormal
end

local function glassMark(mark, point)
	local vertices = {}
	local radius = 1.65 * glassScale * mark.scale * (mark.penetrated and 1.2 or 1)
	local rotation = (mark.id * 2.39996 + mark.variant * 1.37) % (math.pi * 2)
	local cosine, sine = math.cos(rotation), math.sin(rotation)
	-- Native HL2 impact textures, tiled over the curve. Clip their UVs instead
	-- of stretching a complete decal into the remaining space near the frame.
	local ymin, ymax = math.max(-windowHalfWidth, point.y - radius * 1.42), math.min(windowHalfWidth, point.y + radius * 1.42)
	local zmin, zmax = math.max(windowBottom, point.z - radius * 1.42), math.min(windowTop, point.z + radius * 1.42)
	local function vertex(y, z)
		local dy, dz = y - point.y, z - point.z
		return {pos = Vector(windowCentre - windowCurve * y * y, y, z),
			normal = Vector(1, 2 * windowCurve * y, 0):GetNormalized(), color = scarColor,
			u = (dy * cosine + dz * sine) / (radius * 2) + 0.5,
			v = (-dy * sine + dz * cosine) / (radius * 2) + 0.5}
	end
	for row = 0, 3 do
		for column = 0, 5 do
			local y, ey = Lerp(column / 6, ymin, ymax), Lerp((column + 1) / 6, ymin, ymax)
			local z, ez = Lerp(row / 4, zmin, zmax), Lerp((row + 1) / 4, zmin, zmax)
			local poly = {vertex(y, z), vertex(ey, z), vertex(ey, ez), vertex(y, ez)}
			for _, plane in ipairs(clipPlanes) do
				if #poly > 0 then poly = clip(poly, plane[1], plane[2], plane[3]) end
			end
			for _, clipped in ipairs(poly) do
				clipped.pos.x = windowCentre - windowCurve * clipped.pos.y * clipped.pos.y
			end
			for i = 2, #poly - 1 do
				vertices[#vertices + 1], vertices[#vertices + 2], vertices[#vertices + 3] = poly[1], poly[i], poly[i + 1]
			end
		end
	end
	return {{key = "glass" .. mark.variant, glass = true, vertices = vertices}}
end

local function buildMark(triangles, mark)
	local start, entry, exit = mark.pos - mark.dir * 0.5
	local first, last = math.huge, math.huge
	for _, tri in ipairs(triangles) do
		local distance = rayTriangle(start, mark.dir, tri)
		if distance and distance >= 0 and distance <= (mark.penetrated and mark.travel + 0.5 or 128) then
			local facing = tri.n:Dot(mark.dir)
			if facing < -0.01 and distance < first then first, entry = distance, tri end
		end
	end
	local glass, glassDistance = windowHit(start, mark.dir, mark.penetrated and mark.travel + 0.5 or 128)
	if glass and glassDistance < first then return glassMark(mark, glass) end
	if not entry then return {} end
	if mark.penetrated then
		for _, tri in ipairs(triangles) do
			local distance = rayTriangle(start, mark.dir, tri)
			if distance and distance > first + 0.005 and distance <= mark.travel + 0.5
				and distance < last and tri.n:Dot(mark.dir) > 0.01 then last, exit = distance, tri end
		end
	end
	local layers = {}
	local function scar(tri, distance, exiting)
		local point = start + mark.dir * distance
		local key = mark.penetrated and (exiting and "exit" or "entry") or "dent"
		local radius = mark.penetrated and (exiting and 0.68 or 0.46) or 0.6
		local layer = {key = key, vertices = {}}
		-- Native rough impact textures contain their own edge shading. A solid
		-- bright backing turns them into silver discs on the shield's dark paint.
		project(triangles, point, tri.n, radius * decalScale * mark.scale, mark.variant * 1.37 + mark.id * 0.71, layer.vertices, 0.05)
		layers[#layers + 1] = layer
	end
	scar(entry, first, false)
	if exit then scar(exit, last, true) end
	return layers
end

local metalTextures = {dent = "decals/metal/shot4", entry = "decals/metal/shot6", exit = "decals/metal/shot7"}
local function material(key)
	if not materials[key] then
		local texture = metalTextures[key]
		if string.sub(key, 1, 5) == "glass" then
			texture = "decals/glass/shot" .. string.sub(key, 6)
		elseif key == "entry" or key == "exit" then
			-- CS:S is optional. Keep a built-in HL2 impact if it is not mounted.
			if not file.Exists("materials/" .. texture .. ".vtf", "GAME") then
				texture = key == "entry" and "decals/metal/shot1" or "decals/metal/shot3"
			end
		end
		-- Match the native shader and its neutral-grey texture convention.
		materials[key] = CreateMaterial("hg_shield_scars_native_v1_" .. key, "DecalModulate", {
			["$basetexture"] = texture,
			["$model"] = "1", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$nocull"] = "1",
			["$translucent"] = "1", ["$decal"] = "1",
		})
	end
	return materials[key]
end

local function drawHistory(history, glassOnly)
	-- Upload immutable geometry once, then draw it directly on the GPU. Steady
	-- frames do not resubmit thousands of vertices through Lua mesh callbacks.
	history.meshes = history.meshes or {}
	for _, key in ipairs({"dent", "entry", "exit", "glass1", "glass2", "glass3", "glass4", "glass5"}) do
		local vertices = history.groups[key]
		if vertices and #vertices > 0 and (string.sub(key, 1, 5) == "glass") == glassOnly then
			local mat = material(key)
			if not history.meshes[key] then
				local group = {}
				history.meshes[key] = group
				for first = 1, #vertices, 32766 do
					local chunk = {}
					for i = first, math.min(first + 32765, #vertices) do chunk[#chunk + 1] = vertices[i] end
					local cached = Mesh(mat)
					group[#group + 1] = cached
					cached:BuildFromTriangles(chunk)
				end
			end
			render.SetMaterial(mat)
			-- A second native modulation pass strengthens the impact's contrast;
			-- neutral grey stays neutral, with no opaque white backing.
			for _, cached in ipairs(history.meshes[key]) do
				cached:Draw()
				cached:Draw()
			end
		end
	end
end

local function drawProjected(shield, history, pos, ang, glassOnly)
	local transform = Matrix()
	transform:SetTranslation(pos)
	transform:SetAngles(ang)
	local red, green, blue = render.GetColorModulation()
	cam.PushModelMatrix(transform)
	local ok, err = pcall(drawHistory, history, glassOnly)
	cam.PopModelMatrix()
	render.SetColorModulation(red, green, blue)
	if not ok and shield.ShieldScarRenderError ~= err then
		shield.ShieldScarRenderError = err
		ErrorNoHalt("[shield scars] " .. tostring(err) .. "\n")
	end
end

local glassFrame, glassViews = -1, {}
local function glassView()
	local target = render.GetRenderTarget() -- The main framebuffer may return zero values.
	return tostring(target) .. ":" .. tostring(RENDERING_SCOPE or false)
		.. ":" .. tostring(EyePos()) .. ":" .. tostring(EyeAngles())
end

-- Player/ragdoll RenderOverride draws weapons before the character's body.
-- Only the glass must wait until every actor has finished its render pass.
hook.Add("PostDrawTranslucentRenderables", "hg_shield_glass_scars", function(depth, skybox)
	if glassFrame ~= FrameNumber() then glassFrame, glassViews = FrameNumber(), {} return end
	if depth or skybox then return end
	local view = glassView()
	local queued = glassViews[view]
	if not queued then return end
	glassViews[view] = nil -- Multiple callbacks for the same view must not multiply decals.
	local ordered, eye = {}, EyePos()
	for shield, item in pairs(queued) do
		if IsValid(shield) and shield.ShieldScarHistory == item.history then
			item.shield = shield
			ordered[#ordered + 1] = item
		end
	end
	table.sort(ordered, function(a, b) return (a.pos - eye):LengthSqr() > (b.pos - eye):LengthSqr() end)
	for _, item in ipairs(ordered) do drawProjected(item.shield, item.history, item.pos, item.ang, true) end
end, HOOK_MONITOR_LOW or 2) -- ULib: after the normal forced-fake shield fallback.

local buildFrame, buildCount, buildUntil = -1, 0, 0
function hg.DrawShieldScars(shield, model, pos, ang)
	-- The melee camera also poses/draws its WM during CalcView, outside a 3D pass.
	if shield.ShieldCameraUpdating then return end
	local history = shield.ShieldScarHistory
	local epoch, revision = shield:GetNWInt("ShieldScarEpoch", 0), shield:GetNWInt("ShieldScarRevision", 0)
	if revision > 0 and (not history or epoch ~= history.epoch or revision > history.revision)
		and (shield.ShieldScarRequestAt or 0) <= CurTime() then
		shield.ShieldScarRequestAt = CurTime() + 1
		net.Start(message)
		net.WriteEntity(shield)
		net.SendToServer()
	end
	if not history or #history.marks == 0 then return end
	local triangles = modelTriangles(model)
	if not triangles then return end
	if history.format ~= 10 then
		releaseMeshes(history)
		history.cache, history.groups, history.model, history.format = {}, nil, nil, 10
	end
	if history.model ~= model:GetModel() then
		releaseMeshes(history)
		history.model, history.cache, history.groups = model:GetModel(), {}, nil
	end
	if not shield.ShieldScarMeshCleanup then
		shield.ShieldScarMeshCleanup = true
		shield:CallOnRemove("hg_shield_scar_meshes", function(ent) releaseMeshes(ent.ShieldScarHistory) end)
	end
	local frame, retained = FrameNumber(), {}
	if buildFrame ~= frame then buildFrame, buildCount, buildUntil = frame, 0, SysTime() + 0.001 end
	for i = #history.marks, 1, -1 do
		local mark = history.marks[i]
		local layers = history.cache[mark.id]
		if not layers and buildCount < 1 and SysTime() < buildUntil then
			layers = buildMark(triangles, mark)
			buildCount = buildCount + 1
			history.groups = nil
		end
		retained[mark.id] = layers
	end
	history.cache = retained
	if not history.groups then
		releaseMeshes(history)
		history.groups = {}
		local glassCount = 0
		for i = #history.marks, 1, -1 do
			local mark = history.marks[i]
			for _, layer in ipairs(history.cache[mark.id] or {}) do
				if layer.glass then glassCount = glassCount + 1 end
				if not layer.glass or glassCount <= 16 then
					local group = history.groups[layer.key] or {}
					history.groups[layer.key] = group
					for _, vertex in ipairs(layer.vertices) do group[#group + 1] = vertex end
				end
			end
		end
	end
	drawProjected(shield, history, pos, ang, false)
	for key, vertices in pairs(history.groups) do
		if string.sub(key, 1, 5) == "glass" and #vertices > 0 then
			if glassFrame ~= FrameNumber() then glassFrame, glassViews = FrameNumber(), {} end
			local view = glassView()
			glassViews[view] = glassViews[view] or {}
			glassViews[view][shield] = {history = history,
				pos = Vector(pos.x, pos.y, pos.z), ang = Angle(ang.p, ang.y, ang.r)}
			break
		end
	end
end
