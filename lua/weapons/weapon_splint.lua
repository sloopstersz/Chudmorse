if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_bandage_sh"
-- held and animated like the bandage (third-person IK on a viewmodel), using the EFT splint animation
SWEP.PrintName = "Splint"
SWEP.Instructions = "A padded limb splint with a strap. Immobilizes a broken arm or leg so the bone can start knitting back together. Aim at a limb to pick which one, RMB to use on someone else."
SWEP.HowToUseInstructions = "LMB - splint yourself  /  RMB - splint someone else"
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
-- model, animation, sounds and icon from the EFT meds addon (Aluminium Splint), copied into LAMENT
SWEP.WorldModel = "models/weapons/sweps/eft/alusplint/w_meds_alusplint.mdl"

SWEP.BandageTPIK = true
SWEP.supportTPIK = true
SWEP.isTPIKBase = true
SWEP.BandageTPIKWorldModel = "models/weapons/sweps/eft/alusplint/w_meds_alusplint.mdl"
SWEP.BandageTPIKViewModel = "models/weapons/sweps/eft/alusplint/v_meds_alusplint.mdl"
SWEP.WorldModelReal = SWEP.SplintHoldViewModel
SWEP.WorldModelExchange = false
-- holding / drawing uses the bandage's viewmodel and animations (bandage roll hidden, splint drawn in
-- its place); applying it switches to the EFT viewmodel for the EFT splint animation
SWEP.SplintHoldViewModel = "models/weapons/nmrih/items/bandage/v_item_bandages.mdl"
SWEP.SplintUseViewModel = "models/weapons/sweps/eft/alusplint/v_meds_alusplint.mdl"
SWEP.BandageTPIKAnimList = {
	["deploy"] = {"draw", 1, false},             -- bandage draw
	["use"] = {"use_alusplint", 76 / 30, false},  -- EFT splint
	["idle"] = {"idle", 10, true},               -- bandage idle
}
SWEP.AnimList = SWEP.BandageTPIKAnimList
SWEP.BandageSequenceTime = 76 / 30   -- length of use_alusplint
SWEP.SplintUseTime = 76 / 30         -- hold time to apply the splint (plays the animation at normal speed)
SWEP.BandageMinUseTime = 1.2
SWEP.BandageAnimStart = 0
SWEP.BandageAnimEndTrim = 0.25       -- skip the very end of the animation (arms lowering)
SWEP.BandageTransitionDown = 0       -- no dip like the bandage's roll pull
SWEP.BandageTransitionIn = 0
-- bandage viewmodel: 53-82 are the unrolled strips, 83 is the roll in the hand -> hide all of it
SWEP.SplintHoldHiddenBones = {}
for b = 53, 83 do SWEP.SplintHoldHiddenBones[#SWEP.SplintHoldHiddenBones + 1] = b end
SWEP.SplintHoldAnchorBone = "ValveBiped.Bip01_R_Hand" -- the character's own right hand (after the arm IK)
SWEP.BandageTPIKHiddenBonesIdle = SWEP.SplintHoldHiddenBones
SWEP.BandageTPIKHiddenBonesUse = {}     -- the EFT viewmodel is just the splint mesh, nothing to hide
SWEP.HideMeshOnlyScale = {}

-- sizes / placement
SWEP.SplintHoldScale = 1.75             -- splint in the hand while holding (the EFT mesh is only ~4 units)
SWEP.SplintHoldRollBone = 83            -- the bandage roll in the bandage viewmodel; the splint copies how it sits in the hand
SWEP.SplintHoldPos = Vector(0, 0, 0)    -- nudge from the roll's spot, in the roll's space
SWEP.SplintHoldAng = Angle(0, 90, 0)    -- extra turn on top of the roll's orientation (pitch, yaw, roll)
SWEP.SplintHoldViewOffset = Vector(9, -4, 1.25) -- extra shift as seen from your view: forward, right (- = left), up
-- live tuning in game:  lament_splint_hold <x> <y> <z> <pitch> <yaw> <roll>   (prints the current values with no args)
SWEP.SplintUseScale = 1.35              -- splint size during the EFT apply animation
SWEP.SplintUseOffset = Vector(-2, 0, 3) -- pulls the apply animation back toward the camera and up so it's easier
                                        -- to see; keep x at 0 or below, pushing it forward makes the hands stretch
SWEP.HoldPos = Vector(1, 0, 0)       -- base spot in front of the eyes; the shoulder fit below moves it from here
SWEP.HoldAng = Angle(0, 0, 0)
SWEP.ShoulderFitOffset = Vector(0, 0, 0) -- extra nudge after fitting (forward, right, up) if you want it held differently
SWEP.DroppedModelScale = 1.6             -- the EFT world model is tiny (~4 units); scale it up when it's on the ground

if CLIENT then
	-- The EFT viewmodel's arms are posed around a first-person camera, so placed at the eyes its hands
	-- end up out of reach of the character's real arms and the arm IK stretches the hands to them.
	-- Fix: every frame, slide the viewmodel so its shoulders sit on the character's actual shoulders.
	-- The EFT arms are about the same length as a player's, so the hands are always reachable then.
	local function shoulderMid(e)
		local r, l = e:LookupBone("ValveBiped.Bip01_R_UpperArm"), e:LookupBone("ValveBiped.Bip01_L_UpperArm")
		local mr, ml = r and e:GetBoneMatrix(r), l and e:GetBoneMatrix(l)
		if not mr or not ml then return end
		return (mr:GetTranslation() + ml:GetTranslation()) * 0.5
	end

	-- Never let the viewmodel's hands be further from the character's shoulders than its arms reach,
	-- otherwise the arm IK can't get there and the hands stretch. Measured on the real character every
	-- frame; if a hand is out of reach the whole viewmodel is pulled back toward the shoulder.
	local function armReachCorrection(ent, wm, slack)
		local worst, corr = 0, nil
		for _, side in ipairs({"R", "L"}) do
			local ua = ent:LookupBone("ValveBiped.Bip01_" .. side .. "_UpperArm")
			local fa = ent:LookupBone("ValveBiped.Bip01_" .. side .. "_Forearm")
			local hd = ent:LookupBone("ValveBiped.Bip01_" .. side .. "_Hand")
			local wh = wm:LookupBone("ValveBiped.Bip01_" .. side .. "_Hand")
			local mua, mfa, mhd = ua and ent:GetBoneMatrix(ua), fa and ent:GetBoneMatrix(fa), hd and ent:GetBoneMatrix(hd)
			local mwh = wh and wm:GetBoneMatrix(wh)
			if mua and mfa and mhd and mwh then
				local shoulder = mua:GetTranslation()
				local upper = shoulder:Distance(mfa:GetTranslation())
				local reach = math.min(upper * 2, upper + mfa:GetTranslation():Distance(mhd:GetTranslation())) * (slack or 0.95)
				local v = mwh:GetTranslation() - shoulder
				local excess = v:Length() - reach
				if excess > worst then worst, corr = excess, -v:GetNormalized() * excess end
			end
		end
		return corr
	end

	-- TPIK copies the viewmodel's finger bones onto the character as absolute positions. The EFT hand
	-- is a different size from the character's, so the fingers got pulled off the palm (stretched hand).
	-- Keep the copied finger *pose* but rebuild each finger joint at the character's own finger lengths.
	local FINGER_CHAIN = {"0", "01", "02", "1", "11", "12", "2", "21", "22", "3", "31", "32", "4", "41", "42"} -- parents first
	function SWEP:SetHandPos(noset)
		local owner = self:GetOwner()
		local ent = IsValid(owner) and hg.GetTPIKCharacter(owner)
		local saved
		if IsValid(ent) then
			saved = {}
			for _, side in ipairs({"R", "L"}) do
				for _, f in ipairs(FINGER_CHAIN) do
					local b = ent:LookupBone("ValveBiped.Bip01_" .. side .. "_Finger" .. f)
					local p = b and ent:GetBoneParent(b)
					local mb = b and ent:GetBoneMatrix(b)
					local mp = p and p >= 0 and ent:GetBoneMatrix(p)
					if mb and mp then
						local lp = WorldToLocal(mb:GetTranslation(), angle_zero, mp:GetTranslation(), mp:GetAngles())
						saved[#saved + 1] = {b, p, lp}
					end
				end
			end
		end
		local base = weapons.GetStored("weapon_bandage_sh")
		local r
		if base and base.SetHandPos then r = base.SetHandPos(self, noset) end
		if saved then
			for _, e in ipairs(saved) do
				local mb, mp = ent:GetBoneMatrix(e[1]), ent:GetBoneMatrix(e[2])
				if mb and mp then
					mb:SetTranslation(LocalToWorld(e[3], angle_zero, mp:GetTranslation(), mp:GetAngles()))
					ent:SetBoneMatrix(e[1], mb)
				end
			end
		end
		return r
	end

	function SWEP:ApplyReachLimit(holdPos)
		local owner, wm = self:GetOwner(), self.worldModel
		local fix = self.ReachFix or Vector(0, 0, 0)
		local ent = IsValid(owner) and hg.GetTPIKCharacter(owner)
		if IsValid(ent) and IsValid(wm) then
			local corr = armReachCorrection(ent, wm) -- from last frame's placement
			local ang = owner:EyeAngles()
			if corr then
				fix = fix + Vector(corr:Dot(ang:Forward()), corr:Dot(ang:Right()), corr:Dot(ang:Up())) * math.min(1, FrameTime() * 20)
			elseif not armReachCorrection(ent, wm, 0.88) then
				fix = fix * math.max(0, 1 - FrameTime() * 1.5) -- ease back out once there's room to spare
			end
			if fix:Length() > 30 then fix = fix:GetNormalized() * 30 end
			self.ReachFix = fix
		end
		return holdPos + fix
	end

	function SWEP:GetTPIKHoldPos(holdPos)
		local owner = self:GetOwner()
		local wm = self.worldModel
		-- holding uses the bandage viewmodel, already roughly set up for the character's arms
		if not IsValid(wm) or wm:GetModel() ~= self.SplintUseViewModel then return self:ApplyReachLimit(holdPos) end
		local fit = self.ShoulderFit or Vector(0, 0, 0)
		if IsValid(owner) then
			local ent = hg.GetTPIKCharacter(owner)
			local target = IsValid(ent) and shoulderMid(ent)
			local current = shoulderMid(wm) -- from last frame's placement, so this converges smoothly
			if target and current then
				-- aim the shoulders at the character's shoulders plus the extra offsets, so the fit
				-- keeps the offsets instead of cancelling them out next frame
				local ang = owner:EyeAngles()
				-- (the reach limit's pull-back is included, so the two don't fight each other)
				local o = self.ShoulderFitOffset + self.SplintUseOffset + (self.ReachFix or vector_origin)
				target = target + ang:Forward() * o.x + ang:Right() * o.y + ang:Up() * o.z
				local d = target - current
				local step = Vector(d:Dot(ang:Forward()), d:Dot(ang:Right()), d:Dot(ang:Up()))
				fit = fit + step * math.min(1, FrameTime() * 15)
				if fit:Length() > 50 then fit = fit:GetNormalized() * 50 end
				self.ShoulderFit = fit
			end
		end
		return self:ApplyReachLimit(holdPos + fit)
	end

	-- which bones to hide on the current viewmodel; on the bandage one this also grabs the roll's
	-- position (bones are set up but not hidden yet at this point) so the splint can be drawn there
	function SWEP:GetHideMeshBones()
		local wm = self.worldModel
		if not IsValid(wm) or wm:GetModel() ~= self.SplintHoldViewModel then return self.BandageTPIKHiddenBonesUse end
		-- bones are set up but not hidden yet here: remember where the bandage roll sits relative to
		-- the viewmodel hand holding it, so the splint can be put the same way in the character's hand
		local roll = wm:GetBoneMatrix(self.SplintHoldRollBone)
		if roll then
			local best, bestDist
			for _, side in ipairs({"R", "L"}) do
				local h = wm:LookupBone("ValveBiped.Bip01_" .. side .. "_Hand")
				local mh = h and wm:GetBoneMatrix(h)
				if mh then
					local d = mh:GetTranslation():DistToSqr(roll:GetTranslation())
					if not bestDist or d < bestDist then best, bestDist = {side, mh}, d end
				end
			end
			if best then
				local lp, la = WorldToLocal(roll:GetTranslation(), roll:GetAngles(), best[2]:GetTranslation(), best[2]:GetAngles())
				self.SplintRollSide, self.SplintRollPos, self.SplintRollAng = best[1], lp, la
				self.SplintRollFrame = FrameNumber()
			end
		end
		return self.SplintHoldHiddenBones
	end

	concommand.Add("lament_splint_hold", function(ply, _, args)
		local wep = IsValid(ply) and ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_splint" then print("hold the splint first") return end
		if #args >= 3 then
			wep.SplintHoldPos = Vector(tonumber(args[1]) or 0, tonumber(args[2]) or 0, tonumber(args[3]) or 0)
		end
		if #args >= 6 then
			wep.SplintHoldAng = Angle(tonumber(args[4]) or 0, tonumber(args[5]) or 0, tonumber(args[6]) or 0)
		end
		wep.SplintLock = nil
		local p, a = wep.SplintHoldPos, wep.SplintHoldAng
		print(string.format("SWEP.SplintHoldPos = Vector(%g, %g, %g)\nSWEP.SplintHoldAng = Angle(%g, %g, %g)", p.x, p.y, p.z, a.p, a.y, a.r))
	end)

	function SWEP:DrawHeldSplint()
		-- only while holding (the EFT apply animation has its own splint)
		local wm = self.worldModel
		if not IsValid(wm) or wm:GetModel() ~= self.SplintHoldViewModel then return end
		local owner = self:GetOwner()
		local ent = hg.GetTPIKCharacter(owner)
		if not IsValid(ent) then ent = owner end

		-- locked to the hand: once the tuned spot has been captured relative to the hand, the splint
		-- just rides along with the hand bone (re-captured if any of the placement settings change)
		local sig = tostring(self.SplintHoldViewOffset) .. tostring(self.SplintHoldPos) .. tostring(self.SplintHoldAng) .. self.SplintHoldScale
		if self.SplintLockSig ~= sig then self.SplintLock = nil self.SplintLockSig = sig end
		local handBone = ent:LookupBone("ValveBiped.Bip01_" .. (self.SplintRollSide or "R") .. "_Hand")
		local hm = handBone and ent:GetBoneMatrix(handBone)
		if not hm then return end
		if self.SplintLock then
			local pos, ang = LocalToWorld(self.SplintLock[1], self.SplintLock[2], hm:GetTranslation(), hm:GetAngles())
			return self:DrawSplintAt(pos, ang)
		end
		-- capture only once the hold animation has settled (not mid-draw)
		self.SplintIdleSince = (self.anim == "idle") and (self.SplintIdleSince or CurTime()) or nil
		self.SplintCaptureNow = self.SplintIdleSince and CurTime() - self.SplintIdleSince > 0.4
		self.SplintCaptureHand = hm

		-- preferred: the same spot and angle as the bandage roll, relative to the character's real hand
		if self.SplintRollPos and self.SplintRollFrame and FrameNumber() - self.SplintRollFrame <= 1 then
			local hb = ent:LookupBone("ValveBiped.Bip01_" .. self.SplintRollSide .. "_Hand")
			local mh = hb and ent:GetBoneMatrix(hb)
			if mh then
				self.SplintAnchorPos, self.SplintAnchorAng = LocalToWorld(self.SplintRollPos, self.SplintRollAng, mh:GetTranslation(), mh:GetAngles())
				return self:DrawSplintProp()
			end
		end

		-- fallback: fitted between the thumb and fingers
		local bone = ent:LookupBone(self.SplintHoldAnchorBone)
		local m = bone and ent:GetBoneMatrix(bone)
		if not m then return end
		-- grip point: between the thumb and the middle finger, i.e. inside the closed hand. Worked out
		-- from the character's own finger bones so it lands in the palm whatever way the hand bone faces.
		local grip = m:GetTranslation()
		local t = ent:LookupBone("ValveBiped.Bip01_R_Finger01")
		local f = ent:LookupBone("ValveBiped.Bip01_R_Finger21")
		local mt, mf = t and ent:GetBoneMatrix(t), f and ent:GetBoneMatrix(f)
		if mt and mf then grip = (mt:GetTranslation() + mf:GetTranslation()) * 0.5 end

		-- orientation: the rolled splint's long side (mesh Y) runs across the palm, index knuckle to
		-- pinky knuckle, and its front (mesh X) points the way the fingers do, so the hand wraps around it
		local gripAng
		local bi, bp, bm = ent:LookupBone("ValveBiped.Bip01_R_Finger1"), ent:LookupBone("ValveBiped.Bip01_R_Finger4"), ent:LookupBone("ValveBiped.Bip01_R_Finger2")
		local mi, mp, mm = bi and ent:GetBoneMatrix(bi), bp and ent:GetBoneMatrix(bp), bm and ent:GetBoneMatrix(bm)
		if mi and mp and mm then
			local across = (mp:GetTranslation() - mi:GetTranslation()):GetNormalized()
			local fingers = mm:GetTranslation() - m:GetTranslation()
			fingers = (fingers - across * fingers:Dot(across)):GetNormalized() -- square it up with "across"
			local up = fingers:Cross(across)
			gripAng = fingers:AngleEx(up) -- forward = fingers, up = palm normal, local Y = across
		else
			local _, a = LocalToWorld(vector_origin, Angle(90, 90, 0), vector_origin, m:GetAngles())
			gripAng = a
		end
		self.SplintAnchorPos, self.SplintAnchorAng = grip, gripAng
		return self:DrawSplintProp()
	end

	function SWEP:DrawSplintProp()
		local prop = self.SplintProp
		if not IsValid(prop) then
			prop = ClientsideModel(self.WorldModel)
			if not IsValid(prop) then return end
			prop:SetNoDraw(true)
			self.SplintProp = prop
			self:CallOnRemove("remove_splintprop", function() if IsValid(prop) then prop:Remove() end end)
		end
		prop:SetModelScale(self.SplintHoldScale)
		-- the mesh sits off to one side of its origin (built around a hand bone), so centre it
		-- (place the grip point in the hand, then shift the mesh so its middle sits on that point)
		local gripPos, gripAng = LocalToWorld(self.SplintHoldPos, self.SplintHoldAng, self.SplintAnchorPos, self.SplintAnchorAng)
		local pos, ang = LocalToWorld(Vector(-0.1, -2.25, 0.05) * self.SplintHoldScale, angle_zero, gripPos, gripAng)
		local owner = self:GetOwner()
		if IsValid(owner) then
			local eye, o = owner:EyeAngles(), self.SplintHoldViewOffset
			pos = pos + eye:Forward() * o.x + eye:Right() * o.y + eye:Up() * o.z
		end
		if self.SplintCaptureNow and self.SplintCaptureHand then
			local hm = self.SplintCaptureHand
			local lp, la = WorldToLocal(pos, ang, hm:GetTranslation(), hm:GetAngles())
			self.SplintLock = {lp, la}
		end
		self:DrawSplintAt(pos, ang)
	end

	function SWEP:DrawSplintAt(pos, ang)
		local prop = self.SplintProp
		if not IsValid(prop) then
			prop = ClientsideModel(self.WorldModel)
			if not IsValid(prop) then return end
			prop:SetNoDraw(true)
			self.SplintProp = prop
			self:CallOnRemove("remove_splintprop", function() if IsValid(prop) then prop:Remove() end end)
		end
		prop:SetModelScale(self.SplintHoldScale)
		prop:SetRenderOrigin(pos)
		prop:SetRenderAngles(ang)
		prop:SetupBones()
		prop:DrawModel()
	end

	function SWEP:DrawWorldModel2(prepareOnly)
		-- bigger on the ground, normal size in the hands (modelscale2 scales whatever model is drawn)
		self.modelscale2 = IsValid(self:GetOwner()) and 1 or self.DroppedModelScale
		-- scale just the splint inside the EFT viewmodel (not the arms, that would stretch them again)
		local wm = self.worldModel
		if IsValid(wm) then
			local root = wm:GetModel() == self.SplintUseViewModel and wm:LookupBone("splint_root")
			if root then
				wm:ManipulateBoneScale(root, Vector(1, 1, 1) * self.SplintUseScale)
				self.SplintScaledBone = root
			elseif self.SplintScaledBone then
				wm:ManipulateBoneScale(self.SplintScaledBone, Vector(1, 1, 1)) -- back on the bandage model
				self.SplintScaledBone = nil
			end
		end
		local base = weapons.GetStored("weapon_bandage_sh")
		local r
		if base and base.DrawWorldModel2 then r = base.DrawWorldModel2(self, prepareOnly) end
		if not prepareOnly and IsValid(self:GetOwner()) then self:DrawHeldSplint() end
		return r
	end
end
SWEP.WepSelectIcon2box = true -- square icon: don't stretch it wide in the loot menu
if CLIENT then
	SWEP.WepSelectIcon = Material("entities/weapon_eft_alusplint.png", "smooth")
	SWEP.IconOverride = "entities/weapon_eft_alusplint.png"
	SWEP.BounceWeaponIcon = false

	SWEP.WepSelectIcon2 = Material("entities/weapon_eft_alusplint.png", "smooth")

	function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )
		surface.SetDrawColor( 255, 255, 255, alpha )
		surface.SetMaterial( self.WepSelectIcon2 )

		local maxWide = wide
		local maxTall = wide / 2
		local iconWide = self.WepSelectIcon2:Width()
		local iconTall = self.WepSelectIcon2:Height()
		if iconWide <= 0 or iconTall <= 0 then return end
		local scale = math.min(maxWide / iconWide, maxTall / iconTall)
		local drawWide = iconWide * scale
		local drawTall = iconTall * scale

		surface.DrawTexturedRect( x + (maxWide - drawWide) / 2, y + 10 + (maxTall - drawTall) / 2, drawWide, drawTall )

		self:PrintWeaponInfo( x + wide + 20, y + tall * 0.95, alpha )
	end
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -3.5, 0)
SWEP.offsetAng = Angle(90, 90, 0)
SWEP.ModelScale = 1
SWEP.modeNames = {
	[1] = "splint"
}
SWEP.showstats = false

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)
	self.modeValues = {
		[1] = 1,
	}
