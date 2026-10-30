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


-- Use actual transparent pixels and alpha testing, not a white texture whose
-- shader alpha can render opaque on player eye meshes.
local zoomHiddenMaterial = "!chud_zoom_hidden_eyes_v2"
local hiddenEyeTexture = GetRenderTarget("chud_zoom_hidden_eyes_rgba_v2", 16, 16)
render.PushRenderTarget(hiddenEyeTexture)
render.Clear(0, 0, 0, 0, true, true)
render.PopRenderTarget()
CreateMaterial("chud_zoom_hidden_eyes_v2", "VertexLitGeneric", {
    ["$basetexture"] = hiddenEyeTexture:GetName(), ["$model"] = "1",
    ["$alphatest"] = "1", ["$alphatestreference"] = "0.5"
})
local zoomTargets = setmetatable({}, {__mode = "k"})
local function IsZoomHidden(material)
    if not isstring(material) then return false end
    local name = string.lower(string.gsub(material, "^!", ""))
    return name == "chud_zoom_hidden_eyes" or name == "chud_zoom_hidden_eyes_v2"
end
local function RestoreZoomEyes(ent, state)
    if not IsValid(ent) then return end
    for slot, original in pairs(state.materials or {}) do
        if IsZoomHidden(ent:GetSubMaterial(slot)) then
            -- nil clears the override and restores the model's own eye material.
            if original == "" or IsZoomHidden(original) then ent:SetSubMaterial(slot)
            else ent:SetSubMaterial(slot, original) end
        end
    end
    -- Recover eyes left hidden by an older patch or a Lua refresh.
    for i in ipairs(ent:GetMaterials() or {}) do
        if IsZoomHidden(ent:GetSubMaterial(i - 1)) then ent:SetSubMaterial(i - 1) end
    end
    state.materials = {}
end
hook.Add("Think", "ChudZoomEyeAnimation", function()
    local seen = {}
    eachTarget(function(ent, org)
        seen[ent] = true
        local owner = ent:IsPlayer() and ent or (hg.RagdollOwner and hg.RagdollOwner(ent))
        local healthy = not org.headamputated and eyeValue(org, "l") < 1 and eyeValue(org, "r") < 1
            and not eyePopped(org, "l") and not eyePopped(org, "r")
        local active = healthy and IsValid(owner) and owner:Alive() and owner:GetNWBool("ChudZoomEyes", false)
        local state = zoomTargets[ent] or ent.ChudZoomEyeState or {amount = 0, materials = {}, model = ent:GetModel()}
        ent.ChudZoomEyeState = state
        zoomTargets[ent] = state
        if state.model ~= ent:GetModel() then
            RestoreZoomEyes(ent, state)
            state.model = ent:GetModel()
        end
        state.amount = healthy and math.Approach(state.amount, active and 1 or 0, FrameTime() / 0.25) or 0
        ent.ChudZoomEyeAmount = state.amount
        if state.amount > 0 then
            for i, material in ipairs(ent:GetMaterials() or {}) do
                local name = string.lower(material)
                if string.find(name, "eye", 1, true) or string.find(name, "pupil", 1, true) then
                    local slot = i - 1
                    if state.materials[slot] == nil then
                        local original = ent:GetSubMaterial(slot) or ""
                        state.materials[slot] = IsZoomHidden(original) and "" or original
                    end
                    ent:SetSubMaterial(slot, zoomHiddenMaterial)
                end
            end
        else
            RestoreZoomEyes(ent, state)
        end
    end)
    for ent, state in pairs(zoomTargets) do
        if not seen[ent] then
            RestoreZoomEyes(ent, state)
            if IsValid(ent) then ent.ChudZoomEyeAmount = nil end
            zoomTargets[ent] = nil
        end
    end
end)
hook.Add("ShutDown", "ChudZoomEyeMaterials", function()
    for ent, state in pairs(zoomTargets) do RestoreZoomEyes(ent, state) end
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
                        local pos, ang = LocalToWorld(cfg.bulge.offset + Vector(-2 + 4 * zoomSlide, 0, 0), cfg.bulge.angle, att.Pos, att.Ang)
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
