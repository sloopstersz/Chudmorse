--;; ===================================
--;; Chudmorse map vote (RTV)
--;; 5 map cards + Extend / None of these / Random, 50%+ wins outright,
--;; otherwise the top two go head to head. Players can rate the map they
--;; just played for a one-time karma bonus per vote.
--;; ===================================
util.AddNetworkString("ZB_RockTheVote_start")
util.AddNetworkString("ZB_RockTheVote_vote")
util.AddNetworkString("ZB_RockTheVote_voteCLreg")
util.AddNetworkString("ZB_RockTheVote_end")
util.AddNetworkString("ZB_MapVote_Rate")
util.AddNetworkString("ZB_MapVote_Rating")
util.AddNetworkString("RTVMenu")

zb = zb or {}
zb.votestarted = false

local VOTE_TIME       = 30   -- default first-round length (sv_roundsystem passes 20)
local RUNOFF_TIME     = 15   -- head to head length
local EXTEND_ROUNDS   = 8    -- "Extend map" keeps the map for this many rounds
local MAX_EXTENDS     = 2    -- per map
local MAP_CHOICES     = 5
local RATE_KARMA      = 5    -- karma for rating the map (once per vote)
local REVIEW_MAX_LEN  = 140  -- characters per written review
local REVIEWS_SHOWN   = 12   -- newest reviews sent per map
local SLUR_BAN_MINUTES = 60  -- ban length for slurs in a review

-- Tags players can stick on a review (max 3). Order matters: the client sends a bitmask.
local REVIEW_TAGS = {"mixed", "outside", "inside", "dark", "silly", "limitedloot", "barryapproved"}
local MAX_TAGS = 3

-- Tags only certain SteamID64s may use. Everyone else never sees the button.
local TAG_OWNERS = {
    ["barryapproved"] = {["76561199043924494"] = true},
}

local VALID_TAG = {}
for _, tag in ipairs(REVIEW_TAGS) do VALID_TAG[tag] = true end

local function CanUseTag(ply, tag)
    local owners = TAG_OWNERS[tag]
    return VALID_TAG[tag] and (not owners or owners[ply:SteamID64()]) or false
end

local function LockedTagsFor(ply)
    local locked = {}
    for tag in pairs(TAG_OWNERS) do
        if not CanUseTag(ply, tag) then locked[tag] = true end
    end
    return locked
end

-- Drops tags that are no longer in the list (old saves).
local function LiveTags(list)
    local out = {}
    for _, tag in ipairs(istable(list) and list or {}) do
        if VALID_TAG[tag] then table.insert(out, tag) end
    end
    return out
end

-- Checked against the review with spaces/symbols removed and look-alike characters
-- swapped back (n1gg@ -> nigga), so spacing or leetspeak doesn't get around it.
local SLUR_PATTERNS = {"n+i+gg+e+r", "n+i+gg+a", "f+a+g+o+t"}

-- These hide inside normal words (raccoon, tycoon, "which ink"), so they only
-- count as a whole word. Spaced-out letters ("c o o n") are joined first.
local SLUR_WORDS = {"^c+o+o+n+s*$", "^k+i+k+e+s*$", "^c+h+i+n+k+s*$"}
local RTV_ROUND_LIMIT = 15   -- sv_roundsystem starts a vote when Roundscount > 15

local cooldown = {}
local mappull = {}
local vote = nil
local endStarted = false

local function GetMapFamily(map)
    if string.find(string.lower(map), "smalltown") then
        return "smalltown"
    end
    return nil
end

local function GetFamilyMaps(family)
    local familyMaps = {}
    for _, map in ipairs(mappull) do
        if GetMapFamily(map) == family then
            table.insert(familyMaps, map)
        end
    end
    return familyMaps
end

local blacklist = {
    ["gm_construct"] = true, ["gm_flatgrass"] = true, ["gm_altarskforest"] = true, ["gm_renostruct_v2"] = true,
    ["gm_renostruct_v2_night"] = true, ["gm_city_of_silence"] = true, ["ttt_hogwarts"] = true,
    ["hmcd_gonka"] = true, ["hmcd_bloodring"] = true,
}

