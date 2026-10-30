AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

ENT.RemoveOnPress = false
ENT.Model = Model("models/weapons/w_bugbait.mdl")

local function IsTraitorPlayer(ply)
    return ChudTechnicianTraps and ChudTechnicianTraps.CanAct(ply)
end

function ENT:Initialize()
	self:SetModel(self.Model)
	self:SetNoDraw(true)
	self:DrawShadow(false)
	self:SetSolid(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)

	self:SetDelay(self.RawDelay or 1)

	if self:GetDelay() < 0 then
		self.RemoveOnPress = true
	end

	if self.RemoveOnPress then
		self:SetDelay(-1)
	end

	if self:GetUsableRange() < 1 then
		self:SetUsableRange(1024)
	end

	self:SetNextUseTime(0)
	self:SetLocked(self:HasSpawnFlags(2048))
	self:SetDescription(self.RawDescription or "Trap")

	self.RawDelay = nil
	self.RawDescription = nil
end

function ENT:KeyValue(key, value)
	if key == "OnPressed" then
		self:StoreOutput(key, value)
	elseif key == "wait" then
		self.RawDelay = tonumber(value)
	elseif key == "description" then
		self.RawDescription = tostring(value)
		if self.RawDescription and #self.RawDescription < 1 then
			self.RawDescription = nil
		end
	elseif key == "RemoveOnPress" then
		self[key] = tobool(value)
	else
		self:SetNetworkKeyValue(key, value)
	end
end

function ENT:AcceptInput(name, activator)
	if name == "Toggle" then
		self:SetLocked(not self:GetLocked())
		return true
	elseif name == "Hide" or name == "Lock" then
		self:SetLocked(true)
		return true
	elseif name == "Unhide" or name == "Unlock" then
		self:SetLocked(false)
		return true
	end
end

-- Keep the legacy console entry point subject to the same tablet validation.
function ENT:TraitorUse(ply)
    return ChudTechnicianTraps and ChudTechnicianTraps.TryActivateTrap
        and ChudTechnicianTraps.TryActivateTrap(ply, self) or false
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

local function TraitorUseCmd(ply, _, args)
	if #args ~= 1 or not IsValid(ply) or not IsTraitorPlayer(ply) then return end

	local idx = tonumber(args[1])
	if not idx then return end

	local ent = Entity(idx)
	if IsValid(ent) and ent:GetClass() == "ttt_traitor_button" and ent.TraitorUse then
		ent:TraitorUse(ply)
	end
end

concommand.Add("ttt_use_tbutton", TraitorUseCmd)
