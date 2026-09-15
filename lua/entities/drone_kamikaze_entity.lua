AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Spawnable		= false

ENT.nextshoot = 0
ENT.armor = 200 -- Current armor
ENT.defArmor = nil -- Default armor
ENT.Enabled = true -- Is drone driveable
ENT.wait = 0
ENT.AllowControl = false -- For hacking
ENT.PropellersPitch = 95
ENT.SoundVolume = 1000

if CLIENT then
	function ENT:SetElements(tab)
		tab = tab or {
			["m"] = { type = "Model", model = "models/props_combine/combine_mine01.mdl", bone = "", rel = "", pos = Vector(0, 0, 0), angle = Angle(0, 0, 0), size = Vector(1, 1, 1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },
			["mine"] = { type = "Model", model = "models/props_combine/combine_mine01.mdl", bone = "", rel = "", pos = Vector(0, 0, 1), angle = Angle(180, 10, 0), size = Vector(1, 1, 1.5), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },
			
			["m2"] = { type = "Model", model = "models/props_combine/combinecamera001.mdl", bone = "", rel = "", pos = Vector(30, -30, -6), angle = Angle(40, 45, 0), size = Vector(1.5, 1.5, 1.5), color = Color(0, 0, 0, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },
			["m3"] = { type = "Model", model = "models/props_combine/combinecamera001.mdl", bone = "", rel = "", pos = Vector(30, -30, -6), angle = Angle(40, -45, 0), size = Vector(1.5, 1.5, 1.5), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },
			["m4"] = { type = "Model", model = "models/props_combine/combinecamera001.mdl", bone = "", rel = "", pos = Vector(-30, -30, -6), angle = Angle(40, 140, 0), size = Vector(1.5, 1.5, 1.5), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },
			["m5"] = { type = "Model", model = "models/props_combine/combinecamera001.mdl", bone = "", rel = "", pos = Vector(-30, -30, -6), angle = Angle(40, 225, 0), size = Vector(1.5, 1.5, 1.5), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },

			["m6"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(40, -40, 7), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },
			["m7"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(40, 40, 7), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },
			["m8"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(-40, -40, 7), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },
			["m9"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(-40, 40, 7), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },

			["m10"] = { type = "Model", model = "models/hunter/tubes/tube2x2x025.mdl", bone = "", rel = "", pos = Vector(30, -30, 6), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.5), color = Color(155, 155, 155, 255), surpresslightning = false, material = "phoenix_storms/metalset_1-2", skin = 0, bodygroup = {} },
			["m11"] = { type = "Model", model = "models/hunter/tubes/tube2x2x025.mdl", bone = "", rel = "", pos = Vector(30, 30, 6), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.5), color = Color(155, 155, 155, 255), surpresslightning = false, material = "phoenix_storms/metalset_1-2", skin = 0, bodygroup = {} },
			["m12"] = { type = "Model", model = "models/hunter/tubes/tube2x2x025.mdl", bone = "", rel = "", pos = Vector(-30, -30, 6), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.5), color = Color(155, 155, 155, 255), surpresslightning = false, material = "phoenix_storms/metalset_1-2", skin = 0, bodygroup = {} },
			["m13"] = { type = "Model", model = "models/hunter/tubes/tube2x2x025.mdl", bone = "", rel = "", pos = Vector(-30, 30, 6), angle = Angle(0, 0, 0), size = Vector(0.5, 0.5, 0.5), color = Color(155, 155, 155, 255), surpresslightning = false, material = "phoenix_storms/metalset_1-2", skin = 0, bodygroup = {} }
		}

		self.WElements = table.FullCopy(tab)
		self:CreateModels(self.WElements)
	end
else
	-- If true drone goes disabled
	function ENT:Switch(n)
		self.Enabled = n
		self:SetNWBool("disabled", not n)
	end

	-- Changes armor of our drone
	function ENT:SetArm(n)
		self.armor = n

		umsg.Start("upd_health_drone")
			umsg.Entity(self)
			umsg.String(tostring(self.armor))
		umsg.End()
	end
