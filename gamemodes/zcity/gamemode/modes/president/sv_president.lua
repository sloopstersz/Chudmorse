local MODE = MODE

MODE.name = "president"
MODE.PrintName = "President"

util.AddNetworkString("president_start")
util.AddNetworkString("president_end")
util.AddNetworkString("president_task")
util.AddNetworkString("president_intermission")

MODE.presidentEnt = NULL
MODE.roundDone = false
MODE.presidentTaskWon = false
MODE.tasksDone = 0
MODE.tasksRequiredCount = 0
MODE.taskShouldEnd = false
MODE.taskData = {}

local PRESIDENT_COLOR = Color(0, 255, 65)
local BODYGUARD_COLOR = Color(0, 80, 255)
local CITIZEN_COLOR = Color(255, 60, 60)

local ROUND_RESULTS_DELAY = 5

local PLAYER_HULL_MINS = Vector(-16, -16, 0)
local PLAYER_HULL_MAXS = Vector(16, 16, 72)

local PROP_HULL_MINS = Vector(-20, -20, 0)
local PROP_HULL_MAXS = Vector(20, 20, 48)

local SPAWN_CLUSTER_RADIUS = 220
local SPAWN_MIN_SEPARATION = 56
local SPAWN_GROUP_MIN_DISTANCE = 900

local START_SOUND_PATH = "zcity_president/president_start.mp3"

if resource and resource.AddSingleFile then
    resource.AddSingleFile("sound/" .. START_SOUND_PATH)
end

local TASK_PROP_MIN_MASS = 5
local TASK_PROP_MAX_MASS = 90
local TASK_PROP_MAX_SIZE = 120

local TASK_PROP_MODELS = {
    "models/props_c17/oildrum001.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/cardboard_box004a.mdl",
    "models/props_junk/metalbucket01a.mdl",
    "models/props_junk/trafficcone001a.mdl",
    "models/props_c17/FurnitureDrawer001a.mdl"
}

local VALID_PROP_CLASSES = {
    prop_physics = true,
    prop_physics_multiplayer = true
}

local function SetPresident(ply)
    MODE.presidentEnt = IsValid(ply) and ply or NULL
    SetNetVar("zp_president", MODE.presidentEnt)
end

local function GetPresidentEntity()
    local president = MODE.presidentEnt
    if IsValid(president) then return president end

    return MODE.GetPresident()
end

local function IsPresidentAlive()
    local president = GetPresidentEntity()

    return IsValid(president)
        and president:Alive()
        and (not president.organism or not president.organism.incapacitated)
end

local function IsValidTaskProp(ent)
    if not IsValid(ent) then return false end
    if not VALID_PROP_CLASSES[ent:GetClass()] then return false end
    if IsValid(ent:GetParent()) then return false end
    if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return false end

    if not phys:IsMoveable() then return false end
    if phys.IsMotionEnabled and not phys:IsMotionEnabled() then return false end

    local mass = phys:GetMass()
    if not mass or mass < TASK_PROP_MIN_MASS or mass > TASK_PROP_MAX_MASS then
        return false
    end

    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local size = maxs - mins
    if size.x > TASK_PROP_MAX_SIZE or size.y > TASK_PROP_MAX_SIZE or size.z > TASK_PROP_MAX_SIZE then
        return false
    end

    if constraint and constraint.HasConstraints and constraint.HasConstraints(ent) then
        return false
    end

    return true
end


local function BroadcastTaskClear()
    net.Start("president_task")
        net.WriteBool(false)
    net.Broadcast()
end

local function RollChance(percent)
    return math.random(100) <= percent
end

local function ResetPlayerInventory(ply)
    if not IsValid(ply) then return end

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true
    ply:StripWeapons()

    if ply.StripAmmo then
        ply:StripAmmo()
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end

        ply.noSound = false
        ply:SetSuppressPickupNotices(false)
    end)
end

local function GiveWeaponFullClip(ply, class)
    local wep = ply:Give(class)

    if IsValid(wep) and wep.GetMaxClip1 and wep.SetClip1 then
        local maxClip = wep:GetMaxClip1()
        if maxClip and maxClip > 0 then
            wep:SetClip1(maxClip)
        end
    end

    return wep
end

local function GiveReserveClips(ply, wep, clips)
    if not IsValid(ply) or not IsValid(wep) then return end
    if not wep.GetMaxClip1 or not wep.GetPrimaryAmmoType then return end

    local maxClip = wep:GetMaxClip1()
    local ammoType = wep:GetPrimaryAmmoType()

    if maxClip and maxClip > 0 and ammoType and ammoType >= 0 then
        ply:GiveAmmo(maxClip * (clips or 1), ammoType, true)
    end
end

local function GiveSling(ply)
    local inv = ply:GetNetVar("Inventory") or {}
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    ply:SetNetVar("Inventory", inv)
end

local function GiveFlashlightInventory(ply)
    local inv = ply:GetNetVar("Inventory") or {}
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_flashlight"] = true
    ply:SetNetVar("Inventory", inv)
    ply:SetNetVar("flashlight", false)
end

local CHUD_PROTECTOR_PRIMARY_POOL = {
    "weapon_ar15",
    "weapon_mp5",
    "weapon_p90",
    "weapon_spas12_modern",
    "weapon_sr25",
    "weapon_sg552",
    "weapon_m16a1",
    "weapon_ash12",
    "weapon_hk416"
}

