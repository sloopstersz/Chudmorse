AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local FLIGHT_DURATION = 4

function ENT:PlayFlight(sequence)
    local id, duration = self:LookupSequence(sequence)
    if not id or id < 0 then return nil end
    self:ResetSequence(id)
    self:SetCycle(0)
    self:SetPlaybackRate(1)
    return math.max(duration or 0, 1)
end

function ENT:Initialize()
    self.Data = ZZExfil.Types[self.TypeID]
    if not self.Data then self:Remove() return end
    self:SetModel("models/exfil_coldwar/" .. self.Data.model .. ".mdl")
    for _, group in ipairs(self.Data.groups or {}) do self:SetBodygroup(group, 1) end
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetUseType(SIMPLE_USE)
    self.Boarded = {}
    self.RotorSound = CreateSound(self, self.Data.sound or "lfs_custom/uh60_heli.wav")
    if self.RotorSound then self.RotorSound:SetSoundLevel(100) self.RotorSound:PlayEx(0.8, 100) end
    self.State = "landing"
    self:SetNWString("State", self.State)
    self:SetNWInt("Capacity", self.Data.seats)
    self:SetNWVector("LandingPoint", self.LandingPoint)
    SetGlobalEntity("ZZ_ExfilHelicopter", self)
    self.HoverPos = self.LandingPoint + Vector(0, 0, self.Data.height + 48)
    self.FlightStart = CurTime()
    self.FlightFrom = self.HoverPos - self:GetForward() * 3000 + Vector(0, 0, 900)
    self.FlightTo = self.HoverPos
    self.NextState = CurTime() + FLIGHT_DURATION
    self:SetPos(self.FlightFrom)
    self:PlayFlight("landed")

end

function ENT:BeginBoarding()
    self:SetPos(self.HoverPos)
    self:PlayFlight("landed")
    self.State = "boarding"
    self:SetNWString("State", self.State)
end

