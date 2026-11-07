local MODE = MODE

MODE.name = "zzombies"
MODE.PrintName = "Z-Zombies"
MODE.Chance = 0.02

-- Pre-round time before Phase One. The 7 second startup screen plays inside this.
local FIRST_PREROUND = 8
MODE.start_time = FIRST_PREROUND

-- Phase timing is fixed by the mode, unaffected by an old archived console value.
-- One large tablet-style supply crate is delivered each cooldown.

util.AddNetworkString("zzombies_start")
util.AddNetworkString("zzombies_popup")
util.AddNetworkString("zzombies_guard_intro")
util.AddNetworkString("zzombies_heli")
util.AddNetworkString("zzombies_zones")

resource.AddFile("sound/zzombies/theme.mp3")
resource.AddFile("sound/zzombies/guard_intro.mp3")
resource.AddFile("sound/zzombies/helicopter.mp3")

local POPUP_CENTER = 0
local POPUP_TOPRIGHT = 1
local POPUP_ALERT = 2


local function ModeActive()
	return zb.CROUND == MODE.name
end

-- target can be a player, a list of players, or nil for everyone.
local function SendPopup(text, duration, position, target)
	net.Start("zzombies_popup")
		net.WriteString(text)
		net.WriteFloat(duration)
		net.WriteUInt(position, 2)

	if target then net.Send(target) else net.Broadcast() end
end

local function GetPoints(group)
	local pts = zb.GetMapPoints(group)
	if not pts then return {} end

	return zb.TranslatePointsToVectors(pts)
end

