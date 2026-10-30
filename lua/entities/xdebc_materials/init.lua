AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

function ENT:Initialize()
	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:SetResourceAmount( XDEBC_RESOURCE_PACK )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:Wake()
	end
end

function ENT:Use( ply )
	if !IsValid( ply ) or !ply:IsPlayer() then return end
	if ( self.XDEBC_NextUse or 0 ) > CurTime() then return end
	self.XDEBC_NextUse = CurTime() +0.25

	local cap = XDEBC_GetResourceCap( self.ResourceType )
	local current = XDEBC_GetPlayerResource( ply, self.ResourceType )
	if current >= cap then return end
	local amount = math.min( self:GetResourceAmount(), cap -current )
	local added = amount > 0 and XDEBC_AddPlayerResource( ply, self.ResourceType, amount ) or 0
	if added <= 0 then return end
	local remaining = self:GetResourceAmount() -added
	if remaining > 0 then
		self:SetResourceAmount( remaining )
	else
		self:Remove()
	end
end
