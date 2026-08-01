SWEP.Base = "weapon_m4super"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "AWM"
SWEP.Author = "Accuracy International"
SWEP.Instructions = "Bolt-action Sniper Rifle chambered in .338 Lapua Magnum"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_awp.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_ur_aw.mdl"
SWEP.FakeAttachment = "2"
SWEP.FakeBodyGroups = "0112001141"
SWEP.FakeBodyGroupsPresets = {
    "0112001141"
}

SWEP.FakePos = Vector(-9, 3.5, 6)
SWEP.FakeAng = Angle(-0.2, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0.1,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.stupidgun = true

SWEP.FakeReloadSounds = {
	[0.2] = "weapons/universal/uni_crawl_l_03.wav",
	[0.3] = "weapons/arccw_ur/aw/magrel.ogg",
	[0.35] = "weapons/arccw_ur/aw/magout.ogg",
	[0.55] = "weapons/universal/uni_crawl_l_03.wav",
	[0.6] = "weapons/arccw_ur/aw/magin.ogg",
	[0.75] = "weapons/arccw_ur/aw/magtap.ogg",
	[0.9] = "weapons/universal/uni_crawl_l_04.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.2] = "weapons/universal/uni_crawl_l_03.wav",
	[0.3] = "weapons/arccw_ur/aw/magrel.ogg",
	[0.35] = "weapons/arccw_ur/aw/magout_empty.ogg",
	[0.55] = "weapons/universal/uni_crawl_l_03.wav",
	[0.6] = "weapons/arccw_ur/aw/magin.ogg",
	[0.75] = "weapons/arccw_ur/aw/magtap.ogg",
	[0.9] = "weapons/universal/uni_crawl_l_04.wav",
}

local math = math
local math_random = math.random
SWEP.AnimsEvents = {
	["cycle"] = {
		[0.05] = function(self)
			self:EmitSound("weapons/arccw_ur/aw/boltup.ogg", 45, math_random(110, 115))
		end,
		[0.15] = function(self)
			self:EmitSound("weapons/arccw_ur/aw/boltback.ogg", 45, math_random(110, 115))
		end,
		[0.25] = function(self)
			self:EmitSound("weapons/arccw_ur/aw/boltforward.ogg", 45, math_random(110, 115))
		end,
		[0.3] = function(self)
			if !self.noeject then
				self:RejectShell(self.ShellEject)
			else
				self.noeject = false
			end
		end,
		[0.45] = function(self)
			self:EmitSound("weapons/arccw_ur/aw/boltdown.ogg", 45, math_random(110, 115))
		end
	}
}

local vector_full = Vector(1,1,1)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.36] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,0,-50))
				self:GetWM():ManipulateBoneScale(51, vector_origin)
				self:GetWM():ManipulateBoneScale(52, vector_origin)
				self:GetWM():ManipulateBoneScale(53, vector_origin)
			end 
		end,
		[0.55] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(51, vector_full)
				self:GetWM():ManipulateBoneScale(52, vector_full)
				self:GetWM():ManipulateBoneScale(53, vector_full)
			end
		end,
	}
end

SWEP.EjectPos = Vector(4,15.5,-2.75)
SWEP.EjectAng = Angle(-145,90,0)
SWEP.MagModel = "models/kali/weapons/10rd m14 magazine.mdl"

SWEP.FakeMagDropBone = "vm_mag"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0.3,0)
SWEP.lmagang2 = Angle(0,0,0)
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 90

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload_magnum",
	["reload_empty"] = "reload_magnum",
	["cycle"] = "cycle",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2 = Material("entities/awm.png")
SWEP.IconOverride = "entities/awm.png"
SWEP.weight = 6.8
SWEP.weaponInvCategory = 1
SWEP.CustomShell = ".338Lapua"

