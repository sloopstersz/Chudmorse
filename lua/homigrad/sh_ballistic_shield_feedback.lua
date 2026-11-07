-- Cosmetic impact response. Damage, armour and player aim are left to their owners.
if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("effects/hg_shield_impact.lua")
end

local shieldClass = "weapon_ballistic_shield"
local duration = 0.65

function hg.IsBallisticShieldTrace(trace)
	return trace and IsValid(trace.Entity) and isfunction(trace.Entity.GetClass) and trace.Entity:GetClass() == shieldClass
end

local function holder(shield)
	if not IsValid(shield) or shield:GetClass() ~= shieldClass then return end
	local owner = shield:GetOwner()
	if IsValid(owner) and owner:IsPlayer() and owner:Alive() then return owner end
end

if SERVER then
	function hg.BallisticShieldFeedback(trace)
		local shield = trace and trace.Entity
		if not IsValid(shield) or shield:GetClass() ~= shieldClass or not trace.HitPos or trace.ShieldFeedbackDone then return end
		trace.ShieldFeedbackDone = true
		local now = CurTime()
		-- Pellets and hundreds of grenade fragments share one response. Every
		-- projectile still takes the normal independent damage/penetration path.
		if (shield.nextShieldFeedback or 0) > now then return end
		shield.nextShieldFeedback = now + 0.075
		local ammo = isnumber(trace.ShieldAmmo) and game.GetAmmoName(trace.ShieldAmmo) or trace.ShieldAmmo
		local fragment = ammo == "Metal Debris" or ammo == "metal_debris"
		local melee = trace.ShieldAmmo == nil
		local penetrated = trace.ShieldBlocked == false
		local direction = trace.Normal or (trace.HitNormal and -trace.HitNormal) or Vector(1, 0, 0)
		local power = fragment and 0.22 or (melee and 0.65 or (penetrated and 0.9 or 0.58))
		if isstring(ammo) and string.lower(ammo) == "buckshot" then power = 0.5 end
		local point = vector_origin
		if trace.ShieldOrigin and trace.ShieldAngles then
			point = WorldToLocal(trace.HitPos, angle_zero, trace.ShieldOrigin, trace.ShieldAngles)
		end
		local glass = not melee and math.abs(point.y) < 9.67 and point.z > 14.46 and point.z < 18.81
		if glass then power = power * 0.75 end
		local owner = holder(shield)
		if owner then
			local previous = shield:GetNWFloat("ShieldHitAt", -100000)
			local residual = math.exp(-math.max(now - previous, 0) * 14) * shield:GetNWFloat("ShieldHitPower", 0) * 0.35
			shield:SetNWEntity("ShieldHitOwner", owner)
			shield:SetNWBool("ShieldHitGlass", glass)
			shield:SetNWBool("ShieldHitBullet", not melee and not fragment)
			shield:SetNWBool("ShieldHitPenetrated", penetrated)
			shield:SetNWVector("ShieldHitDirection", direction)
			shield:SetNWVector("ShieldHitTorque", Vector(0, math.Clamp(point.y / 14.3, -1, 1), math.Clamp(point.z / 24.6, -1, 1)))
			shield:SetNWFloat("ShieldHitPower", math.min(power + residual, 1.1))
			shield:SetNWFloat("ShieldHitAt", now)
			if power >= 0.5 and (shield.nextShieldGear or 0) <= now and shield:GetShieldCarryFraction() > 0 then
				shield.nextShieldGear = now + 0.3
				owner:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", 48, math.random(93, 101), 0.3)
			end
		end
		local fx = EffectData()
		fx:SetOrigin(trace.HitPos)
		fx:SetNormal(direction)
		fx:SetEntity(shield)
		if trace.ShieldOrigin and trace.ShieldAngles then
			fx:SetStart(trace.ShieldOrigin)
			fx:SetAngles(trace.ShieldAngles)
		end
		fx:SetMagnitude(power)
		fx:SetFlags((glass and 2 or 0) + (penetrated and 1 or 0) + (trace.ShieldOrigin and trace.ShieldAngles and 4 or 0))
		util.Effect("hg_shield_impact", fx, true, true)
		local path
		if glass then
			path = "physics/glass/glass_impact_bullet" .. math.random(1, 4) .. ".wav"
		else
			path = "physics/metal/metal_solid_impact_bullet" .. math.random(2, 4) .. ".wav"
		end
		sound.Play(path, trace.HitPos, fragment and 65 or (penetrated and 79 or 75),
			math.random(penetrated and 84 or 94, penetrated and 96 or 106), fragment and 0.55 or 0.9)
	end
