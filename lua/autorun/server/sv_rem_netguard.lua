if not SERVER then return end

RemorseNetGuard = RemorseNetGuard or {}

local NG = RemorseNetGuard

local CurTime = CurTime
local SysTime = SysTime
local IsValid = IsValid
local istable = istable
local isstring = isstring
local isfunction = isfunction
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local type = type
local min = math.min
local max = math.max
local random = math.random

local TAG = "[RemorseNetGuard] "

local cvEnabled = CreateConVar("rem_netguard_enabled", "1", FCVAR_ARCHIVE, TAG .. "master switch for the net limiter", 0, 1)
local cvObserve = CreateConVar("rem_netguard_observe", "0", FCVAR_ARCHIVE, TAG .. "report violations but never drop anything", 0, 1)
local cvMsgRate = CreateConVar("rem_netguard_msg_rate", "100", FCVAR_ARCHIVE, TAG .. "sustained net messages per second allowed per message name", 1, 5000)
local cvMsgBurst = CreateConVar("rem_netguard_msg_burst", "250", FCVAR_ARCHIVE, TAG .. "burst allowance per message name", 1, 10000)
local cvTotalRate = CreateConVar("rem_netguard_total_rate", "600", FCVAR_ARCHIVE, TAG .. "sustained net messages per second allowed per player across every message", 5, 50000)
local cvTotalBurst = CreateConVar("rem_netguard_total_burst", "1500", FCVAR_ARCHIVE, TAG .. "burst allowance per player across every message", 5, 100000)
local cvByteRate = CreateConVar("rem_netguard_byte_rate", "262144", FCVAR_ARCHIVE, TAG .. "net payload bytes per second allowed per player", 512, 67108864)
local cvByteBurst = CreateConVar("rem_netguard_byte_burst", "524288", FCVAR_ARCHIVE, TAG .. "net payload burst allowance per player in bytes", 512, 134217728)
local cvGrace = CreateConVar("rem_netguard_grace", "12", FCVAR_ARCHIVE, TAG .. "seconds after connecting before the per message limiter engages", 0, 300)
local cvJitter = CreateConVar("rem_netguard_jitter", "0.15", FCVAR_ARCHIVE, TAG .. "randomized slack added to every limit so exact thresholds are not public knowledge", 0, 0.5)
local cvExemptAdmins = CreateConVar("rem_netguard_exempt_admins", "0", FCVAR_ARCHIVE, TAG .. "never limit admins", 0, 1)
local cvDropWarn = CreateConVar("rem_netguard_drop_warn", "50", FCVAR_ARCHIVE, TAG .. "dropped messages before a violation reaches the server console", 1, 1000000)
local cvDropLoud = CreateConVar("rem_netguard_drop_loud", "2000", FCVAR_ARCHIVE, TAG .. "dropped messages before an automatic flood notice is printed", 25, 10000000)
local cvPenalty = CreateConVar("rem_netguard_penalty", "1", FCVAR_ARCHIVE, TAG .. "kick players that keep flooding after already being dropped", 0, 1)
local cvPenaltyDrops = CreateConVar("rem_netguard_penalty_drops", "20", FCVAR_ARCHIVE, TAG .. "dropped messages per second that counts as active flooding", 1, 1000000)
local cvPenaltyTime = CreateConVar("rem_netguard_penalty_time", "20", FCVAR_ARCHIVE, TAG .. "seconds of uninterrupted flooding before the offender is kicked", 1, 600)
local cvPenaltyText = CreateConVar("rem_netguard_penalty_text", "Net flooding", FCVAR_ARCHIVE, TAG .. "kick reason handed to net flooders")
local cvStrikes = CreateConVar("rem_netguard_strikes", "3", FCVAR_ARCHIVE, TAG .. "violations a steam id may commit across reconnects before its next session starts muted", 1, 1000)
local cvMuteTime = CreateConVar("rem_netguard_mute_time", "120", FCVAR_ARCHIVE, TAG .. "seconds a reconnecting repeat offender stays throttled", 0, 7200)
local cvPresets = CreateConVar("rem_netguard_presets", "1", FCVAR_ARCHIVE, TAG .. "apply the built in tight limits for known expensive handlers", 0, 1)

NG.limits = NG.limits or {}
NG.byID = NG.byID or {}
NG.wrapped = NG.wrapped or setmetatable({}, { __mode = "k" })
NG.staleUntil = 0
NG.lastSys = SysTime()

local generated = setmetatable({}, { __mode = "k" })
local warnGap = {}
local reported = {}

