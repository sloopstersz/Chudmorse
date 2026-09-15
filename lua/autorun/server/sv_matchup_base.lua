WWE       = WWE or {}
WWE.moves = WWE.moves or {}

WWE.Config       = WWE.Config or {}
WWE.Config.Reach = 100
WWE.Config.Hull  = 16
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

function WWE.RagdollDown(ply, model, seq, duration, opts)
    if not IsValid(ply) or not ply:Alive() then return nil end
    
    local rag = ply.FakeRagdoll
    if not IsValid(rag) then
        hg.Fake(ply)
        rag = ply.FakeRagdoll
    end
    if not IsValid(rag) then return nil end

    ply.WWE_HoldDownUntil = CurTime() + duration
    WWE.AnimateRagdoll(rag, model or ply:GetModel(), seq, opts)
    return rag
end

function WWE.StandUp(ply)
    if not IsValid(ply) then return end
    ply.WWE_HoldDownUntil = nil
    if IsValid(ply.FakeRagdoll) then hg.FakeUp(ply) end
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
    local move = WWE.moves[name]
    if not move then return false end
    if not WWE.CanGrapple(ply) then return false end
    if move.Condition and not move.Condition(ply) then return false end

    ply.WWE_Cooldowns = ply.WWE_Cooldowns or {}
    if (ply.WWE_Cooldowns[name] or 0) > CurTime() then return false end

    local finder = move.FindTarget or WWE.FindTarget
    local target = finder(ply)
    if not IsValid(target) or target == ply or hg.GetCurrentCharacter(target):IsRagdoll() then return false end
    if not WWE.CanGrapple(target) then return false end

    if move.Execute(ply, target) == false then return false end

    if move.Cooldown then
        ply.WWE_Cooldowns[name] = CurTime() + move.Cooldown
    end
    return true
end

--  wwe_move <name>
--  wwe_move rainmaker

concommand.Add("wwe_move", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if zb.CROUND ~= "event" and not ply:IsAdmin() then ply:ChatPrint("damn something's wrong") return end
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
    if zb.CROUND ~= "event" and not ply:IsAdmin() then ply:ChatPrint("damn something's wrong") return end
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