local ANGRY_CHUD_PRIMARY_POOL = {
    "weapon_mosin",
    "weapon_ks23",
    "weapon_doublebarrel",
    "weapon_toz106",
    "weapon_akmwreked",
    "weapon_ruger",
    "weapon_skorpion"
}

local function GivePooledPrimary(ply, pool, reserveClips)
    local mainClass = table.Random(pool)
    if not mainClass then return nil end

    local primary = GiveWeaponFullClip(ply, mainClass)
    GiveReserveClips(ply, primary, reserveClips or 3)

    -- Requested fixed optics for the scoped pool entries.
    if IsValid(primary) and hg and hg.AddAttachmentForce then
        if mainClass == "weapon_mosin" then
            hg.AddAttachmentForce(ply, primary, "optic12")
        elseif mainClass == "weapon_sr25" then
            hg.AddAttachmentForce(ply, primary, "optic6")
        end
    end

    return primary
end

local function GiveChudProtectorLoadout(ply)
    ply:SetPlayerClass("swat")
    GiveSling(ply)
    GiveFlashlightInventory(ply)

    GivePooledPrimary(ply, CHUD_PROTECTOR_PRIMARY_POOL, 3)

    -- Chud Protectors use only the M9 Beretta as their sidearm.
    local pistol = GiveWeaponFullClip(ply, "weapon_m9beretta")
    GiveReserveClips(ply, pistol, 3)

    -- Every VIC-mode combat loadout gets a medkit.
    ply:Give("weapon_medkit_sh")
    ply:Give("weapon_combatknife")
    ply:Give("weapon_hg_flashbang_tpik")

    hg.AddArmor(ply, {
        "ent_armor_helmet6",
        "ent_armor_vest8",
        ({"ent_armor_mask1", "ent_armor_mask2", "ent_armor_nightvision1"})[math.random(3)]
    })

    if ply.organism then
        ply.organism.recoilmul = 0.6
    end

    ply:SetNetVar("CurPluv", "pluvberet")
end

local function GiveAngryChudLoadout(ply)
    ply:SetPlayerClass("terrorist")
    GiveSling(ply)

    GivePooledPrimary(ply, ANGRY_CHUD_PRIMARY_POOL, 3)

    -- Angry Chuds always get a Makarov sidearm.
    local pistol = GiveWeaponFullClip(ply, "weapon_makarov")
    GiveReserveClips(ply, pistol, 3)

    -- Every VIC-mode combat loadout gets a medkit.
    ply:Give("weapon_medkit_sh")

    hg.AddArmor(ply, {"ent_armor_vest4", "ent_armor_helmet1"})

    ply:Give("weapon_combatknife")
    ply:Give("weapon_bandage_sh")
    ply:Give("weapon_tourniquet")

    local radio = ply:Give("weapon_walkie_talkie")
    if IsValid(radio) then
        radio.Frequency = math.Round(math.Rand(100, 108), 1)
    end

    ply:SetNetVar("CurPluv", "pluvboss")
end

