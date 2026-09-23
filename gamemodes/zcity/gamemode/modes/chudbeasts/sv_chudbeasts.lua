local MODE = MODE

MODE.name = "chudbeasts"
MODE.PrintName = "Chud Beasts"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.randomSpawns = true
MODE.noBoxes = true
MODE.ForBigMaps = false
MODE.Chance = 0.04

-- Chud Beasts keeps the Superfighters 3D combat/stamina style, but uses
-- normal/default movement, with slightly reduced melee damage and a small punch push.
local CHUD_BEAST_HEALTH = 165
local CHUD_BEAST_MELEE_MUL = 0.95
local CHUD_BEAST_PUNCH_KNOCKBACK = 65
local CHUD_BEAST_RAGDOLL_HITS = 8
local CHUD_BEAST_MODEL = "models/risenshine/gang_beast.mdl"

local CHUD_BEAST_BONE_FIELDS = {
    "lleg", "rleg", "larm", "rarm", "spine1", "spine2", "spine3",
    "jaw", "skull", "chest", "pelvis"
}

local function ClearChudBeastBoneDamage(ply, org)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not (zb and zb.CROUND == "chudbeasts") then return end
    org = org or ply.organism
    if not org then return end

    for _, key in ipairs(CHUD_BEAST_BONE_FIELDS) do
        org[key] = 0
    end

    org.llegdislocation = false
    org.rlegdislocation = false
    org.larmdislocation = false
    org.rarmdislocation = false
    org.jawdislocation = false
    org.brokenribs = 0
    org.just_damaged_bone = nil

    if hg.fakeBoneFlop then
        for _, limb in ipairs({"lleg", "rleg", "larm", "rarm"}) do
            hg.fakeBoneFlop.SetLimbSegmentState(org, limb, "up", false)
            hg.fakeBoneFlop.SetLimbSegmentState(org, limb, "down", false)
        end
    end
end

hook.Add("Org Think", "ChudBeasts_NoBrokenBones", function(owner, org)
    ClearChudBeastBoneDamage(owner, org)
end, HOOK_MONITOR_LOW)

util.PrecacheModel(CHUD_BEAST_MODEL)
resource.AddFile("sound/chudbeasts/beats.mp3")

util.AddNetworkString("chudbeasts_start")
util.AddNetworkString("chudbeasts_end")

local function ClearWorldWeaponSpawns()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:IsWeapon() and not IsValid(ent:GetOwner()) then
            ent:Remove()
        end
    end
end

