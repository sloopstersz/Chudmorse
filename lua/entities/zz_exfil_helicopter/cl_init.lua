include("shared.lua")
function ENT:Draw() self:DrawModel() end
function ENT:FireAnimationEvent() return true end
