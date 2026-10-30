if not SERVER then return end

RemorseNetGuard = RemorseNetGuard or {}

local NG = RemorseNetGuard

local CurTime = CurTime
local IsValid = IsValid
local istable = istable
local isstring = isstring
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local Round = math.Round
local sort = table.sort

local TAG = "[RemorseNetGuard] "

local cvInterval = CreateConVar("rem_netguard_report_interval", "0", FCVAR_ARCHIVE, TAG .. "automatically print a report every n seconds, 0 disables it", 0, 3600)
local cvTop = CreateConVar("rem_netguard_report_top", "15", FCVAR_ARCHIVE, TAG .. "rows printed per report section", 1, 200)
local cvMinRate = CreateConVar("rem_netguard_report_min_rate", "1", FCVAR_ARCHIVE, TAG .. "hide players below this many messages per second in volume reports", 0, 100000)

local incidents = {}

local function Allowed(ply)
	return not IsValid(ply) or ply:IsSuperAdmin()
end

local function FmtKb(bytes)
	return tostring(Round((tonumber(bytes) or 0) / 1024, 1)) .. "KB"
end

local function FmtRate(value)
	return tostring(Round(tonumber(value) or 0, 1))
end

function NG.Snapshot(minRate)
	local rows = {}
	local floorRate = tonumber(minRate) or 0

	for _, ply in ipairs(player.GetAll()) do
		local state = ply.rem_netguard

		if istable(state) then
			if state.lastRate >= floorRate or state.lastDropped > 0 or state.totalDropped > 0 then
				rows[#rows + 1] = {
					ply = ply,
					name = ply:Name(),
					steamid = ply:SteamID64(),
					rate = state.lastRate,
					bytes = state.lastBytes,
					dropped = state.lastDropped,
					totalDropped = state.totalDropped,
					totalSent = state.totalSent,
					worst = state.lastWorst,
					worstRate = state.lastWorstCount,
					muted = state.muted,
					throttled = state.totalDropped > 0,
					uptime = CurTime() - state.started,
					msgs = state.msgs,
				}
			end
		end
	end

	sort(rows, function(a, b)
		if a.rate ~= b.rate then return a.rate > b.rate end
		return a.dropped > b.dropped
	end)

	return rows
end

local function Section(title, rows, limit, format)
	print(TAG .. title)

	if #rows == 0 then
		print(TAG .. "  nothing to show")
		return
	end

	local shown = 0

	for _, row in ipairs(rows) do
		if shown >= limit then break end

		shown = shown + 1
		print(TAG .. "  #" .. shown .. " " .. format(row))
	end
end