-- Survivors are team 0. The National Guard are team 1.
local function AliveSurvivors()
	local list = {}

	for _, ply in player.Iterator() do
		if ply:Team() == 0 and ply:Alive() and not ply.ZZ_Extracted and not ZZIsZombie(ply) then
			list[#list + 1] = ply
		end
	end

	return list
end

-- Zombies may killbind; survivors retain the existing restriction.
hook.Add("CanPlayerSuicide", "ZZombies_NoSuicide", function(ply)
	if ModeActive() then
        if ZZIsZombie and ZZIsZombie(ply) then return true end
		ply:ChatPrint("No thanks buster")
		return false
	end
end)

--------------------------------------------------------------------------------
-- Loot
--
-- No loose items and no crates are spawned during the phases. Loot only comes out of
-- the searchable containers that are already on the map (plus the supply boxes dropped
-- during cooldowns, see below), using separate map and supply pools. Firearms are rarer than melee weapons.
--------------------------------------------------------------------------------

MODE.LootSpawn = false -- turns off the periodic loot/crate spawner

-- Lets the map's searchable containers (the same models the normal loot system uses)
-- generate loot even though LootSpawn is off.
MODE.Lootables = setmetatable({}, {
	__index = function(_, model)
		if not isstring(model) or not hg or not hg.loot_boxes then return nil end

		return hg.loot_boxes[string.lower(model)] and true or nil
	end
})

-- Separate map and supply-crate weapon pools. Group weights keep firearms rare
-- even when the firearm list contains more entries than the melee list.
local MAP_MELEE = {"weapon_pocketknife", "weapon_hg_shovel", "weapon_hg_sledgehammer", "weapon_hg_tonfa", "weapon_hg_machete", "weapon_pan", "weapon_hg_spear", "weapon_hammer", "weapon_hg_axe", "weapon_hg_extinguisher", "weapon_hg_crowbar", "weapon_buck200knife", "weapon_brick", "weapon_bat", "weapon_metalbat"}
local MAP_GUNS = {"weapon_px4beretta", "weapon_browninghp", "weapon_cz75", "weapon_p22", "weapon_makarov", "weapon_pm9", "weapon_revolver2", "weapon_tokarev", "weapon_dracovska", "weapon_doublebarrel", "weapon_remington870_long", "weapon_doublebarrel_short", "weapon_remington870_sawed_off", "weapon_kar98", "weapon_mosin", "weapon_skorpion", "weapon_mac11", "weapon_uzi", "weapon_mini14", "weapon_ruger", "weapon_hg_crossbow", "weapon_hg_bow", "weapon_sks", "weapon_akmwreked"}
local CRATE_MELEE = {"weapon_combatknife", "weapon_sogknife"}
local CRATE_GUNS = {"weapon_sr25", "weapon_xm1014", "weapon_fn45", "weapon_m45", "weapon_m249", "weapon_mp5", "weapon_p90", "weapon_vector", "weapon_mp7", "weapon_ar15", "weapon_ak200", "weapon_hk416"}
local SUPPLIES = {
    {0.1, "weapon_xdebarricade"},
    {1, "weapon_zz_antidote"}, {2, "weapon_zz_recovery_pills"},
    {1.2, "ent_armor_vest1"}, {1.2, "ent_armor_mask2"},
    {0.6, "ent_armor_helmet6"}, {1.2, "ent_armor_mask3"}, {1.2, "ent_armor_helmet2"},
    {7, "weapon_bandage_sh"}, {3.5, "weapon_bigbandage_sh"},
    {4, "weapon_tourniquet"}, {5, "weapon_ducttape"}, {2, "weapon_needle"},
    {1.2, "weapon_medkit_sh"}, {1.2, "weapon_morphine"},
    {1, "weapon_adrenaline"}, {1, "weapon_naloxone"},
    {0.6, "weapon_mannitol"}, {0.4, "weapon_fentanyl"}
}
local function Registered(class)
    return weapons.GetStored(class) or scripted_ents.GetStored(class)
end
local function AddGroup(pool, classes, weight)
    local available = {}
    for _, class in ipairs(classes) do
        if Registered(class) then available[#available + 1] = class end
    end
    for _, class in ipairs(available) do
        pool[#pool + 1] = {weight / #available, class}
    end
end
local function MatchingAmmo()
    local result, seen = {}, {}
    -- Include ammo for both pools so crate weapons can be resupplied around the map.
    for _, group in ipairs({MAP_MELEE, MAP_GUNS, CRATE_GUNS}) do
        for _, class in ipairs(group) do
            local weapon = weapons.Get(class)
            if weapon then
                local ammo = weapon.Primary and weapon.Primary.Ammo
                if not ammo or ammo == "none" then ammo = weapon.Ammo end -- bow uses Arrow
                local data = hg.ammotypeshuy and hg.ammotypeshuy[ammo]
                local key = data and data.name
                if not key and isstring(ammo) then key = string.lower(string.Replace(ammo, " ", "")) end
                local entity = key and ("ent_ammo_" .. key)
                if entity and scripted_ents.GetStored(entity) and not seen[entity] then
                    seen[entity] = true
                    result[#result + 1] = entity
                end
            end
        end
    end
    return result
end
local function BuildLootPool(supply, phase)
    phase = math.Clamp(tonumber(phase) or 1, 1, 3)
    local pool = {}
    AddGroup(pool, supply and CRATE_MELEE or MAP_MELEE, 36)
    AddGroup(pool, supply and CRATE_GUNS or MAP_GUNS, supply and ({6, 8, 12})[phase] or 6)
    AddGroup(pool, MatchingAmmo(), supply and ({20, 24, 28})[phase] or 24)
    for _, entry in ipairs(SUPPLIES) do
        if Registered(entry[2]) then
            local weight = entry[1]
            if supply and phase > 1 then
                if entry[2] == "weapon_medkit_sh" or string.StartWith(entry[2], "ent_armor_") then
                    weight = weight * phase
                end
            end
            pool[#pool + 1] = {weight, entry[2]}
        end
    end
    if not supply then
        local total = 0
        for _, entry in ipairs(pool) do total = total + entry[1] end
        pool[#pool + 1] = {total * 0.25, false} -- Keep the existing 20% empty-roll chance.
    end
    return pool
end
function MODE:GetLootTable()
    return BuildLootPool(false, 1)
end
local function GetSupplyLootTable(mode)
    return BuildLootPool(true, mode.Phase)
end

--------------------------------------------------------------------------------
-- Supply boxes
--
-- The only boxes that are spawned. They drop during cooldowns, never during an active
-- phase, and are searched like any other container.
--------------------------------------------------------------------------------

local function FindDropPos()
    local points = GetPoints("zzombiessupply")
    if #points == 0 then return nil end
    local first = math.random(#points)
    for offset = 0, #points - 1 do
        local point = points[(first + offset - 1) % #points + 1]
        local ground = util.TraceLine({
            start = point + Vector(0, 0, 64),
            endpos = point - Vector(0, 0, 256),
            mask = MASK_SOLID_BRUSHONLY
        })
        if ground.Hit and not ground.StartSolid and ground.HitNormal.z >= 0.7 then
            local landing = ground.HitPos + Vector(0, 0, 64)
            local rise = util.TraceHull({
                start = landing,
                endpos = landing + Vector(0, 0, 1200),
                mins = Vector(-48, -48, -48),
                maxs = Vector(48, 48, 48),
                mask = MASK_SOLID
            })
            local height = rise.Fraction * 1200 - 16
            if not rise.StartSolid and height >= 192 then
                local pos = landing + Vector(0, 0, height)
                if util.IsInWorld(pos) then return pos end
            end
        end
    end
    return nil
end

local function DropSupplyBox()
    local pos = FindDropPos()
    if not pos then return false end

    local box = ents.Create("zbox_lootbox")
    if not IsValid(box) then return false end
    box.Model = "models/props_junk/wood_crate002a.mdl"
    box:SetModel(box.Model)
    box:SetMaterial("models/mat_jack_aidbox")
    box:SetPos(pos)
    box:SetAngles(Angle(0, 0, 0))
    box:Spawn()
    box:Activate()
    -- The container initializes physics before its model; rebuild for the large crate.
    box:PhysicsInit(SOLID_VPHYSICS)
    box:SetMoveType(MOVETYPE_VPHYSICS)
    box:SetSolid(SOLID_VPHYSICS)
    local phys = box:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(75)
        phys:EnableMotion(true)
        phys:EnableGravity(true)
        phys:Wake()
        phys:SetVelocity(Vector(0, 0, -100))
    end
    box.ZZ_Supply = true
    box.CanGenerate = false
    box.Loot = {}

    local pool, total = {}, 0
    for _, entry in ipairs(GetSupplyLootTable(MODE)) do
        local class = entry[2]
        if isstring(class) and (weapons.GetStored(class) or scripted_ents.GetStored(class)) then
            total = total + entry[1]
            pool[#pool + 1] = {total, class}
        end
    end
    -- Exactly ten random items; antidote and recovery pills are not guaranteed.
    local count = 10
    for i = #box.Loot + 1, count do
        local roll = math.Rand(0, total)
        for _, entry in ipairs(pool) do
            if roll <= entry[1] then
                box.Loot[#box.Loot + 1] = {class = entry[2]}
                break
            end
        end
    end
    return true
end

local function StartSupplyDrop()
    if #GetPoints("zzombiessupply") == 0 then
        SendPopup("Supply drop unavailable: place a zzombiessupply ZPoint.", 8, POPUP_TOPRIGHT)
        return
    end
    local cooldownEnd = GetGlobalFloat("ZZ_CooldownEnd", 0)
    local function Deliver()
        if not ModeActive() or zb.ROUND_STATE ~= 1 then return end
        if GetGlobalFloat("ZZ_CooldownEnd", 0) ~= cooldownEnd or CurTime() >= cooldownEnd then return end
        -- Retry only when no clear landing spot was found; stop after one crate.
        if not DropSupplyBox() then timer.Simple(1, Deliver) end
    end
    timer.Simple(1, Deliver)
end

--------------------------------------------------------------------------------
-- Extraction and the National Guard (last phase)
--
-- The last phase has a 2 minute countdown. When it ends:
--   1. the helicopter is heard, everyone else gets "GET TO THE EXTRACTION!!!" and the
--      extraction zones (zzombiesextraction points) show up,
--   2. up to 5 spectators are picked as the National Guard and get their own intro
--      (black screen, typed text, their model spinning, their song) for 10 seconds,
--   3. when the intro is over the guard spawns like in homicide, and the survivors have
--      2 minutes to extract (timer in the top right).
-- To extract, stand inside a zone for 10 seconds. Extracted survivors spectate.
--------------------------------------------------------------------------------

-- Same rank odds the National Guard class uses for its names.
local RANKS = {
	{"PVT", 25}, {"PV2", 20}, {"PFC", 18}, {"SPC", 12}, {"CPL", 8}, {"SGT", 7}, {"SSG", 4},
	{"SFC", 2.5}, {"MSG", 1.2}, {"1SG", 0.8}, {"SGM", 0.5}, {"CSM", 0.3}, {"SMA", 0.1},
	{"2LT", 0.3}, {"1LT", 0.2}, {"CPT", 0.08}, {"MAJ", 0.02}
}

local function PickRank()
	local total = 0
	for _, r in ipairs(RANKS) do total = total + r[2] end

	local roll = math.Rand(0, total)

	for _, r in ipairs(RANKS) do
		roll = roll - r[2]
		if roll <= 0 then return r[1] end
	end

	return "PVT"
end

local function EquipGuard(ply, index)
	local hmcd = zb.modes and zb.modes["hmcd"]

	-- Same loadout the homicide National Guard gets.
	if hmcd and hmcd.EquipNationalGuard and pcall(hmcd.EquipNationalGuard, hmcd, ply, index) then
		return
	end

	ply:SetPlayerClass("nationalguard")

	local gun = ply:Give("weapon_m4a1")
	if IsValid(gun) then
		ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
	end

	ply:Give("weapon_hands_sh")
	zb.GiveRole(ply, "National Guard", Color(60, 90, 0))
end

-- Players who can be pulled in as guard: dead, not spectating on purpose, not AFK.
local function EligibleGuards()
	local list = {}

	for _, ply in player.Iterator() do
		if not ply:Alive() and not ZZIsZombie(ply) and ply:Team() ~= TEAM_SPECTATOR and (ply.afkTime2 or 0) <= 60 then
			list[#list + 1] = ply
		end
	end

	return list
end

-- Reserve before killing so death hooks cannot offer a zombie respawn.
local function ReserveGuard(ply)
    ply.ZZGuardReserved = true
    if ply:Alive() then ply:KillSilent() end
    ZZClearZombie(ply)
    ply:SetNWBool("ZZZombieCanChoose", false)
    ply:SetNWString("ZZZombieSelectedClass", "")
    ply.ZZZombieChoicePending = nil
end

-- Two seconds before the arrival: pick the guard and start their intro (music first).
local function PrepareGuards(mode, eta)
	local list = {}
	local forced = mode.TestCaller
	mode.TestCaller = nil

	-- The admin test always includes whoever ran it.
	if IsValid(forced) then
		ReserveGuard(forced)
		list[#list + 1] = forced
	end

	for _, ply in RandomPairs(EligibleGuards()) do
		if #list >= mode.GuardMax then break end
		if ply ~= forced then ReserveGuard(ply) list[#list + 1] = ply end
	end

    -- Use dead zombies first, then sacrifice only enough living zombies to fill vacancies.
    for _, alive in ipairs({false, true}) do
        local candidates = {}
        for _, ply in player.Iterator() do
            if ZZIsZombie(ply) and ply:Alive() == alive and not ply.ZZGuardReserved
                and ply:Team() ~= TEAM_SPECTATOR and not ply.ZZ_Extracted and not ply.ZZExfilBoarded
                and not ply:IsBot() and (ply.afkTime2 or 0) <= 60 then
                candidates[#candidates + 1] = ply
            end
        end
        for _, ply in RandomPairs(candidates) do
            if #list >= mode.GuardMax then break end
            ReserveGuard(ply)
            list[#list + 1] = ply
        end
    end

	mode.GuardList = list

	print(string.format("[Z-Zombies] National Guard picked: %d player(s)", #list))

	for _, ply in ipairs(list) do
		net.Start("zzombies_guard_intro")
			net.WriteFloat(eta)
			net.WriteFloat(mode.GuardIntroDuration)
			net.WriteString(PickRank())
			net.WriteUInt(math.random(1, 9), 4)
		net.Send(ply)
	end
end

-- Tells clients where the extraction zones are so they can draw them.
local function SendZones(target)
	local points = MODE.GroundExtraction and GetPoints("zzombiesgroundextraction")
        or (MODE.ExfilPoint and {MODE.ExfilPoint} or GetPoints("zzombiesextraction"))
	local count = math.min(#points, 255)

	net.Start("zzombies_zones")
		net.WriteFloat(MODE.ExtractionRadius)
		net.WriteUInt(count, 8)

		for i = 1, count do
			net.WriteVector(points[i])
		end

	if target then net.Send(target) else net.Broadcast() end
end

local function ExtractionOpen()
	local eta = GetGlobalFloat("ZZ_ExtractETA", 0)

	return eta > 0 and CurTime() >= eta
end

-- Someone who joins while extraction is open still needs to see the zones.
hook.Add("PlayerInitialSpawn", "ZZombies_SendZones", function(ply)
	timer.Simple(6, function()
		if IsValid(ply) and ModeActive() and ExtractionOpen() then
			SendZones(ply)
		end
	end)
end)

-- The helicopter arrives: everyone who isn't going to be guard hears it and is told to run.
local function AnnounceExtraction(mode)
	local guards = {}
	for _, ply in ipairs(mode.GuardList or {}) do
		guards[ply] = true
	end

	local targets = {}
	for _, ply in player.Iterator() do
		if not guards[ply] then
			targets[#targets + 1] = ply
		end
	end

	SendZones()

	if #targets == 0 then return end

	print(mode.GroundExtraction and "[Z-Zombies] Ground extraction available." or "[Z-Zombies] Helicopter extraction available.")

	-- Helicopter arrival is silent; no imported exfil audio.

	SendPopup("GET TO THE EXTRACTION!!!", 5, POPUP_ALERT, targets)
end

-- The intro is over: spawn the guard the same way homicide does, then start the clock.
local function SpawnGuards(mode)
	local points = GetPoints("zzombiesguard")
	local basePos = (#points > 0) and points[math.random(#points)] or nil
	local spawned = 0

	for i, ply in ipairs(mode.GuardList or {}) do
		if not IsValid(ply) or ply:Alive() or ZZIsZombie(ply) or ply:Team() == TEAM_SPECTATOR then continue end

		ply.ZZ_Extracted = nil
		ply.isPolice = true
		ply.isTraitor = false
		ply.isGunner = false

		ply:Spawn()
		ply:SetTeam(1)

		if not basePos then
			basePos = zb:GetRandomSpawn()
			ply:SetPos(basePos)
		elseif spawned == 0 then
			ply:SetPos(basePos)
		else
			hg.tpPlayer(basePos, ply, i)
		end

		EquipGuard(ply, spawned + 1)
        ply.ZZGuardReserved = nil

		spawned = spawned + 1
	end

	print(string.format("[Z-Zombies] National Guard spawned: %d player(s)", spawned))

	PrintMessage(HUD_PRINTTALK, "National Guard have arrived.")
	local deadline = CurTime() + mode.ExtractionWindow
	local phaseEnd = GetGlobalFloat("ZZ_PhaseEnd", 0)
	if not mode.TestGuardUntil and phaseEnd > 0 then deadline = phaseEnd end
	SetGlobalFloat("ZZ_ExtractDeadline", deadline)
end

-- Runs the arrival in order: pick + intro, helicopter, spawn.
local function UpdateGuardSequence(mode)
	local eta = GetGlobalFloat("ZZ_ExtractETA", 0)
	if eta <= 0 then return end

	local now = CurTime()

	if not mode.GuardPrepared and now >= eta - mode.GuardPreroll then
		mode.GuardPrepared = true
		PrepareGuards(mode, eta)
	end

	if not mode.GuardAnnounced and now >= eta then
		mode.GuardAnnounced = true
		AnnounceExtraction(mode)
	end

	if not mode.GuardSpawned and now >= eta + mode.GuardIntroDuration then
		mode.GuardSpawned = true
		SpawnGuards(mode)
	end
end

-- Where someone's body is: their ragdoll if they are knocked down, otherwise the player.
local function BodyOf(ply)
	local body = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)

	if IsValid(body) then return body end

	return ply
end

local function ExtractPlayer(mode, ply)
    if ply.ZZ_Extracted then return end
	mode.Extracted = (mode.Extracted or 0) + 1
	ply.ZZ_Extracted = true
	ply.ZZ_ExtractStart = nil
	ply:SetNetVar("ZZ_ExtractStart", 0)

	local body = BodyOf(ply)

    ply.ZZExfilPreviousTeam = ply:Team()
    ply:SetNWBool("ZZExfilSurvivor", true)
    ply.ZZZombieChoicePending = nil
    ply:SetNWBool("ZZZombieCanChoose", false)
    ply:SetNWString("ZZZombieSelectedClass", "")
    if ZZInfection and ZZInfection.Clear then ZZInfection.Clear(ply) end
    ply:Freeze(false)
    ply.chosenSpectEntity, ply.lastSpectTarget = nil, nil
    ply.viewmode = 3
    ply:SetNWEntity("spect", NULL)
    ply:SetNWInt("viewmode", 3)
    ply:SetTeam(TEAM_SPECTATOR)
    ply:StripWeapons()
    ply.ZZGuardReserved = true
    local deaths = ply:Deaths()
    ply:KillSilent()
    ply:SetDeaths(deaths)
    ply.ZZGuardReserved = nil
    local function RemoveExtractionBody()
        if not IsValid(ply) or ply:Alive() or not ply.ZZ_Extracted then return end
        local bodies = {body, ply.RagdollDeath, ply.FakeRagdoll,
            ply:GetNWEntity("RagdollDeath"), ply:GetNWEntity("FakeRagdoll")}
        for _, rag in pairs(bodies) do
            if IsValid(rag) and not rag:IsPlayer() then
                rag.hg_no_fullbody_remove_gib = true
                rag.override = true
                rag:SetNWEntity("ply", NULL)
                rag:Remove()
            end
        end
        ply.RagdollDeath, ply.FakeRagdoll = nil, nil
        ply:SetNWEntity("RagdollDeath", NULL)
        ply:SetNWEntity("FakeRagdoll", NULL)
        if hg.ragdollFake then hg.ragdollFake[ply] = nil end
    end
    RemoveExtractionBody()
    timer.Simple(0, RemoveExtractionBody)
    ply:SpectateEntity(NULL)
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SetMoveType(MOVETYPE_NOCLIP)
    ply:SetNoDraw(true)
    ply:SetNotSolid(true)
    zb.GiveRole(ply, "Survivor", Color(90, 200, 110))

    if #AliveSurvivors() == 0 then
        mode.AllSurvivorsExtracted = true
        mode.OperationFailed = false
    end
	SendPopup(ply:Nick() .. " has extracted", 5, POPUP_CENTER)
end

function MODE:ExtractHelicopterPassenger(ply)
    if ZZExfil.IsSurvivor(ply) then ExtractPlayer(self, ply) end
end

local function UpdateGroundExtraction(mode)
    local points = GetPoints("zzombiesgroundextraction")
    local deadline = GetGlobalFloat("ZZ_ExtractDeadline", 0)
    local open = ExtractionOpen() and (deadline <= 0 or CurTime() < deadline)
    for _, ply in player.Iterator() do
        local zone
        if open and ply:Alive() and ply:Team() == 0 and not ply.ZZ_Extracted
            and not ZZIsZombie(ply) and not ply:InVehicle() then
            local body = BodyOf(ply)
            for index, point in ipairs(points) do
                local delta = body:GetPos() - point
                if delta:Length2DSqr() <= mode.ExtractionRadius ^ 2 and math.abs(delta.z) <= 72
                    and not util.TraceLine({start = body:WorldSpaceCenter(), endpos = point + Vector(0, 0, 32),
                        mask = MASK_SOLID_BRUSHONLY, filter = {ply, body}}).Hit then
                    zone = index
                    break
                end
            end
        end
        if not zone then
            ply.ZZ_ExtractStart, ply.ZZ_GroundZone = nil, nil
            ply:SetNetVar("ZZ_ExtractStart", 0)
        else
            if ply.ZZ_GroundZone ~= zone or not ply.ZZ_ExtractStart then
                ply.ZZ_GroundZone = zone
                ply.ZZ_ExtractStart = CurTime()
                ply:SetNetVar("ZZ_ExtractStart", ply.ZZ_ExtractStart)
            end
            if CurTime() - ply.ZZ_ExtractStart >= mode.ExtractionHold then
                ply.ZZ_GroundZone = nil
                ExtractPlayer(mode, ply)
            end
        end
    end
end

local function UpdateExtraction(mode)
    if mode.GroundExtraction then UpdateGroundExtraction(mode) return end
    if not ExtractionOpen() or IsValid(mode.ExfilHelicopter) then return end
    if (mode.NextExfilAttempt or 0) > CurTime() then return end
    mode.NextExfilAttempt = CurTime() + 5
    local deadline = GetGlobalFloat("ZZ_ExtractDeadline", 0)
    if deadline > 0 and CurTime() >= deadline then return end
    local survivors = AliveSurvivors()
    if #survivors == 0 then return end
    local points = GetPoints("zzombiesextraction")
    if #points == 0 then return end
    mode.ExfilPoint = mode.ExfilPoint or points[1]
    local heli = ZZExfil.Spawn(mode, mode.ExfilPoint, #survivors)
    if IsValid(heli) then SendZones() end
end

--------------------------------------------------------------------------------
-- Round flow
--
-- One round, three phases. A phase finishing does NOT end the round: nobody is
-- respawned and nothing is cleaned up, so players keep everything they have. After
-- Phase One and Phase Two there is a cooldown, then the next phase begins. The last phase
-- ends through extraction. The round ends once no survivor is left in the field (all
-- extracted or dead) or the 2 minute extraction window runs out.
--------------------------------------------------------------------------------

function MODE:CheckAlivePlayers()
	return {AliveSurvivors()}
end

-- Hot reloads or switching modes mid-round can leave runtime fields unset.
-- Restore the phase from replicated state without restarting an existing deadline.
local function EnsurePhaseState(mode)
    local function Positive(value, fallback)
        value = tonumber(value)
        if not value or value ~= value or value <= 0 or value == math.huge then return fallback end
        return value
    end
    mode.PhaseCount = math.max(1, math.floor(Positive(mode.PhaseCount, 3)))
    mode.PhaseDuration = Positive(mode.PhaseDuration, 300)
    mode.PhaseCooldown = Positive(mode.PhaseCooldown, 60)
    mode.GuardIntroDuration = Positive(mode.GuardIntroDuration, 10)
    mode.ExtractionWindow = Positive(mode.ExtractionWindow, 120)
    mode.Phase = math.Clamp(math.floor(Positive(mode.Phase,
        Positive(GetGlobalInt("ZZ_Phase", 1), 1))), 1, mode.PhaseCount)
end

-- A phase is now running.
local function StartPhaseTimer(mode)
    EnsurePhaseState(mode)
	local now = CurTime()

	mode.PhaseActive = true

	SetGlobalInt("ZZ_Phase", mode.Phase)
	SetGlobalFloat("ZZ_RoundStart", now)
	SetGlobalFloat("ZZ_PhaseEnd", now + mode.PhaseDuration)
	SetGlobalFloat("ZZ_CooldownEnd", 0)

	-- Last phase: the helicopter is on its way.
	if mode.Phase >= mode.PhaseCount then
		mode.GuardPrepared = false
		mode.GuardAnnounced = false
		mode.GuardSpawned = false
		mode.GuardList = {}

		SetGlobalFloat("ZZ_ExtractDeadline", 0)
		SetGlobalFloat("ZZ_ExtractETA", now + mode.PhaseDuration - mode.GuardIntroDuration - mode.ExtractionWindow)
	end
end

-- A phase was cleared: supplies come in and the next phase counts down. ZZ_Phase already
-- shows the upcoming phase so the cooldown UI can name it.
local function StartCooldown(mode)
	mode.PhaseActive = false
	mode.Phase = mode.Phase + 1

	SetGlobalInt("ZZ_Phase", mode.Phase)
	SetGlobalFloat("ZZ_PhaseEnd", 0)
	SetGlobalFloat("ZZ_CooldownEnd", CurTime() + mode.PhaseCooldown)

    local ok, err = pcall(function()
	SendPopup("The government has sent you supplies from the air. Good luck!", 8, POPUP_TOPRIGHT)
	EmitSound("snd_jack_hmcd_heli2.mp3", vector_origin, 0, CHAN_AUTO, 1, 125, 0, 100)

	StartSupplyDrop()
    end)
    if not ok then ErrorNoHalt("[Z-Zombies] Supply drop failed: " .. tostring(err) .. "\n") end
end

-- Keep the phase clock independent of guard/extraction updates and the shared
-- round Think timer. Both callers use the same deadlines, so a transition can
-- happen only once even if they run on the same frame.
local function AdvancePhaseClock(mode)
    EnsurePhaseState(mode)
    local now = CurTime()
    local cooldownEnd = GetGlobalFloat("ZZ_CooldownEnd", 0)
    if cooldownEnd > 0 then
        if now >= cooldownEnd then StartPhaseTimer(mode) end
        return true
    end
    local phaseEnd = GetGlobalFloat("ZZ_PhaseEnd", 0)
    if phaseEnd <= 0 then
        StartPhaseTimer(mode)
        phaseEnd = GetGlobalFloat("ZZ_PhaseEnd", 0)
    end
    if mode.Phase < mode.PhaseCount then
        if mode.SkipPhase or (phaseEnd > 0 and now >= phaseEnd) then
            mode.SkipPhase = false
            StartCooldown(mode)
        end
        return true
    end
    return false
end

local nextPhaseCheck = 0
hook.Add("Think", "ZZombiesPhaseClock", function()
    if CurTime() < nextPhaseCheck then return end
    nextPhaseCheck = CurTime() + 0.1
    if not ModeActive() or zb.ROUND_STATE ~= 1 then return end
    local mode = CurrentRound()
    if not mode or mode.name ~= "zzombies" then return end
    AdvancePhaseClock(mode)
end)

-- Tells admins when a point group the mode needs hasn't been set on this map.
local function WarnMissingPoints()
	local missing = {}

	if #GetPoints("zzombiesextraction") == 0 and #GetPoints("zzombiesgroundextraction") == 0 then
		missing[#missing + 1] = "zzombiesextraction (there will be no extraction zone)"
	end

	if #GetPoints("zzombiesguard") == 0 then
		missing[#missing + 1] = "zzombiesguard (the National Guard will use a random spawn)"
	end

	if #missing == 0 then return end

	local msg = "[Z-Zombies] No points set for: " .. table.concat(missing, "; ") .. ". Use the zbattle toolgun."
	print(msg)

	for _, ply in player.Iterator() do
		if ply:IsAdmin() then ply:ChatPrint(msg) end
	end
end

function MODE:Intermission()
    EnsurePhaseState(self)
    self.GroundExtraction = #GetPoints("zzombiesgroundextraction") > 0
    SetGlobalBool("ZZ_GroundExtraction", self.GroundExtraction)
    if IsValid(self.ExfilHelicopter) then self.ExfilHelicopter:Remove() end
    self.ExfilHelicopter, self.ExfilPoint, self.NextExfilAttempt = nil, nil, nil
    SetGlobalEntity("ZZ_ExfilHelicopter", NULL)
	for _, ply in player.Iterator() do ply.ZZGuardReserved = nil ZZClearZombie(ply) end
	game.CleanUpMap()

	self.Phase = 1
	self.PhaseActive = false
	self.OperationFailed = false
	self.TimeUp = false
	self.SkipPhase = false
	self.GuardPrepared = false
	self.GuardAnnounced = false
	self.GuardSpawned = false
	self.GuardList = {}
	self.TestCaller = nil
	self.TestGuardUntil = nil
	self.Extracted = 0
    self.AllSurvivorsExtracted = false

	for _, ply in player.Iterator() do
		ply.ZZ_Extracted = nil
		ply.ZZ_ExtractStart = nil
		ply:SetNetVar("ZZ_ExtractStart", 0)
	end

	-- Three five-minute phases and two one-minute preparation periods.
	self.ROUND_TIME = self.PhaseCount * self.PhaseDuration + (self.PhaseCount - 1) * self.PhaseCooldown

	zb.START_TIME = CurTime() + FIRST_PREROUND
	hg.UpdateRoundTime(self.ROUND_TIME, CurTime(), zb.START_TIME)

	SetGlobalInt("ZZ_Phase", 1)
	SetGlobalFloat("ZZ_PhaseStart", CurTime())
	SetGlobalFloat("ZZ_RoundStart", 0)
	SetGlobalFloat("ZZ_PhaseEnd", 0)
	SetGlobalFloat("ZZ_CooldownEnd", 0)
	SetGlobalFloat("ZZ_ExtractETA", 0)
	SetGlobalFloat("ZZ_ExtractDeadline", 0)
end

-- One player starts as a player-controlled zombie.
function MODE:GiveEquipment()
	local candidates = {}

	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			candidates[#candidates + 1] = ply
		end
	end

	if #candidates == 0 then return end

	local humans = {}
	for _, ply in ipairs(candidates) do
		if not ply:IsBot() then humans[#humans + 1] = ply end
	end
	local first = ChudTakeNextModeRole and ChudTakeNextModeRole("infector", candidates)
    if not IsValid(first) then first = #humans > 0 and humans[math.random(#humans)] or nil end

    local builders = {}
	for _, ply in ipairs(candidates) do
		ply:SetupTeam(0)

		if ply == first then
			zb.GiveRole(ply, "Infected", Color(190, 30, 30))
			ZZApplyZombieClass(ply, "shambler", true, true)
		else
			zb.GiveRole(ply, "Survivor", Color(90, 200, 110))
            if ply:Alive() then builders[#builders + 1] = ply end
		end

		net.Start("zzombies_start")
			net.WriteBool(ply == first)
		net.Send(ply)
	end
    for i = 1, math.min(3, #builders) do
        local index = math.random(#builders)
        local builder = table.remove(builders, index)
        builder:Give("weapon_xdebarricade")
    end

end

function MODE:RoundStart()
	self.Phase = 1
	StartPhaseTimer(self)
	WarnMissingPoints()
end

-- Runs every tick while the round is live: the National Guard arrival, moving Phase One and
-- Two into their cooldowns, ending the cooldowns, and extraction in the last phase.
-- Phase One and Two clear after five minutes. Admins
-- can force a clear with zzombies_skipphase.
function MODE:RoundThink()
    local phaseWaiting = AdvancePhaseClock(self)
    -- Guard tests remain available, but cannot prevent clock advancement.
    if not phaseWaiting or self.TestGuardUntil then UpdateGuardSequence(self) end
    if phaseWaiting then return end

	UpdateExtraction(self)

    -- Finish through the normal round system immediately after processing
    -- extraction, rather than waiting for the shared end-round polling hook.
    if zb.ROUND_STATE == 1 and CurrentRound() == self and (self.Extracted or 0) > 0
        and #AliveSurvivors() == 0 then
        self.AllSurvivorsExtracted = true
        self.OperationFailed = false
        zb:EndRound()
        return
    end
end

-- The round ends when no survivor is left in the field, or the extraction window runs out.
function MODE:ShouldRoundEnd()
    if IsValid(self.ExfilHelicopter) and (#self.ExfilHelicopter:Passengers() > 0
        or self.ExfilHelicopter.State == "departing") then return false end
    if self.AllSurvivorsExtracted or ((self.Extracted or 0) > 0 and #AliveSurvivors() == 0) then
        self.OperationFailed = false
        return true
    end
	-- The admin guard test must not be cut short by an empty field.
	if self.TestGuardUntil and CurTime() < self.TestGuardUntil then
		return false
	end

	if #AliveSurvivors() == 0 then
		self.OperationFailed = (self.Extracted or 0) == 0
		return true
	end

    if IsValid(self.ExfilHelicopter) and self.ExfilHelicopter.State == "departing"
        then return false end

	local deadline = GetGlobalFloat("ZZ_ExtractDeadline", 0)
	if self.Phase >= self.PhaseCount and self.PhaseActive then
		deadline = GetGlobalFloat("ZZ_PhaseEnd", deadline)
	end
	if deadline > 0 and CurTime() >= deadline then
		self.TimeUp = true
		self.OperationFailed = (self.Extracted or 0) == 0
		return true
	end

	-- Admin skip in the last phase ends the round.
	if self.Phase >= self.PhaseCount and GetGlobalFloat("ZZ_CooldownEnd", 0) == 0 and self.SkipPhase then
		return true
	end

	return false
end

function MODE:EndRound()
    for _, ply in player.Iterator() do
        if ply.ZZExfilPreviousTeam ~= nil then ply:SetTeam(ply.ZZExfilPreviousTeam) end
    end
    if IsValid(self.ExfilHelicopter) then self.ExfilHelicopter:Remove() end
    self.ExfilHelicopter, self.ExfilPoint, self.NextExfilAttempt = nil, nil, nil
    SetGlobalEntity("ZZ_ExfilHelicopter", NULL)
	for _, ply in player.Iterator() do ply.ZZGuardReserved = nil ZZClearZombie(ply) end
	self.PhaseActive = false
	self.TestGuardUntil = nil

	-- Everything below is cleanup. A problem in it must never stop the round from ending,
	-- so it is guarded and reports to the console instead.
	local ok, err = pcall(function()
		for _, ply in player.Iterator() do
			ply.ZZ_ExtractStart = nil
			ply:SetNetVar("ZZ_ExtractStart", 0)
		end

		SetGlobalFloat("ZZ_PhaseEnd", 0)
		SetGlobalFloat("ZZ_CooldownEnd", 0)
		SetGlobalFloat("ZZ_ExtractETA", 0)
		SetGlobalFloat("ZZ_ExtractDeadline", 0)

		if self.OperationFailed then
			PrintMessage(HUD_PRINTTALK, self.TimeUp and "Z-Zombies failed. Time ran out." or "Z-Zombies failed. No survivors left.")
		elseif (self.Extracted or 0) > 0 then
			PrintMessage(HUD_PRINTTALK, "Z-Zombies complete. " .. self.Extracted .. " survivor(s) extracted.")
		else
			PrintMessage(HUD_PRINTTALK, "Z-Zombies complete. You survived all 3 phases.")
		end
	end)

	if not ok then
		print("[Z-Zombies] EndRound cleanup error: " .. tostring(err))
	end
end

function MODE:GetTeamSpawn()
	-- Survivors are team 0, the National Guard team 1. Both reuse the shared TDM spawn points
	-- when they spawn normally; the guard is moved to zzombiesguard when it arrives.
	return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T")), zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT"))
end

function MODE:CanLaunch()
	local activePlayers = 0

	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			activePlayers = activePlayers + 1
		end
	end

	return activePlayers >= 2
end

local function Reply(ply, msg)
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end

-- Testing helper: clears the running phase (or skips the cooldown) right now.
concommand.Add("zzombies_skipphase", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	if not ModeActive() or zb.ROUND_STATE ~= 1 then
		Reply(ply, "Z-Zombies: no phase is running.")
		return
	end

	if GetGlobalFloat("ZZ_CooldownEnd", 0) > 0 then
		SetGlobalFloat("ZZ_CooldownEnd", CurTime())
	else
		MODE.SkipPhase = true
	end
end)

-- Admin test: runs the whole National Guard arrival right now, with you as one of the guard
-- (you are removed from play first if you are alive). Needs a Z-Zombies round to be running.
-- Intro, helicopter and spawn happen about 2.5, 2.5 and 12.5 seconds from now.
concommand.Add("zzombies_testguard", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	if not ModeActive() or zb.ROUND_STATE ~= 1 then
		Reply(ply, "Z-Zombies: start a Z-Zombies round first.")
		return
	end

	MODE.GuardPrepared = false
	MODE.GuardAnnounced = false
	MODE.GuardSpawned = false
	MODE.GuardList = {}
	MODE.TestCaller = IsValid(ply) and ply or nil

	local eta = CurTime() + MODE.GuardPreroll + 0.5

	MODE.TestGuardUntil = eta + MODE.GuardIntroDuration + 20

	SetGlobalFloat("ZZ_ExtractDeadline", 0)
	SetGlobalFloat("ZZ_ExtractETA", eta)

	Reply(ply, "Z-Zombies: testing the National Guard arrival.")
end)