SWEP.AutomaticDraw = false
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ".338 Lapua Magnum"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 180
SWEP.Primary.Force = 60
SWEP.Primary.Sound = {"weapons/arccw_ur/aw/338/fire-01.ogg", 65, 90, 100}
SWEP.attPos = Vector(0, 0, 0)
SWEP.attAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0,0)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.availableAttachments = {
	sight = {
		[1] = {"holo1", Vector(3, -1, -1.5), {}},
		[2] = {"holo2", Vector(3, -1, -1.5), {}},
		[3] = {"holo3", Vector(3, -1, -1.5), {}},
		[4] = {"holo4", Vector(2, -1, -1.5), {}},
		[5] = {"holo5", Vector(2, -1, -1.5), {}},
		[6] = {"holo5fur", Vector(2, -1, -1.5), {}},
		[7] = {"holo7", Vector(2, -1, -1.5), {}},
		[8] = {"holo8", Vector(2, -1, -1.5), {}},
		[9] = {"holo9", Vector(2, -1, -1.5), {}},
		[10] = {"holo11", Vector(2, -1, -1.5), {}},
		[11] = {"holo12", Vector(2, -1, -1.5), {}},
		[12] = {"holo13", Vector(2, -1, -1.5), {}},
		[13] = {"holo14", Vector(2, -1, -1.5), {}},
		[14] = {"holo15", Vector(3, -1, -0.5), {}},
		[15] = {"holo17", Vector(2, -1, -1.5), {}},
		[16] = {"optic2", Vector(0, 0, 0), {}},
		[17] = {"optic3", Vector(3, -1, -1.5), {}},
		[18] = {"optic6", Vector(0, -3, 0), {}},
		[19] = {"optic7", Vector(2, -1, -1.5), {}},
		[20] = {"optic8", Vector(2, -1, -1.5), {}},
		[21] = {"optic9", Vector(2, -1, -1.5), {}},
		[22] = {"optic14", Vector(2, -1, -1.5), {}},
		
		["mount"] = {picatinny = Vector(-2.5, 1, 2.6), ironsight = Vector(0.5, -1.8, 1)},
		["mountAngle"] = {["picatinny"] = Angle(0, 90, 90),["ironsight"] = Angle(0, 90, 90)},
		["mountType"] = {"picatinny", "ironsight"},
	},
	underbarrel = {
		[1] = {"laser5", Vector(0.0,0.4,0.2), {}},

		["mount"] = {["picatinny_small"] = Vector(13.45, 10, -3.55)},
		["mountAngle"] = {["picatinny_small"] = Angle(0, 90, 180)},
		["mountType"] = {"picatinny_small"},
		["removehuy"] = {
			["picatinny_small"] = {
			}
		}
	},
}

SWEP.StartAtt = {"ironsight1"}

SWEP.LocalMuzzlePos = Vector(35,0,3.2)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "muzzleflash_m79" -- shared in sh_effects.lu

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.15
SWEP.NumBullet = 1
SWEP.ReloadTime = 5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magout.wav",
	"none",
	"weapons/tfa_ins2/ak103/ak103_magoutrattle.wav",
	"weapons/tfa_ins2/ak103/ak103_magin.wav",
	"weapons/tfa_ins2/ak103/ak103_boltback.wav",
	"weapons/tfa_ins2/ak103/ak103_boltrelease.wav",
	"none",
	"none",
	"none"
}
SWEP.DeploySnd = {"homigrad/weapons/draw_hmg.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/hmg_holster.mp3", 55, 100, 110}
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.8636, 5.0264)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(-0.03, -0.04, 0), Angle(-0.05, 0.04, 0)}

SWEP.addSprayMul = 2
SWEP.RecoilMul = 1.8
SWEP.cameraShakeMul = 1
SWEP.ShockMultiplier = 1
SWEP.AnimShootMul = 1
SWEP.AnimShootHandMul = 1
SWEP.ShootAnimMul = 5

SWEP.Ergonomics = 0.85
SWEP.Penetration = 35
SWEP.ZoomFOV = 20
SWEP.WorldPos = Vector(5.5, -1, -1)
SWEP.WorldAng = Angle(0, 0, 2)
SWEP.UseCustomWorldModel = true
SWEP.handsAng = Angle(-2, -1, 0)
SWEP.scopemat = Material("decals/scope.png")
SWEP.perekrestie = Material("decals/perekrestie8.png", "smooth")
SWEP.localScopePos = Vector(-21, 3.95, -0.2)
SWEP.scope_blackout = 400
SWEP.maxzoom = 3.5
SWEP.rot = 37
SWEP.FOVMin = 3.5
SWEP.FOVMax = 10
SWEP.huyRotate = 25
SWEP.FOVScoped = 40

SWEP.DistSound = "weapons/tfa_ins2/sks/sks_dist.wav"

SWEP.lengthSub = 15


--local to head
SWEP.RHPos = Vector(3,-6.5,4)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(17,1.3,-3.4)
SWEP.LHAng = Angle(-110,-180,-5)

function SWEP:AnimHoldPost(model)
end

function SWEP:AnimationPost()
end

function SWEP:GetAnimPos_Insert(time)
	return 0
end

function SWEP:GetAnimPos_Draw(time)
	return 0
end

local function cock(self,time)
	if SERVER then
		self:Draw(true, true)
	end

	if self:Clip1() == 0 then
		self.drawBullet = nil
	end

	if CLIENT and LocalPlayer() == self:GetOwner() then return end

	net.Start("hgwep draw")
		net.WriteEntity(self)
		net.WriteBool(self.drawBullet)
		net.WriteFloat(CurTime())
	net.Broadcast()

	self.Primary.Next = CurTime() + self.AnimDraw + self.Primary.Wait

	local ply = self:GetOwner()

	self.reloadCoolDown = CurTime() + time
end


SWEP.GunCamPos = Vector(6,-12,-5)
SWEP.GunCamAng = Angle(190,-5,-95)

