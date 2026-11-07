MODE.name = "turfwars"
MODE.PrintName = "Turf Wars"

local MODE = MODE

MODE.ForBigMaps = false

MODE.Chance = 0.02

MODE.OverideSpawnPos = true
MODE.LootSpawn = false

-- Pre-round layout (same as riot): 10 seconds of voting, then the result, then the intro.
MODE.VoteTime = 10
MODE.start_time = 19

-- Planned only: the base round system ends a round as "too boring" this many seconds after the
-- pre-round STARTED. It used to be 180 with a 5 second pre-round (175 seconds of play). The vote
-- makes the pre-round longer, so add start_time to keep those same 175 seconds.
-- Unexpected never uses it, see MODE:ShouldRoundEnd.
MODE.ROUND_TIME = MODE.start_time + 175

function MODE:CanLaunch()
	return true
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

util.AddNetworkString("turfwars_start")
util.AddNetworkString("turfwars_start_vote")
util.AddNetworkString("turfwars_vote_update")
util.AddNetworkString("turfwars_vote_result")
util.AddNetworkString("turfwars_show_selected_mode")
util.AddNetworkString("turfwars_change_vote")
util.AddNetworkString("turfwars_start_select")
util.AddNetworkString("turfwars_select_class")
resource.AddFile("sound/turfwars/crisis_response.mp3")
resource.AddFile("sound/turfwars/gang_war.mp3")

-- ===== Unexpected loot: copied from riot's ESCALATED tier (sv_riot.lua), nothing from Contained/Anarchy =====
-- Keep these in sync with riot if you change riot's lists.
local riotWeapons = {
    "weapon_leadpipe",
    "weapon_hg_extinguisher",
    "weapon_hg_sledgehammer",
    "weapon_hatchet",
    "weapon_hg_crowbar",
    "weapon_hammer",
    "weapon_pocketknife",
    "weapon_hg_machete",
    "weapon_hg_shovel",
    "weapon_bat",
    "weapon_metalbat"
}

local riotConsumables = {
    "weapon_bigconsumable",
    "weapon_smallconsumable",
    "weapon_ducttape",
    "weapon_matches",
    "weapon_bandage_sh",
    "weapon_hg_smokenade_tpik",
    "weapon_hg_shuriken"
}

local riotArmorChance = 40

local INTRO_ROLE_NAMES = {
	[0] = "a Bloodz Member",
	[1] = "a Groove Member",
}

-- Planned intro text: one gang planned this, the other gets surprised. Which gang is which is
-- random every round, so Bloodz sees one of these two lines and Groove sees the other.
local PLANNED_LINES = {
	planner = "You've planned this",
	visited = "You have unexpected visitors",
}

local function RemoveVoteTimers()
	timer.Remove("turfwars_vote_end")
	timer.Remove("turfwars_vote_update")
	timer.Remove("turfwars_select_end")
end

local function GetVariant(index)
	local variants = TURFWARS_VARIANTS or {}
	return variants[index] or variants[1] or {
		id = "PLANNED",
		name = "Planned",
		description = "",
	}
end

local function GetIntroSubtitle(variant, teamId, bloodzPlanned)
	if variant.id == "PLANNED" then
		local isPlanner = (teamId == 0) == bloodzPlanned
		return isPlanner and PLANNED_LINES.planner or PLANNED_LINES.visited
	end

	return variant.name
end

local function GetTurfTeam(ply)
	return ply.TurfAssignedTeam or ply:Team()
end

-- Spawning re-balances teams, so remember the team we picked and re-apply it (same as riot)
local function SetTurfTeam(ply, teamId)
	ply.TurfAssignedTeam = teamId
	ply:SetTeam(teamId)
end

local function GiveWeaponNoReserve(ply, class)
	return ply:Give(class)
end