local function GetRandomSelectionSet(list, count)
    local out = {}
    if not istable(list) or #list <= 0 or count <= 0 then return out end

    local shuffled = table.Copy(list)
    table.Shuffle(shuffled)

    for i = 1, math.min(count, #shuffled) do
        out[shuffled[i]] = true
    end

    return out
end

local function GetActiveRoundPlayers(aliveOnly)
    local players = {}

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if aliveOnly and not ply:Alive() then continue end

        players[#players + 1] = ply
    end

    return players
end

local function GetTranslatedPointList(name)
    local raw = zb.GetMapPoints and zb.GetMapPoints(name) or nil
    if not raw then return {} end

    local translated = zb.TranslatePointsToVectors and zb.TranslatePointsToVectors(raw) or raw
    if not istable(translated) then return {} end

    local out = {}
    for _, vec in ipairs(translated) do
        if isvector(vec) then
            out[#out + 1] = vec
        end
    end

    return out
end

local function GetEntityPositions(classNames)
    local out = {}

    for _, class in ipairs(classNames) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if IsValid(ent) then
                out[#out + 1] = ent:GetPos()
            end
        end
    end

    return out
end

local function MergeVectors(...)
    local out = {}

    for i = 1, select("#", ...) do
        local tbl = select(i, ...) or {}
        for _, vec in ipairs(tbl) do
            if isvector(vec) then
                out[#out + 1] = vec
            end
        end
    end

    return out
end

local function GetTCTSpawnPoints()
    local tPoints = GetTranslatedPointList("HMCD_TDM_T")
    local ctPoints = GetTranslatedPointList("HMCD_TDM_CT")

    if #tPoints == 0 then
        tPoints = GetEntityPositions({ "info_player_terrorist" })
    end

    if #ctPoints == 0 then
        ctPoints = GetEntityPositions({ "info_player_counterterrorist" })
    end

    return tPoints, ctPoints
end

local function GetGeneralTaskPoints()
    local randomPoints = GetTranslatedPointList("RandomSpawns")
    if #randomPoints > 0 then
        return randomPoints
    end

    local tPoints, ctPoints = GetTCTSpawnPoints()

    return MergeVectors(
        GetEntityPositions({ "info_player_start", "info_player_deathmatch" }),
        tPoints,
        ctPoints
    )
end

local function GetFarthestPoint(fromPos, points, minDistSqr)
    local bestPos
    local bestDist = -1

    for _, pos in ipairs(points) do
        local dist = fromPos:DistToSqr(pos)
        if dist >= minDistSqr and dist > bestDist then
            bestDist = dist
            bestPos = pos
        end
    end

    return bestPos, bestDist
end

local function GetMovableProps()
    local props = {}

    for _, ent in ents.Iterator() do
        if not IsValidTaskProp(ent) then continue end
        props[#props + 1] = ent
    end

    return props
end


local function FindGroundedOpenPosition(pos, mins, maxs, lift)
    if not isvector(pos) then return nil end

    local groundTrace = util.TraceLine({
        start = pos + Vector(0, 0, 128),
        endpos = pos - Vector(0, 0, 768),
        mask = MASK_PLAYERSOLID
    })

    if not groundTrace.Hit or groundTrace.HitSky then
        return nil
    end

    local openPos = groundTrace.HitPos + Vector(0, 0, lift or 2)

    local hullTrace = util.TraceHull({
        start = openPos,
        endpos = openPos,
        mins = mins,
        maxs = maxs,
        mask = MASK_PLAYERSOLID
    })

    if hullTrace.StartSolid or hullTrace.Hit then
        return nil
    end

    return openPos
end

local function ValidateAreaCenter(pos, radius)
    local center = FindGroundedOpenPosition(pos, PLAYER_HULL_MINS, PLAYER_HULL_MAXS, 2)
    if not center then return nil end

    local sampleDist = math.Clamp((radius or 0) * 0.35, 48, 128)
    local offsets = {
        Vector(0, 0, 0),
        Vector(sampleDist, 0, 0),
        Vector(-sampleDist, 0, 0),
        Vector(0, sampleDist, 0),
        Vector(0, -sampleDist, 0)
    }

    for _, offset in ipairs(offsets) do
        if not FindGroundedOpenPosition(center + offset, PLAYER_HULL_MINS, PLAYER_HULL_MAXS, 2) then
            return nil
        end
    end

    return center
end

local function GetValidAreaPoints(points, radius)
    local out = {}

    for _, pos in ipairs(points) do
        local valid = ValidateAreaCenter(pos, radius)
        if valid then
            out[#out + 1] = valid
        end
    end

    return out
end

local function PickTaskPropModel()
    return TASK_PROP_MODELS[math.random(#TASK_PROP_MODELS)]
end

local function SpawnTaskPropAt(pos, forcedModel)
    local spawnPos = FindGroundedOpenPosition(pos, PROP_HULL_MINS, PROP_HULL_MAXS, 6)
    if not spawnPos then return nil end

    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then return nil end

    ent:SetModel(forcedModel or PickTaskPropModel())
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, math.random(0, 359), 0))
    ent:Spawn()
    ent:Activate()

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) or not phys:IsMoveable() then
        ent:Remove()
        return nil
    end

    local checkTrace = util.TraceHull({
        start = ent:GetPos(),
        endpos = ent:GetPos(),
        mins = PROP_HULL_MINS,
        maxs = PROP_HULL_MAXS,
        mask = MASK_PLAYERSOLID,
        filter = ent
    })

    if checkTrace.StartSolid or checkTrace.Hit then
        ent:Remove()
        return nil
    end

    phys:Wake()

    return ent
end

local function CleanupTaskEntity(task)
    if not task or task.kind ~= "prop" then return end
    if not task.spawnedProp then return end

    if IsValid(task.targetEnt) then
        task.targetEnt:Remove()
    end

    task.targetEnt = nil
end

local function EnsureTaskPropSpawned(task)
    if not task or task.kind ~= "prop" then return true end
    if IsValid(task.targetEnt) then return true end
    if not task.pendingSpawn or not isvector(task.spawnPos) then return false end

    local ent = SpawnTaskPropAt(task.spawnPos, task.spawnModel)
    if not IsValid(ent) then
        return false
    end

    task.targetEnt = ent
    task.spawnedProp = true
    task.pendingSpawn = false

    return true
end

local function SendRoleIntro(ply, roleName, roleColor, objective, restartIntro)
    if not IsValid(ply) then return end

    net.Start("president_start")
        net.WriteString(roleName or "")
        net.WriteString(objective or "")
        net.WriteUInt((roleColor and roleColor.r) or 255, 8)
        net.WriteUInt((roleColor and roleColor.g) or 255, 8)
        net.WriteUInt((roleColor and roleColor.b) or 255, 8)
        net.WriteBool(restartIntro ~= false)
    net.Send(ply)
end

local function GetPresidentObjectiveText(taskShouldEnd, taskCount)
    if MODE.GetTasksEnabled() and taskShouldEnd and taskCount > 0 then
        return "Survive and complete the required tasks."
    elseif MODE.GetTasksEnabled() and taskCount > 0 then
        return "Survive until the round ends or complete tasks for an instant win."
    else
        return "Survive until the round ends."
    end
end

local function SortVectorsByDistance(origin, points)
    local out = {}

    for _, pos in ipairs(points or {}) do
        if isvector(pos) then
            out[#out + 1] = pos
        end
    end

    if isvector(origin) then
        table.sort(out, function(a, b)
            return origin:DistToSqr(a) < origin:DistToSqr(b)
        end)
    end

    return out
end

local function IsPositionSeparated(pos, used, minDistSqr)
    for _, other in ipairs(used) do
        if pos:DistToSqr(other) < minDistSqr then
            return false
        end
    end

    return true
end

local function TryAppendSpawnPosition(list, candidate, used, minDistSqr)
    local openPos = FindGroundedOpenPosition(candidate, PLAYER_HULL_MINS, PLAYER_HULL_MAXS, 2)
    if not openPos then return false end
    if not IsPositionSeparated(openPos, used, minDistSqr) then return false end

    list[#list + 1] = openPos
    used[#used + 1] = openPos

    return true
end

local function PickSpawnAnchor(points, radius)
    local valid = GetValidAreaPoints(points or {}, radius or SPAWN_CLUSTER_RADIUS)
    if #valid > 0 then
        return valid[math.random(#valid)], valid
    end

    local fallback = {}
    for _, pos in ipairs(points or {}) do
        local openPos = FindGroundedOpenPosition(pos, PLAYER_HULL_MINS, PLAYER_HULL_MAXS, 2)
        if openPos then
            fallback[#fallback + 1] = openPos
        end
    end

    if #fallback > 0 then
        return fallback[math.random(#fallback)], fallback
    end

    return nil, {}
end

local function BuildClusterPositions(anchor, count, sourcePoints, fallbackPoints, clusterRadius)
    local positions = {}
    local taken = {}
    local minDistSqr = SPAWN_MIN_SEPARATION * SPAWN_MIN_SEPARATION
    clusterRadius = clusterRadius or SPAWN_CLUSTER_RADIUS

    if count <= 0 then return positions end

    if isvector(anchor) then
        TryAppendSpawnPosition(positions, anchor, taken, minDistSqr)
    end

    local nearbyPoints = SortVectorsByDistance(anchor, sourcePoints or {})
    for _, pos in ipairs(nearbyPoints) do
        if #positions >= count then break end

        if (not isvector(anchor)) or anchor:DistToSqr(pos) <= (clusterRadius * clusterRadius) then
            TryAppendSpawnPosition(positions, pos, taken, minDistSqr)
        end
    end

    if #positions < count and isvector(anchor) then
        for radius = 48, clusterRadius, 48 do
            local step = radius <= 96 and 45 or 30

            for ang = 0, 359, step do
                if #positions >= count then break end

                local rad = math.rad(ang)
                local candidate = anchor + Vector(math.cos(rad) * radius, math.sin(rad) * radius, 0)
                TryAppendSpawnPosition(positions, candidate, taken, minDistSqr)
            end

            if #positions >= count then break end
        end
    end

    if #positions < count then
        local widerPoints = SortVectorsByDistance(anchor, fallbackPoints or {})
        for _, pos in ipairs(widerPoints) do
            if #positions >= count then break end
            TryAppendSpawnPosition(positions, pos, taken, minDistSqr)
        end
    end

    return positions
end

local function TeleportPlayersToCluster(players, anchor, sourcePoints, fallbackPoints, clusterRadius)
    if not istable(players) or #players <= 0 then return end

    local positions = BuildClusterPositions(anchor, #players, sourcePoints, fallbackPoints, clusterRadius)
    if #positions <= 0 then return end

    for i, ply in ipairs(players) do
        if not IsValid(ply) then continue end

        local pos = positions[i] or positions[#positions]
        if not isvector(pos) then continue end

        ply:SetPos(pos)

        if isvector(anchor) then
            local look = anchor - pos
            look.z = 0

            if look:LengthSqr() > 1 then
                ply:SetEyeAngles(look:Angle())
            end
        end
    end
end

local function SetupRoundSpawnGroups(president, bodyguards, citizens)
    local presidentGroup = {}
    if IsValid(president) then
        presidentGroup[#presidentGroup + 1] = president
    end

    for _, ply in ipairs(bodyguards or {}) do
        if IsValid(ply) then
            presidentGroup[#presidentGroup + 1] = ply
        end
    end

    local tPoints, ctPoints = GetTCTSpawnPoints()
    local generalPoints = GetGeneralTaskPoints()

    local presidentAnchor, presidentPool
    local citizenAnchor, citizenPool

    if #ctPoints > 0 and #tPoints > 0 then
        presidentAnchor, presidentPool = PickSpawnAnchor(ctPoints, SPAWN_CLUSTER_RADIUS)
        citizenAnchor, citizenPool = PickSpawnAnchor(tPoints, SPAWN_CLUSTER_RADIUS)
    else
        local generalAnchor, generalPool = PickSpawnAnchor(generalPoints, SPAWN_CLUSTER_RADIUS)
        presidentAnchor = generalAnchor
        presidentPool = generalPool

        if isvector(generalAnchor) and #generalPool > 1 then
            citizenAnchor = GetFarthestPoint(
                generalAnchor,
                generalPool,
                SPAWN_GROUP_MIN_DISTANCE * SPAWN_GROUP_MIN_DISTANCE
            )
        end

        if not isvector(citizenAnchor) then
            citizenAnchor = generalPool[math.random(math.max(#generalPool, 1))]
        end

        citizenPool = generalPool
    end

    TeleportPlayersToCluster(presidentGroup, presidentAnchor, presidentPool, generalPoints, SPAWN_CLUSTER_RADIUS)
    TeleportPlayersToCluster(citizens or {}, citizenAnchor, citizenPool, generalPoints, SPAWN_CLUSTER_RADIUS)
end

local function BuildStayTask()
    local points = GetValidAreaPoints(GetGeneralTaskPoints(), MODE.TaskAreaRadius)
    if #points <= 0 then return nil end

    return {
        kind = "stay",
        pos = points[math.random(#points)],
        radius = MODE.TaskAreaRadius,
        progress = 0
    }
end

local function BuildMoveTask()
    local minRouteSqr = MODE.TaskMinRouteDistance * MODE.TaskMinRouteDistance
    local tPoints = GetValidAreaPoints(select(1, GetTCTSpawnPoints()), MODE.TaskMovePointRadius)
    local ctPoints = GetValidAreaPoints(select(2, GetTCTSpawnPoints()), MODE.TaskMovePointRadius)

    local startPos
    local endPos

    if #tPoints > 0 and #ctPoints > 0 then
        if math.random(2) == 1 then
            startPos = tPoints[math.random(#tPoints)]
            endPos = ctPoints[math.random(#ctPoints)]
        else
            startPos = ctPoints[math.random(#ctPoints)]
            endPos = tPoints[math.random(#tPoints)]
        end

        if startPos:DistToSqr(endPos) < minRouteSqr then
            local fallback = GetFarthestPoint(startPos, math.random(2) == 1 and ctPoints or tPoints, minRouteSqr)
            if fallback then
                endPos = fallback
            end
        end
    else
        local points = GetValidAreaPoints(GetGeneralTaskPoints(), MODE.TaskMovePointRadius)
        if #points < 2 then return nil end

        startPos = points[math.random(#points)]
        endPos = GetFarthestPoint(startPos, points, minRouteSqr)
    end

    if not startPos or not endPos then return nil end
    if startPos:DistToSqr(endPos) < minRouteSqr then return nil end

    return {
        kind = "move",
        posA = startPos,
        posB = endPos,
        reachedA = false,
        radius = MODE.TaskMovePointRadius
    }
end

local function BuildPropTask()
    local props = GetMovableProps()
    local tPoints, ctPoints = GetTCTSpawnPoints()

    local preferredTargets = GetValidAreaPoints(MergeVectors(tPoints, ctPoints), MODE.TaskPropAreaRadius)
    local fallbackTargets = GetValidAreaPoints(GetGeneralTaskPoints(), MODE.TaskPropAreaRadius)

    if #preferredTargets <= 0 and #fallbackTargets <= 0 then
        return nil
    end

    local minDistSqr = MODE.TaskMinPropDistance * MODE.TaskMinPropDistance

    if #props > 0 then
        table.Shuffle(props)

        for _, prop in ipairs(props) do
            local targetPos = GetFarthestPoint(prop:GetPos(), preferredTargets, minDistSqr)
            if not targetPos then
                targetPos = GetFarthestPoint(prop:GetPos(), fallbackTargets, minDistSqr)
            end

            if targetPos then
                return {
                    kind = "prop",
                    targetEnt = prop,
                    pos = targetPos,
                    radius = MODE.TaskPropAreaRadius
                }
            end
        end
    end

    local targetPool = #preferredTargets > 0 and preferredTargets or fallbackTargets
    local spawnCandidates = GetValidAreaPoints(GetGeneralTaskPoints(), 96)
    if #spawnCandidates <= 0 then return nil end

    table.Shuffle(targetPool)

    for _, targetPos in ipairs(targetPool) do
        local spawnPos = GetFarthestPoint(targetPos, spawnCandidates, minDistSqr)
        if spawnPos then
            return {
                kind = "prop",
                targetEnt = NULL,
                pos = targetPos,
                radius = MODE.TaskPropAreaRadius,
                pendingSpawn = true,
                spawnPos = spawnPos,
                spawnModel = PickTaskPropModel(),
                spawnedProp = false
            }
        end
    end

    return nil
end

function MODE.SelectRandomTask()
    local builders = {
        BuildStayTask,
        BuildMoveTask,
        BuildPropTask
    }

    table.Shuffle(builders)

    for _, build in ipairs(builders) do
        local task = build()
        if task then
            return task
        end
    end

    return nil
end

function MODE:GetTaskTargetCount()
    return math.max(self.tasksRequiredCount or 0, 0)
end

function MODE:HasCompletedTaskRequirement()
    return self:GetTaskTargetCount() > 0 and (self.tasksDone or 0) >= self:GetTaskTargetCount()
end

function MODE:GetTaskDisplayName(task)
    if not task then return "" end

    if task.kind == "stay" then
        return "Stay inside the marked area."
    elseif task.kind == "move" then
        return task.reachedA and "Reach point B." or "Reach point A first."
    elseif task.kind == "prop" then
        return "Move the highlighted prop into the marked area."
    end

    return ""
end

function MODE:TaskClearArea()
    for _, task in ipairs(self.taskData or {}) do
        CleanupTaskEntity(task)
    end

    self.taskData = {}
    self.tasksRequiredCount = 0
    self.tasksDone = 0
    self.taskShouldEnd = false
end

function MODE:TaskSync()
    local activeTask = self.taskData[(self.tasksDone or 0) + 1]

    SetNetVar("zp_task_done", self.tasksDone or 0)
    SetNetVar("zp_task_need", self:GetTaskTargetCount())
    SetNetVar("zp_task_shouldend", self.taskShouldEnd or false)
    SetNetVar("zp_task_name", activeTask and self:GetTaskDisplayName(activeTask) or "")
end

local function GetTaskNetInfo(task)
    local info = {
        kind = task.kind,
        pos = task.pos,
        posA = task.posA,
        posB = task.posB,
        radius = task.radius or 0,
        progress = task.progress or 0,
        reachedA = task.reachedA or false,
        staytime = MODE.GetTaskStayTime()
    }

    if IsValid(task.targetEnt) then
        info.targetEnt = task.targetEnt
    end

    return info
end

function MODE:SendTaskToPresident(ply)
    if not IsValid(ply) then return end
    if ply ~= GetPresidentEntity() then return end

    local activeTask = self.taskData[(self.tasksDone or 0) + 1]
    if activeTask and activeTask.kind == "prop" then
        EnsureTaskPropSpawned(activeTask)
    end

    net.Start("president_task")
        net.WriteBool(MODE.GetTasksEnabled() and activeTask ~= nil)
        if activeTask then
            net.WriteTable(GetTaskNetInfo(activeTask))
        end
    net.Send(ply)
end

function MODE:SetupTasks()
    self.taskData = {}
    self.tasksDone = 0
    self.tasksRequiredCount = 0
    self.taskShouldEnd = false

    self:TaskSync()
    BroadcastTaskClear()

    if not MODE.GetTasksEnabled() then
        return
    end

    local president = GetPresidentEntity()
    if not IsValid(president) then return end

    local desired = math.max(MODE.GetTasksWinCondition(), 1)
    local attempts = 0
    local maxAttempts = desired * 12

    while #self.taskData < desired and attempts < maxAttempts do
        attempts = attempts + 1

        local task = MODE.SelectRandomTask()
        if task then
            self.taskData[#self.taskData + 1] = task
        end
    end

    self.tasksRequiredCount = #self.taskData
    self.taskShouldEnd = MODE.GetTasksRequired() and self.tasksRequiredCount > 0 or false

    self:TaskSync()

    if self.tasksRequiredCount <= 0 then
        print("[president] No valid tasks could be generated on this map; tasks are disabled for this round.")
        return
    end

    if self.taskShouldEnd then
        president:ChatPrint("Tasks are REQUIRED this round. Complete " .. self.tasksRequiredCount .. " task(s) to win.")
    else
        president:ChatPrint("Tasks are OPTIONAL this round. Complete " .. self.tasksRequiredCount .. " task(s) for an instant win.")
    end

    self:SendTaskToPresident(president)
end

function MODE:TaskComplete(task)
    if not task then return end
    if self.roundDone then return end

    self.tasksDone = math.min((self.tasksDone or 0) + 1, self:GetTaskTargetCount())
    self:TaskSync()

    local president = GetPresidentEntity()

    if IsValid(president) then
        president:ChatPrint("Task completed! (" .. self.tasksDone .. "/" .. self:GetTaskTargetCount() .. ")")
        president:EmitSound("buttons/button9.wav", 75, 100)
    end

    PrintMessage(HUD_PRINTTALK, "The President completed a task! (" .. self.tasksDone .. "/" .. self:GetTaskTargetCount() .. ")")

    CleanupTaskEntity(task)

    if self:HasCompletedTaskRequirement() then
        self:PresidentTaskWin()
    else
        self:SendTaskToPresident(president)
    end
end

function MODE:PresidentTaskWin()
    if self.roundDone then return end
    if self.presidentTaskWon then return end

    self.presidentTaskWon = true
    self:TaskSync()
    BroadcastTaskClear()

    PrintMessage(HUD_PRINTTALK, "The President completed all required tasks!")
end

function MODE:CheckAlivePlayers()
    local president = {}
    local bodyguards = {}
    local citizens = {}

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if not ply:Alive() then continue end
        if ply.organism and ply.organism.incapacitated then continue end

        if ply == GetPresidentEntity() then
            president[#president + 1] = ply
        elseif ply:Team() == 1 then
            bodyguards[#bodyguards + 1] = ply
        else
            citizens[#citizens + 1] = ply
        end
    end

    return president, bodyguards, citizens
end

function MODE:CanLaunch()
    local activePlayers = 0

    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then
            activePlayers = activePlayers + 1
        end
    end

    return activePlayers >= 3
end

function MODE:RoundStart()
    self.roundDone = false
    self.presidentTaskWon = false
    self.tasksDone = 0
    self.tasksRequiredCount = 0
    self.taskShouldEnd = false
    self.taskData = {}
    self.roundEndAt = CurTime() + (self.ROUND_TIME or MODE.ROUND_TIME or 180)

    BroadcastTaskClear()
    SetNetVar("zp_task_name", "")
    SetNetVar("zp_task_done", 0)
    SetNetVar("zp_task_need", 0)
    SetNetVar("zp_task_shouldend", false)

    local players = GetActiveRoundPlayers(true)
    if #players < 3 then return end

    table.Shuffle(players)

    local president = table.remove(players, 1)
    if not IsValid(president) then return end

    local remaining = #players
    local bodyguardCount = math.Clamp(math.Round(remaining * MODE.BodyguardFraction), 1, math.max(remaining - 1, 1))

    local bodyguards = {}
    local citizens = {}

    for i, ply in ipairs(players) do
        if i <= bodyguardCount then
            bodyguards[#bodyguards + 1] = ply
        else
            citizens[#citizens + 1] = ply
        end
    end

    local shieldCount = math.Clamp(math.Round(#bodyguards * 0.4), 0, #bodyguards)
    local shieldSet = GetRandomSelectionSet(bodyguards, shieldCount)

    SetPresident(president)

    -- VIC (Very Important Chud)
    ResetPlayerInventory(president)
    president:SetupTeam(1)
    president:SetPlayerClass("president")
    president:Give("weapon_hands_sh")
    GiveWeaponFullClip(president, "weapon_p22")
    president:Give("weapon_medkit_sh")
    hg.AddArmor(president, "ent_armor_vest7")
    president:SelectWeapon("weapon_hands_sh")
    president:SetNetVar("CurPluv", "pluvpresident")
    zb.GiveRole(president, "VIC", PRESIDENT_COLOR)

    -- CHUD PROTECTORS (custom VIC SWAT weapon pool)
    for index, ply in ipairs(bodyguards) do
        ResetPlayerInventory(ply)
        ply:SetupTeam(1)
        ply:Give("weapon_hands_sh")
        GiveChudProtectorLoadout(ply)
        ply:SelectWeapon("weapon_hands_sh")
        zb.GiveRole(ply, "Chud Protector", BODYGUARD_COLOR)
    end

    -- ANGRY CHUDS (custom VIC attacker weapon pool)
    for _, ply in ipairs(citizens) do
        ResetPlayerInventory(ply)
        ply:SetupTeam(0)
        ply:Give("weapon_hands_sh")
        GiveAngryChudLoadout(ply)
        ply:SelectWeapon("weapon_hands_sh")
        zb.GiveRole(ply, "Angry Chud", CITIZEN_COLOR)
    end

    SetupRoundSpawnGroups(president, bodyguards, citizens)

    SendRoleIntro(president, "VIC (Very Important Chud)", PRESIDENT_COLOR, "Survive. Your exact objective is being prepared.", true)

    for _, ply in ipairs(bodyguards) do
        SendRoleIntro(ply, "Chud Protector", BODYGUARD_COLOR, "Protect the VIC at all costs.", true)
    end

    for _, ply in ipairs(citizens) do
        SendRoleIntro(ply, "Angry Chud", CITIZEN_COLOR, "Kill the VIC.", true)
    end

    self:SetupTasks()

    PrintMessage(HUD_PRINTTALK, "The VIC has been chosen! Protect him or kill him!")

    local presidentObjective = GetPresidentObjectiveText(self.taskShouldEnd, self:GetTaskTargetCount())

    if self.taskShouldEnd and self:GetTaskTargetCount() > 0 then
        president:ChatPrint("You are the VIC. Survive and complete the required tasks.")
    elseif self:GetTaskTargetCount() > 0 then
        president:ChatPrint("You are the VIC. Survive until the end or complete the tasks for an instant win.")
    else
        president:ChatPrint("You are the VIC. Survive until the round ends.")
    end

    SendRoleIntro(president, "VIC (Very Important Chud)", PRESIDENT_COLOR, presidentObjective, false)
end

function MODE:Intermission()
    game.CleanUpMap()

    self.roundDone = false
    self.presidentTaskWon = false
    self:TaskClearArea()

    SetPresident(NULL)
    BroadcastTaskClear()

    SetNetVar("zp_task_name", "")
    SetNetVar("zp_task_done", 0)
    SetNetVar("zp_task_need", 0)
    SetNetVar("zp_task_shouldend", false)

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        ApplyAppearance(ply)
        ply:SetupTeam(0)
    end

    net.Start("president_intermission")
    net.Broadcast()
end

function MODE:ShouldRoundEnd()
    if self.roundDone then return false end

    local president, bodyguards, citizens = self:CheckAlivePlayers()

    if #president <= 0 then
        return true
    end

    if self.presidentTaskWon then
        return true
    end

    if self.roundEndAt and CurTime() >= self.roundEndAt then
        return true
    end

    if self.taskShouldEnd then
        return false
    end

    if #citizens <= 0 then
        return true
    end

    if #bodyguards <= 0 and #citizens <= 0 then
        return true
    end

    return false
end


function MODE:GetWinner()
    if not IsPresidentAlive() then
        return 0
    end

    if self.presidentTaskWon then
        return 1
    end

    if self.taskShouldEnd then
        return self:HasCompletedTaskRequirement() and 1 or 0
    end

    return 1
end

function MODE:PlayerDeath(ply, inflictor, attacker)
    if MODE.GetTasksEnabled() then
        local president = GetPresidentEntity()
        if IsValid(president) and president:Alive() and (not president.organism or not president.organism.incapacitated) then
            self:SendTaskToPresident(president)
        end
    end
end

function MODE:RoundThink()
    if zb.ROUND_STATE ~= 1 then return end
    if self.roundDone then return end
    if not MODE.GetTasksEnabled() then return end
    if not IsPresidentAlive() then return end

    local president = GetPresidentEntity()
    local activeTask = self.taskData[(self.tasksDone or 0) + 1]
    if not activeTask then
        return
    end

    local now = CurTime()
    activeTask.lastThink = activeTask.lastThink or now

    local dt = math.min(now - activeTask.lastThink, 1)
    activeTask.lastThink = now

    if activeTask.kind == "stay" then
        activeTask.progress = activeTask.progress or 0

        local inside = president:GetPos():DistToSqr(activeTask.pos) <= (activeTask.radius * activeTask.radius)
        if inside then
            activeTask.progress = activeTask.progress + dt
        else
            activeTask.progress = math.max(activeTask.progress - dt * 2, 0)
        end

        if activeTask.progress >= MODE.GetTaskStayTime() then
            self:TaskComplete(activeTask)
            return
        end
    elseif activeTask.kind == "move" then
        local pointRadiusSqr = MODE.TaskMovePointRadius * MODE.TaskMovePointRadius

        if not activeTask.reachedA then
            if president:GetPos():DistToSqr(activeTask.posA) <= pointRadiusSqr then
                activeTask.reachedA = true
                self:TaskSync()
                self:SendTaskToPresident(president)
                president:ChatPrint("Checkpoint reached. Now move to point B.")
            end
        else
            if president:GetPos():DistToSqr(activeTask.posB) <= pointRadiusSqr then
                self:TaskComplete(activeTask)
                return
            end
        end
    elseif activeTask.kind == "prop" then
        if not EnsureTaskPropSpawned(activeTask) then
            local newTask = MODE.SelectRandomTask()
            if newTask then
                self.taskData[(self.tasksDone or 0) + 1] = newTask
                self:TaskSync()
                self:SendTaskToPresident(president)
                president:ChatPrint("The task prop could not be placed safely. A new task has been assigned.")
            end
            return
        end

        if not IsValid(activeTask.targetEnt) then
            local newTask = MODE.SelectRandomTask()
            if newTask then
                self.taskData[(self.tasksDone or 0) + 1] = newTask
                self:TaskSync()
                self:SendTaskToPresident(president)
                president:ChatPrint("The marked prop is gone. A new task has been assigned.")
            end
            return
        end

        local propInZone = activeTask.targetEnt:GetPos():DistToSqr(activeTask.pos) <= (activeTask.radius * activeTask.radius)
        local presidentNearProp = president:GetPos():DistToSqr(activeTask.targetEnt:GetPos()) <= (400 * 400)

        if propInZone and presidentNearProp then
            self:TaskComplete(activeTask)
            return
        end
    end

    activeTask.nextSync = activeTask.nextSync or 0
    if now >= activeTask.nextSync then
        activeTask.nextSync = now + 1
        self:TaskSync()
        self:SendTaskToPresident(president)
    end
end

function MODE:EndRound()
    self.roundDone = true

    local president = GetPresidentEntity()
    local winnerTeam = self:GetWinner()
    local byTasks = self.presidentTaskWon

    local participants = {}
    local winners = {}

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        participants[#participants + 1] = ply

        if winnerTeam == 1 then
            if ply == president or ply:Team() == 1 then
                winners[#winners + 1] = ply
            end
        else
            if ply ~= president and ply:Team() == 0 then
                winners[#winners + 1] = ply
            end
        end
    end

    if winnerTeam == 1 then
        if byTasks then
            PrintMessage(HUD_PRINTTALK, "The President side wins by completing the tasks!")
        else
            PrintMessage(HUD_PRINTTALK, "The President side wins!")
        end
    else
        PrintMessage(HUD_PRINTTALK, "Angry Chuds win! The VIC has failed.")
    end

    net.Start("president_end")
        net.WriteEntity(IsValid(president) and president or NULL)
        net.WriteBool(winnerTeam == 1)
        net.WriteBool(byTasks)
    net.Broadcast()

    timer.Simple(ROUND_RESULTS_DELAY, function()
        for _, ply in ipairs(participants) do
            if not IsValid(ply) then continue end

            if winnerTeam == 1 then
                if ply == president or ply:Team() == 1 then
                    if ply.GiveExp then ply:GiveExp(math.random(150, 200)) end
                    if ply.GiveSkill then ply:GiveSkill(math.Rand(0.2, 0.3)) end
                else
                    if ply.GiveSkill then ply:GiveSkill(-math.Rand(0.05, 0.1)) end
                end
            else
                if ply ~= president and ply:Team() == 0 then
                    if ply.GiveExp then ply:GiveExp(math.random(150, 200)) end
                    if ply.GiveSkill then ply:GiveSkill(math.Rand(0.2, 0.3)) end
                else
                    if ply.GiveSkill then ply:GiveSkill(-math.Rand(0.05, 0.1)) end
                end
            end
        end

        hook.Run("hg.RoundEnd", participants, winners)
    end)

    BroadcastTaskClear()
    SetNetVar("zp_task_name", "")
    SetNetVar("zp_task_shouldend", false)
    self:TaskClearArea()
end

function MODE:GiveWeapons() end
function MODE:GiveEquipment() end
function MODE:CanSpawn() end

hook.Add("PlayerDisconnected", "president_disconnect", function(ply)
    if zb.CROUND ~= "president" then return end
    if zb.ROUND_STATE ~= 1 then return end

    if ply == GetPresidentEntity() then
        SetPresident(NULL)
        MODE:TaskClearArea()
        BroadcastTaskClear()

        SetNetVar("zp_task_name", "")
        SetNetVar("zp_task_done", 0)
        SetNetVar("zp_task_need", 0)
        SetNetVar("zp_task_shouldend", false)

        PrintMessage(HUD_PRINTTALK, "The President disconnected!")
    end
end)
