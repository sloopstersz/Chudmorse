local MODE = MODE

MODE.name = "juggernaut"
MODE.PrintName = "Juggernaut"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.DisableMental = true
MODE.ForBigMaps = false
MODE.randomSpawns = true
MODE.shouldfreeze = false -- Full engine freeze also locks the camera.
MODE.Chance = 0.03
-- Six seconds of intro, followed by the client's two-second screen/music fade.
MODE.start_time = 8
MODE.end_time = 7
MODE.ROUND_TIME = 300
MODE.JuggernautModel = "models/arty/codmw2022/mp/dmz/alqatala/juggernaut/juggernaut_pm.mdl"

function MODE:HG_MovementCalc_2(mul, ply, cmd, mv)
    if zb.ROUND_STATE ~= 0 then return end
    if cmd then
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end
    if mv then
        mv:RemoveKey(IN_ATTACK)
        mv:RemoveKey(IN_ATTACK2)
    end
end

function MODE:PlayerCanLegAttack()
    if zb.ROUND_STATE == 0 then return false end
end

-- Keep preparation stationary while leaving mouse/view angles untouched.
local function HoldForPreparation(ply)
    return zb.ROUND_STATE == 0 and IsValid(ply) and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR
end
function MODE:StartCommand(ply, cmd)
    if not HoldForPreparation(ply) then return end
    cmd:ClearMovement()
    for _, key in ipairs({IN_ATTACK, IN_ATTACK2, IN_USE, IN_JUMP, IN_DUCK}) do cmd:RemoveKey(key) end
end
function MODE:Move(ply, mv)
    if not HoldForPreparation(ply) then return end
    mv:SetVelocity(vector_origin)
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)
    -- Skip positional movement for this tick; view angles remain player-controlled.
    return true
end
