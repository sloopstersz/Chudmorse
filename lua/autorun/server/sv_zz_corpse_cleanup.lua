-- Use Realish's three-second alpha fade and suppress removal gibs.
local function IsLivingBody(ply, body)
    local owner = hg and hg.RagdollOwner and hg.RagdollOwner(body)
    if IsValid(owner) and owner:Alive() and owner.FakeRagdoll == body then return true end
    for living, rag in pairs((hg and hg.ragdollFake) or {}) do
        if rag == body and IsValid(living) and living:Alive() then return true end
    end
    return IsValid(ply) and ply:Alive() and ply.FakeRagdoll == body
end

local function FadeZombieCorpse(ply, body)
    if not IsValid(body) or IsLivingBody(ply, body) then return end
    local color, mode = body:GetColor(), body:GetRenderMode()
    local noGib, override = body.hg_no_fullbody_remove_gib, body.override
    body.hg_no_fullbody_remove_gib = true
    body.override = true
    body:SetRenderMode(RENDERMODE_TRANSALPHA)
    -- Keep collision unchanged during the fade; no solidity getter is needed.
    local name = "zzombie_corpse_fade_" .. body:EntIndex()
    local step = 0
    timer.Create(name, 3 / 12, 12, function()
        if not IsValid(body) then timer.Remove(name) return end
        -- A revived/reclaimed body must remain usable, including mid-fade.
        if IsLivingBody(ply, body) then
            body:SetColor(color)
            body:SetRenderMode(mode)
            body.hg_no_fullbody_remove_gib, body.override = noGib, override
            body.ZZCorpseCleanupQueued = nil
            timer.Remove(name)
            return
        end
        step = step + 1
        body:SetColor(Color(color.r, color.g, color.b, math.floor(color.a * (1 - step / 12))))
        if step >= 12 then body:Remove() end
    end)
end

-- Death hooks only: temporary ragdolls belonging to living zombies are untouched.
local function QueueZombieCorpse(ply, body, wasZombie)
    local mode = CurrentRound and CurrentRound()
    if not mode or mode.name ~= "zzombies" or not IsValid(body) then return end
    if not (wasZombie or body.ZZZombieBody or (ZZIsZombie and ZZIsZombie(ply))) then return end
    if IsValid(ply) and ply:Alive() then return end
    if body.ZZCorpseCleanupQueued then return end
    body.ZZZombieBody = true
    body.ZZCorpseCleanupQueued = true

    timer.Simple(15, function()
        if not IsValid(body) then return end
        -- A revival or another system may have reclaimed this body in the meantime.
        if IsLivingBody(ply, body) then
            body.ZZCorpseCleanupQueued = nil
            return
        end
        FadeZombieCorpse(ply, body)
    end)
end

hook.Add("RagdollDeath", "ZZZombieCorpseCleanup", QueueZombieCorpse)
hook.Add("PostPostPlayerDeath", "ZZZombieCorpseCleanup", QueueZombieCorpse)

-- Capture the role before death handlers clear it. Resolve the corpse after
-- DoPlayerDeath has finished, regardless of hook order or prior ragdolling.
hook.Add("DoPlayerDeath", "ZZZombieCorpseCapture", function(ply)
    if not (ZZIsZombie and ZZIsZombie(ply)) then return end
    local body = ply.FakeRagdoll
    timer.Simple(0, function()
        if not IsValid(body) and IsValid(ply) then
            body = ply:GetNWEntity("RagdollDeath")
        end
        QueueZombieCorpse(ply, body, true)
    end)
end)

-- Recover marked dead bodies missed by death-hook ordering or a Lua refresh.
-- Never treat a living zombie's temporary ragdoll as a corpse.
timer.Create("ZZZombieCorpseRecovery", 1, 0, function()
    local mode = CurrentRound and CurrentRound()
    if not mode or mode.name ~= "zzombies" then return end
    for _, body in ipairs(ents.FindByClass("prop_ragdoll")) do
        if body.ZZZombieBody and not body.ZZCorpseCleanupQueued
            and not IsLivingBody(body.ply, body) then
            QueueZombieCorpse(nil, body, true)
        end
    end
end)