local cfg = {
	msgRate = 100,
	msgBurst = 250,
	totalRate = 600,
	totalBurst = 1500,
	byteRate = 262144,
	byteBurst = 524288,
	grace = 12,
	jitter = 0.15,
	muteTime = 120,
	exemptAdmins = false,
	observe = false,
	muteRate = 3,
}

local function RefreshConfig()
	cfg.msgRate = cvMsgRate:GetFloat()
	cfg.msgBurst = max(cfg.msgRate, cvMsgBurst:GetFloat())
	cfg.totalRate = cvTotalRate:GetFloat()
	cfg.totalBurst = max(cfg.totalRate, cvTotalBurst:GetFloat())
	cfg.byteRate = cvByteRate:GetFloat()
	cfg.byteBurst = max(cfg.byteRate, cvByteBurst:GetFloat())
	cfg.grace = cvGrace:GetFloat()
	cfg.jitter = cvJitter:GetFloat()
	cfg.muteTime = cvMuteTime:GetFloat()
	cfg.exemptAdmins = cvExemptAdmins:GetBool() and true or false
	cfg.observe = cvObserve:GetBool() and true or false
	cfg.muteRate = 3
end

local function Refill(bucket, now, rate, burst)
	local dt = now - bucket.t

	if dt < 0 then
		bucket.t = now
		bucket.n = burst
	elseif dt > 0 then
		bucket.t = now
		bucket.n = min(burst, bucket.n + dt * rate)
	end
end

local function IsRepeatOffender(sid)
	local rec = NG.byID[sid]

	return istable(rec) and (tonumber(rec.strikes) or 0) >= cvStrikes:GetInt()
end

local function NewState(ply, now)
	local j = 1 - cfg.jitter + random() * cfg.jitter * 2
	local sid = ply:SteamID64()
	local muted = cfg.muteTime > 0 and isstring(sid) and sid ~= "" and IsRepeatOffender(sid)

	local state = {
		token = NG,
		started = now,
		graceEnd = now + cfg.grace,
		jitter = j,
		msgRate = cfg.msgRate * j,
		msgBurst = cfg.msgBurst * j,
		totalRate = (muted and cfg.muteRate or cfg.totalRate) * j,
		totalBurst = (muted and cfg.muteRate * 3 or cfg.totalBurst) * j,
		byteRate = cfg.byteRate * j,
		byteBurst = cfg.byteBurst * j,
		msgs = {},
		msgCount = 0,
		total = { t = now, n = 0 },
		bytes = { t = now, n = 0 },
		lastRate = 0,
		lastBytes = 0,
		lastDropped = 0,
		lastWorst = nil,
		lastWorstCount = 0,
		windowCount = 0,
		windowBytes = 0,
		windowDropped = 0,
		worstName = nil,
		worstCount = 0,
		totalSent = 0,
		totalDropped = 0,
		floodSince = 0,
		strikes = 0,
		muted = muted,
	}

	state.total.n = state.totalBurst
	state.bytes.n = muted and state.byteRate or state.byteBurst

	ply.rem_netguard = state

	if muted then
		MsgN(TAG .. ply:Name() .. " rejoined throttled (repeat net flood offender)")
	end

	return state
end

function NG.GetState(ply)
	if not IsValid(ply) then return nil end
	if not ply.rem_netguard then NewState(ply, CurTime()) end

	return ply.rem_netguard
end

function NG.IsThrottled(ply)
	local state = IsValid(ply) and ply.rem_netguard or nil

	return (state and state.muted) and true or false
end

function NG.SetLimit(name, rate, burst, preset)
	if not isstring(name) or name == "" then return end

	local r = tonumber(rate)

	if not r or r <= 0 then
		NG.limits[name] = nil
		return
	end

	NG.limits[name] = { rate = r, burst = tonumber(burst) or r * 2, preset = preset and true or false }
end

function NG.ClearLimit(name)
	if isstring(name) then NG.limits[name] = nil end
end

