-- AUTO SCREENGRABS: when someone's rating goes up to SUSPECT or CHEATING (sv_rating.lua), ZAC quietly
-- takes a few screengrabs of them at random moments while they're in a raid, so admins have evidence
-- to look through later (ZAC menu -> SCREENGRABS, "by" shows "Auto (SUSPECT)" / "Auto (CHEATING)").
-- Also runs at the start of each raid for anyone already rated SUSPECT or worse.
--   SUSPECT: 2 grabs   CHEATING: 3 grabs   spread over 30s - 5 min, at most once every 20 min per player.
local CFG = { Shots = { [2] = 2, [3] = 3 }, MinDelay = 30, MaxDelay = 300, Cooldown = 20 * 60 }
local LEVEL_NAME = { "LEGIT", "SUSPECT", "CHEATING" }

local function inRaid(ply) return ply:GetNWBool("ext_inraid", true) end -- outside the extract mode: always
local function levelOf(ply)
	local p = ZAC.Ratings and ZAC.Ratings[ply:SteamID()]
	return p and tonumber(p.level) or 1
end

local function schedule(ply, level)
	if not (IsValid(ply) and not ply:IsBot()) then return end
	if (ply.ZACAutoSGNext or 0) > CurTime() then return end
	ply.ZACAutoSGNext = CurTime() + CFG.Cooldown
	local n = CFG.Shots[level] or 0
	local label = "Auto (" .. (LEVEL_NAME[level] or "?") .. ")"
	ZAC.Log("screen", "Auto screengrabs scheduled for " .. ZAC.Who(ply) .. " (" .. n .. ", rated " .. (LEVEL_NAME[level] or "?") .. ")", nil, ply)
	for i = 1, n do
		local id = "zac_autosg_" .. ply:SteamID64() .. "_" .. i
		timer.Create(id, math.Rand(CFG.MinDelay, CFG.MaxDelay), 1, function()
			if not (IsValid(ply) and ply:Alive() and inRaid(ply)) then
				-- not in a raid right now: try once more a bit later
				timer.Create(id, 60, 1, function()
					if IsValid(ply) and ply:Alive() and inRaid(ply) then ZAC.Screengrab(nil, ply, label) end
				end)
				return
			end
			ZAC.Screengrab(nil, ply, label)
		end)
	end
	for _, a in player.Iterator() do
		if ZAC.IsAdmin(a) then a:PrintMessage(HUD_PRINTCONSOLE, "[AC] Auto screengrabs scheduled for " .. ply:Nick() .. " (rated " .. (LEVEL_NAME[level] or "?") .. ")") end
	end
end

hook.Add("ZACRatingRaised", "zac_autosg", function(ply, level)
	if level >= 2 then schedule(ply, level) end
end)
hook.Add("ExtractRaidStart", "zac_autosg", function()
	timer.Simple(5, function()
		for _, ply in player.Iterator() do
			local lv = levelOf(ply)
			if lv >= 2 and inRaid(ply) then schedule(ply, lv) end
		end
	end)
end)