local allowedPrefix = {
    ["ttt"] = true, ["hmcd"] = true, ["mu"] = true, ["ze"] = false,
    ["zs"] = true, ["tdm"] = true, ["zb"] = false, ["zbattle"] = false,
    ["gm"] = true, ["ph"] = true, ["cs"] = true, ["de"] = true
}

local prefixWeights = {
    ["ttt"] = 18, ["hmcd"] = 19, ["mu"] = 18, ["ze"] = 0,
    ["zs"] = 9,  ["tdm"] = 5,  ["zb"] = 0,  ["zbattle"] = 0,
    ["gm"] = 20, ["ph"] = 11, ["cs"] = 1,  ["de"] = 1
}

local function GetSafeServerName()
    local hostname = GetConVar("hostname"):GetString() or "unknown"
    hostname = hostname:gsub("[^%w_-]", "_"):sub(1, 20)
    return hostname
end

local function GetDataPath(fileName)
    return "zbattle/" .. GetSafeServerName() .. "/" .. fileName
end

local function EnsureDataDirectory()
    local serverName = GetSafeServerName()
    if not file.Exists("zbattle", "DATA") then file.CreateDir("zbattle") end
    if not file.Exists("zbattle/" .. serverName, "DATA") then file.CreateDir("zbattle/" .. serverName) end
end

EnsureDataDirectory()

local popularityPath = GetDataPath("MapPopularity.json")
local mapPopularity = util.JSONToTable(file.Read(popularityPath, "DATA") or "") or {}

--;; ---------- map ratings ----------
local ratingsPath = GetDataPath("MapRatings.json")
local mapRatings = util.JSONToTable(file.Read(ratingsPath, "DATA") or "") or {}

local function SaveRatings()
    file.Write(ratingsPath, util.TableToJSON(mapRatings))
end

local function QueueSaveRatings()
    timer.Create("ZB_MapVote_SaveRatings", 2, 1, SaveRatings)
end

hook.Add("ShutDown", "ZB_MapVote_SaveRatings", SaveRatings)

-- Entries are {s = score 1-10, r = review text, n = name, t = os.time()}.
-- Old saves stored a bare 1-5 star number; read those as score * 2.
local function Entry(v)
    if istable(v) then return v end
    local n = tonumber(v)
    if n then return {s = math.Clamp(n * 2, 1, 10), r = "", n = "", t = 0} end
end

local function RatingSummary(map)
    local sum, n = 0, 0
    for _, v in pairs(mapRatings[map] or {}) do
        local e = Entry(v)
        local sc = e and tonumber(e.s)
        if sc then sum = sum + sc n = n + 1 end
    end
    return {n > 0 and math.Round(sum / n, 1) or 0, n}
end

local function MyEntry(ply, map)
    local r = mapRatings[map]
    return r and Entry(r[ply:SteamID64()])
end

local function ReviewList(map)
    local out = {}
    for _, v in pairs(mapRatings[map] or {}) do
        local e = Entry(v)
        local tags = e and LiveTags(e.g) or {}
        local hasTags = #tags > 0
        if e and ((e.r and e.r ~= "") or hasTags) then
            table.insert(out, {n = e.n or "?", s = e.s or 0, r = e.r or "", t = e.t or 0, g = hasTags and tags or nil})
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    for i = #out, REVIEWS_SHOWN + 1, -1 do out[i] = nil end
    return out
end

-- Most used tags on a map: {{tag, count}, ...}, top 3.
local function TagCounts(map)
    local counts = {}
    for _, v in pairs(mapRatings[map] or {}) do
        local e = Entry(v)
        if e then
            for _, tag in ipairs(LiveTags(e.g)) do counts[tag] = (counts[tag] or 0) + 1 end
        end
    end
    local list = {}
    for tag, n in pairs(counts) do table.insert(list, {tag, n}) end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i = #list, 4, -1 do list[i] = nil end
    return list
end

local LEET = {["0"] = "o", ["1"] = "i", ["!"] = "i", ["|"] = "i", ["3"] = "e", ["4"] = "a", ["@"] = "a", ["$"] = "s", ["5"] = "s", ["6"] = "g", ["9"] = "g", ["7"] = "t", ["+"] = "t"}

