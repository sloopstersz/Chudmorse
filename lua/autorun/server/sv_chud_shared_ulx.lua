-- Chudmorse: ULX ranks and bans shared between server 1 and server 2 (uses ChudShared's connection).
--  * Rank / ban / unban on either server -> the other applies it within ~15s, and right away
--    when that player joins.
--  * Ranks + permissions (allows, inheritance, can_target, team) are copied ONE WAY from
--    server 1 to server 2. Edit permissions on server 1. Ranks that only exist on server 2 are left alone.
-- Console: chud_ulx_sync, chud_ulx_publish (server 1), chud_ulx_seed confirm (server 1)

if not SERVER then return end

ChudULX = ChudULX or {}
local U = ChudULX
local POLL = 15

local function Log(...) MsgC(Color(200, 200, 205), "[ChudULX] ", color_white, string.format(...), "\n") end
local function CS() return ChudShared end
local function Q(s) return ChudShared.Q(s) end
local NOW = "ROUND(UNIX_TIMESTAMP(NOW(3)) * 1000)"

U.applying = false
U.userMark = U.userMark or 0
U.banMark = U.banMark or 0
U.groupsStamp = U.groupsStamp or ""

local function HasULib() return ULib and ULib.ucl and ULib.ucl.users and ULib.ucl.groups end
local function Role() return CS() and CS().Role() or 2 end

local function Apply(fn, ...)
    U.applying = true
    local ok, err = pcall(fn, ...)
    U.applying = false
    if not ok then Log("apply error: %s", tostring(err)) end
end

---------------------------------------------------------------------------
-- Writing local changes
---------------------------------------------------------------------------
local function WriteUser(id, group, name)
    if not CS() or not id or id == "" then return end
    CS().AddUlxStatement(string.format([[INSERT INTO chud_ulx_users (steamid, grp, name, updated, origin) VALUES (%s, %s, %s, %s, %d)
        ON DUPLICATE KEY UPDATE grp = VALUES(grp), name = IF(VALUES(name) = '', name, VALUES(name)), updated = VALUES(updated), origin = VALUES(origin)]],
        Q(id), Q(group or "user"), Q(name or ""), NOW, Role()))
end

local function WriteBan(steamid, b, active)
    if not CS() or not steamid then return end
    b = b or {}
    CS().AddUlxStatement(string.format([[INSERT INTO chud_ulx_bans (steamid, active, unban, reason, name, admin, time, updated, origin)
        VALUES (%s, %d, %s, %s, %s, %s, %s, %s, %d)
        ON DUPLICATE KEY UPDATE active = VALUES(active), unban = IF(VALUES(active) = 1, VALUES(unban), unban),
        reason = IF(VALUES(active) = 1, VALUES(reason), reason), name = IF(VALUES(name) = '', name, VALUES(name)),
        admin = IF(VALUES(active) = 1, VALUES(admin), admin), time = IF(VALUES(active) = 1, VALUES(time), time),
        updated = VALUES(updated), origin = VALUES(origin)]],
        Q(steamid), active and 1 or 0, tostring(math.floor(tonumber(b.unban) or 0)), Q(b.reason or ""), Q(b.name or ""),
        Q(b.admin or ""), tostring(math.floor(tonumber(b.time) or os.time())), NOW, Role()))
end

local function HookULib()
    hook.Add("ULibUserGroupChange", "ChudULX", function(id, _, _, newGroup)
        if U.applying then return end
        local ply = player.GetBySteamID(id)
        WriteUser(id, newGroup, IsValid(ply) and ply:Nick() or (ULib.ucl.users[id] and ULib.ucl.users[id].name))
    end)
    hook.Add("ULibUserRemoved", "ChudULX", function(id)
        if U.applying then return end
        WriteUser(id, "user")
    end)
    hook.Add("ULibPlayerBanned", "ChudULX", function(steamid, data)
        if U.applying then return end
        WriteBan(steamid, data or (ULib.bans and ULib.bans[steamid]), true)
    end)
    hook.Add("ULibPlayerUnBanned", "ChudULX", function(steamid)
        if U.applying then return end
        WriteBan(steamid, nil, false)
    end)

    if Role() == 1 then
        for _, h in ipairs({"ULibGroupCreated", "ULibGroupRemoved", "ULibGroupAccessChanged", "ULibGroupRenamed",
            "ULibGroupInheritanceChanged", "ULibGroupCanTargetChanged"}) do
            hook.Add(h, "ChudULX", function() timer.Create("ChudULX_Publish", 3, 1, U.PublishGroups) end)
        end
    end
end

---------------------------------------------------------------------------
-- Applying remote changes
---------------------------------------------------------------------------
local function ApplyUser(row)
    local id, group = row.steamid, row.grp
    local cur = ULib.ucl.users[id]
    if group == "user" or group == "" then
        if cur then Apply(ULib.ucl.removeUser, id) end
        return true
    end
    if not ULib.ucl.groups[group] then return false end -- rank not here (yet)
    if not cur or cur.group ~= group then
        Apply(ULib.ucl.addUser, id, cur and cur.allow or nil, cur and cur.deny or nil, group)
        local ply = player.GetBySteamID(id)
        Log("%s -> %s (from the other server)", IsValid(ply) and ply:Nick() or (row.name ~= "" and row.name or id), group)
    end
    return true
end

local function ApplyBan(row)
    local sid = row.steamid
    local active = tonumber(row.active) == 1
    local unban = tonumber(row.unban) or 0
    local cur = ULib.bans and ULib.bans[sid]
    if active and (unban == 0 or unban > os.time()) then
        if cur and (tonumber(cur.unban) or 0) == unban then return end
        local minutes = unban == 0 and 0 or math.max(math.ceil((unban - os.time()) / 60), 1)
        Apply(ULib.addBan, sid, minutes, row.reason ~= "" and row.reason or nil, row.name ~= "" and row.name or nil)
        if ULib.bans[sid] and row.admin ~= "" then ULib.bans[sid].admin = row.admin end
        Log("ban %s applied from the other server", sid)
    elseif cur and not active then
        Apply(ULib.unban, sid)
        Log("unban %s applied from the other server", sid)
    end
end

local function PollUsers(full)
    local where = full and "" or (" WHERE updated >= " .. tostring(math.max(U.userMark - 5000, 0)))
    CS().Query("SELECT steamid, grp, name, updated, " .. NOW .. " AS now FROM chud_ulx_users" .. where, function(rows)
        local missing = 0
        for _, r in ipairs(rows) do
            if not ApplyUser(r) then missing = missing + 1 end
            U.userMark = math.max(U.userMark, tonumber(r.now) or 0)
        end
        if #rows == 0 then
            CS().Query("SELECT " .. NOW .. " AS now", function(n) if n[1] then U.userMark = math.max(U.userMark, tonumber(n[1].now) or 0) end end)
        end
        if missing > 0 and full then Log("%d players have a rank that does not exist on this server yet.", missing) end
    end)
end

local function PollBans(full)
    local where = full and "" or (" WHERE updated >= " .. tostring(math.max(U.banMark - 5000, 0)))
    CS().Query("SELECT *, " .. NOW .. " AS now FROM chud_ulx_bans" .. where, function(rows)
        for _, r in ipairs(rows) do
            ApplyBan(r)
            U.banMark = math.max(U.banMark, tonumber(r.now) or 0)
        end
        if #rows == 0 then
            CS().Query("SELECT " .. NOW .. " AS now", function(n) if n[1] then U.banMark = math.max(U.banMark, tonumber(n[1].now) or 0) end end)
        end
    end)
end

---------------------------------------------------------------------------
-- Ranks + permissions, one way: server 1 -> server 2
---------------------------------------------------------------------------
local function Snapshot()
    local out = {}
    for name, g in pairs(ULib.ucl.groups) do
        out[name] = {allow = g.allow or {}, inherit_from = g.inherit_from, can_target = g.can_target, team = g.team}
    end
    return out
end

function U.PublishGroups()
    if Role() ~= 1 or not HasULib() or not (CS() and CS().IsConnected()) then return end
    local json = util.TableToJSON(Snapshot())
    CS().AddUlxStatement("REPLACE INTO chud_shared_meta (k, v) VALUES ('ulx_groups', " .. Q(json) .. ")")
    CS().AddUlxStatement("REPLACE INTO chud_shared_meta (k, v) VALUES ('ulx_groups_stamp', " .. Q(tostring(os.time()) .. "-" .. util.CRC(json)) .. ")")
    Log("Published %d ranks + permissions for server 2.", table.Count(ULib.ucl.groups))
end

local function AccessSet(allow)
    local set = {}
    for k, v in pairs(allow or {}) do
        if isnumber(k) then set[v] = true else set[k] = v end
    end
    return set
end

local function Try(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Log("could not %s: %s", what, tostring(err)) end
    return ok
end

local function ApplyGroups(groups)
    local created, updated = 0, 0
    U.applying = true
    local ok, err = pcall(function()
        -- 1) create missing ranks
        for name in pairs(groups) do
            if not ULib.ucl.groups[name] then
                if Try("create rank " .. name, ULib.ucl.addGroup, name) then created = created + 1 end
            end
        end
        -- 2) inheritance, can_target, team, permissions
        for name, g in pairs(groups) do
            local local_ = ULib.ucl.groups[name]
            if local_ then
                local touched = false
                if g.inherit_from and local_.inherit_from ~= g.inherit_from and ULib.ucl.groups[g.inherit_from] then
                    touched = Try("set inheritance of " .. name, ULib.ucl.setGroupInheritance, name, g.inherit_from) or touched
                end
                if local_.can_target ~= g.can_target then
                    touched = Try("set can_target of " .. name, ULib.ucl.setGroupCanTarget, name, g.can_target) or touched
                end
                local want, have = AccessSet(g.allow), AccessSet(local_.allow)
                for access, tag in pairs(want) do
                    if have[access] == nil or have[access] ~= tag then
                        touched = Try("give " .. access .. " to " .. name, ULib.ucl.groupAllow, name, tag == true and access or {[access] = tag}) or touched
                    end
                end
                for access in pairs(have) do
                    if want[access] == nil then
                        touched = Try("remove " .. access .. " from " .. name, ULib.ucl.groupAllow, name, access, true) or touched
                    end
                end
                if g.team ~= nil and util.TableToJSON({g.team}) ~= util.TableToJSON({local_.team}) then
                    local_.team = table.Copy(g.team)
                    touched = true
                end
                if touched then updated = updated + 1 end
            end
        end
        if ULib.ucl.saveGroups then ULib.ucl.saveGroups() end
        if ulx and ulx.refreshTeams then ulx.refreshTeams() end
    end)
    U.applying = false
    if not ok then Log("rank copy error: %s", tostring(err)) return end
    Log("Copied ranks from server 1: %d created, %d updated", created, updated)
    if created > 0 then PollUsers(true) end -- players whose rank was missing can get it now
