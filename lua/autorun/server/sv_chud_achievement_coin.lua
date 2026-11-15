-- 250 COIN the first time a player completes any achievement.
-- Each achievement pays once per player, ever (tracked in SQLite), so re-syncing
-- saved progress or re-granting an achievement never pays twice.
local REWARD = 250
local ready = sql.Query([[CREATE TABLE IF NOT EXISTS chud_achievement_coin (
    steamid TEXT NOT NULL, achievement TEXT NOT NULL, PRIMARY KEY (steamid, achievement))]]) ~= false

hook.Add("HG_AchievementCompleted", "ChudAchievementCoin", function(ply, key, ach)
    if not ready or not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() then return end
    if not (ChudCoin and ChudCoin.Add) then return end
    local sid, k = sql.SQLStr(ply:SteamID64()), sql.SQLStr(key)
    if sql.QueryValue("SELECT 1 FROM chud_achievement_coin WHERE steamid = " .. sid .. " AND achievement = " .. k) then return end
    if sql.Query("INSERT INTO chud_achievement_coin (steamid, achievement) VALUES (" .. sid .. ", " .. k .. ")") == false then return end
    if ChudCoin.Add(ply, REWARD) then
        ply:ChatPrint("+" .. REWARD .. " COIN for unlocking \"" .. tostring(ach and ach.name or key) .. "\"")
    else
        sql.Query("DELETE FROM chud_achievement_coin WHERE steamid = " .. sid .. " AND achievement = " .. k)
    end
end)
