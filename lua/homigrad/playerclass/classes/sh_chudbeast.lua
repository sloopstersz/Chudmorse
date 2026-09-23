local CLASS = player.RegClass("chudbeast")

CLASS.CanUseDefaultPhrase = false
CLASS.PanicImmune = true

local CHUD_BEAST_MODEL = "models/risenshine/gang_beast.mdl"
local CHUD_BEAST_HEALTH = 165
local CHUD_BEAST_MELEE_MUL = 0.95

local function ClearClassPain(ply)
    if not IsValid(ply) or ply.PlayerClassName ~= "chudbeast" then return end
    local org = ply.organism
    if not org then return end
    org.pain = 0
    org.avgpain = 0
    org.painadd = 0
    org.painlessen = 0
    org.nearpainlimit = false
    org.painScreamQueue = 0
    org.painScreamUntil = 0
    org.painScreamNext = 0
    if SERVER and hg and hg.StopPainScream then hg.StopPainScream(ply, 0) end
end

if SERVER then
    util.PrecacheModel(CHUD_BEAST_MODEL)

    for index = 1, 6 do
        resource.AddFile("sound/chudbeasts/voices/chud" .. index .. ".mp3")
    end
end

local function ApplyRandomBodygroups(ply)
    ply.ChudBeastClassBodygroups = {}

    for _, bodygroup in ipairs(ply:GetBodyGroups() or {}) do
        local id = tonumber(bodygroup.id)
        local count = tonumber(bodygroup.num) or 0

        if id and count > 0 then
            local value = math.random(0, count - 1)
            ply.ChudBeastClassBodygroups[id] = value
            ply:SetBodygroup(id, value)
        end
    end
end

local function EnsureChudBeastModel(ply)
    if CLIENT or not IsValid(ply) or ply.PlayerClassName ~= "chudbeast" then return end
    if string.lower(ply:GetModel() or "") == CHUD_BEAST_MODEL then return end
    ply:SetModel(CHUD_BEAST_MODEL)
    for id, value in pairs(ply.ChudBeastClassBodygroups or {}) do ply:SetBodygroup(id, value) end
end

function CLASS.On(self)
    if CLIENT then return end

    self.ContextChudBeast = true
    self.ChudBeastClassHadMeleeDamageMul = self.MeleeDamageMul ~= nil
    self.ChudBeastClassOldMeleeDamageMul = self.MeleeDamageMul
    self.MeleeDamageMul = (self.MeleeDamageMul or 1) * CHUD_BEAST_MELEE_MUL

    self:SetModel(CHUD_BEAST_MODEL)
    ApplyRandomBodygroups(self)
    self:SetMaxHealth(CHUD_BEAST_HEALTH)
    self:SetHealth(CHUD_BEAST_HEALTH)

    if self.organism then
        -- Keep the Chud Beast combat/stamina behavior while sh_inertia.lua
        -- explicitly preserves normal walking speed and jump height.
        self.organism.superfighter = true
        self.organism.recoilmul = 0.25
        self.organism.panicattackadd = 0
        self.organism.panicattack = 0
        self.organism.panicattackActive = false
        self.organism.nextPanicHeartRoll = 0
    end

    ClearClassPain(self)

    timer.Simple(0.1, function()
        if not IsValid(self) or self.PlayerClassName ~= "chudbeast" then return end
        self:SetModel(CHUD_BEAST_MODEL)
        for id, value in pairs(self.ChudBeastClassBodygroups or {}) do
            self:SetBodygroup(id, value)
        end
    end)
end

function CLASS.Think(self)
    ClearClassPain(self)
    if SERVER and (self.ChudBeastNextModelCheck or 0) <= CurTime() then
        self.ChudBeastNextModelCheck = CurTime() + 0.1
        EnsureChudBeastModel(self)
    end
end

if SERVER then
    hook.Add("PostEntityTakeDamage", "ChudBeastClass_ClearPainAfterDamage", function(target)
        local ply = target
        if IsValid(target) and target:IsRagdoll() and hg and hg.RagdollOwner then ply = hg.RagdollOwner(target) end
        if not IsValid(ply) or ply.PlayerClassName ~= "chudbeast" then return end
        ClearClassPain(ply)
        timer.Simple(0, function() if IsValid(ply) then ClearClassPain(ply) end end)
    end)
end

function CLASS.Off(self)
    if CLIENT then return end

    self.ContextChudBeast = nil
    self.ChudBeastClassBodygroups = nil
    self.ChudBeastNextModelCheck = nil

    if self.ChudBeastClassHadMeleeDamageMul then
        self.MeleeDamageMul = self.ChudBeastClassOldMeleeDamageMul
    else
        self.MeleeDamageMul = nil
    end
    self.ChudBeastClassOldMeleeDamageMul = nil
    self.ChudBeastClassHadMeleeDamageMul = nil

    if self.organism then
        self.organism.superfighter = false
        self.organism.recoilmul = 1
    end
end
