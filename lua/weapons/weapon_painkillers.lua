if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_tpik_med_base"
SWEP.PrintName = "Painkillers"
SWEP.Instructions = "Can be used to relieve pain (thanks Mr. Obvious). RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/weapons/nmrih/items/phalanx/w_phalanx.mdl"
SWEP.WorldModelReal = "models/weapons/nmrih/items/phalanx/v_item_phalanx.mdl"
SWEP.WorldModelExchange = false
SWEP.WMSkin = 2
SWEP.WMSkinV = 2

SWEP.HideMeshBonesIdle = {
	"phalanx bottle",
	"bottle cap",
	"v_item_pill",
	"v_item_pill001",
	"v_item_pill002",
	"v_item_pill003",
	"v_item_pill004",
	"v_item_pill005",
}
SWEP.HideMeshBonesUse = {
	"phalanx bottle",
	"phalanx bottle2",
	"bottle cap",
	"v_item_pill",
	"v_item_pill001",
	"v_item_pill002",
	"v_item_pill003",
	"v_item_pill004",
	"v_item_pill005",
}

SWEP.HideMeshBones = SWEP.HideMeshBonesIdle

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_painpills")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_painpills.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

SWEP.setlh = true
SWEP.setrh = true

SWEP.HoldPos = Vector(1.5, -1, -0.5)
SWEP.HoldAng = Angle(0, 0, 0)

SWEP.offsetVec = Vector(0, 0, 0)
SWEP.offsetAng = Angle(0, 0, 0)

SWEP.lpos = Vector(0, 0, 0)
SWEP.lang = Angle(0, 0, 0)

SWEP.handPosOffset = Vector(0, 0, 0)
SWEP.handAngOffset = Angle(0, 0, 0)

SWEP.modeNames = {
	[1] = "painkiller"
}

SWEP.UseSpeed = 4
SWEP.CallbackTimeAdjust = 1.25

SWEP.AnimList = {
	["deploy"] = { "draw", 0.5, false },
	["use"] = { "pills", 3, false, false, function(self)
		if CLIENT then return end
		local target = IsValid(self.healTarget) and self.healTarget or self:GetOwner()
		self.healTarget = nil
		if not self:Heal(target) then
			self.healing = false
			self:PlayAnim("idle")
		end
	end },
	["idle"] = { "idle", 5, true }
}

SWEP.TimedHideBones = {
	["bottle cap"] = 1.85,
}
SWEP.TimedShowBones = {
	["phalanx bottle"] = 0.18,
	["bottle cap"] = 0.18,
	["v_item_pill"] = 0.18,
	["v_item_pill001"] = 0.18,
	["v_item_pill002"] = 0.18,
	["v_item_pill003"] = 0.18,
	["v_item_pill004"] = 0.18,
	["v_item_pill005"] = 0.18,
}

SWEP.TimedSounds = {
	{"weapons/tfa_nmrih/items/medpills_shake_01.wav", 0.1},
	{"weapons/tfa_nmrih/items/pills_lid_twist_01.wav", 0.85},
	{"weapons/tfa_nmrih/items/pills_lid_twist_01.wav", 1.35},
	{"weapons/tfa_nmrih/items/medpills_open_01.wav", 1.37},
	{"weapons/tfa_nmrih/items/pills_lid_twist_open_01.wav", 1.92},
	{"weapons/tfa_nmrih/items/pills_lid_twist_open_01.wav", 2.2},
}

SWEP.GarbageRemoveTime = 10

SWEP.modeValuesdef = {
	[1] = 1,
}

SWEP.showstats = false

SWEP.DeploySounds = {
	"weapons/tfa_nmrih/items/medpills_draw_01.wav",
	"weapons/tfa_nmrih/items/pills_draw_01.wav",
	"snd_jack_hmcd_pillsbounce.wav",
}
SWEP.FallSnd = "snd_jack_hmcd_pillsbounce.wav"