end

-- Analytic time, no per-render integration: hands, remote models and the
-- protective plate sample the same impulse, even in scopes and mirrors.
function hg.GetShieldHitMotion(shield, eyeAng)
	local owner = holder(shield)
	if not owner then return vector_origin, angle_zero, vector_origin, angle_zero, 0 end
	local elapsed = CurTime() - shield:GetNWFloat("ShieldHitAt", -100000)
	if shield:GetNWEntity("ShieldHitOwner") ~= owner or elapsed < 0 or elapsed >= duration then
		return vector_origin, angle_zero, vector_origin, angle_zero, 0
	end
	eyeAng = eyeAng or owner:EyeAngles()
	local direction = shield:GetNWVector("ShieldHitDirection", vector_origin)
	local torque = shield:GetNWVector("ShieldHitTorque", vector_origin)
	local power = math.Clamp(shield:GetNWFloat("ShieldHitPower", 0), 0, 1.1)
	local envelope = (1 - math.exp(-elapsed * 80)) * math.exp(-elapsed * 9) * (1 - elapsed / duration) * power
	local push = envelope * math.cos(elapsed * 19)
	local ring = envelope * math.sin(elapsed * 85) * math.exp(-elapsed * 6)
	local front = math.Clamp(direction:Dot(eyeAng:Forward()), -1, 1)
	local side = math.Clamp(direction:Dot(eyeAng:Right()), -1, 1)
	local held = shield:InUse() and hg.GetCurrentCharacter(owner) == owner and shield:GetShieldCarryFraction() or 0
	local body = 0.35 + held * 0.65
	return Vector(front * push * 1.4, side * push * 0.55, -math.abs(push) * 0.12) * held,
		Angle((-front * 2 + torque.z) * push, (side * 2 + torque.y * 3) * push, torque.y * push * 2.5 + ring * 0.5) * held,
		Vector(front * push * 0.22, side * push * 0.1, -math.abs(push) * 0.04) * body,
		Angle(front * push * 0.85, side * push * 0.3, (side + torque.y * 0.5) * push * 0.6 + ring * 0.12) * body,
		envelope * body
end

function hg.ApplyShieldImpactPose(shield, pos, ang, eyeAng)
	local offset, rotation = hg.GetShieldHitMotion(shield, eyeAng)
	local world = LocalToWorld(offset, angle_zero, vector_origin, eyeAng)
	return pos + world, ang + rotation
end

if SERVER then return end

local function localResponse(ply)
	if not IsValid(ply) or ply ~= LocalPlayer() or not ply:Alive() or GetViewEntity() ~= ply then return end
	if ply.organism and ply.organism.otrub then return end
	local third = GetConVar("hg_thirdperson")
	if third and third:GetBool() then return end
	local shield = hg.GetPlayerBallisticShield and hg.GetPlayerBallisticShield(ply)
	if not shield then return end
	return shield
end