end

SWEP.modeValuesdef = {
	[1] = 1,
}

-- how the splint works
SWEP.SplintBrokenAt = 0.3      -- limb damage (0 = fine, 1 = broken) worth splinting
SWEP.SplintSetTo = 0.5         -- a splinted limb immediately drops to this (no longer counts as broken)
SWEP.SplintHealTime = 45       -- seconds for a splinted limb to heal from SplintSetTo to 0

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

-- bandage viewmodel for drawing/holding, EFT viewmodel while applying
function SWEP:PlayAnim(anim, ...)
	self.WorldModelReal = (anim == "use") and self.SplintUseViewModel or self.SplintHoldViewModel
	local base = weapons.GetStored("weapon_tpik_base")
	if base and base.PlayAnim then return base.PlayAnim(self, anim, ...) end
end

-- EFT splint sounds: the strap rustle at the start, then the main splinting sound at the same
-- point the EFT addon plays it (1.5s into the 2.53s animation)
function SWEP:PlayBandageTPIKSounds(elapsed, useTime, sndOwner)
	if self.bandageTPIKSounds < 1 then
		self.bandageTPIKSounds = 1
		sndOwner:EmitSound("weapons/eft/splint/item_splint_00_start.wav", 60, math.random(95, 105))
	end
	if self.bandageTPIKSounds < 2 and elapsed >= useTime * (1.5 / (76 / 30)) then
		self.bandageTPIKSounds = 2
		sndOwner:EmitSound("weapons/eft/splint/item_splint_01_middle.wav", 60, math.random(95, 105))
	end
