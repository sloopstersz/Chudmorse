if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "Ballistic Shield"
SWEP.Instructions = "Stops melee hits, pistol rounds, buckshot and fragments that hit the shield. Reduces blast damage and concussion where the plate covers your body. Rifle rounds penetrate. Covers your back when holstered.\n\nLMB to strike with the shield. Select a pistol or light one-handed melee weapon, then press Alt+R to toggle carrying it with the shield. Combination starts disabled.\nIn combination: release RMB to cover your weapon; hold RMB to move the shield aside. LMB uses the weapon once clear. Shield strikes are disabled while carrying another weapon. Rebind SHIELD COMBINATION in settings."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 3

SWEP.WorldModel = "models/weapons/arccw_go/v_shield.mdl"
SWEP.WorldModelReal = "models/weapons/arccw_go/v_shield.mdl"
SWEP.WorldModelExchange = false
SWEP.ViewModel = ""
SWEP.HoldType = "shotgun"
SWEP.weight = 25

SWEP.supportTPIK = true
SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = true
SWEP.CanSuicide = false
SWEP.WorkWithFake = true
SWEP.WepSelectIcon = Material("entities/shit.png")
SWEP.WepSelectIcon2 = Material("entities/shit.png")
SWEP.IconOverride = "entities/shit.png"

SWEP.HoldPos = Vector(5, 1, 2)
SWEP.HoldAng = Angle(0, 0, 0)

SWEP.AnimList = {
	["idle"] = "idle",
	["deploy"] = "deploy",
	["attack"] = "bash",
	["attack2"] = "bash",
}

SWEP.AttackTime = 0.58
SWEP.AnimTime1 = 1.26
SWEP.WaitTime1 = 1.5
SWEP.AttackLen1 = 40
SWEP.ViewPunch1 = Angle(2.8, -0.7, 0.8)
SWEP.ViewPunchDiv = 80
SWEP.MinSensivity = 0.85

SWEP.Attack2Time = 0.3
SWEP.AnimTime2 = 1
SWEP.WaitTime2 = 0.9
SWEP.AttackLen2 = 70
SWEP.ViewPunch2 = Angle(1, -1, 0)

SWEP.AttackTimeLength = 0.68
SWEP.Attack2TimeLength = 0.15
SWEP.AttackRads = 40
SWEP.AttackRads2 = 40
SWEP.SwingAng = 0
SWEP.SwingAng2 = 0

SWEP.DamageType = DMG_CLUB
SWEP.DamagePrimary = 20
SWEP.DamageSecondary = 15
SWEP.PenetrationPrimary = 1
SWEP.PenetrationSecondary = 1
SWEP.MaxPenLen = 1
SWEP.PenetrationSizePrimary = 3
SWEP.PenetrationSizeSecondary = 3
SWEP.StaminaPrimary = 60
SWEP.StaminaSecondary = 20
SWEP.PainMultiplier = 1.2

SWEP.AttackSwing = "weapons/slam/throw.wav"
SWEP.AttackHit = "weapons/melee/blunt_heavy4.wav"
SWEP.Attack2Hit = "physics/metal/metal_barrel_impact_hard7.wav"
SWEP.AttackHitFlesh = "weapons/melee/blunt_heavy4.wav"
SWEP.Attack2HitFlesh = "physics/body/body_medium_break3.wav"
SWEP.DeploySnd = "physics/metal/metal_canister_impact_soft2.wav"


SWEP.ShieldMaxSpeed = 600
SWEP.ShieldBlastDamageMultiplier = 0.04
SWEP.ShieldToggleCooldown = 5
SWEP.ShieldReadyTime = 0.38
SWEP.ShieldCoverTime = 0.32
SWEP.ShieldDrawTime = 1.05
SWEP.ShieldStowTime = 0.95
SWEP.ShieldPoseBlendTime = 0.24
SWEP.ShieldResumeTime = 0.22
SWEP.ShieldMoveMultiplier = 0.75
SWEP.ShieldBackMoveMultiplier = 0.88
SWEP.ShieldMeleeStaminaMultiplier = 1.6
SWEP.ShieldMaxRetraction = 12.1
SWEP.ShieldInertiaScale = 1

-- Bounds of the mesh in the model's "shield" bone space (not its viewmodel bounds).
SWEP.ShieldMins = Vector(-3, -14.3, -24.6)
SWEP.ShieldMaxs = Vector(2.9, 14.3, 24.6)

local shieldClass = "weapon_ballistic_shield"
local backPos, backAng = Vector(-5, -7, 0), Angle(0, -90, -90)
local rifleShells = {
	["556x45"] = true, ["545x39"] = true, ["762x39"] = true,
	["762x51"] = true, ["762x54"] = true, ["366tkm"] = true,
	["50cal"] = true, [".338Lapua"] = true, ["Pulse"] = true,
}
local defaultAmmo = {pistol = true, smg1 = true, ["357"] = true, buckshot = true}
local poseDefaults = {
	hold = {16, 4, -20, 0, 0, 0}, side = {16, 12, -20, 0, 0, 0},
	shield_pistol = {16, 12, -20, 0, 0, 0}, shield_melee = {16, 12, -20, 0, 0, 0},
	weapon_pistol = {0, 0, 0, 0, 0, 0}, weapon_melee = {0, 0, 0, 0, 0, 0},
	shield_pistol_ready = {16, 28, -22, 0, -12, -6}, shield_melee_ready = {16, 28, -22, 0, -12, -6},
	weapon_pistol_hidden = {-9, 5, -6, 25, 0, -8}, weapon_melee_hidden = {-6, 5, -6, 20, 0, -8},
}

local function fittedPose(name)
	local defaults = poseDefaults[name]
	return GetGlobalVector("hg_shield_" .. name .. "_pos", Vector(defaults[1], defaults[2], defaults[3])),
		GetGlobalAngle("hg_shield_" .. name .. "_ang", Angle(defaults[4], defaults[5], defaults[6]))
end
-- Phase 0..1 is the windup, 1..2 the recovery; phase 1 is server contact.
-- Position, shield rotation and camera lean describe one committed body movement.
local bashFrames = {
	{0, Vector(), Angle(), Vector()},
	{0.62, Vector(-2.2, -0.6, -1.2), Angle(-8, 4, 3), Vector(-0.7, 0.1, -0.35)},
	{1, Vector(3.8, 0.8, 1.1), Angle(10, -5, -3), Vector(1.8, -0.15, -0.75)},
	{1.12, Vector(3.2, 0.65, 0.8), Angle(7, -3.5, -2), Vector(1.35, -0.1, -0.9)},
	{1.55, Vector(-0.65, -0.2, -0.5), Angle(-3, 1, 1), Vector(-0.4, 0.05, -0.25)},
	{2, Vector(), Angle(), Vector()},
}

function SWEP:GetShieldBashMotion()
	if not self:GetInAttack() then return vector_origin, angle_zero, vector_origin end
	local impact = self:GetLastAttack()
	local recovery = math.max(self:GetAttackTime() - impact, 0.001)
	local windup = recovery * self.AttackTime / self.AttackTimeLength
	local phase = CurTime() <= impact and math.Clamp(1 + (CurTime() - impact) / windup, 0, 1)
		or 1 + math.Clamp((CurTime() - impact) / recovery, 0, 1)
	for i = 2, #bashFrames do
		local nextFrame, previous = bashFrames[i], bashFrames[i - 1]
		if phase <= nextFrame[1] then
			local t = (phase - previous[1]) / (nextFrame[1] - previous[1])
			t = t * t * (3 - 2 * t)
			return LerpVector(t, previous[2], nextFrame[2]), LerpAngle(t, previous[3], nextFrame[3]),
				LerpVector(t, previous[4], nextFrame[4])
		end
	end
	return vector_origin, angle_zero, vector_origin
end

-- Server-owned live fitting: the mesh, both hands and bullet OBB use these values.
if SERVER then
	-- Disable every fitting command, including callbacks left by Lua refresh.
	-- Keep loading the server-owned saved poses below.
	for _, command in ipairs({
		"hg_shield_pos", "hg_shield_side_pos", "hg_shield_pistol_pos",
		"hg_shield_melee_pos", "hg_shield_pistol_weapon_pos", "hg_shield_melee_weapon_pos",
		"hg_shield_pistol_ready_pos", "hg_shield_melee_ready_pos", "hg_shield_pistol_hidden_weapon_pos",
		"hg_shield_melee_hidden_weapon_pos", "hg_shield_pose_reset", "hg_shield_brace_pos",
	}) do concommand.Remove(command) end
	local settingsFile = "ballistic_shield_pose.json"
	local function validPose(values)
		if not istable(values) or #values ~= 6 then return false end
		for i = 1, 6 do
			local n = values[i]
			if not isnumber(n) or n ~= n or math.abs(n) > (i <= 3 and 128 or 180) then return false end
		end
		return true
	end
	local stored = hg.BallisticShieldPose or util.JSONToTable(file.Read(settingsFile, "DATA") or "") or {}
	local settings = {}
	for name, defaults in pairs(poseDefaults) do
		local values = istable(stored) and stored[name]
		-- Preserve the player's old shared side grip when splitting it by weapon type.
		if not validPose(values) and (name == "shield_pistol" or name == "shield_melee") then
			values = istable(stored) and stored.side
		end
		settings[name] = validPose(values) and table.Copy(values) or table.Copy(defaults)
	end
	hg.BallisticShieldPose = settings
	local function publish()
		for name, values in pairs(settings) do
			SetGlobalVector("hg_shield_" .. name .. "_pos", Vector(values[1], values[2], values[3]))
			SetGlobalAngle("hg_shield_" .. name .. "_ang", Angle(values[4], values[5], values[6]))
		end
	end
	publish()
end

hg.BallisticShields = hg.BallisticShields or setmetatable({}, {__mode = "k"})
-- Remove the old direction-only immunity when this SWEP is auto-refreshed.
hook.Remove("PostEntityFireBullets", "hg_shield_block")

function SWEP:InitAdd()
	hg.BallisticShields[self] = true
	if SERVER then
		self:SetNWBool("ShieldCombination", false)
		self:SetNWBool("ShieldCarryTarget", false)
		self:SetNWBool("ShieldCarryPaused", false)
		self:SetNWFloat("ShieldCarryFrom", 0)
		self:SetNWFloat("ShieldCarryAt", CurTime())
		self:SetNWString("ShieldCarryProfile", "hold")
	end
end

function SWEP:InUse()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end
	if not hg.CanUseLeftHand(owner) or not hg.CanUseRightHand(owner) then return false end
	return self.BaseClass.InUse(self)
end

