if not SERVER then return end
local MODE = MODE
util.AddNetworkString("HL2TDMVote")
util.AddNetworkString("HL2TDMState")
util.AddNetworkString("HL2TDMIntro")

local function Active()
    local mode = CurrentRound()
    return mode and mode.name == "hl2tdm" and mode
end

function MODE:SendState(target)
    net.Start("HL2TDMState")
    net.WriteBool(self.VoteInProgress == true)
    net.WriteFloat(self.VoteEnd or 0)
    net.WriteUInt(self.SelectedScenario or 0, 3)
    for i = 1, 4 do net.WriteUInt(self.VoteResults[i] or 0, 16) end
    if target then net.Send(target) else net.Broadcast() end
end

function MODE:RecountVotes()
    self.VoteResults = {0, 0, 0, 0}
    for ply, choice in pairs(self.Votes or {}) do
        if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR and self.Scenarios[choice] then
            self.VoteResults[choice] = self.VoteResults[choice] + 1
        end
    end
end

function MODE:Intermission()
    game.CleanUpMap()
    self.Votes, self.VoteResults = {}, {0, 0, 0, 0}
    self.SelectedScenario, self.Equipped = nil, false
    self.VoteInProgress = true
    self.VoteEnd = CurTime() + self.VoteTime
    self.Participants = {}
    SetGlobalInt("HL2TDMScenario", 0)
    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then
            self.Participants[ply] = true
            if ply:Alive() then ply:KillSilent() end
        end
    end
    self:SendState()
end