end

-- Gets drone's individual ID
-- IDs are based on first char after '_' symbol in ent class
-- And drone's EntIndex
function ENT:GetUnit()
	return "UNIT " .. string.upper(string.sub(self:GetClass(), 7, 7)) .. "-" .. self:EntIndex()
end

-- Gets drone's driver
function ENT:GetDriver() 
	return self:GetNWEntity("user") 
end

function ENT:OnRemove()
    self.FCRemoving = true
    local owner = self.FCDisposableOwner
    if IsValid(owner) and owner.OwnedDrone == self then
        owner.OwnedDrone = nil
    end
    if SERVER and IsValid(self:GetDriver()) then
        self:SetDriver(NULL)
    end
    if self.Sound then self.Sound:Stop() self.Sound = nil end
    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 32

	local ent = ents.Create(ClassName)
	ent:SetPos(SpawnPos)
	ent:Spawn()
	ent:Activate()
	ent.Owner = ply

	return ent
end

-- Main function
-- As you can see this function changes drone's driver
function ENT:SetDriver(ply)
    if CLIENT then return false end

    ply = IsValid(ply) and ply or NULL
    local user = self:GetDriver()

    if IsValid(ply) then
        if CurTime() < (self.wait or 0) then return false end
        if IsValid(user) or not ply:Alive() then return false end
        if IsValid(self.FCDisposableOwner) and self.FCDisposableOwner ~= ply then return false end

        self.wait = CurTime() + 0.3

        local activeWeapon = ply:GetActiveWeapon()
        ply.FCDroneState = {
            pos = ply:GetPos(),
            ang = ply:EyeAngles(),
            solid = ply:GetSolid(),
            moveType = ply:GetMoveType(),
            noDraw = ply:GetNoDraw(),
            viewEntity = ply:GetViewEntity(),
            weapon = IsValid(activeWeapon) and activeWeapon:GetClass() or nil
        }

        self.EntryPos = ply.FCDroneState.pos
        self.FCCameraAim = Angle(0, self:GetAngles().y, 0)
        self:SetNWEntity("user", ply)
        ply:SetNWEntity("kamikaze_", self)
        ply:SetViewEntity(self)
        ply:Flashlight(false)
        ply:SetMoveType(MOVETYPE_NONE)
        ply:SetVelocity(-ply:GetVelocity())

        return true
    end

    if not IsValid(user) then
        self:SetNWEntity("user", NULL)
        return false
    end

    self.wait = CurTime() + 0.3
    local state = user.FCDroneState or {}
    local exitPos = state.pos or self.EntryPos or user:GetPos()

    local tr = util.TraceHull({
        start = exitPos + Vector(0, 0, 8),
        endpos = exitPos + Vector(0, 0, 8),
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        filter = {self, user},
        mask = MASK_PLAYERSOLID
    })

    if tr.StartSolid then
        exitPos = self.EntryPos or exitPos
    end

    self:SetNWEntity("user", NULL)
    user:SetNWEntity("kamikaze_", NULL)
    local oldViewEntity = IsValid(state.viewEntity) and state.viewEntity or user
    user:SetViewEntity(oldViewEntity)
    user:SetParent(NULL)
    user:SetPos(exitPos)
    user:SetEyeAngles(state.ang or Angle(0, self:GetAngles().y, 0))
    user:SetVelocity(-user:GetVelocity())
    user:SetSolid(state.solid or SOLID_BBOX)
    user:SetMoveType(state.moveType or MOVETYPE_WALK)
    user:SetNoDraw(state.noDraw or false)

    if state.weapon and user:HasWeapon(state.weapon) then
        user:SelectWeapon(state.weapon)
    end
    self.EntryPos = nil
    self.FCCameraAim = nil
    user.FCDroneState = nil

    return true
end

