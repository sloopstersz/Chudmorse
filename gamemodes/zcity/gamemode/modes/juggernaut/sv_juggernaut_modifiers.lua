local function IsJuggernaut(ent)
    if not IsValid(ent) then return false end

    -- Team 1 is reused by other modes (TDM SWAT, President defenders, etc.).
    -- Never identify the Juggernaut by team number alone.
    local ply = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local round = CurrentRound and CurrentRound()
    if not round or round.name ~= "juggernaut" then return false end

    return ply.PlayerClassName == "juggernaut"
end

local juggernautLastDamage = {}

hook.Add("EntityTakeDamage", "JuggernautDamage", function(ent, dmgInfo)
    if not IsValid(ent) then return end
    if not IsJuggernaut(ent) then return end
    
    juggernautLastDamage[ent] = CurTime()
    
    local oldDamage = dmgInfo:GetDamage()
    local newDamage = oldDamage * 0.3
    
    dmgInfo:SetDamage(newDamage)
    dmgInfo:SetDamageForce(Vector(0, 0, 0))
end)

hook.Add("Think", "JuggernautConstantUpdate", function()
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:IsPlayer() then continue end
        if not IsJuggernaut(ply) then continue end
        if not ply:Alive() then continue end
        
        local org = ply.organism
        if not org then continue end
        
        local lastDamage = juggernautLastDamage[ply] or 0
        local timeSinceDamage = CurTime() - lastDamage
        
        org.lleg = 0
        org.rleg = 0
        org.larm = 0
        org.rarm = 0
        org.chest = 0
        org.pelvis = 0
        org.spine1 = 0
        org.spine2 = 0
        org.spine3 = 0
        org.skull = 0
        org.liver = 0
        org.heart = 0
        org.stomach = 0
        org.intestines = 0
        org.trachea = 0
        org.brain = 0
        
        if org.lungsL then
            org.lungsL[1] = 0
            org.lungsL[2] = 0
        end
        if org.lungsR then
            org.lungsR[1] = 0
            org.lungsR[2] = 0
        end
        
        org.llegdislocation = false
        org.rlegdislocation = false
        org.larmdislocation = false
        org.rarmdislocation = false
        org.jawdislocation = false
        
        org.llegamputated = false
        org.rlegamputated = false
        org.larmamputated = false
        org.rarmamputated = false
        
        org.immobilization = 0
        org.pain = 0
        org.painadd = 0
        org.avgpain = 0
        org.shock = 0
        org.disorientation = 0
        org.bleed = 0
        org.internalBleed = 0
        org.hurt = 0
        org.hurtadd = 0
        org.needfake = false
        org.needotrub = false
        org.otrub = false
        org.fake = false
        org.canmove = true
        org.canmovehead = true
        
        if timeSinceDamage > 5 then
            if ply:Health() < 350 then
                ply:SetHealth(math.min(ply:Health() + 1, 350))
            end
            
            if org.blood and org.blood < 8000 then
                org.blood = math.min(org.blood + 10, 8000)
            end
        end
        
        if org.wounds then
            for i = #org.wounds, 1, -1 do
                if timeSinceDamage > 3 then
                    org.wounds[i][1] = math.max(org.wounds[i][1] - 0.5, 0)
                    if org.wounds[i][1] <= 0 then
                        table.remove(org.wounds, i)
                    end
                end
            end
        end
        
        if org.arterialwounds then
            for i = #org.arterialwounds, 1, -1 do
                if timeSinceDamage > 5 then
                    org.arterialwounds[i][1] = math.max(org.arterialwounds[i][1] - 1, 0)
                    if org.arterialwounds[i][1] <= 0 then
                        table.remove(org.arterialwounds, i)
                    end
                end
            end
        end
        
        if org.dmgstack then
            table.Empty(org.dmgstack)
        end
        
        ply:SetNetVar("wounds", org.wounds or {})
        ply:SetNetVar("arterialwounds", org.arterialwounds or {})
    end
end)

hook.Add("CanFallDamage", "JuggernautNoFallDamage", function(ply, speed)
    if not IsValid(ply) then return end
    if not ply:IsPlayer() then return end
    if IsJuggernaut(ply) then
        return false
    end
end)

hook.Add("FinishMove", "JuggernautStamina", function(ply, move)
    if not IsValid(ply) then return end
    if not ply:IsPlayer() then return end
    if not IsJuggernaut(ply) then return end
    if not ply.organism then return end
    if not ply.organism.stamina then return end
    
    local walk = ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT)
    local sprint = ply:KeyDown(IN_SPEED)
    
    if walk and sprint then
        ply.organism.stamina.sub = 1
    else
        ply.organism.stamina.sub = 0
    end
    
    ply.organism.stamina.subadd = 0
end)

hook.Add("PreHomigradDamage", "JuggernautBlockBoneDamage", function(ply, dmgInfo, hitgroup, ent, harm, hitBoxs, inputHole)
    if not IsValid(ply) then return end
    if not ply:IsPlayer() then return end
    if not IsJuggernaut(ply) then return end

    -- Remorse passes the hitgroup separately to this hook.
    -- CTakeDamageInfo has no GetHitGroup() method.
    if hitgroup == HITGROUP_HEAD then
        dmgInfo:ScaleDamage(0.1)

        if ply.organism then
            ply.organism.skull = 0
            ply.organism.brain = 0
        end
    end

    return true
end)
