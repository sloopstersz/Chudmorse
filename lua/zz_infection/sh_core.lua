ZZInfection = ZZInfection or {}
local Z = ZZInfection
Z.Durations = {30, 90, 25, 15}
Z.Chances = {shambler = 25, runner = 5, heavy = 10}

function Z.Active()
    local mode = CurrentRound and CurrentRound()
    return mode and mode.name == "zzombies" and zb.ROUND_STATE == 1
end

function Z.StageAt(elapsed)
    local boundary = 0
    for stage, duration in ipairs(Z.Durations) do
        boundary = boundary + duration
        if elapsed < boundary then return stage end
    end
    return 5
end

function Z.ConsumeDuration(count)
    return 15 - math.min(math.max(count - 1, 0) * 5, 10)
end

function Z.Human(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() then return ent end
    if hg and hg.RagdollOwner then return hg.RagdollOwner(ent) end
end

function Z.BiteOnly(ply)
    return IsValid(ply) and Z.Active() and ZZIsZombie(ply) and ply:GetNWString("ZZZombieClass", "") == "shambler"
        and ply:GetNWBool("ZZFirstInfected", false) == true
end

function Z.CanBite(ply)
    return IsValid(ply) and Z.Active() and ZZIsZombie(ply)
        and (Z.BiteOnly(ply) or ply:GetNWString("ZZZombieClass", "") == "shambler")
end

-- Called by the normal hands attack before it starts a claw swing.
function Z.Bite(weapon)
    local ply = weapon:GetOwner()
    if not Z.CanBite(ply) or (not Z.BiteOnly(ply) and not ply:KeyDown(IN_RELOAD)) then return false end
    if not ply:Alive() or ply:InVehicle() or ply:GetNetVar("handcuffed", false) then return true end
    if not IsFirstTimePredicted() then return true end
    if IsValid(ply.FakeRagdoll) or (weapon.attacked or 0) > CurTime() then return true end
    weapon.attacked = CurTime() + 1.5
    weapon:SetNextPrimaryFire(weapon.attacked)
    weapon:SetNextSecondaryFire(weapon.attacked)
    if CLIENT then return true end
    ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND)
    ply:LagCompensation(true)
    local tr = util.TraceHull({start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 60,
        mins = Vector(-5, -5, -5), maxs = Vector(5, 5, 5), filter = ply, mask = MASK_SHOT})
    ply:LagCompensation(false)
    if IsValid(tr.Entity) then
        local damage = DamageInfo()
        damage:SetAttacker(ply)
        damage:SetInflictor(weapon)
        damage:SetDamage((ZZGetZombieClass(ply) or {}).damage or 10)
        damage:SetDamageType(DMG_CLUB)
        damage:SetDamageForce(vector_origin)
        damage:SetDamagePosition(tr.HitPos)
        tr.Entity:TakeDamageInfo(damage)
        hook.Run("ZZZombieMeleeHit", ply, tr.Entity)
        ply:EmitSound("npc/zombie/claw_strike1.wav", 65, 90)
    else
        ply:EmitSound("npc/zombie/claw_miss1.wav", 60, 90)
    end
    return true
end

-- Use authoritative elapsed infection time, including the boundary between symptom ticks.
function Z.InfectedSurvivorStage(ply)
    if not Z.Active() or not IsValid(ply) or not ply:IsPlayer()
        or ply:Team() == TEAM_SPECTATOR or ply.ZZ_Extracted
        or (ZZIsZombie and ZZIsZombie(ply)) then return 0 end
    local state = ply.ZZInfectionState
    if not state or state.cured or not state.started then return 0 end
    return Z.StageAt(math.max(CurTime() - state.started, 0))
end