-- Splits players into two gangs of (nearly) equal size. Players that already have a gang keep it
-- (class selection assigns them early); anyone new goes to the smaller gang, random on a tie.
local function AssignTeams(players)
	local counts = {[0] = 0, [1] = 0}
	local fresh = {}

	for _, ply in ipairs(players) do
		if ply.TurfAssignedTeam ~= nil and counts[ply.TurfAssignedTeam] ~= nil then
			counts[ply.TurfAssignedTeam] = counts[ply.TurfAssignedTeam] + 1
		else
			fresh[#fresh + 1] = ply
		end
	end

	table.Shuffle(fresh)

	for _, ply in ipairs(fresh) do
		local teamId
		if counts[0] == counts[1] then
			teamId = math.random(0, 1)
		elseif counts[0] < counts[1] then
			teamId = 0
		else
			teamId = 1
		end

		counts[teamId] = counts[teamId] + 1
		SetTurfTeam(ply, teamId)
	end
end

-- Planned: the model shown on the class screen is the model the player spawns with
local function ApplyTurfModel(ply)
	if not ply.TurfModel then return end

	ply:SetModel(ply.TurfModel)

	for _, bg in ipairs(ply:GetBodyGroups()) do
		ply:SetBodygroup(bg.id, math.random(0, bg.num))
	end
end

local swatSpawned = false

function MODE:BoringRoundFunction()		
	timer.Simple(2, function()
		//PrintMessage(HUD_PRINTTALK, "IT IS A GANG SHOOTOUT FFS...")
	end)
end

function MODE:Intermission()
	game.CleanUpMap()

	RemoveVoteTimers()
	self.VoteInProgress = false
	self.CurrentVariant = nil
	self.RoundSetupTime = nil
	self.SelectionPending = false
	self.SelectEnd = nil
	self.HasAppliedLoadout = false
	self.VoteResults = {[1] = 0, [2] = 0}
	swatSpawned = false

	self.CTPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_CT" ),self.CTPoints)
	self.TPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_T" ),self.TPoints)

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		ply.HasVoted = nil
		ply.TurfAssignedTeam = nil
		ply.TurfClassChoice = nil
		ply.TurfModel = nil
		if ply:Alive() then
			ply:KillSilent()
		end
	end

	self:StartVoting()
end

function MODE:StartVoting()
	self.VoteInProgress = true
	self.VoteResults = {[1] = 0, [2] = 0}

	net.Start("turfwars_start_vote")
	net.WriteFloat(CurTime() + self.VoteTime)
	net.Broadcast()

	timer.Create("turfwars_vote_end", self.VoteTime, 1, function()
		local mode = CurrentRound()
		if mode and mode.name == "turfwars" then
			mode:EndVoting()
		end
	end)

	timer.Create("turfwars_vote_update", 1, self.VoteTime, function()
		local mode = CurrentRound()
		if not mode or mode.name ~= "turfwars" or not mode.VoteInProgress then return end
		net.Start("turfwars_vote_update")
		net.WriteTable(mode.VoteResults)
		net.Broadcast()
	end)
end

function MODE:EndVoting()
	RemoveVoteTimers()

	local highestVotes = -1
	local selectedVariants = {}

	for variantIndex = 1, 2 do
		local votes = self.VoteResults[variantIndex] or 0
		if votes > highestVotes then
			highestVotes = votes
			selectedVariants = {variantIndex}
		elseif votes == highestVotes then
			selectedVariants[#selectedVariants + 1] = variantIndex
		end
	end

	-- ties are random; if nobody voted it is a Planned round (the original Turf Wars)
	local selected = 1
	if highestVotes > 0 and #selectedVariants > 0 then
		selected = selectedVariants[math.random(#selectedVariants)]
	end

	self.CurrentVariant = GetVariant(selected)
	self.VoteInProgress = false
	self.RoundSetupTime = CurTime() + 4

	-- random per round: which gang "planned this" in the Planned intro
	local bloodzPlanned = math.random(2) == 1

	-- remembered for the intro, which is sent after the (Planned) class selection
	self.IntroSelected = selected
	self.IntroBloodzPlanned = bloodzPlanned

	-- Planned: nothing is handed out until the class selection is over
	self.SelectionPending = (self.CurrentVariant.id == "PLANNED")

	net.Start("turfwars_vote_result")
	net.WriteInt(selected, 4)
	net.WriteTable(self.VoteResults)
	net.Broadcast()

	net.Start("turfwars_show_selected_mode")
	net.WriteInt(selected, 4)
	net.Broadcast()

	timer.Simple(3, function()
		local mode = CurrentRound()
		if not mode or mode ~= self or mode.name ~= "turfwars" then return end

		if mode.SelectionPending then
			mode:StartClassSelection()
			return
		end

		mode.HasAppliedLoadout = false
		mode:GiveEquipment()
		mode:SendIntro()
	end)
end

-- sent to every player who is playing this round: the intro screen with their gang, role and text
function MODE:SendIntro()
	local selected = self.IntroSelected or 1
	local variant = self.CurrentVariant or GetVariant(selected)

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		local teamId = GetTurfTeam(ply)

		net.Start("turfwars_start")
		net.WriteInt(selected, 4)
		net.WriteInt(teamId, 4)
		net.WriteString(INTRO_ROLE_NAMES[teamId] or INTRO_ROLE_NAMES[0])
		net.WriteString(GetIntroSubtitle(variant, teamId, self.IntroBloodzPlanned))
		net.WriteString(variant.description or "")
		net.Send(ply)
	end
end

-- ===== Planned: class selection =====
-- Teams and playermodels are decided here (random, nobody chooses them) and shown on the class screen.
-- Players have TURFWARS_SELECT_TIME seconds to pick; whoever does not gets a random class.
function MODE:StartClassSelection()
	local players = {}

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		players[#players + 1] = ply
	end

	AssignTeams(players)

	self.SelectEnd = CurTime() + TURFWARS_SELECT_TIME

	-- push the round start back so it still begins 6 seconds after the intro (same gap as before),
	-- and keep Planned's 175 seconds of play before the base system's "too boring" cutoff
	local begin = self.SelectEnd + 6
	zb.START_TIME = begin
	hg.UpdateRoundTime((begin - zb.ROUND_START) + 175, zb.ROUND_START, begin)

	for _, ply in ipairs(players) do
		local teamId = ply.TurfAssignedTeam
		local models = TURFWARS_MODELS[teamId] or TURFWARS_MODELS[0]
		ply.TurfModel = models[math.random(#models)]
		ply.TurfClassChoice = nil

		net.Start("turfwars_start_select")
		net.WriteFloat(self.SelectEnd)
		net.WriteInt(teamId, 4)
		net.WriteString(ply.TurfModel)
		net.Send(ply)
	end

	timer.Create("turfwars_select_end", TURFWARS_SELECT_TIME, 1, function()
		local mode = CurrentRound()
		if mode and mode.name == "turfwars" then
			mode:FinishClassSelection()
		end
	end)
end

function MODE:FinishClassSelection()
	timer.Remove("turfwars_select_end")

	if not self.SelectionPending then return end

	-- no pick = random class
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		if not TURFWARS_CLASSES[ply.TurfClassChoice or 0] then
			ply.TurfClassChoice = math.random(#TURFWARS_CLASSES)
		end
	end

	self.SelectionPending = false
	self.RoundSetupTime = CurTime() + 1
	self.HasAppliedLoadout = false

	self:GiveEquipment()
	self:SendIntro()
end

net.Receive("turfwars_select_class", function(_, ply)
	if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return end
	if (ply.LastTurfClassPick or 0) > CurTime() - 0.1 then return end
	ply.LastTurfClassPick = CurTime()

	local choice = net.ReadInt(8)
	if not TURFWARS_CLASSES[choice] then return end

	local mode = CurrentRound()
	if not mode or mode.name ~= "turfwars" or not mode.SelectionPending then return end
	if not mode.SelectEnd or CurTime() > mode.SelectEnd then return end

	ply.TurfClassChoice = choice
end)

net.Receive("turfwars_change_vote", function(_, ply)
	if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return end
	if not ply.LastTurfVoteChange then ply.LastTurfVoteChange = 0 end
	if CurTime() - ply.LastTurfVoteChange < 0.5 then return end
	ply.LastTurfVoteChange = CurTime()

	local previousVote = net.ReadInt(4)
	local newVote = net.ReadInt(4)
	if newVote < 1 or newVote > 2 then return end

	local mode = CurrentRound()
	if not mode or mode.name ~= "turfwars" or not mode.VoteInProgress then return end

	if ply.HasVoted and ply.HasVoted >= 1 and ply.HasVoted <= 2 then
		mode.VoteResults[ply.HasVoted] = math.max(0, (mode.VoteResults[ply.HasVoted] or 0) - 1)
	elseif previousVote >= 1 and previousVote <= 2 then
		mode.VoteResults[previousVote] = math.max(0, (mode.VoteResults[previousVote] or 0) - 1)
	end

	mode.VoteResults[newVote] = (mode.VoteResults[newVote] or 0) + 1
	ply.HasVoted = newVote

	net.Start("turfwars_vote_update")
	net.WriteTable(mode.VoteResults)
	net.Broadcast()
end)

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
	if self.VoteInProgress or self.SelectionPending then return false end
	if (self.RoundSetupTime or 0) > CurTime() then return false end

	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())

	-- Unexpected: the round only ends when a gang is wiped out. Returning false (instead of nil)
	-- tells the base round system not to apply its "too boring" time cutoff at all.
	if self.CurrentVariant and self.CurrentVariant.id == "UNEXPECTED" then
		return endround and true or false
	end

	-- Planned: unchanged, nil keeps the base "too boring" cutoff (MODE.ROUND_TIME)
	return endround
end

function MODE:RoundStart()
    swatSpawned = false 
end

--[[local tblatts = {
	[0] = {
		{"optic4"},
	},
	[1] = {
		{"holo14","laser2","grip3"}
	}
}]]

local tblarmors = {
	[0] = {
		{"ent_armor_vest3","ent_armor_helmet2"}
	},
	[1] = {
		{"ent_armor_vest3","ent_armor_helmet2"}
	}
}

function MODE:GetPlySpawn(ply)
end

local function GivePlannedLoadout()
	MODE.CTPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_CT" ),MODE.CTPoints)
	MODE.TPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_T" ),MODE.TPoints)
	timer.Simple(0.1,function()
		local teamArmorCount = { [0] = 0, [1] = 0 } 

		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end
			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			if ply:Team() == 0 then
				ply:SetPlayerClass("bloodz")
				zb.GiveRole(ply, "Bloodz", Color(190,0,0))
				ply:SetNetVar("CurPluv", "pluvred")
			else
				ply:SetPlayerClass("groove")
				zb.GiveRole(ply, "Groove", Color(0,190,0))
				ply:SetNetVar("CurPluv", "pluvgreen")
			end

			-- the model that was shown on the class screen
			ApplyTurfModel(ply)

			-- the class they picked (or the random one they were given) decides the main weapon
			local class = TURFWARS_CLASSES[ply.TurfClassChoice or 0] or TURFWARS_CLASSES[math.random(#TURFWARS_CLASSES)]
			local wep = ply:Give(class.weapons[math.random(#class.weapons)])
			ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType())

			if wep.SetDeagleSkin then
				//wep:SetDeagleSkin(4)
				//wep:SetDeagleBodygroup(1)
			end

			ply:Give("weapon_bandage_sh")
			ply:Give("weapon_tourniquet")
			ply:Give("weapon_fentanyl")

			local hands = ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			timer.Simple(0.1,function()
				ply.noSound = false
			end)

			ply:SetSuppressPickupNotices(false)
		end
	end)
end

-- ===== Unexpected: riot's Escalated gear, but Bloodz vs Groove =====
-- Same loadout as an Escalated "Angry Chud": hands, a random consumable, 40% chance of a helmet,
-- one melee weapon. The 1st gang member also gets a molotov, the 2nd an MP-80, one random member
-- swaps the melee for riot's sawed-off shotgun, and one random member gets the Glock that riot
-- gives its law side (no reserve ammo, like riot). Playermodels, roles and skins are Planned's.
local function GiveUnexpectedMember(ply, teamId, index, shotgunIndex, glockIndex)
	if teamId == 0 then
		ply:SetPlayerClass("bloodz")
		zb.GiveRole(ply, "Bloodz", Color(190,0,0))
		ply:SetNetVar("CurPluv", "pluvred")
	else
		ply:SetPlayerClass("groove")
		zb.GiveRole(ply, "Groove", Color(0,190,0))
		ply:SetNetVar("CurPluv", "pluvgreen")
	end

	ply:Give("weapon_hands_sh")

	if index == 1 then
		ply:Give("weapon_hg_molotov_tpik")
	elseif index == 2 then
		GiveWeaponNoReserve(ply, "weapon_mp-80")
	end

	ply:Give(riotConsumables[math.random(#riotConsumables)])

	if math.random(100) <= riotArmorChance then
		hg.AddArmor(ply, "ent_armor_helmet2")
	end

	local weapon = index == shotgunIndex and "weapon_remington870_sawed_off" or riotWeapons[math.random(#riotWeapons)]
	GiveWeaponNoReserve(ply, weapon)

	if index == glockIndex then
		GiveWeaponNoReserve(ply, "weapon_glock17")
	end

	ply:SelectWeapon(weapon)
end

local function GiveUnexpectedLoadout(players)
	local gangs = {[0] = {}, [1] = {}}

	for _, ply in ipairs(players) do
		local gang = gangs[GetTurfTeam(ply)]
		if gang then gang[#gang + 1] = ply end
	end

	for teamId = 0, 1 do
		local gang = gangs[teamId]
		local count = #gang
		local shotgunIndex = count > 0 and math.random(count) or 1

		-- a different member than the shotgun one when there is a choice
		local glockIndex = 0
		if count > 1 then
			repeat
				glockIndex = math.random(count)
			until glockIndex ~= shotgunIndex
		end

		for index, ply in ipairs(gang) do
			GiveUnexpectedMember(ply, teamId, index, shotgunIndex, glockIndex)
		end
	end
end

function MODE:GiveEquipment()
	if self.VoteInProgress or not self.CurrentVariant or self.HasAppliedLoadout then return end

	local players = {}

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		players[#players + 1] = ply
	end

	table.Shuffle(players)
	self.HasAppliedLoadout = true

	-- two gangs of (nearly) equal size; Planned already assigned them during class selection
	AssignTeams(players)

	for _, ply in ipairs(players) do
		local teamId = ply.TurfAssignedTeam
		ply:SetupTeam(teamId)
		if not ply:Alive() then
			ply:Spawn()
		end
		SetTurfTeam(ply, teamId)
	end

	if self.CurrentVariant.id == "UNEXPECTED" then
		GiveUnexpectedLoadout(players)
	else
		GivePlannedLoadout()
	end
end

function MODE:RoundThink()
	-- keep everyone on the gang they were assigned (spawning re-balances teams)
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		if ply.TurfAssignedTeam == nil then continue end
		if ply:Team() ~= ply.TurfAssignedTeam then
			ply:SetTeam(ply.TurfAssignedTeam)
		end
	end

	-- SWAT only exists in the Planned variant
	local isPlanned = self.CurrentVariant ~= nil and self.CurrentVariant.id == "PLANNED"
    if isPlanned and not swatSpawned and (CurTime() - zb.ROUND_BEGIN) >= 120 then
        local deadPlayers = {}

        for _, ply in player.Iterator() do
            if not ply:Alive() and ply:Team() != TEAM_SPECTATOR then
                table.insert(deadPlayers, ply)
            end
        end

		local startpos = self.TPoints and #self.TPoints > 0 and self.TPoints[1].pos or zb:GetRandomSpawn()

		for i = 1, math.min(4, #deadPlayers) do
            local ply = deadPlayers[i]

            //if self.TPoints and #self.TPoints > 0 then
                ply:Spawn()
				ply:SetTeam(2)
				ply.TurfAssignedTeam = 2
				if !startpos then
					startpos = ply:GetPos()
				else
					hg.tpPlayer(startpos, ply, i, 0)
				end

                ply:SetPlayerClass("swat")
				zb.GiveRole(ply, "SWAT", Color(0,0,122))
				local gun = ply:Give("weapon_ar15")
                ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
                ply:Give("weapon_medkit_sh")
                ply:Give("weapon_tourniquet")
                ply:Give("weapon_walkie_talkie")
                ply:Give("weapon_hg_flashbang_tpik")
                hg.AddArmor(ply, "ent_armor_helmet1")
                hg.AddArmor(ply, "ent_armor_vest4")

                local hands = ply:Give("weapon_hands_sh")
                ply:SelectWeapon("weapon_hands_sh")
            //end
        end

        swatSpawned = true
    end
end

function MODE:GetTeamSpawn()
	return zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_T" )), zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn()
end

function MODE:EndRound()
	RemoveVoteTimers()

	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
	if ChudCoinRewards then ChudCoinRewards.TeamWin(self, winner) end
	for k,ply in player.Iterator() do
		if ply:Team() == winner then
			ply:GiveExp(math.random(15,30))
			ply:GiveSkill(math.Rand(0.1,0.15))
			
		else
			
			ply:GiveSkill(-math.Rand(0.05,0.1))
		end
	end
end

function MODE:PlayerDeath(ply)
end
