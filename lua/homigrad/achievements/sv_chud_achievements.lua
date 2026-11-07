if not SERVER then return end
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

-- The completion goal below counts all registered achievements dynamically.
local goals = {}
for _, def in ipairs(definitions) do
    local key = "chud_" .. def[1]
    goals[key] = def[4]
    A.CreateAchievementType(key, def[4], 0, def[3], def[2], nil, def[4] > 1)
end
A.ChudGoals = goals
-- Option 2: colors describe achievement types, not ownership rarity.
local categories = {
    chud_stand_proud = "combat",
    chud_silent_assassin = "traitor",
    chud_virus = "zzombies",
    chud_cure = "zzombies",
    chud_meat = "zzombies",
    chud_runners = "zzombies",
    chud_shamblers = "zzombies",
    chud_heavies = "zzombies",
    chud_unguarded = "vip",
    chud_greedy = "bystander",
    chud_monk = "bystander",
    chud_abuse = "hero",

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
    local achievement = A.achievements_data.created_achevements[key]
    if achievement then achievement.category = category end
end

for key in pairs(secretAchievements) do
    local info = A.achievements_data.created_achevements[key]
    info.secret = true
    info.exclude_completion = true
    info.category = "secret"
    info.img = "chudmorse/achievements/friendsmask.png"
end
resource.AddFile("materials/chudmorse/achievements/friendsmask.png")

local function CompletionGoal()
    local count = 0
    for key, info in pairs(A.achievements_data.created_achevements) do
        if key ~= "chud_complete" and not info.exclude_completion then count = count + 1 end
    end
    goals.chud_complete = count
    A.achievements_data.created_achevements.chud_complete.needed_value = count
end
CompletionGoal()

-- Local PData is a durable fallback even on servers without the optional MySQL
-- backend. Merge it whenever the base API is read, including after async SQL loads.
local storageKey = "chud_achievements_v1"
local function Hydrate(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply.ChudAchievementSave then
        ply.ChudAchievementSave = util.JSONToTable(ply:GetPData(storageKey, "{}")) or {}
    end
    local all = A.achievements_data.player_achievements
    local id = ply:SteamID64()
    all[id] = all[id] or {}
    for key, saved in pairs(ply.ChudAchievementSave) do
        if goals[key] and istable(saved) then
            local live = all[id][key]
            if not live or (tonumber(live.value) or 0) < (tonumber(saved.value) or 0) then
                all[id][key] = table.Copy(saved)
            end
        end
    end
end

-- Stable originals prevent wrapper chains during Lua refresh.
A.ChudOriginals = A.ChudOriginals or {
    get = A.GetPlayerAchievements, one = A.GetPlayerAchievement, set = A.SetPlayerAchievement
}
local original = A.ChudOriginals
function A.GetPlayerAchievements(ply) Hydrate(ply) return original.get(ply) end
function A.GetPlayerAchievement(ply, key) Hydrate(ply) return original.one(ply, key) end

local function RecheckCompletion(ply)
    CompletionGoal()
    local count = 0
    local data = A.GetPlayerAchievements(ply)
    for key, info in pairs(A.achievements_data.created_achevements) do
        if key ~= "chud_complete" and not info.exclude_completion and (tonumber(data[key] and data[key].value) or 0) >= info.needed_value then count = count + 1 end
    end
    A.SetPlayerAchievement(ply, "chud_complete", count)
end

function A.SetPlayerAchievement(ply, key, value)
    if secretAchievements[key] then return end -- Granted only through the admin grant helper.
    if not goals[key] then
        original.set(ply, key, value)
        if IsValid(ply) and ply:IsPlayer() and not ply:IsBot() then RecheckCompletion(ply) end
        return
    end
    if not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return end
    Hydrate(ply)
    local data = A.achievements_data.player_achievements[ply:SteamID64()]
    local before = tonumber(data[key] and data[key].value) or 0
    value = math.Clamp(math.floor(tonumber(value) or 0), 0, goals[key])
    if value <= before then return end
    original.set(ply, key, value)
    if value >= goals[key] then data[key].obtained_at = os.time() end
    ply.ChudAchievementSave[key] = table.Copy(data[key])
    ply:SetPData(storageKey, util.TableToJSON(ply.ChudAchievementSave))
    if key ~= "chud_complete" then RecheckCompletion(ply) end
end

-- Used by the superadmin SQL editor and griggs command (including server console).
function A.ApplyAdminSecretAchievements(admin, target, achievements)
    if (IsValid(admin) and not admin:IsSuperAdmin()) or not IsValid(target) then return end
    Hydrate(target)
    for key in pairs(secretAchievements) do
        local data = achievements[key]
        if data and (key ~= "chud_friend_survive" or (tonumber(data.value) or 0) < 1
            or (target:Alive() and target:Team() ~= TEAM_SPECTATOR)) then
            local value = (tonumber(data.value) or 0) >= 1 and 1 or 0
            original.set(target, key, value)
            data.value = value
            data.obtained_at = value == 1 and os.time() or nil
            target.ChudAchievementSave[key] = table.Copy(data)
        end
    end
    target:SetPData(storageKey, util.TableToJSON(target.ChudAchievementSave))
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
    if #matches == 0 then
        GriggsReply(admin, "No connected players matched: " .. query)
        return
    end
    if query ~= "*" and #matches > 1 then
        GriggsReply(admin, "Multiple players matched. Use their full name or SteamID64.")
        return
    end

    local granted = 0
    for _, target in ipairs(matches) do
        if (key ~= "chud_friend_survive" or (target:Alive() and target:Team() ~= TEAM_SPECTATOR))
            and (tonumber(A.GetPlayerAchievement(target, key).value) or 0) < 1 then
            A.ApplyAdminSecretAchievements(admin, target, {[key] = {value = 1}})
            A.SaveToSQL(target)
            granted = granted + 1
        end
    end
    GriggsReply(admin, "Granted " .. A.GetAchievementInfo(key).name .. " to " .. granted .. " player(s).")
end)

local function Award(ply, key, amount)
    if not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return end
    key = "chud_" .. key
    local old = A.GetPlayerAchievement(ply, key)
    A.SetPlayerAchievement(ply, key, (tonumber(old.value) or 0) + (amount or 1))
end
local function Best(ply, key, value) A.SetPlayerAchievement(ply, "chud_" .. key, value) end
local function Active() return zb and zb.ROUND_STATE == 1 end
local function Homicide() return CurrentRound() and CurrentRound().name == "hmcd" end
local function Playing(ply) return IsValid(ply) and ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR end
local function Standing(ply)
    return Playing(ply) and ply:Alive() and not ply:GetNetVar("handcuffed", false)
        and not (ply.organism and (ply.organism.incapacitated or ply.organism.otrub))
end
local function Surviving(ply)
    return Playing(ply) and ply:Alive() and not (ply.organism and ply.organism.incapacitated)
end
local function State(ply)
    ply.ChudAchievementRound = ply.ChudAchievementRound or {kills = 0, forgiven = {}, necks = 0}
    return ply.ChudAchievementRound
end

hook.Add("PlayerInitialSpawn", "ChudAchievementLoad", function(ply)
    timer.Simple(1, function() if IsValid(ply) then Hydrate(ply) RecheckCompletion(ply) end end)
end)
hook.Add("PlayerSpawn", "ChudAchievementLife", function(ply)
    ply.ChudLootedBoxes = 0
    ply.ChudSearchedContainers = setmetatable({}, {__mode = "k"})
    ply.ChudMonkRound = false
    ply.ChudCyanideFatal = nil
    ply.ChudBrainCounted = nil
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
    for _, ply in player.Iterator() do
        ply.ChudAchievementRound = {kills = 0, forgiven = {}, necks = 0}
        ply.ChudLastAchievementHit = nil
        ply.ChudAchievementDead = nil
        ply.ChudTranqPending = nil
        ply.ChudBrainCounted = nil
    end
end)

hook.Add("ChudAchievementHomicideResult", "ChudAchievementWins", function(winner)
    for _, ply in player.Iterator() do
        if Playing(ply) then
            local state = State(ply)
            if ply.isTraitor and winner == 1 then
                if ply.ChudAppliedTraitorSkillset == "damned" then Award(ply, "rags") end
                if state.kills == 0 then Award(ply, "clean") end
                local stats = ply.RSStats or {}
                if ply.MainTraitor and state.kills == 0 and not state.didWork
                    and (stats.damageDealt or 0) == 0 and (stats.shotsFired or 0) == 0 then
                    for _, assistant in player.Iterator() do
                        if Playing(assistant) and assistant ~= ply and assistant.isTraitor and not assistant.MainTraitor
                            and (State(assistant).innocentKills or 0) > 0 then
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
hook.Add("ChudAchievementJuggernautResult", "ChudAchievementJuggernaut", function(ply, winner)
    if winner == 1 then Award(ply, "juggernaut") end
end)
-- Award during the fight; winning the round is not required.
local function CheckJuggernautLastSurvivor()
    if not Active() then return end
    local mode = CurrentRound()
    if not mode or mode.name ~= "juggernaut" or mode.Winner then return end
    if not Standing(mode.Juggernaut) then return end
    -- A solo survivor at initial setup has not outlasted any teammates.
    if #(mode.Players or {}) < 3 then return end
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

-- Award only a completed three-location escort, not an elimination win.
hook.Add("ChudAchievementVIPEscort", "ChudSafestManAlive", function(ply, mode)
    if not mode or mode ~= CurrentRound() or mode.Winner ~= 1 or (mode.Stage or 0) <= 3 then return end
    if mode.VIC ~= ply or not IsValid(ply) or not ply:Alive() then return end
    if not ply:IsPlayer() or ply:IsBot() then return end
    Best(ply, "vic", 1)
end)
hook.Add("ChudAchievementMVP", "ChudAchievementMVP", function(ply)
    if not Playing(ply) or State(ply).mvp then return end
    State(ply).mvp = true
    Award(ply, "mvp")
end)
hook.Add("ZB_EndRound", "ChudAchievementAccuracy", function()
    for _, ply in player.Iterator() do
        local stats = ply.RSStats
        if Playing(ply) and stats and (stats.shotsFired or 0) > 0 and stats.shotsHit == stats.shotsFired then Award(ply, "accuracy") end
    end
end)
hook.Add("ChudAchievementKarmaBan", "ChudAchievementBan", function(ply) Award(ply, "karma_ban") end)
hook.Add("ChudAchievementForgive", "ChudAchievementForgive", function(ply, other)
    -- The server emits this only after forgiving a positive recorded karma debt.
    -- Death, extraction or switching to spectator must not discard that forgiveness.
    if not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return end
    if not IsValid(other) or not other:IsPlayer() or ply == other then return end
    if not zb or (zb.ROUND_STATE ~= 1 and zb.ROUND_STATE ~= 3) then return end
    local state = State(ply)
    state.forgiven = state.forgiven or {}
    -- Bots share SteamID64 "0"; humans retain their identity across reconnects.
    local id = other:IsBot() and ("bot:" .. other:UserID()) or ("steam:" .. other:SteamID64())
    if state.forgiven[id] then return end
    state.forgiven[id] = true
    Best(ply, "forgive", table.Count(state.forgiven))
end)
hook.Add("ChudAchievementRDMHarm", "ChudAchievementRDM", function(attacker, victim)
    if Active() and Playing(attacker) and Playing(victim) then
        State(victim).rdmAttacker = attacker
        State(victim).rdmTime = CurTime()
    end
end)
hook.Add("ChudAchievementArrest", "ChudAchievementArrest", function(ply, victim)
    if Active() and Homicide() and Playing(ply) and not ply.isTraitor and Playing(victim)
        and victim:Alive() and victim.isTraitor and not victim:GetNetVar("handcuffed", false) then Award(ply, "arrest") end
end)
hook.Add("ChudAchievementSplit", "ChudAchievementSplit", function(ply)
    if Active() and Playing(ply) then Award(ply, "split") end
end)

local function IsAssassin(ply)
    return ply.isTraitor and (ply.SubRole == "traitor_assasin" or ply.SubRole == "traitor_assasin_soe")
end
local function RememberDamage(victim, damage)
    if not Active() or not Playing(victim) or damage:GetDamage() <= 0 then return end
    local attacker, inflictor = damage:GetAttacker(), damage:GetInflictor()
    local grenade
    if IsValid(inflictor) and string.StartWith(inflictor:GetClass(), "ent_hg_grenade") and Playing(attacker) then
        grenades[inflictor] = grenades[inflictor] or {owner = attacker, victims = {}}
        grenade = grenades[inflictor]
    end
    victim.ChudLastAchievementHit = {attacker = attacker, time = CurTime(), grenade = grenade}
end
hook.Add("PreHomigradDamage", "ChudAchievementDamage", RememberDamage)
hook.Add("EntityTakeDamage", "ChudAchievementDamageFallback", function(ent, damage)
    local ply = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
    if Playing(ply) then RememberDamage(ply, damage) end
end)

util.AddNetworkString("ChudF4SavesLivesSound")
for i = 1, 4 do
    resource.AddFile("sound/chudmorse/notifications/f4_" .. i .. ".mp3")
end

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
    -- The newer thought HUD suppresses classic Notify messages, so use its API.
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

local CheckLastSurvivor
local function Death(victim, inflictor, killer)
    if not Active() or not Playing(victim) or victim.ChudAchievementDead then return end
    victim.ChudAchievementDead = true
    local cyanideKiller = victim.ChudCyanideFatal
    victim.ChudCyanideFatal = nil
    local hit = victim.ChudLastAchievementHit
    if hit and CurTime() - hit.time <= 20 and Playing(hit.attacker) then killer = hit.attacker else hit = nil end
    if Playing(cyanideKiller) and cyanideKiller ~= victim then
        killer = cyanideKiller
        hit = nil
        local state = State(killer)
        state.cyanideKills = (state.cyanideKills or 0) + 1
        Best(killer, "almond", state.cyanideKills)
    end
    if Playing(killer) and killer ~= victim then
        local round = CurrentRound()
        if round and round.name == "zzombies" and ZZIsZombie and ZZIsZombie(victim) then
            local key = ({runner = "runners", shambler = "shamblers", heavy = "heavies"})[victim:GetNWString("ZZZombieClass")]
            if key then Award(killer, key) end
        end
        if round and (round.name == "hmcd" or round.name == "chaos")
            and killer.isGunner and not killer.isTraitor and not victim.isTraitor then Award(killer, "abuse") end
        NotifyTraitorTeamkill(killer, victim)
        State(killer).kills = State(killer).kills + 1
        if Homicide() then
            if killer.isTraitor and not victim.isTraitor then
                State(killer).innocentKills = (State(killer).innocentKills or 0) + 1
            end
            if IsAssassin(killer) then Award(killer, "assassin") end
            if killer.isTraitor and victim.isTraitor and not victim.MainTraitor then Award(killer, "assistant") end
        end
        -- Check the actual kill and roles, not the capped karma-loss notification.
        -- Keep the original achievement key so existing unlocks remain saved.
        if Homicide() and victim:SteamID64() == "76561198370899886"
            and not killer.isTraitor and not killer.isGunner
            and not victim.isTraitor and not victim.isGunner then
            Award(killer, "sloopsters")
        end
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
hook.Add("ChudAchievementNeckSnap", "ChudAchievementNeckSnap", function(ply, victim)
    if not Active() or not Homicide() or not Playing(ply) or not Playing(victim) then return end
    victim.ChudLastAchievementHit = {attacker = ply, time = CurTime()}
    if ply.isTraitor and (ply.SubRole == "traitor_infiltrator" or ply.SubRole == "traitor_infiltrator_soe") then
        local s = State(ply)
        s.necks = s.necks + 1
        Best(ply, "necks", s.necks)
    end
end)
hook.Add("ChudAchievementTranqHit", "ChudAchievementTranqHit", function(ply, victim)
    if Active() and Playing(ply) and Playing(victim) and ply ~= victim and victim:Alive()
        and victim.organism and not victim.organism.otrub then victim.ChudTranqPending = ply end
end)
hook.Add("Org Think", "ChudAchievementInjuries", function(ply, org)
    if not Active() or not Playing(ply) or not ply:Alive() then return end
    if (org.eyeL or 0) >= 1 and (org.eyeR or 0) >= 1 then Award(ply, "eyes") end
    if (org.brain or 0) >= 0.1 and not ply.ChudBrainCounted then
        ply.ChudBrainCounted = true
        Award(ply, "brain")
    end
    if ply.ChudTranqPending then
        if (org.tranquilizer or 0) <= 0 then ply.ChudTranqPending = nil
        elseif org.otrub then
            Award(ply.ChudTranqPending, "tranq10")
            Award(ply.ChudTranqPending, "tranq1000")
            ply.ChudTranqPending = nil
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

-- The cyanide entity remembers who deployed it. Poison kills bypass ordinary
-- DamageInfo, so attribution is captured immediately before the organism kills.
hook.Add("ChudAchievementCyanideExposure", "ChudAchievementCyanideWork", function(ply, victim)
    if Active() and Playing(ply) and Playing(victim) and ply ~= victim then State(ply).didWork = true end
end)
hook.Add("ChudAchievementPoisonDeath", "ChudAchievementPoisonDeath", function(victim, org)
    if not Active() or not Playing(victim) then return end
    if not org.poison3 or org.poison3 + 30 >= CurTime() then return end
    if not org.o2 or (org.o2[1] or 30) > 0.25 then return end
    if not Playing(org.ChudCyanideOwner) or org.ChudCyanideOwner == victim then return end
    victim.ChudCyanideFatal = org.ChudCyanideOwner
end)
hook.Add("HomigradDamage", "ChudAchievementEmployerWork", function(victim, damage)
    local attacker = damage:GetAttacker()
    if Active() and Playing(victim) and Playing(attacker) and attacker ~= victim and damage:GetDamage() > 0 then
        State(attacker).didWork = true
    end
end)
hook.Add("ChudAchievementTranqHit", "ChudAchievementEmployerTranq", function(ply, victim)
    if Active() and Playing(ply) and Playing(victim) and ply ~= victim then State(ply).didWork = true end
end)

-- New mode achievements use successful gameplay events, before cleanup clears roles.
local function Bystander(ply)
    local mode = CurrentRound()
    return Playing(ply) and mode and (mode.name == "hmcd" or mode.name == "chaos")
        and not ply.isTraitor and not ply.isGunner and not ply.isPolice
end
hook.Add("ChudAchievementVirusTurn", "ChudVirusTurn", function(ply)
    if Active() then Award(ply, "virus") end
end)
hook.Add("ChudAchievementInfectedDeath", "ChudInfectedDeath", function(victim, killer, stage)
    if not Active() or not ZZInfection or not ZZInfection.Active() then return end
    if (stage or 0) < 1 or stage >= 5 then return end
    -- Only the actual self-inflicted death counts; never use last-attacker credit.
    if Playing(victim) and killer == victim then Award(victim, "cure") end
end)
hook.Add("ChudAchievementMeal", "ChudGroupMeal", function(eaters)
    local unique, count = {}, 0
    for _, ply in ipairs(eaters) do
        if Playing(ply) and ply:Alive() and ZZIsZombie(ply) and not unique[ply] then
            unique[ply] = true count = count + 1
        end
    end
    if Active() and count >= 4 then for ply in pairs(unique) do Award(ply, "meat") end end
end)
hook.Add("ChudAchievementPresidentAlone", "ChudPresidentAlone", function(ply) Award(ply, "unguarded") end)
-- Count successful inventory searches, not loot generation or broken props.
hook.Remove("ChudAchievementLootBox", "ChudLootBoxes")
hook.Add("ZB_InventoryOpened", "ChudLootContainers", function(ply, ent)
    if not Active() or not Bystander(ply) or not ply:Alive() then return end
    if not IsValid(ent) or ent:IsPlayer() or ent:GetClass() == "prop_ragdoll" then return end
    if not istable(ent:GetNetVar("Inventory")) then return end
    ply.ChudSearchedContainers = ply.ChudSearchedContainers or setmetatable({}, {__mode = "k"})
    if ply.ChudSearchedContainers[ent] then return end
    ply.ChudSearchedContainers[ent] = true
    ply.ChudLootedBoxes = (ply.ChudLootedBoxes or 0) + 1
    Best(ply, "greedy", ply.ChudLootedBoxes)
end)
hook.Add("ZB_StartRound", "ChudMonkStart", function()
    for _, ply in player.Iterator() do
        ply.ChudMonkRound = Bystander(ply) and ply:Alive() and (ply.Karma or 0) >= 120
    end
end)
timer.Create("ChudMonkMonitor", 0.25, 0, function()
    if not Active() then return end
    for _, ply in player.Iterator() do
        if ply.ChudMonkRound and (not Bystander(ply) or not ply:Alive() or (ply.Karma or 0) < 120) then
            ply.ChudMonkRound = false
        end
    end
end)
hook.Add("ZB_EndRound", "ChudMonkEnd", function()
    for _, ply in player.Iterator() do
        if ply.ChudMonkRound and Bystander(ply) and ply:Alive() and (ply.Karma or 0) >= 120 then
            ply.ChudMonkStreak = (ply.ChudMonkStreak or 0) + 1
            Best(ply, "monk", ply.ChudMonkStreak)
        else
            ply.ChudMonkStreak = 0
        end
        ply.ChudMonkRound = false
    end
end)

-- Framed targets are fresh per round. Record actual deaths, not damage-credit guesses.
local function RecordFramedTargetDeath(victim, killer)
    if not Active() then return end
    local mode = CurrentRound()
    if not mode or mode.name ~= "framed" then return end
    local data = mode.TargetLookup and mode.TargetLookup[victim]
    if not data or data.ChudPersonalKill ~= nil then return end
    data.ChudPersonalKill = IsValid(mode.Killer) and killer == mode.Killer and killer ~= victim
    if not data.ChudPersonalKill or mode.ChudSilentAssassinAwarded then return end
    if not mode.Targets or #mode.Targets == 0 then return end
    for _, target in ipairs(mode.Targets) do
        if target.ChudPersonalKill ~= true then return end
    end
    mode.ChudSilentAssassinAwarded = true
    Award(mode.Killer, "silent_assassin")
end
hook.Add("DoPlayerDeath", "ChudFramedPersonalTargets", RecordFramedTargetDeath)
hook.Add("ZB_StartRound", "ChudCombatRoundStart", function()
    local mode = CurrentRound()
    if mode then mode.ChudSilentAssassinAwarded = nil end
end)
hook.Add("ZB_EndRound", "ChudDeathmatchLastStanding", function()
    local mode = CurrentRound()
    if not mode or mode.name ~= "dm" then return end
    local survivors = zb:CheckAlive(true)
    if #survivors == 1 and Playing(survivors[1]) and survivors[1]:Alive() then
        Award(survivors[1], "stand_proud")
    end
end)
