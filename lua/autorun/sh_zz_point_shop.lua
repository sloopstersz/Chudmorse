if SERVER then AddCSLuaFile() end
local function Zombie(ply)
    return IsValid(ply) and ZZIsZombie and ZZIsZombie(ply)
end
if SERVER then
    util.AddNetworkString("ZZZombiePurchase")
    util.AddNetworkString("ZZZombieSpit")
    net.Receive("ZZZombiePurchase", function(_, ply)
        local choice = net.ReadUInt(2)
        if not IsValid(ply) or ply:Alive() or not ZZZombieRespawnActive() or not ply.ZZZombieChoicePending
            or ply.ZZ_Extracted or ply.ZZGuardReserved then return end
        local class = ply:GetNWString("ZZZombieSelectedClass", "")
        if not ZZZombieClasses[class] then return end
        local costs = {50, 75, 100}
        local flags = {[2] = "ZZIntelligence", [3] = "ZZInfectionSpit"}
        local cost, flag = costs[choice], flags[choice]
        if not cost or (flag and ply:GetNWBool(flag, false)) then return end
        local points = ply:GetNWInt("ZZZombiePoints", 0)
        if points < cost then return end
        if choice == 1 then
            if ply:GetNWFloat("ZZZombieRespawnAt", 0) <= CurTime() then return end
            if class == "heavy" and not ZZHeavySlotAvailable(ply) then return end
            local deadline = ply:GetNWFloat("ZZZombieRespawnAt", 0)
            ply:SetNWFloat("ZZZombieRespawnAt", 0)
            if not ZZRespawnSelected(ply) then
                ply:SetNWFloat("ZZZombieRespawnAt", deadline)
                return
            end
        else
            ply:SetNWBool(flag, true)
        end
        ply:SetNWInt("ZZZombiePoints", points - cost)
    end)
    net.Receive("ZZZombieSpit", function(_, ply)
        if not Zombie(ply) or not ply:Alive() or not ZZInfection.Active() or not ply:GetNWBool("ZZInfectionSpit", false)
            or IsValid(ply.FakeRagdoll) or ply:InVehicle() or ply:GetNetVar("handcuffed", false)
            or (ply.ZZSpitReady or 0) > CurTime() then return end
        local shot = ents.Create("zz_infection_spit")
        if not IsValid(shot) then return end
        shot:SetOwner(ply)
        shot:SetPos(ply:GetShootPos())
        shot.FlightVelocity = ply:GetAimVector() * 900
        shot:Spawn()
        ply.ZZSpitReady = CurTime() + 10
        ply:SetNWFloat("ZZSpitReady", ply.ZZSpitReady)
        ply:EmitSound("npc/barnacle/barnacle_gulp1.wav", 65, 120)
    end)
    hook.Add("PlayerDeath", "ZZShopReset", function(ply)
        ply.ZZSpitReady = nil
        ply:SetNWFloat("ZZSpitReady", 0)
        ply:SetNWBool("ZZIntelligence", false)
        ply:SetNWBool("ZZInfectionSpit", false)
    end)
else
    local held = {}
    local spitHeld = false
    hook.Add("Think", "ZZZombiePointShop", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local enabled = not vgui.CursorVisible() and not gui.IsConsoleVisible() and not gui.IsGameUIVisible()
        local shopping = enabled and not ply:Alive() and ZZZombieRespawnActive()
            and ply:GetNWBool("ZZZombieCanChoose", false) and ZZZombieClasses[ply:GetNWString("ZZZombieSelectedClass", "")]
        for i, key in ipairs({KEY_1, KEY_2, KEY_3}) do
            local down = input.IsKeyDown(key)
            if shopping and down and not held[i] then
                net.Start("ZZZombiePurchase") net.WriteUInt(i, 2) net.SendToServer()
            end
            held[i] = down
        end
        local down = input.IsKeyDown(KEY_R) and input.IsMouseDown(MOUSE_RIGHT)
        if enabled and down and not spitHeld and Zombie(ply) and ply:Alive() and ply:GetNWBool("ZZInfectionSpit", false) then
            net.Start("ZZZombieSpit") net.SendToServer()
        end
        spitHeld = down
    end)
    hook.Add("HUDPaint", "ZZSpitHint", function()
        local ply = LocalPlayer()
        if not Zombie(ply) or not ply:Alive() or not ply:GetNWBool("ZZInfectionSpit", false) then return end
        local wait = math.max(0, math.ceil(ply:GetNWFloat("ZZSpitReady", 0) - CurTime()))
        draw.SimpleText(wait > 0 and ("INFECTION SPIT: " .. wait .. "s") or "R + RMB: INFECTION SPIT",
            "DermaDefaultBold", 24, ScrH() * 0.72 + 72, Color(170, 220, 110))
    end)
end

local ENT = {Type = "anim", Base = "base_anim", PrintName = "Infection Spit", Spawnable = false}
if SERVER then
    function ENT:Initialize()
        self:SetModel("models/Items/AR2_Grenade.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self.FlightVelocity = self.FlightVelocity or Vector(0, 0, 0)
        self.Expires = CurTime() + 3
        self.LastStep = CurTime()
    end
    function ENT:Think()
        if not ZZInfection.Active() or CurTime() >= self.Expires then self:Remove() return end
        local dt = math.min(CurTime() - self.LastStep, 0.1)
        self.LastStep = CurTime()
        local pos = self:GetPos()
        local tr = util.TraceHull({start = pos, endpos = pos + self.FlightVelocity * dt,
            mins = Vector(-3, -3, -3), maxs = Vector(3, 3, 3), filter = {self, self:GetOwner()}, mask = MASK_SHOT})
        if tr.Hit then
            local target = ZZInfection.Human(tr.Entity)
            if IsValid(target) and target:Alive() and not Zombie(target) then ZZInfection.Infect(target) end
            local effect = EffectData()
            effect:SetOrigin(tr.HitPos)
            effect:SetNormal(tr.HitNormal)
            effect:SetColor(1)
            util.Effect("BloodImpact", effect, true, true)
            self:Remove()
            return
        end
        self:SetPos(tr.HitPos)
        self.FlightVelocity = self.FlightVelocity - Vector(0, 0, 100) * dt
        self:NextThink(CurTime())
        return true
    end
else
    local mat = CreateMaterial("zz_spit_sprite", "UnlitGeneric", { ["$basetexture"] = "sprites/glow04", ["$additive"] = "1", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$ignorez"] = "0" })
    function ENT:Draw()
        render.SetMaterial(mat)
        render.DrawSprite(self:GetPos(), 10, 10, Color(120, 200, 45, 230))
    end
end
scripted_ents.Register(ENT, "zz_infection_spit")
