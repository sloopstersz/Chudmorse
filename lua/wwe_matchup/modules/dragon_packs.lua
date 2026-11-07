-- Also clear a retired registration when Lua is refreshed.
WWE.moves.dragon_finishingblow = nil
-- Remove every retired Beast move, including registrations left by Lua refresh.
for id in pairs(WWE.moves) do
    if string.sub(id, 1, 13) == "dragon_beast_" then WWE.moves[id] = nil end
end
local hitSettings = include("wwe_matchup/dragon_hit_settings.lua")
-- Remove old registrations during Lua refresh as well as full restarts.
local moves = {
    {id="dragon_beast_piledive", attacker="c_limbs_beasthact", victim="bsmodimations_beasthact", sequence="killmove_beasthact_piledive", direction="front", forward=20, right=0, up=0, yaw=0, wall=false},
    {id="dragon_brawling", attacker="killmove_brawlerhact_player", victim="killmove_brawlerhact_target", sequence="killmove_brawlerhact_brawling", direction="front", forward=25, right=0, up=0, yaw=0, wall=false},
    {id="dragon_disarming", attacker="killmove_brawlerhact_player", victim="killmove_brawlerhact_target", sequence="killmove_brawlerhact_disarming", direction="right", forward=60, right=5, up=0, yaw=0, wall=false},
    {id="dragon_rush_barrage", attacker="killmove_rushhact_player", victim="killmove_rushhact_target", sequence="killmove_rushhact_barrage", direction="front", forward=70, right=0, up=0, yaw=0, wall=false},
    {id="dragon_rush_crushing", attacker="killmove_rushhact_player", victim="killmove_rushhact_target", sequence="killmove_rushhact_crushing", direction="front", forward=35, right=5, up=0, yaw=0, wall=false},
    {id="dragon_rush_wall", attacker="killmove_rushhact_player", victim="killmove_rushhact_target", sequence="killmove_rushhact_crushing_wall", direction="front", forward=60, right=5, up=0, yaw=0, wall=true},
    {id="dragon_tigerdrop", attacker="killmove_tigerdrop_player", victim="killmove_tigerdrop_target", sequence="killmove_tigerdrop", direction="front", forward=50, right=0, up=-5, yaw=0, wall=false},
}

-- Z-WWE registration: a move supplies its animation drivers to RagdollDown.
-- Never load the BSMOD autoruns: their globals and kill hooks belong to BSMOD.
local function FacingAllowed(ply, target, direction)
    local delta = ply:GetPos() - target:GetPos()
    delta.z = 0
    if delta:LengthSqr() < 1 then return false end
    delta:Normalize()
    local forward = target:GetForward():Dot(delta)
    local right = target:GetRight():Dot(delta)
    if direction == "back" then return forward < -0.4 end
    if direction == "right" then return right > 0.4 end
    if direction == "left" then return right < -0.4 end
    return forward > 0.4
end

hook.Add("CanControlFake", "ChudDragonAnimationControl", function(ply, rag)
    if IsValid(rag) and IsValid(rag.AnimModule) and rag.AnimModule.DragonFullBody then return false end
end)

