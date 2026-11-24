-- AIRSTUCK + TICK MANIPULATION
-- Airstuck cheats stop the player's movement commands from reaching the server (or fake their tick
-- numbers), so the server never moves them: they hang in the air, then shoot from there.
--   * No commands for Gap seconds while the connection itself is fine and they're off the ground =
--     held movement. After Drop seconds they're put down on the ground below (prevention).
--   * For BlockFor seconds after the commands come back, their shots are removed (the backlog of
--     commands that arrives at once can't be used to shoot from the frozen spot) and their damage is blocked.
--   * Count incidents in the air: Count+ in Window seconds = flag + cheat-rating points + Discord.
--   * Commands stamped with a tick far in the future (tickbase / timing cheats) = flag + points.
-- A real lag spike can look like one incident (that's why it takes several, and never bans on its own).
local cfg = ZAC.Config
local C = cfg.AirStuck or {}
local SysTime = SysTime

local function canFloat(ply)
	if not ply:Alive() or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK then return false end
	if IsValid(ply.FakeRagdoll) or IsValid(ply:GetNWEntity("FakeRagdoll")) then return false end
	return true
end

local function dropToGround(ply)
	if ZAC.ManualOnly and ZAC.ManualOnly() then return nil end -- testing: only log, never move anyone
	local pos = ply:GetPos()
	local tr = util.TraceHull({
		start = pos, endpos = pos - Vector(0, 0, 8192),
		mins = ply:OBBMins(), maxs = ply:OBBMaxs(), filter = ply, mask = MASK_PLAYERSOLID,
	})
	if tr.StartSolid or not tr.Hit then return nil end
	ply:SetPos(tr.HitPos + Vector(0, 0, 1))
	ply:SetVelocity(-ply:GetVelocity())
	return pos.z - tr.HitPos.z
end

local function incident(ply, s, len)
	local now = SysTime()
	local list = ply.ZACStuckList or {}
	ply.ZACStuckList = list
	list[#list + 1] = now
	while list[1] and now - list[1] > (C.Window or 60) do table.remove(list, 1) end
	local text = string.format("held movement for %.1fs while %s%s%s", len, s.air and "in the air" or "on the ground",
		s.height and string.format(" (%.0fm off the ground, put back down)", s.height / 52.5) or "",
		s.lagging and " - their connection was also dropping packets (could be real lag)" or "")
	ZAC.Log("aim", ZAC.Who(ply) .. " " .. text .. "  (" .. #list .. " in " .. (C.Window or 60) .. "s)", nil, ply)
	local long = len >= (C.LongHold or 2.5) and not s.lagging
	if (#list >= (C.Count or 2) or long) and (ply.ZACStuckFlagNext or 0) < now then
		ply.ZACStuckFlagNext = now + (C.Cooldown or 60)
		local msg = long and string.format("held their movement for %.1fs %s (ping %d, connection fine)", len, s.air and "in the air" or "on the ground", ply:Ping())
			or string.format("%d airstuck incidents in %ds (ping %d)", #list, C.Window or 60, ply:Ping())
		if cfg.AlertAdmins then ZAC.AdminChat(ply:Nick() .. " may be using airstuck: " .. msg) end
		if ZAC.RatingEvidence then ZAC.RatingEvidence(ply, "airstuck", C.Points or 15, msg) end
		if ZAC.Discord then
			ZAC.Discord("Airstuck: " .. ply:Nick(), msg, ZAC.DiscordColors and ZAC.DiscordColors.orange, { ZAC.DiscordPlayerField(ply) })
		end
	end
end

hook.Add("StartCommand", "zac_airstuck", function(ply, cmd)
	if C.Enabled == false or ply:IsBot() then return end
	local now = SysTime()
	ply.ZACCmdT = now

	local s = ply.ZACStuck
	if s then
		-- commands are back
		ply.ZACStuck = nil
		local len = now - s.t0
		if s.air then
			ply.ZACNoShootUntil = now + (C.BlockFor or 0.75)
			if len >= (C.CountMin or 0.8) then incident(ply, s, len) end -- shorter hiccups aren't logged at all
		elseif len >= (C.GroundHold or 2) and not s.lagging then
			-- frozen on the ground with a fine connection (freeze / "fake lag" cheats)
			ply.ZACNoShootUntil = now + (C.BlockFor or 0.75)
			incident(ply, s, len)
		end
	end
	if (ply.ZACNoShootUntil or 0) > now then cmd:RemoveKey(bit.bor(IN_ATTACK, IN_ATTACK2)) end

	-- ticks stamped far in the future
	local tc = cmd:TickCount()
	if C.TickCheck ~= false and tc and tc > 0 and ply:Alive() then
		local ahead = tc - engine.TickCount()
		if ahead > (C.FutureTicks or 66) then
			local w = ply.ZACTickBad or { n = 0, t = now }
			if now - w.t > 3 then w.n, w.t = 0, now end
			w.n = w.n + 1
			ply.ZACTickBad = w
			if w.n >= (C.FutureCount or 20) and (ply.ZACTickFlagNext or 0) < now then
				ply.ZACTickFlagNext = now + (C.Cooldown or 60)
				local msg = string.format("sent %d commands stamped %d ticks in the future (tick manipulation)", w.n, ahead)
				ZAC.Log("aim", ZAC.Who(ply) .. " " .. msg, nil, ply)
				if cfg.AlertAdmins then ZAC.AdminChat(ply:Nick() .. " " .. msg) end
				if ZAC.RatingEvidence then ZAC.RatingEvidence(ply, "tickbase", C.TickPoints or 20, msg) end
				if ZAC.Discord then ZAC.Discord("Tick manipulation: " .. ply:Nick(), msg, ZAC.DiscordColors and ZAC.DiscordColors.red, { ZAC.DiscordPlayerField(ply) }) end
			end
		end
	end
end)

timer.Create("zac_airstuck", 0.1, 0, function()
	if C.Enabled == false then return end
	local now = SysTime()
	for _, ply in player.Iterator() do
		local last = ply.ZACCmdT
		if last and not ply:IsBot() then
			local gap = now - last
			local s = ply.ZACStuck
			if not s and gap >= (C.Gap or 0.5) and canFloat(ply) then
				s = { t0 = last, air = not ply:IsOnGround(), lagging = ply:IsTimingOut() }
				ply.ZACStuck = s
			end
			if s and not s.lagging and ply:IsTimingOut() then s.lagging = true end -- real lag at any point = not counted as long
			if s and s.air and not s.dropped and gap >= (C.Drop or 1) and canFloat(ply) then
				s.dropped = true
				s.height = dropToGround(ply)
			end
		end
	end
end)

-- backup: no bullets / damage from a player while held or just after
hook.Add("EntityFireBullets", "zac_airstuck", function(ent)
	local owner = ent
	if IsValid(ent) and ent:IsWeapon() then owner = ent:GetOwner() end
	if IsValid(owner) and owner:IsPlayer() and ((owner.ZACStuck and owner.ZACStuck.air) or (owner.ZACNoShootUntil or 0) > SysTime()) then return false end
end)
hook.Add("EntityTakeDamage", "zac_airstuck", function(_, dmg)
	local a = dmg:GetAttacker()
	if IsValid(a) and not a:IsPlayer() and IsValid(a:GetOwner()) and a:GetOwner():IsPlayer() then a = a:GetOwner() end
	if IsValid(a) and a:IsPlayer() and ((a.ZACStuck and a.ZACStuck.air) or (a.ZACNoShootUntil or 0) > SysTime()) then return true end
end)

hook.Add("PlayerSpawn", "zac_airstuck", function(ply) ply.ZACStuck, ply.ZACNoShootUntil = nil, nil end)
