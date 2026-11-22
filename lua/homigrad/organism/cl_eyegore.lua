local eyeData = {
	l = {
		model = "models/gore/head_eye02.mdl",
		bulge = { offset = Vector(-4.5, 0, -1), angle = Angle(10, 0, 0) },
		hang = { offset = Vector(-4.5, 0, -1), angle = Angle(20, 0, 0) },
	},
	r = {
		model = "models/gore/head_eye01.mdl",
		bulge = { offset = Vector(-4.5, 0.25, -1), angle = Angle(10, 0, 0) },
		hang = { offset = Vector(-4.5, 0.25, -1), angle = Angle(20, 0, 0) },
	},
}

local sides = {"l", "r"}
local modelCache = {}

local function eyeModel(model)
	if modelCache[model] then return modelCache[model] end
	local m = ClientsideModel(model, RENDERGROUP_OPAQUE)
	if IsValid(m) then
		m:SetNoDraw(true)
		modelCache[model] = m
	end
	return m
end

local function eyeValue(org, side)
	return org[side == "l" and "eyeL" or "eyeR"] or 0
end

local function eyePopped(org, side)
	return org[side == "l" and "eyePoppedL" or "eyePoppedR"]
end

local function eachTarget(func)
	for _, rag in ipairs(hg.ragdolls or {}) do
		if IsValid(rag) then
			local org = rag.new_organism or rag.organism
			if org then func(rag, org) end
		end
	end
	for _, ply in player.Iterator() do
		if IsValid(ply) and not IsValid(ply.FakeRagdoll) then
			local org = ply.new_organism or ply.organism
			if org then func(ply, org) end
		end
	end
end

local function hiddenOwnHead(ent)
	local lp = LocalPlayer()
	if not IsValid(lp) or ent ~= hg.GetCurrentCharacter(lp) then return false end
	local head = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not head then return false end
	local scale = ent:GetManipulateBoneScale(head)
	return scale and scale:LengthSqr() < 0.01
end

local function resetFlesh(ent, side)
	local state = ent.hgEyeFlesh
	if not state or not state[side] then return end
	state[side] = nil
	local mats = ent:GetMaterials() or {}
	for i, mat in ipairs(mats) do
		local name = string.lower(mat)
		if string.find(name, "eye") or string.find(name, "pupil") then
			if string.find(name, "%f[%a]" .. side .. "%f[%A]") or string.find(name, "_" .. side) then
				ent:SetSubMaterial(i - 1, "")
			end
		end
	end
end

local function applyFlesh(ent, side)
	local mats = ent:GetMaterials() or {}
	for i, mat in ipairs(mats) do
		local name = string.lower(mat)
		if string.find(name, "eye") or string.find(name, "pupil") then
			if string.find(name, "%f[%a]" .. side .. "%f[%A]") or string.find(name, "_" .. side) then
				ent:SetSubMaterial(i - 1, "models/flesh")
			end
		end
	end
end

local function spawnEye(ent, side)
	local cfg = eyeData[side]
	local attID = ent:LookupAttachment("eyes")
	if not attID or attID <= 0 then return end
	local att = ent:GetAttachment(attID)
	if not att then return end
	local wPos, wAng = LocalToWorld(cfg.bulge.offset, cfg.bulge.angle, att.Pos, att.Ang)
	local prop = ents.CreateClientProp(cfg.model)
	if not IsValid(prop) then return end
	prop:SetPos(wPos)
	prop:SetAngles(wAng)
	prop:Spawn()
	prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	local phys = prop:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetVelocity(att.Ang:Forward() * math.random(25, 50) + VectorRand(-5, 5))
	end
end

net.Receive("hg_eye_gore_pop", function()
	local ent = net.ReadEntity()
	local side = net.ReadString()
	if not IsValid(ent) or not eyeData[side] then return end
	spawnEye(ent, side)
end)


-- Chud zoom eyes: the bulging eye model is drawn over the socket, so the real
-- eyes no longer need hiding. (Hiding them with sub-materials is what left
-- players with invisible eyes after zooming.)

-- How far the eyes pop out at full zoom (units along the face). Lower = subtler.
local ZOOM_EYE_START = -1.0 -- eye sits back in the socket when zoom begins
local ZOOM_EYE_END = 0.5    -- eye position at full zoom (was +2.0)

local zoomTargets = setmetatable({}, {__mode = "k"})