function ENT:_Initialize(mdl, mass)
	mdl = mdl or "models/props_phx/construct/metal_plate2x2.mdl"
	mass = mass or 200

	self:DrawShadow(false)
	self:SetModel(mdl)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then phys:SetMass(mass) end

	if not self.Sound then
		self.Sound = CreateSound(self, "npc/manhack/mh_engine_loop1.wav")
		self.Sound:Play()
		self.Sound:ChangeVolume(self.SoundVolume)
	end
	
	self:StartMotionController()

	if not self.defArmor then self.defArmor = self.armor end
end

function ENT:Initialize()
	if CLIENT then
		self:SetElements()
		return
	end

	self:_Initialize()

	--Spawning gun
	self.gun = ents.Create("minigun_dent")
	if IsValid(self.gun) then
		self.gun:SetPos(self:GetPos() + self:GetForward() * 10 + self:GetUp() * -10 + self:GetRight() * 10)
		self.gun:SetAngles(self:GetAngles())
		self.gun:SetModelScale(0.9, 0)
		self.gun:Spawn()
		self.gun:SetParent(self)
	end
end

function ENT:OnTakeDamage(dmg)
	if CLIENT then return end

	self:TakePhysicsDamage(dmg)

	-- Maximum armor (Im too lazy to make another variable with a constant value)
	if not self.defArmor then self.defArmor = self.armor end
	if self.armor <= 0 then return end

	self:SetArm(self.armor - dmg:GetDamage())

	if self.armor <= self.defArmor / 2 and not self.DANGER then
		local ef = EffectData()
		ef:SetOrigin(self:GetPos())
		util.Effect("drone_fexplosion", ef)

		self.DANGER = true
	end

	if self.armor <= self.defArmor / 3 and not self.PLAYED_siren then
	
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:AddAngleVelocity(VectorRand() * 100)
		end

		self.PLAYED_siren = true
	end

	--Destroying drone if no health
	if self.armor <= 0 then 
		if self:GetDriver():IsValid() then self:SetDriver(NULL) end
		
		if self.Sound then self.Sound:Stop() self.Sound = nil end

		for i = 1, 5 do
			timer.Simple(math.Rand(0.1, 3), function()
				if not self or not IsValid(self) then return end
				
				local ef = EffectData()
				ef:SetOrigin(self:GetPos())
				util.Effect("Explosion", ef)

				self:Ignite(15)
			end)

			local phys = self:GetPhysicsObject()
			if phys:IsValid() then
				phys:AddAngleVelocity(VectorRand() * 200)

				local vec = VectorRand()
				vec.z = 0

				phys:AddVelocity(vec * 150 + vector_up * 150)
			end
		end

		self:Switch(false) 
		
		timer.Simple(35, function()
			if IsValid(self) then
				SafeRemoveEntity(self)
			end
		end)
	end
end

-- Функция Draw (исправленная)
function ENT:Draw()
	if SERVER then return end
	if self:GetDriver() == LocalPlayer() then return end

	-- Рисуем модель ВСЕГДА
	self:DrawModel()

	--SWEP Construction Kit changed draw code
	if !self.WElements then return end
		
	if !self.wRenderOrder then
		self.wRenderOrder = {}

		for k, v in pairs(self.WElements) do
			table.insert(self.wRenderOrder, 1, k)
		end
	end
		
	for k, name in pairs(self.wRenderOrder) do
		if self:GetDriver():IsValid() and self:GetDriver():SteamID() == LocalPlayer():SteamID() and name == "mine" then continue end

		local v = self.WElements[name]
		if !v then self.wRenderOrder = nil break end
			
		local pos, ang

		pos = self:GetPos()
		ang = self:GetAngles()
			
		local model = v.modelEnt
		local sprite = v.spriteMaterial
			
		model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
		ang:RotateAroundAxis(ang:Up(), v.angle.y)
		ang:RotateAroundAxis(ang:Right(), v.angle.p)
		ang:RotateAroundAxis(ang:Forward(), v.angle.r)
		model:SetAngles(ang)

		local matrix = Matrix()
		matrix:Scale(v.size)
		model:EnableMatrix( "RenderMultiply", matrix )
		model:SetMaterial(v.material)
				
		render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
		render.SetBlend(v.color.a/255)
		model:DrawModel()
		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)
	end
