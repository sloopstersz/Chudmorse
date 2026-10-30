if SERVER then AddCSLuaFile() end

local COST, RANGE, DURATION, COOLDOWN = 20, 1500, 5, 10
local function CanSniff(ply)
    return IsValid(ply) and ply:Alive() and ZZIsZombie and ZZIsZombie(ply)
        and ZZInfection and ZZInfection.Active() and not ply.ZZ_Extracted
        and not IsValid(ply.FakeRagdoll) and not ply:InVehicle()
        and not ply:GetNetVar("handcuffed", false)
        and not (ply.organism and (ply.organism.otrub or ply.organism.incapacitated))
end

if SERVER then
    util.AddNetworkString("ZZSniff")
    util.AddNetworkString("ZZSniffResult")
    net.Receive("ZZSniff", function(_, ply)
        if not CanSniff(ply) or (ply.ZZSniffReady or 0) > CurTime() then return end
        local points = ply:GetNWInt("ZZZombiePoints", 0)
        if points < COST then
            -- Rate limit feedback without spending points or starting the ability cooldown.
            if (ply.ZZSniffFeedback or 0) <= CurTime() then
                ply.ZZSniffFeedback = CurTime() + 1
                ply:ChatPrint("Sniff requires 20 zombie points.")
            end
            return
        end
        local locations = {}
        for _, target in player.Iterator() do
            if target ~= ply and target:Alive() and target:Team() ~= TEAM_SPECTATOR
                and not ZZIsZombie(target) and not target.ZZ_Extracted then
                local body = IsValid(target.FakeRagdoll) and target.FakeRagdoll or target
                local pos = body:WorldSpaceCenter()
                if ply:GetPos():DistToSqr(pos) <= RANGE * RANGE then
                    locations[#locations + 1] = pos
                end
            end
        end
        ply:SetNWInt("ZZZombiePoints", points - COST)
        ply.ZZSniffReady = CurTime() + COOLDOWN
        ply:SetNWFloat("ZZSniffReady", ply.ZZSniffReady)
        -- Positions are sent only to this zombie; no client PVS dependency or target tracking.
        net.Start("ZZSniffResult")
        net.WriteUInt(#locations, 16)
        for _, pos in ipairs(locations) do net.WriteVector(pos) end
        net.Send(ply)
    end)
    local function Reset(ply)
        ply.ZZSniffReady, ply.ZZSniffFeedback = nil, nil
        ply:SetNWFloat("ZZSniffReady", 0)
    end
    hook.Add("PlayerSpawn", "ZZSniffReset", Reset)
    hook.Add("PlayerDeath", "ZZSniffReset", Reset)
    hook.Add("PostCleanupMap", "ZZSniffReset", function()
        for _, ply in player.Iterator() do Reset(ply) end
    end)
else
    local locations, revealUntil = {}, 0
    hook.Add("radialOptions", "ZZZombieSniff", function()
        local ply = LocalPlayer()
        if not CanSniff(ply) then return end
        local remaining = math.max(0, math.ceil(ply:GetNWFloat("ZZSniffReady", 0) - CurTime()))
        local label = "Sniff - 20 points" .. (remaining > 0 and (" (" .. remaining .. "s)") or "")
        hg.radialOptions[#hg.radialOptions + 1] = {function()
            if CanSniff(ply) and ply:GetNWFloat("ZZSniffReady", 0) <= CurTime() then
                net.Start("ZZSniff") net.SendToServer()
            end
        end, label}
    end)
    net.Receive("ZZSniffResult", function()
        locations = {}
        local count = net.ReadUInt(16)
        for i = 1, count do locations[i] = net.ReadVector() end
        if not CanSniff(LocalPlayer()) then locations = {} return end
        revealUntil = CurTime() + DURATION
        surface.PlaySound("npc/zombie/zombie_alert1.wav")
    end)
    hook.Add("Think", "ZZSniffClear", function()
        if CurTime() >= revealUntil or not CanSniff(LocalPlayer()) then
            locations, revealUntil = {}, 0
        end
    end)
    hook.Add("HUDPaint", "ZZSniffLocations", function()
        if CurTime() >= revealUntil or not CanSniff(LocalPlayer()) then return end
        local alpha = math.floor(math.Clamp(revealUntil - CurTime(), 0, 1) * 230)
        local color = Color(210, 45, 35, alpha)
        draw.SimpleText(#locations == 0 and "NO SURVIVOR SCENT NEARBY" or "SURVIVOR SCENT", "DermaDefaultBold",
            ScrW() / 2, ScrH() * 0.68, color, TEXT_ALIGN_CENTER)
        for _, pos in ipairs(locations) do
            local screen = pos:ToScreen()
            if screen.visible then
                local x, y = screen.x, screen.y
                surface.SetDrawColor(color)
                surface.DrawOutlinedRect(x - 7, y - 7, 14, 14, 2)
                draw.SimpleText("SCENT", "DermaDefaultBold", x, y + 12, color, TEXT_ALIGN_CENTER)
            end
        end
    end)
end
