-- LIVE ADMIN SPECTATE (client): sv_spectate.lua sends the watched player's exact commands (view angles,
-- mouse, keys) and where everyone else is. This plays the commands back tick by tick through the
-- player's eyes and draws:
--   * everyone else: GREEN = the watched player can see them, RED = behind a wall, BLUE = teammate
--   * "AIMING AT HIDDEN" when their crosshair sits on someone they can't see
--   * their keys, mouse movement, how far the view turned each tick (snaps), turns with no mouse movement,
--     gaps in their input (airstuck / lag) and commands stamped in the future
-- Controls while watching: LMB next player, RMB previous, R / F first <-> third person, SPACE stop.
local SPEC = {}
ZACSPEC = SPEC

local target
local queue, hist = {}, {}
local cur
local world = { list = {}, eye = nil, alive = true, hp = 100, ping = 0, level = 1, score = 0, stuck = false }
local third = false
local playAcc = 0
local TICK = engine.TickInterval()
local lastView
local noMouse = {}
local HIST = 132

function SPEC.Active() return target ~= nil end
local function ctl(dir) net.Start("zac_spec_ctl") net.WriteInt(dir, 3) net.SendToServer() end

-- while watching, every other CalcView / RenderScene hook is skipped (Z-City draws the world from its own
-- RenderScene hook) so this view is the one on screen - same as the EFZ helmet cam
local wrapped = setmetatable({}, { __mode = "k" })
local OURS = { zac_spec_render = true }
local function wrapOthers()
	for _, ev in ipairs({ "CalcView", "RenderScene" }) do
		for name, fn in pairs(hook.GetTable()[ev] or {}) do
			if not OURS[name] and isfunction(fn) and not wrapped[fn] then
				local orig = fn
				local w = function(...) if SPEC.Active() then return end return orig(...) end
				wrapped[w] = true
				hook.Add(ev, name, w)
			end
		end
	end
end

net.Receive("zac_spec", function()
	local t = net.ReadEntity()
	queue, hist, noMouse, cur, playAcc = {}, {}, {}, nil, 0
	world.list = {}
	if IsValid(t) then
		target = t
		wrapOthers()
		surface.PlaySound("buttons/button17.wav")
	else
		target = nil
	end
end)

net.Receive("zac_spec_cmds", function()
	local n = net.ReadUInt(7)
	for _ = 1, n do
		if net.ReadBool() then
			queue[#queue + 1] = {
				p = net.ReadFloat(), y = net.ReadFloat(), mx = net.ReadInt(16), my = net.ReadInt(16),
				b = net.ReadUInt(32), gap = net.ReadUInt(16), ahead = net.ReadInt(16),
			}
		end
	end
	while #queue > 200 do table.remove(queue, 1) end
end)

net.Receive("zac_spec_world", function()
	world.eye = net.ReadVector()
	world.alive = net.ReadBool()
	world.hp = net.ReadUInt(10)
	world.ping = net.ReadUInt(10)
	world.level = net.ReadUInt(2)
	world.score = net.ReadUInt(10)
	world.stuck = net.ReadBool()
	local list = {}
	for i = 1, net.ReadUInt(6) do
		list[i] = { ent = net.ReadEntity(), pos = net.ReadVector(), visible = net.ReadBool(), team = net.ReadBool() }
	end
	world.list = list
end)

-- play the commands back at the server's tick rate (catching up if they pile up)
local function angleStep(a, b)
	local dp, dy = math.AngleDifference(b.p, a.p), math.AngleDifference(b.y, a.y)
	return math.sqrt(dp * dp + dy * dy)
