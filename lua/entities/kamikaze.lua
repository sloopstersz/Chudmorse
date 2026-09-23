AddCSLuaFile()

DEFINE_BASECLASS( "hb_base_advanced" )
game.AddParticles( "particles/kamik_bomb.pcf")
ENT.Base = "drone_kamikaze_entity"
ENT.PrintName		= "FPV infantry"
ENT.Category        = "[FPV Drones]Kamikaze"
ENT.Spawnable		= false

ENT.armor = 50
ENT.forward = 50
ENT.up = 0
ENT.cam_up = -6.3
ENT.Target = NULL
ENT.PropellersPitch = 170
ENT.SoundVolume = 5
ENT.ExplosionSound          =    "kamikaze/kamikbomb.wav"
ENT.Shocktime                        =  0
ENT.HBOWNER                          =  nil     

ENT.FLIGHT_TIME = 180 
ENT.BATTERY_VOLT_MAX = 16.8 
ENT.BATTERY_VOLT_MIN = 13.2 

ENT.CrashVelocityThreshold = 400  
ENT.DamageVelocityThreshold = 250  
ENT.LastCrashTime = 0
ENT.CrashCooldown = 1.0  

ENT.EngineSoundPath = "kamikaze/fpv_idlesound.ogg"  
ENT.EngineSoundLevel = 90  
ENT.EngineSoundLevelExternal = 75  

