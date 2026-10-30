local CLASS = player.RegClass("chud_juggernaut")
CLASS.ReloadTimeMultiplier = 0.75

function hg.IsJuggernautHP(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    local mode = CurrentRound and CurrentRound()
    return ply.PlayerClassName == "chud_juggernaut" and mode and mode.name == "juggernaut" and mode.Juggernaut == ply
end

if CLIENT then return end

function hg.UpdateJuggernautHP(ply, org)
    if not hg.IsJuggernautHP(ply) then return end
    ply:SetNWBool("ChudJuggernautHP", true)
    ply:SetNWInt("ChudJuggernautHealth", math.max(ply:Health(), 0))
    ply:SetNWInt("ChudJuggernautMaxHealth", ply:GetMaxHealth())
    if not org then return end
    org.incapacitated, org.critical, org.otrub = false, false, false
    org.needotrub, org.needfake = false, false
    org.pain, org.painadd, org.avgpain, org.shock, org.disorientation = 0, 0, 0, 0, 0
    org.consciousness, org.health = 1, ply:Health()
    if hg.send_organism then hg.send_organism(org) end
end

function CLASS.On(self)
    hg.UpdateJuggernautHP(self, self.organism)
end

function CLASS.Off(self)
    self:SetNWBool("ChudJuggernautHP", false)
    self:SetNWInt("ChudJuggernautHealth", 0)
    self:SetNWInt("ChudJuggernautMaxHealth", 0)
end
