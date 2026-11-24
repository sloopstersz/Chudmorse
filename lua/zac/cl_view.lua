local UI = ZACUI

local view
local cam = { mode = "free", pos = nil, ang = nil, yaw = 30, pitch = 22, cursor = false }
local panel
local MODES = { free = "Free camera", orbit = "Orbit", shooter = "Shooter's eyes", walk = "Walk" }

local COL_SHOOTER = Color(90, 170, 255)
local COL_VICTIM = Color(255, 70, 60)
local COL_SHOT = Color(255, 220, 80)
local COL_ORGAN = Color(255, 140, 220)
local WHITE = Color(240, 240, 240)

surface.CreateFont("ZACView", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("ZACViewS", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("ZACViewT", { font = "Roboto", size = 22, weight = 800, extended = true })

local function center(mn, mx) return (mn + mx) * 0.5 end

local function setCursor(on)
	cam.cursor = on
	gui.EnableScreenClicker(on)
end

local function close()
	view = nil
	if cam.cursor then setCursor(false) end
	if IsValid(panel) then panel:Remove() end
	if IsValid(ZAC.ViewReturnFrame) then ZAC.ViewReturnFrame:SetVisible(true) end
	ZAC.ViewReturnFrame = nil
end
ZAC.CloseView = close
ZAC.IsViewing = function() return view ~= nil end

hook.Add("OnShowZCityPause", "zac_view_esc", function()
	if view then close() return false end
end)

function ZAC.RequestView(id, frame)
	ZAC.ViewReturnFrame = frame
	net.Start("zac_view_req")
	net.WriteUInt(id, 32)
	net.SendToServer()
end

local function gotoSpot(which)
	if not view then return end
	net.Start("zac_view_goto")
	net.WriteUInt(view.id, 32)
	net.WriteUInt(which, 2)
	net.SendToServer()
	cam.mode = "walk"
	setCursor(false)
end

local function startFree()
	local mid = (view.aEye + view.hit) * 0.5
	local ang = Angle(cam.pitch, cam.yaw, 0)
	local span = math.max(view.aEye:Distance(view.hit), 120)
	cam.pos = mid - ang:Forward() * math.Clamp(span * 0.9, 150, 4000)
	cam.ang = ang
end

local function button(parent, text, fn)
	local b = UI.Button(parent, text, fn)
	b:Dock(LEFT)
	b:DockMargin(0, 0, 5, 0)
	b:SetWide(math.max(40, b:GetWide()))
	return b
end

local function modeButton(parent, mode)
	local b = button(parent, MODES[mode], function()
		if mode == "free" and not cam.pos then startFree() end
		cam.mode = mode
		if mode ~= "orbit" then setCursor(false) end
	end)
	b.Think = function(self) self.active = cam.mode == mode end
	return b
end

local function openPanel()
	if IsValid(panel) then panel:Remove() end
	panel = vgui.Create("EditablePanel")
	panel:SetSize(math.min(ScrW() - 40, 980), 44)
	panel:SetPos(ScrW() / 2 - panel:GetWide() / 2, ScrH() - 64)
	panel:SetMouseInputEnabled(true)
	panel:SetKeyboardInputEnabled(false)
	panel:DockPadding(8, 7, 8, 7)
	panel.Paint = function(_, w, h) UI.Box(w, h, UI.BG, Color(255, 255, 255, 90)) end

	for _, m in ipairs({ "free", "orbit", "shooter", "walk" }) do modeButton(panel, m) end
	button(panel, "GOTO LOCATION", function() gotoSpot(1) end)
	button(panel, "GOTO SHOOTER", function() gotoSpot(2) end)
	local x = UI.Button(panel, "CLOSE", close)
	x:Dock(RIGHT)
	x:SetWide(80)
end

net.Receive("zac_view", function()
	local id = net.ReadUInt(32)
	if not net.ReadBool() then
		chat.AddText(Color(255, 120, 120), "[AC] ", WHITE, "No view for that line: only hits between two players are kept, since the last server restart.")
		if IsValid(ZAC.ViewReturnFrame) then ZAC.ViewReturnFrame:SetVisible(true) end
		return
	end
	local v = { id = id, killed = net.ReadBool() }
	v.attName, v.attSid, v.vicName, v.vicSid = net.ReadString(), net.ReadString(), net.ReadString(), net.ReadString()
	v.weapon, v.part, v.kind = net.ReadString(), net.ReadString(), net.ReadString()
	v.dmg, v.dist, v.clock = net.ReadFloat(), net.ReadFloat(), net.ReadUInt(32)
	v.aEye, v.aAng, v.aMin, v.aMax, v.aRag = net.ReadVector(), net.ReadAngle(), net.ReadVector(), net.ReadVector(), net.ReadBool()
	v.vMin, v.vMax, v.vRag = net.ReadVector(), net.ReadVector(), net.ReadBool()
	v.hit = net.ReadBool() and net.ReadVector() or center(v.vMin, v.vMax)
	v.organs = {}
	for i = 1, net.ReadUInt(4) do
		v.organs[i] = { name = net.ReadString() }
		if net.ReadBool() then v.organs[i].pos = net.ReadVector() end
	end

	view = v
	cam.yaw, cam.pitch, cam.mode = (v.hit - v.aEye):Angle().y + 70, 22, "free"
	startFree()
	if IsValid(ZAC.ViewReturnFrame) then ZAC.ViewReturnFrame:SetVisible(false) end
	openPanel()
	setCursor(false)
end)

net.Receive("zac_view_goto_result", function()
	local ok, text = net.ReadBool(), net.ReadString()
	chat.AddText(ok and Color(140, 220, 140) or Color(255, 120, 120), "[AC] ", WHITE, text)
end)

local f3Was = false
hook.Add("Think", "zac_view_keys", function()
	if not view then f3Was = false return end
	local f3 = input.IsKeyDown(KEY_F3)
	if f3 and not f3Was then setCursor(not cam.cursor) end
	f3Was = f3
	if gui.IsGameUIVisible() then
		gui.HideGameUI()
		close()
	end
end)
hook.Add("PlayerBindPress", "zac_view_f3", function(_, bind)
	if view and string.find(bind, "showspare1", 1, true) then return true end
end)

local function typing() return IsValid(vgui.GetKeyboardFocus()) or gui.IsConsoleVisible() end

hook.Add("CreateMove", "zac_view_move", function(cmd)
	if not view or cam.mode ~= "free" then return end
	if not cam.cursor then
		local sens = 0.022 * GetConVarNumber("sensitivity")
		cam.ang.p = math.Clamp(cam.ang.p + cmd:GetMouseY() * sens, -89, 89)
		cam.ang.y = cam.ang.y - cmd:GetMouseX() * sens
	end
	cmd:ClearMovement()
	cmd:ClearButtons()
	cmd:SetViewAngles(LocalPlayer():EyeAngles())
end)

hook.Add("Think", "zac_view_fly", function()
	if not view or cam.mode ~= "free" or not cam.pos or typing() then return end
	local speed = (input.IsKeyDown(KEY_LSHIFT) and 900 or 300) * FrameTime()
	local f, r = cam.ang:Forward(), cam.ang:Right()
	local move = Vector(0, 0, 0)
	if input.IsKeyDown(KEY_W) then move = move + f end
	if input.IsKeyDown(KEY_S) then move = move - f end
	if input.IsKeyDown(KEY_D) then move = move + r end
	if input.IsKeyDown(KEY_A) then move = move - r end
	if input.IsKeyDown(KEY_SPACE) then move = move + Vector(0, 0, 1) end
	if input.IsKeyDown(KEY_LCONTROL) then move = move - Vector(0, 0, 1) end
	cam.pos = cam.pos + move * speed
end)

hook.Add("CalcView", "zac_view_cam", function(ply, _, _, fov)
	if not view or cam.mode == "walk" then return end
	if cam.mode == "shooter" then
		return { origin = view.aEye, angles = view.aAng, fov = fov, drawviewer = true }
	end
	if cam.mode == "free" and cam.pos then
		return { origin = cam.pos, angles = cam.ang, fov = fov, drawviewer = true }
	end
	cam.yaw = cam.yaw + FrameTime() * 20
	local mid = (view.aEye + view.hit) * 0.5
	local span = math.max(view.aEye:Distance(view.hit), 120)
	local ang = Angle(cam.pitch, cam.yaw, 0)
	return { origin = mid - ang:Forward() * math.Clamp(span * 0.9, 150, 4000), angles = ang, fov = fov, drawviewer = true }
end)

hook.Add("HUDShouldDraw", "zac_view_hud", function(name)
	if view and cam.mode ~= "walk" and name ~= "CHudGMod" and name ~= "CHudChat" then return false end
end)

hook.Add("PostDrawTranslucentRenderables", "zac_view_draw", function(depth, sky)
	if not view or sky then return end
	render.DrawWireframeBox(vector_origin, angle_zero, view.aMin, view.aMax, COL_SHOOTER, false)
	render.DrawWireframeBox(vector_origin, angle_zero, view.vMin, view.vMax, COL_VICTIM, false)
	render.DrawLine(view.aEye, view.hit, COL_SHOT, false)
	local last = view.hit
	for _, o in ipairs(view.organs) do
		if o.pos then
			render.DrawLine(last, o.pos, COL_ORGAN, false)
			last = o.pos
		end
	end
	render.SetColorMaterial()
	render.DrawSphere(view.hit, 2.2, 10, 10, COL_SHOT)
	for _, o in ipairs(view.organs) do
		if o.pos then render.DrawSphere(o.pos, 1.4, 8, 8, COL_ORGAN) end
	end
	render.DrawSphere(view.aEye, 1.6, 8, 8, COL_SHOOTER)
	render.DrawLine(view.aEye, view.aEye + view.aAng:Forward() * 40, Color(90, 170, 255, 160), false)
end)

local function label(pos, lines, col)
	local s = pos:ToScreen()
	if not s.visible then return end
	surface.SetFont("ZACView")
	local w, h = 0, 0
	for _, l in ipairs(lines) do
		local lw, lh = surface.GetTextSize(l)
		w, h = math.max(w, lw), h + lh
	end
	local x, y = s.x - w / 2 - 6, s.y - h - 14
	surface.SetDrawColor(10, 10, 10, 220)
	surface.DrawRect(x, y, w + 12, h + 8)
	surface.SetDrawColor(col)
	surface.DrawOutlinedRect(x, y, w + 12, h + 8, 1)
	local ty = y + 4
	for i, l in ipairs(lines) do
		draw.SimpleText(l, "ZACView", x + 6, ty, i == 1 and col or WHITE)
		ty = ty + select(2, surface.GetTextSize(l))
	end
end

hook.Add("HUDPaint", "zac_view_hud", function()
	if not view then return end
	local sw = ScrW()

	local title = (view.killed and "KILLING SHOT" or "HIT") .. "   " .. os.date("%Y-%m-%d %H:%M:%S", view.clock)
	draw.SimpleText(title, "ZACViewT", sw / 2 + 1, 23, color_black, TEXT_ALIGN_CENTER)
	draw.SimpleText(title, "ZACViewT", sw / 2, 22, WHITE, TEXT_ALIGN_CENTER)
	draw.SimpleText(view.attName .. "  ->  " .. view.vicName, "ZACView", sw / 2, 50, WHITE, TEXT_ALIGN_CENTER)
	local hint = cam.cursor and "F3: back to the camera  -  click a button below"
		or (cam.mode == "free" and "Mouse: look   W A S D: move   SPACE / CTRL: up / down   SHIFT: faster   F3: cursor   ESC: close"
		or "F3: cursor (buttons below)   ESC: close")
	draw.SimpleText(hint, "ZACViewS", sw / 2, 72, Color(200, 200, 200), TEXT_ALIGN_CENTER)

	label(Vector(center(view.aMin, view.aMax).x, center(view.aMin, view.aMax).y, view.aMax.z), {
		"SHOOTER" .. (view.aRag and " (on the ground)" or ""), view.attName, view.attSid }, COL_SHOOTER)
	label(Vector(center(view.vMin, view.vMax).x, center(view.vMin, view.vMax).y, view.vMax.z), {
		"VICTIM" .. (view.vRag and " (on the ground)" or ""), view.vicName, view.vicSid }, COL_VICTIM)

	local hs = view.hit:ToScreen()
	if not hs.visible then return end
	local lines = { "HIT: " .. (view.part ~= "" and view.part or "Body") }
	if #view.organs > 0 then
		local t = {}
		for _, o in ipairs(view.organs) do t[#t + 1] = o.name end
		lines[#lines + 1] = "Through: " .. table.concat(t, "  >  ")
	else
		lines[#lines + 1] = "No organ reported (armor / graze / limb)"
	end
	lines[#lines + 1] = string.format("%.1f dmg  %s", view.dmg, view.kind)
	if view.weapon ~= "" then lines[#lines + 1] = "Weapon: " .. view.weapon end
	if view.dist > 0 then lines[#lines + 1] = string.format("Distance: %.0f m", view.dist) end

	surface.SetFont("ZACView")
	local w, h = 0, 0
	for _, l in ipairs(lines) do
		local lw, lh = surface.GetTextSize(l)
		w, h = math.max(w, lw), h + lh
	end
	local bx = math.Clamp(hs.x + 120, 10, ScrW() - w - 30)
	local by = math.Clamp(hs.y - h - 80, 80, ScrH() - h - 100)
	if bx < hs.x and bx + w + 12 > hs.x - 20 then bx = math.max(10, hs.x - w - 140) end

	local px = (hs.x > bx + w / 2) and (bx + w + 12) or bx
	surface.SetDrawColor(COL_SHOT)
	surface.DrawLine(px, by + h + 8, hs.x, hs.y)
	surface.DrawLine(px, by + h + 9, hs.x, hs.y + 1)
	draw.RoundedBox(4, hs.x - 4, hs.y - 4, 8, 8, COL_SHOT)

	surface.SetDrawColor(10, 10, 10, 230)
	surface.DrawRect(bx, by, w + 12, h + 8)
	surface.SetDrawColor(COL_SHOT)
	surface.DrawOutlinedRect(bx, by, w + 12, h + 8, 1)
	local ty = by + 4
	for i, l in ipairs(lines) do
		draw.SimpleText(l, "ZACView", bx + 6, ty, i == 1 and COL_SHOT or (i == 2 and COL_ORGAN or WHITE))
		ty = ty + select(2, surface.GetTextSize(l))
	end

	for i, o in ipairs(view.organs) do
		if o.pos then
			local s = o.pos:ToScreen()
			if s.visible then draw.SimpleText(i .. ". " .. o.name, "ZACViewS", s.x + 6, s.y - 8, COL_ORGAN) end
		end
	end
end)