end

function ENT:PhysicsCollide(data, phys)
	if CLIENT then return end
	if not self.Enabled then return end
	if data.DeltaTime < 0.3 then return end

	local speed = data.Speed
	local user = self:GetDriver()

	if speed >= 700 then
		self:TriggerDroneExplosion(user)
		return
	end

	if speed > 420 then
		self:TakeDamage(math.Round(math.Clamp(speed / 70, 5, 15)))

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetVelocity(VectorRand() * 200)
			phys:AddAngleVelocity(VectorRand() * 200)
		end
	end
end

function ENT:Use(activator, caller)
    if CLIENT then return end
    if not self.Enabled then return end
    if not activator:IsPlayer() then return end
    if IsValid(self.FCDisposableOwner) and self.FCDisposableOwner ~= activator then return end
    self:SetDriver(activator)
end

function ENT:_Think()
	if CLIENT then
		if self:GetNWBool("nightvision") and LocalPlayer():GetNWEntity("kamikaze_") == self then
			local dlight = DynamicLight(self:EntIndex())
			if dlight then
				dlight.pos = self:GetPos()
				dlight.r = 255
				dlight.g = 255
				dlight.b = 255
				dlight.brightness = 1
				dlight.Decay = 1000
				dlight.Size = 1500
				dlight.DieTime = CurTime() + 0.2
			end
		end
	end

	local user = self:GetDriver()
	if user:IsValid() and not user:Alive() then self:SetDriver(NULL) end

	if not self.Enabled then
		local ef = EffectData()
		ef:SetOrigin(self:GetPos())
		ef:SetAngles(self:GetAngles())
		util.Effect("drone_sparks", ef)
	end

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then phys:Wake() end

	local vel = math.Round(self:GetVelocity():Length())
	if self.Sound then
		self.Sound:ChangePitch(math.Clamp(vel * 0.255, self.PropellersPitch, 255))
	end
end