local function HasSlur(text)
    local flat = string.lower(text or ""):gsub(".", function(c) return LEET[c] or c end):gsub("[^%a]", "")
    for _, pat in ipairs(SLUR_PATTERNS) do
        if flat:find(pat) then return true end
    end

    local spaced = string.lower(text or ""):gsub(".", function(c) return LEET[c] or c end):gsub("[^%a]", " ")
    local words, run = {}, ""
    for word in spaced:gmatch("%a+") do
        if #word == 1 then
            run = run .. word
        else
            if run ~= "" then table.insert(words, run) run = "" end
            table.insert(words, word)
        end
    end
    if run ~= "" then table.insert(words, run) end
    for _, word in ipairs(words) do
        for _, pat in ipairs(SLUR_WORDS) do
            if word:find(pat) then return true end
        end
    end
    return false
end

local function BanForSlur(ply)
    local name, sid = ply:Nick(), ply:SteamID()
    local reason = "Slur in a map review (" .. SLUR_BAN_MINUTES .. " minute ban)"
    if ULib and ULib.addBan then
        ULib.addBan(sid, SLUR_BAN_MINUTES, reason, name, "MapVote")
    else
        ply:Ban(SLUR_BAN_MINUTES, false)
        ply:Kick(reason)
    end
    for _, v in player.Iterator() do
        v:ChatPrint(name .. " was banned for " .. SLUR_BAN_MINUTES .. " minutes for a slur in a map review.")
    end
    ServerLog("[MapVote] Banned " .. name .. " (" .. sid .. ") for a slur in a map review\n")
end

