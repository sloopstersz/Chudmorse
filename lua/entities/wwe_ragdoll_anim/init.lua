AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local SHADOW = {
    secondstoarrive  = 0.01,
    maxangular       = 400,
    maxangulardamp   = 200,
    maxspeed         = 100,
    maxspeeddamp     = 45,
    teleportdistance = 0,
}

-- Дистанция в юнитах которая считается землёй
local FALL_DROP  = 24

local FALL_GRACE = 0.15

function ENT:Initialize()
    self:SetModel("models/error.mdl")
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self.Delta    = CurTime()
    self.CycleEnd = 1
end

function ENT:Setup(rag, model, seq, opts)
    opts = opts or {}
    if not IsValid(rag) then self:Remove() return end

    self.Ragdoll  = rag
    self.CycleEnd = opts.cycleEnd or 1
    self.FinishFunc = opts.onFinish

    if model then self:SetModel(model) end
    self:SetPos(opts.pos or rag:GetPos())
    self:SetAngles(opts.angles or rag:GetAngles())
    self.GroundZ = self:GetPos().z   -- начальная высота

    self:ResetSequence(self:LookupSequence(seq))
    self:SetCycle(0)
    self:SetPlaybackRate(opts.rate or 1)

    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local phys = rag:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    end
end

function ENT:DriveRagdoll(rag, dt)
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local phys = rag:GetPhysicsObjectNum(i)
        if not IsValid(phys) then continue end

        local bone = self:LookupBone(rag:GetBoneName(rag:TranslatePhysBoneToBone(i)))
        if not bone then continue end

        local pos, ang = self:GetBonePosition(bone)
        if not pos then continue end

        local tr = util.TraceLine({
            start  = phys:GetPos(),
            endpos = pos,
            filter = { self, rag },
            mask   = MASK_SOLID,
        })
        if tr.Hit then continue end

        phys:Wake()
        phys:ComputeShadowControl({
            secondstoarrive  = SHADOW.secondstoarrive,
            pos              = pos,
            angle            = ang,
            maxangular       = SHADOW.maxangular,
            maxangulardamp   = SHADOW.maxangulardamp,
            maxspeed         = SHADOW.maxspeed,
            maxspeeddamp     = SHADOW.maxspeeddamp,
            teleportdistance = SHADOW.teleportdistance,
            deltatime        = dt,
        })
    end
end

function ENT:OverVoid()
    local bone = self:LookupBone("ValveBiped.Bip01_Pelvis") or 0
    local bp   = self:GetBonePosition(bone)
    if not bp then return false end

    local tr = util.TraceLine({
        start  = Vector(bp.x, bp.y, self.GroundZ + 24),
        endpos = Vector(bp.x, bp.y, self.GroundZ - FALL_DROP),
        mask   = MASK_SOLID,
        filter = function(e)
            return not e:IsPlayer() and e:GetClass() ~= "prop_ragdoll"
        end,
    })
    return not tr.Hit
end

function ENT:Think()
    local rag = self.Ragdoll
    if not IsValid(rag) then self:Remove() return end

    if self:OverVoid() then
        self.VoidSince = self.VoidSince or CurTime()
        if CurTime() - self.VoidSince > FALL_GRACE then self:Remove() return end
    else
        self.VoidSince = nil
    end

    local dt = CurTime() - self.Delta
    self:DriveRagdoll(rag, dt)

    if self:GetCycle() >= self.CycleEnd then
        if isfunction(self.FinishFunc) then self.FinishFunc(self, rag) end
        self:Remove()
        return
    end

    self.Delta = CurTime()
    self:NextThink(CurTime())
    return true
end
