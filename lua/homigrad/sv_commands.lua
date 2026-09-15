COMMANDS = COMMANDS or {}

local validUserGroupSuperAdmin = {
	superadmin = true,
}

local validUserGroup = {
	admin = true,
}

function COMMAND_GETACCES(ply)
	if ply == Entity(0) then return 2 end

	local group = ply:GetUserGroup()
	if validUserGroup[group] then
		return 1
	elseif validUserGroupSuperAdmin[group] then
		return 2
	end

	return 0
end

function COMMAND_ACCES(ply,cmd)
	local access = cmd[2] or 1
	if access ~= 0 and COMMAND_GETACCES(ply) < access then return end

	return true
end

function COMMAND_GETARGS(args)
	local newArgs = {}
	local waitClose,waitCloseText

	for i,text in pairs(args) do
		if not waitClose and string.sub(text,1,1) == "\"" then
			waitClose = true

			if string.sub(text,#text,#text) == "\n" then
				newArgs[#newArgs + 1] = string.sub(text,2,#text - 1)

				waitClose = nil
			else
				waitCloseText = string.sub(text,2,#text)
			end

			continue
		end

		if waitClose then
			if string.sub(text,#text,#text) == "\"" then
				waitClose = nil

				newArgs[#newArgs + 1] = waitCloseText .. string.sub(text,1,#text - 1)
			else
				waitCloseText = waitCloseText .. string.sub(text,1,#text)
			end

			continue
		end

		newArgs[#newArgs + 1] = text
	end

	return newArgs
end

function COMMAND_Input(ply,args)
	local cmd = COMMANDS[args[1]]
	if not cmd then return false end
	if not COMMAND_ACCES(ply,cmd) then return true,false end

	table.remove(args,1)

	return true,cmd[1](ply,args)
end
-- Мдаааа А ПЛЕЙРСЕЙ ДЛЯ КОГО НУЖЕН????
hook.Add("HG_PlayerSay","commands-chat",function(ply, txtTbl, text)
	COMMAND_Input(ply, COMMAND_GETARGS(string.Split(string.sub(text, 2, #text), " ")))
end)

COMMANDS.help = {function(ply,args)
	local text = ""

	if args[1] then
		local cmd = COMMANDS[args[1]]
		local argsList = cmd[3]
		if argsList then argsList = " - " .. argsList else argsList = "" end

		text = text .. "	" .. args[1] .. argsList .. "\n"
	else
		local list = {}
		for name in pairs(COMMANDS) do list[#list + 1] = name end
		table.sort(list,function(a,b) return a > b end)
        
		for _,name in pairs(list) do
			local cmd = COMMANDS[name]
            if not COMMAND_ACCES(ply,cmd) then continue end
            
			local argsList = cmd[3]
			if argsList then argsList = " - " .. argsList else argsList = "" end
            
			text = text .. "	" .. name .. argsList .. "\n"
		end
	end

	text = string.sub(text,1,#text - 1)

	ply:ChatPrint(text)
end,0}

if SERVER then
    util.AddNetworkString("PunishLightningEffect")
    util.AddNetworkString("AnotherLightningEffect")
    util.AddNetworkString("PluvCommand")

    COMMANDS.zc_god = {function(ply)
        if not ply.organism then return end
        
        ply.organism.godmode = !ply.organism.godmode
		ply:Notify(ply.organism.godmode and "now i'm immortal..." or "now i'm mortal")
		return
    end,1}

	COMMANDS.zc_cloak = {function(ply)
        if not ply.organism then return end
		ply.cloak = !ply.cloak
        ply:SetMaterial(ply.cloak and "NULL" or nil)
		ply:DrawShadow(!ply.cloak)
		ply:SetCollisionGroup(ply.cloak and COLLISION_GROUP_DEBRIS or COLLISION_GROUP_PLAYER)
		ply:RemoveAllDecals()
		ply:Notify(ply.cloak and "now i'm invisible..." or "now i'm visible") -- walking by the wall
		return
    end,1}

    COMMANDS.punish = {function(ply, args)
        if #args < 1 then
            ply:ChatPrint("Give me the name of this OwO .")
            return
        end

        local targetNickPartial = string.lower(args[1]) 
        local target = nil
        for _, player in player.Iterator() do
            if string.find(string.lower(player:Nick()), targetNickPartial) then 
                target = player
                break
            end
        end

        if not IsValid(target) then
            ply:ChatPrint("I don't see that OwO .")
            return
        end

        target = hg.GetCurrentCharacter(target)

        net.Start("AnotherLightningEffect")
        net.WriteEntity(target)
        net.Broadcast()

        net.Start("PunishLightningEffect")
        net.WriteEntity(target)
        net.Broadcast()

        target:EmitSound("snd_jack_hmcd_lightning.wav")

        local dmg = DamageInfo()
        dmg:SetDamage(1000)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SHOCK)
        target:TakeDamageInfo(dmg)

        ply:ChatPrint("Fatass " .. target:Nick() .. " has been punished.")
    end, 2, "ник игрока"}

    COMMANDS.pluv = {function(ply, args)
        net.Start("PluvCommand")
        net.Send(ply)
    end, 0}

    COMMANDS.notify = {function(ply, args)
        if #args < 2 then
            ply:ChatPrint("Usage: !notify <player> <message>")
            return
        end

        local targetNickPartial = string.lower(args[1]) 
        local target = nil
        for _, player in player.Iterator() do
            if string.find(string.lower(player:Nick()), targetNickPartial) then 
                target = player
                break
            end
        end

        if not IsValid(target) then
            ply:ChatPrint("Player not found: " .. args[1])
            return
        end
        
        table.remove(args, 1) 
        local message = table.concat(args, " ")
        
        if message == "" then
            ply:ChatPrint("Message cannot be empty!")
            return
        end
        
        target:Notify(message, 0)
        ply:ChatPrint("Sent notification to " .. target:GetName() .. ": " .. message)

    end, 2, "name; message"}

local VIP_MODEL_WHITELIST = {
		["models/gacommissions/tungtungtungsahur.mdl"] = true,
		["models/nikita488/player/joker.mdl"] = true,
		["models/blop/expie/expie.mdl"] = true,
		["models/player/skeleton.mdl"] = true,
		["models/player/big_boss.mdl"] = true,
		["models/tctgosling.mdl"] = true,
		["models/player/corpse1.mdl"] = true,
		["models/player/charple.mdl"] = true,
		["models/player/amir/amir_v2.mdl"] = true,
		["models/splinks/hotline_miami/jacket/player_jacket.mdl"] = true,
		["models/player/vin_diesel/slow.mdl"] = true,
		["models/cheddar/cyberpunk/trauma_team/tt_pilot.mdl"] = true,
		["models/cheddar/cyberpunk/trauma_team/tt_medic.mdl"] = true,
		["models/cheddar/cyberpunk/trauma_team/tt_guard.mdl"] = true,
		["models/dannio/pm/rizzler_costco.mdl"] = true,
		["models/player/efeber/tonysop.mdl"] = true,
		["models/player/spook01/male_01.mdl"] = true,
		["models/dannio/pm/aj_costco.mdl"] = true,
		["models/player/h3_masterchief_player.mdl"] = true,
		["models/deadspace2023/dsrisaaclv3.mdl"] = true,
		["models/pechenko_121/doomslayerfull.mdl"] = true,
		["models/player/group01/clark_playermodel.mdl"] = true,
		["models/bindycot/player/po.mdl"] = true,
		["models/player/ntwffelixkranken.mdl"] = true,
		["models/i6nis/freddy_player.mdl"] = true,
        ["models/i6nis/bonnie_player.mdl"] = true,
        ["models/i6nis/chica_player.mdl"] = true,
        ["models/i6nis/foxy_player.mdl"] = true
	}

	local function NormalizeSetModelPath(mdl)
		mdl = string.Trim(string.lower(tostring(mdl or "")))
		mdl = string.Replace(mdl, "\\", "/")
		return mdl
	end

	local function FindZCityAppearanceModel(mdl)
		mdl = NormalizeSetModelPath(mdl)
		if not hg or not hg.Appearance or not hg.Appearance.PlayerModels then return nil end

		for sex = 1, 2 do
			for appearanceName, data in pairs(hg.Appearance.PlayerModels[sex] or {}) do
				if istable(data) and NormalizeSetModelPath(data.mdl) == mdl then
					return appearanceName, data
				end
			end
		end
	end

	local function SaveSetModelOriginalAppearance(ply)
		if ply.ChudSetModelOriginalAppearance then return end

		if ply.CurAppearance then
			ply.ChudSetModelOriginalAppearance = table.Copy(ply.CurAppearance)
		end

		ply.ChudSetModelOriginalModel = ply:GetModel()
	end

	local function RestoreSetModelAppearance(ply)
		if not IsValid(ply) then return false end
		if not hg or not hg.Appearance or not hg.Appearance.ForceApplyAppearance then return false end

		local appearance = ply.ChudSetModelOriginalAppearance or ply.CurAppearance
		if not appearance then return false end

		hg.Appearance.ForceApplyAppearance(ply, table.Copy(appearance))

		ply.ChudSetModelOriginalAppearance = nil
		ply.ChudSetModelOriginalModel = nil
		return true
	end

	local function IsUsableZCityRagdollModel(mdl)
		if not util.IsValidModel(mdl) then
			return false, "That model is invalid or is not installed on the server."
		end

		-- Z-City creates player ragdolls constantly. A model without ragdoll physics
		-- can make the player invisible/broken and causes C_ServerRagdoll errors.
		if util.IsValidRagdoll and not util.IsValidRagdoll(mdl) then
			return false, "That model is not Z-City compatible because it has no valid ragdoll physics."
		end

		return true
	end

	local function ApplyTemporaryZCityModel(ply, mdl)
		local appearanceName = FindZCityAppearanceModel(mdl)
		if not appearanceName then return false end

		SaveSetModelOriginalAppearance(ply)

		local originalAppearance = ply.ChudSetModelOriginalAppearance or ply.CurAppearance
		local temporaryAppearance = originalAppearance and table.Copy(originalAppearance) or hg.Appearance.GetRandomAppearance()
		temporaryAppearance.AModel = appearanceName

		-- Apply the model using Z-City's own appearance code so clothes/submaterials
		-- are correct, then keep the original appearance saved for !setmodel default.
		hg.Appearance.ForceApplyAppearance(ply, temporaryAppearance)
		if originalAppearance then
			ply.CurAppearance = table.Copy(originalAppearance)
		end

		return true
	end

	local function ApplyTemporaryCustomModel(ply, mdl)
		SaveSetModelOriginalAppearance(ply)

		-- Do not edit CurAppearance/AClothes/AAttachments. Those are the player's
		-- normal Z-City appearance and are needed to restore them later.
		ply:SetModel(mdl)
		ply:SetSubMaterial()

		if ply.SetSkin then
			ply:SetSkin(0)
		end

		for _, bodygroup in ipairs(ply:GetBodyGroups() or {}) do
			ply:SetBodygroup(bodygroup.id or 0, 0)
		end

		-- Accessories from the normal Z-City model can be attached to incompatible
		-- bones on custom playermodels. Hide them temporarily; default restores them.
		ply:SetNetVar("Accessories", {})
	end

	COMMANDS.setmodel = {function(ply, args)
		local group = string.lower(ply:GetUserGroup() or "user")
		local isVIP = group == "vip"
		local isAdmin = ply:IsAdmin()

		if not isVIP and not isAdmin then
			ply:ChatPrint("You do not have permission to use this command.")
			return
		end

		if not args[1] then
			ply:ChatPrint("Usage: !setmodel <model/default> OR !setmodel <player> <model/default>")
			return
		end

		local target = ply
		local requestedModel = args[1]

		-- Admins can target another player. VIPs can only target themselves.
		if isAdmin and #args > 1 then
			local matches = player.GetListByName(args[1])
			target = matches and matches[1] or nil
			requestedModel = args[2]

			if not IsValid(target) then
				ply:ChatPrint("Player not found: " .. tostring(args[1]))
				return
			end
		end

		if not IsValid(target) or not target:Alive() then
			ply:ChatPrint("The player must be alive to change models.")
			return
		end

		local mdl = NormalizeSetModelPath(requestedModel)

		if mdl == "default" then
			if RestoreSetModelAppearance(target) then
				ply:ChatPrint(target == ply and "Your normal Z-City appearance was restored." or (target:Name() .. "'s normal Z-City appearance was restored."))
			else
				ply:ChatPrint("Could not restore the normal Z-City appearance.")
			end
			return
		end

		local zcityAppearanceName = FindZCityAppearanceModel(mdl)

		-- VIPs may use only explicitly whitelisted custom models or the built-in
		-- models registered by Z-City's appearance system.
		if not isAdmin and not VIP_MODEL_WHITELIST[mdl] and not zcityAppearanceName then
			ply:ChatPrint("That model is not available for VIPs.")
			return
		end

		local usable, reason = IsUsableZCityRagdollModel(mdl)
		if not usable then
			ply:ChatPrint(reason)
			return
		end

		if zcityAppearanceName then
			ApplyTemporaryZCityModel(target, mdl)
		else
			ApplyTemporaryCustomModel(target, mdl)
		end

		ply:ChatPrint((target == ply and "Your model was set to " or (target:Name() .. "'s model was set to ")) .. mdl)
	end, 0}

	--// Aliases
	COMMANDS.model = COMMANDS.setmodel
	COMMANDS.playermodel = COMMANDS.setmodel
	COMMANDS.setplayermodel = COMMANDS.setmodel
end