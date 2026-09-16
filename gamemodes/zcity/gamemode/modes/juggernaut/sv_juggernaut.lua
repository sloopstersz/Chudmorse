MODE.name = "juggernaut"
MODE.PrintName = "juggernaut"

MODE.OverideSpawnPos = true
MODE.LootSpawn = false
MODE.ForBigMaps = false
MODE.Chance = 0.03

local victimWeapons1 = {
    "weapon_toz106",
    "weapon_musket",
    "weapon_winchester",
    "weapon_mini14",
    "weapon_m16a1",
    "weapon_mp5",
    "weapon_skorpion"
}

-- Scared Chud long guns that should spawn with sling support.
-- Skorpion is intentionally excluded because it is the compact sidearm-style primary.
local victimWeaponsWithSling = {
    ["weapon_toz106"] = true,
    ["weapon_musket"] = true,
    ["weapon_winchester"] = true,
    ["weapon_mini14"] = true,
    ["weapon_m16a1"] = true,
    ["weapon_mp5"] = true
}

local victimWeapons2 = {
	"weapon_glock17",
	"weapon_m9beretta",
	"weapon_hk_usp",
	"weapon_makarov",
	"weapon_p22"
}

local victimConsumables = {
    "weapon_bigconsumable",
    "weapon_smallconsumable",
    "weapon_bandage_sh",
    "weapon_hg_smokenade_tpik",
}

local juggernautLoadout = {
    weapons = {
        {class = "weapon_pkm", extraMags = 2, sling = true},
        {class = "weapon_deagle_annihilator", extraMags = 4},
        {class = "weapon_hg_pipebomb_tpik"}
    },
    armor = {
        "ent_armor_vest5",
        "ent_armor_mask1",
        "ent_armor_helmet5",
        "ent_armor_headphones1"
    },
    curPluv = "pluvberet"
}

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true
end

util.AddNetworkString("juggernaut_start")

function MODE:Intermission()
    game.CleanUpMap()
 
	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
 
		ply:SetupTeam(ply:Team())
	end
end

function MODE:CheckAlivePlayers()
    local acPlayers = {}
    local chigurPlayers = {}
 
    for _, ply in ipairs(team.GetPlayers(0)) do
        if ply:Alive() and not ply:GetNetVar("handcuffed", false) then
            table.insert(chigurPlayers, ply)
        end
    end
 
    for _, ply in ipairs(team.GetPlayers(1)) do
        if ply:Alive() and not ply:GetNetVar("handcuffed", false) then
            table.insert(acPlayers, ply)
        end
    end
 
    return {acPlayers, chigurPlayers}
end

function MODE:EndRound()
    -- Prevent the five-minute reinforcement timer from carrying into another round.
    timer.Remove("JuggernautSpawnNationalGuard")

    -- Legacy Z-City results menu removed. Remorse handles the normal round transition.
end

function MODE:ShouldRoundEnd()
    local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
    return endround
end

