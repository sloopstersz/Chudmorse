-- Chudmorse shared data between server 1 and server 2.
-- Shared: EXP/skill/kills/deaths/suicides, COIN, gun skins, achievements, achievement COIN payouts.
-- NOT shared: karma, pointshop points, playtime (those keep using each server's own database).
--
-- How it stays safe:
--  * EXP stats and COIN are written as "+N" changes, so the servers never overwrite each other.
--  * Achievements only ever go up (GREATEST).
--  * Every change is queued (and saved to data/chud_shared/pending.json) until MySQL accepts it,
--    so nothing is lost if the database is down or the server crashes.
--  * Shared writes wait until server 1 has imported its existing data once.
--
-- Console: chud_shared_status, chud_shared_import confirm (server 1), chud_shared_flush

if not SERVER then return end

ChudShared = ChudShared or {}
local CS = ChudShared

-- Login lives in each server's DATA folder (garrysmod/data/chud_shared/login.json), NOT in the
-- addon, so it can never leak through the Workshop or a public git repo.
local LOGIN_FILE = "chud_shared/login.json"
local function ReadLogin()
    local t = util.JSONToTable(file.Read(LOGIN_FILE, "DATA") or "")
    if istable(t) and t.host and t.user and t.password and t.database then return t end
end
local FLUSH_INTERVAL = 3
local DATA_DIR = "chud_shared"
local PENDING_FILE = DATA_DIR .. "/pending.json"
local ROLE_FILE = "chud_shared_server.txt"

local function Log(...)
    MsgC(Color(200, 200, 205), "[ChudShared] ", color_white, string.format(...), "\n")
end

---------------------------------------------------------------------------
-- Server role (1 = original server with all existing data, 2 = second server)
---------------------------------------------------------------------------
local roleVar = CreateConVar("chud_server_id", "0", FCVAR_ARCHIVE + FCVAR_PROTECTED,
    "1 = original Chudmorse server, 2 = second server, 0 = auto (data/chud_shared_server.txt, then port 27015 = server 1)")

function CS.Role()
    local forced = roleVar:GetInt()
    if forced == 1 or forced == 2 then return forced end
    local fileRole = tonumber(string.Trim(file.Read(ROLE_FILE, "DATA") or ""))
    if fileRole == 1 or fileRole == 2 then return fileRole end
    local port = GetConVar("hostport") and GetConVar("hostport"):GetInt() or 0
    return port == 27015 and 1 or 2
end

---------------------------------------------------------------------------
-- Pending changes (persisted to disk)
---------------------------------------------------------------------------
local EXP_FIELDS = {"skill", "experience", "deaths", "kills", "suicides"}
CS.EXP_FIELDS = EXP_FIELDS

local P
local function LoadPending()
    if not file.Exists(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
    local t = util.JSONToTable(file.Read(PENDING_FILE, "DATA") or "") or {}
    t.exp = istable(t.exp) and t.exp or {}
    t.coin = istable(t.coin) and t.coin or {}
    t.ach = istable(t.ach) and t.ach or {}
    t.stmts = istable(t.stmts) and t.stmts or {}
    t.ulx = istable(t.ulx) and t.ulx or {}
    return t
end
P = CS.Pending or LoadPending()
CS.Pending = P

local saveQueued = false
local function SavePending()
    if saveQueued then return end
    saveQueued = true
    timer.Simple(1, function()
        saveQueued = false
        file.Write(PENDING_FILE, util.TableToJSON(P))
    end)
end
CS.SavePending = SavePending

---------------------------------------------------------------------------
-- Connection
---------------------------------------------------------------------------
CS.DB = CS.DB
CS.Connected = CS.Connected or false
CS.ImportDone = CS.ImportDone or false

local function Esc(s)
    s = tostring(s or "")
    if CS.DB then return CS.DB:escape(s) end
    return (s:gsub("[\\'\"%z\n\r]", function(c) return "\\" .. (c == "\0" and "0" or c == "\n" and "n" or c == "\r" and "r" or c) end))
end
CS.Esc = Esc
local function Q(s) return "'" .. Esc(s) .. "'" end
CS.Q = Q
local function Num(n) return tostring(math.floor((tonumber(n) or 0) + 0)) end
local function Flt(n) return string.format("%.4f", tonumber(n) or 0) end
-- player names: cut to 60 characters without splitting a multi-byte character
local function Name(s)
    s = tostring(s or "")
    if not utf8.len(s) then s = s:gsub("[\128-\255]", "?") end
    if (utf8.len(s) or 0) <= 60 then return s end
    local out, n = {}, 0
    for _, code in utf8.codes(s) do
        n = n + 1
        if n > 60 then break end
        out[n] = utf8.char(code)
    end
    return table.concat(out)
end

function CS.IsConnected()
    return CS.DB ~= nil and CS.Connected and CS.DB:status() == mysqloo.DATABASE_CONNECTED
end

-- true when shared data can be read/written for players
function CS.IsReady() return CS.IsConnected() and CS.ImportDone end

function CS.Query(sql, onSuccess, onError)
    if not CS.IsConnected() then
        if onError then onError("not connected") end
        return
    end
    local q = CS.DB:query(sql)
    q.onSuccess = function(_, data) if onSuccess then onSuccess(data or {}, q) end end
    q.onError = function(_, err)
        Log("query error: %s | %s", err, string.sub(sql, 1, 200))
        if onError then onError(err) end
    end
    q:start()
    return q
end

local function Transaction(sqls, onSuccess, onError)
    if not CS.IsConnected() then if onError then onError("not connected") end return end
    if #sqls == 0 then if onSuccess then onSuccess() end return end
    local tr = CS.DB:createTransaction()
    for _, s in ipairs(sqls) do tr:addQuery(CS.DB:query(s)) end
    tr.onSuccess = function() if onSuccess then onSuccess() end end
    tr.onError = function(_, err)
        Log("transaction error: %s", tostring(err))
        if onError then onError(err) end
    end
    tr:start()
    return tr
end
CS.Transaction = Transaction

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS chud_shared_meta (k VARCHAR(64) NOT NULL PRIMARY KEY, v TEXT NULL) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_shared_exp (steamid VARCHAR(20) NOT NULL PRIMARY KEY, steam_name VARCHAR(64) NOT NULL DEFAULT '',
        skill DOUBLE NOT NULL DEFAULT 0, experience BIGINT NOT NULL DEFAULT 0, deaths BIGINT NOT NULL DEFAULT 0,
        kills BIGINT NOT NULL DEFAULT 0, suicides BIGINT NOT NULL DEFAULT 0, KEY exp_idx (experience)) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_shared_coin (steamid VARCHAR(20) NOT NULL PRIMARY KEY, balance BIGINT NOT NULL DEFAULT 0) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_shared_skins (steamid VARCHAR(20) NOT NULL, item VARCHAR(64) NOT NULL, equipped TINYINT NOT NULL DEFAULT 0,
        PRIMARY KEY (steamid, item)) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_shared_ach (steamid VARCHAR(20) NOT NULL, ach VARCHAR(64) NOT NULL, value BIGINT NOT NULL DEFAULT 0,
        obtained_at BIGINT NULL, PRIMARY KEY (steamid, ach)) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_shared_achcoin (steamid VARCHAR(20) NOT NULL, ach VARCHAR(64) NOT NULL,
        PRIMARY KEY (steamid, ach)) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_ulx_users (steamid VARCHAR(64) NOT NULL PRIMARY KEY, grp VARCHAR(64) NOT NULL,
        name VARCHAR(64) NOT NULL DEFAULT '', updated BIGINT NOT NULL, origin TINYINT NOT NULL DEFAULT 0) DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS chud_ulx_bans (steamid VARCHAR(64) NOT NULL PRIMARY KEY, active TINYINT NOT NULL, unban BIGINT NOT NULL DEFAULT 0,
        reason TEXT NULL, name VARCHAR(64) NOT NULL DEFAULT '', admin VARCHAR(128) NOT NULL DEFAULT '', time BIGINT NOT NULL DEFAULT 0,
        updated BIGINT NOT NULL, origin TINYINT NOT NULL DEFAULT 0) DEFAULT CHARSET=utf8mb4]],
}

