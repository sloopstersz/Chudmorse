AddCSLuaFile()

function EFFECT:Init(data)
	self.Start = data:GetOrigin()

	self.Emitter = ParticleEmitter(self.Start)
	
	for i = 1, math.random(20, 100) do
		local vec = VectorRand()
		local p = self.Emitter:Add("effects/fleck_cement" .. math.random(1, 2), self.Start)

		p:SetDieTime(math.random(1, 15))
		p:SetStartAlpha(math.random(50, 255))
		p:SetEndAlpha(0)
		p:SetStartSize(1)
		p:SetRoll(math.Rand(-10, 10))
		p:SetRollDelta(math.Rand(-10, 10))
		p:SetEndSize(0)		
		p:SetVelocity(vec * 50)
		p:SetGravity(Vector(0, 0, math.random(-600, -200)))
		p:SetCollide(true)
		p:SetColor(0, 0, 0)
	end
	
	self.Emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end





