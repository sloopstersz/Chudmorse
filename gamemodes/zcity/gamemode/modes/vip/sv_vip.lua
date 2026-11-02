if not SERVER then return end
local MODE = MODE
print("[Chudmorse] VIP ragdoll fix v2 loaded")
util.AddNetworkString("chud_vip_prepare")
util.AddNetworkString("chud_vip_loadout")
util.AddNetworkString("chud_vip_menu")
util.AddNetworkString("chud_vip_selection")
local function SendSelection(ply, ends)
    net.Start("chud_vip_selection")
    net.WriteFloat(ends)
    net.WriteString(ply:GetNWString("ChudVIPRole", ""))
    net.Send(ply)
end
resource.AddFile("sound/rem_president.mp3")

local function Participants()
    local result = {}
    for _, ply in player.Iterator() do
        if ply:Team() ~= TEAM_SPECTATOR then result[#result + 1] = ply end
    end
    return result
end

local function Points(group)
    if MODE.GetVIPPoints then return MODE:GetVIPPoints(group) end
    local result = {}
    for _, point in ipairs(zb.GetMapPoints(group) or {}) do
        if isvector(point.pos) then result[#result + 1] = point end
    end
    return result
end

function MODE:BuildRoute(shuffle)
    local pools = {}
    for stage = 1, 3 do
        pools[stage] = Points("President_Task" .. stage)
        if shuffle then table.Shuffle(pools[stage]) end
    end
    local route = {}
    local function Choose(stage)
        if stage == 4 then return true end
        for _, point in ipairs(pools[stage]) do
            local separate = true
            for previous = 1, stage - 1 do
                if route[previous].pos:DistToSqr(point.pos) < (MODE.HoldRadius * 2) ^ 2 then separate = false break end
            end
            if separate then
                route[stage] = point
                if Choose(stage + 1) then return true end
                route[stage] = nil
            end
        end
        return false
    end
    if Choose(1) then return route end
end

function MODE:IsMapAllowed()
    return #Points("President_Defenders") > 0 and #Points("President_Attackers") > 0 and self:BuildRoute(false) ~= nil
end
function MODE:CanLaunch()
    return #Participants() >= 3 and self:IsMapAllowed()
end

function MODE:PublishObjective()
    local point = self.Route and self.Route[self.Stage]
    SetGlobalInt("ChudVIPStage", self.Stage or 1)
    SetGlobalBool("ChudVIPHasObjective", point ~= nil)
    SetGlobalVector("ChudVIPObjective", point and point.pos or vector_origin)
    SetGlobalFloat("ChudVIPHoldEnd", self.HoldStarted and self.HoldStarted + self.HoldTime or 0)
    SetGlobalBool("ChudVIPContested", self.Contested or false)
end

local function EnterLoadoutSpectator(ply)
    -- KillPlayers() immediately respawns everyone; Spectate alone leaves them alive.
    if ply:Alive() then
        local deaths = ply:Deaths()
        ply:KillSilent()
        ply:SetDeaths(deaths)
    end
    local bodies = {ply.RagdollDeath, ply.FakeRagdoll,
        ply:GetNWEntity("RagdollDeath"), ply:GetNWEntity("FakeRagdoll")}
    for _, body in pairs(bodies) do
        if IsValid(body) and not body:IsPlayer() then
            body.hg_no_fullbody_remove_gib = true
            body.override = true
            body:SetNWEntity("ply", NULL)
            body:Remove()
        end
    end
    ply.RagdollDeath, ply.FakeRagdoll = nil, nil
    ply:SetNWEntity("RagdollDeath", NULL)
    ply:SetNWEntity("FakeRagdoll", NULL)
    if hg.ragdollFake then hg.ragdollFake[ply] = nil end
    ply:SetTeam(TEAM_SPECTATOR)
    ply:StripWeapons()
    ply:RemoveAllAmmo()
    ply:Freeze(false)
    ply.chosenSpectEntity, ply.lastSpectTarget = nil, nil
    ply.viewmode = 3
    ply:SetNWEntity("spect", NULL)
    ply:SetNWInt("viewmode", 3)
    ply:SpectateEntity(NULL)
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SetMoveType(MOVETYPE_NOCLIP)
    ply:SetNoDraw(true)
    ply:SetNotSolid(true)
end

function MODE:Intermission()
    game.CleanUpMap()
    for _, p in player.Iterator() do p.ChudVIPInPlay = nil end
    self.Players = Participants()
    self.Started = false
    self.LoadoutEnds = CurTime() + self.LoadoutDuration
    zb.START_TIME = self.LoadoutEnds
    SetGlobalFloat("ChudVIPLoadoutEnds", self.LoadoutEnds)
    table.Shuffle(self.Players)
    local assigned = ChudTakeNextModeRole and ChudTakeNextModeRole("vip", self.Players)
    if IsValid(assigned) then
        for i, ply in ipairs(self.Players) do
            if ply == assigned then
                self.Players[1], self.Players[i] = self.Players[i], self.Players[1]
                break
            end
        end
    end
    self.VIC = self.Players[1]
    self.Route = self:BuildRoute(true)
    self.Stage, self.HoldStarted, self.Contested = 1, nil, false
    self.Winner, self.EndAt = nil, nil
    SetGlobalInt("ChudVIPWinner", 0)
    SetGlobalFloat("ChudVIPEndAt", 0)
    SetGlobalEntity("ChudVIPVIC", IsValid(self.VIC) and self.VIC or NULL)
    SetGlobalString("ChudVIPVICName", IsValid(self.VIC) and self.VIC:Name() or "Unassigned")
    self:PublishObjective()
    local defenders, attackers = Points("President_Defenders"), Points("President_Attackers")
    if #self.Players < 3 or not self.Route or #defenders == 0 or #attackers == 0 then
        self.Winner = 3
        PrintMessage(HUD_PRINTTALK, "VIP Escort needs 3 players, defender/attacker spawns and 3 separate zpoint task locations.")
        return
    end
    local swatCount = math.max(1, math.floor((#self.Players - 1) / 3))
    for i, ply in ipairs(self.Players) do
        ply.ChudVIPLoadout = nil
        ply.ChudVIPChoices = nil
        ply.ChudVIPOriginalAppearance = ply.CurAppearance and table.Copy(ply.CurAppearance)
        EnterLoadoutSpectator(ply)
        ply:SetPlayerClass()
        ApplyAppearance(ply, nil, nil, nil, true)
        local defending = i <= swatCount + 1
        ply.ChudVIPTeam = defending and 1 or 0
        ply:SetTeam(TEAM_SPECTATOR)
        ply:SetNWBool("ChudVIPPreparing", true)
        ply:SetNWString("ChudVIPRole", i == 1 and "VIP" or defending and "Guard" or "Attacker")
        if i ~= 1 then ply:SetPlayerClass(defending and "swat" or "terrorist") end
        local pool = defending and defenders or attackers
        local spawn = pool[(i - 1) % #pool + 1]
        ply.ChudVIPSpawn = {pos = spawn.pos, ang = spawn.ang, offset = math.floor((i - 1) / #pool) + 1}
        ply:StripWeapons()
        ply:RemoveAllAmmo()
        ply:Freeze(false)
        ply:Spectate(OBS_MODE_ROAMING)
        ply:SetNoDraw(true)
        ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0), 0.4, 0)
    end
end

-- Apply weapons only at round start: selection cannot refill ammo or drop gear.
function MODE:GiveEquipment()
    if self.Winner then return end
    net.Start("chud_vip_prepare")
    net.WriteFloat(self.LoadoutEnds - self.LoadoutDuration)
    net.Broadcast()
    for _, ply in ipairs(self.Players or {}) do
        if IsValid(ply) then SendSelection(ply, self.LoadoutEnds) end
    end
end

local function GetOption(className, slotID, weaponClass)
    local class = ChudVIPClasses[className]
    for _, option in ipairs(class and class[slotID] or {}) do
        if option.class == weaponClass then return option end
    end
end

net.Receive("chud_vip_loadout", function(len, ply)
    if len > 8192 or not IsValid(ply) then return end
    local round = CurrentRound()
    if not round or round.name ~= "vip" or zb.ROUND_STATE ~= 0 then return end
    if round.Winner or not round.LoadoutEnds or CurTime() >= round.LoadoutEnds then return end
    if not ply:GetNWBool("ChudVIPPreparing", false) or not table.HasValue(round.Players or {}, ply) or ply == round.VIC then return end
    if CurTime() < (ply.ChudVIPNextChoice or 0) then return end
    ply.ChudVIPNextChoice = CurTime() + 0.1
    local className = net.ReadString()
    if not ChudVIPClassAllowed(ply, className) then return end
    local count = net.ReadUInt(4)
    if count > #ChudVIPLoadoutSlots then return end
    local choices, taken, seen = {}, {}, {}
    for i = 1, count do
        local slot, weaponClass = net.ReadString(), net.ReadString()
        if seen[slot] or taken[weaponClass] or not GetOption(className, slot, weaponClass) then return end
        seen[slot], taken[weaponClass], choices[slot] = true, true, weaponClass
    end
    ply.ChudVIPLoadout, ply.ChudVIPChoices = className, choices
end)

function MODE:EquipLoadout(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    ply:StripWeapons()
    ply:RemoveAllAmmo()
    local class
    if ply == self.VIC then
        class = ChudVIPFixedVIP
    else
        local key = ply.ChudVIPLoadout
        if not ChudVIPClassAllowed(ply, key) then key = ChudVIPClassesFor(ply)[1] end
        class = ChudVIPClasses[key]
    end
    if not class then return end
    local given = {}
    for _, weaponClass in ipairs(class.weapons or {}) do
        if not given[weaponClass] then
            local weapon = ply:Give(weaponClass)
            if IsValid(weapon) then
                given[weaponClass] = weapon
                local clip, ammo = weapon:GetMaxClip1(), weapon:GetPrimaryAmmoType()
                if clip > 0 then weapon:SetClip1(clip) end
                if clip > 0 and ammo >= 0 then ply:GiveAmmo(clip * 3, ammo, true) end
                local attachments = (class.attachments or {})[weaponClass]
                if attachments then
                    timer.Simple(0.5, function()
                        if CurrentRound() ~= self or not IsValid(ply) or not ply:Alive() or not IsValid(weapon) or weapon:GetOwner() ~= ply then return end
                        for _, attachment in ipairs(attachments) do hg.AddAttachmentForce(ply, weapon, attachment) end
                    end)
                end
            end
        elseif weaponClass == "weapon_tourniquet" then
            -- SWEPs cannot be held twice; supply the second after successful use.
            given[weaponClass]:CallOnRemove("ChudVIPSpareTourniquet", function(used)
                if not used.modeValues or used.modeValues[1] ~= 0 or used:GetOwner() ~= ply then return end
                local org = ply.organism
                timer.Simple(0, function()
                    if CurrentRound() == self and zb.ROUND_STATE == 1 and IsValid(ply) and ply:Alive() and ply.organism == org then ply:Give("weapon_tourniquet") end
                end)
            end)
        end
    end
    for _, armor in ipairs(class.armor or {}) do hg.AddArmor(ply, armor) end
    ply:Give("weapon_hands_sh")
    ply:SelectWeapon("weapon_hands_sh")
end

function MODE:RoundStart()
    if self.Winner or self.Started then return end
    self.Started = true
    self.Deploying = true
    for _, ply in ipairs(self.Players or {}) do
        if IsValid(ply) and ply.ChudVIPSpawn then
        local deployed, deployError = pcall(function()
            local spawn = ply.ChudVIPSpawn
            ply.ChudSpectating = nil
            ply.chosenSpectEntity, ply.lastSpectTarget = nil, nil
            ply:SetNWEntity("spect", NULL)
            ply:SetNWInt("viewmode", 3)
            ply:UnSpectate()
            ply:SetNotSolid(false)
            ply:SetupTeam(ply.ChudVIPTeam or 0)
            ply:Spawn()
            ply.ChudVIPInPlay = true -- deployed: respawn hooks must leave them alone
            ply:SetMoveType(MOVETYPE_WALK)
            ply:SetNoDraw(false)
            ply:SetNotSolid(false)
            ply:Freeze(false)
            ply:SetNWBool("ChudVIPPreparing", false)
            local roleClass = ply:GetNWString("ChudVIPRole")
            if roleClass == "Guard" or roleClass == "SWAT" then
                ply:SetPlayerClass("swat")
            elseif roleClass == "Attacker" then
                ply:SetPlayerClass("terrorist")
            else
                ply:SetPlayerClass()
                ApplyAppearance(ply, nil, nil, nil, true)
            end
            hg.tpPlayer(spawn.pos, ply, spawn.offset, 0)
            if isangle(spawn.ang) then ply:SetEyeAngles(spawn.ang) end
            self:EquipLoadout(ply)
            local role = ply:GetNWString("ChudVIPRole")
            zb.GiveRole(ply, role, ply.ChudVIPTeam == 1 and Color(60,130,255) or Color(190,35,35))
            ply:ScreenFade(SCREENFADE.IN, Color(0,0,0), 0.4, 0)
        end)
        if not deployed then
            ErrorNoHalt("[VIP] Failed to deploy " .. ply:Nick() .. ": " .. tostring(deployError) .. "\n")
        end
        end
    end
    self.Deploying = false
    self.EndAt = CurTime() + self.ROUND_TIME
    SetGlobalFloat("ChudVIPEndAt", self.EndAt)
    for _, ply in ipairs(self.Players or {}) do if IsValid(ply) then ply:Freeze(false) end end
end

local function Standing(ply)
    return IsValid(ply) and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR
        and not ply:GetNetVar("handcuffed", false)
        and not (ply.organism and (ply.organism.incapacitated or ply.organism.otrub))
end

function MODE:InObjective(ply, point)
    if not Standing(ply) or ply:GetPos():DistToSqr(point.pos) > self.HoldRadius ^ 2 then return false end
    return not util.TraceLine({start = ply:WorldSpaceCenter(), endpos = point.pos + Vector(0, 0, 32), mask = MASK_SOLID_BRUSHONLY, filter = ply}).Hit
end

function MODE:ShouldRoundEnd()
    if self.Winner then return true end
    if not IsValid(self.VIC) or not self.VIC:Alive() or self.VIC:Team() ~= 1 then self.Winner = 2 return true end
    local attackersAlive = false
    for _, ply in ipairs(self.Players or {}) do
        if IsValid(ply) and ply:Alive() and ply:Team() == 0 then attackersAlive = true break end
    end
    if not attackersAlive then self.Winner = 1 return true end
    if self.EndAt and CurTime() >= self.EndAt then self.Winner = 2 return true end
    return false -- This mode owns its timer, starting after the intro.
end

function MODE:RoundThink()
    for _, ply in ipairs(self.Players or {}) do
        if IsValid(ply) and ply.ChudVIPInPlay and not ply:Alive() then ply.ChudVIPInPlay = nil end
    end
    if self:ShouldRoundEnd() then return end
    local point = self.Route and self.Route[self.Stage]
    if not point then self.Winner = 3 return end
    local contested = false
    for _, ply in ipairs(self.Players or {}) do
        if IsValid(ply) and ply:Team() == 0 and self:InObjective(ply, point) then contested = true break end
    end
    local wasHolding, wasContested = self.HoldStarted, self.Contested
    self.Contested = contested
    if self:InObjective(self.VIC, point) and not contested then
        self.HoldStarted = self.HoldStarted or CurTime()
        if CurTime() - self.HoldStarted >= self.HoldTime then
            self.Stage = self.Stage + 1
            self.HoldStarted = nil
            if self.Stage > 3 then self.Winner = 1 end
            self:PublishObjective()
            return
        end
    else
        self.HoldStarted = nil
    end
    if wasHolding ~= self.HoldStarted or wasContested ~= contested then self:PublishObjective() end
end

function MODE:EndRound()
    for _, p in player.Iterator() do p.ChudVIPInPlay = nil end
    if self.Winner == 1 and IsValid(self.VIC) and self.VIC:Alive() then
        local guardAlive = false
        for _, ply in ipairs(self.Players or {}) do
            if IsValid(ply) and ply ~= self.VIC and ply:Alive() then
                local role = ply:GetNWString("ChudVIPRole")
                if role == "Guard" or role == "SWAT" then guardAlive = true break end
            end
        end
        if not guardAlive then hook.Run("ChudAchievementPresidentAlone", self.VIC) end
    end
    SetGlobalInt("ChudVIPWinner", self.Winner or 3)
    SetGlobalBool("ChudVIPHasObjective", false)
    SetGlobalFloat("ChudVIPHoldEnd", 0)
    for _, ply in ipairs(self.Players or {}) do
        if IsValid(ply) then
            ply:Freeze(false)
            if ply:GetNWBool("ChudVIPPreparing", false) then
                ply:UnSpectate()
                ply:SetTeam(ply.ChudVIPTeam or 0)
                ply:SetNoDraw(false)
                ply:SetNotSolid(false)
            end
            ply:SetNWBool("ChudVIPPreparing", false)
            ply.ChudVIPSpawn = nil
            ply:SetNWString("ChudVIPRole", "")
            if ply.PlayerClassName == "swat" or ply.PlayerClassName == "terrorist" then ply:SetPlayerClass() end
            if ply.ChudVIPOriginalAppearance then
                ply.CurAppearance = ply.ChudVIPOriginalAppearance
                ply.ChudVIPOriginalAppearance = nil
            end
        end
    end
end
function MODE:CanSpawn() return self.Deploying == true end

-- Prep deaths and late joiners stay out until the next round.
function MODE:PlayerDeathThink() return false end
function MODE:PlayerSpawn(ply)
    -- Getting up from a ragdoll (hg.FakeUp) re-spawns the player with OverrideSpawn set.
    -- That is not a real spawn: it must never remove the player. The base gamemode does the same.
    if OverrideSpawn then return end
    if not self.Deploying and ply:GetNWBool("ChudVIPPreparing", false) then
        timer.Simple(0, function()
            if IsValid(ply) and CurrentRound() == self and not self.Deploying
                and ply:GetNWBool("ChudVIPPreparing", false) then
                EnterLoadoutSpectator(ply)
            end
        end)
        return
    end
    if zb.ROUND_STATE == 1 and not self.Deploying then
        -- Backup guard: anyone deployed and still alive stays. Only late joiners and the dead are removed.
        if ply.ChudVIPInPlay then return end
        timer.Simple(0, function()
            if IsValid(ply) and CurrentRound() == self and zb.ROUND_STATE == 1 and not ply.ChudVIPInPlay then
                print("[VIP] Removing " .. ply:Nick() .. " (spawned mid-round without being deployed)")
                ply:KillSilent()
            end
        end)
    end
end

-- A real death takes the player out of play, so a respawn afterwards is still blocked.
local function ChudVIPLeftPlay(ply)
    if IsValid(ply) then ply.ChudVIPInPlay = nil end
end
for _, name in ipairs({"PlayerDeath", "PlayerSilentDeath", "PostPlayerDeath", "DoPlayerDeath"}) do
    hook.Add(name, "ChudVIPLeftPlay", ChudVIPLeftPlay)
end

function MODE:ShowSpare1(ply)
    if not IsValid(ply) or not ply:GetNWBool("ChudVIPPreparing", false) or zb.ROUND_STATE~=0 then return end
    if not self.LoadoutEnds or CurTime()>=self.LoadoutEnds then return end
    SendSelection(ply, self.LoadoutEnds)
    return true
end
