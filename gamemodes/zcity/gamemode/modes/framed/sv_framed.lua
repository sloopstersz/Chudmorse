if not SERVER then return end
local MODE = MODE
MODE.name = "framed"
MODE.PrintName = "Framed"

MODE.start_time = 1
MODE.end_time = 7

-- Hard cap for the whole round. 11 minute kill timer + intro + the time cops get with the sketch.
MODE.ROUND_TIME = 1500

MODE.randomSpawns = true
MODE.shouldfreeze = true
MODE.OverrideSpawn = true
MODE.PoliceAllowed = false

-- Chance of this mode being rolled (can be changed in game with zb_setmodechance framed <number>)
MODE.Chance = 0.1

--\\ Loot: exactly the same pool and pacing as homicide
MODE.LootSpawn = true
MODE.LootOnTime = true
MODE.LootDivTime = 700
MODE.LootAmountMul = 0.75
MODE.EmptyBoxChance = 0.15
MODE.LootLooseSkip = 0.25

local function SyncLootTable()
	local hmcd = zb.modes and zb.modes["hmcd"]
	if not hmcd then return end

	if hmcd.Types and hmcd.Types.standard and hmcd.Types.standard.LootTable then
		MODE.LootTable = hmcd.Types.standard.LootTable
	else
		MODE.LootTable = hmcd.LootTableSingle or hmcd.LootTable
	end
end

-- Same karma scaling homicide uses, minus the "traitor opened it" bonus so the killer gets no extra loot.
function MODE:ZB_LootMultiplier(ply)
	if not IsValid(ply) then return 1 end

	local karma = ply.Karma or 100
	if karma < 30 then return 0.25 end
	if karma < 70 then return 0.5 end
	if zb.MaxKarma and karma >= zb.MaxKarma then return 1.25 end

	return 1
end
--//

--\\ Sounds
resource.AddFile("sound/framed/killer_intro.mp3")
resource.AddFile("sound/framed/civilian_intro.mp3")
resource.AddFile("sound/framed/cop_intro.mp3")
--//

util.AddNetworkString("framed_start")
util.AddNetworkString("framed_target")
util.AddNetworkString("framed_sketch")
util.AddNetworkString("framed_roundend")
util.AddNetworkString("framed_skip")
util.AddNetworkString("framed_release")
util.AddNetworkString("framed_setrole")

-- Admin overrides for the next Framed round (set from the scoreboard right click menu, used once).
MODE.ForcedKiller = nil
MODE.ForcedCops = {}

-- Round state (rebuilt every round)
MODE.Killer = nil
MODE.Cops = {}
MODE.Civilians = {}
MODE.Targets = {}
MODE.TargetLookup = {}
MODE.SketchGiven = false
MODE.ReleaseTime = nil
MODE.TimeUpAt = nil
MODE.StartRoundTime = nil
MODE.Result = nil

local ROLE_CIVILIAN, ROLE_COP, ROLE_KILLER = 0, 1, 2

local COLOR_KILLER = Color(190, 0, 0)
local COLOR_COP = Color(15, 15, 255)
local COLOR_CIVILIAN = Color(60, 205, 90)