end

function SWEP:GetBandageTPIKUseTime(target)
	return self.SplintUseTime
end

function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:NPCHeal(owner, 0.2, "snd_jack_hmcd_bandage.wav")
	end
end

if SERVER then
	local LIMB_BONES = {
		["ValveBiped.Bip01_L_Thigh"] = "lleg", ["ValveBiped.Bip01_L_Calf"] = "lleg", ["ValveBiped.Bip01_L_Foot"] = "lleg", ["ValveBiped.Bip01_L_Toe0"] = "lleg",
		["ValveBiped.Bip01_R_Thigh"] = "rleg", ["ValveBiped.Bip01_R_Calf"] = "rleg", ["ValveBiped.Bip01_R_Foot"] = "rleg", ["ValveBiped.Bip01_R_Toe0"] = "rleg",
		["ValveBiped.Bip01_L_UpperArm"] = "larm", ["ValveBiped.Bip01_L_Forearm"] = "larm", ["ValveBiped.Bip01_L_Hand"] = "larm",
		["ValveBiped.Bip01_R_UpperArm"] = "rarm", ["ValveBiped.Bip01_R_Forearm"] = "rarm", ["ValveBiped.Bip01_R_Hand"] = "rarm",
	}
	local LIMB_NAMES = { lleg = "left leg", rleg = "right leg", larm = "left arm", rarm = "right arm" }
	local LIMBS = { "lleg", "rleg", "larm", "rarm" }

	function SWEP:GetTargetLimb(ent)
		local owner = self:GetOwner()
		local tr = hg.eyeTrace(owner)
		if not tr or tr.Entity ~= ent then return nil end
		local physbone = tr.PhysicsBone
		if not physbone or physbone < 0 then return nil end
		local boneid = ent:TranslatePhysBoneToBone(physbone)
		if not boneid or boneid < 0 then return nil end
		return LIMB_BONES[ent:GetBoneName(boneid)]
	end

	local function CanSplint(self, org, limb)
		if not limb or not isnumber(org[limb]) then return false end
		if org[limb .. "amputated"] or org[limb .. "upamputated"] then return false end
		if org.splints and org.splints[limb] then return false end
		return org[limb] >= self.SplintBrokenAt
	end

	-- aimed at a specific limb, otherwise the worst one; nil if nothing needs a splint
	function SWEP:FindSplintLimb(org, limb)
		if CanSplint(self, org, limb) then return limb end
		local best, worst = nil, 0
		for _, l in ipairs(LIMBS) do
			if CanSplint(self, org, l) and org[l] > worst then
				worst = org[l]
				best = l
			end
		end
		return best
	end

	-- chat messages are rate limited so holding the button doesn't spam
	function SWEP:SplintMessage(text)
		local owner = self:GetOwner()
		if not IsValid(owner) or not owner:IsPlayer() then return end
		if (owner.NextSplintMsg or 0) > CurTime() then return end
		owner.NextSplintMsg = CurTime() + 3
		owner:ChatPrint(text)
	end

	function SWEP:Splint(ent, limb)
		local org = ent.organism
		if not org then return false end

		limb = self:FindSplintLimb(org, limb)
		local owner = self:GetOwner()
		if not limb then return false end

		org[limb] = math.min(org[limb], self.SplintSetTo)
		org.splints = org.splints or {}
		org.splints[limb] = self.SplintSetTo / math.max(self.SplintHealTime, 1) -- heal per second
		if org.avgpain then org.avgpain = math.max(org.avgpain - 10, 0) end
		if org.pain then org.pain = math.max(org.pain - 5, 0) end

		local who = hg.GetCurrentCharacter(owner) == ent and "your" or "their"
		local text = "You splint " .. who .. " " .. LIMB_NAMES[limb] .. "."
		-- short delay so the message lands after the splint goes on
		timer.Simple(0.6, function()
			if IsValid(owner) and owner:IsPlayer() then owner:ChatPrint(text) end
		end)
		owner:EmitSound("snd_jack_hmcd_bandage.wav", 60, math.random(85, 95))
		return true
	end

	-- the use animation only starts if there's a limb worth splinting
	function SWEP:CanBandageTPIK(target)
		local org = IsValid(target) and target.organism
		if not org then return false end
		if self:FindSplintLimb(org, self:GetTargetLimb(target)) then return true end
		local owner = self:GetOwner()
		local self_target = hg.GetCurrentCharacter(target) == hg.GetCurrentCharacter(owner)
		self:SplintMessage(self_target and "You have no broken limbs to splint." or "They have no broken limbs to splint.")
		return false
	end

	function SWEP:Heal(ent, mode)
		if ent:IsNPC() then
			self:NPCHeal(ent, 0.2, "snd_jack_hmcd_bandage.wav")
			return
		end

		local owner = self:GetOwner()
		local org = ent.organism
		if not org then return end

		-- nothing broken: don't start the animation at all
		local limb = self:FindSplintLimb(org, self:GetTargetLimb(ent))
		if not limb then
			self:SetHolding(0)
			self:SplintMessage(ent == hg.GetCurrentCharacter(owner) and "You have no broken limbs to splint." or "They have no broken limbs to splint.")
			return
		end

		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 10, 100))
			if self:GetHolding() < 100 then return end
		end

		if self:Splint(ent, limb) then
			self.modeValues[1] = 0
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
			return true
		end
	end

	-- splinted limbs heal back to 0 over time, then the splint comes off
	hook.Add("Org Think", "ZC_SplintHealing", function(owner, org, timeValue)
		if not org.splints then return end
		for limb, rate in pairs(org.splints) do
			if not isnumber(org[limb]) or org[limb .. "amputated"] then
				org.splints[limb] = nil
			else
				org[limb] = math.max(org[limb] - rate * timeValue, 0)
				if org[limb] <= 0 then org.splints[limb] = nil end
			end
		end
		if next(org.splints) == nil then org.splints = nil end
	end)

	hook.Add("PlayerSpawn", "ZC_SplintReset", function(ply)
		if ply.organism then ply.organism.splints = nil end
	end)
end
