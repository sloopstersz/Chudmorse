local CLASS = player.RegClass("VICTIM")
 
function CLASS.Off(self)
    if CLIENT then return end
end

 
 
function CLASS.On(self)
    if CLIENT then return end
    ApplyAppearance(self,nil,nil,nil,true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    self:SetNWString("PlayerName","")
    self:SetPlayerColor(Color(255,0,0):ToVector())
    self:SetModel(models[math.random(#models)])
    Appearance.AAttachments = "none"
    self:SetNetVar("Accessories", Appearance.AAttachments or "yes")
    self:SetBodygroup(0,9)
 
    self:SetSubMaterial()
    Appearance.AColthes = ""

        
    
    
    self.CurAppearance = Appearance
end