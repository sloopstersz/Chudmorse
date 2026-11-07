-- Rewards use the starting roster because Homicide clears roles in EndRound.
ChudCoinRewards = ChudCoinRewards or {}
local round
local function playerEntity(ply)
    return IsValid(ply) and ply:IsPlayer()
end
local function participant(ply)
    return playerEntity(ply) and ply:Team() ~= TEAM_SPECTATOR
end
local function credit(ply, amount)
    return participant(ply) and ChudCoin and ChudCoin.Add and ChudCoin.Add(ply, amount)
end

function ChudCoinRewards.Start()
    local mode = CurrentRound()
    round = {mode=mode, name=mode.name, players={}, traitors={}, count=0, deaths={}, targets={}, finished=false}
    for _, ply in player.Iterator() do
        if participant(ply) and ply:Alive() then
            round.players[ply] = true
            if (mode.name == "hmcd" or mode.name == "chaos") and ply.isTraitor then
                round.traitors[ply] = true
                round.count = round.count + 1
            end
        end
    end
    if mode.name == "framed" then
        round.killer = mode.Killer
        for _, target in ipairs(mode.Targets or {}) do
            if playerEntity(target.ply) then round.targets[target.ply] = true end
        end
    end
end

local function death(victim, attacker)
    if not round or round.finished or CurrentRound() ~= round.mode then return end
    if not zb or (zb.ROUND_STATE ~= 1 and zb.ROUND_STATE ~= 3) then return end
    if not round.players[victim] or round.deaths[victim] then return end
    round.deaths[victim] = true
    -- Organism damage can finish a victim through world damage after the hit.
    -- A self-kill never falls back to somebody who previously hurt the player.
    if not playerEntity(attacker) then
        local hit = victim.RSLastHit
        if hit and CurTime() - (hit.t or 0) <= 20 and playerEntity(hit.att) then attacker = hit.att end
    end
    if not participant(attacker) or attacker == victim then return end
    if round.name == "hmcd" or round.name == "chaos" then
        if round.traitors[victim] and not round.traitors[attacker] and not attacker.isTraitor then
            credit(attacker, 10)
        end
    elseif round.name == "framed" and attacker == round.killer and round.targets[victim] then
        credit(attacker, 5)
    end
end

hook.Add("PlayerDeath", "ChudCoinRewards.Kill", function(victim, inflictor, attacker)
    death(victim, attacker)
end)
gameevent.Listen("entity_killed")
hook.Add("entity_killed", "ChudCoinRewards.KillFallback", function(data)
    death(Entity(data.entindex_killed or -1), Entity(data.entindex_attacker or -1))
end)

-- Called before the round summary is built, so the reward is in COIN GAINED.
function ChudCoinRewards.Finish()
    if not round or round.finished or CurrentRound() ~= round.mode then return end
    round.finished = true
    if round.name == "hmcd" or round.name == "chaos" then
        local reward = ({10,15,20})[math.min(round.count,3)]
        if not reward then return end
        for ply in pairs(round.players) do
            if participant(ply) and ply:Alive() and not round.deaths[ply] and not round.traitors[ply] then
                credit(ply, reward)
            end
        end
    elseif round.name == "superfighters" or round.name == "dm" then
        local alive = zb:CheckAlive(true)
        -- Both modes end with one survivor; a wipe or forced multi-player end is not a win.
        if #alive == 1 then
            local winner = alive[1]
            if round.players[winner] and participant(winner) and winner:Alive() and not round.deaths[winner] then
                credit(winner, round.name == "dm" and 10 or 15)
            end
        end
    elseif round.name == "framed" and round.mode.Result == "escaped" then
        local killer = round.killer
        if participant(killer) and killer:Alive() and not round.deaths[killer] then credit(killer,50) end
    end
end

-- Modes report their actual outcome before cleanup; objective wins must not be
-- guessed from the number of survivors (notably Counter-Strike).
function ChudCoinRewards.TeamWin(mode, winner, useRiotTeams)
    if not round or round.finished or round.teamPaid or round.mode ~= mode then return end
    round.teamPaid = true
    if winner ~= 0 and winner ~= 1 then return end
    for _, ply in player.Iterator() do
        local side = useRiotTeams and (ply.RiotAssignedTeam or ply:Team()) or ply:Team()
        if participant(ply) and ply:Alive() and side == winner then credit(ply,10) end
    end
end