local function compatibleWeapon(weapon)
	if not IsValid(weapon) or weapon:GetClass() == shieldClass then return false end
	if weapon.ShieldCompatible ~= nil then return weapon.ShieldCompatible == true end
	if weapon.ishgwep then return weapon.IsPistolHoldType and weapon:IsPistolHoldType() end
	-- Weight is in kg; exclude two-handed tools and heavy one-handed exceptions.
	return weapon.ismelee and not weapon.TwoHanded and isnumber(weapon.weight) and weapon.weight <= 1.5
end

-- Carrying is separate from control: a knocked-down player still has a visible shield.
function SWEP:GetCarriedCompanionWeapon()
	local owner = self:GetOwner()
	if (not self:GetNWBool("ShieldCombination", false) and self:GetShieldCarryFraction() == 0)
		or not IsValid(owner) or not owner:IsPlayer()
		or not owner:Alive() or owner.suiciding or owner:InVehicle()
		or not hg.CanUseLeftHand(owner) or not hg.CanUseRightHand(owner) then return end
	local weapon = owner:GetActiveWeapon()
	if compatibleWeapon(weapon) then return weapon end
end

function SWEP:GetCompanionWeapon()
	if not self:InUse() then return end
	local weapon = self:GetCarriedCompanionWeapon()
	-- Reloading keeps the offhand grip; readiness closes without changing the companion.
	if weapon and weapon.InUse and weapon:InUse() then return weapon end
end

function SWEP:ToggleShieldCombination()
	if not SERVER then return false end
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end
	local weapon = owner:GetActiveWeapon()
	if weapon ~= self and not compatibleWeapon(weapon) then return false end
	local enabled = not self:GetNWBool("ShieldCombination", false)
	if (enabled and not self:InUse()) or self:GetInAttack() or weapon.reload
		or (weapon.GetInAttack and weapon:GetInAttack())
		or (hg.ShieldMeleeSwingActive and hg.ShieldMeleeSwingActive(self, weapon)) then return false end
	local now = CurTime()
	local remaining = (owner.HGShieldNextToggle or 0) - now
	if enabled and remaining > 0 then
		if now >= (owner.HGShieldCooldownNoticeAt or 0) then
			owner.HGShieldCooldownNoticeAt = now + 1
			owner:ChatPrint(string.format("Shield combination cooldown: %.1f s.", remaining))
		end
		return false
	end
	-- Keep the cooldown on the player so replacing/dropping the shield cannot bypass it.
	if enabled then owner.HGShieldNextToggle = now + (self.ShieldToggleCooldown or 5) end
	self:UpdateShieldCarry()
	self:SetNWBool("ShieldCombination", enabled)
	self:UpdateShieldCarry()
	self:UpdateShieldReady()
	if weapon.SetBlocking then weapon:SetBlocking(false) end
	owner:ChatPrint(enabled and "Shield combination enabled. Hold RMB to ready your weapon. Shield strikes are disabled."
		or "Shield combination disabled.")
	return true
end

-- IsValid only confirms the engine entity, not that its current SWEP methods
-- have arrived. Check at global hook boundaries; retry naturally next call.
local function shieldMethodsAvailable(shield)
	-- A holstered shield can stop transmitting before its cleared owner arrives.
	-- Keep it registered for PVS re-entry, but never use its stale client state.
	return IsValid(shield) and isfunction(shield.GetCompanionWeapon)
		and isfunction(shield.GetCarriedCompanionWeapon) and isfunction(shield.GetRagdollShieldTransform)
		and isfunction(shield.GetShieldCarryFraction) and isfunction(shield.IsShieldCombinationReady)
		and isfunction(shield.UpdateShieldCarry) and isfunction(shield.IsShieldCarryBusy)
		and isfunction(shield.UpdateShieldReady) and isfunction(shield.GetShieldReadyFraction)
		and isfunction(shield.CanUseCompanionWeapon) and isfunction(shield.GetShieldTransform)
		and isfunction(shield.ClampShieldPose)
		and isfunction(shield.GetInAttack) and isfunction(shield.InUse)
		and (not CLIENT or not shield:IsDormant())
end

-- The observer may receive the active weapon/explicit handle before its inventory.
function hg.GetPlayerBallisticShield(owner)
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local function owned(candidate)
		return shieldMethodsAvailable(candidate) and candidate:GetOwner() == owner and candidate:GetClass() == shieldClass
	end
	local active = owner:GetActiveWeapon()
	if owned(active) then return active end
	local linked = owner:GetNWEntity("BallisticShield")
	if owned(linked) then return linked end
	local inventory = owner:GetWeapon(shieldClass)
	if owned(inventory) then return inventory end
	for candidate in pairs(hg.BallisticShields) do
		if owned(candidate) then return candidate end
	end
end

function SWEP:UpdateShieldTransmission(owner)
	if not SERVER then return end
	if self.ShieldPVSFlagApplied then
		self:RemoveEFlags(EFL_IN_SKYBOX)
		self.ShieldPVSFlagApplied = nil
	end
	owner = owner or self:GetOwner()
	local previous = self.ShieldTransmitOwner
	if IsValid(previous) and previous ~= owner and previous:GetNWEntity("BallisticShield") == self then
		previous:SetNWEntity("BallisticShield", NULL)
	end
	-- Source already parents equipped weapons to their holder. Include the
	-- holstered shield when that parent transmits, without broadcasting the holder.
	local follow = IsValid(owner) and self:GetParent() == owner
	if self.ShieldTransmitParent ~= follow then
		self:SetTransmitWithParent(follow)
		self.ShieldTransmitParent = follow
	end
	if IsValid(owner) and owner:IsPlayer() and owner:GetNWEntity("BallisticShield") ~= self then
		owner:SetNWEntity("BallisticShield", self)
	end
	self.ShieldTransmitOwner = owner
end

if SERVER then
	hook.Add("WeaponEquip", "hg_shield_transmission", function(weapon, owner)
		if IsValid(weapon) and weapon:GetClass() == shieldClass and isfunction(weapon.UpdateShieldTransmission) then
			weapon:UpdateShieldTransmission(owner)
		end
	end)
	hook.Add("PlayerDroppedWeapon", "hg_shield_transmission", function(_, weapon)
		if IsValid(weapon) and weapon:GetClass() == shieldClass and isfunction(weapon.UpdateShieldTransmission) then
			weapon:UpdateShieldTransmission(NULL)
		end
	end)
end

function hg.GetShieldCompanion(weapon)
	if not IsValid(weapon) then return end
	local owner = weapon:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local shield = hg.GetPlayerBallisticShield(owner)
	if shieldMethodsAvailable(shield) and shield:GetCompanionWeapon() == weapon then return shield end
end

function hg.GetCarriedShield(weapon)
	if not IsValid(weapon) then return end
	local owner = weapon:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local shield = hg.GetPlayerBallisticShield(owner)
	if shieldMethodsAvailable(shield) and shield:GetCarriedCompanionWeapon() == weapon then return shield end
end

local combinationBind = "SHIELD COMBINATION"
local toggleMessage = "hg_shield_combination_request"
local function requestShieldToggle(owner)
    if not SERVER or not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
    local now = CurTime()
    if now < (owner.ShieldRequestAfter or 0) then return end
    owner.ShieldRequestAfter = now + 0.25
    local shield = hg.GetPlayerBallisticShield(owner)
    if shieldMethodsAvailable(shield) then shield:ToggleShieldCombination() end
end
if SERVER then
    util.AddNetworkString(toggleMessage)
    net.Receive(toggleMessage, function(_, owner)
        -- Never trust a client-supplied weapon, owner or enabled state.
        requestShieldToggle(owner)
    end)
end
function hg.ShieldCombinationKeyDown(owner, reloadPressed)
	if not IsValid(owner) then return false end
	local pressed = owner:IsPlayer() and owner:KeyDown(IN_WALK) and (reloadPressed or owner:KeyDown(IN_RELOAD))
	if owner.IsBindPressed then pressed = pressed or owner:IsBindPressed(combinationBind) end
	if not pressed and reloadPressed and hg.Binds and isfunction(hg.Binds.GetButton) then
		-- StartCommand can precede the R button callback on the first reload tick.
		local keys = hg.Binds.GetButton(combinationBind, owner)
		pressed = keys and keys[1] == KEY_R and keys[2] and (owner.downedbuttons or {})[keys[2]]
	end
	if not pressed then return false end
	local shield = hg.GetPlayerBallisticShield(owner)
	local weapon = owner:GetActiveWeapon()
	return shieldMethodsAvailable(shield) and (weapon == shield or compatibleWeapon(weapon))
end

-- The bind dispatcher fires again for other keys held with a chord; latch until release.
hook.Add("BindActivated_" .. combinationBind, "hg_shield_combination", function(owner)
	if not SERVER or owner.ShieldCombinationLatch or not hg.ShieldCombinationKeyDown(owner) then return end
	owner.ShieldCombinationLatch = true
	requestShieldToggle(owner)
end)

hook.Add("PlayerButtonUp", "hg_shield_combination_release", function(owner, button)
	local keys = hg.Binds and isfunction(hg.Binds.GetButton) and hg.Binds.GetButton(combinationBind, owner)
	if keys and (button == keys[1] or button == keys[2]) then owner.ShieldCombinationLatch = nil end
end)

if SERVER then
	concommand.Add("hg_shield_toggle", function(owner)
		if not IsValid(owner) or not owner:IsPlayer() then return end
		requestShieldToggle(owner)
	end)
	local function resetCombination(shield)
		if not IsValid(shield) or shield:GetClass() ~= shieldClass then return end
		shield:SetNWBool("ShieldCombination", false)
		shield:SetNWFloat("ShieldCarryFrom", 0)
		shield:SetNWFloat("ShieldCarryAt", CurTime())
		shield:SetNWBool("ShieldCarryTarget", false)
		shield:SetNWBool("ShieldCarryPaused", false)
		shield.ShieldCarryCharacter = nil
		shield.ShieldReadiness = nil
	end
	hook.Add("WeaponEquip", "hg_shield_combination_reset", resetCombination)
	hook.Add("PlayerDeath", "hg_shield_combination_death", function(owner)
		resetCombination(hg.GetPlayerBallisticShield(owner))
		owner.ShieldCombinationLatch = nil
	end)
end

local function readyFraction(from, target, started, opening, closing)
	local duration = (target == 1 and opening or closing) * math.abs(target - from)
	if duration < 0.001 then return target end
	local t = math.Clamp((CurTime() - started) / duration, 0, 1)
	t = t * t * (3 - 2 * t)
	return from + (target - from) * t
end

local function smoothCarry(t)
	t = math.Clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function carryAngle(t, from, to)
	if t <= 0 then return from end
	if t >= 1 then return to end
	-- Keep the same short turn across -180/180, including the edge-on shoulder pose.
	return Angle(from.p + ((to.p - from.p + 180) % 360 - 180) * t,
		from.y + ((to.y - from.y + 180) % 360 - 180) * t,
		from.r + ((to.r - from.r + 180) % 360 - 180) * t)
