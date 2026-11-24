-- LIVE ADMIN SPECTATE: watch a player through their own eyes, with exactly the view angles their game
-- sends to the server every tick (not the smoothed angles everyone else sees), their keys and mouse,
-- and every other player drawn on top - green if the watched player can see them, red if they're
-- behind a wall (from the server's own traces, so a cheat can't hide or fake it).
--   Start:  chat  !spec <name>   console  zac spectate <name|steamid>   menu  Players tab > right-click > Spectate (live)
--   Stop:   chat  !spec          or SPACE while watching
-- Admins only. The admin stands still where they are while watching (nobody sees them move).
local cfg = ZAC.Config

util.AddNetworkString("zac_spec")       -- server -> admin: start / stop (entity target)
util.AddNetworkString("zac_spec_cmds")  -- server -> admin: the target's commands since the last batch
util.AddNetworkString("zac_spec_world") -- server -> admin: other players, visibility, the target's state
util.AddNetworkString("zac_spec_ctl")   -- admin -> server: 0 stop, 1 next, -1 previous

local BUF = 256

local function watchers(target)
	local out = {}
	for _, p in player.Iterator() do
		if p.ZACSpecTarget == target and ZAC.IsAdmin(p) then out[#out + 1] = p end
	end
	return out
end

local function anyWatching(target)
	for _, p in player.Iterator() do if p.ZACSpecTarget == target then return true end end
	return false
end

local function sendState(admin, target)
	net.Start("zac_spec")
	net.WriteEntity(IsValid(target) and target or NULL)
	net.Send(admin)
end

function ZAC.StopSpectate(admin, why)
	if not IsValid(admin) or not admin.ZACSpecTarget then return end
	local t = admin.ZACSpecTarget
	admin.ZACSpecTarget = nil
	sendState(admin, NULL)
	ZAC.Log("admin", ZAC.Who(admin) .. " stopped spectating " .. (IsValid(t) and ZAC.Who(t) or "a player") .. (why and (" (" .. why .. ")") or ""), nil, admin, IsValid(t) and t or nil)
end

function ZAC.StartSpectate(admin, target)
	if not (ZAC.IsAdmin(admin) and IsValid(target) and target:IsPlayer()) then return false, "No such player." end
	if target == admin then return false, "You can't spectate yourself." end
	admin.ZACSpecTarget = target
	admin.ZACSpecSeq = target.ZACSpecSeq or 0
	target.ZACSpecBuf = target.ZACSpecBuf or {}
	sendState(admin, target)
	ZAC.Log("admin", ZAC.Who(admin) .. " started spectating " .. ZAC.Who(target), nil, admin, target)
	return true
end

-- every command the target sends, exactly as the server gets it
hook.Add("StartCommand", "zac_spec", function(ply, cmd)
	if ply.ZACSpecTarget then
		-- the watching admin stands still
		cmd:ClearMovement()
		cmd:ClearButtons()
	end
	local buf = ply.ZACSpecBuf
	if not buf then return end
	if not anyWatching(ply) then ply.ZACSpecBuf = nil return end
	local now = SysTime()
	local seq = (ply.ZACSpecSeq or 0) + 1
	ply.ZACSpecSeq = seq
	local ang = cmd:GetViewAngles()
	buf[seq % BUF] = {
		seq = seq, p = ang.p, y = ang.y,
		mx = math.Clamp(cmd:GetMouseX(), -32767, 32767), my = math.Clamp(cmd:GetMouseY(), -32767, 32767),
		b = cmd:GetButtons(), gap = math.Clamp(math.floor((now - (ply.ZACSpecLastCmd or now)) * 1000), 0, 65535),
		ahead = math.Clamp(cmd:TickCount() - engine.TickCount(), -32767, 32767),
	}
	ply.ZACSpecLastCmd = now
end)

-- keep the watched player's surroundings networked to the admin
hook.Add("SetupPlayerVisibility", "zac_spec", function(ply)
	local t = ply.ZACSpecTarget
	if IsValid(t) then AddOriginToPVS(t:EyePos()) end
end)

local function ratingOf(p)
	local r = ZAC.Ratings and ZAC.Ratings[p:SteamID()]
	if not r or not ZAC.RatingOf then return 1, 0 end
	local level, score = ZAC.RatingOf(r)
	return level, score
end

local worldClock = 0
timer.Create("zac_spec", 0.05, 0, function()
	worldClock = worldClock + 1
	local sendWorld = worldClock % 3 == 0
	for _, admin in player.Iterator() do
		local t = admin.ZACSpecTarget
		if t ~= nil then
			if not IsValid(t) then
				ZAC.StopSpectate(admin, "they left")
			elseif not ZAC.IsAdmin(admin) then
				ZAC.StopSpectate(admin, "not an admin")
			else
				-- commands since the last batch
				local buf, last, seq = t.ZACSpecBuf or {}, admin.ZACSpecSeq or 0, t.ZACSpecSeq or 0
				if seq - last > BUF - 1 then last = seq - (BUF - 1) end
				local n = math.min(seq - last, 64)
				if n > 0 then
					net.Start("zac_spec_cmds", true)
					net.WriteUInt(n, 7)
					for s = seq - n + 1, seq do
						local c = buf[s % BUF]
						if c and c.seq == s then
							net.WriteBool(true)
							net.WriteFloat(c.p) net.WriteFloat(c.y)
							net.WriteInt(c.mx, 16) net.WriteInt(c.my, 16)
							net.WriteUInt(c.b, 32)
							net.WriteUInt(c.gap, 16)
							net.WriteInt(c.ahead, 16)
						else
							net.WriteBool(false)
						end
					end
					net.Send(admin)
				end
				admin.ZACSpecSeq = seq

				if sendWorld then
					local list = {}
					for _, p in player.Iterator() do
						if p ~= t and p:Alive() then list[#list + 1] = p end
					end
					local level, score = ratingOf(t)
					net.Start("zac_spec_world", true)
					net.WriteVector(t:EyePos())
					net.WriteBool(t:Alive())
					net.WriteUInt(math.Clamp(t:Health(), 0, 1023), 10)
					net.WriteUInt(math.Clamp(t:Ping(), 0, 1023), 10)
					net.WriteUInt(level, 2)
					net.WriteUInt(math.Clamp(score, 0, 1023), 10)
					net.WriteBool(t.ZACStuck ~= nil)
					net.WriteUInt(math.min(#list, 63), 6)
					for i = 1, math.min(#list, 63) do
						local p = list[i]
						net.WriteEntity(p)
						net.WriteVector(p:EyePos())
						net.WriteBool(t:Alive() and ZAC.CanSee and ZAC.CanSee(t, p) or false)
						local tm = t:GetNWInt("ext_team", 0)
						net.WriteBool(tm ~= 0 and tm == p:GetNWInt("ext_team", 0))
					end
					net.Send(admin)
				end
			end
		end
	end
end)

net.Receive("zac_spec_ctl", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACSpecNext or 0) > CurTime() then return end
	ply.ZACSpecNext = CurTime() + 0.25
	local dir = net.ReadInt(3)
	if dir == 0 then return ZAC.StopSpectate(ply) end
	local list = {}
	for _, p in player.Iterator() do if p ~= ply and not p:IsBot() then list[#list + 1] = p end end
	if #list == 0 then return end
	local cur = 0
	for i, p in ipairs(list) do if p == ply.ZACSpecTarget then cur = i end end
	local nxt = list[((cur - 1 + dir) % #list) + 1]
	ZAC.StartSpectate(ply, nxt)
end)

local function startBy(admin, arg)
	local function say(t) if IsValid(admin) then admin:ChatPrint("[AC] " .. t) else print("[AC] " .. t) end end
	if not IsValid(admin) then return say("Spectate works in game only.") end
	arg = string.Trim(arg or "")
	if arg == "" then
		if admin.ZACSpecTarget then return ZAC.StopSpectate(admin) end
		return say("Usage: !spec <name>   (!spec on its own stops)")
	end
	local p = ZAC.FindPlayer(arg)
	if not p then return say("No player '" .. arg .. "' online.") end
	local ok, why = ZAC.StartSpectate(admin, p)
	if not ok then say(why) end
end

ZAC.AdminActions.spectate = function(admin, target) startBy(admin, target) end
ZAC.AdminActions.unspectate = function(admin) if IsValid(admin) then ZAC.StopSpectate(admin) end end

hook.Add("PlayerSay", "zac_spec", function(ply, text)
	local t = string.Trim(text)
	local cmd, arg = string.match(t, "^[!/](%a+)%s*(.*)$")
	cmd = cmd and string.lower(cmd)
	if cmd ~= "spec" and cmd ~= "spectate" then return end
	if not ZAC.IsAdmin(ply) then return end
	startBy(ply, arg)
	return ""
end)

hook.Add("PlayerDisconnected", "zac_spec", function(ply)
	ply.ZACSpecTarget = nil
	for _, p in player.Iterator() do
		if p.ZACSpecTarget == ply then ZAC.StopSpectate(p, "they left") end
	end
end)
