-- Server-owned currency. Independent of rank XP, karma and zombie points.
ChudCoin = ChudCoin or {}
local MAX_COINS = 1000000000
local ready = sql.Query("CREATE TABLE IF NOT EXISTS chud_coin (steamid TEXT PRIMARY KEY, balance INTEGER NOT NULL DEFAULT 0)") ~= false
local function validPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply:IsBot()
end

function ChudCoin.Get(ply)
    if not validPlayer(ply) or not ready then return nil end
    if ply.ChudCoinBalance ~= nil then return ply.ChudCoinBalance end
    local rows = sql.Query("SELECT balance FROM chud_coin WHERE steamid = " .. sql.SQLStr(ply:SteamID64()))
    if rows == false then return nil end
    local balance = math.Clamp(math.floor(tonumber(rows and rows[1] and rows[1].balance) or 0), 0, MAX_COINS)
    ply.ChudCoinBalance = balance
    ply:SetNWInt("ChudCoin", balance)
    return balance
end

local function save(ply, balance)
    local result = sql.Query("REPLACE INTO chud_coin (steamid, balance) VALUES (" .. sql.SQLStr(ply:SteamID64()) .. ", " .. balance .. ")")
    if result == false then return false end
    ply.ChudCoinBalance = balance
    ply:SetNWInt("ChudCoin", balance)
    return true
end

local function validAmount(amount)
    return isnumber(amount) and amount == amount and amount > 0 and amount <= MAX_COINS and amount == math.floor(amount)
end

function ChudCoin.Add(ply, amount)
    if not validAmount(amount) then return false end
    local balance = ChudCoin.Get(ply)
    if balance == nil or balance + amount > MAX_COINS then return false end
    if not save(ply, balance + amount) then return false end
    hook.Run("ChudCoinEarned", ply, amount)
    return true
end

function ChudCoin.TrySpend(ply, amount)
    if not validAmount(amount) then return false end
    local balance = ChudCoin.Get(ply)
    if balance == nil or balance < amount then return false end
    return save(ply, balance - amount)
end

hook.Add("PlayerInitialSpawn", "ChudCoin.Load", function(ply)
    ChudCoin.Get(ply)
end)
-- Refresh connected players if this file is reloaded.
for _, ply in ipairs(player.GetAll()) do
    ply.ChudCoinBalance = nil
    ChudCoin.Get(ply)
end

resource.AddFile("materials/chudmorse/shop/coin_source.png")