end

local function spineTransform(ent)
	local bone = ent:LookupBone("ValveBiped.Bip01_Spine2")
	local matrix = bone and ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation(), matrix:GetAngles() end
end

local function shieldBackTransform(ent)
	local pos, ang = spineTransform(ent)
	if pos then return LocalToWorld(backPos, backAng, pos, ang) end
end

local function heldOffset(profile, ready)
	local pos, ang = fittedPose(profile)
	if profile ~= "hold" then
		local opened, rotation = fittedPose(profile .. "_ready")
		pos, ang = LerpVector(ready, pos, opened), LerpAngle(ready, ang, rotation)
	end
	return pos, ang
end

function SWEP:GetShieldCarryFraction()
	local from = self:GetNWFloat("ShieldCarryFrom", 0)
	if self:GetNWBool("ShieldCarryPaused", false) then return from end
	local target = self:GetNWBool("ShieldCarryTarget", false) and 1 or 0
	return readyFraction(from, target, self:GetNWFloat("ShieldCarryAt", CurTime()), self.ShieldDrawTime, self.ShieldStowTime)
end

-- Keep the visible raised pose while a previous weapon is being put away.
function SWEP:GetShieldVisualReadyFraction()
	if self:IsShieldCarryBusy() then
		return readyFraction(self:GetNWFloat("ShieldCarryReadyFrom", 0), 0,
			self:GetNWFloat("ShieldCarryReadyAt", CurTime()), self.ShieldReadyTime, self.ShieldCoverTime)
	end
	local owner, state = self:GetOwner(), self.ShieldReadiness
	if state and (SERVER or owner == LocalPlayer()) then
		return readyFraction(state.from, state.target, state.started, self.ShieldReadyTime, self.ShieldCoverTime)
	end
	return readyFraction(self:GetNWFloat("ShieldReadyFrom", 0), self:GetNWBool("ShieldReady", false) and 1 or 0,
		self:GetNWFloat("ShieldReadyAt", CurTime()), self.ShieldReadyTime, self.ShieldCoverTime)
end

function SWEP:GetShieldProfileFraction()
	if self.ShieldPoseBlendTime <= 0 then return 1 end
	return smoothCarry((CurTime() - self:GetNWFloat("ShieldProfileAt", -100000)) / self.ShieldPoseBlendTime)
end

function SWEP:GetShieldHeldOffset(ready)
	local pos, ang = heldOffset(self:GetNWString("ShieldCarryProfile", "hold"), ready)
	local blend = self:GetShieldProfileFraction()
	if blend < 1 then
		pos = LerpVector(blend, self:GetNWVector("ShieldProfileFromPos", pos), pos)
		ang = carryAngle(blend, self:GetNWAngle("ShieldProfileFromAng", ang), ang)
	end
	return pos, ang
end

function SWEP:IsShieldCarryBusy()
	if self:GetNWBool("ShieldCarryPaused", false) then return false end
	local carry = self:GetShieldCarryFraction()
	local target = self:GetNWBool("ShieldCarryTarget", false) and 1 or 0
	return carry ~= target or (carry > 0 and (self:GetShieldProfileFraction() < 1
		or CurTime() - self:GetNWFloat("ShieldResumeAt", -100000) < self.ShieldResumeTime))
end

function SWEP:IsShieldCombinationReady()
	return self:GetNWBool("ShieldCombination", false) and self:GetNWBool("ShieldCarryTarget", false)
		and self:GetShieldCarryFraction() == 1 and not self:IsShieldCarryBusy()
end

-- The server records one clock for selecting the shield, Alt+R and weapon changes.
-- Clients sample these timestamps, including when a remote player enters the PVS midway.
function SWEP:UpdateShieldCarry()
	if not SERVER then return end
	self:UpdateShieldTransmission()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local ent, weapon = hg.GetCurrentCharacter(owner), owner:GetActiveWeapon()
	if not IsValid(ent) then return end
	local equipped = weapon == self
	local combined = self:GetNWBool("ShieldCombination", false) and compatibleWeapon(weapon)
	local target = owner:Alive() and not owner:InVehicle() and not owner.suiciding
		and hg.CanUseLeftHand(owner) and hg.CanUseRightHand(owner) and (equipped or combined) or false
	local carry = self:GetShieldCarryFraction()
	local visualReady = self:GetShieldVisualReadyFraction()
	local changed = false
	local paused = ent ~= owner and not self:InUse()
	local wasPaused = self:GetNWBool("ShieldCarryPaused", false)
	if wasPaused and not paused and IsValid(self.ShieldCarryCharacter) and carry > 0 then
		local origin, orientation = spineTransform(ent)
		local pos, ang
		if carry >= 0.18 then pos, ang = self:GetRagdollShieldTransform(self.ShieldCarryCharacter)
		else pos, ang = shieldBackTransform(self.ShieldCarryCharacter) end
		if pos and origin then
			local offset, rotation = WorldToLocal(pos, ang, origin, orientation)
			self:SetNWVector("ShieldResumeFromPos", offset)
			self:SetNWAngle("ShieldResumeFromAng", rotation)
			self:SetNWFloat("ShieldResumeAt", CurTime())
		end
	end
	self.ShieldCarryCharacter = ent
	if target ~= self:GetNWBool("ShieldCarryTarget", false) or paused ~= wasPaused then
		changed = true
		self:SetNWFloat("ShieldCarryFrom", carry)
		self:SetNWFloat("ShieldCarryAt", CurTime())
		self:SetNWBool("ShieldCarryTarget", target)
		self:SetNWBool("ShieldCarryPaused", paused)
	end
	if target then
		local profile = equipped and "hold" or (weapon.ishgwep and "shield_pistol" or "shield_melee")
		if profile ~= self:GetNWString("ShieldCarryProfile", "hold") then
			-- Preserve the current pose when changing a held shield into an offhand grip.
			changed = true
			local pos, ang = self:GetShieldHeldOffset(visualReady)
			self:SetNWVector("ShieldProfileFromPos", pos)
			self:SetNWAngle("ShieldProfileFromAng", ang)
			self:SetNWFloat("ShieldProfileAt", CurTime())
			self:SetNWString("ShieldCarryProfile", profile)
		end
	end
	if changed then
		self:SetNWFloat("ShieldCarryReadyFrom", visualReady)
		self:SetNWFloat("ShieldCarryReadyAt", CurTime())
		self:UpdateShieldReady()
	end
end

function hg.IsShieldCarryBusy(owner)
	if not IsValid(owner) or not owner:IsPlayer() then return false end
	local shield = hg.GetPlayerBallisticShield(owner)
	if not shieldMethodsAvailable(shield) then return false end
	shield:UpdateShieldCarry()
	return shield:IsShieldCarryBusy()
end

-- These policies must also work before a command can set owner.suiciding.
function hg.GetWorkingShield(owner)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	local shield = hg.GetPlayerBallisticShield(owner)
	if not shieldMethodsAvailable(shield) then return end
	local weapon = owner:GetActiveWeapon()
	if weapon == shield then return shield end
	if shield:GetNWBool("ShieldCombination", false) and compatibleWeapon(weapon) and not owner:InVehicle()
		and hg.CanUseLeftHand(owner) and hg.CanUseRightHand(owner) then return shield end
	shield:UpdateShieldCarry()
	if shield:GetShieldCarryFraction() > 0 or shield:IsShieldCarryBusy() then return shield end
end

function hg.ShieldBlocksPosture(owner)
	if not hg.GetWorkingShield(owner) then return false end
	local weapon = owner:GetActiveWeapon()
	return IsValid(weapon) and weapon.ishgwep and weapon.IsPistolHoldType and weapon:IsPistolHoldType() or false
end

function SWEP:GetShieldReadyFraction()
	local owner = self:GetOwner()
	if CLIENT and owner ~= LocalPlayer() then
		local weapon = IsValid(owner) and owner:GetActiveWeapon()
		if not IsValid(weapon) or self:GetNWString("ShieldReadyWeapon", "") ~= weapon:GetClass() then return 0 end
		return readyFraction(self:GetNWFloat("ShieldReadyFrom", 0), self:GetNWBool("ShieldReady", false) and 1 or 0,
			self:GetNWFloat("ShieldReadyAt", CurTime()), self.ShieldReadyTime, self.ShieldCoverTime)
	end
	local state = self.ShieldReadiness
	if not state or not IsValid(owner) or state.weapon ~= owner:GetActiveWeapon() then return 0 end
	return readyFraction(state.from, state.target, state.started, self.ShieldReadyTime, self.ShieldCoverTime)
end

-- Predict the local hands; remote players use the server's transition timestamps.
-- Named NW fields avoid changing the melee datatable schema on existing weapons.
function SWEP:UpdateShieldReady(weapon, aiming)
	local owner = self:GetOwner()
	if CLIENT and owner ~= LocalPlayer() then return end
	local companion = self:GetCompanionWeapon()
	if weapon ~= companion then weapon = nil end
	if aiming == nil then aiming = IsValid(owner) and hg.KeyDown(owner, IN_ATTACK2) end
	local committed = weapon and weapon.GetInAttack and weapon:GetInAttack()
	if weapon and hg.ShieldMeleeSwingActive then committed = committed or hg.ShieldMeleeSwingActive(self, weapon) end
	local target = weapon and self:IsShieldCombinationReady() and not weapon.reload
		and not self:GetInAttack() and (aiming or committed) and 1 or 0
	local state = self.ShieldReadiness
	local changedWeapon = not state or state.weapon ~= weapon
	if not changedWeapon and state.target == target then return end
	local from = changedWeapon and 0 or self:GetShieldReadyFraction()
	self.ShieldReadiness = {weapon = weapon, from = from, target = target, started = CurTime()}
	if SERVER then
		self:SetNWFloat("ShieldReadyFrom", from)
		self:SetNWFloat("ShieldReadyAt", CurTime())
		self:SetNWBool("ShieldReady", target == 1)
		self:SetNWString("ShieldReadyWeapon", IsValid(weapon) and weapon:GetClass() or "")
	end
end

function SWEP:CanUseCompanionWeapon(weapon)
	if not self:IsShieldCombinationReady() or weapon.reload or self:GetInAttack()
		or self:GetShieldReadyFraction() < 0.98 then return false end
	if weapon.ishgwep and weapon.GetTrace then
		-- Reject a fitted muzzle still inside/behind the shield's actual surface.
		local muzzle, aim = weapon:GetTrace(true, nil, nil, true)
		local pos, ang = self:GetShieldTransform()
		if not muzzle or not aim or not pos then return false end
		local owner = weapon:GetOwner()
		local eye = hg.eye(owner, 0, hg.GetCurrentCharacter(owner))
		if not eye or util.IntersectRayWithOBB(eye, muzzle - eye, pos, ang, self.ShieldMins, self.ShieldMaxs) then return false end
		if util.IntersectRayWithOBB(muzzle, aim:Forward() * 64, pos, ang, self.ShieldMins, self.ShieldMaxs) then return false end
	end
	return true
