ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "#xdebc.EntityNails"
ENT.Category = "#xdebc.Category"
ENT.Author = "garikdev"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Model = "models/props_lab/box01a.mdl"
ENT.ResourceType = "Nails"

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "ResourceAmount" )
end
