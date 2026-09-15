SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = " SG 552 Commando"
SWEP.Author = "Swiss Arms AG"
SWEP.Instructions = "Automatic rifle chambered in 5.56×45 mm\n\nRate of fire 700 rounds per minute"
SWEP.Category = "Weapons - Assault Rifles"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_rif_sg552.mdl"
SWEP.WorldModelFake = "models/pwb/weapons/w_sg552.mdl"
SWEP.FakePos = Vector(-20, 6, 4)
SWEP.FakeAng = Angle(0, 0, 0)
SWEP.AttachmentPos = Vector(-565.5,-49,221.81)
SWEP.AttachmentAng = Angle(180,0,0)


SWEP.FakeEjectBrassATT = "2"
SWEP.FakeReloadSounds = {
	[0.4] = "pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	[0.9] = "pwb2/weapons/m4a1/ru-556 clip in 2.wav",
}
SWEP.DOZVUK = true

SWEP.FakeEmptyReloadSounds = {
	[0.4] = "pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	[0.7] = "pwb2/weapons/m4a1/ru-556 clip in 2.wav",
	[0.95] = "pwb2/weapons/m4a1/ru-556 bolt back.wav",
	[1] = "pwb2/weapons/m4a1/ru-556 bolt forward.wav"
}
local vector_full = Vector(1,1,1)
local vecPochtiZero = Vector(0.01,0.01,0.01)
if CLIENT then
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(48, vector_full)
			self:GetWM():ManipulateBoneScale(49, vector_full)
		end,
		[0.52] = function( self, timeMul )
			self:GetWM():ManipulateBoneScale(48, vecPochtiZero)
			self:GetWM():ManipulateBoneScale(49, vecPochtiZero)
		end
	}
end

SWEP.GetDebug = false
SWEP.CanEpicRun = false
SWEP.lmagpos = Vector(0,0,0)
SWEP.FakeAttachment = "muzzle"
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,2,-6)
SWEP.lmagang2 = Angle(0,0,-90)

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70


SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}




SWEP.WepSelectIcon2 = Material("pwb/sprites/sg552.png")
SWEP.IconOverride = "entities/weapon_pwb_sg552.png"
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.dwr_customIsSuppressed = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "5.56x45 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 44
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 35
SWEP.Primary.Sound = {"m16a4/m16a4_fp.wav", 85, 80, 90}
SWEP.SupressedSound = {"weapons/tfa_scp5k/ump/fire/ump_shot_sil_01.ogg", 65, 90, 100}
SWEP.Primary.Wait = 0.07
SWEP.ReloadTime = 3.8
SWEP.ReloadSoundes = {
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip out 1.wav",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 clip in 2.wav",
	"none",
	"none",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt back.wav",
	"none",
	"pwb2/weapons/m4a1/ru-556 bolt forward.wav",
	"none",
	"none",
	"none",
	"none"
}
SWEP.PPSMuzzleEffect = "pcf_jack_mf_mrifle1"
SWEP.LocalMuzzlePos = Vector(0,0,5)
SWEP.LocalMuzzleAng = Angle(0,0,0)
SWEP.WeaponEyeAngles = Angle(0,0,0)



SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, 0.36, 5.55)
SWEP.RHandPos = Vector(-5, -1, 1)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.ShockMultiplier = 3
SWEP.CustomShell = "9x19"
SWEP.EjectPos = Vector(6,20,0)
SWEP.EjectAng = Angle(0,90,0)

SWEP.weight = 3

SWEP.Spray = {}
for i = 1, 30 do
	SWEP.Spray[i] = Angle(-0.02 - math.cos(i) * 0.01, math.cos(i * i) * 0.04, 0) * 1
end


SWEP.Ergonomics = 0.9
SWEP.Penetration = 13
SWEP.WorldPos = Vector(10, -0, -1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.attPos = Vector(-12, -0, 0.5)
SWEP.attAng = Angle(-0, 0, 0)
SWEP.lengthSub = 25
SWEP.handsAng = Angle(0, 0, 0)
SWEP.Supressor = true
SWEP.SetSupressor = false
SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor2", Vector(0,0,0), {}},
		["mount"] = Vector(-0.8, -0.3, 0.5),
		["mountAngle"] = Angle(0,0,0),
	},
	sight = {
		["mountType"] = {"picatinny","dovetail",},
		["mount"] = {["picatinny"] = Vector(-14, 1.26, 0.37), ["dovetail"] = Vector(-2.2, -0.9, 0.5), },
		["mountAngle"] = Angle(0,0,0),
	},
}

--local to head
SWEP.RHPos = Vector(4,-5.5,3.5)
SWEP.RHAng = Angle(0,-15,90)
--local to rh
SWEP.LHPos = Vector(12,0.2,-3.5)
SWEP.LHAng = Angle(-110,-180,5)

SWEP.ShootAnimMul = 4

local lfang2 = Angle(0, -35, -15)
local lfang21 = Angle(0, 35, 25)
local lfang1 = Angle(-5, -5, -5)
local lfang0 = Angle(-15, -22, 15)
local vec_zero = Vector(0,0,0)
local ang_zero = Angle(0,0,0)
function SWEP:AnimHoldPost()

end

function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	self.vec = self.vec or Vector(0,0,0)
	local vec = self.vec
	if CLIENT and IsValid(wep) then
		self.shooanim = Lerp(FrameTime()*14,self.shooanim or 0,self.ReloadSlideOffset)
		vec[1] = 0*self.shooanim
		vec[2] = 1*self.shooanim
		vec[3] = 0*self.shooanim
		wep:ManipulateBonePosition(66,vec,false)
		local seq = wep:GetSequenceName(wep:GetSequence())
		local bone_scale = (seq:find("reload") or self.reload) and Vector(1,1,1) or Vector(0,0,0)
		wep:ManipulateBoneScale(85, bone_scale)
		wep:InvalidateBoneCache()
	end
end


-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-6,7,-9),
	Vector(-15,7,-15),
	Vector(-15,6,-15),
	Vector(-13,5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
	Vector(-0.5,1.5,-5),
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
	Vector(0,0,1),
	Vector(8,1,2),
	Vector(6,4.5,-4),
	Vector(6,4.5,-4),
	Vector(6,4.5,-4),
	Vector(1,4.5,-3),
	Vector(1,4.5,-2),
	Vector(0,4,-2),
	Vector(0,5,0),
	"reloadend",
	Vector(-2,2,1),
	Vector(0,0,0),
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-70,0,110),
	Angle(-50,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-90,0,110),
	Angle(-60,0,95),
	Angle(0,0,60),
	Angle(0,0,30),
	Angle(0,0,2),
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
	Angle(20,0,-60),
	Angle(20,0,-60),
	Angle(20,0,-60),
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
	Angle(7,17,-22),
	Angle(0,14,-21),
	Angle(0,15,-22),
	Angle(0,24,-23),
	Angle(0,25,-22),
	Angle(-15,24,-25),
	Angle(-15,25,-23),
	Angle(5,0,2),
	Angle(0,0,0),
}


SWEP.ReloadSlideAnim = {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	4,
	4,
	0,
	0,
	0,
	0
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



function SWEP:PostFireBullet(bullet)
	if CLIENT then
		-- Просто проигрываем анимацию выстрела
		self:PlayAnim("shoot1", 0.1, nil, false)
	end
end