SWEP.FakeEjectBrassATT = "4"

function SWEP:Reload(time)
	--PrintTable(self:GetWM():GetAttachments())
	--print(self:GetNetVar("shootgunReload",0))
	local ply = self:GetOwner()
	--if ply.organism and (ply.organism.larmamputated or ply.organism.rarmamputated) then return end
	if self.AnimStart_Draw > CurTime() - 0.5 then return end
	if not self:CanUse() then return end
	if self.reloadCoolDown > CurTime() then return end
	if self.Primary.Next > CurTime() then return end
	if self:GetNetVar("shootgunReload",0) > CurTime() then return end

	if self.drawBullet == false and SERVER then
		cock(self,2)
		self:SetNetVar("shootgunReload",CurTime() + 1.3)
		self:PlayAnim(self.AnimList["cycle"] or "cycle", 2, false, nil, false, true)
		return
	end

	if not self:CanReload() then return end

	if SERVER then
		self:SetNetVar("shootgunReload",CurTime() + 1.1)
		self.LastReload = CurTime()
		self:ReloadStart()
		self:ReloadStartPost()
		local org = self:GetOwner().organism
		self.StaminaReloadMul = (org and ((2 - (self:GetOwner().organism.stamina[1] / 180)) + ((org.pain / 40) + (org.larm / 3) + (org.rarm / 5)) - (1 - math.Clamp(org.recoilmul or 1,0.45,1.4))) or 1)
		self.StaminaReloadMul = math.Clamp(self.StaminaReloadMul,0.65,2)
		self.StaminaReloadTime = self.ReloadTime * self.StaminaReloadMul
		self.StaminaReloadTime = (self.StaminaReloadTime + (self:Clip1() > 0 and -self.StaminaReloadTime/3 or 0 ))
		self.reload = self.LastReload + self.StaminaReloadTime
		self.dwr_reverbDisable = true
		self:PlayAnim(self.AnimList["reload"] or "reload", self.StaminaReloadTime, false, nil, false, true)
		net.Start("hgwep reload")
			net.WriteEntity(self)
			net.WriteFloat(self.LastReload)
			net.WriteInt(self:Clip1(),10)
			net.WriteFloat(self.StaminaReloadTime)
			net.WriteFloat(self.StaminaReloadMul)
		net.Broadcast()
	end
end

function SWEP:ReloadEnd()
	--if not self.CustomAmmoInsertEvent then
	self:InsertAmmo(self:GetMaxClip1() - self:Clip1() + (self.drawBullet ~= nil and not self.OpenBolt and 1 or 0))
	--end
	self.ReloadNext = CurTime() + self.ReloadCooldown --я хуй знает чо это
	if CLIENT and self.drawBullet == nil then
		self.noeject = true
	end
	if SERVER and self.drawBullet == nil then
		self:SetNetVar("shootgunReload",CurTime() + 1.3)
		self:PlayAnim(self.AnimList["cycle"] or "cycle", 2, false, nil, false, true)
	end

	self:Draw(nil,true)
end

function SWEP:CanPrimaryAttack()
	return not (self:GetNetVar("shootgunReload",0) > CurTime())
end

function SWEP:DrawPost()
end

function SWEP:PostSetupDataTables()
	self:NetworkVar("Int",0,"AWPSkin")
    self:NetworkVar("String",0,"RandomBodygroups")
    if ( CLIENT ) then
		self:NetworkVarNotify( "AWPSkin", self.OnVarChanged2 )
        self:NetworkVarNotify( "RandomBodygroups", self.OnVarChanged )
    end
end

function SWEP:OnVarChanged( name, old, new )
    if !IsValid(self:GetWM()) then return end
    self:GetWM():SetBodyGroups(new)
end

function SWEP:OnVarChanged2( name, old, new )
	if !IsValid(self:GetWM()) then return end

	self:GetWM():SetSkin(new)
end

function SWEP:InitializePost()
	self.AnimStart_Insert = 0
	self.AnimStart_Draw = 0

	local Skin = math.random(0,4)
	self:SetAWPSkin(Skin)
	self:SetRandomBodygroups(self.FakeBodyGroupsPresets[math.random(#self.FakeBodyGroupsPresets)])
end

function SWEP:ModelCreated(model)
	if self.AddModelCreated then
		self:AddModelCreated(model)
	end

	model:SetBodyGroups(self:GetRandomBodygroups())
	model:SetSkin(self:GetAWPSkin())
end

-- Inspect Assault
SWEP.InspectAnimWepAng = {
	Angle(0,0,0),
	Angle(4,4,15),
	Angle(10,15,25),
	Angle(10,15,25),
	Angle(10,15,25),
	Angle(-6,-15,-15),
	Angle(1,15,-45),
	Angle(15,25,-55),
	Angle(15,25,-55),
	Angle(15,25,-55),
	Angle(0,0,0),
	Angle(0,0,0)
}
