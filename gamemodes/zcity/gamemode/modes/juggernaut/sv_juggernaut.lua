if not SERVER then return end
local MODE = MODE

local survivorWeapons = {
	"weapon_hk_usp",
	"weapon_makarov",
	"weapon_revolver2",
	"weapon_pl15",
	"weapon_m1911",
	"weapon_fn45",
	"weapon_tec9",
	"weapon_p22",
	"weapon_cz75",
	"weapon_flintlock",
	"weapon_doublebarrel_short",
	"weapon_toz106",
	"weapon_mac11",
	"weapon_skorpion",
	"weapon_ruger",
}


util.AddNetworkString("rem_juggernaut_intro")
util.AddNetworkString("rem_juggernaut_end")
resource.AddFile("sound/rem_juggernaut.mp3")
resource.AddFile("models/arty/codmw2022/mp/dmz/alqatala/juggernaut/juggernaut_pm.mdl")

local function AddMaterials(directory)
	local files, folders = file.Find(directory .. "/*", "GAME")
	for _, name in ipairs(files) do
		if string.GetExtensionFromFilename(name) == "vmt" or string.GetExtensionFromFilename(name) == "vtf" then
			resource.AddFile(directory .. "/" .. name)
		end
	end
	for _, name in ipairs(folders) do
		AddMaterials(directory .. "/" .. name)
	end
end
AddMaterials("materials/arty/codmw2022/mp/dmz/alqatala/juggernaut")
AddMaterials("materials/arty/codmw2022/shared")

-- Models that are not precached can fail util.IsValidModel on the server, which skipped SetModel.
local function JuggernautModelAvailable(mode)
	util.PrecacheModel(mode.JuggernautModel)
	return util.IsValidModel(mode.JuggernautModel) or file.Exists(mode.JuggernautModel, "GAME")
end

local function ApplyJuggernautLook(mode, ply)
	if not IsValid(ply) then return end
	if mode.JuggernautModelOK and string.lower(ply:GetModel() or "") ~= string.lower(mode.JuggernautModel) then
		ply:SetModel(mode.JuggernautModel)
	end
	ply:SetBodyGroups("000000000000")
	ply:SetSubMaterial()
	ply:SetNetVar("Accessories", "none")
	ply:SetNetVar("AccessoryColors", {})
	ply:SetNWString("BandageGlovesMdl", "")
	ply:SetPlayerColor(Vector(1, 1, 1))
	ply:SetNWVector("PlayerColor", Vector(1, 1, 1))
	-- Verified in the supplied MDL: group 11, value 1 is the empty mesh.
	ply:SetBodygroup(11, 1)
end

-- The appearance system can re-apply the player's normal model after GiveEquipment runs.
-- Keep checking the Juggernaut and put the model back if anything changed it.
timer.Create("ChudJuggernautModelKeeper", 0.25, 0, function()
	local mode = CurrentRound()
	if not mode or mode.name ~= "juggernaut" or not mode.JuggernautModelOK then return end
	if zb.ROUND_STATE ~= 0 and zb.ROUND_STATE ~= 1 then return end
	local jug = mode.Juggernaut
	if not IsValid(jug) or not jug:Alive() or jug:Team() == TEAM_SPECTATOR then return end
	if string.lower(jug:GetModel() or "") ~= string.lower(mode.JuggernautModel) then
		ApplyJuggernautLook(mode, jug)
	end
end)

