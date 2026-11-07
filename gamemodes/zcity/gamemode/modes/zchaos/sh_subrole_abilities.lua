-- Keep these mode callbacks inactive while another mode is running.
local modeHookAPI = hook
local hook = setmetatable({}, {__index = modeHookAPI})
function hook.Add(event, id, callback)
    modeHookAPI.Add(event, "CHAOS_" .. id, function(...)
        local active = zb and (zb.CROUND_MAIN or zb.CROUND)
        if active ~= "chaos" then return end
        return callback(...)
    end)
end
function hook.Remove(event, id)
    modeHookAPI.Remove(event, "CHAOS_" .. id)
end

local MODE = MODE
MODE.NetSize_ChemicalResistanceBits = 8
local chemical_degrade_speeds = {
	["HCN"] = 1,
	["KCN"] = 0.5,
}

MODE.DisarmReach = 90
MODE.NoDisarmWeapons = {
	["weapon_hands_sh"] = true,
}

--\\
function MODE.GetPlayerTraceToOtherVictim(ply, victim, dist)
	if(IsValid(victim))then
		local ragdoll = victim.FakeRagdoll or victim:GetNWEntity("RagdollDeath", victim.FakeRagdoll)
		
		if(IsValid(ragdoll))then
			--
		else
			ragdoll = victim
		end
		
		local bone_id = ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
		
		if(bone_id)then
			local bone_matrix = ragdoll:GetBoneMatrix(bone_id)
			
			if(bone_matrix)then
				local pos, ang = bone_matrix:GetTranslation(), bone_matrix:GetAngles()
				local ply_offset_normal = pos - ply:GetShootPos()
				local ply_aim_normal = ply:GetAimVector()
					
				ply_offset_normal:Normalize()
				ply_aim_normal:Normalize()
				
				local ang_diff = -(math.deg(math.acos(ply_aim_normal:DotProduct(-ply_offset_normal))) - 180)
				
				if(ang_diff < 80)then
					local aim_ent, other_ply, trace = MODE.GetPlayerTraceToOther(ply, ply_offset_normal, dist)
					
					if(IsValid(aim_ent))then
						return aim_ent, other_ply, trace
					else
						return MODE.GetPlayerTraceToOther(ply, dist)
					end
				else
					return MODE.GetPlayerTraceToOther(ply, dist)
				end
			end
		end
	end
end
--//

--\\Neck Break
function MODE.CanPlayerBreakOtherNeck(ply, aim_ent)
	if(aim_ent:IsRagdoll())then
		local bone_id = aim_ent:LookupBone("ValveBiped.Bip01_Head1")
		
		if(bone_id)then
			local bone_matrix = aim_ent:GetBoneMatrix(bone_id)
			
			if(bone_matrix)then
				local pos, ang = bone_matrix:GetTranslation(), bone_matrix:GetAngles()
				local other_normal = -ang:Right()
				local ply_normal = pos - ply:GetShootPos()
				local dist_z = math.abs(pos.z - ply:GetShootPos().z)
				
				if(dist_z < 50) then
					ply_normal:Normalize()
					
					local ang_diff = -(math.deg(math.acos(ply_normal:DotProduct(other_normal))) - 180)
					
					if(ang_diff < 100)then
						return true
					end
				end
			end
		end
	elseif(aim_ent:IsPlayer())then
		local other_angle = aim_ent:EyeAngles()[2]
		local ply_angle = (aim_ent:GetPos() - ply:GetPos()):Angle()[2] --ply:EyeAngles()[2]
		local ang_diff = math.abs(math.AngleDifference(other_angle, ply_angle))
		
		if(ang_diff < 100)then
			return true
		end
	end
	
	return false
end