local function GetNationalGuardCandidates()
    local available = {}

    for _, ply in player.Iterator() do
        -- National Chud reinforcements are dead Scared Chuds only.
        -- This prevents the Juggernaut from respawning as Guard if they die.
        if ply:Team() ~= 0 then continue end
        if ply:Alive() then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if (ply.afkTime2 or 0) > 60 then continue end

        available[#available + 1] = ply
    end

    return available
end

function MODE:EquipNationalGuard(ply, index)
    ply:SetPlayerClass("nationalguard")

    local gun
    if index == 1 then
        gun = ply:Give("weapon_m249")
    else
        gun = ply:Give("weapon_m4a1")
    end

    if IsValid(gun) then
        ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
    end

    local pistol = ply:Give("weapon_m9beretta")
    if IsValid(pistol) then
        ply:GiveAmmo(pistol:GetMaxClip1() * 3, pistol:GetPrimaryAmmoType(), true)
    end

    ply:Give("weapon_combatknife")
    ply:Give("weapon_handcuffs")
    ply:Give("weapon_handcuffs_key")
    ply:Give("weapon_walkie_talkie")
    ply:Give("weapon_bandage_sh")
    ply:Give("weapon_medkit_sh")

    local taser = ply:Give("weapon_taser")
    if IsValid(taser) then
        ply:GiveAmmo(taser:GetMaxClip1() * 3, taser:GetPrimaryAmmoType(), true)
    end

    hg.AddArmor(ply, {"vest4", "helmet1"})

    local inv = ply:GetNetVar("Inventory") or {}
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_flashlight"] = true
    inv["Weapons"]["hg_sling"] = true
    ply:SetNetVar("Inventory", inv)

    ply:SetNetVar("CurPluv", "pluvberet")

    local hands = ply:Give("weapon_hands_sh")
    if IsValid(hands) then
        ply:SetActiveWeapon(hands)
    end

    zb.GiveRole(ply, "National Chud", Color(60, 90, 0))
end

function MODE:SpawnNationalGuard()
    local candidates = GetNationalGuardCandidates()
    if #candidates == 0 then return 0 end

    table.Shuffle(candidates)

    local count = math.min(#candidates, 6)
    local spawned = 0
    local basepos

    for i = 1, count do
        local ply = candidates[i]
        if not IsValid(ply) then continue end

        ply.isPolice = true
        ply.isTraitor = false
        ply.isGunner = false

        -- Keep Guard on the Scared Chud side for Juggernaut win logic.
        ply:SetupTeam(0)
        ply:Spawn()
        -- GM:PlayerSpawn may auto-balance a respawning player; force Guard back to the Chud side.
        ply:SetTeam(0)

        if not basepos then
            -- National Chuds use the normal random spawn system.
            basepos = zb:GetRandomSpawn()

            if basepos then
                ply:SetPos(basepos)
            end
        elseif basepos then
            hg.tpPlayer(basepos, ply, i)
        end

        self:EquipNationalGuard(ply, spawned + 1)
        spawned = spawned + 1
    end

    return spawned
end

function MODE:RoundStart()
    timer.Remove("JuggernautSpawnNationalGuard")

    timer.Create("JuggernautSpawnNationalGuard", 300, 1, function()
        if zb.ROUND_STATE ~= 1 then return end

        local current = CurrentRound()
        if not current or current.name ~= "juggernaut" then return end

        local spawned = current:SpawnNationalGuard()
        if spawned > 0 then
            PrintMessage(HUD_PRINTTALK, "National Chuds have arrived.")
            EmitSound("snd_jack_hmcd_heli2.mp3", vector_origin, 0, CHAN_AUTO, 1, 125, 0, 100)
        end
    end)
end

function MODE:GiveEquipment()
    local players = {}
    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then
            players[#players + 1] = ply
        end
    end

    table.Shuffle(players)

    local numPlayers = #players
    if numPlayers < 3 then return end

    -- Superadmins can queue a specific player as the next Fat Chud from the scoreboard menu.
    -- Move that player to the final slot, which is the slot this mode already reserves for Juggernaut.
    local forcedJuggernautSteamID = zb.NextSpecialRoleTargets and zb.NextSpecialRoleTargets.juggernaut
    if forcedJuggernautSteamID then
        for index, candidate in ipairs(players) do
            if IsValid(candidate) and candidate:SteamID() == forcedJuggernautSteamID then
                table.remove(players, index)
                players[#players + 1] = candidate
                break
            end
        end

        -- Consume the request when a Juggernaut round starts.
        zb.NextSpecialRoleTargets.juggernaut = nil
    end

    local numac = 1
    local numkillers = numPlayers - numac

    for i = 1, numkillers do
        local ply = players[i]
        ply:SetupTeam(0)
        ply:SetPlayerClass("terrorist")
        zb.GiveRole(ply, "Scared Chud", Color(190, 0, 0))
        ply:Give("weapon_hands_sh")
		ply:Give("weapon_medkit_sh")
        ply:SetNetVar("CurPluv", "pluvmajima")
        ply:Give(victimConsumables[math.random(#victimConsumables)])
    
        local victimWeapons1_choice = victimWeapons1[math.random(#victimWeapons1)]
        local wep1 = ply:Give(victimWeapons1_choice)

        -- Every Scared Chud rifle/long gun receives sling support.
        if victimWeaponsWithSling[victimWeapons1_choice] then
            local inv = ply:GetNetVar("Inventory", {})
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"] = true
            ply:SetNetVar("Inventory", inv)

            if IsValid(wep1) then
                wep1.sling = true
            end
        end
        
        local victimWeapons2_choice = victimWeapons2[math.random(#victimWeapons2)]
        local wep2 = ply:Give(victimWeapons2_choice)
        
        if IsValid(wep1) then
            local ammoType = wep1:GetPrimaryAmmoType()
            local maxClip = wep1:GetMaxClip1()
            if ammoType and ammoType >= 0 and maxClip and maxClip > 0 then
                ply:GiveAmmo(maxClip, ammoType, true)
            end
        end
        
        if IsValid(wep2) then
            local ammoType = wep2:GetPrimaryAmmoType()
            local maxClip = wep2:GetMaxClip1()
            if ammoType and ammoType >= 0 and maxClip and maxClip > 0 then
                ply:GiveAmmo(maxClip, ammoType, true)
            end
            ply:SelectWeapon(wep2:GetClass())
        end
        
        hg.AddArmor(ply, "ent_armor_vest1")
		hg.AddArmor(ply, "ent_armor_helmet7")
    end
    
    for i = numkillers + 1, numPlayers do
        local ply = players[i]
        ply:SetupTeam(1)
        ply:SetPlayerClass("juggernaut")
        zb.GiveRole(ply, "Fat Chud", Color(0, 0, 190))
 
        local inv = ply:GetNetVar("Inventory", {})
        inv["Weapons"] = inv["Weapons"] or {}
        inv["Weapons"]["hg_sling"] = true
        ply:SetNetVar("Inventory", inv)
 
        local hands = ply:Give("weapon_hands_sh")
        if IsValid(hands) then ply:SelectWeapon(hands:GetClass()) end

        -- Juggernaut/Fat Chud starts with a medkit.
        ply:Give("weapon_medkit_sh")

        ply:SetNetVar("CurPluv", juggernautLoadout.curPluv)

        for _, weaponInfo in ipairs(juggernautLoadout.weapons) do
            local wep = ply:Give(weaponInfo.class)

            if IsValid(wep) then
                local ammoType = wep:GetPrimaryAmmoType()
                local maxClip = wep:GetMaxClip1()

                -- extraMags is reserve ammo only; the weapon already spawns with a loaded magazine.
                if weaponInfo.extraMags and weaponInfo.extraMags > 0 and ammoType and ammoType >= 0 and maxClip and maxClip > 0 then
                    ply:GiveAmmo(maxClip * weaponInfo.extraMags, ammoType, true)
                end

                if weaponInfo.sling then
                    wep.sling = true
                end
            end
        end

        for _, armorName in ipairs(juggernautLoadout.armor) do
            hg.AddArmor(ply, armorName)
        end

        ply:SelectWeapon("weapon_deagle_annihilator")
        
        timer.Simple(0.2, function()
            if not IsValid(ply) then return end
            
            ply:SetMaxHealth(350)
            ply:SetHealth(350)
            
            if ply.armors then
                ply.armors["head"] = "helmet5"
                ply.armors["torso"] = "vest5"
                ply.armors["face"] = "mask1"
                ply.armors["ears"] = "headphones1"
            end
            
            -- Keep normal tinnitus behavior; the Juggernaut's headphones provide hearing protection.
            ply.noTinnitus = nil
        end)
    end

    -- Start the intro only after all role/team assignments are finished.
    -- Send the role explicitly so the client never has to race team replication.
    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        net.Start("juggernaut_start")
            net.WriteUInt(ply:Team() == 1 and 1 or 0, 1)
        net.Send(ply)
    end
end

function MODE:GetTeamSpawn()
    -- Team 0 = Scared Chuds, Team 1 = Fat Chud.
    -- Only the Fat Chud has a Juggernaut-specific editor point.
    -- Scared Chuds keep the normal TDM spawn group.
    local scared = zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T"))
    local fat = zb.TranslatePointsToVectors(zb.GetMapPoints("JUGGERNAUT_FAT_CHUD_SPAWN"))

    if not fat or #fat == 0 then
        fat = zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT"))
    end

    return scared, fat
end

function MODE:RoundThink()
end

function MODE:CanLaunch()
    local activePlayers = 0
 
    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then
            activePlayers = activePlayers + 1
        end
    end
    
    if activePlayers < 3 then
        return false
    end
 
    return true
end

return MODE