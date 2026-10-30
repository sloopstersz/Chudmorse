AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

function ENT:Initialize()
	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local materialCvar = GetConVar( "xdebc_crate_materials" )
	local nailCvar = GetConVar( "xdebc_crate_nails" )
	self:SetMaterialsAmount( materialCvar and materialCvar:GetInt() or XDEBC_SUPPLY_CRATE_MATERIALS )
	self:SetNailsAmount( nailCvar and nailCvar:GetInt() or XDEBC_SUPPLY_CRATE_NAILS )
	if self:GetMaterialsAmount() <= 0 and self:GetNailsAmount() <= 0 then
		self:Remove()
		return
	end

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:Wake()
	end
end

function ENT:Use( ply )
	if !IsValid( ply ) or !ply:IsPlayer() then return end
	if ( self.XDEBC_NextUse or 0 ) > CurTime() then return end
	self.XDEBC_NextUse = CurTime() +0.25

	local materials = self:GetMaterialsAmount()
	local nails = self:GetNailsAmount()
	local addedMaterials = 0
	local addedNails = 0

	if materials > 0 then
		addedMaterials = XDEBC_AddPlayerResource( ply, "Materials", materials )
	end
	if nails > 0 then
		addedNails = XDEBC_AddPlayerResource( ply, "Nails", nails )
	end
	if addedMaterials <= 0 and addedNails <= 0 then return end

	self:SetMaterialsAmount( materials -addedMaterials )
	self:SetNailsAmount( nails -addedNails )
	ply:EmitSound( "items/ammo_pickup.wav", 65, 100, 0.6, CHAN_ITEM )

	if self:GetMaterialsAmount() <= 0 and self:GetNailsAmount() <= 0 then
		self:Remove()
	end
end
