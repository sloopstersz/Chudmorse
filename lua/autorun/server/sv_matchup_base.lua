WWE       = WWE or {}
WWE.moves = WWE.moves or {}

WWE.Config       = WWE.Config or {}
WWE.Config.Reach = 100
WWE.Config.Hull  = 16
WWE.Config.StaminaCost = 35  -- stamina a Martial Artist loses when a move connects

-- Blood puff used by the Martial Artist moves (judge defines this in the gamemode init)
hg = hg or {}
if not hg.BloodAt then
    function hg.BloodAt(ent, boneName)
        if not IsValid(ent) then return end
        local bone = ent:LookupBone(boneName)
        if not bone then return end
        local pos = ent:GetBonePosition(bone)
        local ef = EffectData()
        ef:SetOrigin(pos)
        util.Effect("BloodImpact", ef)
    end
end

local WWE_ADMIN_GROUPS = {
    admin = true,
    superadmin = true,
}

local WWE_DENIED_GROUPS = {
    vip = true,
    mod = true,
    moderator = true,
    moderators = true,
}

-- Keep WWE restricted to actual admin ranks. ULX custom ranks are supported
-- through their inheritance chain, while VIP/moderator ranks stay denied even
-- if their ULX group inherits permissions from admin.
function WWE.HasAdminAccess(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local group = string.lower(tostring(ply:GetUserGroup() or "user"))
    local groups = ULib and ULib.ucl and ULib.ucl.groups
    local visited = {}

    while group ~= "" and not visited[group] do
        if WWE_DENIED_GROUPS[group] then return false end
        if WWE_ADMIN_GROUPS[group] then return true end

        visited[group] = true
        local groupData = groups and groups[group]
        local parent = groupData and groupData.inherit_from
        if not isstring(parent) or parent == "" then break end

        group = string.lower(parent)
    end

    -- Preserve compatibility on servers without ULib.
    if not groups then return ply:IsAdmin() end
    return false
end
-- Admins keep full access; traitor Martial Artists may run their own moves.
-- (the wwe_move / wwe_taunt console commands below stay admin-only)
function WWE.CanUseMoves(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ChudDragonStyle and ChudDragonStyle.CanUse(ply) then return true end
    return ply:IsAdmin() or (zb and zb.CROUND == "event")
end

-- эть нахуй бля наёбка 
local ENTITY = FindMetaTable("Entity")
ENTITY.RealGetVelocity = ENTITY.RealGetVelocity or ENTITY.GetVelocity
function ENTITY:GetVelocity()
    return self.WWE_FakeVel or ENTITY.RealGetVelocity(self)
end

function WWE.ResolvePlayer(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end
    local owner = hg.RagdollOwner(ent)
    if IsValid(owner) and owner:IsPlayer() then return owner end
    return nil
end

function WWE.CanGrapple(ply)
    return IsValid(ply)
        and ply:Alive()
        -- and ply:GetEyeTrace().Entity:IsPlayer()
        -- and not hg.GetCurrentCharacter(ply:GetEyeTrace().Entity):IsRagdoll()
        -- and ply.organism.otrub ~= true
        -- and not hg.GetCurrentCharacter(ply):IsRagdoll()
        -- and ply:IsOnGround()
        -- and not ply:Crouching()
        -- and not ply:KeyDown(IN_DUCK)
end

function WWE.IsGrounded(ply)
    return IsValid(ply) and ply:Alive() and hg.GetCurrentCharacter(ply):IsRagdoll()
end

function WWE.IsStanding(ply)
    return IsValid(ply) and ply:Alive() and not hg.GetCurrentCharacter(ply):IsRagdoll()
end

function WWE.OverVoid(ply)
    local plyz = ply:GetPos().z
    local rply = hg.GetCurrentCharacter(ply)
    local bone = rply:LookupBone("ValveBiped.Bip01_Pelvis") or 0
    local bp   = rply:GetBonePosition(bone)
    if not bp then return false end

    local tr = util.TraceLine({
        start  = Vector(bp.x, bp.y, plyz + 24),
        endpos = Vector(bp.x, bp.y, plyz - 24),
        mask   = MASK_SOLID,
        filter = function(e)
            return not e:IsPlayer() and e:GetClass() ~= "prop_ragdoll"
        end,
    })
    return not tr.Hit
end

function WWE.FindTarget(ply, reach, hull)
    reach = reach or WWE.Config.Reach
    hull  = hull  or WWE.Config.Hull
    local eyePos = ply:EyePos()
    local rad    = Vector(hull, hull, hull)
    local tr = util.TraceHull({
        start  = eyePos,
        endpos = eyePos + ply:GetAimVector() * reach,
        filter = { ply, hg.GetCurrentCharacter(ply) },
        mins   = -rad,
        maxs   = rad,
        mask   = MASK_SHOT,
    })
    return WWE.ResolvePlayer(tr.Entity)
end

function WWE.AnimateRagdoll(rag, model, seq, opts)
    if not IsValid(rag) then return nil end

    if IsValid(rag.AnimModule) then rag.AnimModule:Remove() rag.AnimModule = nil end

    local anm = ents.Create("wwe_ragdoll_anim")
    if not IsValid(anm) then return nil end

    anm:Spawn()
    anm:Setup(rag, model, seq, opts)

    rag.AnimModule = anm
    return anm
end

hook.Add("Should Fake Up", "WWE-HoldDown", function(ply)
    if (ply.WWE_HoldDownUntil or 0) > CurTime() then return false end
end)

-- Temporary animation velocity must expire: FakeUp rejects moving bodies.
function WWE.SetTemporaryVelocity(rag, velocity, duration)
    if not IsValid(rag) then return end
    local token = {}
    rag.WWE_VelocityToken = token
    rag.WWE_FakeVel = velocity
    timer.Simple(duration or 1, function()
        if IsValid(rag) and rag.WWE_VelocityToken == token then
            rag.WWE_FakeVel = nil
            rag.WWE_VelocityToken = nil
        end
    end)
end

function WWE.RagdollDown(ply, model, seq, duration, opts)
    if not IsValid(ply) or not ply:Alive() then return nil end
    
    local rag = ply.FakeRagdoll
    if not IsValid(rag) then
        hg.Fake(ply)
        rag = ply.FakeRagdoll
    end
    if not IsValid(rag) then return nil end

    ply.WWE_HoldDownUntil = CurTime() + duration
    local driver = WWE.AnimateRagdoll(rag, model or ply:GetModel(), seq, opts)
    local token = {}
    ply.WWE_MoveToken = token
    -- Release only this move's controller. Never stop a newer move or stand
    -- the victim up automatically; normal injury/recovery checks still apply.
    timer.Simple(math.max(0, duration) + 0.1, function()
        if IsValid(driver) then driver:Remove() end
        if IsValid(rag) and rag.AnimModule == driver then rag.AnimModule = nil end
        if IsValid(ply) and ply.WWE_MoveToken == token then
            ply.WWE_MoveToken = nil
            ply.WWE_HoldDownUntil = nil
        end
    end)

    -- keep the fighter's own character model visible; the animation itself is driven by
    -- an invisible anim entity, but the posed body should be the player's own
    if IsValid(rag) and rag:GetModel() ~= ply:GetModel() then
        rag:SetModel(ply:GetModel())
    end

    return rag
end

function WWE.StandUp(ply)
    if not IsValid(ply) then return end
    ply.WWE_HoldDownUntil = nil
    if IsValid(ply.FakeRagdoll) then hg.FakeUp(ply) end
end

-- Deal organism damage from a WWE move.
-- The victim is ragdolled (FakeRagdoll) during the move; hitting the FakeRagdoll
-- routes through the Homigrad damage hook straight to the player's organism.
function WWE.ApplyMoveDamage(target, attacker, amount, dmgtype)
	amount = amount or 0
	if amount <= 0 then return end
	if not IsValid(target) or not target:Alive() then return end

	local rag = (IsValid(target.FakeRagdoll) and target.FakeRagdoll) or target
	if not IsValid(rag) then return end

	local att = IsValid(attacker) and attacker or target
	local dmgInfo = DamageInfo()
	dmgInfo:SetAttacker(att)
	dmgInfo:SetInflictor(att)
	dmgInfo:SetDamage(amount)
	dmgInfo:SetDamageType(dmgtype or DMG_CLUB)
	dmgInfo:SetDamagePosition(rag:GetPos())
	rag:TakeDamageInfo(dmgInfo)

	-- Manhunt-style execution feedback: a dense body hit plus a quieter flesh layer.
	local hitPos = rag:GetPos() + Vector(0, 0, 42)
	local blunt = {
		"physics/body/body_medium_impact_hard1.wav",
		"physics/body/body_medium_impact_hard3.wav",
		"physics/body/body_medium_impact_hard5.wav",
		"physics/body/body_medium_impact_hard6.wav",
	}
	local flesh = {
		"physics/flesh/flesh_squishy_impact_hard1.wav",
		"physics/flesh/flesh_squishy_impact_hard2.wav",
		"physics/flesh/flesh_squishy_impact_hard3.wav",
		"physics/flesh/flesh_squishy_impact_hard4.wav",
	}
	sound.Play(blunt[math.random(#blunt)], hitPos, 85, math.random(94, 106), 1)
	sound.Play(flesh[math.random(#flesh)], hitPos, 78, math.random(96, 108), 0.65)

	-- Blunt (DMG_CLUB) barely registers pain through the standard path and
	-- never triggers a pain scream, so guarantee the victim feels it directly.
	local org = target.organism
	if org and amount > 0 then
		org.painadd = (org.painadd or 0) + amount * 1.5
		org.lasthit = CurTime()
		org.immobilization = math.min((org.immobilization or 0) + amount * 0.4, 30)
		if hg.QueuePainScream then hg.QueuePainScream(target, math.Clamp(amount / 25, 0.75, 1.5)) end
	end
end

-- Validate that a model contains a sequence (used for custom killmove models).
-- Caches results so we don't create entities on every move use.
-- Probe with the same scripted animation entity used to drive the ragdolls.
-- Animation-only models do not need prop_dynamic's prop/model validation.
local sequenceDurations = {}
local function ReadSequenceDuration(model, seq)
    local key = model .. "|" .. seq
    if sequenceDurations[key] then return sequenceDurations[key] end
    if not file.Exists(model, "GAME") then return 0 end
    util.PrecacheModel(model)
    local ent = ents.Create("wwe_ragdoll_anim")
    if not IsValid(ent) then return 0 end
    -- Initialize assigns error.mdl, so set the real model after Spawn.
    ent:Spawn()
    ent:SetModel(model)
    ent:Activate()
    local id = ent:LookupSequence(seq)
    if not id or id < 0 then
        for i = 0, ent:GetSequenceCount() - 1 do
            if ent:GetSequenceName(i) == seq then id = i break end
        end
    end
    local duration = 0
    if id and id >= 0 then
        ent:ResetSequence(id)
        duration = tonumber(ent:SequenceDuration(id)) or 0
    end
    ent:Remove()
    -- A missing/unready model must not poison this cache for the whole session.
    if duration > 0 then sequenceDurations[key] = duration end
    return duration
end

function WWE.SeqExists(model, seq)
    return ReadSequenceDuration(model, seq) > 0
end

function WWE.SeqDuration(model, seq)
    return ReadSequenceDuration(model, seq)
end

--  Move registry
--  def = {
--    Condition  = function(ply)          -- extra attacker gate (e.g. sprinting)
--    Cooldown   = number                 -- seconds, per attacker per move
--    FindTarget = function(ply)          -- override target search (optional)
--    Execute    = function(ply, target)  -- do the move; return false to abort
--  }

function WWE.RegisterMove(name, def)
    def.name = name
    WWE.moves[name] = def
end

function WWE.RunMove(ply, name)
    if IsValid(ply) and ply.SubRole == "traitor_martialartist" and ChudDragonStyle and ChudDragonStyle.CanUse(ply)
        and not ChudDragonStyle.CanUseMove(ply, name) then return false end
    if not WWE.CanUseMoves(ply) then return false end

    local move = WWE.moves[name]
    if not move then return false end
    if not WWE.CanGrapple(ply) then return false end
    if move.Condition and not move.Condition(ply) then return false end

    ply.WWE_Cooldowns = ply.WWE_Cooldowns or {}
    if (ply.WWE_Cooldowns[name] or 0) > CurTime() then return false end

    if (ply.WWE_HoldDownUntil or 0) > CurTime() then return false end

    local finder = move.FindTarget or WWE.FindTarget
    local target = finder(ply)
    if not IsValid(target) or target == ply then return false end
    if hg.GetCurrentCharacter(target):IsRagdoll() and not move.AllowDowned then return false end
    if not WWE.CanGrapple(target) then return false end
    ply.WWE_LastTarget = target

    if move.Execute(ply, target) == false then return false end

    -- performing a move drains a Martial Artist's stamina, but only when it connects
    -- (admin matchup moves are unchanged)
    if ply.SubRole == "traitor_martialartist" and ply.organism and ply.organism.stamina then
        ply.organism.stamina.subadd = (ply.organism.stamina.subadd or 0) + (WWE.Config.StaminaCost or 35)
    end

    if move.Cooldown then
        ply.WWE_Cooldowns[name] = CurTime() + move.Cooldown
    end
    return true
end

--  wwe_move <name>
--  wwe_move rainmaker

concommand.Add("wwe_move", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if zb.CROUND ~= "event" and not ply:IsAdmin() then return end
    local name = args[1]
    if not name or name == "" then
        ply:ChatPrint("[WWE] Usage: wwe_move <move>")
        return
    end
    if not WWE.moves[name] then
        ply:ChatPrint("[WWE] Unknown move: " .. name)
        return
    end
    WWE.RunMove(ply, name)
end)

concommand.Add("wwe_taunt", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if zb.CROUND ~= "event" and not ply:IsAdmin() then return end
    local name = args[1]
    if not name or name == "" then
        ply:ChatPrint("[WWE] Usage: wwe_taunt <taunt>")
        return
    end
    if not ply:LookupSequence(name) then
        ply:ChatPrint("[WWE] Unknown sequence: " .. name)
        return
    end
    if hg.GetCurrentCharacter(ply):IsRagdoll() then return end
    if !ply:IsOnGround() then return end
    ply:PlayCustomAnims(name, true, nil, true)
end)

local mods = file.Find("wwe_matchup/modules/*.lua", "LUA")
for _, f in ipairs(mods) do
    include("wwe_matchup/modules/" .. f)
    print("[WWE Matchup] loaded move module: " .. f)
end

include("wwe_matchup/mw_martialartist.lua")