end
hook.Add("Think", "zac_spec_play", function()
	if not SPEC.Active() then return end
	playAcc = playAcc + FrameTime()
	local extra = #queue > 10 and math.floor((#queue - 10) / 4) or 0
	while (playAcc >= TICK or extra > 0) and #queue > 0 do
		if playAcc >= TICK then playAcc = playAcc - TICK else extra = extra - 1 end
		local s = table.remove(queue, 1)
		if cur then
			s.step = angleStep(cur, s)
			s.nomouse = s.step > 1.5 and s.mx == 0 and s.my == 0
		else
			s.step = 0
		end
		cur = s
		hist[#hist + 1] = s
		if #hist > HIST then table.remove(hist, 1) end
		if s.nomouse then noMouse[#noMouse + 1] = RealTime() end
	end
	if #queue == 0 then playAcc = math.min(playAcc, TICK) end
	while noMouse[1] and RealTime() - noMouse[1] > 5 do table.remove(noMouse, 1) end
end)

local function eyePos()
	if IsValid(target) and not target:IsDormant() then
		local rag = target:GetNWEntity("FakeRagdoll")
		if IsValid(rag) then
			local bone = rag:LookupBone("ValveBiped.Bip01_Head1")
			local m = bone and rag:GetBoneMatrix(bone)
			if m then return m:GetTranslation() end
		end
		return target:EyePos()
	end
	return world.eye
end

local function viewAngles()
	if cur then return Angle(cur.p, cur.y, 0) end
	if IsValid(target) then return target:EyeAngles() end
	return Angle()
end

local rv = { x = 0, y = 0, drawhud = true, drawviewmodel = false, dopostprocess = true, drawmonitors = true }
hook.Add("RenderScene", "zac_spec_render", function()
	if not SPEC.Active() then return end
	local eye = eyePos()
	if not eye then return end
	local ang = viewAngles()
	local origin = eye
	if third then
		local want = eye - ang:Forward() * 90 + Vector(0, 0, 12)
		local tr = util.TraceHull({ start = eye, endpos = want, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4), mask = MASK_SOLID_BRUSHONLY })
		origin = tr.HitPos
	end
	rv.w, rv.h = ScrW(), ScrH()
	rv.origin, rv.angles, rv.fov, rv.znear = origin, ang, 90, 1
	lastView = { origin = origin, angles = ang, fov = 90 }
	render.Clear(0, 0, 0, 255, true, true)
	render.RenderView(rv)
	return true
end)

-- first person: don't draw the watched player's own body over the view
hook.Add("PrePlayerDraw", "zac_spec_hide", function(ply)
	if SPEC.Active() and not third and ply == target then return true end
end)
hook.Add("CalcViewModelView", "zac_spec_novm", function() if SPEC.Active() then return Vector(0, 0, -100000), angle_zero end end)
hook.Add("PreDrawViewModel", "zac_spec_novm", function() if SPEC.Active() then return true end end)
hook.Add("HUDShouldDraw", "zac_spec_hud", function(name)
	if SPEC.Active() and name ~= "CHudGMod" and name ~= "CHudChat" then return false end
end)

hook.Add("PlayerBindPress", "zac_spec_keys", function(_, bind, pressed)
	if not SPEC.Active() or not pressed then return end
	if string.find(bind, "+attack2", 1, true) then ctl(-1) return true end
	if string.find(bind, "+attack", 1, true) then ctl(1) return true end
	if string.find(bind, "+jump", 1, true) then ctl(0) return true end
	if string.find(bind, "+reload", 1, true) or string.find(bind, "impulse 100", 1, true) then third = not third return true end
	if string.find(bind, "+forward", 1, true) or string.find(bind, "+back", 1, true) or string.find(bind, "+move", 1, true)
		or string.find(bind, "+use", 1, true) or string.find(bind, "+duck", 1, true) then return true end
end)

-- ===== overlay =====
surface.CreateFont("ZACSpec", { font = "Roboto Mono", size = 15, weight = 600 })
surface.CreateFont("ZACSpec_B", { font = "Roboto", size = 22, weight = 900 })
surface.CreateFont("ZACSpec_S", { font = "Roboto Mono", size = 13, weight = 500 })

-- GMod's fov is the horizontal fov of a 4:3 screen
local function project(pos, v, w, h)
	local d = pos - v.origin
	local x, y, z = d:Dot(v.angles:Forward()), d:Dot(v.angles:Right()), d:Dot(v.angles:Up())
	if x <= 1 then return nil end
	local scale = (h * 2 / 3) / math.tan(math.rad(v.fov) / 2)
	return w / 2 + y / x * scale, h / 2 - z / x * scale, x
end

local GREEN, RED, BLUE, WHITE, DIM = Color(80, 230, 90), Color(255, 60, 50), Color(90, 150, 255), Color(240, 240, 240), Color(150, 150, 150)
local LEVEL_NAME = { "LEGIT", "SUSPECT", "CHEATING" }
local LEVEL_COL = { GREEN, Color(255, 190, 40), RED }
local KEYS = {
	{ IN_FORWARD, "W" }, { IN_MOVELEFT, "A" }, { IN_BACK, "S" }, { IN_MOVERIGHT, "D" }, { IN_JUMP, "JUMP" }, { IN_DUCK, "DUCK" },
	{ IN_WALK, "WALK" }, { IN_SPEED, "RUN" }, { IN_ATTACK, "ATK1" }, { IN_ATTACK2, "ATK2" }, { IN_USE, "USE" }, { IN_RELOAD, "RELOAD" },
}

local function text(s, x, y, col, font, ax)
	draw.SimpleTextOutlined(s, font or "ZACSpec", x, y, col or WHITE, ax or TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
end

hook.Add("HUDPaint", "zac_spec_overlay", function()
	if not SPEC.Active() then return end
	local w, h = ScrW(), ScrH()
	local v = lastView

	-- everyone else
	local aimHidden
	if v then
		local fwd = v.angles:Forward()
		for _, e in ipairs(world.list) do
			local pos = e.pos
			if IsValid(e.ent) and not e.ent:IsDormant() then pos = e.ent:EyePos() end
			local col = e.team and BLUE or (e.visible and GREEN or RED)
			local sx, sy, depth = project(pos, v, w, h)
			local dist = pos:Distance(v.origin) / 52.49
			if sx then
				local size = math.Clamp(1400 / math.max(depth, 1), 4, 60)
				surface.SetDrawColor(col)
				surface.DrawOutlinedRect(sx - size * 0.5, sy - size * 0.3, size, size * 3.2, 2)
				local name = IsValid(e.ent) and e.ent:Nick() or "?"
				text(string.format("%s  %.0fm%s", name, dist, e.visible and "" or "  HIDDEN"), sx, sy - size * 0.3 - 16, col, "ZACSpec_S", TEXT_ALIGN_CENTER)
			end
			if not e.visible and not e.team and eyePos() then
				local dir = (pos - eyePos()):GetNormalized()
				if fwd:Dot(dir) > math.cos(math.rad(4)) then aimHidden = IsValid(e.ent) and e.ent:Nick() or "someone" end
			end
		end
	end

	-- crosshair: exactly where their view points
	surface.SetDrawColor(255, 255, 255, 220)
	surface.DrawLine(w / 2 - 8, h / 2, w / 2 + 9, h / 2)
	surface.DrawLine(w / 2, h / 2 - 8, w / 2, h / 2 + 9)
	if aimHidden then text("AIMING AT HIDDEN: " .. aimHidden, w / 2, h / 2 + 24, RED, "ZACSpec_B", TEXT_ALIGN_CENTER) end

	-- info panel
	local x, y = 20, 20
	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(x - 10, y - 10, 430, 300)
	local name = IsValid(target) and target:Nick() or "(gone)"
	text("SPECTATING  " .. name, x, y, WHITE, "ZACSpec_B")
	y = y + 28
	text(IsValid(target) and target:SteamID() or "", x, y, DIM)
	y = y + 18
	text(string.format("Rating %s (%d)   HP %d   Ping %d ms%s", LEVEL_NAME[world.level] or "?", world.score, world.hp, world.ping, world.alive and "" or "   DEAD"), x, y, LEVEL_COL[world.level] or WHITE)
	y = y + 22

	-- keys
	local kx = x
	local b = cur and cur.b or 0
	for _, k in ipairs(KEYS) do
		local on = bit.band(b, k[1]) ~= 0
		surface.SetFont("ZACSpec_S")
		local tw = surface.GetTextSize(k[2]) + 8
		surface.SetDrawColor(on and 255 or 60, on and 255 or 60, on and 255 or 60, on and 230 or 160)
		surface.DrawRect(kx, y, tw, 18)
		draw.SimpleText(k[2], "ZACSpec_S", kx + 4, y + 2, on and Color(0, 0, 0) or DIM)
		kx = kx + tw + 3
		if kx > x + 380 then kx = x y = y + 21 end
	end
	y = y + 26

	-- mouse / angles
	if cur then
		text(string.format("View  pitch %6.2f  yaw %7.2f", cur.p, cur.y), x, y) y = y + 17
		text(string.format("Mouse dx %5d  dy %5d   turn %5.1f deg/tick", cur.mx, cur.my, cur.step or 0), x, y) y = y + 17
		local gapCol = cur.gap > 200 and RED or WHITE
		text(string.format("Input gap %4d ms   tick %+d", cur.gap, cur.ahead), x, y, gapCol) y = y + 17
	else
		text("Waiting for their commands...", x, y, DIM) y = y + 17
	end
	if world.stuck then text("NO INPUT - HELD IN PLACE (airstuck / lag)", x, y, RED) y = y + 17 end
	if #noMouse > 0 then text(#noMouse .. " turn(s) without mouse movement in 5s", x, y, #noMouse >= 3 and RED or Color(255, 190, 40)) y = y + 17 end
	y = y + 6

	-- turn per tick, last 2 seconds (tall red bars = snaps)
	local gx, gy, gw, gh = x, y, 400, 50
	surface.SetDrawColor(255, 255, 255, 30)
	surface.DrawRect(gx, gy, gw, gh)
	local bw = gw / HIST
	for i, s in ipairs(hist) do
		local step = s.step or 0
		local bh = math.min(step / 45, 1) * gh
		if step > 20 then surface.SetDrawColor(255, 60, 50, 255) elseif s.nomouse then surface.SetDrawColor(255, 190, 40, 255) else surface.SetDrawColor(220, 220, 220, 200) end
		surface.DrawRect(gx + (i - 1) * bw, gy + gh - bh, math.max(bw - 1, 1), bh)
	end
	text("turn per tick (red = snap over 20 deg, orange = no mouse)", gx, gy + gh + 2, DIM, "ZACSpec_S")

	text("LMB next   RMB previous   R first/third person   SPACE stop", w / 2, h - 40, WHITE, "ZACSpec", TEXT_ALIGN_CENTER)
end)
