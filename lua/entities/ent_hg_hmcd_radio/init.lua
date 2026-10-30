AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    if SERVER then
        self:SetMoveType(MOVETYPE_VPHYSICS)
    end
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:DrawShadow(true)
    self:AddEFlags(EFL_IN_SKYBOX)
    
    local phys = self:GetPhysicsObject()

    if SERVER and IsValid(phys) then
        phys:SetMass(10)
        phys:Wake()
        phys:EnableMotion(true)
    end
end

hook.Add("OnEntityCreated", "radioCreate", function( ent )
	if ent:GetClass() == "ent_hg_hmcd_radio" then
		SetGlobalEntity("radio",ent)
	end
end)

util.AddNetworkString("RadioURLInput")
util.AddNetworkString("PlayRadioSound")
util.AddNetworkString("RadioChangeValue")
util.AddNetworkString("RadioChangeVolume")
util.AddNetworkString("RadioPause")
util.AddNetworkString("RadioStop")
util.AddNetworkString("RadioLooping")
util.AddNetworkString("paint_radio")

local function RadioCheckURL(url)
	return isstring(url) and #url <= 512 and (string.StartWith(url, "http://") or string.StartWith(url, "https://"))
end

net.Receive("RadioURLInput", function(len, ply)
	if (ply.cooldown_radurl or 0) > CurTime() then return end
	ply.cooldown_radurl = CurTime() + 1

	local url = net.ReadString()
	local ent = net.ReadEntity()
	
	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end
	if not RadioCheckURL(url) then return end

	net.Start("PlayRadioSound")
	net.WriteString(url)
	net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)

net.Receive("paint_radio", function(len, ply)
	if (ply.cooldown_radpaint or 0) > CurTime() then return end
	ply.cooldown_radpaint = CurTime() + 1

	local url = net.ReadString()
	local ent = net.ReadEntity()

	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end
	if not RadioCheckURL(url) then return end

	ent:SetTextureURL( url )

	
	net.Start("paint_radio")
		net.WriteString( url )
		net.WriteEntity( ent )
	net.Broadcast()
end)

net.Receive("RadioChangeValue", function(len, ply)
	if (ply.cooldown_radval or 0) > CurTime() then return end
	ply.cooldown_radval = CurTime() + 1

	local val = net.ReadFloat()
	if not isnumber(val) or val ~= val or math.abs(val) == math.huge then return end
	val = math.Clamp(val, 0, 86400)

	local index = net.ReadInt(32)
	if not isnumber(index) or index < 0 or index > game.MaxEntities() then return end
	local ent = Entity(index)

	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("RadioChangeValue")
	net.WriteFloat(val)
	net.WriteInt(index,32)
	net.Broadcast()
end)

net.Receive("RadioChangeVolume", function(len, ply)
	if (ply.cooldown_radvol or 0) > CurTime() then return end
	ply.cooldown_radvol = CurTime() + 1

	local val = net.ReadFloat()
	if not isnumber(val) or val ~= val or math.abs(val) == math.huge then return end
	val = math.Clamp(val, 0, 2)

	local index = net.ReadInt(32)
	if not isnumber(index) or index < 0 or index > game.MaxEntities() then return end
	local ent = Entity(index)
	
	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("RadioChangeVolume")
	net.WriteFloat(val)
	net.WriteInt(index,32)
	net.Broadcast()
end)

net.Receive("RadioPause", function(len, ply)
	if (ply.cooldown_radpause or 0) > CurTime() then return end
	ply.cooldown_radpause = CurTime() + 1

	local bool = net.ReadBool()
	local ent = net.ReadEntity()
	
	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end
	
	net.Start("RadioPause")
		net.WriteBool(bool)
		net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)

net.Receive("RadioLooping", function(len, ply)
	if (ply.cooldown_radloop or 0) > CurTime() then return end
	ply.cooldown_radloop = CurTime() + 1

	local bool = net.ReadBool()
	local ent = net.ReadEntity()

	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("RadioLooping")
		net.WriteBool(bool)
		net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)

net.Receive("RadioStop", function(len, ply)
	if (ply.cooldown_radstop or 0) > CurTime() then return end
	ply.cooldown_radstop = CurTime() + 1

	local ent = net.ReadEntity()

	if not IsValid(ply) then return end
	if not IsValid(ent) or ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("RadioStop")
		net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)