-- The Workshop shield samples are stereo: keep them local to the holder.
-- The mono impact above supplies attenuation and direction for everybody else.
local closeSounds = file.Exists("sound/homigrad/physics/shield/bullet_hit_shield_01.wav", "GAME")
local plateSound, heardShield, heardAt, soundAt, fading = nil, nil, -100000, -100000, false
hook.Add("Think", "hg_shield_hit_audio", function()
	local ply = LocalPlayer()
	local shield = localResponse(ply)
	if not closeSounds or not shield or shield:GetShieldCarryFraction() <= 0 then
		if plateSound then plateSound:Stop(); plateSound = nil end
		heardShield, heardAt = nil, -100000
		return
	end
	local at = shield:GetNWFloat("ShieldHitAt", -100000)
	local elapsed = CurTime() - at
	if (shield ~= heardShield or at ~= heardAt) and elapsed >= 0 and elapsed < 0.2 then
		heardShield, heardAt = shield, at
		if shield:GetNWEntity("ShieldHitOwner") == ply and shield:GetNWBool("ShieldHitBullet", false)
			and not shield:GetNWBool("ShieldHitGlass", false) and CurTime() - soundAt >= 0.12 then
			if plateSound then plateSound:Stop() end
			local variant = math.floor(at * 1000) % 7 + 1
			plateSound = CreateSound(ply, string.format("homigrad/physics/shield/bullet_hit_shield_%02d.wav", variant))
			if plateSound then
				plateSound:SetSoundLevel(0)
				plateSound:PlayEx(0.42, shield:GetNWBool("ShieldHitPenetrated", false) and 88 or 98)
			end
			soundAt, fading = CurTime(), false
		end
	end
	if plateSound and not fading and CurTime() - soundAt > 0.16 then
		plateSound:FadeOut(0.2)
		fading = true
	end
end)

hook.Add("PostHGCalcView", "hg_shield_hit_camera", function(ply, view)
	local shield = localResponse(ply)
	if not shield or not view.origin or not view.angles then return end
	local _, _, lean, turn, amount = hg.GetShieldHitMotion(shield, ply:EyeAngles())
	if amount <= 0 then return end
	lean, turn = lean * 2, turn * 2
	local desired = LocalToWorld(lean, angle_zero, view.origin, ply:EyeAngles())
	local trace = util.TraceHull({start = view.origin, endpos = desired, mins = Vector(-1, -1, -1), maxs = Vector(1, 1, 1),
		filter = {ply, hg.GetCurrentCharacter(ply)}, mask = MASK_SOLID})
	view.origin = trace.HitPos
	view.angles = Angle(view.angles.p, view.angles.y, view.angles.r) + turn
	if view.fov then view.fov = view.fov + amount * 0.35 end
end, HOOK_HIGH or -1) -- The native ScreenShake hook can return early at normal priority.

hook.Add("Bones", "hg_shield_hit_body", function(ply)
	if not IsValid(ply) or not ply:Alive() or not hg.bone or not hg.bone.Set or hg.GetCurrentCharacter(ply) ~= ply then return end
	local shield = hg.GetPlayerBallisticShield and hg.GetPlayerBallisticShield(ply)
	if not shield then return end
	local _, turn = hg.GetShieldHitMotion(shield, ply:EyeAngles())
	if turn.p == 0 and turn.y == 0 and turn.r == 0 then return end
	-- A separate native layer fades out through HomigradBones when the hit ends.
	hg.bone.Set(ply, "spine2", vector_origin, Angle(0, turn.y * 0.25, turn.p * 0.65), "shield_hit")
end)

local colour = { ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0 }
hook.Add("RenderScreenspaceEffects", "hg_shield_hit_focus", function()
	local ply = LocalPlayer()
	local shield = localResponse(ply)
	if not shield then return end
	local elapsed = CurTime() - shield:GetNWFloat("ShieldHitAt", -100000)
	if elapsed < 0 or elapsed >= 0.16 then return end
	local _, _, _, _, amount = hg.GetShieldHitMotion(shield, ply:EyeAngles())
	if amount <= 0 then return end
	local focus = amount * (1 - elapsed / 0.16)
	colour["$pp_colour_brightness"] = -focus * 0.008
	colour["$pp_colour_contrast"] = 1 + focus * 0.035
	colour["$pp_colour_colour"] = 1 - focus * 0.12
	DrawColorModify(colour)
end)
