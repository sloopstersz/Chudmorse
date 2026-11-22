-- 250 COIN the first time a player completes any achievement.
-- Each achievement pays once per player, ever. Tracked locally (SQLite) AND in the shared
-- database (sv_chud_shared_db.lua), so unlocking on the other server never pays twice either.
local REWARD = 250
local ready = sql.Query([[CREATE TABLE IF NOT EXISTS chud_achievement_coin (
    steamid TEXT NOT NULL, achievement TEXT NOT NULL, PRIMARY KEY (steamid, achievement))]]) ~= false

local function Pay(ply, sid, k, key, ach)
    if sql.Query("INSERT OR IGNORE INTO chud_achievement_coin (steamid, achievement) VALUES (" .. sid .. ", " .. k .. ")") == false then return end
    if ChudCoin.Add(ply, REWARD) then
        ply:ChatPrint("+" .. REWARD .. " COIN for unlocking \"" .. tostring(ach and ach.name or key) .. "\"")
    else
        sql.Query("DELETE FROM chud_achievement_coin WHERE steamid = " .. sid .. " AND achievement = " .. k)
    end
end

hook.Add("HG_AchievementCompleted", "ChudAchievementCoin", function(ply, key, ach)
    if not ready or not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return end
    if not (ChudCoin and ChudCoin.Add) then return end
    local steamid = ply:SteamID64()
    local sid, k = sql.SQLStr(steamid), sql.SQLStr(key)
    if sql.QueryValue("SELECT 1 FROM chud_achievement_coin WHERE steamid = " .. sid .. " AND achievement = " .. k) then
        if ChudShared then ChudShared.MarkAchCoin(steamid, key) end
        return
    end

    if not ChudShared then Pay(ply, sid, k, key, ach) return end

    ChudShared.ClaimAchCoin(steamid, key, function(granted)
        if not IsValid(ply) then return end
        if granted == true then
            Pay(ply, sid, k, key, ach)
        elseif granted == nil then
            -- shared DB unreachable: pay from the local ledger and record it for the other server
            Pay(ply, sid, k, key, ach)
            ChudShared.MarkAchCoin(steamid, key)
        else
            -- already paid on the other server: remember locally too
            sql.Query("INSERT OR IGNORE INTO chud_achievement_coin (steamid, achievement) VALUES (" .. sid .. ", " .. k .. ")")
        end
    end)
end)
