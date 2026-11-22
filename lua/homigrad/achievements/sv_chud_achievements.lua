if not SERVER then return end
-- Chudmorse achievements (rewrite).
--
-- Progress safety:
--  * Every achievement key, name and goal below is unchanged, so saved SQL rows,
--    the local PData backup ("chud_achievements_v1") and the COIN payout table
--    (chud_achievement_coin) all keep lining up with what players already have.
--  * Progress only ever goes up. Loading merges SQL, PData and live data by
--    taking the highest value of each, so nobody loses an unlock or progress.

local A = hg.achievements

local secretAchievements = {chud_friend_visit = true, chud_friend_survive = true}
A.SecretAchievements = secretAchievements

local definitions = {
    {"stand_proud", "Stand Proud", "Be the last one standing in deathmatch.", 1},
    {"silent_assassin", "Silent Assassin", "Kill your targets yourself without having any of them die to others.", 1},
    {"virus", "I feel horrible.", "Succumb to the Virus", 1},
    {"cure", "Only Cure", "Refuse to Surrender to the Virus by Taking your own life.", 1},
    {"meat", "ahh fresh meat", "Eat a player with 3 other zombies", 1},
    {"runners", "World War Z", "Kill 50 runners", 50},
    {"shamblers", "Walking Dead", "Kill 25 shamblers", 25},
    {"heavies", "Double Tap", "Kill 10 heavies", 10},
    {"unguarded", "What am I paying you for?", "Win as the president with no guards alive", 1},
    {"greedy", "Greedy Bastard", "Search 10 different lootable containers in 1 life", 10},
    {"monk", "Monk", "Have 120 Karma for 5 consecutive rounds", 5},
    {"abuse", "Abuse of power", "As Hero, Kill 5 people that are not the traitor", 5},

    {"friend_visit", "Visit from a friend", "Encounter an old Friend", 1},
    {"friend_survive", "We'll see each other again one day", "Survive an Encounter with Friend", 1},
    {"rags", "Rags to Riches", "Win a traitor round using Damned.", 1},
    {"vic", "Safest man alive", "Win President as the Very Important Chud by completing all three locations.", 1},
    {"juggernaut", "Genocide", "Win as the Juggernaut.", 1},
    {"dread", "Sense of dread", "Be the last survivor standing in Juggernaut", 1},
    {"karma_ban", "porta BANNED", "Get karma banned.", 1},
    {"mvp", "Better than all of you", "Get MVP 100 times.", 100},
    {"grenade", "Suicidal", "Kill at least 3 people, including yourself, with one grenade.", 1},
    {"eyes", "Blind", "Lose both eyes.", 1},
    {"split", "Gorilla Tag", "Be split in two.", 1},
    {"brain", "fgorot hwo ot tkinh", "Become brain damaged in 10 separate lives.", 10},
    {"assistant", "Retard", "Kill your traitor assistant.", 1},
    {"clean", "Clean Palms", "Win as a traitor without killing anyone.", 1},
    {"odds", "Against all odds", "Be the last survivor facing 3 active traitors, then win.", 1},
    {"accuracy", "Childhood", "Finish a round with 100% accuracy and at least one shot fired.", 1},
    {"sloopsters", "slipsters", "RDM sloopsters.", 1},
    {"forgive", "TTT XP grind", "Forgive 5 different people's karma in one round.", 5},
    {"tranq10", "Sleepy time", "Tranquilize 10 players into unconsciousness.", 10},
    {"tranq1000", "Big Boss", "Tranquilize 1000 players into unconsciousness.", 1000},
    {"arrest", "Actually did my job", "Arrest a living traitor.", 1},
    {"necks", "Turn around next time", "As infiltrator, snap 5 necks in one round.", 5},
    {"assassin", "Assassin Adept", "Kill 1000 players as Assassin.", 1000},
    {"almond", "Almond scent", "Kill 10 players using cyanide canisters in a single round.", 10},
    {"lazy", "Lazy employer", "Win as the main traitor without attacks, damage or kills while assistants kill innocents.", 1},
    {"complete", "The Chud to rule them all!", "Unlock every other Chudmorse achievement, including existing achievements.", 20}
}

local goals = {}
for _, def in ipairs(definitions) do
    local key = "chud_" .. def[1]
    goals[key] = def[4]
    A.CreateAchievementType(key, def[4], 0, def[3], def[2], nil, def[4] > 1)
end
A.ChudGoals = goals