function ENT:Think()
	self:_Think()

	if CLIENT then
		-- Вращение пропеллеров
		if self.WElements then
			local rotSpeed = CurTime() * 1500
			if self.WElements["m6"] then self.WElements["m6"].angle = Angle(0, rotSpeed, 0) end
			if self.WElements["m7"] then self.WElements["m7"].angle = Angle(0, rotSpeed, 0) end
			if self.WElements["m8"] then self.WElements["m8"].angle = Angle(0, rotSpeed, 0) end
			if self.WElements["m9"] then self.WElements["m9"].angle = Angle(0, rotSpeed, 0) end
		end
		return 
	end
	
	-- Minigun
	local user = self:GetDriver()
	if self.gun and self.gun:IsValid() then 
		self.gun:Switch(user:IsValid() and user:KeyDown(IN_ATTACK)) 
	end
	
	if user:IsValid() then
		
		local weapon = user:GetActiveWeapon()
		
		if weapon:IsValid() then
			weapon:SetNextPrimaryFire(CurTime() + 2)
			weapon:SetNextSecondaryFire(CurTime() + 2)
		end

		if user:KeyDown(IN_ATTACK) and CurTime() > self.nextshoot then
			if self.gun and self.gun:IsValid() then
				local bullet = {}
				bullet.Num = 1
				bullet.Src = self.gun:GetPos() + self.gun:GetForward() * 20
				bullet.Dir = self.gun:GetForward()
				bullet.Spread = Vector(0.02, 0.02, 0.02)
				bullet.Tracer = 2	
				bullet.Force = 50
				bullet.Damage = 10
				bullet.Attacker = self.Owner
			 
				user:EmitSound("weapons/pistol/pistol_fire2.wav", 100, math.random(200, 250))
				self.gun:FireBullets(bullet)
				self.nextshoot = CurTime() + 0.03
			end
		end

		if self.gun and self.gun:IsValid() then
			local aim = self.FCCameraAim or user:EyeAngles()
			self.gun:SetAngles(aim)
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:PhysicsSimulate(phys, delta)
	if CLIENT then return end
	if not self.Enabled then return SIM_NOTHING end

	local ang = phys:GetAngles()
	local avel = phys:GetAngleVelocity()
	local vel = phys:GetVelocity()
	local angf = Vector(0, 0, 0)
	local angp = math.NormalizeAngle(ang.p)
	local angr = math.NormalizeAngle(ang.r)
	local user = self:GetDriver()
	local gravity = physenv.GetGravity and physenv.GetGravity() or Vector(0, 0, -600)
	local vecf = gravity * -1

	if user:IsValid() then
		local sourceAim = self.FCCameraAim or Angle(0, self:GetAngles().y, 0)
		local aim = Angle(
			math.Clamp(math.NormalizeAngle(sourceAim.p), -85, 85),
			math.NormalizeAngle(sourceAim.y),
			0
		)
		local forward = aim:Forward()
		local right = aim:Right()
		local moveDir = Vector(0, 0, 0)

		if user:KeyDown(IN_FORWARD) then moveDir = moveDir + forward end
		if user:KeyDown(IN_BACK) then moveDir = moveDir - forward end
		if user:KeyDown(IN_MOVELEFT) then moveDir = moveDir - right end
		if user:KeyDown(IN_MOVERIGHT) then moveDir = moveDir + right end
		if user:KeyDown(IN_JUMP) or user:KeyDown(IN_ATTACK) then moveDir = moveDir + vector_up end
		if user:KeyDown(IN_DUCK) or user:KeyDown(IN_ATTACK2) then moveDir = moveDir - vector_up end

		if moveDir:LengthSqr() > 1 then
			moveDir:Normalize()
		end

		local maxSpeed = user:KeyDown(IN_SPEED) and 1450 or 760
		local targetVelocity = moveDir * maxSpeed
		local response = moveDir:LengthSqr() > 0 and 8.5 or 6.5
		vecf = vecf + (targetVelocity - vel) * response

		local yawError = math.AngleDifference(aim.y, ang.y)
		angf.z = angf.z + yawError * 12
	end

	angf.x = angf.x - angr * 7
	angf.y = angf.y - angp * 7
	angf = angf - avel * delta * 90

	return angf, vecf, SIM_GLOBAL_ACCELERATION
end
function ENT:EMPaffect()
	if self:GetDriver():IsValid() then self:SetDriver(NULL) end
	
	self:EmitSound("npc/manhack/bat_away.wav", 400, 85)
	self:EmitSound("npc/manhack/grind_flesh2.wav", 400, 100)
	
	if self.Sound then self.Sound:Stop() self.Sound = nil end

	self:Switch(false)
end

if CLIENT then
	ENT.wRenderOrder = nil

	function ENT:CreateModels(tab)
		if !tab then return end

		for k, v in pairs(tab) do
			if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and 
					string.find(v.model, ".mdl") and file.Exists (v.model, "GAME")) then
				
				v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_OPAQUE)
				if IsValid(v.modelEnt) then
					v.modelEnt:SetPos(self:GetPos())
					v.modelEnt:SetAngles(self:GetAngles())
					v.modelEnt:SetParent(self)
					v.modelEnt:SetNoDraw(true)
					v.createdModel = v.model
				else
					v.modelEnt = nil
				end
			end
		end
	end

	function table.FullCopy(tab)
		if !tab then return nil end
		
		local res = {}
		for k, v in pairs(tab) do
			if type(v) == "table" then
				res[k] = table.FullCopy(v)
			elseif type(v) == "Vector" then
				res[k] = Vector(v.x, v.y, v.z)
			elseif type(v) == "Angle" then
				res[k] = Angle(v.p, v.y, v.r)
			else
				res[k] = v
			end
		end
		
		return res
	end
end