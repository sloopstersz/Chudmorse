local cfg = ZAC.Config
local CHUNK = 60000 -- most a player may send in one piece (the client sends 16 KB pieces)
local SEND_CHUNK, SEND_GAP = 24000, 0.15 -- to the admin: small pieces, slowly (big fast ones overflowed and kicked)
local INDEX = "zac/screens/index.json"

local pending = {}

local index = util.JSONToTable(file.Read(INDEX, "DATA") or "") or {}
local function saveIndex() file.Write(INDEX, util.TableToJSON(index, true)) end

local function addToIndex(e)
	table.insert(index, 1, e)
	while #index > cfg.ScreengrabKeep do
		local old = table.remove(index)
		if old and old.file and file.Exists(old.file, "DATA") then file.Delete(old.file) end
	end
	saveIndex()
end

local function sendList(ply)
	net.Start("zac_sg_list")
	local n = math.min(#index, 300)
	net.WriteUInt(n, 9)
	for i = 1, n do
		local e = index[i]
		net.WriteString(e.file)
		net.WriteString(e.name or "?")
		net.WriteString(e.sid or "")
		net.WriteUInt(e.time or 0, 32)
		net.WriteString(e.by or "")
		net.WriteUInt(math.Clamp(e.kb or 0, 0, 65535), 16)
	end
	net.Send(ply)
end

local function listToAdmins()
	for _, p in player.Iterator() do
		if p.ZACLive and ZAC.IsAdmin(p) then sendList(p) end
	end
end

local function sendToAdmin(admin, data, title, code)
	if not IsValid(admin) then return end
	local total = math.ceil(#data / SEND_CHUNK)
	if total > 255 then admin:ChatPrint("[AC] That screengrab is too big to send.") return end
	local token = math.random(1, 2147483646)
	for i = 1, total do
		timer.Simple(i * SEND_GAP, function()
			if not IsValid(admin) then return end
			local part = string.sub(data, (i - 1) * SEND_CHUNK + 1, i * SEND_CHUNK)
			net.Start("zac_sg_view")
			net.WriteUInt(token, 32)
			net.WriteUInt(i, 8)
			net.WriteUInt(total, 8)
			net.WriteString(title)
			net.WriteString(code or "")
			net.WriteUInt(#part, 16)
			net.WriteData(part, #part)
			net.Send(admin)
		end)
	end
end

function ZAC.Screengrab(admin, target, label)
	if not IsValid(target) or not target:IsPlayer() or target:IsBot() then return false, "No such player." end
	for _, p in pairs(pending) do
		if p.target == target then return false, "Already grabbing " .. target:Nick() .. "'s screen." end
	end
	local token = math.random(1, 2147483646)
	-- a random check code drawn into the corner of the picture by the player's game
	local abc, code = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789", ""
	for _ = 1, 5 do local k = math.random(#abc) code = code .. string.sub(abc, k, k) end
	pending[token] = { target = target, admin = admin, label = label, chunks = {}, got = 0, bytes = 0, started = CurTime(), code = code }
	net.Start("zac_sg_req")
	net.WriteUInt(token, 32)
	net.WriteUInt(math.Clamp(cfg.ScreengrabQuality, 1, 100), 7)
	net.WriteString(code)
	net.Send(target)
	ZAC.Log("screen", (IsValid(admin) and ZAC.Who(admin) or label or "Console") .. " requested a screengrab of " .. ZAC.Who(target), nil, target)

	timer.Simple(cfg.ScreengrabTimeout, function()
		local p = pending[token]
		if not p then return end
		pending[token] = nil
		local who = IsValid(p.target) and ZAC.Who(p.target) or "a player who left"
		ZAC.Log("screen", "Screengrab of " .. who .. " FAILED: nothing arrived in " .. cfg.ScreengrabTimeout .. "s (" .. p.got .. " of " .. tostring(p.total or "?") .. " parts)",
			nil, IsValid(p.target) and p.target or nil)
		if IsValid(p.admin) then p.admin:ChatPrint("[AC] Screengrab of " .. who .. " failed (it never arrived).") end
	end)
	return true
end

local function finish(token, p)
	pending[token] = nil
	if not IsValid(p.target) then return end
	local data = table.concat(p.chunks)
	if string.sub(data, 1, 2) ~= "\255\216" then
		ZAC.Log("screen", "Screengrab of " .. ZAC.Who(p.target) .. " FAILED: the upload is not a picture", nil, p.target)
		return
	end
	local name = string.format("zac/screens/%s_%s.jpg", p.target:SteamID64(), os.date("%Y%m%d_%H%M%S"))
	file.Write(name, data)
	local by = IsValid(p.admin) and p.admin:Nick() or p.label or "Console"
	addToIndex({ file = name, name = p.target:Nick(), sid = p.target:SteamID(), time = os.time(), by = by, kb = math.ceil(#data / 1024), code = p.code })
	ZAC.Log("screen", string.format("Screengrab of %s saved (%d KB, %.1fs, check code %s)", ZAC.Who(p.target), math.ceil(#data / 1024), CurTime() - p.started, p.code or "?"),
		"File: garrysmod/data/" .. name, p.target)
	if p.flags and p.flags > 0 then
		local what = {}
		if bit.band(p.flags, 1) > 0 then what[#what + 1] = "render.Capture" end
		if bit.band(p.flags, 2) > 0 then what[#what + 1] = "render.UpdateScreenEffectTexture" end
		if bit.band(p.flags, 4) > 0 then what[#what + 1] = "render.PushRenderTarget" end
		if bit.band(p.flags, 8) > 0 then what[#what + 1] = "render.RenderView" end
		local m = ZAC.Who(p.target) .. "'s game has these screen functions REPLACED by a script: " .. table.concat(what, ", ") .. " (anti-screengrab cheats do this - their screengrabs can be faked)"
		ZAC.Log("screen", m, nil, p.target)
		for _, a in player.Iterator() do if ZAC.IsAdmin(a) then a:ChatPrint("[AC] " .. m) end end
	end
	sendToAdmin(p.admin, data, p.target:Nick() .. "  " .. p.target:SteamID() .. "  " .. os.date("%Y-%m-%d %H:%M:%S"), p.code)
	listToAdmins()
end

net.Receive("zac_sg_chunk", function(_, ply)
	local token = net.ReadUInt(32)
	local idx, total = net.ReadUInt(8), net.ReadUInt(8)
	local flags = net.ReadUInt(8)
	local len = net.ReadUInt(16)
	local p = pending[token]
	if not p or p.target ~= ply then return end
	if total < 1 or idx < 1 or idx > total or len < 1 or len > CHUNK then return end
	if p.total and p.total ~= total then pending[token] = nil return end
	p.total = total
	if p.chunks[idx] then return end
	local data = net.ReadData(len)
	p.bytes = p.bytes + #data
	if p.bytes > cfg.ScreengrabMaxBytes then
		pending[token] = nil
		ZAC.Log("screen", "Screengrab of " .. ZAC.Who(ply) .. " FAILED: too big", nil, ply)
		return
	end
	p.chunks[idx] = data
	p.flags = bit.bor(p.flags or 0, flags)
	p.got = p.got + 1
	if p.got == p.total then finish(token, p) end
end)

net.Receive("zac_sg_list_req", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACSgListNext or 0) > CurTime() then return end
	ply.ZACSgListNext = CurTime() + 0.5
	sendList(ply)
end)

net.Receive("zac_sg_open", function(_, ply)
	if not ZAC.IsAdmin(ply) then return end
	if (ply.ZACSgOpenNext or 0) > CurTime() then return end
	ply.ZACSgOpenNext = CurTime() + 1
	local want = net.ReadString()
	for _, e in ipairs(index) do
		if e.file == want then
			local data = file.Read(e.file, "DATA")
			if not data then ply:ChatPrint("[AC] That screengrab file is gone.") return end
			sendToAdmin(ply, data, (e.name or "?") .. "  " .. (e.sid or "") .. "  " .. os.date("%Y-%m-%d %H:%M:%S", e.time or 0), e.code)
			return
		end
	end
end)

ZAC.AdminActions.screengrab = function(admin, target)
	local p = ZAC.FindPlayer(target)
	local ok, why = ZAC.Screengrab(admin, p)
	local text = ok and ("Grabbing " .. p:Nick() .. "'s screen... it will pop up when it arrives.") or why
	if IsValid(admin) then admin:ChatPrint("[AC] " .. text) else print("[AC] " .. text) end
end