end

-- Offsets use eye axes (X forward, Y left, Z up), not a model's rotated grip axes.
-- Apply before model/muzzle derivation so server shots and client hands agree.
function hg.ShieldCompanionWeaponTransform(weapon, pos, ang)
	local shield = hg.GetShieldCompanion(weapon)
	if not pos or not ang or not shield then return pos, ang end
	local offset, rotation = fittedPose(weapon.ishgwep and "weapon_pistol" or "weapon_melee")
	local hiddenPos, hiddenAng = fittedPose(weapon.ishgwep and "weapon_pistol_hidden" or "weapon_melee_hidden")
	-- Each command defines one complete endpoint; neither is an offset of the other.
	local ready = shield:GetShieldReadyFraction()
	offset, rotation = LerpVector(ready, hiddenPos, offset), LerpAngle(ready, hiddenAng, rotation)
	local carry = shield:GetShieldCarryFraction()
	offset, rotation = offset * carry, LerpAngle(carry, angle_zero, rotation)
	if offset:LengthSqr() ~= 0 or rotation.p ~= 0 or rotation.y ~= 0 or rotation.r ~= 0 then
		local eyeAng = weapon:GetOwner():EyeAngles()
		local _, relativeAng = WorldToLocal(vector_origin, ang, vector_origin, eyeAng)
		pos, ang = LocalToWorld(offset, relativeAng + rotation, pos, eyeAng)
	end
	-- The right hand, weapon and muzzle follow plate contact and blast recoil.
	local _, _, correction = shield:GetShieldTransform()
	return pos + (correction or vector_origin), ang
end

-- Called before the active weapon's attack: its own ammunition/animations stay native.
function hg.ShieldCompanionPrimary(weapon)
	if hg.IsShieldCarryBusy(weapon:GetOwner()) then return true end
	local shield = hg.GetShieldCompanion(weapon)
	if not shield then return false end
	shield:UpdateShieldReady(weapon)
	if weapon.SetBlocking then weapon:SetBlocking(false) end
	if not shield:IsShieldCombinationReady() or weapon.reload or shield:GetInAttack() then return true end
	if hg.KeyDown(weapon:GetOwner(), IN_ATTACK2) then return not shield:CanUseCompanionWeapon(weapon) end
	-- Covered LMB is consumed. A companion weapon never starts a shield strike.
	return true
end

-- Feed the existing melee pose interpolation, keeping its attack animation intact.
function hg.ShieldCompanionMeleePose(weapon, pos, ang)
	local shield = hg.GetShieldCompanion(weapon)
	if not shield then return end
	local ready = shield:GetShieldReadyFraction()
	local carry = shield:GetShieldCarryFraction()
	pos.x = pos.x + (-3 + 5 * ready) * carry
	pos.y = pos.y - 5 * carry
	pos.z = pos.z + (-5 + 7 * ready) * carry
	ang.p = ang.p + (15 - 21 * ready) * carry
end

-- Holstered SWEPs do not get the active weapon's Think/prediction callbacks.
hook.Add("Player Think", "hg_shield_companion", function(owner)
	local shield = hg.GetPlayerBallisticShield(owner)
	if not shieldMethodsAvailable(shield) then return end
	shield:UpdateShieldCarry()
	if isfunction(shield.GetShieldInertia) then
		if shield:GetShieldCarryFraction() > 0 and shield:InUse() then
			shield:GetShieldInertia(owner:EyeAngles())
		else
			shield.ShieldInertia = nil
		end
	end
	shield:UpdateShieldReady(shield:GetCompanionWeapon())
	if owner:GetActiveWeapon() ~= shield then shield:Think() end
end)

-- Read physical keys outside command prediction: IN_WALK is not always bound to Alt.
if CLIENT then
    local wasHeld = false
    hook.Add("Think", "ChudShieldKeyboardToggle", function()
        local held = (input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)) and input.IsKeyDown(KEY_R)
        local pressed = held and not wasHeld
        wasHeld = held
        if not pressed or gui.IsGameUIVisible() or vgui.CursorVisible() then return end
        local owner = LocalPlayer()
        if not IsValid(owner) or not owner:Alive() or owner:IsTyping() then return end
        local shield = hg.GetPlayerBallisticShield(owner)
        if not shieldMethodsAvailable(shield) then return end
        net.Start(toggleMessage)
        net.SendToServer()
    end)
end

-- Keep LMB held through the opening animation, including on semiautomatic guns.
-- The engine receives a fresh attack press when the hand/shield have cleared.
hook.Add("StartCommand", "hg_shield_ready", function(owner, cmd)
    local chord = cmd:KeyDown(IN_WALK) and cmd:KeyDown(IN_RELOAD)
    if SERVER and owner:IsBot() then
        if chord and not owner.ShieldCommandChord then requestShieldToggle(owner) end
        owner.ShieldCommandChord = chord
    end
    if CLIENT and owner == LocalPlayer() then
        chord = chord or ((input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)) and input.IsKeyDown(KEY_R))
    end
    -- Consume the chord after sending it; the server cannot recover stripped input.
    if chord or hg.ShieldCombinationKeyDown(owner, cmd:KeyDown(IN_RELOAD)) then cmd:RemoveKey(IN_RELOAD) end
	local weapon = owner:GetActiveWeapon()
	if hg.IsShieldCarryBusy(owner) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_RELOAD)
		return
	end
	local shield = hg.GetShieldCompanion(weapon)
	if not shield then return end
	local aiming = cmd:KeyDown(IN_ATTACK2)
	shield:UpdateShieldReady(weapon, aiming)
	if not cmd:KeyDown(IN_ATTACK) then return end
	if not shield:IsShieldCombinationReady() or weapon.reload or (aiming and not shield:CanUseCompanionWeapon(weapon))
		or (not aiming and shield:GetShieldReadyFraction() > 0.02) then cmd:RemoveKey(IN_ATTACK) end
end)

-- The shield has no secondary action or generic melee parry.
function SWEP:CanBlock()
	return false
end

function SWEP:SecondaryAttack()
end

function SWEP:BehindAttack()
	return false
end

function SWEP:BlocksShieldAmmo(ammoType)
	local name = isnumber(ammoType) and game.GetAmmoName(ammoType) or ammoType
	if not isstring(name) then return false end
	-- Fragments use a nominal speed of 700 m/s, unlike the old 400 m/s fallback.
	if name == "Metal Debris" or name == "metal_debris" then return true end
	local ammo = (hg.ammotypeshuy and hg.ammotypeshuy[name]) or (hg.ammotypes and hg.ammotypes[name])
	local settings = ammo and ammo.BulletSettings
	if not settings then return defaultAmmo[string.lower(name)] == true end
	-- Subsonic rifle ammunition must still penetrate.
	if rifleShells[settings.Shell] then return false end
	return isnumber(settings.Speed) and settings.Speed <= self.ShieldMaxSpeed
end

