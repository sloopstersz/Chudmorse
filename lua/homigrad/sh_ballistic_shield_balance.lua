-- Extra handling cost and recovery for an explicitly enabled shield combination.
local shieldClass = "weapon_ballistic_shield"

local function companionShield(weapon)
	if not IsValid(weapon) or not weapon.ismelee or not hg.GetShieldCompanion then return end
	return hg.GetShieldCompanion(weapon)
end

-- Native GetInAttack can end on contact; PlayAnim's duration includes the return swing.
function hg.StartShieldMeleeSwing(weapon, anim, duration)
	local shield = companionShield(weapon)
	if not shield or not isstring(anim) then return end
	local previous = shield.ShieldMeleeSwing
	local chargedRecovery = anim == "equip" and previous and previous.weapon == weapon and previous.charged
		and previous.finish > CurTime()
	local charged = anim == "charge_end" or chargedRecovery
	if string.sub(anim, 1, 6) ~= "attack" and not charged then
		shield.ShieldMeleeSwing = nil
		if SERVER then shield:SetNWFloat("ShieldSwingUntil", 0) end
		return
	end
	if shield.IsShieldCombinationReady and not shield:IsShieldCombinationReady() then return end
	local finish = CurTime() + math.max(duration or 0, 0) + 0.08
	shield.ShieldMeleeSwing = {weapon = weapon, finish = finish, charged = charged}
	if SERVER then
		shield:SetNWString("ShieldSwingWeapon", weapon:GetClass())
		shield:SetNWFloat("ShieldSwingUntil", finish)
	end
end

function hg.ShieldMeleeSwingActive(shield, weapon)
	if not IsValid(shield) or not IsValid(weapon) or not weapon.ismelee or weapon.reload then return false end
	local owner = weapon:GetOwner()
	if not IsValid(owner) or owner ~= shield:GetOwner() or owner:GetActiveWeapon() ~= weapon then return false end
	local finish = shield:GetNWString("ShieldSwingWeapon", "") == weapon:GetClass() and shield:GetNWFloat("ShieldSwingUntil", 0) or 0
	local state = shield.ShieldMeleeSwing
	if state and state.weapon == weapon then
		finish = math.max(finish, state.finish)
		-- Client hit reactions may stretch the visible recovery after contact.
		if CLIENT and not weapon.cycling then finish = math.max(finish, weapon.animtime or 0) end
	end
	return finish > CurTime()
end

function hg.ShieldMeleeStaminaCost(weapon, cost)
	local shield = companionShield(weapon)
	if not shield then return cost end
	return cost * math.max(shield.ShieldMeleeStaminaMultiplier or 1.6, 1)
end

-- Use the stock movement multiplier, preserving class speed, injury and load penalties.
hook.Add("HG_MovementCalc_2", "hg_shield_weight", function(mul, owner)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() or owner:InVehicle()
		or owner:GetMoveType() ~= MOVETYPE_WALK or hg.GetCurrentCharacter(owner) ~= owner then return end
	local shield = owner:GetWeapon(shieldClass)
	if not IsValid(shield) or not isfunction(shield.GetShieldCarryFraction) then return end
	local carrying = shield:GetShieldCarryFraction()
	local multiplier = Lerp(carrying, shield.ShieldBackMoveMultiplier or 0.88, shield.ShieldMoveMultiplier or 0.75)
	mul[1] = mul[1] * multiplier
end)
