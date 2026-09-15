AddCSLuaFile()

function EFFECT:Init(data)
	self.Start = data:GetOrigin()
	self.Ang = data:GetAngles()

	self.Emitter = ParticleEmitter(self.Start)
	
	--for i = 1, 10 do
		local p = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Start)

		p:SetDieTime(math.Rand(1.5, 2))
		p:SetStartAlpha(55)
		p:SetEndAlpha(0)
		p:SetStartSize(10)
		p:SetEndSize(60)
		p:SetRoll(math.Rand(-2, 2))
		p:SetRollDelta(math.Rand(-2, 2))

		p:SetVelocity(Vector(math.random(-20, 20), math.random(-10, 10), 80))
		p:SetGravity(Vector(0, 0, -15))
		p:SetColor(0, 0, 0)
	--end
	
	self.Emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end





