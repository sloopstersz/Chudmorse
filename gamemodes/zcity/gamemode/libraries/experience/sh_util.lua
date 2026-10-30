--
zb = zb or {}

zb.Experience = zb.Experience or {}

zb.Experience.SkillMedals = {
    {
        icon = Material("vgui/mats_jack_awards/pt"),
        name = "Pt",
        skill = { 4.6, 99999999999999 }
    },
    {
        icon = Material("vgui/mats_jack_awards/au"),
        name = "Au",
        skill = { 3.7, 4.6 }
    },
    {
        icon = Material("vgui/mats_jack_awards/pd"),
        name = "Pd",
        skill = { 2.9, 3.7 }
    },
    {
        icon = Material("vgui/mats_jack_awards/ir"),
        name = "Ir",
        skill = { 2.2, 2.9 }
    },
    {
        icon = Material("vgui/mats_jack_awards/os"),
        name = "Os",
        skill = { 1.6, 2.2 }
    },
    {
        icon = Material("vgui/mats_jack_awards/ru"),
        name = "Ru",
        skill = { 1.1, 1.6 }
    },
    {
        icon = Material("vgui/mats_jack_awards/ag"),
        name = "Ag",
        skill = { .7, 1.1 }
    },
    {
        icon = Material("vgui/mats_jack_awards/sn"),
        name = "Sn",
        skill = { .4, .7 }
    },
    {
        icon = Material("vgui/mats_jack_awards/ni"),
        name = "Ni",
        skill = { .2, .4 }
    },
    {
        icon = Material("vgui/mats_jack_awards/cu"),
        name = "Cu",
        skill = { 0, .2 }
    },
}

zb.Experience.Bands = {
    {
        icon = Material("vgui/mats_jack_awards/10"),
        name = "",
        skill = { 15360, 999999999999999999 }
    },
    {
        icon = Material("vgui/mats_jack_awards/9"),
        name = "",
        skill = { 7680, 15360 }
    },
    {
        icon = Material("vgui/mats_jack_awards/8"),
        name = "",
        skill = { 3840, 7680 }
    },
    {
        icon = Material("vgui/mats_jack_awards/7"),
        name = "",
        skill = { 1920, 3840 }
    },
    {
        icon = Material("vgui/mats_jack_awards/6"),
        name = "",
        skill = { 960, 1920 }
    },
    {
        icon = Material("vgui/mats_jack_awards/5"),
        name = "",
        skill = { 480, 960 }
    },
    {
        icon = Material("vgui/mats_jack_awards/4"),
        name = "",
        skill = { 240, 480 }
    },
    {
        icon = Material("vgui/mats_jack_awards/3"),
        name = "",
        skill = { 120, 240 }
    },
    {
        icon = Material("vgui/mats_jack_awards/2"),
        name = "",
        skill = { 60, 120 }
    },
    {
        icon = Material("vgui/mats_jack_awards/1"),
        name = "",
        skill = { 0, 60 }
    },
}

local SHTable = zb.Experience

function zb.Experience.GetAwards( self )
    local skill = self.skill or 0
    local exp = self.exp or 0
    --print(skill,exp)
    --print(MedalTab.skill[1])
    local Medal = nil
    for i = 1, #SHTable.SkillMedals do
        local MedalTab = SHTable.SkillMedals[i]
        if skill >= tonumber( MedalTab.skill[1] ) and skill < tonumber( MedalTab.skill[2] ) then 
            Medal = table.Copy( MedalTab )
            break 
        end
    end

    local Band = nil
    for i = 1, #SHTable.Bands do
        local BandTab = SHTable.Bands[i]
        if exp >= tonumber( BandTab.skill[1] ) and exp < tonumber( BandTab.skill[2] ) then 
            Band = table.Copy( BandTab )
            break 
        end
    end
    

    return Band, Medal
end


local plyMeta = FindMetaTable("Player")

