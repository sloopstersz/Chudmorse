if SERVER then AddCSLuaFile() end
ChudDragonStyle = ChudDragonStyle or {}
ChudDragonStyle.RequiredXP = 15000
function ChudDragonStyle.Unlocked(ply)
    if not IsValid(ply) then return false end
    local xp = SERVER and ply.GetExp and ply:GetExp() or (not SERVER and ply.exp)
    return (tonumber(xp) or 0) >= ChudDragonStyle.RequiredXP
end
function ChudDragonStyle.CanUse(ply)
    local mode = CurrentRound and CurrentRound()
    return IsValid(ply) and mode and (mode.name == "hmcd" or mode.name == "chaos")
        and zb and zb.ROUND_STATE == 1 and ply:Alive() and ply.isTraitor and ply.SubRole == "traitor_martialartist"
end
function ChudDragonStyle.CanUseDragon(ply)
    return ChudDragonStyle.CanUse(ply) and ChudDragonStyle.Unlocked(ply) and ply:GetNWBool("ChudDragonStyle", false)
end
-- Dragon Style replaces the base move set, except for the shared Giant Swing.
ChudDragonStyle.BaseMoves = {
    mw_giantswing = true, mw_dyli_front = true, mw_suplex = true,
    mw_necktrauma = true, mw_cagematch = true, mw_sweetdreams = true
}
ChudDragonStyle.DragonMoves = {
    dragon_beast_piledive = true,
    dragon_brawling = true,
    dragon_disarming = true,
    dragon_rush_barrage = true,
    dragon_rush_crushing = true,
    dragon_rush_wall = true,
    dragon_tigerdrop = true,
}

function ChudDragonStyle.CanUseMove(ply, moveId)
    if not ChudDragonStyle.CanUse(ply) then return false end
    -- Giant Swing is shared by both styles; keep its normal base-move effects.
    if moveId == "mw_giantswing" then return true end
    local moves = ChudDragonStyle.CanUseDragon(ply) and ChudDragonStyle.DragonMoves or ChudDragonStyle.BaseMoves
    return moves[moveId] == true
end
if SERVER then
    hook.Add("PlayerSpawn", "ChudDragonStyleReset", function(ply)
        if OverrideSpawn then return end
        if ply.MAMeleeApplied then ply.MeleeDamageMul = nil ply.MAMeleeApplied = nil end
        ply.MACooldowns = nil
        ply:SetNWBool("ChudDragonStyle", false)
    end)
end

-- Capture the actual held object before the animation puts its owner into fake.
function ChudDragonStyle.GetHeldItem(ply)
    if not IsValid(ply) then return nil end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return nil end
    if IsValid(wep.CarryEnt) then return wep.CarryEnt, wep, true end
    local class = wep:GetClass()
    if wep.NoDrop or class == "weapon_hands_sh" or class == "weapon_hg_coolhands" then return nil end
    return wep, wep, false
end