function ENT:Initialize()
	if CLIENT then
		self:SetElements({
			["m+++"] = { type = "Model", model = "models/kamik/ardrone.mdl", bone = "", rel = "", pos = Vector(-1.1, 0.2, 0), angle = Angle(0, 4, 0), size = Vector(0.8, 0.8, 0.8), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} },
			["m6"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(3.3, -4.8, 3.2), angle = Angle(0, 0, 0), size = Vector(0.1, 0.1, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },
			["m7"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(4, 4.5, 3.2), angle = Angle(0, 0, 0), size = Vector(0.1, 0.1, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },
			["m8"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(-6.1, -4.1, 3.2), angle = Angle(0, 0, 0), size = Vector(0.1, 0.1, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} },
			["m9"] = { type = "Model", model = "models/hunter/plates/plate1x1.mdl", bone = "", rel = "", pos = Vector(-5.4, 5.2, 3.2), angle = Angle(0, 0, 0), size = Vector(0.1, 0.1, 0.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "models/airboat/airboat_blur02", skin = 0, bodygroup = {} }
		})
		return
	end

	self:_Initialize("models/kamik/ardrone.mdl", 30)
	
	self:SetNWFloat("Kamikaze_BatteryPct", 1.0)
	self:SetNWFloat("Kamikaze_mAh", 0)
	self:SetNWBool("Kamikaze_DeadBattery", false)
	self.InternalBattery = 1.0
	self.NextBatterySync = CurTime() + 1.0
	self.BatteryLastThink = CurTime()
	
	self:SetNWInt("Kamikaze_Interference", 0)
	self.NextInterfCheck = CurTime() + 2.0
	self.SpawnTime = CurTime()
	
	self:SetNWBool("Kamikaze_Flashlight", false)
	
	if not self.Sound then
		self.Sound = CreateSound(self, self.EngineSoundPath)
		self.Sound:SetSoundLevel(self.EngineSoundLevel)
	end
end

function ENT:GetBatteryVoltage()
	local pct = self.InternalBattery or 1.0
	return self.BATTERY_VOLT_MIN + (self.BATTERY_VOLT_MAX - self.BATTERY_VOLT_MIN) * pct
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

-- ============================================================
-- Freak-City: IED-style explosion for FPV drone
-- Основано на взрыве weapon_traitor_ied.
-- ============================================================
ENT.IEDBlastDis = 12
ENT.IEDBlastDamage = 350
ENT.IEDSoundFar = {
    "iedins/ied_detonate_dist_01.wav",
    "ied/ied_detonate_dist_02.wav",
    "ied/ied_detonate_dist_03.wav"
}
ENT.IEDSound = {
    "ied/ied_detonate_01.wav",
    "ied/ied_detonate_02.wav",
    "ied/ied_detonate_03.wav"
}
ENT.IEDSoundWater = "iedins/water/ied_water_detonate_01.wav"

local function FCDroneApplyIEDDisorientation(source, pos, blastDis)
    if not hg then return end

    local dis = blastDis / 0.01905
    local disorientationDis = 10 / 0.01905

    for _, enta in ipairs(ents.FindInSphere(pos, disorientationDis)) do
        local tracePos = enta:IsPlayer() and (enta:GetPos() + enta:OBBCenter()) or enta:GetPos()
        local tr

        if hg.ExplosionTrace then
            tr = hg.ExplosionTrace(pos, tracePos, {source})
        else
            tr = util.TraceLine({
                start = pos,
                endpos = tracePos,
                filter = {source},
                mask = MASK_SHOT
            })
        end

        local phys = enta:GetPhysicsObject()
        local force = enta:GetPos() - pos
        local len = math.max(force:Length(), 1)
        force:Div(len)

        local frac = math.Clamp((disorientationDis - len) / disorientationDis, 0.1, 1)
        local physicsFrac = math.Clamp((dis - len) / dis, 0.5, 1)
        local forceAdd = force * physicsFrac * 50000

        if enta.organism then
            local behindWall = IsValid(tr.Entity) and tr.Entity ~= enta and tr.MatType ~= MAT_GLASS

            if IsValid(enta.organism.owner) and enta.organism.owner:IsPlayer() and not behindWall then
                if hg.ExplosionDisorientation then
                    hg.ExplosionDisorientation(enta, 5 * frac * 1.5, 6 * frac * 1.5)
                elseif enta.organism.owner.AddTinnitus then
                    enta.organism.owner:AddTinnitus(5 * frac * 1.5)
                end

                if hg.RunZManipAnim then
                    hg.RunZManipAnim(enta.organism.owner, "shieldexplosion")
                end
            end
        end

        if len > dis then continue end

        if IsValid(tr.Entity) and tr.Entity ~= enta then
            if IsValid(phys) then
                phys:ApplyForceCenter((forceAdd / 20) + vector_up * math.random(500, 550))
            end
            continue
        end

        if enta:IsPlayer() and hg then
            if hg.AddForceRag then
                hg.AddForceRag(enta, 0, forceAdd * 0.5, 0.5)
                hg.AddForceRag(enta, 1, forceAdd * 0.5, 0.5)
            end

            if hg.LightStunPlayer then
                hg.LightStunPlayer(enta)
            end
        end

        if IsValid(phys) then
            phys:ApplyForceCenter(forceAdd)
        end
    end
end

local function FCDroneSpawnIEDShrapnel(source, pos, attacker)
    if not IsValid(source) then return end

    -- Match the regular grenade: its base entity uses 300 * 3 fragments,
    -- 40 damage, and only fires a fragment when its trace can hit an entity.
    local fragmentCount = 300 * 3

    local co = coroutine.create(function()
        for i = 1, fragmentCount do
            if not IsValid(source) then return end

            local dir = VectorRand():GetNormalized()
            dir.z = dir.z > 0 and math.abs(dir.z - 0.5) or -math.abs(dir.z + 0.5)
            dir:Normalize()

            local tr = util.QuickTrace(pos, dir * 10000, source)
            if not tr.Hit or tr.HitSky or tr.HitWorld then
                if i % 35 == 0 then
                    coroutine.yield()
                end
                continue
            end

            local bullet = {
                Dir = dir,
                Src = pos,
                Force = 0.01,
                Damage = 40,
                AmmoType = "Metal Debris",
                Attacker = IsValid(attacker) and attacker or source,
                Distance = 205,
                DisableLagComp = true,
                Filter = {source},
                Penetration = 4,
                Num = 1,
                Tracer = 0,
                Spread = vector_origin
            }

            if source.FireLuaBullets then
                source:FireLuaBullets(bullet, true)
            else
                source:FireBullets(bullet)
            end

            -- Не пытаемся выпустить сотни осколков в один тик.
            if i % 35 == 0 then
                coroutine.yield()
            end
        end
    end)

    local timerName = "FCDroneIEDShrapnel_" .. source:EntIndex() .. "_" .. math.floor(CurTime() * 1000)

    timer.Create(timerName, 0, 0, function()
        if coroutine.status(co) == "dead" then
            timer.Remove(timerName)
            return
        end

        local ok = coroutine.resume(co)
        if not ok or coroutine.status(co) == "dead" then
            timer.Remove(timerName)
        end
    end)
end

function ENT:TriggerDroneExplosion(user)
    if CLIENT or self.FCExploded then return end
    self.FCExploded = true

    local attacker = user
    if not IsValid(attacker) then
        attacker = IsValid(self.FCDisposableOwner) and self.FCDisposableOwner
            or (IsValid(self.HBOWNER) and self.HBOWNER)
            or (IsValid(self.Owner) and self.Owner)
            or self
    end

    if IsValid(user) and user:IsPlayer() and GiveExplosionImmunity then
        GiveExplosionImmunity(user, 2.5)
    end

    -- Сразу отключаем управление, чтобы после нажатия R игрок вернулся в тело.
    local driver = self:GetDriver()
    if IsValid(driver) and self.SetDriver then
        self:SetDriver(NULL)
    end

    if self.Switch then
        self:Switch(false)
    else
        self.Enabled = false
    end

    self:SetNWBool("Kamikaze_Flashlight", false)

    if self.Sound then
        self.Sound:Stop()
        self.Sound = nil
    end

    -- Как у IED: короткий сигнал перед подрывом.
    timer.Simple(0.4, function()
        if not IsValid(self) then return end

        local entPos = self:GetPos() + self:OBBCenter()
        local blastDis = self.IEDBlastDis or 12
        local blastDamage = self.IEDBlastDamage or 350

        -- Звук взрыва.
        local mainSound = table.Random(self.IEDSound or {})
        if mainSound then
            sound.Play(mainSound, entPos, 120, math.random(95, 105), 1)
        end

        -- Вода / земля — тот же визуальный принцип, что у IED.
        if self:WaterLevel() == 0 then
            ParticleEffect("pcf_jack_groundsplode_medium", self:GetPos(), -vector_up:Angle())
        else
            local effectdata = EffectData()
            effectdata:SetOrigin(self:GetPos())
            effectdata:SetScale(3)
            effectdata:SetNormal(-self:GetAngles():Forward())
            util.Effect("eff_jack_genericboom", effectdata, true, true)

            local waterSound = self.IEDSoundWater
            if waterSound then
                sound.Play(waterSound, entPos, 120, 100, 1)
            end
        end

        if hg and hg.ExplosionEffect then
            hg.ExplosionEffect(entPos, blastDis / 0.2, 80)
        end

        -- Центральный blast — значения взяты с IED.
        util.BlastDamage(
            self,
            IsValid(attacker) and attacker or self,
            entPos,
            blastDis / 0.01905,
            blastDamage * 0.1
        )

        FCDroneApplyIEDDisorientation(self, entPos, blastDis)

        if hgBlastDoors then
            hgBlastDoors(self, entPos, blastDamage / 400, blastDis / 8, false)
        end

        util.ScreenShake(entPos, 45, 225, 2.5, 3000)

        -- Металлический FPV-дрон разбрасывает осколки как металлический объект с IED.
        local poof = EffectData()
        poof:SetOrigin(entPos)
        poof:SetScale(1)
        util.Effect("eff_jack_hmcd_shrapnel", poof, true, true)

        -- Сразу прячем корпус, но оставляем entity жить ещё немного,
        -- чтобы coroutine успел выпустить все осколки.
        self:SetNoDraw(true)
        self:SetSolid(SOLID_NONE)
        self:SetMoveType(MOVETYPE_NONE)

        FCDroneSpawnIEDShrapnel(self, entPos, attacker)

        timer.Simple(0.65, function()
            if IsValid(self) then
                self:Remove()
            end
        end)
    end)
end

function ENT:TriggerWaterFailure()
	if CLIENT or self.FCWaterFailure or self.FCExploded then return end

	self.FCWaterFailure = true
	local user = self:GetDriver()

	if self.Switch then
		self:Switch(false)
	else
		self.Enabled = false
		self:SetNWBool("disabled", true)
	end

	self:SetNWBool("Kamikaze_DeadBattery", true)
	self:SetNWBool("Kamikaze_Flashlight", false)

	if self.Sound then
		self.Sound:Stop()
	end

	if IsValid(user) and self.SetDriver then
		self:SetDriver(NULL)
	end

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetVelocity(phys:GetVelocity() * 0.25)
	end


	local effect = EffectData()
	effect:SetOrigin(self:LocalToWorld(self:OBBCenter()))
	effect:SetNormal(vector_up)
	effect:SetMagnitude(3)
	effect:SetScale(2)
	effect:SetRadius(4)
	util.Effect("Sparks", effect, true, true)

	timer.Simple(0.3, function()
		if not IsValid(self) then return end
		self:TriggerDroneExplosion(user)
	end)
end

function ENT:ExitDriver()
    if SERVER and IsValid(self:GetDriver()) then
        self:SetDriver(NULL)
    end
end

function ENT:OnRemove()
    if SERVER and IsValid(self:GetDriver()) then
        self:SetDriver(NULL)
    end

    if self.Sound then
        self.Sound:Stop()
        self.Sound = nil
    end

    if IsValid(self.Particle) then
        self.Particle:Remove()
    end
end

function ENT:Think()
	if SERVER then
		if not self.FCWaterFailure and not self.FCExploded and self:WaterLevel() > 0 then
			self:TriggerWaterFailure()
		end

		if self.FCWaterFailure then
			self:NextThink(CurTime())
			return true
		end

		local ct = CurTime()
		local dt = ct - (self.BatteryLastThink or ct)
		self.BatteryLastThink = ct
		
		if self.Enabled and not self:GetNWBool("Kamikaze_DeadBattery") then
			self.InternalBattery = math.Clamp(self.InternalBattery - dt / self.FLIGHT_TIME, 0, 1)
			
			if ct > self.NextBatterySync then
				self.NextBatterySync = ct + 1.0
				self:SetNWFloat("Kamikaze_BatteryPct", self.InternalBattery)
				local totalVoltage = self:GetBatteryVoltage()
				self:SetNWFloat("Kamikaze_BatteryTotal", totalVoltage)
				self:SetNWFloat("Kamikaze_BatteryCell", totalVoltage / 4)
				
				local mAh = self:GetNWFloat("Kamikaze_mAh", 0)
				self:SetNWFloat("Kamikaze_mAh", mAh + 45 * dt)
			end
			
			if self.InternalBattery <= 0 then
				self:SetNWBool("Kamikaze_DeadBattery", true)
				self.Enabled = false
				if self.Sound then self.Sound:Stop() end
			end
		end
		
		if ct > (self.SpawnTime or 0) + 5 and ct > self.NextInterfCheck then
			self.NextInterfCheck = ct + 0.5
			local pos = self:GetPos()
			local interference = 0
			
			local tr = util.TraceLine({
				start = pos,
				endpos = pos + Vector(0, 0, -300),
				filter = self
			})
			
			if tr.HitWorld then
				local dist_to_ground = pos:Distance(tr.HitPos)
				if dist_to_ground < 500 then
					interference = (1 - dist_to_ground / 500) * 40
				end
			end
			
			local nearby = ents.FindInSphere(pos, 400)
			for j = 1, #nearby do
				local target = nearby[j]
				if target == self then continue end
				
				local is_interfering = false
				
				if target:IsPlayer() then
					if not target:InVehicle() then
						is_interfering = true
					end
				elseif target:IsNPC() then
					is_interfering = true
				elseif target:IsVehicle() then
					is_interfering = true
				elseif target:GetClass():find("prop_physics") then
					local phys = target:GetPhysicsObject()
					if IsValid(phys) and phys:GetMass() > 100 then
						is_interfering = true
					end
				end
				
				if is_interfering then
					local dist = pos:Distance(target:GetPos())
					if dist < 400 then
						interference = interference + 30 * (1 - dist / 400)
					end
				end
			end
			
			interference = math.Clamp(interference, 0, 100)
			self:SetNWInt("Kamikaze_Interference", interference)
			
		elseif ct <= (self.SpawnTime or 0) + 5 then
			self:SetNWInt("Kamikaze_Interference", 0)
		end
		
		if self.Enabled and not self:GetNWBool("Kamikaze_DeadBattery") then
			if self.Sound and not self.Sound:IsPlaying() then
				self.Sound:Play()
			end
			
			if self.Sound then
				local throttle = self.Throttle or 0
				local vel = self:GetVelocity():Length()
				local pitch = math.Clamp(90 + (throttle * 30) + (vel / 20), 70, 130)
				self.Sound:ChangePitch(pitch, 0.1)
			end
		else
			if self.Sound and self.Sound:IsPlaying() then
				self.Sound:Stop()
			end
		end
		
		if self.Enabled then
			local phys = self:GetPhysicsObject()
			if phys:IsValid() and phys:IsAsleep() then
				phys:Wake()
				phys:ApplyForceCenter(Vector(0, 0, 10))
			end
		end
	end

	self:_Think()

	if CLIENT then
		if self.WElements then
			self.WElements["m6"].angle = Angle(0, CurTime() * 1500, 0)
			self.WElements["m7"].angle = Angle(0, CurTime() * 1500, 0)
			self.WElements["m8"].angle = Angle(0, CurTime() * 1500, 0)
			self.WElements["m9"].angle = Angle(0, CurTime() * 1500, 0)
		end
		return 
	end
	
	local user = self:GetDriver()
	if user:IsValid() then
		-- 🛠️ ФИКС: Заморозка тела игрока
		if user:GetMoveType() ~= MOVETYPE_NONE then
			user:SetMoveType(MOVETYPE_NONE)
		end
		
		local weapon = user:GetActiveWeapon()
		if weapon:IsValid() then
			weapon:SetNextPrimaryFire(CurTime() + 2)
			weapon:SetNextSecondaryFire(CurTime() + 2)
		end

		if user:KeyDown(IN_RELOAD) then
			self:TriggerDroneExplosion(user)
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:PhysicsCollide(data, phys)
	if CLIENT then return end
	if not self.Enabled then return end
	
	local ct = CurTime()
	if ct - self.LastCrashTime < self.CrashCooldown then return end
	if data.DeltaTime < 0.2 then return end

	local speed = data.Speed
	local user = self:GetDriver()
	
	local shouldExplode = false
	
	if speed >= self.CrashVelocityThreshold then
		shouldExplode = true
	end
	
	if not shouldExplode and speed > 300 then
		local hitNormal = data.HitNormal
		local dot = hitNormal:Dot(Vector(0, 0, 1))
		if math.abs(dot) < 0.3 then
			shouldExplode = true
		end
	end
	
	if not shouldExplode and speed > 250 and self.armor < 30 then
		shouldExplode = true
	end
	
	if shouldExplode then
		self.LastCrashTime = ct
		self:TriggerDroneExplosion(user)
		return
	end
	
	if speed > self.DamageVelocityThreshold then
		self.LastCrashTime = ct
		self:TakeDamage(math.Round(math.Clamp(speed / 30, 5, 25)))
		
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetVelocity(VectorRand() * 150)
			phys:AddAngleVelocity(VectorRand() * 200)
		end
		
		self:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 5) .. ".wav", 75, 100)
	end
