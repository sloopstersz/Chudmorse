-- Server-owned input: do not poll KeyPressed in PlayerPostThink.
local function TryMove(ply)
    if not IsValid(ply) or not ChudDragonStyle or not ChudDragonStyle.CanUse(ply) then return end
    if not ply.organism or ply.organism.otrub then return end
    local mode = CurrentRound()
    if not mode or not mode.RunMartialArtistMove or not WWE or not WWE.FindTarget then return end
    if ChudDragonStyle.CanUseMove(ply, "mw_giantswing") and WWE.moves.mw_giantswing then
        if mode.RunMartialArtistMove(ply, "mw_giantswing") then return end
    end
    -- Use the same server trace as execution, rather than selecting a target
    -- at 160 units which the execution trace at 100 units cannot reach.
    local target = WWE.FindTarget(ply)
    if not IsValid(target) or not target:Alive() then return end
    local moves = {}
    if ChudDragonStyle.CanUseDragon(ply) and IsValid(ChudDragonStyle.GetHeldItem(target)) then
        moves = {"dragon_tigerdrop"}
    else
        local delta = ply:GetPos() - target:GetPos()
        delta.z = 0
        local behind = delta:LengthSqr() > 1 and delta:GetNormalized():Dot(Angle(0, target:EyeAngles().yaw, 0):Forward()) <= -0.4
        local direction = behind and "back" or "front"
        for _, move in ipairs(mode.MAMoves or {}) do
            if (move.dir == direction or move.dir == "any") and ChudDragonStyle.CanUseMove(ply, move.id) then
                moves[#moves + 1] = move.id
            end
        end
        for i = #moves, 2, -1 do
            local j = math.random(i)
            moves[i], moves[j] = moves[j], moves[i]
        end
    end
    for _, id in ipairs(moves) do
        if mode.RunMartialArtistMove(ply, id, target) then return end
    end
end

hook.Add("StartCommand", "ChudMartialArtistInput", function(ply, cmd)
    if not IsValid(ply) then return end
    local held = cmd:KeyDown(IN_USE)
    local pressed = held and not ply.ChudMAUseHeld
    ply.ChudMAUseHeld = held
    if not pressed or not cmd:KeyDown(IN_WALK) then return end
    if not ChudDragonStyle or not ChudDragonStyle.CanUse(ply) then return end
    -- Defer entity creation until outside command processing; keep the input
    -- edge captured here. No client networking or listen-server host is needed.
    local organism = ply.organism
    timer.Simple(0, function()
        if IsValid(ply) and ply.organism == organism then TryMove(ply) end
    end)
end)
hook.Add("PlayerSpawn", "ChudMartialArtistInputReset", function(ply)
    ply.ChudMAUseHeld = nil
end)