-- Custom bottle label: set SWEP.WMBottleMaterial to a material path. It replaces the
-- bottle's own material(s). They're found by name (phalanx/bottle/label, but not pills);
-- set SWEP.WMBottleMaterialIndex = {n, ...} instead if that picks the wrong ones.
local function BottleMaterialSlots(ent, wep)
	if wep.WMBottleMaterialIndex then return wep.WMBottleMaterialIndex end
	local slots = {}
	for i, name in ipairs(ent:GetMaterials() or {}) do
		local n = string.lower(name)
		if (n:find("phalanx", 1, true) or n:find("bottle", 1, true) or n:find("label", 1, true)) and not n:find("pill", 1, true) then
			slots[#slots + 1] = i - 1
		end
	end
	return slots
end

function SWEP:ApplyBottleMaterial(ent)
	if not self.WMBottleMaterial or not IsValid(ent) then return end
	local mdl = ent:GetModel()
	if ent._chudBottleMat == mdl then return end
	ent._chudBottleMat = mdl
	ent:SetSubMaterial()
	for _, slot in ipairs(BottleMaterialSlots(ent, self)) do
		ent:SetSubMaterial(slot, self.WMBottleMaterial)
	end
end

-- Bottle colour. Pill items pick a skin on the phalanx model with WMSkin/WMSkinV.
-- If the model doesn't have that skin, WMFallbackColor tints the bottle instead.
if CLIENT then
	function SWEP:DrawWorldModel2(prepareOnly)
		local base = weapons.GetStored("weapon_tpik_med_base")
		local tint = self.WMFallbackColor
		local mdl = self.worldModel
		if IsValid(mdl) then self:ApplyBottleMaterial(mdl) end
		local skin = IsValid(self:GetOwner()) and (self.WMSkinV or self.WMSkin or 0) or (self.WMSkin or 0)
		if prepareOnly or not tint or not IsValid(mdl) or skin < mdl:SkinCount() then
			return base.DrawWorldModel2(self, prepareOnly)
		end
		render.SetColorModulation(tint.r / 255, tint.g / 255, tint.b / 255)
		local ret = base.DrawWorldModel2(self, prepareOnly)
		render.SetColorModulation(1, 1, 1)
		return ret
	end

	-- Dev helper: hold any pill item and run  chud_pillskin <n>  to preview skins,
	-- or  chud_pillskin  on its own to print how many skins the bottle has.
	concommand.Add("chud_pillskin", function(ply, _, args)
		local wep = IsValid(ply) and ply:GetActiveWeapon()
		if not IsValid(wep) or not wep.IsChudPills then print("[chud_pillskin] hold a pill item first") return end
		local mdl = wep.worldModel
		local count = IsValid(mdl) and mdl:SkinCount() or "?"
		if not args[1] then
			print("[chud_pillskin] " .. wep:GetClass() .. " skin " .. tostring(wep.WMSkinV or wep.WMSkin) .. ", model has " .. count .. " skins (0-based)")
			if IsValid(mdl) then
				for i, name in ipairs(mdl:GetMaterials()) do print("  material slot " .. (i - 1) .. ": " .. name) end
			end
			return
		end
		local n = tonumber(args[1]) or 0
		wep.WMSkin, wep.WMSkinV = n, n
		if IsValid(mdl) then mdl:SetSkin(n) end
		print("[chud_pillskin] previewing skin " .. n .. " of " .. count)
	end)
end

SWEP.IsChudPills = true

function SWEP:CanPrimaryAttack()
	return true
end

function SWEP:InitAdd()
	self.modeValues = {
		[1] = 1
	}
end

function SWEP:Deploy()
	if self.DeploySounds and #self.DeploySounds > 0 then
		self.DeploySnd = self.DeploySounds[math.random(#self.DeploySounds)]
	end
	local snd = self.DeploySnd
	self.DeploySnd = ""
	local base = weapons.GetStored("weapon_tpik_med_base")
	if base and base.Deploy then
		local ret = base.Deploy(self)
		if SERVER and snd and not self._deploySndPlayed and self:GetOwner() and not self:GetOwner().noSound then
			self._deploySndPlayed = true
			self:GetOwner():EmitSound(snd, 65, math.random(95, 105))
		end
		return ret
	end
	return true
end

function SWEP:Holster()
	self._deploySndPlayed = false

	self.healTarget = nil
	if self.healing then
		self.healing = false
		self.callback = nil
		hook.Remove("Think", "AnimCallback" .. self:EntIndex())
		self.HideMeshBones = self.HideMeshBonesIdle
		self._wasInUse = false
	end
	return true
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() and self.NPCUsable ~= false then
		self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.wav")
		self:NPCHeal(owner, 0.2, "snd_jack_hmcd_pillsuse.wav")
		return
	end

	local base = weapons.GetStored("weapon_tpik_med_base")
	if base and base.OwnerChanged then base.OwnerChanged(self) end
end

local function GarbagePhysCallback(ent, data)
	if data.DeltaTime < 0.2 then return end
	ent:EmitSound(ent.FallSnd)
end

function SWEP:Think()
	if hg.SWEPEditor_Apply then hg.SWEPEditor_Apply(self) end

	local curTime = CurTime()
	local anim = self.anim

	local inUse = anim == "use" and self.animtime and self.animtime > curTime

	if not IsFirstTimePredicted() then return end

	if inUse ~= self._wasInUse then
		self._wasInUse = inUse
		if inUse then
			self._timedApplied = {}
			self._showApplied = {}
			self._soundIdx = 1

			if not self._timedSndCache and self.TimedSounds and #self.TimedSounds > 0 then
				local sorted = {}
				for i, data in ipairs(self.TimedSounds) do
					if data[1] ~= "" then
						sorted[#sorted + 1] = {data[1], data[2]}
					end
				end
				table.sort(sorted, function(a, b) return a[2] < b[2] end)
				self._timedSndCache = sorted
				self._timedSndCount = #sorted
			end

			self.HideMeshBones = table.Copy(self.HideMeshBonesUse)
		else
			self.HideMeshBones = self.HideMeshBonesIdle
		end
	end

	if inUse and self.animtime and self.animspeed then
		local elapsed = self.animspeed - (self.animtime - curTime)
		local changed

		if self.TimedHideBones then
			for bone, time in pairs(self.TimedHideBones) do
				if not self._timedApplied[bone] and elapsed >= time then
					self._timedApplied[bone] = true
					changed = true
					self.HideMeshBones = table.Copy(self.HideMeshBones)
					self.HideMeshBones[#self.HideMeshBones + 1] = bone
				end
			end
		end

		if self.TimedShowBones then
			for bone, time in pairs(self.TimedShowBones) do
				if not self._showApplied[bone] and elapsed >= time then
					self._showApplied[bone] = true
					if not changed then
						changed = true
						self.HideMeshBones = table.Copy(self.HideMeshBones)
					end
					local list = self.HideMeshBones
					for i = #list, 1, -1 do
						if list[i] == bone then
							table.remove(list, i)
							break
						end
					end
				end
			end
		end

		if self._timedSndCache then
			local idx = self._soundIdx or 1
			local cache = self._timedSndCache
			local count = self._timedSndCount
			while idx <= count and elapsed >= cache[idx][2] do
				local data = cache[idx]
				idx = idx + 1
				if CLIENT then
					local owner = self:GetOwner()
					if IsValid(owner) then
						owner:EmitSound(data[1], 60, math.random(95, 105), 1, CHAN_STATIC)
					end
				end
			end
			self._soundIdx = idx
		end
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if not self.healing and anim == "deploy" and self.animtime and self.animtime <= curTime then
		if SERVER then
			self:PlayAnim("idle")
		end
	end
end

function SWEP:PostSetHandPos()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local ent = hg.GetTPIKCharacter(ply)
	if not IsValid(ent) then return end

	local rhBone = ent:LookupBone("ValveBiped.Bip01_R_Hand")
	if rhBone then
		local mat = ent:GetBoneMatrix(rhBone)
		if mat then
			local pos = mat:GetTranslation() + self.handPosOffset
			local ang = mat:GetAngles()
			ang.p = ang.p + self.handAngOffset.p
			ang.y = ang.y + self.handAngOffset.y
			ang.r = ang.r + self.handAngOffset.r
			mat:SetTranslation(pos)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(rhBone, mat)
		end
	end

	if not self.lhandik then return end

	local lhBone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
	if lhBone then
		local mat = ent:GetBoneMatrix(lhBone)
		if mat then
			local pos = mat:GetTranslation()
			local offset = self.handPosOffset
			pos.x = pos.x - offset.x
			pos.y = pos.y - offset.y
			pos.z = pos.z + offset.z
			local ang = mat:GetAngles()
			ang.p = ang.p - self.handAngOffset.p
			ang.y = ang.y - self.handAngOffset.y
			ang.r = ang.r + self.handAngOffset.r
			mat:SetTranslation(pos)
			mat:SetAngles(ang)
			ent:SetBoneMatrix(lhBone, mat)
		end
	end
end

if SERVER then
	function SWEP:PrimaryAttack()
		if self.healing then return end
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		self.healTarget = nil
		self.healing = true
		self:PlayAnim("use", self.UseSpeed, false, nil, false)
	end

	-- RMB: feed pills to someone who is knocked down (same rule as the old Chudmorse painkillers)
	function SWEP:SecondaryAttack()
		if self.healing then return end
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local tr = hg.eyeTrace(owner)
		if not tr then return end
		local ent = tr.Entity
		if not IsValid(ent) then return end
		if hg.GetCurrentCharacter(ent) == hg.GetCurrentCharacter(owner) then return end

		if ent:IsNPC() then
			if self.NPCUsable == false then return end
			self:SpawnGarbage(nil, nil, "snd_jack_hmcd_foodbounce.wav")
			self:NPCHeal(ent, 0.2, "snd_jack_hmcd_pillsuse.wav")
			return
		end

		if not self:CanFeed(ent) then return end

		self.healTarget = ent
		self.healing = true
		self:PlayAnim("use", self.UseSpeed, false, nil, false)
	end

	-- Who RMB can give pills to. Default: someone who is knocked down.
	function SWEP:CanFeed(ent)
		local org = ent.organism
		return org and IsValid(org.owner) and IsValid(org.owner.FakeRagdoll)
	end

	-- Shared ending for every pill item: swallow sounds, drop the empty bottle, remove.
	function SWEP:FinishPills()
		local owner = self:GetOwner()
		self.healing = false
		if not IsValid(owner) then self:Remove() return end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		entOwner:EmitSound("weapons/tfa_nmrih/items/pills_enter_mouth_01.wav", 60, math.random(95, 105))
		timer.Simple(0.7, function()
			if not IsValid(entOwner) then return end
			local snd = math.random(2) == 1 and "weapons/tfa_nmrih/items/gulp_01.wav" or "weapons/tfa_nmrih/items/gulp_02.wav"
			entOwner:EmitSound(snd, 60, math.random(95, 105))
		end)

		self:DropGarbage()
		owner:SelectWeapon("weapon_hands_sh")
		self:Remove()
		return true
	end

	function SWEP:DropGarbage()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local chr = hg.GetCurrentCharacter(owner)
		if not IsValid(chr) then return end

		local boneid = chr:LookupBone("ValveBiped.Bip01_R_Hand")
		if not boneid then return end

		local matrix = chr:GetBoneMatrix(boneid)
		if not matrix then return end

		local ent = ents.Create("prop_physics")
		if not IsValid(ent) then return end
		ent:SetModel(self.WorldModel)
		ent:SetPos(matrix:GetTranslation())
		ent:SetAngles(matrix:GetAngles())
		ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		ent:Spawn()
		ent:Activate()
		ent:SetSkin(self.WMSkin or 0)
		self:ApplyBottleMaterial(ent)
		if self.WMFallbackColor and (self.WMSkin or 0) >= ent:SkinCount() then ent:SetColor(self.WMFallbackColor) end

		ent.FallSnd = Sound(self.FallSnd)

		ent:AddCallback("PhysicsCollide", GarbagePhysCallback)

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocity(owner:GetAimVector() * 150 + VectorRand(-20, 20))
			phys:AddAngleVelocity(VectorRand(-50, 50))
		end

		SafeRemoveEntityDelayed(ent, self.GarbageRemoveTime)
	end

	function SWEP:Heal(ent)
		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()
		if not IsValid(owner) then return end
		if ent ~= owner and not (IsValid(org.owner) and IsValid(org.owner.FakeRagdoll)) then return end
		if not org.analgesiaAdd then return end

		local mode = self.modeValues and self.modeValues[1] or self.modeValuesdef[1]

		org.analgesiaAdd = math.min((org.analgesiaAdd or 0) + mode * 0.4, 4)

		return self:FinishPills()
	end
end
