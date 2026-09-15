-- Kick Catch: RMB with bare hands while someone is GROUND-kicking you
-- catches their leg and dumps them on the floor.
-- Jump kicks (kicker airborne) can NOT be caught - dodge those instead.
if not SERVER then return end

local RANGE        = 95     -- max distance to the kicker
local COOLDOWN     = 2      -- seconds between attempts per player
local CATCHER_FACE = 0.5    -- how directly catcher must face kicker
local KICKER_FACE  = 0.25   -- kick must be roughly aimed at catcher

hook.Add("KeyPress", "KickCatch_Attempt", function(ply, key)
    if key ~= IN_ATTACK2 then return end
    if not IsValid(ply) or not ply:Alive() then return end

    -- must be bare-handed (either hands variant)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    local wclass = wep:GetClass()
    if wclass ~= "weapon_hands_sh" and wclass ~= "weapon_hg_coolhands" then return end

    -- catcher must be standing and capable
    local char = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
    if char and char:IsRagdoll() then return end

    if (ply.KickCatchCD or 0) > CurTime() then return end



    -- find a valid kicker in front of us
    local myPos = ply:EyePos()
    local myFwd = ply:GetAimVector()

    for _, kicker in player.Iterator() do
        if kicker == ply or not kicker:Alive() then continue end

        -- mid-kick window?
        if kicker:GetNWFloat("InLegKick", 0) <= CurTime() then continue end

        -- GROUND kicks only - airborne (jump) kicks cannot be caught
        if not kicker:IsOnGround() then continue end

        local kChar = hg.GetCurrentCharacter and hg.GetCurrentCharacter(kicker)
        if kChar and kChar:IsRagdoll() then continue end

        local kickerPos = kicker:EyePos()
        local diff = kickerPos - myPos
        if diff:Length() > RANGE then continue end

        local toKicker = diff:GetNormalized()

        -- catcher must be facing the kicker
        if myFwd:Dot(toKicker) < CATCHER_FACE then continue end

        -- the kick must be roughly aimed at the catcher
        if kicker:GetAimVector():Dot(-toKicker) < KICKER_FACE then continue end

        -- clear line between them
        local tr = util.TraceLine({
            start = myPos,
            endpos = kickerPos,
            filter = { ply, kicker, char, kChar }
        })
        if tr.Hit then continue end

        -- ===== CAUGHT =====
        ply.KickCatchCD = CurTime() + COOLDOWN

        -- cancel the kick and release their movement lock
        kicker:PlayCustomAnims("")
        kicker.InLegKick = 0
        kicker:SetNWFloat("InLegKick", 0)

        -- ragdoll them, then put their caught LEG straight into the
        -- catcher's grip - identical hold to RMB-grabbing a ragdoll
        hg.Fake(kicker)

        local handsClass = wclass
        local attempts = 0
        local function TryCarry()
            if not IsValid(ply) or not IsValid(kicker) then return end
            if not ply:Alive() or not kicker:Alive() then return end

            local wep2 = ply:GetActiveWeapon()
            if not IsValid(wep2) or wep2:GetClass() ~= handsClass then return end

            local rag = kicker.FakeRagdoll
            if IsValid(rag) then
                -- small downward shove on the head as the leg is seized -
                -- upper body drops, better odds they clonk their head
                local headBone = rag:LookupBone("ValveBiped.Bip01_Head1")
                if headBone then
                    local hIdx = rag:TranslateBoneToPhysBone(headBone)
                    local hPhys = rag:GetPhysicsObjectNum(hIdx >= 0 and hIdx or 0)
                    if IsValid(hPhys) then
                        hPhys:SetVelocity(hPhys:GetVelocity() + Vector(0, 0, -220))
                    end
                end

                -- grab by the kicking leg (right calf), fall back to spine
                local bone = rag:LookupBone("ValveBiped.Bip01_R_Calf")
                    or rag:LookupBone("ValveBiped.Bip01_Spine2") or 0
                local physIdx = rag:TranslateBoneToPhysBone(bone)
                local phys = rag:GetPhysicsObjectNum(physIdx >= 0 and physIdx or 0)

                if IsValid(phys) and hg.SetCarryEnt2 then
                    hg.SetCarryEnt2(
                        ply, rag, bone, phys:GetMass(),
                        Vector(0, 0, 0),
                        ply:GetAimVector() * 45 + ply:GetShootPos(),
                        ply:EyeAngles()
                    )
                end
                return
            end

            attempts = attempts + 1
            if attempts < 20 then
                timer.Simple(0, TryCarry)
            end
        end
        timer.Simple(0, TryCarry)

        -- feedback
        ply:ViewPunch(Angle(-3, 2, 0))
        ply:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 65)
        kicker:EmitSound("player/clothes_generic_foley_0" .. math.random(1, 5) .. ".wav", 70)

        return -- one catch per press
    end

    -- whiffed attempts still trigger a short cooldown so RMB can't be
    -- spam-held as a passive shield
    ply.KickCatchCD = CurTime() + (COOLDOWN * 0.5)
end)

print("[KickCatch] Loaded - RMB with hands to catch ground kicks")