local function IsParticipant(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR
end

local function RoleID(ply)
    return ply:IsBot() and ("BOT:" .. ply:UserID()) or ply:SteamID()
end

local function IsAFK(ply)
	return (ply.afkTime2 or 0) > 60
end

--\\ Round flow
function MODE:CanLaunch()
    local count = 0
    for _, ply in player.Iterator() do if IsParticipant(ply) then count = count + 1 end end
    return count >= 2
end

function MODE:CanSpawn()
end

function MODE:GiveEquipment()
end

function MODE:GetPlySpawn(ply)
end

function MODE:Intermission()
	self.RoundSerial = (self.RoundSerial or 0) + 1
	game.CleanUpMap()

	timer.Remove("framed_endcheck")

	self.Killer = nil
	self.Cops = {}
	self.Civilians = {}
	self.Targets = {}
	self.TargetLookup = {}
	self.SketchGiven = false
	self.ReleaseTime = nil
	self.TimeUpAt = nil
	self.StartRoundTime = nil
	self.Result = nil

	SyncLootTable()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		ply:KillSilent()

		ply.isPolice = false
		ply.isTraitor = false
		ply.isGunner = false
		ply.MainTraitor = false
		ply.SubRole = nil
		ply.Profession = nil
		ply.FramedHoldUntil = nil

		ply:SetupTeam(0)

		if ply.organism and DefaultSkillIssue then
			ply.organism.recoilmul = DefaultSkillIssue
		end
	end
end

function MODE:RoundStart()
	self.StartRoundTime = CurTime()
	self.Result = nil

	SyncLootTable()

	self:AssignRoles()
	self:SpawnEveryone()
end

function MODE:AssignRoles()
	self.Killer = nil
	self.Cops = {}
	self.Civilians = {}
	self.Targets = {}
	self.TargetLookup = {}
	self.SketchGiven = false

	local pool = {}

	for _, ply in player.Iterator() do
		if IsParticipant(ply) then
			pool[#pool + 1] = ply
		end
	end

	local total = #pool
	if total == 0 then return end

	-- Admin overrides are used up by this round, whether or not the picked players are still here.
	local forcedKillerID = self.ForcedKiller
	local forcedCopIDs = self.ForcedCops or {}

	self.ForcedKiller = nil
	self.ForcedCops = {}

	local killer

	if forcedKillerID then
		for _, ply in ipairs(pool) do
			if RoleID(ply) == forcedKillerID then
				killer = ply
				break
			end
		end
	end

	-- Players an admin made cops are not eligible for the random killer pick.
	local killerPool = {}

	for _, ply in ipairs(pool) do
		if not forcedCopIDs[RoleID(ply)] then
			killerPool[#killerPool + 1] = ply
		end
	end

	if #killerPool == 0 then killerPool = pool end

	-- Otherwise: karma weighted like the homicide traitor pick, awake players first.
	if not killer then
		for _, ply in RandomPairs(killerPool) do
			if not IsAFK(ply) and math.random(100) <= (ply.Karma or 100) then
				killer = ply
				break
			end
		end
	end

	if not killer then
		for _, ply in RandomPairs(killerPool) do
			if not IsAFK(ply) then
				killer = ply
				break
			end
		end
	end

	killer = killer or killerPool[math.random(#killerPool)]

	killer.isTraitor = true
	killer.MainTraitor = true
	self.Killer = killer

	-- Everybody else, awake players first so AFK players end up as plain civilians.
	local awake, afk = {}, {}

    for _, ply in RandomPairs(pool) do
        if ply ~= killer then
            if IsAFK(ply) then
                afk[#afk + 1] = ply
            else
                awake[#awake + 1] = ply
            end
        end
    end

	local ordered = awake
	table.Add(ordered, afk)

	-- Admin-picked cops always become cops, ahead of the random ones.
	local forcedCops, others = {}, {}

	for _, ply in ipairs(ordered) do
		if forcedCopIDs[RoleID(ply)] then
			forcedCops[#forcedCops + 1] = ply
		else
			others[#others + 1] = ply
		end
	end

	local forcedCount = #forcedCops

	table.Add(forcedCops, others)
	ordered = forcedCops

	local copCount = math.min(math.max(self.GetCopCount(total), forcedCount), math.max(total - 2, 0))

	for i = 1, #ordered do
		local ply = ordered[i]

		if i <= copCount then
			ply.isPolice = true
			self.Cops[#self.Cops + 1] = ply
		else
			self.Civilians[#self.Civilians + 1] = ply
		end
	end

	local targetCount = math.min(self.GetTargetCount(total), #self.Civilians)

	for i = 1, targetCount do
		local ply = self.Civilians[i]
		local data = {ply = ply, dead = false}

		self.Targets[#self.Targets + 1] = data
		self.TargetLookup[ply] = data
	end
end

function MODE:EquipCop(ply)
	local serial = self.RoundSerial
	ply:SetPlayerClass("police")

	local glock = ply:Give("weapon_glock17")

	if IsValid(glock) then
		if glock:GetPrimaryAmmoType() >= 0 then
			ply:GiveAmmo(glock:GetMaxClip1() * 3, glock:GetPrimaryAmmoType(), true)
		end

		local attachments = {}
		if math.random(2) == 1 then attachments[#attachments + 1] = "holo16" end
		if math.random(2) == 1 then attachments[#attachments + 1] = "laser3" end

		if #attachments > 0 then
			timer.Simple(0.5, function()
				if CurrentRound() ~= self or self.RoundSerial ~= serial or zb.ROUND_STATE ~= 1 or not IsValid(ply) or not ply:Alive() or not IsValid(glock) then return end

				local wep = glock
				if not IsValid(wep) or not hg or not hg.AddAttachmentForce then return end

				for _, attachment in ipairs(attachments) do
					hg.AddAttachmentForce(ply, wep, attachment)
				end
			end)
		end
	end

	ply:Give("weapon_medkit_sh")
	ply:Give("weapon_walkie_talkie")
	ply:Give("weapon_naloxone")
	ply:Give("weapon_painkillers")
	ply:Give("weapon_handcuffs")
	ply:Give("weapon_handcuffs_key")
	ply:Give("weapon_hg_tonfa")

	local taser = ply:Give("weapon_taser")

	if IsValid(taser) and taser:GetPrimaryAmmoType() >= 0 then
		ply:GiveAmmo(taser:GetMaxClip1() * 3, taser:GetPrimaryAmmoType(), true)
	end

	if hg and hg.AddArmor then
		hg.AddArmor(ply, {"vest2"})
	end

	local inv = ply:GetNetVar("Inventory")

	if istable(inv) then
		inv["Weapons"] = inv["Weapons"] or {}
		inv["Weapons"]["hg_flashlight"] = true
		ply:SetNetVar("Inventory", inv)
	end

	if ply.organism then
		ply.organism.recoilmul = 0.8
	end

	ply:SetNetVar("CurPluv", "pluvberet")
end

function MODE:EquipKiller(ply)
	local serial = self.RoundSerial
	-- Suppressed P22 and one spare magazine (the gun comes loaded, the spare is the reserve ammo).
	local p22 = ply:Give("weapon_p22")

	if IsValid(p22) and p22:GetPrimaryAmmoType() >= 0 then
		ply:GiveAmmo(p22:GetMaxClip1(), p22:GetPrimaryAmmoType(), true)
	end

	timer.Simple(0.5, function()
		if CurrentRound() ~= self or self.RoundSerial ~= serial or zb.ROUND_STATE ~= 1 or not IsValid(ply) or not ply:Alive() or not IsValid(p22) then return end

		local wep = p22

		if IsValid(wep) and hg and hg.AddAttachmentForce then
			hg.AddAttachmentForce(ply, wep, "supressor4")
		end
	end)
end

function MODE:SpawnEveryone()
	local serial = self.RoundSerial
	local copBase, copIndex = nil, 0
	local idx = 0

	for _, ply in player.Iterator() do
		if not IsParticipant(ply) then continue end

		idx = idx + 1
		ply.SubRole = nil

        -- Start the hold before spawning/equipping, not after the delayed briefing message.
        if ply == self.Killer then ply.FramedHoldUntil = CurTime() + self.KillerIntroDuration + 5 end
        ply:Spawn()
        ply:SetupTeam(0)
        ply:StripWeapons()
        ply:RemoveAllAmmo()
        ApplyAppearance(ply, nil, nil, nil, true)

		if ply.isPolice then
			copIndex = copIndex + 1

			if not copBase then
				copBase = zb:GetRandomSpawn()
				if copBase then ply:SetPos(copBase) end
			else
				hg.tpPlayer(copBase, ply, copIndex)
			end
		else
			ply:GetRandomSpawn()
		end

		if not ply:Alive() then continue end

		ply:SetSuppressPickupNotices(true)
		ply.noSound = true

		if ply.isPolice then
			self:EquipCop(ply)
		end

		if ply == self.Killer then
			self:EquipKiller(ply)
		end

		local hands = ply:Give("weapon_hands_sh")
		if IsValid(hands) then ply:SetActiveWeapon(hands) end
		ply:SetNetVar("flashlight", false)

		timer.Simple(0.1, function()
			if not IsValid(ply) then return end

			ply.noSound = false
			ply:SetSuppressPickupNotices(false)
		end)

		local role = (ply == self.Killer and ROLE_KILLER) or (ply.isPolice and ROLE_COP) or ROLE_CIVILIAN

		timer.Simple(0.6 + 0.05 * idx, function()
            if CurrentRound() ~= self or self.RoundSerial ~= serial or zb.ROUND_STATE ~= 1
                or not IsValid(ply) or not ply:Alive() then return end
            self:SendStart(ply, role)
		end)
	end

end

function MODE:BuildTargetInfo()
	for _, data in ipairs(self.Targets) do
		local ply = data.ply

		if IsValid(ply) then
			local appearance = istable(ply.CurAppearance) and table.Copy(ply.CurAppearance) or {}

			data.appearance = appearance
			data.name = appearance.AName or ply:Nick()
			data.model = ply:GetModel() or ""
		else
			data.appearance = data.appearance or {}
			data.name = data.name or "Unknown"
			data.model = data.model or ""
		end
	end
end

function MODE:SendStart(ply, role)
	local killerRole = role == ROLE_KILLER

	if killerRole then
		self:BuildTargetInfo()

		-- The killer is held in place while the briefing plays (F skips it). The kill timer starts on release.
		self.ReleaseTime = CurTime() + self.KillerIntroDuration
		self.TimeUpAt = self.ReleaseTime + self.KillTime
		ply.FramedHoldUntil = self.ReleaseTime
	end

	net.Start("framed_start")
		net.WriteUInt(role, 2)
		net.WriteFloat(killerRole and self.KillerIntroDuration or self.CrewIntroDuration)
		net.WriteUInt(#self.Targets, 4)

		if killerRole then
			net.WriteFloat(self.KillTime)
            net.WriteFloat(self.ReleaseTime)
            net.WriteFloat(self.TimeUpAt)

			for _, data in ipairs(self.Targets) do
				net.WriteString(data.name or "Unknown")
				net.WriteString(data.model or "")
				net.WriteTable(data.appearance or {})
				net.WriteEntity(data.ply)
                net.WriteBool(data.dead == true)
			end
		end
	net.Send(ply)

	if killerRole then
		zb.GiveRole(ply, "Killer", COLOR_KILLER)
	elseif role == ROLE_COP then
		zb.GiveRole(ply, "Police Officer", COLOR_COP)
	else
		zb.GiveRole(ply, "Civilian", COLOR_CIVILIAN)
	end
end
--//

--\\ Killer briefing skip
function MODE:ReleaseKiller()
	local killer = self.Killer
	if not IsValid(killer) then return end

	local now = CurTime()

	killer.FramedHoldUntil = now
	self.ReleaseTime = now
	self.TimeUpAt = now + self.KillTime
    net.Start("framed_release")
    net.WriteFloat(self.ReleaseTime)
    net.WriteFloat(self.TimeUpAt)
    net.Send(killer)
end

net.Receive("framed_skip", function(_, ply)
	if zb.ROUND_STATE ~= 1 then return end

	local mode = zb.modes["framed"]
	if not mode or CurrentRound() ~= mode then return end
	if ply ~= mode.Killer or not IsParticipant(ply) or not ply:Alive() then return end
	if (ply.FramedHoldUntil or 0) <= CurTime() then return end

	mode:ReleaseKiller()
end)
--//

--\\ Admin role overrides (scoreboard right click -> "Set as framed killer / cop"), admin or higher
net.Receive("framed_setrole", function(_, ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end

	local target = net.ReadEntity()
	local role = net.ReadString()

	if role == "clear" then
		MODE.ForcedKiller = nil
		MODE.ForcedCops = {}

		ply:ChatPrint("Framed: forced roles cleared.")
		return
	end

	if not IsValid(target) or not target:IsPlayer() then return end

	local id = RoleID(target)

	if role == "killer" then
		MODE.ForcedCops[id] = nil
		MODE.ForcedKiller = id

		ply:ChatPrint(target:Nick() .. " will be the killer in the next Framed round.")
	elseif role == "cop" then
		if MODE.ForcedKiller == id then MODE.ForcedKiller = nil end
		MODE.ForcedCops[id] = true

		ply:ChatPrint(target:Nick() .. " will be a cop in the next Framed round.")
	end
end)
--//

--\\ Targets
local function KilledByKiller(victim)
	local killer = MODE.Killer
	if not IsValid(killer) then return false end

	local lastHit = victim.RSLastHit

	if lastHit and IsValid(lastHit.att) and (CurTime() - (lastHit.t or 0)) < 60 then
		return lastHit.att == killer
	end

	local best, who = 0, nil

	for attacker, damage in pairs((zb.HarmDone and zb.HarmDone[victim]) or {}) do
		if IsValid(attacker) and attacker ~= victim and damage > best then
			best, who = damage, attacker
		end
	end

	return who == killer
end

function MODE:SendTargetDown(data, byKiller)
	local killer = self.Killer
	if not IsValid(killer) then return end

	local index = table.KeyFromValue(self.Targets, data)
	if not index then return end

	net.Start("framed_target")
		net.WriteUInt(index, 4)
		net.WriteBool(byKiller)
	net.Send(killer)
end

function MODE:QueueEndCheck()
	local mode = self

	timer.Create("framed_endcheck", 0.25, 1, function()
		if zb.ROUND_STATE ~= 1 then return end
		if CurrentRound() ~= mode then return end

		if mode:ShouldRoundEnd() then
			zb:EndRound()
		end
	end)
end

function MODE:Player_Death(ply)
	if zb.ROUND_STATE ~= 1 then return end

	if ply == self.Killer then
		self:QueueEndCheck()
		return
	end

	local data = self.TargetLookup and self.TargetLookup[ply]
	if not data or data.dead then return end

	data.dead = true

	self:SendTargetDown(data, KilledByKiller(ply))
	self:QueueEndCheck()
end

function MODE:PlayerDisconnected(ply)
	if zb.ROUND_STATE ~= 1 then return end

	local data = self.TargetLookup and self.TargetLookup[ply]

	if data and not data.dead then
		data.dead = true
		self:SendTargetDown(data, false)
	end

	self:QueueEndCheck()
end
--//

--\\ Sketch (the killer ran out of time)
function MODE:RoundThink()
    if zb.ROUND_STATE ~= 1 then return end
    -- Recover targets when a death callback was missed or someone switched to spectator.
    for _, data in ipairs(self.Targets) do
        if not data.dead and (not IsParticipant(data.ply) or not data.ply:Alive()) then
            data.dead = true
            self:SendTargetDown(data, IsValid(data.ply) and KilledByKiller(data.ply) or false)
        end
    end

	if not self.SketchGiven and self.TimeUpAt and CurTime() >= self.TimeUpAt then
		self:GiveSketch()
	end
end

-- Once the sketch is out, the killer is always sent to the cops (even from far away) so the red highlight works everywhere.
function MODE:SetupPlayerVisibility(ply, viewEnt)
	if zb.ROUND_STATE ~= 1 or not self.SketchGiven then return end
	if not ply.isPolice then return end

	local killer = self.Killer
	if not IsValid(killer) or not killer:Alive() then return end

	local character = (hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(killer)) or killer
	if not IsValid(character) then character = killer end

	AddOriginToPVS(character:GetPos())
end

function MODE:GiveSketch()
	if self.SketchGiven then return end
	self.SketchGiven = true

	local killer = self.Killer
	if not IsValid(killer) or not killer:Alive() then return end

	local appearance = istable(killer.CurAppearance) and table.Copy(killer.CurAppearance) or {}
	local name = appearance.AName or killer:Nick()
	local model = killer:GetModel() or ""

	for _, cop in ipairs(self.Cops) do
		if not IsValid(cop) or not cop:Alive() then continue end

		net.Start("framed_sketch")
			net.WriteBool(true)
			net.WriteString(name)
			net.WriteString(model)
			net.WriteTable(appearance)
			net.WriteUInt(killer:EntIndex(), 16)
		net.Send(cop)
	end

	net.Start("framed_sketch")
		net.WriteBool(false)
	net.Send(killer)
end
--//

--\\ Round end
function MODE:EvaluateResult()
	if #self.Targets == 0 then return "failed" end
	local killer = self.Killer

	if not IsValid(killer) or killer:Team() == TEAM_SPECTATOR or not killer:Alive() or killer:GetNetVar("handcuffed", false) then
		return "failed"
	end

	if #self.Targets > 0 then
		local left = 0

		for _, data in ipairs(self.Targets) do
			if not data.dead then left = left + 1 end
		end

		if left == 0 then
			return "escaped"
		end
	end

	return nil
end

function MODE:ShouldRoundEnd()
	if not self.StartRoundTime or (CurTime() - self.StartRoundTime) < 3 then
		return false
	end

	local result = self:EvaluateResult()

	if result then
		self.Result = result
		return true
	end
end

-- Called by the round system when the hard cap is hit: the job wasn't finished in time.
function MODE:BoringRoundFunction()
	self.Result = self.Result or "failed"
end

function MODE:EndRound()
	self.RoundSerial = (self.RoundSerial or 0) + 1
	timer.Remove("framed_endcheck")

	local result = self.Result or self:EvaluateResult() or "failed"
	self.Result = result

	local escaped = result == "escaped"
	local killer = self.Killer

	local alias, nick, aliasColor = "Unknown", "disconnected", Color(255, 255, 255)

	if IsValid(killer) then
		local appearance = istable(killer.CurAppearance) and killer.CurAppearance or {}

		alias = appearance.AName or killer:Nick()
		nick = killer:Nick()

		local c = appearance.AColor

		if istable(c) and c.r and c.g and c.b then
			aliasColor = Color(c.r, c.g, c.b)
		elseif isvector(c) then
			aliasColor = Color(c.x * 255, c.y * 255, c.z * 255)
		end
	end

	net.Start("framed_roundend")
		net.WriteBool(escaped)
		net.WriteString(alias)
		net.WriteString(nick)
		net.WriteColor(aliasColor)
	net.Broadcast()

	timer.Simple(2, function()
		if IsValid(killer) then
			PrintMessage(HUD_PRINTTALK, "The killer was " .. killer:Name())
		else
			PrintMessage(HUD_PRINTTALK, "The killer left the game.")
		end
	end)

	if IsValid(killer) then
		if escaped then
			if killer.GiveExp then killer:GiveExp(math.Rand(30, 50)) end
			if killer.GiveSkill then killer:GiveSkill(math.Rand(0.15, 0.3)) end
			killer:SetPData("zb_framed_killer_wins", (tonumber(killer:GetPData("zb_framed_killer_wins", 0)) or 0) + 1)
		else
			if killer.GiveSkill then killer:GiveSkill(-math.Rand(0.05, 0.1)) end
		end

		killer.FramedHoldUntil = nil
	end
end
--//