-- Shared by server hit tests and client drawing; no client bone matrices are trusted.
-- X is the outward face normal, Y the width and Z the height of the shield.
function SWEP:ClampShieldPose(pos, ang, eye)
	local owner = self:GetOwner()
	if hg.GetCurrentCharacter(owner) ~= owner then return pos, ang end
	local eyeAng = owner:EyeAngles()
	local forward, left, up = ang:Forward(), -ang:Right(), ang:Up()
	local half = (self.ShieldMaxs - self.ShieldMins) * 0.5
	local centre = (self.ShieldMaxs + self.ShieldMins) * 0.5
	local offset = forward * centre.x + left * centre.y + up * centre.z
	-- TraceHull is axis aligned: enclose the rotated shield, including its edges.
	local extent = Vector(math.abs(forward.x) * half.x + math.abs(left.x) * half.y + math.abs(up.x) * half.z,
		math.abs(forward.y) * half.x + math.abs(left.y) * half.y + math.abs(up.y) * half.z,
		math.abs(forward.z) * half.x + math.abs(left.z) * half.y + math.abs(up.z) * half.z)
	local anchor = eye - eyeAng:Forward() * 8
	local height = math.Clamp((pos - eye):Dot(eyeAng:Up()), -20, 0)
	local query = {start = anchor + eyeAng:Up() * height + offset, endpos = pos + offset,
		mins = -extent, maxs = extent, mask = MASK_PLAYERSOLID, collisiongroup = COLLISION_GROUP_PLAYER,
		filter = {self, owner, hg.GetCurrentCharacter(owner), owner:GetActiveWeapon()}}
	if IsValid(self.worldModel) then query.filter[#query.filter + 1] = self.worldModel end
	local active = owner:GetActiveWeapon()
	if IsValid(active) and IsValid(active.worldModel) then query.filter[#query.filter + 1] = active.worldModel end
	if IsValid(owner.OldRagdoll) then query.filter[#query.filter + 1] = owner.OldRagdoll end
	-- Sweep at the fitted height. The portion below the player's feet must not
	-- turn contact with the floor into a backwards pull on the whole shield.
	query.start.z = query.endpos.z
	query.mins.z = math.max(query.mins.z, owner:GetPos().z + 0.1 - query.endpos.z)
	if query.mins.z >= query.maxs.z then return pos, ang end
	local trace = util.TraceHull(query)
	if trace.StartSolid then
		-- A nearby object can obstruct the low anchor; retry from eye height.
		query.start = anchor + offset
		trace = util.TraceHull(query)
	end
	-- Ignore upward-facing floor/slope contacts without hiding a wall behind them.
	-- Trim only the contact hull's lower edge; the plate and protective OBB stay put.
	for _ = 1, 3 do
		local normal = trace.HitNormal
		if trace.StartSolid or not normal or normal.z < 0.7 then break end
		local clearance = (trace.HitPos - query.endpos):Dot(normal) / normal.z
		if clearance < -0.0001 then break end
		query.mins.z = query.mins.z + math.max(clearance, 0) + 0.1
		if query.mins.z >= query.maxs.z then return pos, ang end
		trace = util.TraceHull(query)
	end
	-- An overlapping anchor has no valid entry point. Treating it as fraction zero
	-- pulls a sideways shield through its owner even when retreat cannot clear the wall.
	if trace.StartSolid then return pos, ang end
	local backward = Angle(0, eyeAng.y, 0):Forward()
	local normal = trace.HitNormal
	if normal and normal:Dot(backward) >= -0.25 then return pos, ang end
	local fraction = math.Clamp(trace.Fraction, 0, 1)
	local contact = LerpVector(fraction, query.start, query.endpos) - offset
	-- Only a frontal obstacle may retract the plate. Never cross behind the body.
	local bodyLimit = math.max((pos - eye):Dot(backward), 0)
	local limit = math.min(self.ShieldMaxRetraction, bodyLimit)
	local pullback = math.Clamp((pos - contact):Dot(backward), 0, limit)
	return pos - backward * pullback, ang
end

-- Derived from v_shield idle frame zero, in the left hand bone's coordinates.
local ragdollGripPos = Vector(-2.494611, -0.412061, -5.308801)
local ragdollGripAng = Angle(17.562797, 65.483255, -1.894385)
function SWEP:GetRagdollShieldTransform(ent)
	local bone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
	local matrix = bone and ent:GetBoneMatrix(bone)
	if not matrix then return end
	return LocalToWorld(ragdollGripPos, ragdollGripAng, matrix:GetTranslation(), matrix:GetAngles())
end

local function carryCurve(from, fromAng, finish, finishAng, eyeAng, phase)
	-- First reach/grasp the parked shield; release it only after it is parked again.
	local t = smoothCarry((phase - 0.18) / 0.74)
	if t == 0 then return from, fromAng end
	if t == 1 then return finish, finishAng end
	local body = Angle(0, eyeAng.y, 0)
	local left, forward, up = -body:Right(), body:Forward(), Vector(0, 0, 1)
	local a = from + left * 26 + up * 9
	local b = finish + left * 20 - forward * 5 + up * 5
	local p0, p1, p2 = LerpVector(t, from, a), LerpVector(t, a, b), LerpVector(t, b, finish)
	local pos = LerpVector(t, LerpVector(t, p0, p1), LerpVector(t, p1, p2))
	-- Turn the plate edge-on as it passes the shoulder, then settle it facing forward.
	local side = Angle(-6, eyeAng.y + 90, -8)
	local ang = t < 0.5 and carryAngle(smoothCarry(t * 2), fromAng, side)
		or carryAngle(smoothCarry(t * 2 - 1), side, finishAng)
	return pos, ang
end

-- Use the melee/camera velocity lag and frame-time smoothing with shared inputs.
-- Cache per game-time sample: repeated hand, render and hit queries must not add motion.
function SWEP:GetShieldInertia(eyeAng)
	local owner = self:GetOwner()
	local scale = math.max(self.ShieldInertiaScale or 1, 0)
	if scale == 0 or hg.GetCurrentCharacter(owner) ~= owner or owner:InVehicle() then
		self.ShieldInertia = nil
		return vector_origin, angle_zero
	end
	local now, origin = CurTime(), owner:GetPos()
	local state = self.ShieldInertia
	if not state or state.owner ~= owner or now - state.at > 0.25 or now < state.at
		or (origin - state.origin):LengthSqr() > 128 * 128 then
		state = {owner = owner, at = now, origin = origin, eye = Angle(eyeAng.p, eyeAng.y, eyeAng.r),
			velocity = Vector(), position = Vector(), turn = Angle(), walk = 0, phase = 0, offset = Vector(), rotation = Angle()}
		self.ShieldInertia = state
	end
	local dt = now - state.at
	if dt <= 0 then return state.offset, state.rotation end
	local turn = Angle(math.Clamp(math.AngleDifference(eyeAng.p, state.eye.p) / (dt * 75), -1.5, 1.5),
		math.Clamp(math.AngleDifference(eyeAng.y, state.eye.y) / (dt * 75), -1.5, 1.5), 0)
	state.turn = LerpAngle(hg.lerpFrameTime2(0.08, dt), state.turn, turn)
	state.velocity = LerpVector(hg.lerpFrameTime2(0.9, dt), state.velocity * (0.99 ^ (dt * 60)), -owner:GetVelocity() * 0.01)
	if state.velocity:LengthSqr() > 9 then state.velocity = state.velocity:GetNormalized() * 3 end
	state.position = LerpVector(hg.lerpFrameTime2(0.03, dt), state.position, state.velocity)
	local velocity = owner:GetVelocity()
	local walking = owner:OnGround() and math.Clamp(Vector(velocity.x, velocity.y, 0):Length() / 200, 0, 1) or 0
	state.walk = Lerp(hg.lerpFrameTime2(0.1, dt), state.walk, walking)
	state.phase = state.phase + state.walk * dt * 7
	local step = math.sin(state.phase) * state.walk
	state.offset = state.position + eyeAng:Right() * (state.turn.y + step * 0.35)
		+ eyeAng:Up() * (state.turn.p - math.abs(math.cos(state.phase)) * state.walk * 0.25)
	if state.offset:LengthSqr() > 9 then state.offset = state.offset:GetNormalized() * 3 end
	state.offset = state.offset * scale
	state.rotation = Angle(-state.turn.p * 4,
		-state.turn.y * 4, math.Clamp(state.turn.y * 2 - state.position:Dot(eyeAng:Right()) + step * 0.5, -6, 6)) * scale
	state.at, state.origin = now, origin
	state.eye = Angle(eyeAng.p, eyeAng.y, eyeAng.r)
	return state.offset, state.rotation
end

function SWEP:GetShieldTransform()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	local ent = hg.GetCurrentCharacter(owner)
	if not IsValid(ent) then return end
	if owner:GetActiveWeapon() == self and (not hg.CanUseLeftHand(owner) or not hg.CanUseRightHand(owner)) then return end
	self:UpdateShieldCarry()
	local carry = self:GetShieldCarryFraction()
	local from, fromAng = shieldBackTransform(ent)
	if carry == 0 then self.ShieldInertia = nil return from, fromAng end
	-- An uncontrolled fake keeps its real hand attachment, without a second animation arc.
	if not self:InUse() then
		self.ShieldInertia = nil
		if ent ~= owner and hg.CanUseLeftHand(owner) and hg.CanUseRightHand(owner) then
			if carry < 0.18 then return from, fromAng end
			return self:GetRagdollShieldTransform(ent)
		end
		return
	end
	if carry < 1 and not from then return end
	local eye = hg.eye(owner, 0, ent)
	if not eye then return end
	local ang = owner:EyeAngles()
	local offset, rotation = self:GetShieldHeldOffset(self:GetShieldVisualReadyFraction())
	local motion, turn = self:GetShieldBashMotion()
	local blastMotion, blastTurn = self:GetShieldBlastMotion(ang)
	local inertiaPos, inertiaAng = self:GetShieldInertia(ang)
	local pos, angle = LocalToWorld(offset + motion, rotation + turn + inertiaAng + blastTurn, eye, ang)
	pos = pos + inertiaPos
	local fittedPos = pos
	pos = pos + LocalToWorld(blastMotion, angle_zero, vector_origin, ang)
	if hg.ApplyShieldImpactPose then pos, angle = hg.ApplyShieldImpactPose(self, pos, angle, ang) end
	pos, angle = self:ClampShieldPose(pos, angle, eye)
	local correction = pos - fittedPos
	if from and carry < 1 then
		local uncorrected = carryCurve(from, fromAng, fittedPos, angle, ang, carry)
		pos, angle = carryCurve(from, fromAng, pos, angle, ang, carry)
		correction = pos - uncorrected
	end
	local resume = smoothCarry((CurTime() - self:GetNWFloat("ShieldResumeAt", -100000)) / self.ShieldResumeTime)
	if resume < 1 then
		local origin, orientation = spineTransform(ent)
		if origin then
			local start, startAng = LocalToWorld(self:GetNWVector("ShieldResumeFromPos", vector_origin),
				self:GetNWAngle("ShieldResumeFromAng", angle_zero), origin, orientation)
			pos, angle = LerpVector(resume, start, pos), carryAngle(resume, startAng, angle)
			correction = correction * resume
		end
	end
	return pos, angle, correction
end

local function filtered(filter, shield, owner, character)
	if isfunction(filter) then
		return filter(shield) == false or filter(owner) == false or filter(character) == false
	elseif istable(filter) then
		return table.HasValue(filter, shield) or table.HasValue(filter, owner) or table.HasValue(filter, character)
	end
	return filter == shield or filter == owner or filter == character
end

-- Clip to the FIRST world/entity hit. A shield behind a wall or a body cannot block it.
-- Test all nearby shields so they also cover other players standing behind them.
function hg.TraceBallisticShields(start, finish, ammoType, filter, melee, reportBullet)
	local delta = finish - start
	if delta:LengthSqr() < 0.0001 then return end
	local nearest, result = 1, nil
	local report = SERVER and reportBullet and ammoType ~= nil and hg.RecordShieldScar
	local penetrations = report and {} or nil
	for shield in pairs(hg.BallisticShields) do
		if not IsValid(shield) then
			hg.BallisticShields[shield] = nil
		elseif shieldMethodsAvailable(shield) then
			local owner = shield:GetOwner()
			local blocked = melee or shield:BlocksShieldAmmo(ammoType)
			if IsValid(owner) and owner:IsPlayer() and owner:Alive() and (blocked or report) then
				local character = hg.GetCurrentCharacter(owner)
				if IsValid(character) and not filtered(filter, shield, owner, character)
					and util.DistanceToLine(start, finish, character:GetPos()) < 128 then
					local pos, ang = shield:GetShieldTransform()
					if pos then
						local hit, normal, fraction = util.IntersectRayWithOBB(start, delta, pos, ang, shield.ShieldMins, shield.ShieldMaxs)
						if hit and fraction >= 0 and fraction <= 1 then
							local contact = {Hit = true, HitPos = hit, HitNormal = normal, Fraction = fraction,
								StartPos = start, Normal = delta:GetNormalized(), Entity = shield, MatType = MAT_METAL,
								ShieldOrigin = pos, ShieldAngles = ang, ShieldAmmo = ammoType, ShieldBlocked = blocked,
								ShieldScar = report and fraction > 0 and normal:Dot(delta) < 0,
								ShieldTravel = blocked and 128 or delta:Length() * (1 - fraction)}
							if blocked and fraction <= nearest then nearest, result = fraction, contact end
							if not blocked and report then penetrations[#penetrations + 1] = contact end
						end
					end
				end
			end
		end
	end
	-- Record only real bullets and only up to the nearest blocking plate. Pure IK,
	-- muzzle and melee queries have no cosmetic or network side effects.
	for _, contact in ipairs(penetrations or {}) do
		if contact.Fraction <= nearest then hg.RecordShieldScar(contact) end
	end
	return result
end

-- Snapshot the plate once per damage event: recoil and subsequent body damage
-- cannot change protection halfway through the same explosion or fragment.
local blastBodySamples = {
	{"ValveBiped.Bip01_Head1", 0.15}, {"ValveBiped.Bip01_Spine2", 0.25},
	{"ValveBiped.Bip01_Spine1", 0.2}, {"ValveBiped.Bip01_Pelvis", 0.2},
	{"ValveBiped.Bip01_L_Forearm", 0.05}, {"ValveBiped.Bip01_R_Forearm", 0.05},
	{"ValveBiped.Bip01_L_Calf", 0.05}, {"ValveBiped.Bip01_R_Calf", 0.05},
}

function hg.GetShieldBlastPointMultiplier(protection, finish)
	local multiplier, blocked = 1, false
	for _, plate in ipairs(protection.plates) do
		local hit, _, fraction = util.IntersectRayWithOBB(protection.origin, finish - protection.origin,
			plate.pos, plate.ang, plate.mins, plate.maxs)
		if hit and fraction > 0 and fraction <= 1 then
			multiplier, blocked = math.min(multiplier, plate.residual), true
		end
	end
	return multiplier, blocked
end

function hg.GetShieldBlastMultiplier(ent, origin)
	if not IsValid(ent) or not origin or not next(hg.BallisticShields) then return 1 end
	local owner = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return 1 end
	local protection = {origin = origin, plates = {}}
	for shield in pairs(hg.BallisticShields) do
		if shieldMethodsAvailable(shield) then
			local holder = shield:GetOwner()
			if IsValid(holder) and holder:IsPlayer() and holder:Alive() then
				local character = hg.GetCurrentCharacter(holder)
				if IsValid(character) and util.DistanceToLine(origin, ent:GetPos(), character:GetPos()) < 128 then
					local pos, ang = shield:GetShieldTransform()
					if pos then
						protection.plates[#protection.plates + 1] = {shield = shield, pos = pos, ang = ang,
							mins = shield.ShieldMins, maxs = shield.ShieldMaxs, coverage = 0,
							residual = math.Clamp(shield.ShieldBlastDamageMultiplier or 0.04, 0.01, 1)}
					end
				end
			end
		end
	end
	local reduction, residual = 0, 1
	for _, sample in ipairs(blastBodySamples) do
		local bone = ent:LookupBone(sample[1])
		local matrix = bone and ent:GetBoneMatrix(bone)
		if matrix then
			local point, multiplier = matrix:GetTranslation(), 1
			for _, plate in ipairs(protection.plates) do
				local hit, _, fraction = util.IntersectRayWithOBB(origin, point - origin, plate.pos, plate.ang, plate.mins, plate.maxs)
				if hit and fraction > 0 and fraction <= 1 then
					multiplier = math.min(multiplier, plate.residual)
					residual = math.min(residual, plate.residual)
					plate.coverage = plate.coverage + sample[2]
				end
			end
			reduction = reduction + sample[2] * (1 - multiplier)
		end
	end
	-- Small exposed limbs must not restore near-full pressure to covered organs.
	-- Overlapping shields still use the best single residual, never a product.
	protection.multiplier = math.Clamp(math.max(residual, (1 - reduction) ^ 2), 0.01, 1)
	return protection.multiplier, protection
end

function hg.GetShieldFragmentProtection(ent, dmgInfo)
	if not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end
	local ammo = game.GetAmmoName(dmgInfo:GetAmmoType())
	if not ammo or (string.lower(ammo) ~= "metal debris" and string.lower(ammo) ~= "metal_debris") then return end
	local _, protection = hg.GetShieldBlastMultiplier(ent, dmgInfo:GetReportedPosition())
	return protection
end

function hg.ApplyShieldBlastDamage(ent, dmgInfo)
	if not dmgInfo:IsDamageType(DMG_BLAST) then return end
	-- RadiusDamage supplies the explosion origin here, including remote charges
	-- whose inflictor is a weapon held far away from the detonation.
	local multiplier, protection = hg.GetShieldBlastMultiplier(ent, dmgInfo:GetDamagePosition())
	if multiplier >= 1 then return end
	protection.damage = dmgInfo:GetDamage()
	if SERVER then
		for _, plate in ipairs(protection.plates) do
			if plate.coverage > 0 and isfunction(plate.shield.OnShieldExplosion) then
				plate.shield:OnShieldExplosion(protection.origin, protection.damage * plate.coverage, plate.pos)
			end
		end
	end
	dmgInfo:ScaleDamage(multiplier)
	dmgInfo:SetDamageForce(dmgInfo:GetDamageForce() * multiplier)
	return protection
end

function SWEP:OnShieldExplosion(origin, absorbed, pos)
	if not SERVER or absorbed <= 0 then return end
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end
	local power = math.Clamp(absorbed / 80, 0, 1.2)
	local previous = self.ShieldBlastEvent
	-- The same grenade can damage the holder, fake proxy and several teammates.
	if previous and CurTime() - previous.at < 0.15 and (previous.origin - origin):LengthSqr() < 16 then
		self:SetNWFloat("ShieldBlastPower", math.max(self:GetNWFloat("ShieldBlastPower", 0), power))
		return
	end
	self.ShieldBlastEvent = {at = CurTime(), origin = origin}
	self:SetNWFloat("ShieldBlastAt", CurTime())
	self:SetNWFloat("ShieldBlastPower", power)
	self:SetNWVector("ShieldBlastDirection", (pos - origin):GetNormalized())
	sound.Play("physics/metal/metal_barrel_impact_hard5.wav", pos, 80, math.random(75, 85), math.min(power, 1))
	if self:GetShieldCarryFraction() > 0 and self:InUse() then
		owner:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", 55, 90, math.min(power * 0.6, 0.7))
		owner:ViewPunch(Angle(-power * 0.8, 0, power * 0.3))
	end
end

-- One heavy catch, a short rebound and a damped metallic tremor. Analytic time
-- keeps the hand, collision plate and camera independent of FPS and tick rate.
function SWEP:GetShieldBlastMotion(eyeAng)
	local elapsed = CurTime() - self:GetNWFloat("ShieldBlastAt", -100000)
	if elapsed < 0 or elapsed >= 1.2 or not self:InUse() then
		return vector_origin, angle_zero, vector_origin, angle_zero
	end
	local owner = self:GetOwner()
	eyeAng = eyeAng or owner:EyeAngles()
	local power = math.Clamp(self:GetNWFloat("ShieldBlastPower", 0), 0, 1.2) * self:GetShieldCarryFraction()
	local direction = self:GetNWVector("ShieldBlastDirection", vector_origin)
	local forward, side = math.Clamp(direction:Dot(eyeAng:Forward()), -1, 1), math.Clamp(direction:Dot(eyeAng:Right()), -1, 1)
	local envelope = (1 - math.exp(-elapsed * 45)) * math.exp(-elapsed * 5) * (1 - elapsed / 1.2) * power
	local push = envelope * math.cos(elapsed * 11)
	local tremor = envelope * math.sin(elapsed * 48) * math.exp(-elapsed * 6)
	return Vector(forward * push * 2.6, side * push * 1.2, 0),
		Angle(-forward * push * 5, side * push * 3, side * push * 3 + tremor * 0.8),
		Vector(forward * push * 0.75, side * push * 0.35, -math.abs(push) * 0.12),
		Angle(-forward * push * 1.1, side * push * 0.35, side * push * 0.7 + tremor * 0.35)
end

-- Native weapon contact and eye-to-muzzle checks must see the virtual shield too.
-- Keep the original first solid hit and its fraction relative to the full trace.
function hg.ClipWeaponTraceToShield(weapon, trace, start, ammoType)
	if not trace or not trace.HitPos then return trace end
	start = start or trace.StartPos
	if not start then return trace end
	local owner = weapon:GetOwner()
	if not IsValid(owner) then return trace end
	local filter = {weapon, owner, hg.GetCurrentCharacter(owner)}
	local block = hg.TraceBallisticShields(start, trace.HitPos, ammoType, filter, ammoType == nil)
	if not block then return trace end
	block.Fraction = block.Fraction * (trace.Fraction or 1)
	return block
end

local weaponContactPadding = 0.5

-- Sweep hand/weapon volumes from the attacker, then resolve penetration against
-- the entry face. This constrains the final pose, after native animation lerps.
function hg.ResolveShieldWeaponContact(weapon, points, radius)
	if #points == 0 then return vector_origin end
	local owner = weapon:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return vector_origin end
	local character = hg.GetCurrentCharacter(owner)
	local eye = hg.eye(owner, 0, character)
	if not eye then return vector_origin end
	local approach = owner:GetAimVector()
	local obstacles = {}
	local padding = Vector(radius, radius, radius)
	for shield in pairs(hg.BallisticShields) do
		if shieldMethodsAvailable(shield) then
			local defender = shield:GetOwner()
			if IsValid(defender) and defender ~= owner and hg.GetCurrentCharacter(defender) ~= character
				and (defender:GetPos() - eye):LengthSqr() < 262144 then
				local pos, ang = shield:GetShieldTransform()
				if pos then obstacles[#obstacles + 1] = {pos, ang, shield.ShieldMins - padding, shield.ShieldMaxs + padding} end
			end
		end
	end
	local correction = Vector()
	for pass = 1, 2 do
		for _, obstacle in ipairs(obstacles) do
			local pos, ang, mins, maxs = obstacle[1], obstacle[2], obstacle[3], obstacle[4]
			for _, sample in ipairs(points) do
				local point = sample + correction
				-- Preserve a clear path around an edge or below the shield.
				local start = point - approach * (point - eye):Dot(approach)
				local hit, normal = util.IntersectRayWithOBB(start, point - start, pos, ang, mins, maxs)
				if hit then
					if not normal or normal:LengthSqr() < 0.001 then
						-- Keep a hand on the attacker's side when the sweep starts inside the volume.
						local side = (start - pos):Dot(ang:Forward()) >= 0 and 1 or -1
						normal = ang:Forward() * side
						hit = pos + ang:Forward() * (side == 1 and maxs.x or mins.x)
					end
					local depth = (hit - point):Dot(normal) + 0.05
					if depth > 0 then correction = correction + normal * depth end
				end
			end
		end
	end
	return correction
end

function hg.ShieldFirearmContact(weapon, modelPos, modelAng, handPos, handAng)
	if not weapon.LocalMuzzlePos then return modelPos, handPos end
	local muzzle = LocalToWorld(weapon.LocalMuzzlePos, weapon.LocalMuzzleAng or angle_zero, modelPos, modelAng)
	local points = {}
	local segments = math.Clamp(math.ceil((muzzle - handPos):Length() / 6), 1, 32)
	for i = 0, segments do points[#points + 1] = LerpVector(i / segments, handPos, muzzle) end
	local wrist = handPos - handAng:Up()
	points[#points + 1] = LocalToWorld(weapon.RHPosOffset or vector_origin, angle_zero, wrist, handAng)
	if weapon.LHPos and weapon.setlhik ~= false and not hg.GetShieldCompanion(weapon) then
		local leftAng = Angle(handAng.p, handAng.y, handAng.r)
		leftAng:RotateAroundAxis(leftAng:Forward(), -90)
		local leftPos, gripAng = LocalToWorld(weapon.LHPos, weapon.LHAng or angle_zero, wrist, leftAng)
		points[#points + 1] = LocalToWorld(weapon.LHPosOffset or vector_origin, angle_zero, leftPos, gripAng)
	end
	local correction = hg.ResolveShieldWeaponContact(weapon, points, weaponContactPadding)
	return modelPos + correction, handPos + correction
end

-- Stop the actual swing before damage, wounds, decals or victim impulses run.
-- The segment ends at its first solid hit, so walls and exposed limbs still win.
function hg.InterceptShieldMelee(weapon, trace, start, filter)
	if not trace then return end
	local attacker = weapon:GetOwner()
	-- A victim already in the swing's HitEnts still carries a solid shield.
	-- Ignore only the attacker's own equipment, not previously struck defenders.
	if IsValid(attacker) then filter = {weapon, attacker, hg.GetCurrentCharacter(attacker)} end
	local block = hg.TraceBallisticShields(start or trace.StartPos, trace.HitPos, nil, filter, true)
	if not block then return trace end
	if weapon.SetInAttack then weapon:SetInAttack(false) end
	if SERVER then
		hg.BallisticShieldImpact(block)
		local owner = weapon:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then owner:ViewPunch(Angle(-1, 0, 0.4)) end
	end
end

function hg.BallisticShieldImpact(trace)
	if not SERVER then return end
	if hg.RecordShieldScar then hg.RecordShieldScar(trace) end
	if hg.BallisticShieldFeedback then hg.BallisticShieldFeedback(trace) end
end

-- One contact, with the usual melee body step and spring-camera impact.
function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	local owner = self:GetOwner()
	if not self:InUse() or not owner.organism or not owner.organism.stamina then return end
	self:UpdateShieldCarry()
	if self:IsShieldCarryBusy() or self:GetShieldCarryFraction() < 1 then return end
	local active = owner:GetActiveWeapon()
	if active ~= self then return end
	if self:GetInAttack() or self:GetNextPrimaryFire() > CurTime() then return end
	local fatigue = math.Clamp((180 - owner.organism.stamina[1]) / 90, 1, 2)
	self:SetAttackType(1)
	self:SetLastAttack(CurTime() + self.AttackTime * fatigue)
	self:SetAttackTime(self:GetLastAttack() + self.AttackTimeLength * fatigue)
	self:SetAttackLength(self.AttackLen1)
	self:SetAttackWait(self.WaitTime1 * fatigue)
	self:SetNextPrimaryFire(CurTime() + self.WaitTime1 * fatigue)
	self.ShieldBashHit = false
	self.ShieldBashStepTime = CurTime()
	self.attackedOnce = false
	self.HitEnts = {owner, hg.GetCurrentCharacter(owner)}
	self:SetInAttack(true)
	if SERVER then
		owner.organism.stamina.subadd = owner.organism.stamina.subadd + self.StaminaPrimary * 0.5
		owner:EmitSound(self.DeploySnd, 45, math.random(90, 100))
	end
end

function SWEP:StepShieldBash(owner)
	if not SERVER then return end
	local now = CurTime()
	local previous = math.max(self.ShieldBashStepTime or now, now - 0.05)
	self.ShieldBashStepTime = now
	if hg.GetCurrentCharacter(owner) ~= owner or not owner:OnGround() or owner:InVehicle()
		or owner:GetMoveType() ~= MOVETYPE_WALK then return end
	local scale = math.max((self:GetAttackTime() - self:GetLastAttack()) / self.AttackTimeLength, 0.1)
	local elapsed = math.max(0, math.min(now, self:GetLastAttack() + 0.11 * scale)
		- math.max(previous, self:GetLastAttack() - 0.14 * scale))
	if elapsed == 0 then return end
	local aim = owner:GetAimVector()
	local direction = Vector(aim.x, aim.y, 0):GetNormalized()
	local speed = owner:GetVelocity():Dot(direction)
	-- SetVelocity adds velocity to players, as in weapon_melee/weapon_ram.
	-- Integrate in seconds so the step does not depend on the server tick rate.
	local impulse = math.min(650 * elapsed / scale, math.max(190 - speed, 0))
	if impulse > 0 then owner:SetVelocity(direction * impulse) end
end

function SWEP:Think()
	if not self:GetInAttack() then return end
	local owner = self:GetOwner()
	if not self:InUse() or owner:GetActiveWeapon() ~= self then self:SetInAttack(false) return end
	if CurTime() > self:GetAttackTime() then self:SetInAttack(false) return end
	self:StepShieldBash(owner)
	if SERVER and not self.ShieldBashHit and CurTime() >= self:GetLastAttack() then
		self.ShieldBashHit = true
		owner:EmitSound(self.AttackSwing, 50, math.random(90, 100))
		owner:LagCompensation(true)
		local trace = self:Attack(owner, hg.GetCurrentCharacter(owner))
		owner:LagCompensation(false)
		owner:ViewPunch(self.ViewPunch1 * (trace and trace.Hit and 1 or 0.55))
		self:ApplyShieldBash(trace)
	end
	if CurTime() >= self:GetAttackTime() then self:SetInAttack(false) end
end

function SWEP:ApplyShieldBash(trace)
	if not trace or not trace.Hit then return end
	local target = trace.Entity
	local soft = IsValid(target) and self:IsEntSoft(target)
	sound.Play(soft and self.AttackHitFlesh or self.AttackHit, trace.HitPos, 65, math.random(95, 105))
	if not IsValid(target) or target:IsWorld() then return end
	local owner = self:GetOwner()
	local character = hg.GetCurrentCharacter(owner)
	local mul = self:MultiplyDMG(owner, character, character:GetVelocity():Length(), 1)
	local damage = math.random(self.DamagePrimary - 3, self.DamagePrimary + 3) * mul / (soft and 1.5 or 6)
	self.Penetration, self.PenetrationSize = self.PenetrationPrimary, self.PenetrationSizePrimary
	local info = DamageInfo()
	info:SetAttacker(owner)
	info:SetInflictor(self)
	info:SetDamageType(DMG_CLUB)
	info:SetDamage(damage)
	info:SetDamageForce(trace.Normal * damage)
	info:SetDamagePosition(trace.HitPos)
	target:TakeDamageInfo(info)
	self.attackedOnce = true
	local force = trace.Normal * math.min(damage, 20) * 220
	if target:IsPlayer() or target:IsRagdoll() then
		hg.AddForceRag(target, trace.PhysicsBone or 0, force, 0.2)
		local victim = target:IsPlayer() and target or hg.RagdollOwner(target)
		if IsValid(victim) and victim:IsPlayer() then
			victim:ViewPunch(Angle(-1.5, 0, 0))
			if target:IsPlayer() and victim:OnGround() then
				local direction = Vector(trace.Normal.x, trace.Normal.y, 0):GetNormalized()
				victim:SetVelocity(direction * math.min(100 + damage * 3, 160) + Vector(0, 0, 8))
			end
		end
	end
	local phys = target:GetPhysicsObjectNum(trace.PhysicsBone or 0)
	if IsValid(phys) then phys:ApplyForceOffset(force, trace.HitPos) end
end

function SWEP:Attack(owner, ent, vellen, attacktype, inattackLength)
	if CurrentRound and (CurrentRound().time_without_shooting or 0) + (zb.ROUND_START or 0) > CurTime() then return end
	self.HitEnts = self.HitEnts or {owner, ent}
	local start = hg.eye(owner, 0, ent)
	if not start then return end
	local shieldPos, shieldAng = self:GetShieldTransform()
	if not shieldPos then return end
	local relative = shieldPos - start
	local aim = owner:GetAimVector()
	-- Start at the body, at the fitted shield's height/side, so a protruding shield
	-- cannot attack through a wall. Follow the actual face, with a capped reach.
	start = start + relative - aim * relative:Dot(aim)
	local reach = shieldPos + shieldAng:Forward() * 4 - start
	local finish = start + reach:GetNormalized() * math.min(reach:Length(), self:GetAttackLength())
	local trace = util.TraceHull({start = start, endpos = finish,
		mins = Vector(-6, -6, -6), maxs = Vector(6, 6, 6), filter = self.HitEnts, mask = MASK_SHOT_HULL})
	return hg.InterceptShieldMelee(self, trace, start, self.HitEnts)
end

if CLIENT then
	function hg.ShieldMeleeContact(weapon, model)
		if not IsValid(model) or weapon:GetClass() == shieldClass then return end
		local points, matrices = {}, {}
		local exchange = weapon.worldModel2
		local replaced = weapon.WorldModelExchange and IsValid(exchange)
		for i = 0, model:GetBoneCount() - 1 do
			local matrix = model:GetBoneMatrix(i)
			if matrix then
				matrices[i] = matrix
				local name = string.lower(model:GetBoneName(i))
				local right = weapon.setrh ~= false and (string.find(name, "_r_hand", 1, true) or string.find(name, "_r_finger", 1, true))
				local left = weapon.setlh ~= false and (string.find(name, "_l_hand", 1, true) or string.find(name, "_l_finger", 1, true))
				-- The replacement is the visible weapon; its hidden animation rig must not collide.
				if name ~= "__invalidbone__" and (right or left or (not replaced and not string.find(name, "valvebiped.", 1, true))) then
					points[#points + 1] = matrix:GetTranslation()
				end
			end
		end
		if replaced then
			local base = matrices[weapon.basebone or 1]
			local origin, orientation = LocalToWorld(weapon.weaponPos or vector_origin, weapon.weaponAng or angle_zero,
				base and base:GetTranslation() or model:GetPos(), base and base:GetAngles() or model:GetAngles())
			-- Compiled animation bounds can extend far beyond the visible weapon.
			local mins, maxs = exchange:GetModelRenderBounds()
			if (maxs - mins):LengthSqr() < 0.001 then mins, maxs = exchange:GetModelBounds() end
			local scale = weapon.modelscale or 1
			local size = maxs - mins
			local axis = size.x >= size.y and size.x >= size.z and "x" or (size.y >= size.z and "y" or "z")
			local segments = math.Clamp(math.ceil(size[axis] * scale / 6), 1, 32)
			for i = 0, segments do
				local point = (mins + maxs) * 0.5
				point[axis] = mins[axis] + size[axis] * i / segments
				points[#points + 1] = LocalToWorld(point * scale, angle_zero, origin, orientation)
			end
			for _, x in ipairs({mins.x, maxs.x}) do
				for _, y in ipairs({mins.y, maxs.y}) do
					for _, z in ipairs({mins.z, maxs.z}) do
						points[#points + 1] = LocalToWorld(Vector(x, y, z) * scale, angle_zero, origin, orientation)
					end
				end
			end
		end
		local correction = hg.ResolveShieldWeaponContact(weapon, points, weaponContactPadding)
		if correction:LengthSqr() < 0.000001 then return end
		local pos = model:GetPos() + correction
		model:SetPos(pos)
		model:SetRenderOrigin(pos)
		-- Move the animated weapon and both grips rigidly before copying its hands.
		for i, matrix in pairs(matrices) do
			matrix:SetTranslation(matrix:GetTranslation() + correction)
			model:SetBoneMatrix(i, matrix)
		end
	end

	function hg.ShieldFistsContact(ent, weapon)
		if not IsValid(weapon) or not weapon.GetFists or not weapon:GetFists() then return end
		for _, hand in ipairs({{weapon.rhandik, hg.TPIKBonesRH}, {weapon.lhandik, hg.TPIKBonesLH}}) do
			if hand[1] and hand[2] then
				local points, matrices = {}, {}
				for _, name in ipairs(hand[2]) do
					local index = ent:LookupBone(name)
					local matrix = index and ent:GetBoneMatrix(index)
					if matrix then
						points[#points + 1] = matrix:GetTranslation()
						matrices[index] = matrix
					end
				end
				local correction = hg.ResolveShieldWeaponContact(weapon, points, 3)
				if correction:LengthSqr() > 0.000001 then
					for index, matrix in pairs(matrices) do
						matrix:SetTranslation(matrix:GetTranslation() + correction)
						ent:SetBoneMatrix(index, matrix)
					end
				end
			end
		end
	end

	function SWEP:Camera(eyePos, eyeAng, view, vellen)
		local owner = self:GetOwner()
		if not self:InUse() or owner:GetActiveWeapon() ~= self then
			self.OldAngPunch = nil
			return view
		end
		-- The same hand-bone spring ViewPunch and aim/movement inertia as weapon_ram.
		self.ShieldCameraUpdating = true
		view = self.BaseClass.Camera(self, eyePos, eyeAng, view, vellen) or view
		self.ShieldCameraUpdating = nil
		return self:ShieldCameraLean(eyePos, eyeAng, view)
	end

	function SWEP:ShieldCameraLean(eyePos, eyeAng, view)
		local owner = self:GetOwner()
		local _, _, lean = self:GetShieldBashMotion()
		local _, _, blastLean, blastAngle = self:GetShieldBlastMotion(eyeAng)
		lean = lean + blastLean
		if blastAngle.p ~= 0 or blastAngle.y ~= 0 or blastAngle.r ~= 0 then
			view.angles = (view.angles or eyeAng) + blastAngle
		end
		if lean:LengthSqr() > 0.0001 then
			local desired = LocalToWorld(lean, angle_zero, view.origin, eyeAng)
			local trace = util.TraceHull({start = eyePos, endpos = desired,
				mins = Vector(-1.5, -1.5, -1.5), maxs = Vector(1.5, 1.5, 1.5),
				filter = {owner, hg.GetCurrentCharacter(owner)}, mask = MASK_SOLID})
			view.origin = trace.HitPos
		end
		return view
	end

	function SWEP:PoseShield(pos, ang)
		local model = self:GetWM()
		if not IsValid(model) then return end
		if not model.ShieldBoundsSet then
			model:SetRenderBounds(Vector(-48, -48, -48), Vector(48, 48, 48))
			model.ShieldBoundsSet = true
		end
		-- The mesh and grip bones are posed together, relative to the shield bone.
		model:ResetSequence(model:LookupSequence("idle"))
		model:SetCycle(0)
		model:SetPos(pos)
		model:SetAngles(ang)
		model:SetRenderOrigin(pos)
		model:SetRenderAngles(ang)
		model:InvalidateBoneCache()
		model:SetupBones()
		local bone = model:LookupBone("shield")
		local matrix = bone and model:GetBoneMatrix(bone)
		if not matrix then return end
		local target = Matrix()
		target:SetTranslation(pos)
		target:SetAngles(ang)
		local transform = target * matrix:GetInverse()
		for i = 0, model:GetBoneCount() - 1 do
			local mat = model:GetBoneMatrix(i)
			if mat and model:GetBoneName(i) ~= "__INVALIDBONE__" then model:SetBoneMatrix(i, transform * mat) end
		end
		return model
	end

	local function shieldRenderPass()
		local target = render.GetRenderTarget() -- The main framebuffer can return zero values.
		return tostring(target) .. ":" .. tostring(RENDERING_SCOPE or false)
			.. ":" .. tostring(EyePos()) .. ":" .. tostring(EyeAngles())
	end

	function SWEP:DrawShield(pos, ang)
		local pass = not self.ShieldCameraUpdating and shieldRenderPass()
		if pass and self.ShieldLastDrawFrame == FrameNumber() and self.ShieldDrawPasses and self.ShieldDrawPasses[pass] then return end
		local model = self:PoseShield(pos, ang)
		if IsValid(model) then
			model:DrawModel()
			if not pass then return end -- CalcView only prepares the camera/hand pose.
			if hg.DrawShieldScars then
				-- Read back the bone used by the native draw, including rebuilds/LOD.
				local bone = model:LookupBone("shield")
				local matrix = bone and model:GetBoneMatrix(bone)
				hg.DrawShieldScars(self, model, matrix and matrix:GetTranslation() or pos, matrix and matrix:GetAngles() or ang)
			end
			if self.ShieldLastDrawFrame ~= FrameNumber() then self.ShieldDrawPasses = {} end
			self.ShieldLastDrawFrame = FrameNumber()
			self.ShieldDrawPasses = self.ShieldDrawPasses or {}
			self.ShieldDrawPasses[pass] = true
		end
	end

	function SWEP:SetHandPos(companion)
		self.rhandik, self.lhandik = false, false
		local owner = self:GetOwner()
		if not self:InUse() then return end
		local pos, ang = self:GetShieldTransform()
		if not pos or (owner:GetActiveWeapon() ~= self and not companion) then return end
		local ent = hg.GetCurrentCharacter(owner)
		local model = self:PoseShield(pos, ang)
		if not IsValid(model) then return end
		-- Pose before MainTPIKFunction solves the elbows, rather than using last frame's WM.
		local phase = self:GetShieldCarryFraction()
		local leftWeight = smoothCarry(phase / 0.18)
		local rightWeight = companion and 0 or smoothCarry((phase - 0.70) / 0.25)
		local function copyHand(bones, hand, weight)
			if weight <= 0 then return false end
			local index = ent:LookupBone(hand)
			local original = index and ent:GetBoneMatrix(index)
			if not original then return false end
			local modelHand = model:LookupBone(hand)
			if not modelHand or not model:GetBoneMatrix(modelHand) then return false end
			if hand == "ValveBiped.Bip01_L_Hand" then owner.lhold = original else owner.rhold = original end
			for _, name in ipairs(bones) do
				local targetBone, sourceBone = ent:LookupBone(name), model:LookupBone(name)
				local target = targetBone and ent:GetBoneMatrix(targetBone)
				local source = sourceBone and model:GetBoneMatrix(sourceBone)
				if target and source and ent:GetBoneName(targetBone) ~= "__INVALIDBONE__" then
					local reach = hand == "ValveBiped.Bip01_L_Hand" and phase < 0.18 and math.sin(math.pi * weight) * 7 or 0
					target:SetTranslation(LerpVector(weight, target:GetTranslation(), source:GetTranslation())
						- Angle(0, owner:EyeAngles().y, 0):Right() * reach)
					target:SetAngles(carryAngle(weight, target:GetAngles(), source:GetAngles()))
					ent:SetBoneMatrix(targetBone, target)
				end
			end
			return true
		end
		self.lhandik = copyHand(hg.TPIKBonesLH, "ValveBiped.Bip01_L_Hand", leftWeight)
		if not companion then self.rhandik = copyHand(hg.TPIKBonesRH, "ValveBiped.Bip01_R_Hand", rightWeight) end
	end

	function hg.ApplyOffhandShieldHands(owner, weapon)
		if not IsValid(weapon) then return end
		local shield = hg.GetPlayerBallisticShield(owner)
		if not shieldMethodsAvailable(shield) or weapon == shield then return end
		if not hg.GetShieldCompanion(weapon) and not shield:IsShieldCarryBusy() then return end
		shield:SetHandPos(true)
		if shield.lhandik then weapon.lhandik = true end
	end

	function hg.DrawOffhandShield(weapon)
		local shield = hg.GetCarriedShield(weapon)
		if not shield then return end
		local pos, ang = shield:GetShieldTransform()
		if pos then shield:DrawShield(pos, ang) end
	end

	function SWEP:DrawWorldModel2()
		local owner = self:GetOwner()
		if not IsValid(owner) then
			self:DrawModel()
			local bone = self:LookupBone("shield")
			local matrix = bone and self:GetBoneMatrix(bone)
			if matrix and hg.DrawShieldScars then hg.DrawShieldScars(self, self, matrix:GetTranslation(), matrix:GetAngles()) end
			return
		end
		if owner:GetActiveWeapon() ~= self then return end
		local pos, ang = self:GetShieldTransform()
		if pos then self:DrawShield(pos, ang) end
	end

	local function drawPlayerShield(ply)
		local shield = hg.GetPlayerBallisticShield(ply)
		if not shield then return end
		local pass = shieldRenderPass()
		if shield.ShieldLastDrawFrame == FrameNumber() and shield.ShieldDrawPasses and shield.ShieldDrawPasses[pass] then return end
		local character = hg.GetCurrentCharacter(ply)
		if not IsValid(character) or character:IsDormant() or character:GetNoDraw() then return end
		if not isfunction(shield.DrawShield) then return end
		local pos, ang = shield:GetShieldTransform()
		if pos then shield:DrawShield(pos, ang) end
	end

	-- The native melee DrawWorldModel draws only NPCs/dropped items. Its Camera
	-- path exists only for the local owner, so observers need an explicit route.
	function SWEP:DrawWorldModel()
		local owner = self:GetOwner()
		if not IsValid(owner) then self:DrawWorldModel2() return end
		if owner:IsPlayer() then drawPlayerShield(owner)
		elseif isfunction(self.BaseClass.DrawWorldModel) then self.BaseClass.DrawWorldModel(self) end
	end

	hook.Add("PostPlayerDraw", "hg_shield_back", drawPlayerShield)
	-- Z-City replaces player rendering and can skip PostPlayerDraw entirely.
	-- Do this after opaque actors so their bones are ready; no inventory-only lookup.
	hook.Add("PostDrawOpaqueRenderables", "hg_shield_visible", function(depth, skybox)
		if depth or skybox then return end
		for _, ply in player.Iterator() do drawPlayerShield(ply) end
	end)
	hook.Add("PostDrawTranslucentRenderables", "hg_shield_back_fake", function(depth, skybox)
		if depth or skybox then return end
		for _, ply in player.Iterator() do
			if hg.GetCurrentCharacter(ply) ~= ply then drawPlayerShield(ply) end
		end
	end)
end
