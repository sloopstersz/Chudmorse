AddCSLuaFile()

local ImmunePlayers = {}

-- 給予無敵旗標
function GiveExplosionImmunity(ply, duration)
	if not IsValid(ply) then return end
	ImmunePlayers[ply] = true

	timer.Simple(duration, function()
		if IsValid(ply) then
			ImmunePlayers[ply] = nil
		end
	end)
end

-- 攔截爆炸傷害
hook.Add("EntityTakeDamage", "ExplosionSelfImmunity", function(target, dmg)
	if not IsValid(target) or not target:IsPlayer() then return end
	if not ImmunePlayers[target] then return end

	if dmg:IsExplosionDamage() then
		-- 可加條件進一步限制來源
		dmg:SetDamage(0)
		return true -- 完全忽略
	end
end)

if SERVER then
    util.PrecacheSound("kamikaze/cod_mw_blip1.wav")
end