-- Clear any invisible-eye material an older version of this file left behind.
local function IsZoomHidden(material)
    if not isstring(material) or material == "" then return false end
    local name = string.lower(string.gsub(material, "^!", ""))
    return name == "chud_zoom_hidden_eyes" or name == "chud_zoom_hidden_eyes_v2"
end
local function ClearLeftoverHiddenEyes(ent)
    if not IsValid(ent) or not ent.GetMaterials then return end
    for i in ipairs(ent:GetMaterials() or {}) do
        if IsZoomHidden(ent:GetSubMaterial(i - 1)) then ent:SetSubMaterial(i - 1, "") end
    end
end
timer.Create("ChudZoomEyesLeftoverCleanup", 1, 0, function()
    for _, ply in player.Iterator() do ClearLeftoverHiddenEyes(ply) end
    for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do ClearLeftoverHiddenEyes(rag) end
end)

hook.Add("Think", "ChudZoomEyeAnimation", function()
    local seen = {}
    eachTarget(function(ent, org)
        seen[ent] = true
        local owner = ent:IsPlayer() and ent or (hg.RagdollOwner and hg.RagdollOwner(ent))
        local healthy = not org.headamputated and eyeValue(org, "l") < 1 and eyeValue(org, "r") < 1
            and not eyePopped(org, "l") and not eyePopped(org, "r")
        local active = healthy and IsValid(owner) and owner:Alive() and owner:GetNWBool("ChudZoomEyes", false)
        local amount = zoomTargets[ent] or 0
        amount = healthy and math.Approach(amount, active and 1 or 0, FrameTime() / 0.25) or 0
        zoomTargets[ent] = amount
        ent.ChudZoomEyeAmount = amount
    end)
    for ent in pairs(zoomTargets) do
        if not seen[ent] then
            if IsValid(ent) then ent.ChudZoomEyeAmount = nil end
            zoomTargets[ent] = nil
        end
    end
end)

hook.Add("PostDrawOpaqueRenderables", "hg_eye_gore_draw", function()
	eachTarget(function(ent, org)
		if hiddenOwnHead(ent) or org.headamputated then return end
        local viewer = LocalPlayer()
        local owner = ent:IsPlayer() and ent or (hg.RagdollOwner and hg.RagdollOwner(ent))
        local ownBody = IsValid(viewer) and (ent == viewer or owner == viewer
            or ent == viewer:GetNWEntity("FakeRagdoll") or ent == viewer.FakeRagdoll)
        -- Cosmetic zoom eyes are visible to other players, never their owner.
        local zoomAmount = not ownBody and (ent.ChudZoomEyeAmount or 0) or 0
        local zoomSlide = zoomAmount * zoomAmount * (3 - 2 * zoomAmount)
		local attID = ent:LookupAttachment("eyes")
		if not attID or attID <= 0 then return end
		local att = ent:GetAttachment(attID)
		if not att then return end
		for _, side in ipairs(sides) do
			local v = eyeValue(org, side)
			ent.hgEyeFlesh = ent.hgEyeFlesh or {}
			if v < 1 then
				resetFlesh(ent, side)
                if zoomAmount > 0 and not eyePopped(org, side) then
                    local cfg = eyeData[side]
                    local m = eyeModel(cfg.model)
                    if IsValid(m) then
                        local pos, ang = LocalToWorld(cfg.bulge.offset + Vector(Lerp(zoomSlide, ZOOM_EYE_START, ZOOM_EYE_END), 0, 0), cfg.bulge.angle, att.Pos, att.Ang)
                        m:SetPos(pos)
                        m:SetAngles(ang)
                        m:SetupBones()
                        local blend = render.GetBlend()
                        render.SetBlend(blend * math.min(zoomAmount * 6, 1))
                        m:DrawModel()
                        render.SetBlend(blend)
                    end
                end
			else
				if not ent.hgEyeFlesh[side] then
					ent.hgEyeFlesh[side] = true
					applyFlesh(ent, side)
				end
				if eyePopped(org, side) then continue end
				local cfg = eyeData[side]
				local hanging = v >= 1
				local offset = hanging and cfg.hang.offset or cfg.bulge.offset
				local angle = hanging and cfg.hang.angle or cfg.bulge.angle
				local m = eyeModel(cfg.model)
				if not IsValid(m) then continue end
				local wPos, wAng = LocalToWorld(offset, angle, att.Pos, att.Ang)
				m:SetPos(wPos)
				m:SetAngles(wAng)
				m:SetupBones()
				m:DrawModel()
			end
		end
	end)
end)
