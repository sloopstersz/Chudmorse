local Z = ZZInfection
util.AddNetworkString("ZZInfectionSymptom")
resource.AddFile("materials/zzombies/infection_edges.png")
local pointsPerMeal = CreateConVar("zzombies_consume_points", "10", FCVAR_ARCHIVE, "Zombie points per completed meal, for each active eater", 0, 1000)
local meals = {}
local consumeScreams = {
    "zzombies/consumption/zscream1.wav",
    "zzombies/consumption/zscream2.wav",
    "zzombies/consumption/zscream3.wav",
    "zzombies/consumption/zscream4.wav"
}
for _, path in ipairs(consumeScreams) do resource.AddFile("sound/" .. path) end

function Z.PlayGroupScream(body, count)
    if count < 3 or not IsValid(body) or body.ZZGroupScreamPlayed then return end
    body.ZZGroupScreamPlayed = true
    sound.Play(consumeScreams[math.random(1, #consumeScreams)], body:WorldSpaceCenter(), 90, 100, 1)
end

local function Eligible(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR
        and not ply.ZZ_Extracted and not ply.ZZExfilBoarded and not ZZIsZombie(ply)
end

local function Fever(ply, amount)
    local org = ply.organism
    if not org or not isnumber(org.temperature) then return end
    if amount > 0 and ply.ZZFeverBaseline == nil then ply.ZZFeverBaseline = org.temperature end
    local baseline = ply.ZZFeverBaseline or org.temperature
    local underlying = math.max(math.min(org.temperature, baseline), org.temperature - (ply.ZZInfectionHeat or 0))
    -- Sustain infection fever against normal body cooling. Native temperature
    -- effects provide heat strain and reduced stamina recovery above 38 C.
    -- Do not cap heat from fires or other sources; limit only infection's target.
    local target = underlying + (amount > 0 and math.max(0, math.min(baseline + amount, 41.5) - baseline) or 0)
    org.temperature = math.max(underlying, target)
    ply.ZZInfectionHeat = org.temperature - underlying
    if amount == 0 then ply.ZZFeverBaseline = nil end
end

-- Only end seizures started by infection, leaving unrelated injuries alone.
local function EndInfectionSeizure(ply)
    local episode = ply.ZZNativeSeizure
    local org = ply.organism
    if episode and org == episode.organism then
        if org.seizureEnd and math.abs((ply.fakecd or 0) - org.seizureEnd) < 0.01 then
            ply.fakecd = math.max(CurTime(), episode.fakecd)
        end
        org.seizure = 0
        org.seizureActive = false
        org.seizureStart, org.seizureEnd, org.nextSeizureSpasm = 0, 0, 0
        ply.fullsend = true
    end
    ply.ZZNativeSeizure = nil
    ply.ZZSeizureUntil = nil
end

function Z.Clear(ply, resetPoints)
    Fever(ply, 0)
    EndInfectionSeizure(ply)
    if ply.organism and isnumber(ply.organism.disorientation) then
        ply.organism.disorientation = math.max(0, ply.organism.disorientation - (ply.ZZDisorientationAdded or 0))
    end
    ply.ZZDisorientationAdded = nil
    ply:SetNWFloat("ZZInfectionOverlay", 0)
    ply.ZZInfectionState, ply.ZZInfectionAttacks = nil, nil
    ply.ZZSymptomRelief, ply.ZZSeizureUntil, ply.ZZEatenBy = nil, nil, nil
    ply:SetNWInt("ZZInfectionStage", 0)
    ply:SetNWFloat("ZZInfectionSymptoms", 0)
    ply:SetNWFloat("ZZInfectionSeizure", 0)
    ply:SetNWFloat("ZZConsumeProgress", 0)
    ply:SetNWInt("ZZConsumeCount", 0)
    if resetPoints then ply:SetNWInt("ZZZombiePoints", 0) end
end

function Z.Infect(ply)
    if not Z.Active() or not Eligible(ply) then return false end
    if ply.ZZInfectionState and not ply.ZZInfectionState.cured then return false end
    if ply.ZZInfectionState then Z.Clear(ply) end
    ply.ZZInfectionState = {started = CurTime(), nextEvent = CurTime() + Z.Durations[1] + 5}
    ply:SetNWInt("ZZInfectionStage", 1)
    return true
end

function Z.UsePill(ply, antidote)
    if not Z.Active() or not Eligible(ply) then return false, "This treatment is for living survivors." end
    local state = ply.ZZInfectionState
    if antidote then
        if not state or state.cured then return false, "No active infection to treat." end
        if Z.StageAt(CurTime() - state.started) >= 4 then return false, "The infection is too advanced for an antidote." end
        state.overlayResidual = ply:GetNWFloat("ZZInfectionOverlay", 0)
        state.residual = ply:GetNWFloat("ZZInfectionSymptoms", 0)
        state.cured, state.curedAt = true, CurTime()
        ply:SetNWInt("ZZInfectionStage", 0)
        ply.ZZInfectionAttacks = nil
        return true, "Infection stopped. Recovery pills can ease the remaining symptoms."
    end
    if not state then return false, "No infection symptoms to treat." end
    if ply.ZZSymptomRelief and CurTime() < ply.ZZSymptomRelief + 120 then
        return false, "Your recovery pills are still working."
    end
    ply.ZZSymptomRelief = CurTime()
    return true, "Symptoms will ease over 30 seconds. This does not stop infection."
end

-- A second distinct zombie hitting within five seconds guarantees infection.
hook.Add("ZZZombieMeleeHit", "ZZInfectionHit", function(attacker, ent)
    if not Z.Active() or not ZZIsZombie(attacker) then return end
    local victim = Z.Human(ent)
    if not Eligible(victim) then return end
    local now, count = CurTime(), 0
    victim.ZZInfectionAttacks = victim.ZZInfectionAttacks or {}
    victim.ZZInfectionAttacks[attacker] = now
    for zombie, time in pairs(victim.ZZInfectionAttacks) do
        if not IsValid(zombie) or not zombie:Alive() or not ZZIsZombie(zombie) or now - time > 5 then
            victim.ZZInfectionAttacks[zombie] = nil
        else count = count + 1 end
    end
    if count >= 2 or math.random(100) <= (Z.Chances[attacker:GetNWString("ZZZombieClass")] or 0) then Z.Infect(victim) end
end)

local function MarkBody(ply, body)
    if not IsValid(body) or not IsValid(ply) then return end
    body.ZZHumanBody = not ZZIsZombie(ply)
    body.ZZZombieBody = ZZIsZombie(ply) and true or false
end
hook.Add("Ragdoll_Create", "ZZInfectionBody", MarkBody)
hook.Add("RagdollDeath", "ZZInfectionDeathBody", MarkBody)
hook.Add("PostPostPlayerDeath", "ZZInfectionDeathBody", MarkBody)

local function Edible(body)
    if not IsValid(body) or body:GetClass() ~= "prop_ragdoll" or body.ZZConsumed or body.ZZZombieBody then return false end
    local owner = Z.Human(body)
    if IsValid(owner) and owner:Alive() then return Eligible(owner) end
    return body.ZZHumanBody == true
end

local function LookingAtBody(ply)
    local tr = util.TraceLine({start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 95,
        filter = ply, mask = MASK_SHOT})
    return Edible(tr.Entity) and tr.Entity or nil
end

local function FinishMeal(body, eaters)
    if not Edible(body) then return end
    hook.Run("ChudAchievementMeal", eaters)
    body.ZZConsumed = true -- claim before death hooks or another tick can see it
    local pos, victim = body:WorldSpaceCenter(), Z.Human(body)
    if IsValid(victim) and victim:Alive() then
        victim.ZZEatenBy = nil
        victim:Kill()
        local corpse = victim:GetNWEntity("RagdollDeath")
        if IsValid(corpse) then corpse.ZZConsumed = true corpse:Remove() end
    end
    if not body.ZZGroupScreamPlayed then sound.Play("vo/npc/male01/pain09.wav", pos, 90, 85, 1) end
    for _, zombie in ipairs(eaters) do
        if IsValid(zombie) then
            zombie:SetNWInt("ZZZombiePoints", zombie:GetNWInt("ZZZombiePoints", 0) + pointsPerMeal:GetInt())
        end
    end
    if IsValid(body) then body:Remove() end
end

hook.Add("Should Fake Up", "ZZConsumptionHold", function(ply)
    if Z.Active() and ((ply.ZZEatenBy or 0) >= 2 or (ply.ZZSeizureUntil or 0) > CurTime()) then return false end
end)

local function Symptom(ply, stage)
    local org = ply.organism
    if not org or not hg.organism then return end
    local roll = math.random(1, 4)
    if roll == 1 then
        if not org.seizureActive and (org.seizure or 0) <= 0 and hg.organism.AddSeizure then
            ply.ZZSeizureUntil = CurTime() + (stage == 4 and 5 or 3)
            ply.ZZNativeSeizure = {organism = org, fakecd = ply.fakecd or 0}
            hg.organism.AddSeizure(org, 1)
        end
    elseif roll == 2 then
        if hg.organism.Vomit then hg.organism.Vomit(ply) end
    elseif roll == 3 then
        if hg.organism.CoughBlood then hg.organism.CoughBlood(org) end
    else
        if hg.organism.AddPanicAttack then hg.organism.AddPanicAttack(org, 0.3, true) end
        net.Start("ZZInfectionSymptom") net.WriteUInt(stage, 3) net.Send(ply)
    end
    ply.fullsend = true
end

local stageMessages = {
    [3] = "The sickness is getting worse. Find an antidote.",
    [4] = "INFECTION IMMINENT - antidote can no longer help.",
    [5] = "You have turned into a Shambler."
}

local function NotifyStage(ply, state, stage)
    local message = stageMessages[stage]
    if not message or state.notifiedStage == stage or not ply.Notify then return end
    -- The game's notifier suppresses unconscious players. Try once they wake.
    if ply.organism and ply.organism.otrub then return end
    if ply:Notify(message, 1, "zz_infection_stage_" .. stage, 0, nil, Color(210, 55, 45)) ~= false then
        state.notifiedStage = stage
    end
end

-- No death, Spawn, SetModel or spawnpoint selection: conversion happens in place.
function Z.Transform(ply)
    if not ZZApplyZombieClass or not ZZApplyZombieClass(ply, "shambler", true, false) then return false end
    local org = ply.organism
    if org then
        org.seizure, org.seizureStart, org.seizureEnd, org.nextSeizureSpasm = 0, 0, 0, 0
        org.seizureActive = false
        ply.fakecd = CurTime()
        ply.fullsend = true
    end
    ply.ZZNativeSeizure, ply.ZZSeizureUntil = nil, nil
    ply:SetNWFloat("ZZInfectionSeizure", 0)
    hook.Run("ChudAchievementVirusTurn", ply)
    ply:SetNWBool("ZZFirstInfected", false)
    if IsValid(ply.FakeRagdoll) then
        ply.FakeRagdoll.ZZZombieBody = true
        ply.FakeRagdoll.ZZHumanBody = false
    end
    return true
end

local function TickInfection(ply, now, dt)
    local state = ply.ZZInfectionState
    if not state then return end
    -- A partial class callback must not discard an infection that still needs conversion.
    if not Eligible(ply) then
        if ZZIsZombie(ply) and ply:Alive() and ply.PlayerClassName ~= "headcrabzombie" then
            if not Z.Transform(ply) then return end
        else Z.Clear(ply) end
        return
    end
    local stage = state.cured and 0 or Z.StageAt(now - state.started)
    if stage == 5 then
        ply:SetNWInt("ZZInfectionStage", 5)
        if now >= (state.nextTransform or 0) then
            state.nextTransform = now + 1
            if Z.Transform(ply) then NotifyStage(ply, state, 5) end
        end
        return
    end
    NotifyStage(ply, state, stage)
    if ply.ZZNativeSeizure and now >= (ply.ZZSeizureUntil or 0) then EndInfectionSeizure(ply) end
    ply:SetNWInt("ZZInfectionStage", stage)
    local severity = state.cured and (state.residual or 0) * math.max(0, 1 - (now - state.curedAt) / 120)
        or ({0, 0.3, 0.65, 1})[stage]
    if ply.ZZSymptomRelief then
        local elapsed = now - ply.ZZSymptomRelief
        if elapsed < 120 then severity = severity * (1 - math.Clamp(elapsed / 30, 0, 1))
        else ply.ZZSymptomRelief = nil end
    end
    ply:SetNWFloat("ZZInfectionSymptoms", severity)
    Fever(ply, severity * 4.8)
    if stage >= 3 and now >= state.nextEvent then
        state.nextEvent = now + (stage == 4 and math.Rand(8, 14) or math.Rand(14, 24))
        if math.Rand(0, 1) < severity then Symptom(ply, stage) end
    end
    local org = ply.organism
    if org and isnumber(org.disorientation) then
        local previous = math.max(0, org.disorientation - (ply.ZZDisorientationAdded or 0))
        local target = math.max(previous, severity * 3.5)
        ply.ZZDisorientationAdded = target - previous
        org.disorientation = target
    end
    -- The border ramps within each stage as well as between stages.
    local elapsed = now - state.started
    local starts = {0}
    for i = 2, #Z.Durations do starts[i] = starts[i - 1] + Z.Durations[i - 1] end
    local low, high = {0, 0.08, 0.32, 0.65}, {0.08, 0.32, 0.65, 1}
    local overlay = state.cured and (state.overlayResidual or 0) * math.max(0, 1 - (now - state.curedAt) / 120)
        or low[stage] + (high[stage] - low[stage]) * math.Clamp((elapsed - starts[stage]) / Z.Durations[stage], 0, 1)
    if ply.ZZSymptomRelief then overlay = overlay * (1 - math.Clamp((now - ply.ZZSymptomRelief) / 30, 0, 1)) end
    ply:SetNWFloat("ZZInfectionOverlay", overlay)
    if stage == 4 and severity > 0.1 then
        local stamina = ply.organism and ply.organism.stamina
        if istable(stamina) then stamina[1] = math.max(0, (stamina[1] or 0) - dt * 7 * severity) end
        if now >= (state.nextBreath or 0) then
            state.nextBreath = now + 5
            ply:EmitSound("player/suit_sprint.wav", 55, 95)
        end
    end
    if state.cured and severity <= 0 then Z.Clear(ply) end
end

local lastTick = 0
hook.Add("Think", "ZZInfectionAndConsumption", function()
    local now = CurTime()
    if now - lastTick < 0.1 then return end
    local dt = math.Clamp(now - lastTick, 0, 0.25)
    lastTick = now
    if not Z.Active() then return end
    local groups = {}
    for _, ply in player.Iterator() do
        ply.ZZEatenBy = nil
        ply:SetNWFloat("ZZConsumeProgress", 0)
        ply:SetNWInt("ZZConsumeCount", 0)
        TickInfection(ply, now, dt)
        if ZZIsZombie(ply) and ply:Alive() and not IsValid(ply.FakeRagdoll) and not ply:InVehicle() and ply:KeyDown(IN_USE)
            and not ply:KeyDown(IN_ATTACK) and not ply:KeyDown(IN_ATTACK2) then
            local weapon = ply:GetActiveWeapon()
            local body = IsValid(weapon) and weapon:GetClass() == "weapon_hands_sh" and LookingAtBody(ply)
            if IsValid(body) then
                groups[body] = groups[body] or {}
                groups[body][#groups[body] + 1] = ply
            end
        end
    end
    for body in pairs(meals) do if not groups[body] then meals[body] = nil end end
    for body, eaters in pairs(groups) do
        local meal = meals[body] or {progress = 0}
        meals[body] = meal
        Z.PlayGroupScream(body, #eaters)
        meal.progress = math.min(1, meal.progress + dt / Z.ConsumeDuration(#eaters))
        local victim = Z.Human(body)
        if IsValid(victim) and victim:Alive() then
            victim.ZZEatenBy = #eaters
            if #eaters >= 2 then
                Z.Infect(victim)
            end
            victim:SetNWInt("ZZConsumeCount", #eaters)
        end
        for _, zombie in ipairs(eaters) do
            zombie:SetNWFloat("ZZConsumeProgress", meal.progress)
            zombie:SetNWInt("ZZConsumeCount", #eaters)
        end
        if now >= (meal.nextSound or 0) then
            meal.nextSound = now + 1.5
            body:EmitSound("npc/barnacle/barnacle_crunch2.wav", 60, 90)
        end
        if meal.progress >= 1 then FinishMeal(body, eaters) meals[body] = nil end
    end
end)

local function InfectedDeath(ply, killer)
    if ply.ZZInfectedDeathHandled then return end
    local stage = Z.InfectedSurvivorStage(ply)
    if stage < 1 then return end
    ply.ZZInfectedDeathHandled = true
    hook.Run("ChudAchievementInfectedDeath", ply, killer, stage)
end
-- Capture infection before PlayerDeath cleanup and mode role changes.
hook.Add("DoPlayerDeath", "ZZInfectedDeath", function(ply, killer)
    InfectedDeath(ply, killer)
end)
hook.Add("PlayerSpawn", "ZZInfectionReset", function(ply)
    ply.ZZInfectedDeathHandled = nil
    Z.Clear(ply)
end)
hook.Add("PlayerDeath", "ZZInfectionReset", function(ply, inflictor, killer)
    InfectedDeath(ply, killer)
    Z.Clear(ply)
end)
local function ResetRound()
    meals = {}
    for _, ply in player.Iterator() do Z.Clear(ply, true) end
end
hook.Add("ZB_EndRound", "ZZInfectionReset", ResetRound)
hook.Add("PostCleanupMap", "ZZInfectionReset", ResetRound)
