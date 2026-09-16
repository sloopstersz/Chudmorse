local CLASS = player.RegClass("juggernaut")

-- Fat Chud/Juggernaut is completely immune to the panic systems.
CLASS.PanicImmune = true

local BULLDOZER_MODEL = "models/mark2580/payday2/pd2_bulldozer_player.mdl"

function CLASS.On(self)
    if CLIENT then return end

    -- Fat Chud has an exclusive custom voice pack. Stop any normal human
    -- phrase/pain scream that was already playing before the class switch.
    if hg and hg.StopPainScream then
        hg.StopPainScream(self, 0)
    end
    if self.lastPhr and self.lastPhr ~= "" then
        self:StopSound(self.lastPhr)
    end
    self.lastPhr = nil
    self.phrCld = 0

    ApplyAppearance(self, nil, nil, nil, true)

    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    self:SetNWString("PlayerName", "Fat Chud")
    self:SetModel(BULLDOZER_MODEL)
    self:SetSubMaterial()

    Appearance.AAttachments = "none"
    Appearance.AColthes = ""
    self:SetNetVar("Accessories", "none")
    self.CurAppearance = Appearance

    timer.Simple(0.1, function()
        if not IsValid(self) then return end

        -- Re-assert the Bulldozer model after appearance/playerclass setup.
        self:SetModel(BULLDOZER_MODEL)
        self:SetMaxHealth(350)
        self:SetHealth(350)

        if not self.organism then return end

        -- Give the Juggernaut Superfighter combat/stamina values.
        -- Movement speed/jump boosts are excluded in sh_inertia.lua.
        self.organism.superfighter = true
        self.organism.recoilmul = 0.25

        -- Clear any panic carried over from before this player became the Juggernaut.
        self.organism.panicattackadd = 0
        self.organism.panicattack = 0
        self.organism.panicattackActive = false
        self.organism.nextPanicHeartRoll = 0

        self.organism.blood = 8000
        self.organism.maxBlood = 8000
        self.organism.skull = 0.01
        self.organism.spine1 = 0.05
        self.organism.spine2 = 0.05
        self.organism.spine3 = 0.05
        self.organism.chest = 0.1
        self.organism.pelvis = 0.05
        self.organism.lleg = 0.05
        self.organism.rleg = 0.05
        self.organism.larm = 0.05
        self.organism.rarm = 0.05
        self.organism.brain = 0
        self.organism.headamputated = false
        self.organism.llegdislocation = false
        self.organism.rlegdislocation = false
        self.organism.larmdislocation = false
        self.organism.rarmdislocation = false
        self.organism.jawdislocation = false
        self.organism.liver = 0
        self.organism.heart = 0
        self.organism.stomach = 0
        self.organism.intestines = 0
        if self.organism.lungsL then self.organism.lungsL[1] = 0 end
        if self.organism.lungsR then self.organism.lungsR[1] = 0 end
        self.organism.bleedingResistance = 0.2
        self.organism.painResistance = 0.3

        if self.organism.stamina then
            self.organism.stamina.max = 300
            self.organism.stamina.range = 300
            self.organism.stamina[1] = 300
        end
    end)
end

function CLASS.Off(self)
    if CLIENT then return end
    if self.organism then
        self.organism.superfighter = false
        self.organism.recoilmul = 1
        self.organism.maxBlood = nil
        self.organism.bleedingResistance = nil
        self.organism.painResistance = nil
    end
end
