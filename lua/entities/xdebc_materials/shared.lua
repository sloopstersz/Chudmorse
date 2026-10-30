ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "#xdebc.EntityMaterials"
ENT.Category = "#xdebc.Category"
ENT.Author = "garikdev"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Model = "models/props_junk/cardboard_box004a.mdl"
ENT.ResourceType = "Materials"

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "ResourceAmount" )
end
