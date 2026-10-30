include("shared.lua")

function ENT:Initialize()
    self.Emitter = ParticleEmitter(self:GetPos())
    self.NextGas = 0
    self:SetRenderBounds(Vector(-180, -180, -20), Vector(180, 180, 140))
end

function ENT:Draw() end

function ENT:Think()
    if not self.Emitter or CurTime() < self.NextGas then return end
    self.NextGas = CurTime() + 0.15
    local remaining = self:GetNWFloat("ExpiresAt", 0) - CurTime()
    if remaining <= 0 then return end
    for i = 1, 5 do
        local angle = math.Rand(0, math.pi * 2)
        local radius = math.sqrt(math.Rand(0, 1)) * 145
        local particle = self.Emitter:Add("particle/particle_smokegrenade",
            self:GetPos() + Vector(math.cos(angle) * radius, math.sin(angle) * radius, math.Rand(10, 55)))
        if particle then
            particle:SetVelocity(Vector(math.Rand(-5, 5), math.Rand(-5, 5), math.Rand(2, 8)))
            particle:SetDieTime(math.min(remaining, math.Rand(1.5, 2.5)))
            particle:SetStartAlpha(90)
            particle:SetEndAlpha(0)
            particle:SetStartSize(28)
            particle:SetEndSize(48)
            particle:SetRoll(math.Rand(0, 360))
            particle:SetColor(115, 145, 55)
            particle:SetCollide(true)
            particle:SetBounce(0)
            particle:SetLighting(true)
        end
    end
end

function ENT:OnRemove()
    if self.Emitter then self.Emitter:Finish() end
end