function MODE.BreakOtherNeck(ply, other_ply, aim_ent)
	if(other_ply:Alive())then
		if SERVER then hook.Run("ChudAchievementNeckSnap", ply, other_ply) end
		other_ply:Kill()
		other_ply:ViewPunch(Angle(0, 0, -10))
		
		aim_ent.organism.spine3 = 1
		
		aim_ent:EmitSound("neck_snap_01.wav", 60, 100, 1, CHAN_AUTO)

		timer.Simple(0.1, function()
			local ent = other_ply:GetNWEntity("RagdollDeath")

			if IsValid(ent) then
				ent:RemoveInternalConstraint(ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Head1")))

				local spine = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Spine2"))
				local head = ent:TranslateBoneToPhysBone(ent:LookupBone("ValveBiped.Bip01_Head1"))

				local pspine = ent:GetPhysicsObjectNum(spine)
				local phead = ent:GetPhysicsObjectNum(head)

				local lpos, lang = WorldToLocal(phead:GetPos() + phead:GetAngles():Forward() * -2 + phead:GetAngles():Up() * -1.5, angle_zero, pspine:GetPos(), pspine:GetAngles())
                
				phead:SetPos(pspine:GetPos() + pspine:GetAngles():Forward() * 12.9 + pspine:GetAngles():Right() * -1)

				local cons = constraint.AdvBallsocket(ent, ent, spine, head, lpos, nil, 0, 0, -55, -90, -50, 55, 35, 50, 0, 0, 0, 0, 0)
			end
		end)
	end
end

function MODE.StartBreakingOtherNeck(ply, other_ply)
	ply.Ability_NeckBreak = {
		Victim = other_ply,
		Progress = 0,
	}
	other_ply.BeingVictimOfNeckBreak = true
	
	if(SERVER)then
		other_ply:ViewPunch(Angle(0, -10, -10))
		
		net.Start("CHAOS_BeingVictimOfNeckBreak")
			net.WriteBool(true)
		net.Send(other_ply)
		
		net.Start("CHAOS_BreakingOtherNeck")
			net.WriteBool(true)
			net.WriteEntity(ply)
			net.WriteEntity(other_ply)
		net.SendPVS(ply:GetShootPos())
	end
end

function MODE.StopBreakingOtherNeck(ply)
	if(ply.Ability_NeckBreak and IsValid(ply.Ability_NeckBreak.Victim))then
		ply.Ability_NeckBreak.Victim.BeingVictimOfNeckBreak = false
	end
	
	if(SERVER and ply.Ability_NeckBreak and IsValid(ply.Ability_NeckBreak.Victim))then
		net.Start("CHAOS_BeingVictimOfNeckBreak")
			net.WriteBool(false)
		net.Send(ply.Ability_NeckBreak.Victim)

		net.Start("CHAOS_BreakingOtherNeck")
			net.WriteBool(false)
			net.WriteEntity(ply)
		net.SendPVS(ply:GetShootPos())
	end
	
	ply.Ability_NeckBreak = nil
end

function MODE.ContinueBreakingOtherNeck(ply)
	local break_data = ply.Ability_NeckBreak
	local victim = break_data.Victim
	local aim_ent, other_ply, trace = MODE.GetPlayerTraceToOtherVictim(ply, victim)
	
	if(IsValid(aim_ent) and (aim_ent:IsPlayer() or aim_ent:IsRagdoll()))then
		if(IsValid(victim) and victim:Alive() and MODE.CanPlayerBreakOtherNeck(ply, aim_ent) and other_ply == victim)then
			break_data.Progress = break_data.Progress + FrameTime() * 300
			
			if(break_data.Progress >= 100)then
				if(SERVER)then
					MODE.BreakOtherNeck(ply, break_data.Victim, aim_ent)
				end
				
				
				MODE.StopBreakingOtherNeck(ply)
			end
		else
			MODE.StopBreakingOtherNeck(ply)
		end
	else
		MODE.StopBreakingOtherNeck(ply)
	end
end

hook.Add("HG_MovementCalc_2", "CHAOS_SubRole_Abilities", function(mul, ply, cmd)
	if(ply.BeingVictimOfNeckBreak or ply.BeingVictimOfDisarmament)then
		mul[1] = mul[1] * 0.3
	end
end)
--//

--\\Disarm
function MODE.CanPlayerDisarmOtherPly(ply, other_ply)
	--[[if(other_ply and IsValid(other_ply:GetActiveWeapon()))then
		if(MODE.NoDisarmWeapons[other_ply:GetActiveWeapon():GetClass()])then
			return false
		end
	else
		return false
	end--]]
	
	return true
end

function MODE.CanPlayerDisarmOther(ply, aim_ent)
	if(aim_ent:IsRagdoll())then
		local bone_id = aim_ent:LookupBone("ValveBiped.Bip01_Spine2")
		
		if(bone_id)then
			local bone_matrix = aim_ent:GetBoneMatrix(bone_id)
			
			if(bone_matrix)then
				local pos, ang = bone_matrix:GetTranslation(), bone_matrix:GetAngles()
				local other_normal = ang:Right()
				local ply_normal = pos - ply:GetShootPos()
				local dist_z = math.abs(pos.z - ply:GetShootPos().z)
				
				if(dist_z < 50) then
					ply_normal:Normalize()
					
					local ang_diff = -(math.deg(math.acos(ply_normal:DotProduct(other_normal))) - 180)
					
					if(ang_diff < 90)then
						return 2
					else
						return 1.5
					end
				end
			end
		end
	elseif(aim_ent:IsPlayer())then
		local other_angle = aim_ent:EyeAngles()[2]
		local ply_angle = (aim_ent:GetPos() - ply:GetPos()):Angle()[2] --ply:EyeAngles()[2]
		local ang_diff = math.abs(math.AngleDifference(other_angle, ply_angle))
		
		if(ang_diff < 70)then
			return 2
		else
			return 1.5
		end
	end
	
	return false
end

function MODE.DisarmOther(ply, other_ply, aim_ent)
    if IsValid(other_ply) and other_ply.SubRole == "traitor_martialartist" then return end
	if(other_ply:Alive())then
		local weapon = other_ply:GetActiveWeapon()

		if(IsValid(weapon) and !weapon.NoDrop)then
			other_ply:DropWeapon(weapon)
			ply:PickupWeapon(weapon, false)
		end

		hg.LightStunPlayer(other_ply)
		timer.Simple(0,function()
			local rag = hg.GetCurrentCharacter(other_ply)
			if IsValid(rag) and rag ~= other_ply then
				local bon = rag:LookupBone("ValveBiped.Bip01_Head1")
				local physnum = rag:TranslateBoneToPhysBone(bon)
				local phys = rag:GetPhysicsObjectNum(physnum)
				local dist = 25--phys:GetPos():Distance(ply:EyePos())
				
				hg.SetCarryEnt2(ply, rag, bon, phys:GetMass(), Vector(-2,0,0), ply:GetAimVector() * dist + ply:EyeAngles():Up() * 5 + ply:EyeAngles():Right() * -5 + ply:GetShootPos(), ply:EyeAngles() + Angle(-90, 90, 0))
			end
		end)
	end
end

function MODE.StartDisarmingOther(ply, other_ply)
	ply.Ability_Disarm = {
		Victim = other_ply,
		Progress = 0,
	}
	other_ply.BeingVictimOfDisarmament = true
	
	if(SERVER)then
		-- other_ply:ViewPunch(Angle(0, -10, -10))
		
		net.Start("CHAOS_BeingVictimOfDisarmament")
			net.WriteBool(true)
		net.Send(other_ply)
		
		net.Start("CHAOS_DisarmingOther")
			net.WriteBool(true)
			net.WriteEntity(other_ply)
		net.Send(ply)
	end
end

function MODE.StopDisarmingOther(ply)
	if(ply.Ability_Disarm and IsValid(ply.Ability_Disarm.Victim))then
		ply.Ability_Disarm.Victim.BeingVictimOfDisarmament = false
	end
	
	if(SERVER and ply.Ability_Disarm and IsValid(ply.Ability_Disarm.Victim))then
		net.Start("CHAOS_BeingVictimOfDisarmament")
			net.WriteBool(false)
		net.Send(ply.Ability_Disarm.Victim)

		net.Start("CHAOS_DisarmingOther")
			net.WriteBool(false)
		net.Send(ply)
	end
	
	ply.Ability_Disarm = nil
end

function MODE.ContinueDisarmingOther(ply)
	local ability_data = ply.Ability_Disarm
	local victim = ability_data.Victim
	local aim_ent, other_ply, trace = MODE.GetPlayerTraceToOtherVictim(ply, victim, MODE.DisarmReach)
	
	if(IsValid(aim_ent) and (aim_ent:IsPlayer() or aim_ent:IsRagdoll()))then
		local disarm_strength = MODE.CanPlayerDisarmOther(ply, aim_ent)
		
		if(IsValid(victim) and victim:Alive() and disarm_strength and other_ply == victim and MODE.CanPlayerDisarmOtherPly(ply, other_ply))then
			ability_data.Progress = ability_data.Progress + FrameTime() * 250 * disarm_strength
			
			if(ability_data.Progress >= 100)then
				if(SERVER)then
					MODE.DisarmOther(ply, victim, aim_ent)
				end
				
				
				MODE.StopDisarmingOther(ply)
			end
		else
			MODE.StopDisarmingOther(ply)
		end
	else
		MODE.StopDisarmingOther(ply)
	end
end

hook.Add("PlayerSwitchWeapon", "CHAOS_SubRole_Abilities", function(ply)
	if(ply.BeingVictimOfDisarmament)then
		return true
	end
end)
--//
MODE.MAMoves = {
    {id = "dragon_beast_piledive", name = "Beast: Piledive", dir = "any"},
    {id = "dragon_brawling", name = "Brawler: Brawling", dir = "any"},
    {id = "dragon_disarming", name = "Brawler: Disarming", dir = "any"},
    {id = "dragon_rush_barrage", name = "Rush: Barrage", dir = "any"},
    {id = "dragon_rush_crushing", name = "Rush: Crushing", dir = "any"},
    {id = "dragon_rush_wall", name = "Rush: Wall Crushing", dir = "any"},
    {id = "dragon_tigerdrop", name = "Tiger Drop", dir = "any"},
    { id = "mw_giantswing", name = "Floor Giantswing", dir = "floor" },
    { id = "mw_dyli_front", name = "Dying Light Front", dir = "front" },
    { id = "mw_suplex",    name = "Suplex Deluxe", dir = "back" },
    { id = "mw_necktrauma", name = "Neck Trauma",   dir = "back" },
    { id = "mw_cagematch", name = "Cage Match", dir = "back" },
    { id = "mw_sweetdreams", name = "Sweet Dreams", dir = "back" },
}

if SERVER then
	local maMoveCategories = {
        dragon_beast_piledive = "knockdown",
        dragon_brawling = "knockdown",
        dragon_disarming = "knockdown",
        dragon_rush_barrage = "knockdown",
        dragon_rush_crushing = "knockdown",
        dragon_rush_wall = "knockdown",
        dragon_tigerdrop = "knockdown",


		mw_dyli_front = "disarm",
		mw_suplex = "knockdown",
		mw_necktrauma = "knockdown",
		mw_cagematch = "knockdown",
		mw_sweetdreams = "knockdown"
	}
	local maCooldowns = {
		disarm = 8,
		knockdown = 8
	}
	local maLimbNames = {
		larm = "left arm",
		rarm = "right arm",
		lleg = "left leg",
		rleg = "right leg"
	}

	function MODE.MAForceUncon(target, duration)
		if not IsValid(target) or not target:Alive() or not target.organism then return end
		local org = target.organism
		org.consciousness = 0
		org.needotrub = true
		org.needfake = true
		org.disorientation = math.min((org.disorientation or 0) + 10, 10)
		org.immobilization = math.min((org.immobilization or 0) + 40, 90)
		org.painadd = math.min((org.painadd or 0) + 30, 150)
		if not IsValid(target.FakeRagdoll) then hg.Fake(target, nil, true) end
		timer.Simple(duration or 6, function()
			if not IsValid(target) or not target:Alive() or not target.organism then return end
			local org = target.organism
			org.consciousness = 1
			org.needotrub = false
			org.needfake = false
			org.disorientation = math.min((org.disorientation or 0) + 8, 10)
			org.immobilization = math.min((org.immobilization or 0) + 30, 90)
		end)
	end

	hook.Add("EntityTakeDamage", "MMA_MoveProtection", function(ent, dmg)
		if not IsValid(ent) then return end
		local ply = ent:IsPlayer() and ent or (IsValid(ent.ply) and ent.ply)
		if not IsValid(ply) or ply.SubRole ~= "traitor_martialartist" then return end
		if (ply.WWE_HoldDownUntil or 0) > CurTime() then
			dmg:SetDamage(0)
			return true
		end
	end, 0.5)

	local function dislocateMALimb(target)
		if not IsValid(target) or not target:Alive() or not target.organism or target.organism.superfighter then return end

		local available = {}
		for limb in pairs(maLimbNames) do
			if not target.organism[limb .. "dislocation"] and not target.organism[limb .. "amputated"] then
				available[#available + 1] = limb
			end
		end
		if #available == 0 then return end

		local limb = available[math.random(#available)]
		local org = target.organism
		org[limb .. "dislocation"] = true
		org.painadd = math.min((org.painadd or 0) + 25, 150)
		org.shock = math.min((org.shock or 0) + 8, 95)
		target:EmitSound("physics/body/body_medium_break" .. math.random(2, 4) .. ".wav", 70, math.random(90, 105))
		target:Notify("Your " .. maLimbNames[limb] .. " was dislocated by the takedown.", true, "ma_dislocation", 3)
	end

	function MODE.RunMartialArtistMove(ply, moveId, target)
		if not (ChudDragonStyle and ChudDragonStyle.CanUse(ply)) then return false end
		if not ChudDragonStyle.CanUseMove(ply, moveId) then return false end
		if not (WWE and WWE.moves and WWE.moves[moveId]) then return false end

		local category = maMoveCategories[moveId]
		if moveId ~= "mw_giantswing" and not category then return false end

		ply.MACooldowns = ply.MACooldowns or {}
		if category and (ply.MACooldowns[category] or 0) > CurTime() then return false end

		local success = WWE.RunMove(ply, moveId)
		if not success then return false end

		if not IsValid(target) then
			target = ply.WWE_LastTarget
		end

		if category then
			ply.MACooldowns[category] = CurTime() + maCooldowns[category]
		end

        -- Dragon Style uses only the authored animation and its damage callback.
        -- Do not layer the base role's forced unconsciousness/dislocations over it.
        if ChudDragonStyle.DragonMoves[moveId] then return true end

		if IsValid(target) then
			if moveId == "mw_giantswing" then
				local org = target.organism
				if org then
					org.disorientation = math.min((org.disorientation or 0) + 8, 10)
					org.immobilization = math.min((org.immobilization or 0) + 25, 90)
					org.painadd = math.min((org.painadd or 0) + 20, 150)
					if not IsValid(target.FakeRagdoll) then hg.Fake(target, nil, true) end
				end
			else
				MODE.MAForceUncon(target, 8)
			end
		end

		if category == "knockdown" and IsValid(target) and math.Rand(0, 1) < 0.6 then
			timer.Simple(0.8, function()
				dislocateMALimb(target)
			end)
		end

		return true
	end

    util.AddNetworkString("HMCD_MA_Move")
    util.AddNetworkString("HMCD_MA_MoveList")
    util.AddNetworkString("HMCD_MA_RequestList")

    -- Push the list of Martial Artist moves (id + display name) to the client.
    function MODE.SendMAMoveList(ply)
        local list = {}
        for _, m in ipairs(MODE.MAMoves) do
            if WWE and WWE.moves and WWE.moves[m.id] and ChudDragonStyle.CanUseMove(ply, m.id) then
                list[#list + 1] = m
            end
        end
        net.Start("HMCD_MA_MoveList")
        net.WriteUInt(#list, 8)
        for _, m in ipairs(list) do
            net.WriteString(m.id)
            net.WriteString(m.name)
            net.WriteString(m.dir)
        end
        net.Send(ply)
    end

    hook.Add("PlayerSpawn", "HMCD_MA_SendMoveList", function(ply)
        if OverrideSpawn then return end
		ply.MACooldowns = nil
		if ply.MAMeleeApplied then
			ply.MeleeDamageMul = nil
			ply.MAMeleeApplied = nil
		end
        if ChudDragonStyle and ChudDragonStyle.CanUse(ply) then
            CurrentRound().SendMAMoveList(ply)
        end
    end)

    -- Respond to a client request (covers any spawn-timing edge cases)
    net.Receive("HMCD_MA_RequestList", function(len, ply)
        if ChudDragonStyle and ChudDragonStyle.CanUse(ply) then
            CurrentRound().SendMAMoveList(ply)
        end
    end)

    -- Execute a z_wwe move on behalf of the Martial Artist.
    -- WWE.RunMove resolves the target via the attacker's aim and runs the move.
    net.Receive("HMCD_MA_Move", function(len, ply)
        if not (ChudDragonStyle and ChudDragonStyle.CanUse(ply)) then return end
        if not ply:Alive() then return end

        local moveId = net.ReadString()
		local active = CurrentRound()
        local _, target = active.GetPlayerTraceToOther(ply, nil, 160)
        active.RunMartialArtistMove(ply, moveId, target)
    end)
end

if CLIENT then
    MODE.WWEMoveList = MODE.WWEMoveList or {}

    net.Receive("HMCD_MA_MoveList", function()
        local n = net.ReadUInt(8)
        local MODE = CurrentRound()
        if not MODE then return end
        MODE.WWEMoveList = {}
        for i = 1, n do
            MODE.WWEMoveList[#MODE.WWEMoveList + 1] = {
                id = net.ReadString(),
                name = net.ReadString(),
                dir = net.ReadString(),
            }
        end
    end)

    -- returns the nearby living player we could perform a move on (or nil)
    local function MA_GetTarget()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return nil end
        local reach = 110
        local tr = util.TraceHull({
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:EyeAngles():Forward() * reach,
            mins = Vector(-14, -14, -14),
            maxs = Vector(14, 14, 14),
            filter = ply,
            mask = MASK_SHOT_HULL,
        })
        local ent = tr.Entity
        if IsValid(ent) and ent:IsPlayer() and ent ~= ply and ent:Alive() then
            return ent
        end
        return nil
    end

    -- MA moves are now triggered directly with Alt+E (see sv_subrole_abilities). Radial menu removed.
end
--//