for _, info in ipairs(moves) do
    local move = info
    WWE.RegisterMove(move.id, {
        Cooldown = 8,
        Condition = WWE.IsStanding,
        Execute = function(ply, target)
            if not ChudDragonStyle.CanUseMove(ply, move.id) then return false end
            local heldItem, holdingWeapon, carriedProp = ChudDragonStyle.GetHeldItem(target)
            local armedTarget = IsValid(heldItem)
            -- Enforce priority on the server too, including direct move requests.
            if armedTarget and move.id ~= "dragon_tigerdrop" then return false end
            if not (armedTarget and move.id == "dragon_tigerdrop") and not FacingAllowed(ply, target, move.direction) then return false end
            local attackerModel = "models/chudmorse/dragon/" .. move.attacker .. ".mdl"
            local victimModel = "models/chudmorse/dragon/" .. move.victim .. ".mdl"
            if not WWE.SeqExists(attackerModel, move.sequence) or not WWE.SeqExists(victimModel, move.sequence) then return false end
            local attackerDuration = WWE.SeqDuration(attackerModel, move.sequence)
            local victimDuration = WWE.SeqDuration(victimModel, move.sequence)
            if attackerDuration <= 0 or victimDuration <= 0 then return false end
            local duration = math.max(attackerDuration, victimDuration)
            local origin = target:GetPos()
            local angles = Angle(0, target:EyeAngles().y, 0)
            if move.wall then
                local tr = util.TraceLine({start = target:WorldSpaceCenter(), endpos = target:WorldSpaceCenter() - angles:Forward() * 100, filter = {ply, target}, mask = MASK_SOLID_BRUSHONLY})
                if not tr.Hit or math.abs(tr.HitNormal.z) > 0.1 then return false end
                angles = Angle(0, tr.HitNormal:Angle().y, 0)
                origin = Vector(tr.HitPos.x, tr.HitPos.y, origin.z) + tr.HitNormal * (move.id == "dragon_rush_wall" and 90 or 50)
            end
            local attackerPos = origin + angles:Forward() * move.forward + angles:Right() * move.right + Vector(0, 0, move.up)
            local attackerAngles = angles + Angle(0, move.yaw, 0)
            local start = CurTime()
            local optionsA = {pos = attackerPos, angles = attackerAngles, syncStart = start, syncDuration = attackerDuration, fullAnimation = true, dragonFullBody = true}
            local optionsT = {pos = origin, angles = angles, syncStart = start, syncDuration = victimDuration, fullAnimation = true, dragonFullBody = true}
            local ragA = WWE.RagdollDown(ply, attackerModel, move.sequence, duration, optionsA)
            local ragT = WWE.RagdollDown(target, victimModel, move.sequence, duration, optionsT)
            if not IsValid(ragA) or not IsValid(ragT) or not IsValid(ragA.AnimModule) or not IsValid(ragT.AnimModule) then
                for _, fighter in ipairs({ply, target}) do
                    local rag = fighter.FakeRagdoll
                    if IsValid(rag) and IsValid(rag.AnimModule) then rag.AnimModule:Remove() end
                    WWE.StandUp(fighter)
                end
                return false
            end
            -- Start both only after both drivers exist. Preserve native FPS:
            -- a shorter victim sequence must not be stretched to the attacker length.
            local pairedStart = CurTime()
            for _, driver in ipairs({ragA.AnimModule, ragT.AnimModule}) do
                driver.SyncStart = pairedStart
                driver:SetPlaybackRate(0)
                driver:SetCycle(0)
            end
            ragA.AnimModule.PairRagdoll = ragT
            ragT.AnimModule.PairRagdoll = ragA
            constraint.NoCollide(ragA, ragT, 0, 0)
            local settings = hitSettings[move.id] or hitSettings.default
            local defaults = hitSettings.default
            local victimOrganism = target.organism
            local function StillSameVictim()
                return IsValid(ply) and ply:Alive() and IsValid(target) and target:Alive()
                    and IsValid(ragT) and target.FakeRagdoll == ragT and target.organism == victimOrganism
            end
            local function HitDelay(event)
                return math.Clamp(tonumber(event.time) or duration * (tonumber(event.fraction) or 0.65), 0, duration)
            end
            for _, entry in ipairs(settings.hits or defaults.hits) do
                local event = entry
                timer.Simple(HitDelay(event), function()
                    if not StillSameVictim() then return end
                    if event.disarm and IsValid(heldItem) then
                        if carriedProp then
                            if IsValid(holdingWeapon) and holdingWeapon.SetCarrying and holdingWeapon.CarryEnt == heldItem then
                                holdingWeapon:SetCarrying()
                            end
                            target:DropObject()
                        elseif heldItem:GetOwner() == target then
                            target:DropWeapon(heldItem)
                        end
                    end
                    local impactSound = event.sound
                    if impactSound == nil then
                        impactSound = event.breakArm and defaults.fractureSounds or defaults.impactSounds
                    end
                    if istable(impactSound) then
                        impactSound = #impactSound > 0 and impactSound[math.random(1, #impactSound)] or nil
                    end
                    if isstring(impactSound) and impactSound ~= "" then
                        local low = math.Clamp(tonumber(event.pitchMin) or defaults.pitchMin or 100, 0, 255)
                        local high = math.Clamp(tonumber(event.pitchMax) or defaults.pitchMax or low, low, 255)
                        ragT:EmitSound(impactSound, math.Clamp(tonumber(event.soundLevel) or defaults.soundLevel or 75, 0, 511),
                            math.random(math.floor(low), math.floor(high)), math.Clamp(tonumber(event.volume) or defaults.volume or 1, 0, 1))
                    end
                    if event.blood ~= false and hg and hg.BloodAt then
                        hg.BloodAt(ragT, event.bone or "ValveBiped.Bip01_Head1")
                    end
                    local limb = event.breakArm
                    if (limb == "larm" or limb == "rarm") and victimOrganism and not victimOrganism[limb .. "amputated"] then
                        if (victimOrganism[limb] or 0) < 1 then
                            victimOrganism[limb] = 1
                        end
                    end
                end)
            end
            local damageTime = math.Clamp(tonumber(settings.damageTime) or duration * (tonumber(settings.damageFraction) or defaults.damageFraction), 0, duration)
            timer.Simple(damageTime, function()
                if not StillSameVictim() then return end
                WWE.ApplyMoveDamage(target, ply, tonumber(settings.damage) or defaults.damage, DMG_CLUB)
            end)
            -- Recover only the assailant after both animation tracks finish.
            -- The victim remains in the final shadow-tracked ragdoll pose.
            timer.Simple(duration + 0.05, function()
                if IsValid(ply) and ply:Alive() and ply.FakeRagdoll == ragA then
                    WWE.StandUp(ply)
                end
            end)
            return true
        end
    })
end