-- Strip control characters and cap length without cutting a UTF-8 character.
local function CleanReview(text)
    text = tostring(text or ""):gsub("[%c]", " "):gsub("%s+", " ")
    text = string.Trim(text)
    if utf8.len(text) and utf8.len(text) > REVIEW_MAX_LEN then
        text = text:sub(1, (utf8.offset(text, REVIEW_MAX_LEN + 1) or #text + 1) - 1)
    end
    return text
end

--;; ---------- map pool ----------
local function getmaps()
    table.Empty(mappull)
    for _, map in ipairs(file.Find("maps/*.bsp", "GAME")) do
        map = map:sub(1, -5)
        local prefix = map:Split("_")[1]
        if (allowedPrefix[prefix] or not string.find(map, "_")) and not blacklist[map] and not map:lower():StartWith("background") then
            table.insert(mappull, map)
        end
    end
end

local function getWeightedRandomMapPrefix()
    local totalWeight = 0
    for _, weight in pairs(prefixWeights) do totalWeight = totalWeight + weight end

    local randomWeight = math.random() * totalWeight
    for prefix, weight in pairs(prefixWeights) do
        if randomWeight < weight then return prefix end
        randomWeight = randomWeight - weight
    end
end

local function getMapsByPrefix(prefix)
    local prefixMaps = {}
    for _, map in ipairs(mappull) do
        if map:StartWith(prefix .. "_") then table.insert(prefixMaps, map) end
    end
    return prefixMaps
end

local function getMapWeight(map)
    local pop = mapPopularity[map] or 0
    return math.max(1 - (pop / 100), 0.01)
end

local function LoadPlayedMaps()
    local path = GetDataPath("PlayedMaps.json")
    return util.JSONToTable(file.Read(path, "DATA") or "") or {}
end

-- Weighted pick that removes the chosen entry from list.
local function TakeWeighted(list)
    local total = 0
    for _, m in ipairs(list) do total = total + getMapWeight(m) end
    local rnd = math.random() * total
    for idx, m in ipairs(list) do
        local w = getMapWeight(m)
        if rnd < w then return table.remove(list, idx) end
        rnd = rnd - w
    end
    return table.remove(list)
end

-- Same idea as the old RTV: 3 weighted prefixes with 4+ fresh maps each,
-- then weighted fallback. blocked = maps that must not appear.
local function GeneratePool(blocked)
    local function free(m) return not blocked[m] end

    local chosen, attempts = {}, 0
    while #chosen < 3 and attempts < 300 do
        attempts = attempts + 1
        local prefix = getWeightedRandomMapPrefix()
        if prefix and not table.HasValue(chosen, prefix) then
            local count = 0
            for _, m in ipairs(getMapsByPrefix(prefix)) do
                if free(m) then count = count + 1 end
            end
            if count >= 4 then table.insert(chosen, prefix) end
        end
    end

    local pool = {}
    for _, prefix in ipairs(chosen) do
        local valid = {}
        for _, m in ipairs(getMapsByPrefix(prefix)) do
            if free(m) then table.insert(valid, m) end
        end
        for i = 1, 4 do
            if #valid == 0 then break end
            table.insert(pool, TakeWeighted(valid))
        end
    end

    if #pool < 12 then
        local fallback = {}
        for _, m in ipairs(mappull) do
            if free(m) and not table.HasValue(pool, m) then table.insert(fallback, m) end
        end
        while #pool < 12 and #fallback > 0 do
            table.insert(pool, TakeWeighted(fallback))
        end
    end

    return pool
end

-- One map per prefix first so the cards stay varied, then fill up.
local function PickChoices(pool)
    local shuffled = table.Copy(pool)
    table.Shuffle(shuffled)

    local out, used = {}, {}
    for _, m in ipairs(shuffled) do
        local prefix = m:match("^([^_]+)_") or m
        if #out < MAP_CHOICES and not used[prefix] then
            table.insert(out, m)
            used[prefix] = true
        end
    end
    for _, m in ipairs(shuffled) do
        if #out >= MAP_CHOICES then break end
        if not table.HasValue(out, m) then table.insert(out, m) end
    end
    return out
end

local function BuildChoices(exclude)
    local cur = game.GetMap()
    local played = LoadPlayedMaps()

    local blocked = {[cur] = true}
    for _, m in ipairs(played) do blocked[m] = true end
    for m in pairs(exclude or {}) do blocked[m] = true end

    local choices = PickChoices(GeneratePool(blocked))

    -- Small map lists: ignore played history before giving up.
    if #choices < MAP_CHOICES then
        local relaxed = {[cur] = true}
        for m in pairs(exclude or {}) do relaxed[m] = true end
        for _, m in ipairs(choices) do relaxed[m] = true end
        for _, m in ipairs(PickChoices(GeneratePool(relaxed))) do
            if #choices >= MAP_CHOICES then break end
            table.insert(choices, m)
        end
    end

    return choices
end

local function RandomMap()
    local cur = game.GetMap()
    local list = {}
    for _, m in ipairs(mappull) do
        if m ~= cur then table.insert(list, m) end
    end
    return list[math.random(#list)] or cur
end

-- Popularity + played history, unchanged from the old RTV.
local function RecordPlayed(winmap)
    local mapFamily = GetMapFamily(winmap)
    mapPopularity[winmap] = math.min((mapPopularity[winmap] or 0) + 5, 100)

    local playedMapsPath = GetDataPath("PlayedMaps.json")
    local PlayedMaps = LoadPlayedMaps()

    if not table.HasValue(PlayedMaps, winmap) then
        table.insert(PlayedMaps, 1, winmap)

        if mapFamily then
            for _, familyMap in ipairs(GetFamilyMaps(mapFamily)) do
                if familyMap ~= winmap and not table.HasValue(PlayedMaps, familyMap) then
                    table.insert(PlayedMaps, 1, familyMap)
                    mapPopularity[familyMap] = math.min((mapPopularity[familyMap] or 0) + 5, 100)
                end
            end
        end

        if #PlayedMaps > 20 then
            local lastFiveMaps = {}
            for i = math.max(1, #PlayedMaps - 5 + 1), #PlayedMaps do
                if i > 1 then table.insert(lastFiveMaps, PlayedMaps[i]) end
            end
            PlayedMaps = {winmap}
            for _, map in ipairs(lastFiveMaps) do table.insert(PlayedMaps, map) end
        end

        file.Write(playedMapsPath, util.TableToJSON(PlayedMaps))
    end

    for map, pop in pairs(mapPopularity) do
        if map ~= winmap and not table.HasValue(PlayedMaps, map) then
            mapPopularity[map] = math.max(pop - 2, 0)
        end
    end

    file.Write(popularityPath, util.TableToJSON(mapPopularity))
end

hook.Add("InitPostEntity", "zb_GetMaps", function()
    zb.votestarted = false
    getmaps()
end)

--;; ---------- networking ----------
local function SendTally()
    if not vote then return end
    local voters = {}
    for ply, opt in pairs(vote.ballots) do
        if IsValid(ply) then
            voters[opt] = voters[opt] or {}
            table.insert(voters[opt], ply:EntIndex())
        end
    end
    net.Start("ZB_RockTheVote_voteCLreg")
        net.WriteTable(voters)
        net.WriteUInt(math.min(player.GetCount(), 255), 8)
    net.Broadcast()
end

local function PayloadFor(ply)
    local cur = game.GetMap()
    local ratings = {[cur] = RatingSummary(cur)}
    local reviews = {[cur] = ReviewList(cur)}
    local tagCounts = {[cur] = TagCounts(cur)}
    for _, m in ipairs(vote.maps) do
        ratings[m] = RatingSummary(m)
        reviews[m] = ReviewList(m)
        tagCounts[m] = TagCounts(m)
    end
    local mine = MyEntry(ply, cur)

    return {
        phase = vote.phase,
        maps = vote.maps,
        options = vote.options,
        runoff = vote.runoff,
        endTime = vote.endTime,
        duration = vote.duration,
        current = cur,
        ratings = ratings,
        reviews = reviews,
        myRating = mine and mine.s or 0,
        myReview = mine and mine.r or "",
        myTags = LiveTags(mine and mine.g),
        tagList = REVIEW_TAGS,
        lockedTags = LockedTagsFor(ply),
        maxTags = MAX_TAGS,
        tagCounts = tagCounts,
        reviewMax = REVIEW_MAX_LEN,
        rated = vote.rated[ply:SteamID64()] and true or false,
        myVote = vote.ballots[ply],
        extendRounds = EXTEND_ROUNDS,
        rateKarma = RATE_KARMA,
    }
end

local function SendStart(target)
    if not vote then return end
    for _, ply in ipairs(target and {target} or player.GetHumans()) do
        net.Start("ZB_RockTheVote_start")
            net.WriteTable(PayloadFor(ply))
        net.Send(ply)
    end
end

local function SendRating()
    local cur = game.GetMap()
    local summary = RatingSummary(cur)
    local reviews = ReviewList(cur)
    for _, ply in ipairs(player.GetHumans()) do
        local mine = MyEntry(ply, cur)
        net.Start("ZB_MapVote_Rating")
            net.WriteFloat(summary[1])
            net.WriteUInt(summary[2], 16)
            net.WriteUInt(mine and mine.s or 0, 4)
            net.WriteBool(vote and vote.rated[ply:SteamID64()] or false)
            net.WriteString(mine and mine.r or "")
            net.WriteTable(reviews)
            net.WriteTable(LiveTags(mine and mine.g))
            net.WriteTable(TagCounts(cur))
        net.Send(ply)
    end
end

--;; ---------- vote flow ----------
local function OpenVote(duration, exclude, canReroll, keepRated)
    local maps = BuildChoices(exclude)

    local options = {}
    if (zb.MapVoteExtends or 0) < MAX_EXTENDS then table.insert(options, "extend") end
    if canReroll then table.insert(options, "reroll") end
    table.insert(options, "random")

    vote = {
        phase = 1,
        maps = maps,
        options = options,
        valid = {},
        ballots = {},
        rated = keepRated or {},
        endTime = CurTime() + duration,
        duration = duration,
        canReroll = canReroll,
    }
    for _, m in ipairs(maps) do vote.valid[m] = true end
    for _, o in ipairs(options) do vote.valid[o] = true end

    SendStart()
    SendTally()
end

local function StartRunoff(a, b)
    vote.phase = 2
    vote.runoff = {a, b}
    vote.valid = {[a] = true, [b] = true}
    for ply, opt in pairs(vote.ballots) do
        if not vote.valid[opt] then vote.ballots[ply] = nil end
    end
    vote.endTime = CurTime() + RUNOFF_TIME
    vote.duration = RUNOFF_TIME

    SendStart()
    SendTally()
end

local function SendEnd(opt, winmap)
    net.Start("ZB_RockTheVote_end")
        net.WriteString(opt)
        net.WriteString(winmap or "")
    net.Broadcast()
end

local function Finish(opt)
    if opt == "reroll" then
        local exclude = {}
        for _, m in ipairs(vote.maps) do exclude[m] = true end
        OpenVote(VOTE_TIME, exclude, false, vote.rated)
        return
    end

    vote.finished = true

    if opt == "extend" then
        zb.MapVoteExtends = (zb.MapVoteExtends or 0) + 1
        zb.Roundscount = RTV_ROUND_LIMIT + 1 - EXTEND_ROUNDS
        if zb.ClearRTVVotes then zb.ClearRTVVotes() end
        SendEnd("extend", game.GetMap())

        timer.Simple(4, function()
            vote = nil
            zb.votestarted = false
            hook.Remove("Think", "RTVThink")
        end)
        return
    end

    if endStarted then return end
    endStarted = true

    local winmap = opt == "random" and RandomMap() or opt
    RecordPlayed(winmap)
    SendEnd(opt, winmap)
    SaveRatings()

    timer.Simple(4, function()
        RunConsoleCommand("changelevel", winmap)
    end)
end

local function Resolve()
    local counts, total = {}, 0
    for ply, opt in pairs(vote.ballots) do
        if IsValid(ply) and vote.valid[opt] then
            counts[opt] = (counts[opt] or 0) + 1
            total = total + 1
        end
    end

    if total == 0 then
        -- Nobody voted: pick one of the offered maps (or the runoff pair).
        local pool = vote.phase == 2 and vote.runoff or vote.maps
        Finish(pool[math.random(#pool)] or "random")
        return
    end

    local ranked = {}
    for opt, n in pairs(counts) do table.insert(ranked, {opt = opt, n = n, r = math.random()}) end
    table.sort(ranked, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.r > b.r -- ties are random
    end)

    local top, second = ranked[1], ranked[2]
    if vote.phase == 1 and second then
        -- 50%+ wins outright, as long as it isn't tied for first.
        local outright = top.n * 2 >= total and top.n > second.n
        if not outright then
            StartRunoff(top.opt, second.opt)
            return
        end
    end

    Finish(top.opt)
end

function zb.ThinkRTV()
    if not zb.votestarted or not vote or vote.finished then return end
    if CurTime() >= vote.endTime then Resolve() end
end

function zb.StartRTV(time)
    if zb.votestarted then return end
    getmaps()

    zb.votestarted = true
    endStarted = false
    OpenVote(time or VOTE_TIME, nil, true)

    hook.Add("Think", "RTVThink", zb.ThinkRTV)
end

-- Ends the current round of voting right now (kept for compatibility).
function zb.EndRTV()
    if vote and not vote.finished then Resolve() end
end

net.Receive("ZB_RockTheVote_vote", function(len, ply)
    if not vote or vote.finished then return end
    if (cooldown[ply] or 0) > CurTime() then return end
    cooldown[ply] = CurTime() + 0.4

    local opt = net.ReadString()
    if not vote.valid[opt] or vote.ballots[ply] == opt then return end

    vote.ballots[ply] = opt
    SendTally()
end)

net.Receive("ZB_MapVote_Rate", function(len, ply)
    if not vote or not IsValid(ply) then return end
    if (ply.ZB_MapRateCD or 0) > CurTime() then return end
    ply.ZB_MapRateCD = CurTime() + 0.5

    local score = net.ReadUInt(4)
    local hasText = net.ReadBool()
    local text = hasText and CleanReview(net.ReadString()) or nil
    local hasTags = net.ReadBool()
    local tags
    if hasTags then
        local mask = net.ReadUInt(8)
        tags = {}
        for i, tag in ipairs(REVIEW_TAGS) do
            if bit.band(mask, bit.lshift(1, i - 1)) ~= 0 and #tags < MAX_TAGS and CanUseTag(ply, tag) then table.insert(tags, tag) end
        end
    end
    if score < 1 or score > 10 then return end

    if text and HasSlur(text) then
        BanForSlur(ply)
        return
    end

    local cur, sid = game.GetMap(), ply:SteamID64()
    mapRatings[cur] = mapRatings[cur] or {}
    local old = Entry(mapRatings[cur][sid])
    if hasText or hasTags then
        if (ply.ZB_MapReviewCD or 0) > CurTime() then return end
        ply.ZB_MapReviewCD = CurTime() + 3
    end
    mapRatings[cur][sid] = {
        s = score,
        r = text or (old and old.r) or "",
        g = tags or (old and old.g) or nil,
        n = string.sub(ply:Nick(), 1, 32),
        t = (hasText or hasTags or not old) and os.time() or (old.t or os.time()),
    }
    QueueSaveRatings()

    if not vote.rated[sid] then
        vote.rated[sid] = true
        if isnumber(ply.Karma) then
            local cap = zb.MaxKarma or 100
            ply.Karma = math.max(ply.Karma, math.min(ply.Karma + RATE_KARMA, cap))
            ply:SetNetVar("Karma", ply.Karma)
        end
    end

    SendRating()
end)

hook.Add("PlayerInitialSpawn", "ZB_MapVote_LateJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) and vote and not vote.finished then
            SendStart(ply)
            SendTally()
        end
    end)
end)

hook.Add("PlayerDisconnected", "ZB_MapVote_Leave", function(ply)
    cooldown[ply] = nil
    if vote and vote.ballots[ply] then
        vote.ballots[ply] = nil
        timer.Simple(0, SendTally)
    end
end)

function zb.RTVMenu(ply)
    net.Start("RTVMenu")
    net.Send(ply)
end

-- !clearreview <name or part of it>: removes that player's review on this map.
COMMANDS.clearreview = {function(ply, args)
    if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
    local needle = string.lower(table.concat(args or {}, " "))
    if needle == "" then ply:ChatPrint("Usage: !clearreview <name>") return end
    local cur, removed = game.GetMap(), 0
    for sid, v in pairs(mapRatings[cur] or {}) do
        local e = Entry(v)
        if e and string.find(string.lower(e.n or ""), needle, 1, true) then
            e.r = ""
            mapRatings[cur][sid] = e
            removed = removed + 1
        end
    end
    QueueSaveRatings()
    ply:ChatPrint("Cleared " .. removed .. " review(s) on " .. cur .. ".")
    if vote then SendRating() end
end, 0}

COMMANDS.forcertv = {function(ply, args)
    if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
    zb.StartRTV(20)
end, 0}

--;; ---------- !rtv (vote to start a map vote) ----------
local rtvVotes = {}

function zb.ClearRTVVotes()
    rtvVotes = {}
end

function zb.CheckRTVVotes(needPrint)
    local votesNeeded = math.ceil(#player.GetAll() / 2)
    if table.Count(rtvVotes) >= votesNeeded then
        if needPrint then
            for _, v in player.Iterator() do
                v:ChatPrint("Enough votes to change the map. RTV will be on next round.")
            end
        end
        return true
    end
    return false
end

local function rtv(ply, args)
    if zb.votestarted then
        zb.RTVMenu(ply)
        return
    end

    local steamID = ply:SteamID()
    if rtvVotes[steamID] then
        rtvVotes[steamID] = nil
        ply:ChatPrint("You canceled your vote for map change.")
        return
    end

    rtvVotes[steamID] = true

    local remaining = math.ceil(#player.GetAll() / 2) - table.Count(rtvVotes)
    if remaining > 0 then
        for _, v in player.Iterator() do
            v:ChatPrint(ply:Nick() .. " voted for map change. " .. remaining .. " more votes needed. Type !rtv again to cancel your vote.")
        end
    end

    zb.CheckRTVVotes(true)
end

COMMANDS.rtv = {rtv, 0}
COMMANDS.кем = {rtv, 0}

hook.Add("ShutDown", "ResetRTVVotesOnMapChange", zb.ClearRTVVotes)
hook.Add("PostGamemodeLoaded", "InitializeRTVSystem", zb.ClearRTVVotes)

hook.Add("PlayerDisconnected", "CheckRTVAfterDisconnect", function(ply)
    if rtvVotes[ply:SteamID()] then
        rtvVotes[ply:SteamID()] = nil
        timer.Simple(0.1, zb.CheckRTVVotes)
    end
end)