end

local function PollGroups(force)
    if Role() ~= 2 then return end
    CS().Query("SELECT k, v FROM chud_shared_meta WHERE k IN ('ulx_groups', 'ulx_groups_stamp')", function(rows)
        local data, stamp
        for _, r in ipairs(rows) do
            if r.k == "ulx_groups" then data = r.v elseif r.k == "ulx_groups_stamp" then stamp = r.v end
        end
        if not data or not stamp then return end
        if stamp == U.groupsStamp and not force then return end
        local groups = util.JSONToTable(data)
        if not istable(groups) then return end
        U.groupsStamp = stamp
        ApplyGroups(groups)
    end)
end

---------------------------------------------------------------------------
-- First run on server 1: seed the shared tables with server 1's ULX users + bans
---------------------------------------------------------------------------
function U.Seed(force)
    if Role() ~= 1 or not HasULib() then return end
    CS().Query("SELECT v FROM chud_shared_meta WHERE k = 'ulx_seeded'", function(rows)
        if rows[1] and not force then return end
        local users, bans = 0, 0
        for id, u in pairs(ULib.ucl.users) do
            if u.group and u.group ~= "user" then WriteUser(id, u.group, u.name) users = users + 1 end
        end
        for sid, b in pairs(ULib.bans or {}) do
            if (tonumber(b.unban) or 0) == 0 or tonumber(b.unban) > os.time() then WriteBan(sid, b, true) bans = bans + 1 end
        end
        CS().AddUlxStatement("REPLACE INTO chud_shared_meta (k, v) VALUES ('ulx_seeded', " .. Q(os.date("!%Y-%m-%d %H:%M:%S")) .. ")")
        Log("Seeded shared ULX data: %d ranks, %d bans.", users, bans)
    end)