local function MarkReady()
    if CS.ImportDone then return end
    CS.ImportDone = true
    Log("Shared data is live (server %d).", CS.Role())
    hook.Run("ChudShared_Ready")
    for _, ply in player.Iterator() do CS.LoadPlayer(ply) end
    if CS.Role() == 2 and CS.LocalDBReady then CS.RunImport(2) end
end

local function CheckImportFlag()
    CS.Query("SELECT v FROM chud_shared_meta WHERE k = 'import_s1'", function(rows)
        local done = rows[1] ~= nil
        if done then
            MarkReady()
        elseif not done and CS.Role() == 1 then
            if CS.LocalDBReady then CS.RunImport(1) end -- otherwise DatabaseConnected starts it
        elseif not done then
            Log("Waiting for server 1 to import its data. Changes are queued meanwhile.")
        end
    end)
end

function CS.Connect()
    local LOGIN = ReadLogin()
    if not LOGIN then
        Log("garrysmod/data/%s is missing or incomplete - shared data disabled, using local data only.", LOGIN_FILE)
        return
    end
    if not util.IsBinaryModuleInstalled("mysqloo") then
        Log("MySQLOO is not installed - shared data disabled, using local data only.")
        return
    end
    if not mysqloo then require("mysqloo") end
    if not mysqloo then Log("MySQLOO failed to load.") return end

    if CS.DB then pcall(function() CS.DB:disconnect() end) end
    local db = mysqloo.connect(LOGIN.host, LOGIN.user, LOGIN.password, LOGIN.database, LOGIN.port or 3306)
    if db.setAutoReconnect then db:setAutoReconnect(true) end
    CS.DB = db

    function db:onConnected()
        CS.Connected = true
        if self.setCharacterSet then pcall(self.setCharacterSet, self, "utf8mb4") end
        Log("Connected to the shared database (this is server %d).", CS.Role())
        Transaction(TABLES, function()
            hook.Run("ChudShared_Connected")
            CheckImportFlag()
        end)
    end

    function db:onConnectionFailed(err)
        CS.Connected = false
        Log("Could not connect to the shared database: %s. Retrying in 30s, local data is used meanwhile.", tostring(err))
        timer.Create("ChudShared_Reconnect", 30, 1, CS.Connect)
    end

    db:connect()
