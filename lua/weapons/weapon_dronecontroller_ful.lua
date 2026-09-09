AddCSLuaFile()

if CLIENT then
    SWEP.WepSelectIcon = Material("vgui/fpv_drone.png")
end

SWEP.PrintName = "FPV-Drone"
SWEP.Author = "Frigen"
SWEP.Category = "FPV-Drone"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.BounceWeaponIcon = false
SWEP.Base = "weapon_base"
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/tfa_cso/c_bunkerbuster3.mdl"
SWEP.WorldModel = "models/weapons/tfa_cso/w_bunkerbuster.mdl"
SWEP.ViewModelFlip = true
SWEP.ViewModelFOV = 80
SWEP.HoldType = "grenade"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.Instructions = "ЛКМ — бросить и подключиться\nМышь — поворачивать дрон и направление полёта\nW — точно по направлению камеры\nS — точно назад от направления камеры\nA/D — движение влево/вправо\nE — отключиться, дрон останется\nE рядом — подключиться снова\nR — взорвать дрон\nZ — включить/выключить фонарь"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:CanDeployDrone()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return false end
    if self:GetNWBool("FCDroneUsed", false) then return false end
    if IsValid(owner.OwnedDrone) then return false end
    if IsValid(owner:GetNWEntity("kamikaze_")) then return false end
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1.5)
    self:SetNextSecondaryFire(CurTime() + 1.5)

    if CLIENT then return end
    if not self:CanDeployDrone() then
        local owner = self:GetOwner()
        if IsValid(owner) then owner:EmitSound("buttons/button10.wav", 65, 100) end
        return
    end

    local owner = self:GetOwner()
    self:SetNWBool("FCDroneUsed", true)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
    owner:DoAnimationEvent(ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE)
    owner:EmitSound("kamikaze/holster.wav", 65, 100)

    timer.Simple(0.45, function()
        if not IsValid(self) or not IsValid(owner) or not owner:Alive() then return end

        local startPos = owner:GetShootPos()
        local aimDir = owner:GetAimVector()
        local spawnPos = startPos + aimDir * 48 + Vector(0, 0, -5)
        local tr = util.TraceHull({
            start = startPos,
            endpos = spawnPos,
            mins = Vector(-12, -12, -8),
            maxs = Vector(12, 12, 8),
            filter = owner,
            mask = MASK_SOLID
        })

        if tr.Hit then
            self:SetNWBool("FCDroneUsed", false)
            owner:EmitSound("buttons/button10.wav", 65, 100)
            owner:ChatPrint("Недостаточно места, чтобы бросить дрон.")
            return
        end

        local drone = ents.Create("kamikaze")
        if not IsValid(drone) then
            self:SetNWBool("FCDroneUsed", false)
            owner:ChatPrint("Не удалось создать дрон.")
            return
        end

        drone:SetPos(spawnPos)
        drone:SetAngles(Angle(0, owner:EyeAngles().y, 0))
        drone.FCDisposable = true
        drone.FCDisposableOwner = owner
        drone.HBOWNER = owner
        drone.Owner = owner
        drone:SetNWEntity("drone_owner", owner)
        drone:Spawn()
        drone:Activate()
        owner.OwnedDrone = drone

        local phys = drone:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetVelocity(owner:GetVelocity() + aimDir * 280 + Vector(0, 0, 90))
            phys:AddAngleVelocity(VectorRand() * 25)
        end

        timer.Simple(0.12, function()
            if not IsValid(drone) or not IsValid(owner) or not owner:Alive() then
                if IsValid(drone) then drone:Remove() end
                return
            end

            if not drone.SetDriver or not drone:SetDriver(owner) then
                drone:Remove()
                owner:ChatPrint("Не удалось подключиться к дрону.")
                return
            end

            owner:EmitSound("kamikaze/draw.wav", 65, 100)
            if IsValid(self) then self:Remove() end
        end)
    end)
end

function SWEP:SecondaryAttack()
    self:PrimaryAttack()
end

function SWEP:Reload()
end