end

function ENT:Draw()
	if SERVER then return end
	if self:GetDriver() == LocalPlayer() then return end

	if !self.WElements then return end

	if !self.wRenderOrder then
		self.wRenderOrder = {}
		for k, v in pairs(self.WElements) do
			table.insert(self.wRenderOrder, 1, k)
		end
	end

	for k, name in pairs(self.wRenderOrder) do
		if self:GetDriver():IsValid() and self:GetDriver():SteamID() == LocalPlayer():SteamID() and name == "mine" then
			continue
		end

		local v = self.WElements[name]
		if !v then
			self.wRenderOrder = nil
			break
		end

		if not IsValid(v.modelEnt) then
			if v.model and v.model ~= "" then
				v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_OPAQUE)
				if IsValid(v.modelEnt) then
					v.modelEnt:SetNoDraw(true)
					v.createdModel = v.model
				else
					continue
				end
			else
				continue
			end
		end

		local pos = self:GetPos()
		local ang = self:GetAngles()
		local model = v.modelEnt

		local newPos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
		local newAng = Angle(ang.p, ang.y, ang.r)
		newAng:RotateAroundAxis(newAng:Up(), v.angle.y)
		newAng:RotateAroundAxis(newAng:Right(), v.angle.p)
		newAng:RotateAroundAxis(newAng:Forward(), v.angle.r)

		model:SetPos(newPos)
		model:SetAngles(newAng)

		local matrix = Matrix()
		matrix:Scale(v.size)
		model:EnableMatrix("RenderMultiply", matrix)

		if v.material and v.material ~= "" then
			model:SetMaterial(v.material)
		end

		render.SetColorModulation(v.color.r / 255, v.color.g / 255, v.color.b / 255)
		render.SetBlend(v.color.a / 255)

		model:DrawModel()

		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)
	end
end

function ENT:CalcView(ply, pos, ang, fov)
    if self:GetDriver() == ply then
        local view = {}
        view.origin = self:GetPos() + self:GetForward() * -0.2 + self:GetUp() * 3.7
        view.angles = self:GetAngles()
        view.fov = 90
        view.drawviewer = false
        view.drawviewmodel = false
        view.znear = 1
        return view
    end
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
		angf.z = angf.z + yawError * 14
	end

	angf.x = angf.x - angr * 7
	angf.y = angf.y - angp * 7
	angf = angf - avel * delta * 100

	return angf, vecf, SIM_GLOBAL_ACCELERATION
end
-- 🛠️ ФИКС: Добавляем глобальный хук для PVS, чтобы карта и пропы не пропадали
if SERVER then
	hook.Add("SetupPlayerVisibility", "FPVDrones_PVS_Fix", function(ply)
		local drone = ply:GetNWEntity("kamikaze_") 
		if IsValid(drone) then
			AddOriginToPVS(drone:GetPos())
		end
	end)
end