end

---------------------------------------------------------------------------
-- Start-up, polling, joining players
---------------------------------------------------------------------------
local started = false
local function Start()
    if started or not HasULib() or not (CS() and CS().IsConnected()) then return end
    started = true
    HookULib()
    if Role() == 1 then
        U.Seed()
        timer.Simple(2, U.PublishGroups)
    end
    -- a full pull on start catches anything changed while this server was down
    timer.Simple(4, function()
        PollGroups(true)
        timer.Simple(3, function() PollUsers(true) PollBans(true) end)
    end)
    timer.Create("ChudULX_Poll", POLL, 0, function()
        if not CS().IsConnected() then return end
        PollGroups()
        PollUsers()
        PollBans()
    end)
    Log("ULX rank/ban sync running (server %d).", Role())
end

hook.Add("ChudShared_Connected", "ChudULX_Start", function() timer.Simple(3, Start) end)
timer.Create("ChudULX_StartRetry", 10, 0, function()
    if started then timer.Remove("ChudULX_StartRetry") return end
    Start()
end)

-- apply this player's rank / ban right away when they join
hook.Add("PlayerAuthed", "ChudULX_Join", function(ply, steamid)
    if not started or not CS().IsConnected() then return end
    CS().Query("SELECT steamid, grp, name FROM chud_ulx_users WHERE steamid = " .. Q(steamid), function(rows)
        if rows[1] and IsValid(ply) then ApplyUser(rows[1]) end
    end)
    CS().Query("SELECT * FROM chud_ulx_bans WHERE steamid = " .. Q(steamid), function(rows)
        if rows[1] then ApplyBan(rows[1]) end
    end)
end)

---------------------------------------------------------------------------
-- Console
---------------------------------------------------------------------------
concommand.Add("chud_ulx_sync", function(ply)
    if IsValid(ply) then return end
    if not started then print("[ChudULX] not running (no ULX or no shared database).") return end
    PollGroups(true)
    timer.Simple(3, function() PollUsers(true) PollBans(true) end)
    print("[ChudULX] full re-sync started.")
end)

concommand.Add("chud_ulx_publish", function(ply)
    if IsValid(ply) then return end
    if Role() ~= 1 then print("[ChudULX] Run this on SERVER 1.") return end
    U.PublishGroups()
end)

concommand.Add("chud_ulx_seed", function(ply, _, args)
    if IsValid(ply) then return end
    if Role() ~= 1 then print("[ChudULX] Run this on SERVER 1.") return end
    if args[1] ~= "confirm" then print("[ChudULX] chud_ulx_seed confirm  - re-uploads server 1's ULX ranks + bans") return end
    U.Seed(true)
end)
