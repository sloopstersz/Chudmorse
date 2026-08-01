SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Gepárd GM6 Lynx"
SWEP.Author = "SERO"
SWEP.Instructions = "The GM6 uses a long-recoil system to fire the weapon, like a Remington Model 8. The barrel recoils with every shot, traveling with the bolt for a short period of time before coming back on its own. A unique feature is the caliber change option, where the caliber can be changed from .50 BMG to 12.7x108 mm"
SWEP.Category = "Weapons - Sniper Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_snip_g3sg1.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_uc_myt_gm6.mdl"
SWEP.FakeBodyGroups = "00000300"

SWEP.FakePos = Vector(-13, 4.5, 6.4)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(0.5,0.1,0.3)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeScale = 0.95
SWEP.FakeAttachment = "1"
SWEP.FakeEjectBrassATT = "2"

SWEP.FakeReloadSounds = {
	[0.3] = "weapons/myt_uc_gm6/magrel.ogg",
	[0.34] = "weapons/myt_uc_gm6/mag_out.ogg",
	[0.6] = "weapons/tfa_ins2/universal/uni_weapon_draw.wav",
	[0.66] = "weapons/myt_uc_gm6/magplace.ogg",
	[0.72] = "weapons/myt_uc_gm6/magin.ogg",
	[0.8] = "weapons/myt_uc_gm6/mag_hit.ogg",
}

SWEP.FakeEmptyReloadSounds = {
	[0.25] = "weapons/myt_uc_gm6/magrel.ogg",
	[0.3] = "weapons/myt_uc_gm6/mag_out.ogg",
	[0.42] = "weapons/tfa_ins2/universal/uni_weapon_draw.wav",
	[0.6] = "weapons/myt_uc_gm6/magplace.ogg",
	[0.65] = "weapons/myt_uc_gm6/magin.ogg",
	[0.7] = "weapons/myt_uc_gm6/mag_hit.ogg",
	[0.8] = "weapons/myt_uc_gm6/chgrab.ogg",
	[0.82] = "weapons/myt_uc_gm6/chback.ogg",
	[0.88] = "weapons/myt_uc_gm6/chforward.ogg",
}
SWEP.MagModel = "models/weapons/arccw/c_uc_myt_gm6.mdl"

SWEP.FakeMagDropBone = "W_Mag"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,0)
SWEP.lmagang2 = Angle(0,0,0)
SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_UpperArm"
SWEP.ViewPunchDiv = 40

local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.6] = function( self, timeMul )
			if self:Clip1() >= 1 then
			end
		end,
		[0.2] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(47, vector_origin)
				self:GetWM():ManipulateBoneScale(48, vector_origin)
			end 
		end,
		[0.45] = function( self, timeMul )
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(0,-20,10), "10322224", true )
				self:GetWM():ManipulateBoneScale(43, vector_origin)
				self:GetWM():ManipulateBoneScale(47, vector_origin)
				self:GetWM():ManipulateBoneScale(48, vector_origin)
			end 
		end,
		[0.5] = function( self, timeMul )
			if self:Clip1() < 1 then
				self:GetWM():ManipulateBoneScale(43, vector_full)
				self:GetWM():ManipulateBoneScale(47, vector_full)
				self:GetWM():ManipulateBoneScale(48, vector_full)
			end
		end,
	}
end

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}

SWEP.ScrappersSlot = "Primary"
SWEP.WepSelectIcon2box = false
SWEP.WepSelectIcon2 = Material("entities/gm6.png")
SWEP.IconOverride = "entities/gm6.png"
SWEP.weight = 11.5
SWEP.weaponInvCategory = 1
SWEP.CustomShell = "50cal"
SWEP.EjectPos = Vector(3,2.5,0)
SWEP.EjectAng = Angle(0,0,0)

SWEP.AutomaticDraw = true
SWEP.UseCustomWorldModel = false
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "12.7x108 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Spread = 0
SWEP.Primary.Damage = 180
SWEP.Primary.Force = 60
SWEP.Primary.Sound = {"weapons/myt_uc_gm6/fire-01.ogg", 70, 90, 100}
SWEP.availableAttachments = {
	sight = {
		["mount"] = { picatinny = Vector(-24.5, 2.1, -0.3)},
		["mountType"] = {"picatinny"},
	},
	underbarrel = {
		["mount"] = Vector(-8.8, -0.4, 0),
		["mountAngle"] = Angle(0, 0, 0),
		["mountType"] = "picatinny_small"
	},
}

