

if SERVER then AddCSLuaFile() end

SWEP.Base           = "weapon_tpik_base"
SWEP.PrintName      = "Vodka"
SWEP.Instructions   = "Drink to clear current pain and depression. Causes intoxication; injuries can bring symptoms back."
SWEP.Category       = "ZCity Other"
SWEP.Spawnable      = true
SWEP.AdminOnly      = false

SWEP.Primary.Wait   = 1
SWEP.Primary.Next   = 0

SWEP.HoldType       = "slam"
SWEP.ViewModel      = ""
SWEP.WorldModel     = "models/weapons/sweps/stalker2/vodka/w_item_vodka.mdl"
SWEP.WorldModelReal = "models/weapons/sweps/stalker2/vodka/v_item_vodka.mdl"
SWEP.WorldModelExchange = false

if CLIENT then
    SWEP.WepSelectIcon   = Material("entities/weapon_vodka_tpik.png", "smooth mips")
    SWEP.IconOverride    = "entities/weapon_vodka_tpik.png"
    SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = false
SWEP.Slot           = 3
SWEP.SlotPos        = 1
SWEP.WorkWithFake   = true

SWEP.modeNames = {
    [1] = "vodka"
}

function SWEP:InitializeAdd()
    self:SetHold(self.HoldType)
    self.modeValues = {
        [1] = 1
    }
end

SWEP.setlh = true
SWEP.setrh = true
SWEP.HoldAng = Angle(0, 0, 0)

SWEP.AnimList = {
    ["deploy"] = { "anim_draw", 1, false },
    ["attack"] = { "use", 5, false, false, function(self)
        if CLIENT then return end
        self:Heal(self:GetOwner())
    end },
    ["idle"] = { "anim_idle", 5, true }
}

SWEP.HoldPos = Vector(1, 0, 5)

SWEP.modeValuesdef = {
    [1] = 1,
}

SWEP.CallbackTimeAdjust = 1.8

SWEP.showstats = false

SWEP.DeploySnd = "snd_jack_hmcd_foodbounce.wav"
SWEP.FallSnd   = "snd_jack_hmcd_foodbounce.wav"

function SWEP:Animation()
end

if SERVER then

    function SWEP:PrimaryAttack()
        self:PlayAnim("attack")
    end

    function SWEP:Heal(ent, mode)
        local owner = self:GetOwner()
        if self.Consumed or not IsValid(owner) or not IsValid(ent) then return end
        if owner:IsPlayer() and not owner:Alive() then return end
        local org = ent.organism
        if not org or org.alive == false then return end
        if ent ~= owner and not org.otrub then return end
        self.Consumed = true
        local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner

        -- Базовые эффекты на организм 
        org.satiety = (org.satiety or 0) + 2
        org.disorientation = (org.disorientation or 0) + 20
        org.pain = 0
        org.avgpain = 0
        org.painadd = 0
        org.depression = 0
        org.depressionadd = 0
        org.depressionBlood = 0
        org.selfharmPendingUntil = nil
        org.selfharmNextEquip = nil
        local patient = IsValid(org.owner) and org.owner or ent
        if patient:IsPlayer() then
            patient:SetNWFloat("rem_selfharm_pending", 0)
            if patient.selfharming and hg and hg.organism and hg.organism.EndSelfHarm then
                hg.organism.EndSelfHarm(patient)
            end
        end

        -- Звук питья
        entOwner:EmitSound(
            "snd_jack_hmcd_drink" .. math.random(3) .. ".wav",
            60,
            math.random(95, 105)
        )

       
        if apply_drgs_eff then
            apply_drgs_eff(ent, "effect17", 10)
            apply_drgs_eff(ent, "effect37", 10)
        end

        owner:SelectWeapon("weapon_hands_sh")
        self:Remove()

        return true
    end

end
