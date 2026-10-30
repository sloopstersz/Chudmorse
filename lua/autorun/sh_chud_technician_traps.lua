if SERVER then AddCSLuaFile() end
ChudTechnicianTraps = ChudTechnicianTraps or {}
local F = ChudTechnicianTraps
F.TrapClass = "ttt_traitor_button"
F.TrapRange = 4096
F.AimDot = math.cos(math.rad(8))
function F.CanAct(ply)
    local mode = CurrentRound and CurrentRound()
    if not mode or (mode.name ~= "hmcd" and mode.name ~= "chaos") then return false end
    if not zb or zb.ROUND_STATE ~= 1 then return false end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or ply:Team() == TEAM_SPECTATOR then return false end
    if not ply.isTraitor or ply.SubRole ~= "traitor_fox" or ply:InVehicle() then return false end
    if IsValid(ply.FakeRagdoll) or IsValid(ply:GetNWEntity("FakeRagdoll")) then return false end
    local org = ply.organism or {}
    return not org.otrub and not org.larmamputated and not org.rarmamputated
end
function F.ValidTrap(ply, trap)
    return IsValid(trap) and trap:GetClass() == F.TrapClass
        and isfunction(trap.IsUsable) and isfunction(trap.GetDelay)
        and ply:GetPos():DistToSqr(trap:GetPos()) <= F.TrapRange * F.TrapRange
end
if SERVER then
    util.AddNetworkString("ChudTechScan")
    util.AddNetworkString("ChudTechActivate")
    local scans = {}
    local function Clear(ply, reset)
        local state = scans[ply]
        scans[ply] = nil
        if not IsValid(ply) then return end
        if state and not reset then ply:SetNWFloat("ChudTechCooldown", math.min(CurTime(), state.ends) + 60) end
        if reset then ply:SetNWFloat("ChudTechCooldown", 0) end
        ply:SetNWFloat("ChudTechReady", 0)
        ply:SetNWFloat("ChudTechEnd", 0)
    end
    net.Receive("ChudTechScan", function(_, ply)
        if not F.CanAct(ply) or scans[ply] or CurTime() < ply:GetNWFloat("ChudTechCooldown", 0) then return end
        local now = CurTime()
        scans[ply] = {ready = now + 2, ends = now + 26}
        ply:SetNWFloat("ChudTechReady", now + 2)
        ply:SetNWFloat("ChudTechEnd", now + 26)
        ply:SetNWFloat("ChudTechCooldown", now + 86)
    end)
    -- Version 3 map-output activation, shared by the UI and legacy console command.
    function F.TryActivateTrap(ply, trap)
        if not F.CanAct(ply) then return false end
        local state, now = scans[ply], CurTime()
        if not state or now < state.ready or now >= state.ends then return false end
        if now < (state.nextTrap or 0) or not F.ValidTrap(ply, trap) or not trap:IsUsable() then return false end
        if ply:GetAimVector():Dot((trap:GetPos() - ply:EyePos()):GetNormalized()) < F.AimDot then return false end
        if hook.Run("TTTCanUseTraitorButton", trap, ply) == false then return false end
        -- Reserve before map outputs; outputs can re-enter or remove the button.
        state.nextTrap = now + 0.25
        local remove = trap.RemoveOnPress or trap:GetDelay() < 0
        if remove then trap:SetLocked(true)
        else trap:SetNextUseTime(now + math.max(0.25, trap:GetDelay())) end
        trap:TriggerOutput("OnPressed", ply)
        if remove and IsValid(trap) then trap:Remove() end
        hook.Run("TTTTraitorButtonActivated", trap, ply)
        return true
    end
    net.Receive("ChudTechActivate", function(_, ply) F.TryActivateTrap(ply, Entity(net.ReadUInt(16))) end)
    hook.Add("Think", "ChudTechScan", function()
        for ply, state in pairs(scans) do
            if not F.CanAct(ply) or CurTime() >= state.ends then Clear(ply) end
        end
    end)
    hook.Add("PlayerDeath", "ChudTechScan", function(ply) Clear(ply) end)
    hook.Add("Fake", "ChudTechScan", function(ply) Clear(ply) end)
    hook.Add("PlayerSpawn", "ChudTechScan", function(ply) Clear(ply, true) end)
    hook.Add("PlayerDisconnected", "ChudTechScan", function(ply) scans[ply] = nil end)
    local function Reset()
        for _, ply in ipairs(player.GetAll()) do Clear(ply, true) end
    end
    hook.Add("ZB_PreRoundStart", "ChudTechScan", Reset)
    hook.Add("ZB_EndRound", "ChudTechScan", Reset)
    return