-- Colors describe achievement types, not ownership rarity.
local categories = {
    chud_stand_proud = "combat", chud_silent_assassin = "traitor",
    chud_virus = "zzombies", chud_cure = "zzombies", chud_meat = "zzombies",
    chud_runners = "zzombies", chud_shamblers = "zzombies", chud_heavies = "zzombies",
    chud_unguarded = "vip", chud_greedy = "bystander", chud_monk = "bystander", chud_abuse = "hero",
    chud_rags = "traitor", chud_vic = "vip", chud_juggernaut = "juggernaut", chud_dread = "juggernaut",
    chud_karma_ban = "special", chud_mvp = "milestone", chud_grenade = "general",
    chud_eyes = "general", chud_split = "general", chud_brain = "milestone",
    chud_assistant = "traitor", chud_clean = "traitor", chud_odds = "bystander",
    chud_accuracy = "general", chud_sloopsters = "special", chud_forgive = "general",
    chud_tranq10 = "milestone", chud_tranq1000 = "milestone", chud_arrest = "hero",
    chud_necks = "traitor", chud_assassin = "milestone", chud_complete = "milestone",
    chud_almond = "traitor", chud_lazy = "traitor",
    gollavo = "milestone"
}
for key, category in pairs(categories) do
    local info = A.achievements_data.created_achevements[key]
    if info then info.category = category end
end

for key in pairs(secretAchievements) do
    local info = A.achievements_data.created_achevements[key]
    info.secret = true
    info.exclude_completion = true
    info.category = "secret"
    info.img = "chudmorse/achievements/friendsmask.png"
end
resource.AddFile("materials/chudmorse/achievements/friendsmask.png")

-- Shelved while Z-Zombies and Framed are being reworked. Definitions and saved
-- progress are kept; these are hidden (unless already earned) and do not count
-- toward chud_complete. Empty this table to bring them back.
local shelvedAchievements = {
    chud_virus = true, chud_cure = true, chud_meat = true,
    chud_runners = true, chud_shamblers = true, chud_heavies = true, -- Z-Zombies
    chud_silent_assassin = true, -- Framed
}
A.ShelvedAchievements = shelvedAchievements
for key in pairs(shelvedAchievements) do
    local info = A.achievements_data.created_achevements[key]
    if info then
        info.shelved = true
        info.exclude_completion = true
    end
end

local function CompletionGoal()
    local count = 0
    for key, info in pairs(A.achievements_data.created_achevements) do
        if key ~= "chud_complete" and not info.exclude_completion then count = count + 1 end
    end
    goals.chud_complete = count
    A.achievements_data.created_achevements.chud_complete.needed_value = count
end
CompletionGoal()

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------
local STORAGE_KEY = "chud_achievements_v1"

local function Num(entry)
    if istable(entry) then entry = entry.value end
    return tonumber(entry) or 0
end