end

hook.Add("Initialize", "ChudShared_Connect", function() timer.Simple(1, CS.Connect) end)
if GAMEMODE then timer.Simple(1, function() if not CS.DB then CS.Connect() end end) end

timer.Create("ChudShared_Watch", 10, 0, function()
    if not CS.DB then return end
    local st = CS.DB:status()
    if CS.Connected and (st == mysqloo.DATABASE_NOT_CONNECTED or st == mysqloo.DATABASE_INTERNAL_ERROR) then
        -- was connected, now isn't: start over (failed attempts retry on their own timer)
        Log("Lost the shared database, reconnecting...")
        CS.Connected = false
        CS.Connect()
    elseif CS.Connected and not CS.ImportDone then
        CheckImportFlag()
    end
end)

---------------------------------------------------------------------------
-- Queueing changes
---------------------------------------------------------------------------
function CS.AddExpDelta(sid, name, field, delta)
    delta = tonumber(delta) or 0
    if delta == 0 or not sid or sid == "" then return end
    local e = P.exp[sid] or {}
    e[field] = (e[field] or 0) + delta
    if name then e.name = Name(name) end
    P.exp[sid] = e
    SavePending()
end

function CS.PendingExp(sid, field)
    local e = P.exp[sid]
    return e and tonumber(e[field]) or 0
end

function CS.AddCoinDelta(sid, delta)
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 or not sid or sid == "" then return end
    P.coin[sid] = (P.coin[sid] or 0) + delta
    SavePending()
end

function CS.PendingCoin(sid) return tonumber(P.coin[sid]) or 0 end

function CS.RaiseAch(sid, key, value, obtained)
    value = math.floor(tonumber(value) or 0)
    if not sid or sid == "" or not key then return end
    P.ach[sid] = P.ach[sid] or {}
    local cur = P.ach[sid][key]
    if not cur or value > cur.v then
        P.ach[sid][key] = {v = value, o = tonumber(obtained) or (cur and cur.o) or nil}
        SavePending()
    end
end

