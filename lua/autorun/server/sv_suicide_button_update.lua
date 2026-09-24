-- Suicide key update for Chudmorse (server-only drop-in).
--
-- Put this file in:  addons/chudmorse-main/lua/autorun/server/   and restart the server.
--
--   * the `suicide` key raises the weapon step by step, even at low depression
--   * once it's fully up (a gun), it locks there instead of firing on its own -
--     you pull the trigger yourself with your normal fire button
--   * shows the "i-i cant.. i wont.. please.." lines while you do it
--   * also fixes the console error from sv_phrases.lua (AssignPainScreamFolder: 'folders' is nil)
--
-- Use this INSTEAD of suicide_button_update.zip, not together with it.

if not SERVER then return end

hg = hg or {}

----------------------------------------------------------------------
-- helpers (same logic as the local ones inside Chudmorse's sv_suicideurges.lua)
----------------------------------------------------------------------
local function findSuicideWeapon(ply)
	local firearm

	for _, wep in ipairs(ply:GetWeapons()) do
		if IsValid(wep) and wep.CanSuicide then
			if wep.ismelee2 or wep.Base == "weapon_melee" then return wep end
			if ishgweapon(wep) and not firearm then firearm = wep end
		end
	end

	return firearm
end

local function hasSuicideWeapon(ply)
	return IsValid(findSuicideWeapon(ply))
end

local function autoEquipSuicideWeapon(ply)
	local wep = ply.GetActiveWeapon and ply:GetActiveWeapon()
	if IsValid(wep) and wep.CanSuicide then return true end

	local found = findSuicideWeapon(ply)
	if not IsValid(found) then return false end

	ply:SelectWeapon(found:GetClass())
	if ply.SetActiveWeapon then ply:SetActiveWeapon(found) end

	return true
end

local function doUrgeCut(ply)
	if not hasSuicideWeapon(ply) then return end

	local org = ply.organism
	if not org or not org.alive then return end

	local wep = ply.GetActiveWeapon and ply:GetActiveWeapon()
	if IsValid(wep) and wep.SuicideFunc then
		wep:SuicideFunc()
		return
	end

	if IsValid(wep) and ishgweapon(wep) and not (wep.ismelee2 or wep.Base == "weapon_melee") and wep:Clip1() > 0 then
		local oldStart = ply.startsuicide
		ply.startsuicide = CurTime() - 2
		ply.suiciding = true
		ply.remUrgeFiring = true
		wep:PrimaryAttack(true)
		ply.remUrgeFiring = nil
		ply.suiciding = false
		ply.startsuicide = oldStart
		return
	end

	local ent = hg.GetCurrentCharacter(ply)
	if not IsValid(ent) then return end

	local neck = ent:LookupBone("ValveBiped.Bip01_Neck1")
	if not neck then return end

	local matrix = ent:GetBoneMatrix(neck)
	if not matrix then return end

	local dmgInfo = DamageInfo()
	dmgInfo:SetAttacker(ply)
	if IsValid(wep) then dmgInfo:SetInflictor(wep) end
	dmgInfo:SetDamageType(DMG_SLASH)

	local ang = matrix:GetAngles()
	local _, cutAng = LocalToWorld(vector_origin, Angle(0, -60, 0), vector_origin, ang)

	hg.organism.input_list["arteria"](org, 0, 5, dmgInfo, nil, -cutAng:Forward())

	for i = 1, 5 do
		hg.organism.AddWoundManual(ply, 50, VectorRand(-2, 2), cutAng, "ValveBiped.Bip01_Neck1", CurTime() + math.Rand(0, 2))
	end

	ply:AddNaturalAdrenaline(math.max(2 - (org.adrenaline or 0), 0))
	org.fear = math.max(org.fear, 1)

	hook.Run("HomigradDamage", ply, dmgInfo, HITGROUP_HEAD, ent, 15)

	if IsValid(wep) then
		ply:EmitSound(wep.SuicideSound or wep.Attack2HitFlesh or wep.AttackHitFlesh, 50)
	end
end

----------------------------------------------------------------------
-- the key: each press raises the weapon one step
----------------------------------------------------------------------
local aim_step = 0.125
local aim_hold_window = 0.5
local aim_raise_time = 5
local aim_decay_speed = 0.3

local aim_phrases = {
	"no-no.. i dont want to do this..",
	"stop.. please.. dont make me..",
	"i-i cant.. i wont.. please..",
	"no-no no.. someone help me..",
	"dont... i dont want to die..",
	"not now.. please, not now..",
}

local function resetAim(ply)
	ply.hgSuicideAim = 0
	ply.hgSuicideLocked = false
	ply.suiciding = false
	ply:SetNWFloat("rem_suicide_aim", 0)
	ply:SetNWFloat("willsuicide", 0)
end

-- the text from the clip, one line every 2-4 seconds while aiming
local function aimPhrase(ply)
	-- keep the depression module's own "CUT IT.." lines quiet while aiming
	local org = ply.organism
	if org then org.depressionNextMinigamePhrase = CurTime() + 1 end

	if (ply.hgAimPhraseNext or 0) < CurTime() then
		ply.hgAimPhraseNext = CurTime() + math.Rand(2, 4)
		ply:Notify(table.Random(aim_phrases), 3, "depression_suicide_aim", 0)
	end
end

function hg.PressSuicideAim(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if not ply:Alive() then return end
	if not hasSuicideWeapon(ply) then return end
	if ply.remUrgeEnd or ply.selfharming then return end

	autoEquipSuicideWeapon(ply)

	local wep = ply.GetActiveWeapon and ply:GetActiveWeapon()
	local isMelee = IsValid(wep) and (wep.ismelee2 or wep.Base == "weapon_melee")

	ply.hgSuicideAim = math.min((ply.hgSuicideAim or 0) + aim_step, 1)
	ply.hgSuicideLastPress = CurTime()

	if ply.hgSuicideAim >= 1 and isMelee then
		ply.suiciding = true

		doUrgeCut(ply)

		ply.hgSuicideAim = 0
		ply.suiciding = false
		ply:SetNWFloat("willsuicide", 0)
		ply:SetNWFloat("rem_suicide_aim", 0)

		return
	end

	ply.suiciding = true

	if ply.hgSuicideAim >= 1 then
		-- fully raised: lock here, no auto-fire. the player has to pull the trigger themselves.
		ply.hgSuicideLocked = true
		ply:SetNWFloat("willsuicide", 0)
	else
		ply.hgSuicideLocked = false
		ply:SetNWFloat("willsuicide", CurTime() + (1 - ply.hgSuicideAim) * aim_raise_time)
	end
	ply:SetNWFloat("rem_suicide_aim", ply.hgSuicideAim)
end

hook.Add("Player Think", "REM_SuicideAimThink", function(ply)
	local aim = ply.hgSuicideAim or 0
	if aim <= 0 then
		ply.hgAimPhraseNext = nil
		return
	end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or not wep.CanSuicide then
		resetAim(ply)
		return
	end

	local isMelee = wep.ismelee2 or wep.Base == "weapon_melee"

	if aim < 1 then
		if (ply.hgSuicideLastPress or 0) + aim_hold_window < CurTime() then
			aim = math.max(aim - FrameTime() * aim_decay_speed, 0)
		end

		if aim <= 0 then
			resetAim(ply)
			return
		end

		ply.hgSuicideAim = aim
		ply.hgSuicideLocked = false
		ply.suiciding = true

		if isMelee then
			ply:SetNWFloat("willsuicide", 0)
		else
			ply:SetNWFloat("willsuicide", CurTime() + (1 - aim) * aim_raise_time)
		end
		ply:SetNWFloat("rem_suicide_aim", aim)

		aimPhrase(ply)
		return
	end

	-- melee resolves itself the moment it hits full aim (see PressSuicideAim); this is just a safety net
	if isMelee then
		ply.hgSuicideAim = 0
		ply.hgSuicideLocked = false
		ply.suiciding = false
		ply:SetNWFloat("rem_suicide_aim", 0)
		return
	end

	-- fully raised firearm: stays locked here, no timer, until the player fires it or switches away
	aimPhrase(ply)
end)

hook.Add("PlayerDeath", "REM_SuicideAim_Cleanup", function(ply)
	ply.hgAimPhraseNext = nil

	if (ply.hgSuicideAim or 0) <= 0 and ply:GetNWFloat("willsuicide", 0) <= 0 then return end

	resetAim(ply)
end)

-- can't fire normally while the weapon is still being raised; firing once locked ends the aim state
local function gateWeapon(wep)
	if not IsValid(wep) or wep.remAimGated or not isfunction(wep.CanPrimaryAttack) then return end
	wep.remAimGated = true

	local origCan = wep.CanPrimaryAttack
	wep.CanPrimaryAttack = function(self, ...)
		local owner = self:GetOwner()
		if IsValid(owner) and owner.suiciding
			and (owner.hgSuicideAim or 0) > 0
			and not owner.hgSuicideLocked then
			return false
		end

		return origCan(self, ...)
	end

	if isfunction(wep.PrimaryAttack) then
		local origFire = wep.PrimaryAttack
		wep.PrimaryAttack = function(self, ...)
			local owner = self:GetOwner()
			local firingLocked = IsValid(owner) and owner.suiciding and owner.hgSuicideLocked
			local ret = origFire(self, ...)
			if firingLocked then resetAim(owner) end
			return ret
		end
	end
end

hook.Add("WeaponEquip", "REM_SuicideAimGate", function(wep)
	timer.Simple(0, function() gateWeapon(wep) end)
end)

for _, ply in ipairs(player.GetAll()) do
	for _, wep in ipairs(ply:GetWeapons()) do gateWeapon(wep) end
end

-- the `suicide` console command (Chudmorse's own one refuses below 0.5 depression)
local function installCommand()
	concommand.Add("suicide", function(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if ply:GetNWFloat("rem_urges_end", 0) > CurTime() then return end
		if ply.remUrgeEnd then return end

		if ply.organism and (ply.organism.depression or 0) < 0.5 then
			hg.PressSuicideAim(ply)
			return
		end

		if not ply.suiciding then
			if hg.StartSuicideUrge then hg.StartSuicideUrge(ply) end
		else
			ply.suiciding = false
		end
	end)
end

installCommand()
hook.Add("InitPostEntity", "REM_SuicideAimCommand", installCommand)

----------------------------------------------------------------------
-- console error fix: sv_phrases.lua "attempt to get length of local 'folders' (a nil value)"
----------------------------------------------------------------------
if hg.AssignPainScreamFolder then
	local painScreamFolders = {
		[false] = { "male1", "male2" },
		[true] = { "female1", "female2" },
	}

	function hg.AssignPainScreamFolder(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end

		local female = ThatPlyIsFemale(ply)

		if ply.painScreamFolder and ply.painScreamFolderFemale == female then
			return ply.painScreamFolder
		end

		local folders = painScreamFolders[female] or painScreamFolders[false]
		ply.painScreamFolderFemale = female
		ply.painScreamFolder = folders[math.random(#folders)]

		return ply.painScreamFolder
	end
end

MsgN("[Chudmorse] suicide key update loaded")
