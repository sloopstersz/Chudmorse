-- Short, non-emissive dust and paint/glass flecks. No sparks or dynamic lights.
local budgetFrame, remaining = -1, 0

function EFFECT:Init(data)
	if budgetFrame ~= FrameNumber() then budgetFrame, remaining = FrameNumber(), 64 end
	if remaining < 3 then return end
	local pos, direction = data:GetOrigin(), data:GetNormal()
	if EyePos():DistToSqr(pos) > 1600 * 1600 then return end
	if direction:LengthSqr() < 0.5 then direction = Vector(-1, 0, 0) end
	direction = direction:GetNormalized()
	local normal, rear, rearNormal = -direction, pos + direction * 1.5, direction
	local flags = data:GetFlags()
	if bit.band(flags, 4) ~= 0 and hg.GetShieldParticleSurfaces then
		local front, outward, back, inward = hg.GetShieldParticleSurfaces(data:GetEntity(), pos, direction, data:GetStart(), data:GetAngles())
		if front then pos, normal, rear, rearNormal = front, outward, back, inward end
	end
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	-- The shield is close to the holder's face. Do not let the default emitter
	-- near-fade hide all of its short-lived particles in first person.
	emitter:SetNearClip(0, 1)
	local glass = bit.band(flags, 2) ~= 0
	local penetrated = bit.band(flags, 1) ~= 0
	local power = math.Clamp(data:GetMagnitude(), 0.2, 1.1)
	local frontCount = 5 + math.ceil(power * 5)
	local count = math.min(remaining, frontCount + (penetrated and 5 or 3))
	remaining = remaining - count
	for i = 1, count do
		local inside = i > frontCount
		local index = inside and i - frontCount or i
		local dust = index <= (inside and 2 or 3)
		local origin = inside and rear or pos
		local outward = inside and rearNormal or normal
		-- A stopped bullet only shakes loose a little inner dust/paint. A real
		-- perforation has a stronger outward exit burst on that side.
		local force = inside and not penetrated and 0.3 or 1
		local material = dust and "particle/particle_smokegrenade"
			or (glass and "effects/fleck_glass" .. math.random(1, 3) or "effects/fleck_cement" .. math.random(1, 2))
		local particle = emitter:Add(material, origin + outward * 0.7)
		if particle then
			particle:SetVelocity((outward * math.Rand(25, 75) + VectorRand() * (dust and 12 or 45)) * power * force)
			particle:SetDieTime(dust and math.Rand(0.28, 0.42) or math.Rand(0.32, 0.6))
			particle:SetStartAlpha(dust and 105 or 230)
			particle:SetEndAlpha(0)
			particle:SetStartSize((dust and 2.4 or math.Rand(0.35, 0.85)) * (inside and not penetrated and 0.6 or 1))
			particle:SetEndSize(dust and (5 + power * 3) * (inside and not penetrated and 0.6 or 1) or 0.15)
			particle:SetColor(glass and 185 or 140, glass and 200 or 145, glass and 210 or 150)
			particle:SetGravity(Vector(0, 0, dust and -12 or -260))
			particle:SetAirResistance(dust and 110 or 20)
			particle:SetRoll(math.Rand(-math.pi, math.pi))
			particle:SetRollDelta(math.Rand(-4, 4))
			particle:SetLighting(true)
		end
	end
	emitter:Finish()
end

function EFFECT:Think() return false end
function EFFECT:Render() end
