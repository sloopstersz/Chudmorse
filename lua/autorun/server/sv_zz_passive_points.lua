-- Passive income uses the same round-scoped bank as consumption and future abilities.
local nextPoint = {}
local interval = 2

hook.Add("Think", "ZZZombiePassivePoints", function()
    local mode = CurrentRound and CurrentRound()
    if not mode or mode.name ~= "zzombies" or not zb or zb.ROUND_STATE ~= 1 then
        nextPoint = {}
        return
    end

    local now = CurTime()
    for _, ply in player.Iterator() do
        if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR and ZZIsZombie and ZZIsZombie(ply)
            and not ply.ZZ_Extracted and not ply.ZZExfilBoarded then
            if not nextPoint[ply] then
                nextPoint[ply] = now + interval
            elseif now >= nextPoint[ply] then
                ply:SetNWInt("ZZZombiePoints", ply:GetNWInt("ZZZombiePoints", 0) + 1)
                nextPoint[ply] = now + interval
            end
        else
            nextPoint[ply] = nil
        end
    end
end)

local function ResetPlayer(ply) nextPoint[ply] = nil end
hook.Add("PlayerDeath", "ZZZombiePassivePoints", ResetPlayer)
hook.Add("PlayerSpawn", "ZZZombiePassivePoints", ResetPlayer)
hook.Add("PlayerDisconnected", "ZZZombiePassivePoints", ResetPlayer)
hook.Add("ZB_EndRound", "ZZZombiePassivePoints", function() nextPoint = {} end)
hook.Add("PostCleanupMap", "ZZZombiePassivePoints", function() nextPoint = {} end)