function plyMeta:GetAwards()
    if CLIENT and IsValid(self) and CurTime() >= (self.NextSQBRequest or 0) then
        self.NextSQBRequest = CurTime() + 1
        net.Start("zb_xp_get")
            net.WriteEntity(self)
        net.SendToServer()
    end
    return zb.Experience.GetAwards( self )
end

function plyMeta:GetStatVal(dataName, fallback)
    if not CLIENT then return end
    if not IsValid(self) then return fallback end
    -- The XP reply carries a complete snapshot, so no counter can be starved.
    self:GetAwards()
    if self.SvDB and self.SvDB[dataName] then
        return self.SvDB[dataName] 
    end
    return fallback
end

if SERVER then
    util.AddNetworkString("get_svPData")

    local svPData = {
        ["Kills"] = true,
        ["Headshots"] = true,
        ["Suicides"] = true,
        ["Deaths"] = true
    }

    net.Receive( "get_svPData", function( len, ply )
        if not IsValid(ply) then return end

        local ent = net.ReadEntity()
        local dataName = net.ReadString()
        if not IsValid(ent) or not ent:IsPlayer() then return end
        if ent ~= ply and not ply:IsAdmin() then return end
        if not isstring(dataName) or not svPData[dataName] then return end
        -- A four-counter refresh is one normal UI operation. A shared cooldown
        -- discarded Deaths/Suicides whenever Kills arrived first.
        -- Key by the fixed whitelist, keeping requests bounded even for admins.
        ply.SvStatReplyTimes = ply.SvStatReplyTimes or {}
        local now = CurTime()
        if now < (ply.SvStatReplyTimes[dataName] or 0) then return end
        ply.SvStatReplyTimes[dataName] = now + 1
        local getter = ent["Get"..dataName]
        if type(getter) ~= "function" then return end
        local value = getter(ent)
        if not isnumber(value) then return end
        net.Start("get_svPData")
            net.WriteEntity( ent )
            net.WriteString( dataName )
            net.WriteFloat( value )
        net.Send(ply)
    end)

    hook.Add("PlayerDeath","ZB_GiveKills", function(ply, inflictor, engineAttacker)
        if not IsValid(ply) then return end
        ply:GiveDeaths(1)
        -- Retain this life's harm table even if round cleanup replaces the map.
        local harm = zb.HarmDone and zb.HarmDone[ply] or {}
        local org = ply.organism
        -- A direct killbind has no harm entry. Organ failure also calls Kill(),
        -- so exclude that path instead of labelling every bleed-out a suicide.
        local directSuicide = engineAttacker == ply and inflictor == ply
            and (not org or (org.alive ~= false and not org.deathStateKilled and not org.incapacitated))
        timer.Simple(.1,function()
            if not IsValid(ply) then return end
            local most_harm,biggest_attacker = 0,nil
                --print(ply)
            for attacker,attacker_harm in pairs(harm) do
                --print(attacker)
                if not IsValid(attacker) or not attacker:IsPlayer() or not isnumber(attacker_harm) then continue end
                if most_harm < attacker_harm then
                    most_harm = attacker_harm
                    biggest_attacker = attacker
                end
            end
            if directSuicide then biggest_attacker = ply end
            -- NPC/world entries cannot receive player statistics. Preserve the
            -- harm-based credit for organ deaths, which internally call Kill().
            if not IsValid(biggest_attacker) and IsValid(engineAttacker)
                and engineAttacker:IsPlayer() and engineAttacker ~= ply then
                biggest_attacker = engineAttacker
            end
            if IsValid(biggest_attacker) then
                if biggest_attacker == ply then
                    biggest_attacker:GiveSuicides(1)
                else
                    biggest_attacker:GiveKills(1)
                end
            end
        end)
    end)
else
    net.Receive( "get_svPData", function()
        local ent = net.ReadEntity()
        local dataName = net.ReadString()
        local dataType = net.ReadFloat()
        if not IsValid(ent) then return end
        ent.SvDB = ent.SvDB or {}
        ent.SvDB[dataName] = dataType
        if IsValid(zb.Experience.OpenedAccount) then
            zb.Experience.OpenedAccount:Udpate(ent)
        end
    end)
end