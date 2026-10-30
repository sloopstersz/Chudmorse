if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("homigrad/organism/cl_eyegore.lua")
    util.AddNetworkString("ChudZoomEyes")
    net.Receive("ChudZoomEyes", function(length, ply)
        if length < 1 or not IsValid(ply) then return end
        local active = net.ReadBool() and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR
        ply.ChudZoomEyesExpires = active and CurTime() + 2 or nil
        ply:SetNWBool("ChudZoomEyes", active)
    end)
    local function Clear(ply)
        ply.ChudZoomEyesExpires = nil
        ply:SetNWBool("ChudZoomEyes", false)
    end
    hook.Add("PlayerDeath", "ChudZoomEyesReset", Clear)
    hook.Add("PlayerSpawn", "ChudZoomEyesReset", Clear)
    timer.Create("ChudZoomEyesRecovery", 0.25, 0, function()
        for _, ply in player.Iterator() do
            if ply:GetNWBool("ChudZoomEyes", false) and (not ply:Alive()
                or ply:Team() == TEAM_SPECTATOR or (ply.ChudZoomEyesExpires or 0) <= CurTime()) then Clear(ply) end
        end
    end)
    return
end

-- Also loads when a dedicated server did not run the recursive client loader.
hook.Add("InitPostEntity", "ChudZoomEyesClientLoader", function()
    local drawHooks = hook.GetTable().PostDrawOpaqueRenderables or {}
    if not drawHooks.hg_eye_gore_draw then include("homigrad/organism/cl_eyegore.lua") end
end)

local lastSent, nextSend = nil, 0
hook.Add("Think", "ChudZoomEyesState", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or util.NetworkStringToID("ChudZoomEyes") == 0 then return end
    local active = zooming == true and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR
    if active == lastSent and RealTime() < nextSend then return end
    lastSent, nextSend = active, RealTime() + 0.5
    net.Start("ChudZoomEyes")
    net.WriteBool(active)
    net.SendToServer()
end)