SWEP.LocalMuzzlePos = Vector(25,1.2,1.5)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.PPSMuzzleEffect = "muzzleflash_m79" -- shared in sh_effects.lu

SWEP.ShockMultiplier = 1

SWEP.handsAng = Angle(0, 0, 0)
SWEP.handsAng2 = Angle(-3, 1, 0)

SWEP.Primary.Wait = 0.2
SWEP.NumBullet = 1
SWEP.AnimShootMul = 5
SWEP.AnimShootHandMul = 4
SWEP.ReloadTime = 5.5
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
SWEP.ZoomPos = Vector(10, 1.35, 5.2054)
SWEP.RHandPos = Vector(-8, -2, 6)
SWEP.LHandPos = Vector(6, -3, 1)
SWEP.AimHands = Vector(-10, 1.8, -6.1)
SWEP.SprayRand = {Angle(-0.03, -0.04, 0), Angle(-0.05, 0.04, 0)}

SWEP.addSprayMul = 2
SWEP.RecoilMul = 3
SWEP.cameraShakeMul = 1
SWEP.ShockMultiplier = 2
SWEP.AnimShootMul = 2
SWEP.AnimShootHandMul = 2
SWEP.ShootAnimMul = 5

SWEP.Ergonomics = 0.78
SWEP.Penetration = 35
SWEP.ZoomFOV = 1
SWEP.WorldPos = Vector(5.5, -1, -1)
SWEP.WorldAng = Angle(0, 0, 0)
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
SWEP.FOVScoped = 0

local vecZero = Vector(0, 0, 0)

SWEP.DistSound = "weapons/tfa_ins2/sks/sks_dist.wav"

SWEP.lengthSub = 15


--local to head
SWEP.RHPos = Vector(3,-6.5,4)
SWEP.RHAng = Angle(0,-12,90)
--local to rh
SWEP.LHPos = Vector(17,1.3,-3.4)
SWEP.LHAng = Angle(-110,-180,-5)

local lfang2 = Angle(-2, -35, -1)
local lfang21 = Angle(0, 35, 20)
local lfang1 = Angle(5, -15,-20)
local lfang0 = Angle(-0, -5, 0)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()
	--self:BoneSet("l_finger0", vec_zero, lfang0)

end

function SWEP:PrimaryShootPost()
	if CLIENT then
		if self:Clip1() < 1 then
			self:GetWM():ManipulateBoneScale(44, vecPochtiZero)
		end
	end
end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,(self:Clip1() < 1 and not self.reload) and 2.3 or self.ReloadSlideOffset)
		wep:ManipulateBonePosition(43,Vector(0 , 2.2*self.shooanim,0 ),false)
	end
end

-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1,7,-3),
	Vector(-7,15,-15),
	Vector(-7,15,-15),
	Vector(-1,7,-3),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	Vector(-1.5,1.5,-8),
	"fastreload",
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,0),
	Vector(0,0,2),
	Vector(8,1,2),
	Vector(8,2.5,-2),
	Vector(7,2.5,-2),
	Vector(6,2.5,-2),
	Vector(3,2.5,-2),
	Vector(3,2.5,-1),
	Vector(0,4,-1),
	"reloadend",
	Vector(0,5,0),
	Vector(-2,2,1),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-80,0,110),
	Angle(-20,0,110),
	Angle(-30,0,110),
	Angle(-20,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-20,0,45),
	Angle(-2,0,-3),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(0,0,0),
	Angle(20,-10,-20),
	Angle(20,0,-20),
	Angle(20,0,-20),
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-15,15,-17),
	Angle(-14,14,-22),
	Angle(-10,15,-24),
	Angle(12,14,-23),
	Angle(11,15,-20),
	Angle(12,14,-19),
	Angle(11,14,-20),
	Angle(7,9,-21),
	Angle(0,14,-21),
	Angle(0,15,-22),
	Angle(0,24,-23),
	Angle(0,25,-22),
	Angle(-15,24,-25),
	Angle(-15,25,-23),
	Angle(5,0,2),
	Angle(0,0,0),
}

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