local function ApplyChudBeastModel(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply:SetModel(CHUD_BEAST_MODEL)

    -- Pick a valid bodygroup combination once per player each round, then
    -- reuse it when the model is reapplied so their appearance stays stable.
    if not ply.ChudBeastsBodygroups then
        ply.ChudBeastsBodygroups = {}

        for _, bodygroup in ipairs(ply:GetBodyGroups() or {}) do
            local id = tonumber(bodygroup.id)
            local count = tonumber(bodygroup.num) or 0

            if id and count > 0 then
                ply.ChudBeastsBodygroups[id] = math.random(0, count - 1)
            end
        end
    end

    for id, value in pairs(ply.ChudBeastsBodygroups) do
        ply:SetBodygroup(id, value)
    end
end

-- Add just a little extra shove to normal hand punches in this mode.
-- Punch damage uses the mode-specific CHUD_BEAST_MELEE_MUL above.
local function IsChudBeastPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply.PlayerClassName == "chudbeast" then return true end
    return zb and zb.CROUND == "chudbeasts"
end

local function ClearChudBeastPain(ply, org)
    if not IsChudBeastPlayer(ply) then return false end
    org = org or ply.organism
    if not org then return false end
    org.pain = 0
    org.avgpain = 0
    org.painadd = 0
    org.painlessen = 0
    org.nearpainlimit = false
    org.painScreamQueue = 0
    org.painScreamUntil = 0
    org.painScreamNext = 0
    if hg and hg.StopPainScream then hg.StopPainScream(ply, 0) end
    return true
end

hook.Add("Org Think", "ChudBeasts_FinalPainImmunity", function(owner, org)
    ClearChudBeastPain(owner, org)
end, HOOK_MONITOR_LOW)

hook.Add("PostEntityTakeDamage", "ChudBeasts_ClearPainAfterDamage", function(target)
    local ply = target
    if IsValid(target) and target:IsRagdoll() and hg and hg.RagdollOwner then ply = hg.RagdollOwner(target) end
    if not IsChudBeastPlayer(ply) then return end
    ClearChudBeastPain(ply)
    timer.Simple(0, function() if IsValid(ply) then ClearChudBeastPain(ply) end end)
end)

hook.Add("EntityTakeDamage", "ChudBeasts_TinyPunchKnockback", function(target, dmginfo)
    local attacker = dmginfo:GetAttacker()
    local inflictor = dmginfo:GetInflictor()
    if not IsChudBeastPlayer(attacker) then return end
    if not IsValid(inflictor) then return end

    -- weapon_hands_sh is automatically replaced by weapon_hg_coolhands, so
    -- accept both classes. The old single-class check prevented hits from
    -- ever reaching the counter on normal Chudmorse servers.
    local inflictorClass = inflictor:GetClass()
    if inflictorClass ~= "weapon_hands_sh" and inflictorClass ~= "weapon_hg_coolhands" then return end
    if target == attacker then return end

    local aim = attacker:GetAimVector()
    local push = Vector(aim.x, aim.y, math.max(aim.z, 0.08)):GetNormalized()
    local isLegKick = attacker:GetNWFloat("InLegKick", 0) > CurTime()

    if IsValid(target) and target:IsPlayer() then
        if isLegKick then
            -- A landed Chud Beast kick instantly toggles hg_fake for the
            -- victim. The 400 knockback itself is applied directly by the
            -- hg_kick/LegAttack code path. Delay to the next tick so that force is
            -- applied before the player's ragdoll is created.
            if target:Alive() and not IsValid(target.FakeRagdoll) then
                target.ChudBeastsPunchHits = 0

                timer.Simple(0, function()
                    if not IsValid(target) or not target:Alive() then return end
                    if not IsChudBeastPlayer(attacker) then return end
                    if IsValid(target.FakeRagdoll) then return end
                    concommand.Run(target, "fake", {}, "")
                end)
            end

            return
        end

        target:SetVelocity(push * CHUD_BEAST_PUNCH_KNOCKBACK)

        -- Every 8 landed Chud Beast punches knocks the standing victim down.
        -- Reset on knockdown so, after they stand back up, another 8 hits are
        -- required for the next ragdoll.
        if target:Alive() and not IsValid(target.FakeRagdoll) then
            target.ChudBeastsPunchHits = (target.ChudBeastsPunchHits or 0) + 1

            if target.ChudBeastsPunchHits >= CHUD_BEAST_RAGDOLL_HITS then
                target.ChudBeastsPunchHits = 0

                timer.Simple(0, function()
                    if not IsValid(target) or not target:Alive() then return end
                    if not IsChudBeastPlayer(attacker) then return end
                    if IsValid(target.FakeRagdoll) then return end
                    -- Toggle the same command used by the player's hg_fake bind.
                    -- In this codebase the registered console command is named
                    -- "fake", and running it as the victim guarantees that the
                    -- victim (not the attacker) is knocked down on hit eight.
                    concommand.Run(target, "fake", {}, "")
                end)
            end
        end

        return
    end

    if IsValid(target) and target:IsRagdoll() then
        -- hg_kick already applies its own ragdoll force in LegAttack.
        if isLegKick then return end

        local phys = target:GetPhysicsObjectNum(0)
        if IsValid(phys) then
            phys:ApplyForceCenter(push * phys:GetMass() * CHUD_BEAST_PUNCH_KNOCKBACK)
        end
    end
end)

local function RestoreChudBeastModifiers(ply)
    if not IsValid(ply) then return end

    ply.ChudBeastsPunchHits = nil
    ply.ChudBeastsBodygroups = nil

    if ply.ChudBeastsMeleeModifierApplied then
        if ply.ChudBeastsHadMeleeDamageMul then
            ply.MeleeDamageMul = ply.ChudBeastsOldMeleeDamageMul
        else
            ply.MeleeDamageMul = nil
        end
    end
    ply.ChudBeastsMeleeModifierApplied = nil
    ply.ChudBeastsOldMeleeDamageMul = nil
    ply.ChudBeastsHadMeleeDamageMul = nil

    if ply.ChudBeastsOldMaxHealth ~= nil then
        ply:SetMaxHealth(ply.ChudBeastsOldMaxHealth)
        ply.ChudBeastsOldMaxHealth = nil
    end
end

function MODE:CanLaunch()
    return true
end

function MODE:Intermission()
    game.CleanUpMap()

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        RestoreChudBeastModifiers(ply)
        ApplyAppearance(ply)
        ply:SetupTeam(0)

        ply:SetPlayerClass("chudbeast", {instant = true})

        -- Transform every participating player immediately during the intro.
        -- This runs after normal appearance/team setup so it is the final model.
        ply.ChudBeastsBodygroups = nil
        ApplyChudBeastModel(ply)
    end

    -- This mode is melee-only: remove any map-placed/world weapon entities.
    timer.Simple(0, ClearWorldWeaponSpawns)
    timer.Simple(0.25, ClearWorldWeaponSpawns)

    local rndpoints = zb.GetMapPoints("RandomSpawns") or {}
    local zonepoint = table.Random(rndpoints)
    local zonepos = zonepoint and zonepoint.pos or vector_origin

    net.Start("chudbeasts_start")
        net.WriteVector(zonepos)
    net.Broadcast()

end

function MODE:CheckAlivePlayers()
    local alive = {}
    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end
        if ply.organism and ply.organism.incapacitated then continue end
        alive[#alive + 1] = ply
    end
    return alive
end

function MODE:ShouldRoundEnd()
    return (#zb:CheckAlive(true) <= 1)
end

function MODE:RoundStart()
    ClearWorldWeaponSpawns()

    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end

        ply.ChudBeastsPunchHits = 0
        ply:SetSuppressPickupNotices(true)
        ply.noSound = true

        ply.ChudBeastsOldMaxHealth = ply:GetMaxHealth()
        ply:SetMaxHealth(CHUD_BEAST_HEALTH)
        ply:SetHealth(CHUD_BEAST_HEALTH)

        -- Chud Beasts use their own dedicated player model. Re-apply it after
        -- round-start appearance hooks so the normal appearance system cannot
        -- immediately overwrite it.
        ply.ChudBeastsBodygroups = nil
        ApplyChudBeastModel(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) and zb.CROUND == "chudbeasts" then
                ApplyChudBeastModel(ply)
            end
        end)

        ply:Give("weapon_hands_sh")

        local inv = ply:GetNetVar("Inventory")
        if istable(inv) then
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"] = true
            ply:SetNetVar("Inventory", inv)
        end

        ply:Give("weapon_walkie_talkie")
        ply:SelectWeapon("weapon_hands_sh")

        -- Both hands and weapon_melee use MeleeDamageMul, so this reduces
        -- Chud Beasts melee damage without changing melee in every other mode.
        if ply.PlayerClassName ~= "chudbeast" then
            ply.ChudBeastsMeleeModifierApplied = true
            ply.ChudBeastsHadMeleeDamageMul = ply.MeleeDamageMul ~= nil
            ply.ChudBeastsOldMeleeDamageMul = ply.MeleeDamageMul
            ply.MeleeDamageMul = (ply.MeleeDamageMul or 1) * CHUD_BEAST_MELEE_MUL
        end

        if ply.organism then
            ply.organism.recoilmul = 0.25
            ply.organism.superfighter = true
            ply.organism.panicattackadd = 0
            ply.organism.panicattack = 0
            ply.organism.panicattackActive = false
            ply.organism.nextPanicHeartRoll = 0
        end

        timer.Simple(0.1, function()
            if IsValid(ply) then ply.noSound = false end
        end)

        ply:SetSuppressPickupNotices(false)
        zb.GiveRole(ply, "Chud Beast", Color(190, 15, 15))
    end

    timer.Simple(0.25, ClearWorldWeaponSpawns)
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

-- Intentionally empty: Chud Beasts has no loot/weapon spawns.
MODE.LootTable = {}

function MODE:RoundThink()
    -- Keep map/script-created world weapons from becoming weapon spawns during
    -- the round while leaving each player's hands/walkie alone.
    if (self.nextWeaponCleanup or 0) < CurTime() then
        self.nextWeaponCleanup = CurTime() + 1
        ClearWorldWeaponSpawns()
    end
end

function MODE:PlayerDeath(ply)
end

function MODE:CanSpawn()
end

function MODE:EndRound()
    for _, ply in player.Iterator() do
        RestoreChudBeastModifiers(ply)
    end

    timer.Simple(2, function()
        net.Start("chudbeasts_end")
            local ent = zb:CheckAlive(true)[1]
            net.WriteEntity(IsValid(ent) and ent:Alive() and ent or NULL)
        net.Broadcast()
    end)
end