NG.presets = NG.presets or {
	["zb_sql_leaderboard"] = { 1, 3 },
	["ZB_AdminStatsRequest"] = { 1, 3 },
	["ZB_AdminStatsSave"] = { 1, 2 },
	["ZB_SendModesInfo"] = { 1, 3 },
	["ZB_SendRoundList"] = { 1, 3 },
	["ZB_UpdateRoundList"] = { 1, 3 },
	["ZB_NotifyRoundListChange"] = { 1, 3 },
	["AdminSetGameMode"] = { 1, 2 },
	["AdminEndRound"] = { 1, 2 },
	["AdminSetGameQueue"] = { 1, 2 },
	["forgive_player"] = { 1, 2 },
	["zb_getallpoints"] = { 2, 4 },
	["zb_getspecificpoints"] = { 2, 4 },
	["get_karma"] = { 2, 4 },
	["get_svPData"] = { 3, 8 },
	["ZB_GiveRole"] = { 2, 4 },
	["HG_AdminTools"] = { 2, 4 },
	["hg_pointshop_net"] = { 2, 4 },
	["Get_Appearance"] = { 3, 8 },
	["OnlyGet_Appearance"] = { 3, 8 },
	["weaponInv"] = { 3, 8 },
	["zb_xp_get"] = { 3, 8 },
}

function NG.ApplyPresets()
	for name, preset in pairs(NG.presets) do
		if cvPresets:GetBool() then
			NG.SetLimit(name, preset[1], preset[2], true)
		else
			NG.ClearLimit(name)
		end
	end
end

local function Report(context, err)
	local seen = reported[context]

	if seen and seen > 0 then return end

	reported[context] = (seen or 0) + 1

	MsgN(TAG .. context .. " error: " .. tostring(err))
end

local function SafeRun(context, event, ...)
	local res = { pcall(hook.Run, event, ...) }

	if not res[1] then
		Report(context, res[2])
	end
end

local function RecordDrop(ply, state, name)
	state.windowDropped = state.windowDropped + 1
	state.totalDropped = state.totalDropped + 1

	local warn = cvDropWarn:GetInt()

	if state.totalDropped < warn then return end

	local gap = warnGap[name]

	if gap and gap > 0 then return end

	warnGap[name] = 10

	state.strikes = state.strikes + 1

	local sid = ply:SteamID64()

	MsgN(TAG .. "dropped " .. state.totalDropped .. " messages from " .. ply:Name() .. " (" .. (sid ~= "" and sid or "unknown") .. ") | last: " .. name)

	if state.totalDropped >= cvDropLoud:GetInt() then
		MsgN(TAG .. "flooder: " .. ply:Name() .. " (" .. sid .. ") is saturating " .. name)
	end

	SafeRun("RemorseNetGuardViolation", "RemorseNetGuardViolation", ply, name, state.totalDropped, state)
end

local function Admit(name, len, ply)
	local now = CurTime()
	local state = ply.rem_netguard

	if not istable(state) or state.token ~= NG then
		if cfg.exemptAdmins and ply:IsAdmin() then return false end
		state = NewState(ply, now)
	elseif cfg.exemptAdmins and ply:IsAdmin() then
		return false
	end

	local bytes = tonumber(len) or 0
	local custom = NG.limits[name]
	local rate = custom and custom.rate or state.msgRate
	local burst = custom and custom.burst or state.msgBurst
	local bucket = state.msgs[name]

	if not bucket then
		if state.msgCount >= 256 then
			state.msgs = {}
			state.msgCount = 0
		end

		bucket = { t = now, n = burst, w = 0, lastW = 0 }
		state.msgs[name] = bucket
		state.msgCount = state.msgCount + 1
	end

	local allowed = true

	if now >= state.graceEnd and now >= NG.staleUntil then
		Refill(bucket, now, rate, burst)

		if bucket.n >= 1 then
			bucket.n = bucket.n - 1
		else
			allowed = false
		end

		if allowed then
			Refill(state.total, now, state.totalRate, state.totalBurst)

			if state.total.n >= 1 then
				state.total.n = state.total.n - 1
			else
				allowed = false
			end
		end

		if allowed then
			Refill(state.bytes, now, state.byteRate, state.byteBurst)

			if state.bytes.n >= 1 then
				state.bytes.n = max(0, state.bytes.n - bytes)
			else
				allowed = false
			end
		end
	end

	if not allowed then
		RecordDrop(ply, state, name)

		if not cfg.observe then return true end
	end

	state.totalSent = state.totalSent + 1
	state.windowCount = state.windowCount + 1
	state.windowBytes = state.windowBytes + bytes

	bucket.w = bucket.w + 1

	if bucket.w > state.worstCount then
		state.worstCount = bucket.w
		state.worstName = name
	end

	return false
end

local function Guard(name, fn)
	if type(fn) ~= "function" then return fn end

	local original = NG.wrapped[fn]

	if original then fn = original end
	if generated[fn] then return fn end

	local wrapped = function(len, ply)
		if not IsValid(ply) then return fn(len, ply) end
		if not cvEnabled:GetBool() then return fn(len, ply) end
		if ply:IsBot() then return fn(len, ply) end

		local ok, dropped = pcall(Admit, name, len, ply)

		if not ok then
			Report("admit:" .. tostring(name), dropped)
			return fn(len, ply)
		end

		if dropped then return end

		return fn(len, ply)
	end

	generated[wrapped] = true
	NG.wrapped[wrapped] = fn

	return wrapped
