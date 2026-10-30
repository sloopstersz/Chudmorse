ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "#xdebc.EntitySupplyCrate"
ENT.Category = "#xdebc.Category"
ENT.Author = "garikdev"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Model = "models/props_junk/wood_crate001a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "MaterialsAmount" )
	self:NetworkVar( "Int", 1, "NailsAmount" )
end
