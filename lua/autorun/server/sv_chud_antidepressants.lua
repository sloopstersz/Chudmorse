ChudAntidepressants = ChudAntidepressants or {}
local A = ChudAntidepressants
-- Gameplay balance: duration in seconds, depression on the organism's 0..1 scale.
A.Duration = 60
A.RecoveryPerSecond = 0.01
A.DoseWindow = 120
A.OverdoseDoses = 3
A.OverdoseDuration = 30
A.States = A.States or {}
local states = A.States
function A.Take(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ply.organism then return false end
    local now, org = CurTime(), ply.organism
    local state = states[ply]
    if not state or state.org ~= org then
        state = {org = org, doses = {}, last = now}
        states[ply] = state
    end
    for i = #state.doses, 1, -1 do
        if now - state.doses[i] >= A.DoseWindow then table.remove(state.doses, i) end
    end
    state.doses[#state.doses + 1] = now
    -- Extra doses refresh duration, not recovery strength.
    state.reliefEnd = now + A.Duration
    if #state.doses >= A.OverdoseDoses then
        state.overdoseEnd = now + A.OverdoseDuration
        state.damageRate = math.min(2 * (#state.doses - A.OverdoseDoses + 1), 10)
        if ply.Notify then ply:Notify("I took too many pills...", 6, "antidepressant_overdose", 0) end
    end
    return true
end
function A.Update(ply, state, now)
    if not IsValid(ply) or not ply:Alive() or ply.organism ~= state.org then states[ply] = nil return end
    local previous = state.last
    state.last = now
    local relief = math.max(0, math.min(now, state.reliefEnd or 0) - previous)
    local org = state.org
    if relief > 0 then
        org.depression = math.max(0, (org.depression or 0) - A.RecoveryPerSecond * relief)
        org.depressionBlood = math.max(0, (org.depressionBlood or 0) - A.RecoveryPerSecond * relief)
    end
    local overdose = math.max(0, math.min(now, state.overdoseEnd or 0) - previous)
    if overdose > 0 then
        local damage = DamageInfo()
        damage:SetDamage(overdose * state.damageRate)
        damage:SetDamageType(DMG_POISON)
        damage:SetAttacker(ply)
        damage:SetInflictor(ply)
        ply:TakeDamageInfo(damage)
    end
    local lastDose = state.doses[#state.doses] or 0
    if now >= lastDose + A.DoseWindow and now >= (state.overdoseEnd or 0) then states[ply] = nil end
end
timer.Create("ChudAntidepressants", 1, 0, function()
    local now = CurTime()
    for ply, state in pairs(states) do A.Update(ply, state, now) end
end)
local function Clear(ply) states[ply] = nil end
hook.Add("PlayerSpawn", "ChudAntidepressants", Clear)
hook.Add("PlayerDeath", "ChudAntidepressants", Clear)
hook.Add("Player_Death", "ChudAntidepressants", Clear)
hook.Add("PlayerDisconnected", "ChudAntidepressants", Clear)
hook.Add("PostCleanupMap", "ChudAntidepressants", function() table.Empty(states) end)