end

function NG.Kick(ply, state, reason)
	local sid = ply:SteamID64()

	if isstring(sid) and sid ~= "" then
		local rec = NG.byID[sid]

		if not istable(rec) then
			rec = { strikes = 0 }
			NG.byID[sid] = rec
		end

		rec.strikes = max(tonumber(rec.strikes) or 0, tonumber(state.strikes) or 0) + 1
		rec.name = ply:Name()
		rec.last = SysTime()
	end

	MsgN(TAG .. "kicking " .. ply:Name() .. " (" .. (sid ~= "" and sid or "unknown") .. ") | " .. (state.lastWorst or "unknown") .. " | " .. state.totalDropped .. " dropped")

	ply:Kick(reason or cvPenaltyText:GetString())

	SafeRun("RemorseNetGuardKicked", "RemorseNetGuardKicked", ply, state)
end

local oldNetReceive = net.Receive

net.Receive = function(name, fn)
	return oldNetReceive(name, Guard(name, fn))
end

hook.Add("PlayerInitialSpawn", "RemorseNetGuard", function(ply)
	local res = { pcall(function()
		ply.rem_netguard = nil
		NewState(ply, CurTime())
	end) }

	if not res[1] then
		Report("PlayerInitialSpawn", res[2])
	end
end)

hook.Add("PlayerDisconnected", "RemorseNetGuard", function(ply)
	local state = ply.rem_netguard

	ply.rem_netguard = nil

	if istable(state) and state.token == NG and state.totalDropped > 0 then
		MsgN(TAG .. ply:Name() .. " left after " .. state.totalDropped .. " dropped messages | worst: " .. (state.lastWorst or state.worstName or "unknown"))
	end
end)

timer.Create("RemorseNetGuard_Config", 1, 0, RefreshConfig)

timer.Create("RemorseNetGuard_Sweep", 1, 0, function()
	local now = CurTime()
	local sys = SysTime()

	if sys - NG.lastSys > 2 then
		NG.staleUntil = now + 1
	end

	NG.lastSys = sys

	for name, value in pairs(warnGap) do
		value = value - 1

		if value <= 0 then
			warnGap[name] = nil
		else
			warnGap[name] = value
		end
	end

	local punishing = cvPenalty:GetBool() and true or false
	local need = cvPenaltyDrops:GetFloat()
	local hold = cvPenaltyTime:GetFloat()

	for _, ply in ipairs(player.GetAll()) do
		local state = ply.rem_netguard

		if istable(state) then
			state.lastRate = state.windowCount
			state.lastBytes = state.windowBytes
			state.lastDropped = state.windowDropped
			state.lastWorst = state.worstName
			state.lastWorstCount = state.worstCount

			state.windowCount = 0
			state.windowBytes = 0
			state.windowDropped = 0
			state.worstCount = 0
			state.worstName = nil

			for _, bucket in pairs(state.msgs) do
				bucket.lastW = bucket.w
				bucket.w = 0
			end

			if punishing and state.lastDropped >= need then
				if state.floodSince == 0 then state.floodSince = now end

				if now - state.floodSince >= hold then
					state.floodSince = 0

					local res = { pcall(NG.Kick, ply, state) }

					if not res[1] then
						Report("kick", res[2])
					end
				end
			else
				state.floodSince = 0
			end
		end
	end

	local cut = sys - 3600

	for sid, rec in pairs(NG.byID) do
		if (tonumber(rec.last) or 0) < cut then
			NG.byID[sid] = nil
		end
	end
end)

timer.Simple(0, function()
	RefreshConfig()
	NG.ApplyPresets()

	if not istable(net.Receivers) then return end

	local names = {}

	for name in pairs(net.Receivers) do
		names[#names + 1] = name
	end

	for _, name in ipairs(names) do
		local fn = net.Receivers[name]
		local res = { pcall(Guard, name, fn) }

		if not res[1] then
			Report("wrap:" .. tostring(name), res[2])
		elseif isfunction(res[2]) and res[2] ~= fn then
			net.Receivers[name] = res[2]
		end
	end

	MsgN(TAG .. "loaded | rem_netguard_report to inspect, rem_netguard_observe 1 to calibrate, rem_netguard_presets to list tight limits, rem_netguard_enabled 0 to bypass")
end)
