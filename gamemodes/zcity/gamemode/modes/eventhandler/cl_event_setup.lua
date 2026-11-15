---------------------------------------------------------------------------
-- Event Setup (Chudmorse style)
--   open with !eventsetup or zb_event_setup
--   (locals only: any function put on MODE becomes a gamemode hook)
---------------------------------------------------------------------------

local State = {
	name = "Event", role = "Player", objective = "", endLogic = 2,
	active = false, current = "", nextRound = "", players = {},
}

local C = {
	bg = Color(10, 10, 19, 242),
	panel = Color(0, 0, 0, 140),
	row = Color(255, 255, 255, 6),
	rowHover = Color(255, 255, 255, 16),
	line = Color(255, 255, 255, 35),
	lineHi = Color(255, 255, 255, 80),
	red = Color(192, 0, 0),
	redHi = Color(225, 25, 25),
	redDim = Color(192, 0, 0, 70),
	green = Color(50, 200, 50),
	text = Color(225, 225, 225),
	dim = Color(150, 150, 150),
	faint = Color(95, 95, 105),
}

local SND_HOVER, SND_SELECT, SND_ERROR = "ui/rem_hover.wav", "ui/rem_select.wav", "buttons/button10.wav"

local END_LOGIC = {
	{id = 1, label = "EVENTERS LEFT", desc = "Ends when only eventers are still alive"},
	{id = 2, label = "LAST ALIVE", desc = "Ends when one player (or nobody) is left"},
	{id = 3, label = "MANUAL", desc = "Never ends on its own - use END EVENT"},
}

local function U(n)
	return math.max(1, math.floor(n * math.min(ScrW(), ScrH()) / 1000))
end

local function CreateFonts()
	surface.CreateFont("ChudSetup_Title", {font = "Verily Serif Mono", size = math.max(22, U(34)), weight = 200})
	surface.CreateFont("ChudSetup_Body", {font = "Verily Serif Mono", size = math.max(16, U(20)), weight = 200})
	surface.CreateFont("ChudSetup_Small", {font = "Verily Serif Mono", size = math.max(13, U(15)), weight = 200})
end
CreateFonts()
hook.Add("OnScreenSizeChanged", "ChudSetup_Fonts", CreateFonts)

local function Fit(text, font, maxW)
	surface.SetFont(font)
	if maxW <= 0 or surface.GetTextSize(text) <= maxW then return text end
	while #text > 1 and surface.GetTextSize(text .. "...") > maxW do
		text = text:sub(1, -2)
	end
	return text .. "..."
end

