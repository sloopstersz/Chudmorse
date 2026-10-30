if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_betablock"
SWEP.PrintName = "Antidote Pills"
SWEP.Instructions = "LMB: take pills. RMB: give to a nearby survivor. Cures infection in stages 1-3 only."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Antidote = true
SWEP.modeNames = {[1] = "antidote"}
function SWEP:OwnerChanged() end
function SWEP:TakePill(target)
    if CLIENT or self.ZZUsed or (self.ZZPillCooldown or 0) > CurTime() then return end
    self.ZZPillCooldown = CurTime() + 1
    local owner = self:GetOwner()
    if not IsValid(owner) or not ZZInfection then return end
    local patient = ZZInfection.Human(target)
    if not IsValid(patient) then return end
    local success, message = ZZInfection.UsePill(patient, self.Antidote)
    if message then owner:ChatPrint(message) end
    if not success then return end
    self.ZZUsed = true
    patient:EmitSound("snd_jack_hmcd_pillsuse.wav", 60)
    owner:SelectWeapon("weapon_hands_sh")
    self:Remove()
end
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1)
    self:TakePill(self:GetOwner())
end
function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 1)
    if CLIENT then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local tr = util.TraceLine({start = owner:GetShootPos(), endpos = owner:GetShootPos() + owner:GetAimVector() * 80,
        mask = MASK_SHOT, filter = {owner, owner.FakeRagdoll}})
    self:TakePill(tr.Entity)
end
-- Override inherited treatment so the item never applies beta blockers.
function SWEP:Heal() end
