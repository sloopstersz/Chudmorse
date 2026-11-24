-- Speedhack check: a client running faster than real time sends more movement commands per
-- second than the server tickrate. A lag spike gives a burst, but it's paid back by the gap
-- before it, so we look at the total over a several-second window, not single seconds.
local cfg = ZAC.Config
local S = cfg.SpeedCheck or {}
local tick = 1 / engine.TickInterval()
local SysTime = SysTime

hook.Add("StartCommand", "zac_speed", function(ply)
	if ply:IsBot() then return end
	ply.ZACCmdN = (ply.ZACCmdN or 0) + 1
end)

timer.Create("zac_speed", 1, 0, function()
	if S.Enabled == false then return end
	local now = SysTime()
	for _, ply in player.Iterator() do
		if not ply:IsBot() then
			local n = ply.ZACCmdN or 0
			ply.ZACCmdN = 0
			local last = ply.ZACCmdLast or now
			ply.ZACCmdLast = now
			local hist = ply.ZACCmdHist or {}
			ply.ZACCmdHist = hist
			hist[#hist + 1] = { n, now - last }
			while #hist > (S.Window or 6) do table.remove(hist, 1) end

			if #hist >= (S.Window or 6) and ply:Alive() and not ply:IsTimingOut() then
				local cmds, secs = 0, 0
				for _, h in ipairs(hist) do cmds, secs = cmds + h[1], secs + h[2] end
				local rate = secs > 0 and cmds / secs or 0
				if rate > tick * (S.Ratio or 1.2) and (ply.ZACSpeedNext or 0) < now then
					ply.ZACSpeedNext = now + (S.Cooldown or 30)
					local pct = math.Round(rate / tick * 100)
					ZAC.Log("aim", string.format("%s is sending %d%% of the normal movement rate (%.0f/s, server tick %d) - possible speedhack",
						ZAC.Who(ply), pct, rate, tick), nil, ply)
					if cfg.AlertAdmins then ZAC.AdminChat(ply:Nick() .. " may be speedhacking (" .. pct .. "% movement rate)") end
					if ZAC.RatingEvidence then
						ZAC.RatingEvidence(ply, "speed", S.Points or 12, string.format("movement rate %d%% of normal for %ds", pct, #hist))
					end
				end
			end
		end
	end
end)