local function SendAction(action, writer)
	net.Start("event_setup_action")
	net.WriteString(action)
	if writer then writer() end
	net.SendToServer()
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local function ChudButton(parent, label, onClick, opts)
	opts = opts or {}
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.Label = label
	b.Font = opts.font or "ChudSetup_Small"
	b.Danger = opts.danger
	b.Filled = opts.filled

	function b:SizeToLabel(pad)
		surface.SetFont(self.Font)
		local text = isfunction(self.Label) and self.Label(self) or self.Label
		self:SetWide(surface.GetTextSize(text) + (pad or U(14)) * 2)
	end

	b.OnCursorEntered = function(self) if self:IsEnabled() then surface.PlaySound(SND_HOVER) end end
	b.DoClick = function(self)
		surface.PlaySound(SND_SELECT)
		if onClick then onClick(self) end
	end

	b.Paint = function(self, w, h)
		local hov = self:IsHovered() and self:IsEnabled()
		local filled = self.Filled
		if isfunction(filled) then filled = filled(self) end
		local text = isfunction(self.Label) and self.Label(self) or self.Label

		if filled then
			surface.SetDrawColor(hov and C.redHi or C.red)
			surface.DrawRect(0, 0, w, h)
		else
			surface.SetDrawColor(0, 0, 0, hov and 210 or 150)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(hov and (self.Danger and C.redHi or C.lineHi) or C.line)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			if hov then
				surface.SetDrawColor(C.red)
				surface.DrawRect(0, h - U(2), w, U(2))
			end
		end

		local col = C.text
		if not self:IsEnabled() then col = C.faint
		elseif self.Danger and hov and not filled then col = C.redHi end
		draw.SimpleText(text, self.Font, w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return b
end

local function ChudEntry(parent, placeholder, maxLen)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont("ChudSetup_Body")
	e:SetUpdateOnType(true)
	e:SetDrawLanguageID(false)
	e.Placeholder = placeholder
	e.MaxLen = maxLen
	e.AllowInput = function(self)
		if self.MaxLen and #self:GetText() >= self.MaxLen then return true end
	end
	e.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 170)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(self:HasFocus() and C.red or C.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		if self:GetText() == "" and self.Placeholder and not self:HasFocus() then
			draw.SimpleText(self.Placeholder, self:GetFont(), U(6), self:IsMultiline() and U(6) or h / 2, C.faint,
				TEXT_ALIGN_LEFT, self:IsMultiline() and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
		end
		self:DrawTextEntryText(C.text, C.redDim, C.text)
		if self.MaxLen and self:HasFocus() then
			draw.SimpleText(#self:GetText() .. "/" .. self.MaxLen, "ChudSetup_Small", w - U(6), h - U(4), C.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end
	return e
end

local function StyleScroll(scroll)
	local bar = scroll:GetVBar()
	bar:SetWide(U(6))
	bar:SetHideButtons(true)
	bar.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
	end
	bar.btnGrip.Paint = function(self, w, h)
		surface.SetDrawColor(self:IsHovered() and C.redHi or C.red)
		surface.DrawRect(0, 0, w, h)
	end
end

local function PanelBG(self, w, h)
	surface.SetDrawColor(C.panel)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(C.line)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function SectionTitle(parent, text, rightText)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(U(30))
	p:DockMargin(0, 0, 0, U(8))
	p.Paint = function(self, w, h)
		draw.SimpleText(text, "ChudSetup_Body", 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local r = isfunction(rightText) and rightText() or rightText
		if r then draw.SimpleText(r, "ChudSetup_Small", w, h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
		surface.SetDrawColor(C.red)
		surface.DrawRect(0, h - U(2), U(28), U(2))
		surface.SetDrawColor(C.line)
		surface.DrawRect(U(28), h - 1, w - U(28), 1)
	end
	return p
end

local function FieldLabel(parent, text)
	local l = vgui.Create("DLabel", parent)
	l:Dock(TOP)
	l:SetFont("ChudSetup_Small")
	l:SetTextColor(C.dim)
	l:SetText(text)
	l:SizeToContentsY()
	l:DockMargin(0, U(6), 0, U(4))
	return l
end

local function ChudConfirm(parent, text, yesLabel, onYes)
	local o = vgui.Create("DPanel", parent)
	o:SetSize(parent:GetWide(), parent:GetTall())
	o:SetPos(0, 0)
	o:MoveToFront()
	o.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, 0, w, h)
	end

	local box = vgui.Create("DPanel", o)
	box:SetSize(math.min(U(520), o:GetWide() - 40), U(150))
	box:Center()
	box.Paint = function(self, w, h)
		surface.SetDrawColor(C.bg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(C.red)
		surface.DrawRect(0, 0, w, U(3))
		draw.SimpleText(text, "ChudSetup_Body", w / 2, U(46), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local row = vgui.Create("DPanel", box)
	row:SetPaintBackground(false)
	row:SetTall(U(36))

	local yes = ChudButton(row, yesLabel, function() o:Remove() onYes() end, {font = "ChudSetup_Body", filled = true})
	yes:SizeToLabel(U(20))
	local no = ChudButton(row, "CANCEL", function() o:Remove() end, {font = "ChudSetup_Body"})
	no:SizeToLabel(U(20))

	row:SetWide(yes:GetWide() + no:GetWide() + U(8))
	yes:SetPos(0, 0) yes:SetTall(U(36))
	no:SetPos(yes:GetWide() + U(8), 0) no:SetTall(U(36))
	row:SetPos((box:GetWide() - row:GetWide()) / 2, box:GetTall() - U(36) - U(18))

	o.OnMousePressed = function() o:Remove() end
	return o
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

local function OpenSetupMenu()
	if IsValid(EventSetupMenu) then EventSetupMenu:Remove() end

	local P = U(14)
	local W = math.min(math.Clamp(ScrW() * 0.66, 860, 1250), ScrW() - 20)
	local H = math.min(math.Clamp(ScrH() * 0.74, 580, 860), ScrH() - 20)

	local f = vgui.Create("EditablePanel")
	EventSetupMenu = f
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f:SetKeyboardInputEnabled(true)
	f.StartTime = SysTime()
	f:SetAlpha(0)
	f:AlphaTo(255, 0.15)

	f.Paint = function(self, w, h)
		Derma_DrawBackgroundBlur(self, self.StartTime)
		surface.SetDrawColor(C.bg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(C.red)
		surface.DrawRect(0, 0, w, U(3))
	end

	f.Think = function(self)
		if input.IsKeyDown(KEY_ESCAPE) then
			gui.HideGameUI()
			self:Remove()
		end
	end

	function f:Toast(msg, isError)
		self.ToastText = msg
		self.ToastError = isError
		self.ToastTime = CurTime()
	end

	-------------------------------------------------------------------
	-- Header
	-------------------------------------------------------------------
	local header = vgui.Create("DPanel", f)
	header:Dock(TOP)
	header:SetTall(U(70))
	header.Paint = function(self, w, h)
		draw.SimpleText("EVENT SETUP", "ChudSetup_Title", P, U(10), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		surface.SetFont("ChudSetup_Title")
		local tw, th = surface.GetTextSize("EVENT SETUP")
		draw.SimpleText("//  " .. string.upper(State.name ~= "" and State.name or "Event"), "ChudSetup_Body",
			P + tw + U(12), U(10) + th / 2, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("SET THE DETAILS, PICK YOUR EVENTERS, THEN START IT  ·  EVENTERS PICKED BEFORE THE ROUND CARRY INTO IT",
			"ChudSetup_Small", P, U(12) + th, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if f.ToastText then
			local age = CurTime() - f.ToastTime
			if age < 3.5 then
				local a = 255 * math.Clamp(3.5 - age, 0, 1)
				local col = f.ToastError and ColorAlpha(C.redHi, a) or ColorAlpha(C.text, a)
				draw.SimpleText(f.ToastText, "ChudSetup_Body", w - P - U(48), U(10) + th / 2, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetDrawColor(C.line)
		surface.DrawRect(P, h - 1, w - P * 2, 1)
	end

	local close = ChudButton(header, "X", function() f:Remove() end, {font = "ChudSetup_Body", danger = true})
	close:SetSize(U(36), U(36))
	header.PerformLayout = function(self, w, h)
		close:SetPos(w - P - close:GetWide(), U(10))
	end

	-------------------------------------------------------------------
	-- Footer: round controls
	-------------------------------------------------------------------
	local footer = vgui.Create("DPanel", f)
	footer:Dock(BOTTOM)
	footer:SetTall(U(64))
	footer:DockPadding(P, U(14), P, U(14))
	footer.Paint = function(self, w, h)
		surface.SetDrawColor(C.line)
		surface.DrawRect(P, 0, w - P * 2, 1)
	end

	local startNext = ChudButton(footer, "SET AS NEXT ROUND", function()
		SendAction("start", function() net.WriteBool(false) end)
	end, {font = "ChudSetup_Body"})
	startNext:Dock(LEFT)
	startNext:SizeToLabel()

	local startNow = ChudButton(footer, "START NOW", function()
		if State.active then return f:Toast("The event is already running.", true) end
		ChudConfirm(f, "END THE CURRENT ROUND AND START THE EVENT?", "START EVENT", function()
			SendAction("start", function() net.WriteBool(true) end)
		end)
	end, {font = "ChudSetup_Body", filled = true})
	startNow:Dock(LEFT)
	startNow:DockMargin(U(6), 0, 0, 0)
	startNow:SizeToLabel()

	local endEvent = ChudButton(footer, "END EVENT", function()
		ChudConfirm(f, "END THE EVENT ROUND NOW?", "END EVENT", function() SendAction("end") end)
	end, {font = "ChudSetup_Body", danger = true})
	endEvent:Dock(LEFT)
	endEvent:DockMargin(U(6), 0, 0, 0)
	endEvent:SizeToLabel()

	local loot = ChudButton(footer, "LOOT TABLE", function()
		f:Remove()
		RunConsoleCommand("zb_event_loot_menu")
	end, {font = "ChudSetup_Body"})
	loot:Dock(RIGHT)
	loot:SizeToLabel()

	local status = vgui.Create("DPanel", footer)
	status:Dock(FILL)
	status:DockMargin(U(16), 0, U(16), 0)
	status.Paint = function(self, w, h)
		local text, col
		if State.active then
			text, col = "EVENT LIVE", C.red
		elseif State.nextRound == "event" then
			text, col = "EVENT IS UP NEXT", C.green
		else
			text, col = "CURRENT: " .. string.upper(State.current ~= "" and State.current or "-") .. "  ·  NEXT: " .. string.upper(State.nextRound ~= "" and State.nextRound or "RANDOM"), C.faint
		end
		draw.SimpleText(Fit(text, "ChudSetup_Small", w), "ChudSetup_Small", 0, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-------------------------------------------------------------------
	-- Body
	-------------------------------------------------------------------
	local body = vgui.Create("DPanel", f)
	body:Dock(FILL)
	body:DockPadding(P, P, P, P)
	body:SetPaintBackground(false)

	local left = vgui.Create("DPanel", body)
	left:Dock(LEFT)
	left:SetWide(math.floor((W - P * 3) * 0.5))
	left:DockPadding(U(12), U(10), U(12), U(12))
	left.Paint = PanelBG

	local right = vgui.Create("DPanel", body)
	right:Dock(FILL)
	right:DockMargin(P, 0, 0, 0)
	right:DockPadding(U(12), U(10), U(12), U(12))
	right.Paint = PanelBG

	-------------------------------------------------------------------
	-- Left: details
	-------------------------------------------------------------------
	local dirty = false
	local pendingLogic = State.endLogic

	SectionTitle(left, "DETAILS", function() return dirty and "UNSAVED CHANGES" or nil end)

	FieldLabel(left, "EVENT NAME")
	local nameEntry = ChudEntry(left, "Event", 48)
	nameEntry:Dock(TOP)
	nameEntry:SetTall(U(34))
	nameEntry:SetText(State.name)

	FieldLabel(left, "PLAYER ROLE  (WHAT NON-EVENTERS ARE CALLED)")
	local roleEntry = ChudEntry(left, "Player", 32)
	roleEntry:Dock(TOP)
	roleEntry:SetTall(U(34))
	roleEntry:SetText(State.role)

	FieldLabel(left, "OBJECTIVE  (SHOWN ON THE INTRO SCREEN)")
	local objEntry = ChudEntry(left, "Survive. Or don't.", 160)
	objEntry:Dock(TOP)
	objEntry:SetTall(U(70))
	objEntry:SetMultiline(true)
	objEntry:SetText(State.objective)

	for _, e in ipairs({nameEntry, roleEntry, objEntry}) do
		e.OnValueChange = function() dirty = true end
	end

	FieldLabel(left, "ROUND ENDS WHEN")
	local logicButtons = {}
	for _, opt in ipairs(END_LOGIC) do
		local row = vgui.Create("DPanel", left)
		row:Dock(TOP)
		row:SetTall(U(32))
		row:DockMargin(0, 0, 0, U(4))
		row:SetPaintBackground(false)

		local b = ChudButton(row, opt.label, function()
			pendingLogic = opt.id
			dirty = true
		end, {filled = function() return pendingLogic == opt.id end})
		b:Dock(LEFT)
		surface.SetFont("ChudSetup_Small")
		b:SetWide(surface.GetTextSize("EVENTERS LEFT") + U(30))
		logicButtons[#logicButtons + 1] = b

		local d = vgui.Create("DPanel", row)
		d:Dock(FILL)
		d:DockMargin(U(10), 0, 0, 0)
		d.Paint = function(self, w, h)
			draw.SimpleText(Fit(opt.desc, "ChudSetup_Small", w), "ChudSetup_Small", 0, h / 2,
				pendingLogic == opt.id and C.text or C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local saveRow = vgui.Create("DPanel", left)
	saveRow:Dock(BOTTOM)
	saveRow:SetTall(U(36))
	saveRow:SetPaintBackground(false)

	local function LoadFields()
		nameEntry:SetText(State.name)
		roleEntry:SetText(State.role)
		objEntry:SetText(State.objective)
		pendingLogic = State.endLogic
		dirty = false
	end

	local save = ChudButton(saveRow, "SAVE DETAILS", function()
		SendAction("details", function()
			net.WriteString(nameEntry:GetValue())
			net.WriteString(roleEntry:GetValue())
			net.WriteString(objEntry:GetValue())
			net.WriteUInt(pendingLogic, 2)
		end)
		dirty = false
	end, {font = "ChudSetup_Body", filled = function() return dirty end})
	save:Dock(LEFT)
	save:SizeToLabel(U(20))

	local revert = ChudButton(saveRow, "REVERT", function() LoadFields() end, {danger = true})
	revert:Dock(LEFT)
	revert:DockMargin(U(6), 0, 0, 0)
	revert:SizeToLabel()
	revert.Think = function(self) self:SetEnabled(dirty) end

	-------------------------------------------------------------------
	-- Right: eventers
	-------------------------------------------------------------------
	SectionTitle(right, "EVENTERS", function()
		local n = 0
		for _, p in ipairs(State.players) do if p.eventer then n = n + 1 end end
		return n .. " / " .. #State.players .. " PLAYERS"
	end)

	local list = vgui.Create("DScrollPanel", right)
	list:Dock(FILL)
	StyleScroll(list)

	local function RebuildPlayers()
		list:Clear()

		local players = table.Copy(State.players)
		table.sort(players, function(a, b)
			if a.eventer ~= b.eventer then return a.eventer end
			return string.lower(a.nick) < string.lower(b.nick)
		end)

		if #players == 0 then
			local empty = list:Add("DPanel")
			empty:Dock(TOP)
			empty:SetTall(U(60))
			empty.Paint = function(self, w, h)
				draw.SimpleText("NO PLAYERS", "ChudSetup_Small", w / 2, h / 2, C.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			return
		end

		for _, p in ipairs(players) do
			local row = list:Add("DPanel")
			row:Dock(TOP)
			row:SetTall(U(38))
			row:DockMargin(0, 0, U(8), U(4))
			row:DockPadding(0, U(5), U(6), U(5))

			local toggle = ChudButton(row, p.eventer and "REMOVE" or "MAKE EVENTER", function()
				SendAction("eventer", function()
					net.WriteString(p.sid)
					net.WriteBool(not p.eventer)
				end)
			end, {danger = p.eventer})
			toggle:Dock(RIGHT)
			surface.SetFont("ChudSetup_Small")
			toggle:SetWide(surface.GetTextSize("MAKE EVENTER") + U(24))

			row.Paint = function(self, w, h)
				local hov = self:IsHovered() or self:IsChildHovered()
				surface.SetDrawColor(hov and C.rowHover or C.row)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(p.eventer and C.green or C.redDim)
				surface.DrawRect(0, 0, U(3), h)

				local x = U(14)
				local tagW = 0
				local tag = p.eventer and "EVENTER" or string.upper(State.role ~= "" and State.role or "Player")
				surface.SetFont("ChudSetup_Small")
				tagW = surface.GetTextSize(tag)

				local nameMax = w - x - toggle:GetWide() - tagW - U(70)
				local nick = Fit(p.nick, "ChudSetup_Body", nameMax)
				local nameCol = (p.spectator or not p.alive) and C.dim or C.text
				draw.SimpleText(nick, "ChudSetup_Body", x, h / 2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				surface.SetFont("ChudSetup_Body")
				x = x + surface.GetTextSize(nick) + U(10)

				if p.admin then
					draw.SimpleText("ADMIN", "ChudSetup_Small", x, h / 2, C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end

				draw.SimpleText(tag, "ChudSetup_Small", w - toggle:GetWide() - U(16), h / 2,
					p.eventer and C.green or C.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	-------------------------------------------------------------------
	-- Sync
	-------------------------------------------------------------------
	function f:OnStateUpdated()
		if not dirty and not nameEntry:HasFocus() and not roleEntry:HasFocus() and not objEntry:HasFocus() then
			LoadFields()
		end
		RebuildPlayers()
	end

	LoadFields()
	RebuildPlayers()
end

net.Receive("event_setup_sync", function()
	local data = net.ReadTable()
	if not istable(data) then return end
	for k, v in pairs(data) do State[k] = v end
	State.players = State.players or {}

	if IsValid(EventSetupMenu) and EventSetupMenu.OnStateUpdated then
		EventSetupMenu:OnStateUpdated()
	end
end)

net.Receive("event_setup_notify", function()
	local msg = net.ReadString()
	local isError = net.ReadBool()

	if IsValid(EventSetupMenu) then
		EventSetupMenu:Toast(msg, isError)
	else
		chat.AddText(isError and C.redHi or C.red, "[Event Setup] ", color_white, msg)
	end
	if isError then surface.PlaySound(SND_ERROR) end
end)

net.Receive("event_setup_open", function()
	OpenSetupMenu()
end)

concommand.Add("zb_event_setup_menu", function()
	RunConsoleCommand("zb_event_setup")
end)