local function Human(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply:IsBot()
end

local function LoadSave(ply)
    if not ply.ChudAchievementSave then
        ply.ChudAchievementSave = util.JSONToTable(ply:GetPData(STORAGE_KEY, "{}") or "{}") or {}
    end
    return ply.ChudAchievementSave
end

local function WriteSave(ply)
    ply:SetPData(STORAGE_KEY, util.TableToJSON(LoadSave(ply)))
end

-- Merge the PData backup (and legacy headshot counter) into the live table,
-- keeping whichever value is higher. Never lowers anything.
local function Hydrate(ply)
    if not Human(ply) then return end
    local all = A.achievements_data.player_achievements
    local id = ply:SteamID64()
    all[id] = all[id] or {}
    local live = all[id]
    for key, saved in pairs(LoadSave(ply)) do
        if A.GetAchievementInfo(key) and istable(saved) and Num(live[key]) < Num(saved) then
            live[key] = table.Copy(saved)
        end
    end
    -- Gollavo has always been driven by the "Headshots" PData counter.
    if A.GetAchievementInfo("gollavo") then
        local headshots = tonumber(ply:GetPData("Headshots", 0)) or 0
        if Num(live.gollavo) < headshots then
            live.gollavo = live.gollavo or {}
            live.gollavo.value = headshots
        end
    end
    return live
end

local function Persist(ply, key)
    local live = A.achievements_data.player_achievements[ply:SteamID64()]
    if not live or not live[key] then return end
    LoadSave(ply)[key] = table.Copy(live[key])
    WriteSave(ply)
    -- shared with the other server (only ever raises)
    if ChudShared then ChudShared.RaiseAch(ply:SteamID64(), key, Num(live[key]), live[key].obtained_at) end
end

-- Stable originals prevent wrapper chains during Lua refresh.
A.ChudOriginals = A.ChudOriginals or {
    get = A.GetPlayerAchievements, one = A.GetPlayerAchievement, set = A.SetPlayerAchievement
}
local original = A.ChudOriginals

function A.GetPlayerAchievements(ply) Hydrate(ply) return original.get(ply) end
function A.GetPlayerAchievement(ply, key) Hydrate(ply) return original.one(ply, key) end

local RecheckCompletion

-- Single entry point for all progress. Only raises values.
function A.SetPlayerAchievement(ply, key, value)
    local info = A.GetAchievementInfo(key)
    if not info or not Human(ply) then return end
    if secretAchievements[key] then return end -- secret ones: admin grant only
    local live = Hydrate(ply)
    local before = Num(live[key])
    value = math.floor(tonumber(value) or 0)
    if goals[key] then value = math.Clamp(value, 0, info.needed_value) end
    if value <= before then return end

    original.set(ply, key, value) -- sends the popup + fires HG_AchievementCompleted on unlock
    live = A.achievements_data.player_achievements[ply:SteamID64()]
    if live[key] and before < info.needed_value and value >= info.needed_value then
        live[key].obtained_at = live[key].obtained_at or os.time()
    end
    Persist(ply, key)
    if key ~= "chud_complete" then RecheckCompletion(ply) end
end

RecheckCompletion = function(ply)
    CompletionGoal()
    local live = Hydrate(ply)
    if not live then return end
    local count = 0
    for key, info in pairs(A.achievements_data.created_achevements) do
        if key ~= "chud_complete" and not info.exclude_completion and Num(live[key]) >= info.needed_value then
            count = count + 1
        end
    end
    A.SetPlayerAchievement(ply, "chud_complete", count)
end

local function SyncPlayer(ply)
    if not Human(ply) then return end
    local live = Hydrate(ply)
    -- Push merged values back into the backup so it is always complete.
    local save = LoadSave(ply)
    local changed = false
    for key, entry in pairs(live) do
        if A.GetAchievementInfo(key) and istable(entry) and Num(save[key]) < Num(entry) then
            save[key] = table.Copy(entry)
            changed = true
        end
    end
    if changed then WriteSave(ply) end
    RecheckCompletion(ply)
end
A.ChudSyncPlayer = SyncPlayer

-- Shared achievements arrived (sv_chud_shared_db.lua): raise anything the other server unlocked,
-- quietly (no popup, no COIN), and push anything only this server had.
hook.Add("ChudShared_PlayerLoaded", "ChudAchievementShared", function(ply, data)
    if not Human(ply) then return end
    local live = Hydrate(ply)
    if not live then return end
    local sid = ply:SteamID64()
    local shared = {}
    local save = LoadSave(ply)
    local changed = false
    for _, row in ipairs(data.ach or {}) do
        local key, value = row.ach, tonumber(row.value) or 0
        shared[key] = value
        if A.GetAchievementInfo(key) and Num(live[key]) < value then
            live[key] = live[key] or {}
            live[key].value = value
            live[key].obtained_at = live[key].obtained_at or tonumber(row.obtained_at)
            save[key] = table.Copy(live[key])
            changed = true
        end
    end
    if changed then WriteSave(ply) end
    -- the headshot counter counts up from PData; keep it at least at the shared value
    if live.gollavo and Num(live.gollavo) > (tonumber(ply:GetPData("Headshots", 0)) or 0) then
        ply:SetPData("Headshots", Num(live.gollavo))
        ply:SetNWInt("Headshots", Num(live.gollavo))
    end
    for key, entry in pairs(live) do
        if A.GetAchievementInfo(key) and istable(entry) and Num(entry) > (shared[key] or 0) then
            ChudShared.RaiseAch(sid, key, Num(entry), entry.obtained_at)
        end
    end
    SyncPlayer(ply)
end)

-- SQL loads asynchronously, so sync shortly after joining and again a bit later.
hook.Add("PlayerInitialSpawn", "ChudAchievementLoad", function(ply)
    for _, delay in ipairs({1, 6}) do
        timer.Simple(delay, function() if IsValid(ply) then SyncPlayer(ply) end end)
    end
end)
for _, ply in player.Iterator() do SyncPlayer(ply) end -- Lua refresh

---------------------------------------------------------------------------
-- Admin tools / secret achievements
---------------------------------------------------------------------------
local function GrantSecret(target, key, value)
    local live = Hydrate(target)
    value = value >= 1 and 1 or 0
    if value == 1 and Num(live[key]) >= 1 then return false end
    original.set(target, key, value)
    live = A.achievements_data.player_achievements[target:SteamID64()]
    live[key] = live[key] or {}
    live[key].value = value
    live[key].obtained_at = value == 1 and os.time() or nil
    LoadSave(target)[key] = table.Copy(live[key])
    WriteSave(target)
    if ChudShared and value == 1 then ChudShared.RaiseAch(target:SteamID64(), key, 1, live[key].obtained_at) end
    return true
end

-- Called by the superadmin stats editor (sv_admin_tools) with the full edited table.
function A.ApplyAdminSecretAchievements(admin, target, achievements)
    if (IsValid(admin) and not admin:IsSuperAdmin()) or not Human(target) or not istable(achievements) then return end
    Hydrate(target)
    for key in pairs(secretAchievements) do
        local data = achievements[key]
        if data then
            local value = Num(data) >= 1 and 1 or 0
            if key == "chud_friend_survive" and value == 1 and not (target:Alive() and target:Team() ~= TEAM_SPECTATOR) then
                value = Num(A.GetPlayerAchievement(target, key))
            end
            data.value = value
            if value == 1 then original.set(target, key, 1) end
        end
    end
    -- The editor is authoritative: mirror its table into the backup so the
    -- PData merge does not undo an admin's deliberate change.
    local save = {}
    for key, data in pairs(achievements) do
        if A.GetAchievementInfo(key) and istable(data) then save[key] = table.Copy(data) end
    end
    target.ChudAchievementSave = save
    WriteSave(target)
end

local function GriggsReply(admin, message)
    if IsValid(admin) then admin:ChatPrint(message) else print(message) end
end

concommand.Add("griggs", function(admin, command, args)
    if IsValid(admin) and not admin:IsSuperAdmin() then
        GriggsReply(admin, "Only superadmins can grant Friend achievements.")
        return
    end
    local keys = {visit = "chud_friend_visit", survive = "chud_friend_survive"}
    local key = keys[string.lower(args[1] or "")]
    local query = string.Trim(table.concat(args, " ", 2))
    if not key or query == "" then
        GriggsReply(admin, "Usage: griggs visit <name|*> or griggs survive <name|*>")
        return
    end

    local matches, exact = {}, {}
    local needle = string.lower(query)
    for _, target in player.Iterator() do
        if not target:IsBot() then
            local name = string.lower(target:Name())
            local character = string.lower(target:GetNWString("PlayerName", ""))
            if query == "*" then
                matches[#matches + 1] = target
            elseif name == needle or character == needle or target:SteamID64() == query then
                exact[#exact + 1] = target
            elseif string.find(name, needle, 1, true) or string.find(character, needle, 1, true) then
                matches[#matches + 1] = target
            end
        end
    end
    if #exact > 0 then matches = exact end
    if #matches == 0 then GriggsReply(admin, "No connected players matched: " .. query) return end
    if query ~= "*" and #matches > 1 then
        GriggsReply(admin, "Multiple players matched. Use their full name or SteamID64.")
        return
    end

    local granted = 0
    for _, target in ipairs(matches) do
        if (key ~= "chud_friend_survive" or (target:Alive() and target:Team() ~= TEAM_SPECTATOR))
            and GrantSecret(target, key, 1) then
            A.SaveToSQL(target)
            granted = granted + 1
        end
    end
    GriggsReply(admin, "Granted " .. A.GetAchievementInfo(key).name .. " to " .. granted .. " player(s).")
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Award(ply, key, amount)
    if not Human(ply) then return end
    key = "chud_" .. key
    A.SetPlayerAchievement(ply, key, Num(A.GetPlayerAchievement(ply, key)) + (amount or 1))
end
local function Best(ply, key, value) A.SetPlayerAchievement(ply, "chud_" .. key, value) end

local function Active() return zb and zb.ROUND_STATE == 1 end
local function ModeName() local mode = CurrentRound and CurrentRound() return mode and mode.name end
-- Chaos is a homicide variant with the same roles.
local function Homicide() local name = ModeName() return name == "hmcd" or name == "chaos" end
local function Playing(ply) return IsValid(ply) and ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR end
local function Standing(ply)
    return Playing(ply) and ply:Alive() and not ply:GetNetVar("handcuffed", false)
        and not (ply.organism and (ply.organism.incapacitated or ply.organism.otrub))
end
local function Surviving(ply)
    return Playing(ply) and ply:Alive() and not (ply.organism and ply.organism.incapacitated)
end
local function NewRoundState() return {kills = 0, forgiven = {}, necks = 0, cyanideKills = 0, innocentKills = 0} end
local function State(ply)
    ply.ChudAchievementRound = ply.ChudAchievementRound or NewRoundState()
    return ply.ChudAchievementRound
end
local function IsAssassin(ply)
    return ply.isTraitor and (ply.SubRole == "traitor_assasin" or ply.SubRole == "traitor_assasin_soe")
end
local function IsInfiltrator(ply)
    return ply.isTraitor and (ply.SubRole == "traitor_infiltrator" or ply.SubRole == "traitor_infiltrator_soe")
end

local HIT_WINDOW = 20

-- Homigrad kills players through the organism (owner:Kill()), so the engine's
-- attacker is usually the victim. Work out who really did it.
local function ResolveKiller(victim, attacker)
    local now = CurTime()
    local hit = victim.ChudLastAchievementHit
    if hit and now - hit.time <= HIT_WINDOW and Playing(hit.attacker) then return hit.attacker, hit end
    local rs = victim.RSLastHit
    if rs and IsValid(rs.att) and Playing(rs.att) and now - (rs.t or 0) <= HIT_WINDOW then return rs.att end
    if Playing(attacker) and attacker ~= victim then return attacker end
    local best, who = 0, nil
    for att, dmg in pairs(zb and zb.HarmDone and zb.HarmDone[victim] or {}) do
        if Playing(att) and att ~= victim and (tonumber(dmg) or 0) > best then best, who = dmg, att end
    end
    return who
end

---------------------------------------------------------------------------
-- Life / round state
---------------------------------------------------------------------------
hook.Add("PlayerSpawn", "ChudAchievementLife", function(ply)
    ply.ChudLootedBoxes = 0
    ply.ChudSearchedContainers = setmetatable({}, {__mode = "k"})
    ply.ChudCyanideFatal = nil
    ply.ChudBrainCounted = nil
    ply.ChudEyesCounted = nil
    ply.ChudAchievementDead = nil
    ply.ChudLastAchievementHit = nil
    ply.ChudTranqPending = nil
end)

local grenades = {}
hook.Add("ZB_PreRoundStart", "ChudAchievementClearSkillset", function()
    for _, ply in player.Iterator() do ply.ChudAppliedTraitorSkillset = nil end
end)
hook.Add("ZB_StartRound", "ChudAchievementRound", function()
    grenades = {}
    local mode = CurrentRound()
    if mode then mode.ChudSilentAssassinAwarded = nil end
    for _, ply in player.Iterator() do
        ply.ChudAchievementRound = NewRoundState()
        ply.ChudLastAchievementHit = nil
        ply.ChudAchievementDead = nil
        ply.ChudTranqPending = nil
        ply.ChudBrainCounted = nil
        ply.ChudEyesCounted = nil
        -- Monk: only rounds the player actually takes part in count.
        ply.ChudMonkRound = nil
        if Playing(ply) then ply.ChudMonkRound = (tonumber(ply.Karma) or 0) >= 120 end
    end
end)

---------------------------------------------------------------------------
-- Damage tracking
---------------------------------------------------------------------------
local function RememberDamage(victim, damage)
    if not Active() or not Playing(victim) or damage:GetDamage() <= 0 then return end
    local attacker, inflictor = damage:GetAttacker(), damage:GetInflictor()
    local grenade
    if IsValid(inflictor) and string.StartWith(inflictor:GetClass(), "ent_hg_grenade") and Playing(attacker) then
        grenades[inflictor] = grenades[inflictor] or {owner = attacker, victims = {}}
        grenade = grenades[inflictor]
    end
    -- Keep the last real attacker; don't let world/prop damage erase it.
    if not Playing(attacker) and victim.ChudLastAchievementHit then return end
    victim.ChudLastAchievementHit = {attacker = attacker, time = CurTime(), grenade = grenade}
end
hook.Add("PreHomigradDamage", "ChudAchievementDamage", function(victim, damage)
    local ply = IsValid(victim) and (victim:IsPlayer() and victim or hg.RagdollOwner(victim))
    if Playing(ply) then RememberDamage(ply, damage) end
end)
hook.Add("EntityTakeDamage", "ChudAchievementDamageFallback", function(ent, damage)
    local ply = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
    if Playing(ply) then RememberDamage(ply, damage) end
end)
hook.Add("HomigradDamage", "ChudAchievementEmployerWork", function(victim, damage)
    local attacker = damage:GetAttacker()
    if Active() and Playing(attacker) and IsValid(victim) and attacker ~= victim and damage:GetDamage() > 0 then
        State(attacker).didWork = true
    end
end)

---------------------------------------------------------------------------
-- Traitor teamkill thoughts (#F4SAVESLIVES) — unchanged feature
---------------------------------------------------------------------------
util.AddNetworkString("ChudF4SavesLivesSound")
for i = 1, 4 do resource.AddFile("sound/chudmorse/notifications/f4_" .. i .. ".mp3") end

local traitorTeamkillMessages = {
    main_assistant = {
        "Shit... Wrong person.",
        "Oh fuck! Shot the wrong person!",
        "Shit! That was my assistant!",
        "Fuuuccckkk me man...",
        "#F4SAVESLIVES",
        "I'm so stupid... Fuck..."
    },
    assistant_main = {
        "What have I done?!",
        "Fuck... This is going to be much harder without them...",
        "Oh no... Why did I do that?",
        "#F4SAVESLIVES",
        "Should've watched who I was killing... Fuck...",
        "Fuck... I just killed my husband."
    },
    assistant_assistant = {
        "I think that was my friend...",
        "Whoops... That was my friend...",
        "Aw damn it! I killed my friend!",
        "#F4SAVESLIVES",
        "Jesus why did I do that?"
    }
}

local function NotifyTraitorTeamkill(killer, victim)
    if not Homicide() or not killer.isTraitor or not victim.isTraitor or killer:IsBot() then return end
    local group
    if killer.MainTraitor and not victim.MainTraitor then
        group = traitorTeamkillMessages.main_assistant
    elseif not killer.MainTraitor and victim.MainTraitor then
        group = traitorTeamkillMessages.assistant_main
    elseif not killer.MainTraitor and not victim.MainTraitor then
        group = traitorTeamkillMessages.assistant_assistant
    end
    if not group then return end
    local message = group[math.random(#group)]
    local key = "traitor_teamkill_" .. victim:EntIndex()
    if killer:GetInfoNum("hg_newthoughts", 0) > 0 then
        killer:Thought(message, 0, key)
    else
        killer:Notify(message, 0, key)
    end
    if message == "#F4SAVESLIVES" and killer:Alive() and not (killer.organism and killer.organism.otrub) then
        net.Start("ChudF4SavesLivesSound")
        net.WriteUInt(math.random(1, 4) - 1, 2)
        net.Send(killer)
    end
end

---------------------------------------------------------------------------
-- Deaths
---------------------------------------------------------------------------
local function CheckFramedTarget(victim, killer)
    local mode = CurrentRound()
    if not mode or mode.name ~= "framed" or mode.ChudSilentAssassinAwarded then return end
    local data = mode.TargetLookup and mode.TargetLookup[victim]
    if not data or data.ChudPersonalKill ~= nil then return end
    data.ChudPersonalKill = IsValid(mode.Killer) and killer == mode.Killer and killer ~= victim
    if not data.ChudPersonalKill or not mode.Targets or #mode.Targets == 0 then return end
    for _, target in ipairs(mode.Targets) do
        if target.ChudPersonalKill ~= true then return end
    end
    mode.ChudSilentAssassinAwarded = true
    Award(mode.Killer, "silent_assassin")
end

local CheckLastSurvivor
local function Death(victim, inflictor, attacker)
    if not Active() or not Playing(victim) or victim.ChudAchievementDead then return end
    victim.ChudAchievementDead = true

    local killer, hit = ResolveKiller(victim, attacker)
    local cyanideKiller = victim.ChudCyanideFatal
    victim.ChudCyanideFatal = nil
    if Playing(cyanideKiller) and cyanideKiller ~= victim then
        killer, hit = cyanideKiller, nil
        local state = State(killer)
        state.cyanideKills = state.cyanideKills + 1
        Best(killer, "almond", state.cyanideKills)
    end

    CheckFramedTarget(victim, killer)

    if Playing(killer) and killer ~= victim then
        local mode = ModeName()
        if mode == "zzombies" and ZZIsZombie and ZZIsZombie(victim) then
            local key = ({runner = "runners", shambler = "shamblers", heavy = "heavies"})[victim:GetNWString("ZZZombieClass")]
            if key then Award(killer, key) end
        end
        if Homicide() then
            if killer.isGunner and not killer.isTraitor and not victim.isTraitor then Award(killer, "abuse") end
            NotifyTraitorTeamkill(killer, victim)
            if killer.isTraitor and not victim.isTraitor then
                State(killer).innocentKills = State(killer).innocentKills + 1
            end
            if IsAssassin(killer) then Award(killer, "assassin") end
            if killer.isTraitor and victim.isTraitor and not victim.MainTraitor then Award(killer, "assistant") end
            -- Original key kept so existing unlocks stay saved.
            if victim:SteamID64() == "76561198370899886"
                and not killer.isTraitor and not killer.isGunner
                and not victim.isTraitor and not victim.isGunner then
                Award(killer, "sloopsters")
            end
        end
        State(killer).kills = State(killer).kills + 1
    end

    if hit and hit.grenade then
        local g = hit.grenade
        g.victims[victim] = true
        if not g.awarded and g.victims[g.owner] and table.Count(g.victims) >= 3 then
            g.awarded = true
            Award(g.owner, "grenade")
        end
    end

    if CheckLastSurvivor then CheckLastSurvivor() end
end
hook.Add("PlayerDeath", "ChudAchievementDeath", Death)
hook.Add("Player_Death", "ChudAchievementDeathFallback", function(ply) Death(ply) end)
hook.Remove("DoPlayerDeath", "ChudFramedPersonalTargets") -- now handled in Death()

-- Neck snaps kill via ply:Kill(), so credit the snapper first.
hook.Add("ChudAchievementNeckSnap", "ChudAchievementNeckSnap", function(ply, victim)
    if not Active() or not Homicide() or not Playing(ply) or not Playing(victim) then return end
    victim.ChudLastAchievementHit = {attacker = ply, time = CurTime()}
    State(ply).didWork = true
    if IsInfiltrator(ply) then
        local s = State(ply)
        s.necks = s.necks + 1
        Best(ply, "necks", s.necks)
    end
end)

---------------------------------------------------------------------------
-- Cyanide
---------------------------------------------------------------------------
hook.Add("ChudAchievementCyanideExposure", "ChudAchievementCyanideWork", function(ply, victim)
    if Active() and Playing(ply) and Playing(victim) and ply ~= victim then State(ply).didWork = true end
end)
hook.Add("ChudAchievementPoisonDeath", "ChudAchievementPoisonDeath", function(victim, org)
    if not Active() or not Playing(victim) or not org then return end
    -- Cyanide only starts suffocating 30s after exposure.
    if not org.poison3 or org.poison3 + 30 > CurTime() then return end
    local owner = org.ChudCyanideOwner
    if not Playing(owner) or owner == victim then return end
    victim.ChudCyanideFatal = owner
end)

---------------------------------------------------------------------------
-- Injuries / tranquilizer
---------------------------------------------------------------------------
hook.Add("ChudAchievementTranqHit", "ChudAchievementTranqHit", function(ply, victim)
    if not Active() or not Playing(ply) or not Playing(victim) or ply == victim then return end
    State(ply).didWork = true
    if victim:Alive() and victim.organism and not victim.organism.otrub then
        victim.ChudTranqPending = {by = ply, time = CurTime()}
    end
end)

hook.Add("Org Think", "ChudAchievementInjuries", function(ply, org)
    if not Active() or not Playing(ply) or not ply:Alive() or not org then return end
    if not ply.ChudEyesCounted and (org.eyeL or 0) >= 1 and (org.eyeR or 0) >= 1 then
        ply.ChudEyesCounted = true
        Award(ply, "eyes")
    end
    if not ply.ChudBrainCounted and (org.brain or 0) >= 0.1 then
        ply.ChudBrainCounted = true
        Award(ply, "brain")
    end
    local pending = ply.ChudTranqPending
    if pending then
        if not Playing(pending.by) or CurTime() - pending.time > 120 then
            ply.ChudTranqPending = nil
        elseif org.otrub then
            ply.ChudTranqPending = nil
            Award(pending.by, "tranq10")
            Award(pending.by, "tranq1000")
        end
    end
end)

hook.Add("ChudAchievementSplit", "ChudAchievementSplit", function(ply)
    if Active() and Playing(ply) then Award(ply, "split") end
end)

---------------------------------------------------------------------------
-- Homicide / Chaos
---------------------------------------------------------------------------
hook.Add("ChudAchievementHomicideResult", "ChudAchievementWins", function(winner)
    -- Runs inside MODE:EndRound before roles are cleared.
    for _, ply in player.Iterator() do
        if Playing(ply) then
            local state = State(ply)
            if ply.isTraitor and winner == 1 then
                if ply.ChudAppliedTraitorSkillset == "damned" then Award(ply, "rags") end
                if state.kills == 0 then Award(ply, "clean") end
                local stats = ply.RSStats or {}
                if ply.MainTraitor and state.kills == 0 and not state.didWork
                    and (stats.damageDealt or 0) <= 0 and (stats.shotsFired or 0) == 0 then
                    for _, assistant in player.Iterator() do
                        if Playing(assistant) and assistant ~= ply and assistant.isTraitor and not assistant.MainTraitor
                            and State(assistant).innocentKills > 0 then
                            Award(ply, "lazy")
                            break
                        end
                    end
                end
            elseif not ply.isTraitor and winner == 0 and Surviving(ply) and state.againstOdds then
                Award(ply, "odds")
            end
        end
    end
end)

CheckLastSurvivor = function()
    if not Active() or not Homicide() then return end
    local survivors, traitors = {}, 0
    for _, ply in player.Iterator() do
        if ply.isTraitor and Standing(ply) then traitors = traitors + 1
        elseif not ply.isTraitor and not ply.isPolice and Surviving(ply) then survivors[#survivors + 1] = ply end
    end
    if #survivors == 1 and traitors >= 3 then State(survivors[1]).againstOdds = true end
end
timer.Create("ChudAchievementLastSurvivor", 0.25, 0, CheckLastSurvivor)

hook.Add("ChudAchievementArrest", "ChudAchievementArrest", function(ply, victim)
    if Active() and Homicide() and Playing(ply) and not ply.isTraitor and Playing(victim)
        and victim:Alive() and victim.isTraitor and not victim:GetNetVar("handcuffed", false) then
        Award(ply, "arrest")
    end
end)

---------------------------------------------------------------------------
-- Karma
---------------------------------------------------------------------------
hook.Add("ChudAchievementKarmaBan", "ChudAchievementBan", function(ply) Award(ply, "karma_ban") end)

hook.Add("ChudAchievementForgive", "ChudAchievementForgive", function(ply, other)
    if not Human(ply) or not IsValid(other) or not other:IsPlayer() or ply == other then return end
    if not zb or (zb.ROUND_STATE ~= 1 and zb.ROUND_STATE ~= 3) then return end
    local state = State(ply)
    local id = other:IsBot() and ("bot:" .. other:UserID()) or ("steam:" .. other:SteamID64())
    if state.forgiven[id] then return end
    state.forgiven[id] = true
    Best(ply, "forgive", table.Count(state.forgiven))
end)

-- Monk: karma must stay at 120 for the whole of 5 rounds in a row that you play.
-- Rounds you sit out don't break the streak; dropping below 120 does.
timer.Create("ChudMonkMonitor", 0.25, 0, function()
    if not Active() then return end
    for _, ply in player.Iterator() do
        if ply.ChudMonkRound and (tonumber(ply.Karma) or 0) < 120 then ply.ChudMonkRound = false end
    end
end)

---------------------------------------------------------------------------
-- Round end
---------------------------------------------------------------------------
hook.Add("ZB_EndRound", "ChudAchievementRoundEnd", function()
    local mode = CurrentRound()
    for _, ply in player.Iterator() do
        -- Accuracy: pellets/penetration can register more hits than shots.
        local stats = ply.RSStats
        if Playing(ply) and stats and (stats.shotsFired or 0) > 0 and (stats.shotsHit or 0) >= stats.shotsFired then
            Award(ply, "accuracy")
        end
        if ply.ChudMonkRound ~= nil then
            if ply.ChudMonkRound and (tonumber(ply.Karma) or 0) >= 120 then
                ply.ChudMonkStreak = (ply.ChudMonkStreak or 0) + 1
                Best(ply, "monk", ply.ChudMonkStreak)
            else
                ply.ChudMonkStreak = 0
            end
            ply.ChudMonkRound = nil
        end
    end
    if mode and mode.name == "dm" then
        local survivors = {}
        for _, ply in ipairs(zb:CheckAlive(true)) do
            if Playing(ply) then survivors[#survivors + 1] = ply end
        end
        if #survivors == 1 then Award(survivors[1], "stand_proud") end
    end
    -- Belt and braces: make sure everyone's backup is up to date.
    for _, ply in player.Iterator() do
        if Human(ply) then RecheckCompletion(ply) end
    end
end)
hook.Remove("ZB_EndRound", "ChudAchievementAccuracy")
hook.Remove("ZB_EndRound", "ChudMonkEnd")
hook.Remove("ZB_EndRound", "ChudDeathmatchLastStanding")
hook.Remove("ZB_StartRound", "ChudMonkStart")
hook.Remove("ZB_StartRound", "ChudCombatRoundStart")
hook.Remove("ChudAchievementTranqHit", "ChudAchievementEmployerTranq")

hook.Add("ChudAchievementMVP", "ChudAchievementMVP", function(ply)
    if not Playing(ply) or State(ply).mvp then return end
    State(ply).mvp = true
    Award(ply, "mvp")
end)

---------------------------------------------------------------------------
-- Juggernaut
---------------------------------------------------------------------------
hook.Add("ChudAchievementJuggernautResult", "ChudAchievementJuggernaut", function(ply, winner)
    if winner == 1 then Award(ply, "juggernaut") end
end)

local function CheckJuggernautLastSurvivor()
    if not Active() then return end
    local mode = CurrentRound()
    if not mode or mode.name ~= "juggernaut" or mode.Winner then return end
    if not Standing(mode.Juggernaut) then return end
    if #(mode.Players or {}) < 3 then return end -- a solo survivor outlasted nobody
    local lastSurvivor
    for _, ply in ipairs(mode.Players) do
        if ply ~= mode.Juggernaut and Standing(ply) then
            if lastSurvivor then return end
            lastSurvivor = ply
        end
    end
    if not lastSurvivor or State(lastSurvivor).juggernautDread then return end
    State(lastSurvivor).juggernautDread = true
    Award(lastSurvivor, "dread")
end
timer.Create("ChudAchievementJuggernautLastSurvivor", 0.25, 0, CheckJuggernautLastSurvivor)

---------------------------------------------------------------------------
-- VIP
---------------------------------------------------------------------------
hook.Add("ChudAchievementVIPEscort", "ChudSafestManAlive", function(ply, mode)
    if not mode or mode.Winner ~= 1 or (mode.Stage or 0) <= 3 then return end
    if mode.VIC ~= ply or not IsValid(ply) or not ply:Alive() then return end
    Best(ply, "vic", 1)
end)
hook.Add("ChudAchievementPresidentAlone", "ChudPresidentAlone", function(ply) Award(ply, "unguarded") end)

---------------------------------------------------------------------------
-- Zombies / infection
---------------------------------------------------------------------------
hook.Add("ChudAchievementVirusTurn", "ChudVirusTurn", function(ply)
    if Active() then Award(ply, "virus") end
end)

hook.Add("ChudAchievementInfectedDeath", "ChudInfectedDeath", function(victim, killer, stage)
    if not Active() or not ZZInfection or not ZZInfection.Active() then return end
    if (stage or 0) < 1 or stage >= 5 or not Playing(victim) then return end
    -- The engine reports nearly every Homigrad death as self-inflicted, so use
    -- the last real damage instead: it must have been the victim's own.
    local hit = victim.ChudLastAchievementHit
    if hit and hit.attacker == victim and CurTime() - hit.time <= 5 then Award(victim, "cure") end
end)

hook.Add("ChudAchievementMeal", "ChudGroupMeal", function(eaters)
    if not Active() then return end
    local unique, count = {}, 0
    for _, ply in ipairs(eaters or {}) do
        if Playing(ply) and ply:Alive() and ZZIsZombie(ply) and not unique[ply] then
            unique[ply] = true
            count = count + 1
        end
    end
    if count >= 4 then for ply in pairs(unique) do Award(ply, "meat") end end
end)

---------------------------------------------------------------------------
-- Looting
---------------------------------------------------------------------------
hook.Remove("ChudAchievementLootBox", "ChudLootBoxes")
hook.Add("ZB_InventoryOpened", "ChudLootContainers", function(ply, ent)
    if not Active() or not Playing(ply) or not ply:Alive() then return end
    if ZZIsZombie and ZZIsZombie(ply) then return end
    if not IsValid(ent) or ent:IsPlayer() or ent:GetClass() == "prop_ragdoll" then return end
    if not istable(ent:GetNetVar("Inventory")) then return end
    ply.ChudSearchedContainers = ply.ChudSearchedContainers or setmetatable({}, {__mode = "k"})
    if ply.ChudSearchedContainers[ent] then return end
    ply.ChudSearchedContainers[ent] = true
    ply.ChudLootedBoxes = (ply.ChudLootedBoxes or 0) + 1
    Best(ply, "greedy", ply.ChudLootedBoxes)
end)