function MODE:EndVoting()
    if not self.VoteInProgress then return end
    self:RecountVotes()
    local best, choices = -1, {}
    for i = 1, 4 do
        local count = self.VoteResults[i]
        if count > best then best, choices = count, {i}
        elseif count == best then choices[#choices + 1] = i end
    end
    self.SelectedScenario = choices[math.random(#choices)]
    self.VoteInProgress = false
    SetGlobalInt("HL2TDMScenario", self.SelectedScenario)
    self:SendState()
    local voteEnd = self.VoteEnd
    timer.Simple(3, function()
        if Active() ~= self or self.VoteEnd ~= voteEnd or zb.ROUND_STATE == 2 then return end
        self:GiveEquipment()
    end)
end

net.Receive("HL2TDMVote", function(_, ply)
    local choice = net.ReadUInt(3)
    local mode = Active()
    if not mode or not mode.VoteInProgress or CurTime() >= mode.VoteEnd then return end
    if not IsValid(ply) or ply:IsBot() or not mode.Participants[ply] or ply:Team() == TEAM_SPECTATOR then return end
    if not mode.Scenarios[choice] or (ply.HL2TDMNextVote or 0) > CurTime() then return end
    ply.HL2TDMNextVote = CurTime() + 0.2
    mode.Votes[ply] = choice
    mode:RecountVotes()
    mode:SendState()
end)

-- Runs during intermission too; does not depend on the combat RoundThink hook.
hook.Add("Think", "HL2TDMVoteClock", function()
    local mode = Active()
    if mode and mode.VoteInProgress and CurTime() >= mode.VoteEnd then mode:EndVoting() end
end)
hook.Add("PlayerDisconnected", "HL2TDMVoteDisconnect", function(ply)
    local mode = Active()
    if not mode or not mode.VoteInProgress then return end
    mode.Votes[ply] = nil
    mode:RecountVotes()
    mode:SendState()
end)

local function GiveGun(ply, class)
    local weapon = ply:Give(class)
    if not IsValid(weapon) then return end
    local clip, ammo = weapon:GetMaxClip1(), weapon:GetPrimaryAmmoType()
    if clip > 0 and ammo >= 0 then
        weapon:SetClip1(clip)
        ply:GiveAmmo(clip * 3, ammo, true)
    end
end

function MODE:GiveEquipment()
    if self.VoteInProgress or not self.SelectedScenario or self.Equipped then return end
    self.Equipped = true
    local players = {}
    for ply in pairs(self.Participants or {}) do
        if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR then players[#players + 1] = ply end
    end
    table.Shuffle(players)
    local friendlyCount = math.ceil(#players / 2)
    for i, ply in ipairs(players) do
        local side = i <= friendlyCount and 0 or 1
        ply:SetTeam(side)
        ply:Spawn()
        ply:SetupTeam(side)
        ply:StripWeapons()
        ply:RemoveAllAmmo()
        ply.subClass, ply.leader = nil, nil
        ply:Give("weapon_hands_sh")
        local role
        if side == 1 then
            role = self.SelectedScenario == 2 and "Civil Protection" or "Combine"
            ply:SetPlayerClass(self.SelectedScenario == 2 and "Metrocop" or "Combine", {})
        elseif self.SelectedScenario == 1 then
            role = "National Guard"
            ply:SetPlayerClass("nationalguard", {})
            GiveGun(ply, "weapon_m4a1")
            GiveGun(ply, "weapon_hk_usp")
            ply:Give("weapon_medkit_sh")
        elseif self.SelectedScenario == 2 then
            role = "Refugee"
            ply:SetPlayerClass("Refugee", {})
        elseif self.SelectedScenario == 4 and i == 1 then
            role = "Freeman"
            ply:SetPlayerClass("Gordon", {equipment = "rebel"})
        else
            role = "Rebel"
            ply:SetPlayerClass("Rebel", {})
        end
        ply:SetTeam(side)
        ply:SetNWString("HL2TDMRole", role)
        zb.GiveRole(ply, role, side == 1 and Color(80, 190, 230) or Color(230, 145, 60))
        ply:SelectWeapon("weapon_hands_sh")
        net.Start("HL2TDMIntro")
        net.WriteUInt(self.SelectedScenario, 3)
        net.WriteUInt(side, 1)
        net.WriteString(role)
        net.Send(ply)
    end
end

function MODE:RoundStart()
    self:EndVoting()
    self:GiveEquipment()
end
function MODE:GetTeamSpawn()
    return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T")), zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT"))
end
function MODE:CheckAlivePlayers()
    local alive = {{}, {}}
    for _, ply in player.Iterator() do
        local side = ply:Team()
        if self.Participants and self.Participants[ply] and (side == 0 or side == 1)
            and ply:Alive() and not (ply.organism and ply.organism.incapacitated)
            and not ply:GetNetVar("handcuffed", false) then
            table.insert(alive[side + 1], ply)
        end
    end
    return alive
end
function MODE:ShouldRoundEnd()
    if self.VoteInProgress or not self.Equipped then return false end
    local alive = self:CheckAlivePlayers()
    return #alive[1] == 0 or #alive[2] == 0
end
function MODE:EndRound()
    self.VoteInProgress = false
    local alive = self:CheckAlivePlayers()
    local scenario = self.Scenarios[self.SelectedScenario or 3]
    local winner = #alive[1] > 0 and scenario.opposition or #alive[2] > 0 and (self.SelectedScenario == 2 and "Civil Protection" or "Combine") or "Nobody"
    PrintMessage(HUD_PRINTTALK, "Half-Life 2 TDM: " .. winner .. " wins.")
    self:SendState()
end
function MODE:CanLaunch() return true end
function MODE:RoundThink() end
function MODE:CanSpawn() return false end
function MODE:GetPlySpawn() end
function MODE:PlayerDeath() end

-- Block the generic pre-round respawn keys while the scenario vote is on screen.
function MODE:PlayerDeathThink(ply)
    if self.VoteInProgress or (not self.Equipped and zb.ROUND_STATE == 0) then return false end
end
hook.Add("PlayerInitialSpawn", "HL2TDMSyncVote", function(ply)
    timer.Simple(2, function()
        local mode = Active()
        if mode and mode.VoteResults and IsValid(ply) then mode:SendState(ply) end
    end)
end)