function CS.AddStatement(sql)
    P.stmts[#P.stmts + 1] = sql
    SavePending()
end

function CS.AddUlxStatement(sql)
    P.ulx[#P.ulx + 1] = sql
    SavePending()
    CS.FlushUlx()
end

---------------------------------------------------------------------------
-- Flushing
---------------------------------------------------------------------------
local flushing, flushingUlx = false, false

local function ExpUpsert(sid, e)
    local d = {}
    for _, f in ipairs(EXP_FIELDS) do d[f] = tonumber(e[f]) or 0 end
    local name = Q(e.name or "")
    return string.format([[INSERT INTO chud_shared_exp (steamid, steam_name, skill, experience, deaths, kills, suicides)
        VALUES (%s, %s, GREATEST(%s,0), GREATEST(%s,0), GREATEST(%s,0), GREATEST(%s,0), GREATEST(%s,0))
        ON DUPLICATE KEY UPDATE skill = GREATEST(skill + (%s), 0), experience = GREATEST(experience + (%s), 0),
        deaths = GREATEST(deaths + (%s), 0), kills = GREATEST(kills + (%s), 0), suicides = GREATEST(suicides + (%s), 0)%s]],
        Q(sid), name, Flt(d.skill), Num(d.experience), Num(d.deaths), Num(d.kills), Num(d.suicides),
        Flt(d.skill), Num(d.experience), Num(d.deaths), Num(d.kills), Num(d.suicides),
        e.name and e.name ~= "" and ", steam_name = VALUES(steam_name)" or "")
end

local function CoinUpsert(sid, n)
    return string.format([[INSERT INTO chud_shared_coin (steamid, balance) VALUES (%s, GREATEST(%s,0))
        ON DUPLICATE KEY UPDATE balance = GREATEST(balance + (%s), 0)]], Q(sid), Num(n), Num(n))
end

local function AchUpsert(sid, key, a)
    return string.format([[INSERT INTO chud_shared_ach (steamid, ach, value, obtained_at) VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE value = GREATEST(value, VALUES(value)), obtained_at = COALESCE(obtained_at, VALUES(obtained_at))]],
        Q(sid), Q(key), Num(a.v), a.o and Num(a.o) or "NULL")
end

function CS.Flush(onDone)
    if flushing or not CS.IsReady() then if onDone then onDone(false) end return end
    local exp, coin, ach, stmts = P.exp, P.coin, P.ach, P.stmts
    if not next(exp) and not next(coin) and not next(ach) and #stmts == 0 then if onDone then onDone(true) end return end

    P.exp, P.coin, P.ach, P.stmts = {}, {}, {}, {}
    local sqls = {}
    for sid, e in pairs(exp) do sqls[#sqls + 1] = ExpUpsert(sid, e) end
    for sid, n in pairs(coin) do if n ~= 0 then sqls[#sqls + 1] = CoinUpsert(sid, n) end end
    for sid, keys in pairs(ach) do for key, a in pairs(keys) do sqls[#sqls + 1] = AchUpsert(sid, key, a) end end
    for _, s in ipairs(stmts) do sqls[#sqls + 1] = s end

    flushing = true
    return Transaction(sqls, function()
        flushing = false
        SavePending()
        if onDone then onDone(true) end
    end, function()
        flushing = false
        -- put everything back in front of anything queued meanwhile
        for sid, e in pairs(exp) do
            for f, v in pairs(e) do
                if f == "name" then P.exp[sid] = P.exp[sid] or {} P.exp[sid].name = P.exp[sid].name or v
                else CS.AddExpDelta(sid, nil, f, v) end
            end
        end
        for sid, n in pairs(coin) do CS.AddCoinDelta(sid, n) end
        for sid, keys in pairs(ach) do for key, a in pairs(keys) do CS.RaiseAch(sid, key, a.v, a.o) end end
        local merged = {}
        for _, s in ipairs(stmts) do merged[#merged + 1] = s end
        for _, s in ipairs(P.stmts) do merged[#merged + 1] = s end
        P.stmts = merged
        SavePending()
        if onDone then onDone(false) end
    end)
end

function CS.FlushUlx()
    if flushingUlx or not CS.IsConnected() or #P.ulx == 0 then return end
    local list = P.ulx
    P.ulx = {}
    flushingUlx = true
    Transaction(list, function()
        flushingUlx = false
        SavePending()
    end, function()
        flushingUlx = false
        for _, s in ipairs(P.ulx) do list[#list + 1] = s end
        P.ulx = list
        SavePending()
    end)
end

timer.Create("ChudShared_Flush", FLUSH_INTERVAL, 0, function()
    CS.Flush()
    CS.FlushUlx()
end)

hook.Add("PlayerDisconnected", "ChudShared_FlushOnLeave", function() timer.Simple(0.5, function() CS.Flush() end) end)

hook.Add("ShutDown", "ChudShared_FlushOnShutdown", function()
    file.Write(PENDING_FILE, util.TableToJSON(P))
    if not CS.IsReady() then return end
    -- block so the last changes make it in; anything left stays in pending.json for next start
    local tr = CS.Flush()
    if tr and tr.wait then pcall(tr.wait, tr) end
end)

---------------------------------------------------------------------------
-- Loading a player's shared data
---------------------------------------------------------------------------
function CS.LoadPlayer(ply)
    if not IsValid(ply) or ply:IsBot() or not CS.IsReady() then return end
    local sid = ply:SteamID64()
    local data, left = {}, 4
    local function done()
        left = left - 1
        if left > 0 or not IsValid(ply) then return end
        ply.ChudSharedLoaded = true
        hook.Run("ChudShared_PlayerLoaded", ply, data)
    end
    CS.Query("SELECT * FROM chud_shared_exp WHERE steamid = " .. Q(sid), function(r) data.exp = r[1] done() end, done)
    CS.Query("SELECT balance FROM chud_shared_coin WHERE steamid = " .. Q(sid), function(r) data.coin = r[1] and tonumber(r[1].balance) done() end, done)
    CS.Query("SELECT item, equipped FROM chud_shared_skins WHERE steamid = " .. Q(sid), function(r) data.skins = r done() end, done)
    CS.Query("SELECT ach, value, obtained_at FROM chud_shared_ach WHERE steamid = " .. Q(sid), function(r) data.ach = r done() end, done)
end

-- true when the shared DB is up but this player's shared data is not loaded yet
-- (used to hold back spending until we know the real balance)
function CS.Loading(ply)
    return CS.IsReady() and IsValid(ply) and not ply:IsBot() and not ply.ChudSharedLoaded
end

hook.Add("PlayerInitialSpawn", "ChudShared_Load", function(ply)
    -- small delay: lets the other server flush if the player just switched servers
    timer.Simple(3, function() if IsValid(ply) then CS.LoadPlayer(ply) end end)
end)

---------------------------------------------------------------------------
-- EXP helpers (used by sv_experience.lua)
---------------------------------------------------------------------------
CS.ExpBase = CS.ExpBase or {}

function CS.ExpSetBase(ply, inst)
    if not IsValid(ply) then return end
    local b = {}
    for _, f in ipairs(EXP_FIELDS) do b[f] = tonumber(inst[f]) or 0 end
    CS.ExpBase[ply:SteamID64()] = b
end

-- called whenever the experience instance is saved: queue whatever changed since last time
function CS.ExpChanged(ply, inst)
    if not IsValid(ply) or ply:IsBot() then return end
    local sid = ply:SteamID64()
    local b = CS.ExpBase[sid]
    if not b then CS.ExpSetBase(ply, inst) return end
    for _, f in ipairs(EXP_FIELDS) do
        local now = tonumber(inst[f]) or 0
        local d = now - (b[f] or 0)
        if d ~= 0 then
            CS.AddExpDelta(sid, ply:Name(), f, d)
            b[f] = now
        end
    end
end

hook.Add("PlayerDisconnected", "ChudShared_ExpCleanup", function(ply)
    local sid = ply:SteamID64()
    timer.Simple(1, function() if not player.GetBySteamID64(sid) then CS.ExpBase[sid] = nil end end)
end)

---------------------------------------------------------------------------
-- Admin stats editor: write only the fields the admin actually changed
---------------------------------------------------------------------------
CS.AdminRowCache = CS.AdminRowCache or {}

function CS.AdminSetStats(sid, name, before, after, achBefore, achAfter)
    if not sid or sid == "" then return end
    local sets = {}
    for _, f in ipairs(EXP_FIELDS) do
        local a, b = tonumber(after[f]), tonumber(before and before[f])
        if a and (b == nil or math.abs(a - b) > 0.0001) then
            sets[#sets + 1] = string.format("%s = %s", f, f == "skill" and Flt(a) or Num(a))
            -- drop queued +N for this field: the admin value replaces it
            if P.exp[sid] then P.exp[sid][f] = nil end
        end
    end
    if #sets > 0 then
        CS.AddStatement(string.format("INSERT IGNORE INTO chud_shared_exp (steamid, steam_name) VALUES (%s, %s)", Q(sid), Q(Name(name))))
        CS.AddStatement("UPDATE chud_shared_exp SET " .. table.concat(sets, ", ") .. " WHERE steamid = " .. Q(sid))
    end
    for key, v in pairs(achAfter or {}) do
        local a = tonumber(istable(v) and v.value or v) or 0
        local bv = achBefore and achBefore[key]
        local b = tonumber(istable(bv) and bv.value or bv)
        if b == nil or a ~= b then
            if P.ach[sid] then P.ach[sid][key] = nil end
            CS.AddStatement(string.format("REPLACE INTO chud_shared_ach (steamid, ach, value, obtained_at) VALUES (%s, %s, %s, NULL)", Q(sid), Q(key), Num(a)))
        end
    end
    -- the editor is about to replace the live values with `after`; baseline = after, so the
    -- admin change is not counted a second time as a +N
    local ply = player.GetBySteamID64(sid)
    if IsValid(ply) then CS.ExpSetBase(ply, after) end
    CS.Flush()
end

-- Overlay shared EXP/achievements on the admin stats list (offline players especially)
function CS.OverlayAdminRows(rows, cb)
    if not CS.IsReady() then cb(rows) return end
    CS.Query("SELECT * FROM chud_shared_exp", function(expRows)
        CS.Query("SELECT steamid, ach, value FROM chud_shared_ach", function(achRows)
            local byId, seen = {}, {}
            for _, r in ipairs(rows) do byId[r.steamid] = r end
            local ach = {}
            for _, a in ipairs(achRows) do
                ach[a.steamid] = ach[a.steamid] or {}
                ach[a.steamid][a.ach] = tonumber(a.value) or 0
            end
            for _, e in ipairs(expRows) do
                local sid = tostring(e.steamid)
                local r = byId[sid]
                if not r then
                    r = {steamid = sid, name = tostring(e.steam_name or "Unknown"), active = false, headshots = 0, karma = 100, achievements = {}}
                    rows[#rows + 1] = r
                    byId[sid] = r
                end
                if not r.active then
                    for _, f in ipairs(EXP_FIELDS) do r[f] = tonumber(e[f]) or 0 end
                    if ach[sid] then
                        r.achievements = r.achievements or {}
                        for k, v in pairs(ach[sid]) do r.achievements[k] = v end
                        if ach[sid].gollavo then r.headshots = ach[sid].gollavo end
                    end
                end
            end
            for _, r in ipairs(rows) do
                CS.AdminRowCache[r.steamid] = table.Copy(r)
            end
            cb(rows)
        end, function() cb(rows) end)
    end, function() cb(rows) end)
end

---------------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------------
function CS.TopExp(limit, cb)
    CS.Query("SELECT steamid, steam_name, skill, experience, deaths, kills, suicides FROM chud_shared_exp ORDER BY experience DESC LIMIT " .. Num(math.Clamp(limit or 50, 1, 200)),
        cb, function() cb(nil) end)
end

---------------------------------------------------------------------------
-- Achievement COIN payout ledger (shared so an achievement never pays twice)
---------------------------------------------------------------------------
function CS.ClaimAchCoin(sid, key, cb)
    if not CS.IsReady() then cb(nil) return end -- nil = unknown, caller decides
    local q = CS.Query(string.format("INSERT IGNORE INTO chud_shared_achcoin (steamid, ach) VALUES (%s, %s)", Q(sid), Q(key)),
        function(_, query) cb(query:affectedRows() > 0) end, function() cb(nil) end)
end

function CS.MarkAchCoin(sid, key)
    CS.AddStatement(string.format("INSERT IGNORE INTO chud_shared_achcoin (steamid, ach) VALUES (%s, %s)", Q(sid), Q(key)))
end

---------------------------------------------------------------------------
-- One-time import of existing data
--  server 1: copies everything (EXP, achievements, COIN, skins, payout ledger)
--  server 2: merges safely - highest EXP stats / achievements, union of skins and payouts,
--            COIN only for players server 1 has no COIN row for (no spent COIN comes back)
---------------------------------------------------------------------------
local importing = false

local function Chunked(rows, build, prefix, suffix)
    local sqls, batch = {}, {}
    for _, r in ipairs(rows) do
        local v = build(r)
        if v then batch[#batch + 1] = v end
        if #batch >= 200 then sqls[#sqls + 1] = prefix .. table.concat(batch, ",") .. suffix batch = {} end
    end
    if #batch > 0 then sqls[#sqls + 1] = prefix .. table.concat(batch, ",") .. suffix end
    return sqls
end

CS.LocalDBReady = CS.LocalDBReady or false
hook.Add("DatabaseConnected", "ChudShared_LocalDBReady", function() CS.LocalDBReady = true end)

-- Reads a table through the gamemode's own database connection (sqlite or this server's MySQL).
-- cb(rows) on success, cb(nil) if it failed or timed out (the import then aborts, nothing is written).
local function ReadLocalTable(tbl, cb)
    if not (CS.LocalDBReady and mysql and mysql.RawQuery) then cb(nil) return end
    local answered = false
    local function reply(rows) if answered then return end answered = true cb(rows) end
    local ok = pcall(function()
        mysql:RawQuery("SELECT * FROM " .. tbl, function(rows) reply(istable(rows) and rows or {}) end)
    end)
    if not ok then
        -- sqlite: table missing means this server never had that data
        if mysql.module == "sqlite" and not sql.TableExists(tbl) then reply({}) else reply(nil) end
        return
    end
    timer.Simple(30, function() reply(nil) end) -- MySQL errors have no callback
end

function CS.RunImport(which, force)
    if importing or not CS.IsConnected() then return end
    local key = which == 1 and "import_s1" or "import_s2"
    CS.Query("SELECT v FROM chud_shared_meta WHERE k = " .. Q(key), function(rows)
        if rows[1] and not force then return end
        importing = true
        if which == 1 then
            Log("[import] Original server detected - copying existing data...")
        else
            Log("[import] Merging server 2's existing data (highest values win, no COIN duplication)...")
        end

        local counts = {exp = 0, ach = 0, coin = 0, skins = 0}
        local sqls = {}
        local gotExp, gotAch, aborted = false, false, false

        local function abort(what)
            if aborted then return end
            aborted = true
            importing = false
            Log("[import] Could not read %s from this server's database yet - will retry when it connects. Nothing was written.", what)
        end

        local function finish()
            if aborted or not (gotExp and gotAch) then return end
            -- local SQLite tables (COIN, skins, payouts)
            local coinRows = sql.Query("SELECT steamid, balance FROM chud_coin") or {}
            counts.coin = #coinRows
            for _, s in ipairs(Chunked(coinRows, function(r)
                return string.format("(%s, %s)", Q(r.steamid), Num(math.max(tonumber(r.balance) or 0, 0)))
            end, "INSERT IGNORE INTO chud_shared_coin (steamid, balance) VALUES ", "")) do sqls[#sqls + 1] = s end

            local skinRows = sql.Query("SELECT steamid, item, equipped FROM chud_skins") or {}
            counts.skins = #skinRows
            for _, s in ipairs(Chunked(skinRows, function(r)
                return string.format("(%s, %s, %s)", Q(r.steamid), Q(r.item), tonumber(r.equipped) == 1 and "1" or "0")
            end, "INSERT IGNORE INTO chud_shared_skins (steamid, item, equipped) VALUES ", "")) do sqls[#sqls + 1] = s end

            local paid = sql.Query("SELECT steamid, achievement FROM chud_achievement_coin") or {}
            for _, s in ipairs(Chunked(paid, function(r)
                return string.format("(%s, %s)", Q(r.steamid), Q(r.achievement))
            end, "INSERT IGNORE INTO chud_shared_achcoin (steamid, ach) VALUES ", "")) do sqls[#sqls + 1] = s end

            sqls[#sqls + 1] = string.format("REPLACE INTO chud_shared_meta (k, v) VALUES (%s, %s)", Q(key), Q(os.date("!%Y-%m-%d %H:%M:%S")))

            Transaction(sqls, function()
                importing = false
                Log("[import] Done. EXP %d, achievements %d, COIN %d, skins %d.", counts.exp, counts.ach, counts.coin, counts.skins)
                if which == 1 then MarkReady() end
            end, function(err)
                importing = false
                Log("[import] FAILED (%s). Nothing was written; it will retry on next start or with chud_shared_import confirm.", tostring(err))
            end)
        end

        ReadLocalTable("zb_experience", function(rows)
            if aborted then return end
            if rows == nil then abort("EXP (zb_experience)") return end
            gotExp = true
            counts.exp = #rows
            for _, s in ipairs(Chunked(rows, function(r)
                if not r.steamid or r.steamid == "" then return end
                return string.format("(%s, %s, %s, %s, %s, %s, %s)", Q(r.steamid), Q(Name(r.steam_name)), Flt(r.skill),
                    Num(r.experience), Num(r.deaths), Num(r.kills), Num(r.suicides))
            end, "INSERT INTO chud_shared_exp (steamid, steam_name, skill, experience, deaths, kills, suicides) VALUES ",
            " ON DUPLICATE KEY UPDATE skill = GREATEST(skill, VALUES(skill)), experience = GREATEST(experience, VALUES(experience)), " ..
            "deaths = GREATEST(deaths, VALUES(deaths)), kills = GREATEST(kills, VALUES(kills)), suicides = GREATEST(suicides, VALUES(suicides))")) do
                sqls[#sqls + 1] = s
            end
            finish()
        end)

        ReadLocalTable("hg_achievements", function(rows)
            if aborted then return end
            if rows == nil then abort("achievements (hg_achievements)") return end
            gotAch = true
            local flat = {}
            for _, r in ipairs(rows or {}) do
                for k, v in pairs(util.JSONToTable(r.achievements or "") or {}) do
                    local val = tonumber(istable(v) and v.value or v)
                    if val and val > 0 then
                        flat[#flat + 1] = {sid = r.steamid, k = k, v = val, o = istable(v) and tonumber(v.obtained_at) or nil}
                    end
                end
            end
            counts.ach = #flat
            for _, s in ipairs(Chunked(flat, function(a)
                return string.format("(%s, %s, %s, %s)", Q(a.sid), Q(a.k), Num(a.v), a.o and Num(a.o) or "NULL")
            end, "INSERT INTO chud_shared_ach (steamid, ach, value, obtained_at) VALUES ",
            " ON DUPLICATE KEY UPDATE value = GREATEST(value, VALUES(value)), obtained_at = COALESCE(obtained_at, VALUES(obtained_at))")) do
                sqls[#sqls + 1] = s
            end
            finish()
        end)
    end)
end

-- the gamemode database connects after us; (re)try the imports once it is up
hook.Add("DatabaseConnected", "ChudShared_ImportRetry", function()
    timer.Simple(5, function()
        if not CS.IsConnected() then return end
        if not CS.ImportDone and CS.Role() == 1 then CS.RunImport(1)
        elseif CS.ImportDone and CS.Role() == 2 then CS.RunImport(2) end
    end)
end)

---------------------------------------------------------------------------
-- Console
---------------------------------------------------------------------------
local function ConsoleOnly(ply) return not IsValid(ply) end

concommand.Add("chud_shared_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local function out(s) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, s) else print(s) end end
    local pendingExp, pendingCoin = table.Count(P.exp), table.Count(P.coin)
    out(string.format("[ChudShared] server %d | %s | import %s | queued: exp %d, coin %d, ach %d, other %d, ulx %d",
        CS.Role(), CS.IsConnected() and "CONNECTED" or "NOT CONNECTED", CS.ImportDone and "done" or "waiting",
        pendingExp, pendingCoin, table.Count(P.ach), #P.stmts, #P.ulx))
end)

concommand.Add("chud_shared_flush", function(ply)
    if not ConsoleOnly(ply) then return end
    CS.Flush(function(ok) print("[ChudShared] flush " .. (ok and "ok" or "not done (not connected / nothing to do)")) end)
end)

concommand.Add("chud_shared_import", function(ply, _, args)
    if not ConsoleOnly(ply) then return end
    if args[1] ~= "confirm" then
        print("[ChudShared] Run on SERVER 1 only:  chud_shared_import confirm   (re-copies server 1's data, highest values win)")
        return
    end
    if CS.Role() ~= 1 then
        print("[ChudShared] This server is not server 1. Use chud_shared_import_server2 confirm here instead.")
        return
    end
    CS.RunImport(1, true)
end)

concommand.Add("chud_shared_import_server2", function(ply, _, args)
    if not ConsoleOnly(ply) then return end
    if args[1] ~= "confirm" then print("[ChudShared] chud_shared_import_server2 confirm  (merge this server's data, safe to re-run)") return end
    CS.RunImport(2, true)
end)