local function Participants()
	local result = {}
	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then result[#result + 1] = ply end
	end
	return result
end

function MODE:CanLaunch()
	return #Participants() >= 2
end

function MODE:Intermission()
	game.CleanUpMap()
	self.Winner = nil
	self.MissingModelWarning = nil
	self.JuggernautModelOK = nil
	self.Players = Participants()
	table.Shuffle(self.Players)
    local assigned = ChudTakeNextModeRole and ChudTakeNextModeRole("juggernaut", self.Players)
    if IsValid(assigned) then
        for i, ply in ipairs(self.Players) do
            if ply == assigned then
                self.Players[1], self.Players[i] = self.Players[i], self.Players[1]
                break
            end
        end
    end
	self.Juggernaut = self.Players[1]
	for i, ply in ipairs(self.Players) do
		ply:SetPlayerClass()
		ApplyAppearance(ply)
		ply:SetupTeam(i == 1 and 1 or 0)
		ply:Freeze(false) -- Preparation holds movement without freezing view angles.
	end
end

function MODE:GiveEquipment()
	for _, ply in ipairs(self.Players or {}) do
		if IsValid(ply) and ply:Alive() then
			local isJuggernaut = ply == self.Juggernaut
			ply:StripWeapons()
			ply:RemoveAllAmmo()
			local hands = hg.GetHandsWeaponClass and hg.GetHandsWeaponClass(ply) or "weapon_hands_sh"
			ply:Give(hands)
			ply:SelectWeapon(hands)
			ply:SetMaxHealth(isJuggernaut and 350 or 100)
			ply:SetHealth(ply:GetMaxHealth())
			zb.GiveRole(ply, isJuggernaut and "Juggernaut" or "Scared Chud", Color(190, 30, 30))
			if isJuggernaut then
				ply:SetPlayerClass("chud_juggernaut")
				self.JuggernautModelOK = JuggernautModelAvailable(self)
				if not self.JuggernautModelOK and not self.MissingModelWarning then
					self.MissingModelWarning = true
					local message = "[Juggernaut] Missing model: " .. self.JuggernautModel
					ErrorNoHalt(message .. "\n")
					ply:ChatPrint(message .. ". Install the model content on the server and clients.")
				end
				ApplyJuggernautLook(self, ply)
			end
			if isJuggernaut then
				local inv = ply:GetNetVar("Inventory", {})
				inv.Weapons = inv.Weapons or {}
				inv.Weapons.hg_sling = true
				ply:SetNetVar("Inventory", inv)
				for _, armor in ipairs({
					"ent_armor_vest5",
					"ent_armor_mask1",
					"ent_armor_headphones1",
					"ent_armor_helmet5",
				}) do
					hg.AddArmor(ply, armor)
				end
				for _, class in ipairs({ "weapon_pkm", "weapon_deagle_annihilator" }) do
					local weapon = ply:Give(class)
					if IsValid(weapon) then
						local clip = weapon:GetMaxClip1()
						local ammo = weapon:GetPrimaryAmmoType()
						if clip > 0 then weapon:SetClip1(clip) end
						if clip > 0 and ammo >= 0 then ply:GiveAmmo(clip * 3, ammo, true) end
					end
				end
				for _, class in ipairs({
					"weapon_hg_pipebomb_tpik",
					"weapon_bigbandage_sh",
					"weapon_betablock",
					"weapon_medkit_sh",
					"weapon_fentanyl",
				}) do
					ply:Give(class)
				end
			else
				local inv = ply:GetNetVar("Inventory", {})
				inv.Weapons = inv.Weapons or {}
				inv.Weapons.hg_sling = true
				ply:SetNetVar("Inventory", inv)
				local class = survivorWeapons[math.random(#survivorWeapons)]
				local weapon = ply:Give(class, true)
				if IsValid(weapon) then
					local clip, ammo = weapon:GetMaxClip1(), weapon:GetPrimaryAmmoType()
					-- One loaded magazine plus two spare magazines.
					if clip > 0 then weapon:SetClip1(clip) end
					if clip > 0 and ammo >= 0 then ply:SetAmmo(clip * 2, ammo) end
					ply:SelectWeapon(class)
				end
				ply:Give("weapon_medkit_sh")
			end
			net.Start("rem_juggernaut_intro")
			net.WriteBool(isJuggernaut)
			net.WriteFloat(self.IntroDuration or 8)
			net.Send(ply)
		end
	end
	-- Start on the next engine tick instead of waiting for the round polling timer.
	timer.Simple(0, function()
		if CurrentRound() == self and zb.ROUND_STATE == 0 then zb:RoundStart() end
	end)
end

function MODE:RoundStart()
	for _, ply in ipairs(self.Players or {}) do
		if IsValid(ply) then ply:Freeze(false) end
	end
end

function MODE:CheckAlivePlayers()
	local sides = { {}, {} }
	for _, ply in ipairs(self.Players or {}) do
		if
			IsValid(ply)
			and ply:Team() ~= TEAM_SPECTATOR
			and ply:Alive()
			and not ply:GetNetVar("handcuffed", false)
			and not (ply.organism and ply.organism.incapacitated)
		then
			local side = ply == self.Juggernaut and 1 or 2
			sides[side][#sides[side] + 1] = ply
		end
	end
	return sides
end

function MODE:ShouldRoundEnd()
	local ended, winner = zb:CheckWinner(self:CheckAlivePlayers())
	if ended then self.Winner = winner end
	return ended
end

function MODE:EndRound()
	hook.Run("ChudAchievementJuggernautResult", self.Juggernaut, self.Winner)
	for _, ply in ipairs(self.Players or {}) do
		if IsValid(ply) then
			ply:Freeze(false)
			if ply.PlayerClassName == "chud_juggernaut" then ply:SetPlayerClass() end
			ply:SetMaxHealth(100)
			if ply:Alive() then ply:SetHealth(math.min(ply:Health(), 100)) end
		end
	end
	net.Start("rem_juggernaut_end")
	net.WriteUInt(self.Winner or 3, 2)
	net.Broadcast()
end

-- Registered by Chudmorse's mode loader; never runs for other gamemodes.
function MODE:PreHomigradDamage(ply, damage)
	if IsValid(ply) and ply == self.Juggernaut then damage:ScaleDamage(0.3) end
end

function MODE:CanSpawn()
	return false
end
function MODE:RoundThink() end