end
local function Scanning(ply)
    return F.CanAct(ply) and CurTime() >= ply:GetNWFloat("ChudTechReady", 0)
        and CurTime() < ply:GetNWFloat("ChudTechEnd", 0)
end
local function Selected(ply)
    if not Scanning(ply) then return end
    local best, bestDot = nil, F.AimDot
    for _, trap in ipairs(ents.FindByClass(F.TrapClass)) do
        if F.ValidTrap(ply, trap) and trap:IsUsable() then
            local dot = ply:GetAimVector():Dot((trap:GetPos() - ply:EyePos()):GetNormalized())
            if dot > bestDot then best, bestDot = trap, dot end
        end
    end
    return best
end
hook.Add("radialOptions", "ChudTechTraps", function()
    local ply = LocalPlayer()
    if not F.CanAct(ply) then return end
    local active = CurTime() < ply:GetNWFloat("ChudTechEnd", 0)
    local remaining = math.ceil(ply:GetNWFloat("ChudTechCooldown", 0) - CurTime())
    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            if active or remaining > 0 then return end
            net.Start("ChudTechScan") net.SendToServer()
        end,
        active and "Map traps (ACTIVE)" or (remaining > 0 and ("Map traps (" .. remaining .. "s)") or "Scan map traps")
    }
end)
hook.Add("PlayerBindPress", "ChudTechTraps", function(ply, bind, pressed)
    if not pressed or bind ~= "+use" or vgui.CursorVisible() or gui.IsGameUIVisible() then return end
    local trap = Selected(ply)
    if not IsValid(trap) then return end
    net.Start("ChudTechActivate") net.WriteUInt(trap:EntIndex(), 16) net.SendToServer()
    return true
end)
hook.Add("HUDPaint", "ChudTechTraps", function()
    local ply = LocalPlayer()
    if not F.CanAct(ply) or CurTime() >= ply:GetNWFloat("ChudTechEnd", 0) then return end
    if not Scanning(ply) then
        draw.SimpleText("SCANNING TRAPS", "DermaDefaultBold", ScrW() * 0.5, ScrH() * 0.6, color_white, TEXT_ALIGN_CENTER)
        return
    end
    local selected = Selected(ply)
    for _, trap in ipairs(ents.FindByClass(F.TrapClass)) do
        if F.ValidTrap(ply, trap) then
            local screen = trap:GetPos():ToScreen()
            if screen.visible then
                local color = trap == selected and Color(255, 70, 70) or Color(190, 190, 190)
                local size = trap == selected and 12 or 9
                surface.SetDrawColor(color)
                surface.DrawLine(screen.x, screen.y - size, screen.x + size, screen.y)
                surface.DrawLine(screen.x + size, screen.y, screen.x, screen.y + size)
                surface.DrawLine(screen.x, screen.y + size, screen.x - size, screen.y)
                surface.DrawLine(screen.x - size, screen.y, screen.x, screen.y - size)
                local label = trap:IsUsable() and trap:GetDescription() or "TRAP UNAVAILABLE"
                draw.SimpleText(label, "DermaDefaultBold", screen.x, screen.y + size + 4, color, TEXT_ALIGN_CENTER)
            end
        end
    end
    if IsValid(selected) then
        local key = string.upper(input.LookupBinding("+use") or "E")
        draw.SimpleText("[" .. key .. "] ACTIVATE TRAP", "DermaDefaultBold", ScrW() * 0.5, ScrH() * 0.6, Color(255, 80, 80), TEXT_ALIGN_CENTER)
    end
end)