local function RemoveBoardingBody(ply)
    if not IsValid(ply) then return end
    local bodies = {ply:GetNWEntity("RagdollDeath"), ply:GetNWEntity("FakeRagdoll")}
    if IsValid(ply.RagdollDeath) then bodies[#bodies + 1] = ply.RagdollDeath end
    if IsValid(ply.FakeRagdoll) then bodies[#bodies + 1] = ply.FakeRagdoll end
    for _, body in pairs(bodies) do
        if IsValid(body) and not body:IsPlayer() then
            body.hg_no_fullbody_remove_gib = true
            body.override = true
            body:SetNWEntity("ply", NULL)
            body:Remove()
        end
    end
    ply.RagdollDeath, ply.FakeRagdoll = nil, nil
    ply:SetNWEntity("RagdollDeath", NULL)
    ply:SetNWEntity("FakeRagdoll", NULL)
    if hg and hg.ragdollFake then hg.ragdollFake[ply] = nil end
end

function ENT:Use(ply)
    if self.State ~= "boarding" or not ZZExfil.IsSurvivor(ply) or ply:InVehicle() or IsValid(ply.FakeRagdoll) then return end
    -- Board from the pickup area, not the hidden animated seat positions.
    local point = self.LandingPoint
    local delta = ply:GetPos() - point
    if delta:Length2DSqr() > 240 * 240 or math.abs(delta.z) > 160 then return end
    local tr = util.TraceLine({start = ply:EyePos(), endpos = point + Vector(0, 0, 48),
        mask = MASK_SOLID_BRUSHONLY, filter = {ply, self}})
    if tr.Hit then return end
    if self.Boarded[ply] or #self:Passengers() >= self.Data.seats then return end
    self.Boarded[ply] = true
    ply.ZZExfilPreviousTeam = ply:Team()
    ply.ZZExfilBoarded = self
    ply:SetNWBool("ZZExfilBoarded", true)
    -- Leave active play without the normal corpse-removal gib effect.
    ply:SetNWBool("ZZExfilSurvivor", true)
    ply.ZZGuardReserved = nil
    ply.ZZZombieChoicePending = nil
    ply:SetNWBool("ZZZombieCanChoose", false)
    ply:SetNWString("ZZZombieSelectedClass", "")
    if ZZInfection and ZZInfection.Clear then ZZInfection.Clear(ply) end
    ply:Freeze(false)
    ply.chosenSpectEntity, ply.lastSpectTarget = nil, nil
    ply.viewmode = 3
    ply:SetNWEntity("spect", NULL)
    ply:SetNWInt("viewmode", 3)
    ply:SetTeam(TEAM_SPECTATOR)
    ply:StripWeapons()
    -- Silent death enables the normal dead-player spectator controls.
    -- Reserve during death callbacks so the zombie class picker cannot open.
    ply.ZZGuardReserved = true
    local deaths = ply:Deaths()
    ply:KillSilent()
    ply:SetDeaths(deaths)
    ply.ZZGuardReserved = nil
    RemoveBoardingBody(ply)
    timer.Simple(0, function()
        if IsValid(ply) and not ply:Alive() and ply:GetNWBool("ZZExfilBoarded", false) then
            RemoveBoardingBody(ply)
        end
    end)
    ply:SpectateEntity(NULL)
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SetMoveType(MOVETYPE_NOCLIP)
    ply:SetNoDraw(true)
    ply:SetNotSolid(true)
    ply:SetNWEntity("ZZExfilHeli", self)
    zb.GiveRole(ply, "Survivor", Color(90, 200, 110))
    self:SetNWInt("Passengers", #self:Passengers())
end

function ENT:Passengers()
    local passengers = {}
    for ply in pairs(self.Boarded or {}) do
        if IsValid(ply) and ply.ZZExfilBoarded == self then passengers[#passengers + 1] = ply end
    end
    return passengers
end

function ENT:Depart()
    if self.State ~= "boarding" then return end
    self.State = "departing"
    self:SetNWString("State", self.State)
    self:SetSolid(SOLID_NONE)
    self:PlayFlight("landed")
    self.FlightStart = CurTime()
    self.FlightFrom = self:GetPos()
    self.FlightTo = self.FlightFrom + self:GetForward() * 5000 + Vector(0, 0, 1800)
    self.NextState = CurTime() + FLIGHT_DURATION
end

function ENT:Think()
    local mode = CurrentRound and CurrentRound()
    if mode ~= self.ExfilMode or not mode or mode.name ~= "zzombies" or zb.ROUND_STATE ~= 1 then self:Remove() return end
    if self.State == "landing" or self.State == "departing" then
        local progress = math.Clamp((CurTime() - self.FlightStart) / FLIGHT_DURATION, 0, 1)
        progress = progress * progress * (3 - 2 * progress)
        self:SetPos(LerpVector(progress, self.FlightFrom, self.FlightTo))
    end
    if self.State == "landing" and CurTime() >= self.NextState then self:BeginBoarding() end
    local passengers = self:Passengers()
    self:SetNWInt("Passengers", #passengers)
    if self.State == "boarding" then
        local remaining = 0
        for _, ply in player.Iterator() do if ZZExfil.IsSurvivor(ply) then remaining = remaining + 1 end end
        local deadline = GetGlobalFloat("ZZ_ExtractDeadline", 0)
        if (#passengers > 0 and (#passengers >= self.Data.seats or remaining == 0))
            or (deadline > 0 and CurTime() >= deadline - FLIGHT_DURATION) then self:Depart() end
    elseif self.State == "departing" and CurTime() >= self.NextState then
        self.Releasing = true
        for _, ply in ipairs(passengers) do
            if not ply.ZZ_Extracted then
                ply.ZZ_Extracted = true
                mode.Extracted = (mode.Extracted or 0) + 1
            end
        end
        self:Remove()
        -- Use the normal Z-Zombies outcome, never the addon's cinematic.
        if zb.ROUND_STATE == 1 and CurrentRound() == mode then
            mode.OperationFailed = (mode.Extracted or 0) == 0
            zb:EndRound()
        end
        return
    end
    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    if self.RotorSound then self.RotorSound:Stop() end
    for _, ply in ipairs(self:Passengers()) do
        ply.ZZExfilBoarded = nil
        ply:SetNWEntity("ZZExfilHeli", NULL)
        -- Remain a hidden spectator until the next spawn; do not create a corpse.
    end
end