local function MessageRows(rows, limit)
	local list = {}

	for _, row in ipairs(rows) do
		if istable(row.msgs) then
			local list2 = {}

			for name, bucket in pairs(row.msgs) do
				local count = tonumber(bucket.lastW) or 0

				if count > 0 then
					list2[#list2 + 1] = { name = name, count = count }
				end
			end

			sort(list2, function(a, b)
				return a.count > b.count
			end)

			for _, entry in ipairs(list2) do
				list[#list + 1] = {
					ply = row,
					name = entry.name,
					count = entry.count,
				}
			end
		end
	end

	sort(list, function(a, b)
		return a.count > b.count
	end)

	if #list > limit then
		for i = limit + 1, #list do
			list[i] = nil
		end
	end

	return list
end

function NG.Report(reason)
	local rows = NG.Snapshot(cvMinRate:GetFloat())
	local limit = cvTop:GetInt()
	local enabled = GetConVar("rem_netguard_enabled"):GetBool()
	local observe = GetConVar("rem_netguard_observe"):GetBool()

	print(TAG .. "report: " .. tostring(reason or "manual") .. " | " .. #rows .. " tracked | limiter " .. (enabled and (observe and "observing" or "enforcing") or "disabled"))

	Section("volume", rows, limit, function(row)
		return row.name .. " [" .. row.steamid .. "] | " .. FmtRate(row.rate) .. " msg/s | " .. FmtKb(row.bytes) .. "/s | " .. FmtRate(row.dropped) .. " dropped/s | " .. row.totalSent .. " sent | " .. row.totalDropped .. " dropped total"
	end)

	local offenders = {}

	for _, row in ipairs(rows) do
		if row.throttled then offenders[#offenders + 1] = row end
	end

	Section("offenders", offenders, limit, function(row)
		return row.name .. " [" .. row.steamid .. "] | " .. row.totalDropped .. " dropped | worst " .. tostring(row.worst or "unknown") .. " (" .. FmtRate(row.worstRate) .. "/s) | " .. (row.muted and "throttled" or "limiting")
	end)

	Section("hottest messages", MessageRows(rows, limit), limit, function(row)
		return row.ply.name .. " -> " .. row.name .. " | " .. row.count .. " msg/s"
	end)

	Section("incidents", incidents, limit, function(row)
		return row.name .. " [" .. row.steamid .. "] | " .. row.name_msg .. " | " .. row.dropped .. " dropped total"
	end)
end

function NG.ResetReport()
	incidents = {}
end

hook.Add("RemorseNetGuardViolation", "RemorseNetGuard_Report", function(ply, name, dropped, state)
	if not IsValid(ply) then return end

	incidents[#incidents + 1] = {
		name = ply:Name(),
		steamid = ply:SteamID64(),
		name_msg = name,
		dropped = dropped,
		jitter = Round(tonumber(state and state.jitter) or 1, 3),
		muted = state and state.muted or false,
	}

	local limit = math.max(cvTop:GetInt() * 2, 10)

	while #incidents > limit do
		table.remove(incidents, 1)
	end
end)

concommand.Add("rem_netguard_report", function(ply)
	if not Allowed(ply) then return end

	NG.Report("manual")
end)

concommand.Add("rem_netguard_limits", function(ply)
	if not Allowed(ply) then return end

	print(TAG .. "active limits")

	for _, key in ipairs({
		"rem_netguard_enabled",
		"rem_netguard_observe",
		"rem_netguard_msg_rate",
		"rem_netguard_msg_burst",
		"rem_netguard_total_rate",
		"rem_netguard_total_burst",
		"rem_netguard_byte_rate",
		"rem_netguard_byte_burst",
		"rem_netguard_grace",
		"rem_netguard_jitter",
		"rem_netguard_exempt_admins",
		"rem_netguard_penalty",
		"rem_netguard_penalty_drops",
		"rem_netguard_penalty_time",
		"rem_netguard_strikes",
		"rem_netguard_mute_time",
		"rem_netguard_presets",
	}) do
		local cv = GetConVar(key)

		if cv then
			print(TAG .. "  " .. key .. " = " .. cv:GetString())
		end
	end

	local names = {}

	for name in pairs(NG.limits) do
		names[#names + 1] = name
	end

	sort(names)

	if #names == 0 then
		print(TAG .. "  per message overrides: none")
	else
		for _, name in ipairs(names) do
			local entry = NG.limits[name]

			print(TAG .. "  " .. (entry.preset and "preset " or "override ") .. name .. " = " .. tostring(entry.rate) .. "/s burst " .. tostring(entry.burst))
		end
	end
end)

concommand.Add("rem_netguard_presets", function(ply)
	if not Allowed(ply) then return end

	NG.ApplyPresets()

	print(TAG .. "presets " .. (GetConVar("rem_netguard_presets"):GetBool() and "applied" or "cleared"))
end)

concommand.Add("rem_netguard_reset", function(ply, args)
	if not Allowed(ply) then return end

	local target

	if isstring(args and args[1]) and args[1] ~= "" then
		target = player.GetByID(args[1]) or Player(args[1])
	end

	if not IsValid(target) then
		target = ply
	end

	if not IsValid(target) then return end

	target.rem_netguard = nil
	NG.GetState(target)

	print(TAG .. "counters reset for " .. target:Name())
end)

concommand.Add("rem_netguard_watch", function(ply)
	if not Allowed(ply) then return end

	local state = IsValid(ply) and ply.rem_netguard or nil

	if not istable(state) then
		print(TAG .. "no data for " .. (IsValid(ply) and ply:Name() or "console"))
		return
	end

	print(TAG .. ply:Name() .. " [" .. ply:SteamID64() .. "]")
	print(TAG .. "  jitter: " .. tostring(Round(state.jitter, 3)) .. " | grace left: " .. tostring(math.max(0, Round(state.graceEnd - CurTime(), 1))) .. "s")
	print(TAG .. "  message budget: " .. tostring(Round(state.msgRate, 1)) .. "/s burst " .. tostring(Round(state.msgBurst, 1)))
	print(TAG .. "  total budget: " .. tostring(Round(state.totalRate, 1)) .. "/s burst " .. tostring(Round(state.totalBurst, 1)))
	print(TAG .. "  byte budget: " .. tostring(Round(state.byteRate / 1024, 1)) .. "KB/s burst " .. tostring(Round(state.byteBurst / 1024, 1)) .. "KB")
	print(TAG .. "  sent: " .. state.totalSent .. " | dropped: " .. state.totalDropped .. " | strikes: " .. state.strikes .. (state.muted and " | throttled" or ""))

	local list = {}

	for name, bucket in pairs(state.msgs) do
		list[#list + 1] = { name = name, count = tonumber(bucket.lastW) or 0, tokens = bucket.n }
	end

	sort(list, function(a, b)
		return a.count > b.count
	end)

	for i = 1, math.min(#list, cvTop:GetInt()) do
		local entry = list[i]

		print(TAG .. "  " .. entry.name .. " | " .. entry.count .. " msg/s | tokens " .. tostring(Round(entry.tokens, 1)))
	end
end)

timer.Create("RemorseNetGuard_Report", 1, 0, function()
	local interval = cvInterval:GetFloat()

	if interval <= 0 then return end
	if CurTime() < NG.nextReport then return end

	NG.nextReport = CurTime() + interval

	NG.Report("interval")
end)

if tonumber(GetConVar("rem_netguard_report_interval"):GetString()) > 0 then
	NG.nextReport = CurTime() + tonumber(GetConVar("rem_netguard_report_interval"):GetString())
end
