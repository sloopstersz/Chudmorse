ZACUI = ZACUI or {}
local UI = ZACUI

UI.BG = Color(8, 8, 8, 250)
UI.PANEL = Color(18, 18, 18, 255)
UI.HOVER = Color(40, 40, 40, 255)
UI.LINE = Color(255, 255, 255, 45)
UI.WHITE = Color(240, 240, 240)
UI.DIM = Color(150, 150, 150)
UI.BLACK = Color(0, 0, 0)

surface.CreateFont("ZACUI", { font = "Roboto", size = 16, weight = 500 })
surface.CreateFont("ZACUI_B", { font = "Roboto", size = 16, weight = 800 })
surface.CreateFont("ZACUI_T", { font = "Roboto", size = 20, weight = 800 })

local function box(w, h, bg, outline)
	surface.SetDrawColor(bg)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(outline or UI.LINE)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end
UI.Box = box

function UI.Frame(title, w, h)
	local f = vgui.Create("DFrame")
	f:SetTitle("")
	f:SetSize(w, h)
	f:Center()
	f:MakePopup()
	f:DockPadding(8, 36, 8, 8)
	if IsValid(f.btnMaxim) then f.btnMaxim:SetVisible(false) end
	if IsValid(f.btnMinim) then f.btnMinim:SetVisible(false) end
	f.Paint = function(self, pw, ph)
		box(pw, ph, UI.BG, Color(255, 255, 255, 90))
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawRect(0, 0, pw, 2)
		draw.SimpleText(string.upper(title), "ZACUI_T", 10, 16, UI.WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(UI.LINE)
		surface.DrawRect(0, 30, pw, 1)
	end
	f.btnClose.Paint = function(self, bw, bh)
		draw.SimpleText("X", "ZACUI_B", bw / 2, bh / 2, self:IsHovered() and UI.WHITE or UI.DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	return f
end

function UI.Button(parent, text, fn)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.label = text
	b.DoClick = fn or function() end
	b.Paint = function(self, w, h)
		local on = self.active or self:IsHovered()
		box(w, h, on and UI.WHITE or UI.PANEL, Color(255, 255, 255, 110))
		draw.SimpleText(self.label, "ZACUI_B", w / 2, h / 2, on and UI.BLACK or UI.WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	surface.SetFont("ZACUI_B")
	b:SetWide(surface.GetTextSize(text) + 24)
	return b
end

function UI.Toggle(parent, text, on, fn)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.on = on
	surface.SetFont("ZACUI")
	b:SetWide(surface.GetTextSize(text) + 30)
	b.DoClick = function(self) self.on = not self.on if fn then fn(self.on) end end
	b.Paint = function(self, w, h)
		local s = 14
		local y = math.floor((h - s) / 2)
		surface.SetDrawColor(255, 255, 255, 200)
		surface.DrawOutlinedRect(2, y, s, s, 1)
		if self.on then surface.DrawRect(5, y + 3, s - 6, s - 6) end
		draw.SimpleText(text, "ZACUI", s + 10, h / 2, self:IsHovered() and UI.WHITE or (self.on and UI.WHITE or UI.DIM), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	return b
end

function UI.Entry(parent, placeholder)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont("ZACUI")
	e.Paint = function(self, w, h)
		box(w, h, UI.PANEL, self:HasFocus() and Color(255, 255, 255, 160) or UI.LINE)
		if self:GetText() == "" and not self:HasFocus() and placeholder then
			draw.SimpleText(placeholder, "ZACUI", 6, h / 2, UI.DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		self:DrawTextEntryText(UI.WHITE, Color(110, 110, 110), UI.WHITE)
	end
	return e
end

local function styleBar(vbar)
	if not IsValid(vbar) then return end
	vbar:SetWide(8)
	vbar.Paint = function(_, w, h) surface.SetDrawColor(0, 0, 0, 200) surface.DrawRect(0, 0, w, h) end
	if vbar.btnUp then vbar.btnUp.Paint = function() end end
	if vbar.btnDown then vbar.btnDown.Paint = function() end end
	if vbar.btnGrip then vbar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(200, 200, 200, 180) surface.DrawRect(1, 0, w - 2, h) end end
end
UI.StyleBar = styleBar

function UI.List(parent)
	local l = vgui.Create("DListView", parent)
	l:SetMultiSelect(false)
	l:SetDataHeight(20)
	l:SetHeaderHeight(22)
	l.Paint = function(_, w, h) box(w, h, Color(0, 0, 0, 230)) end
	styleBar(l.VBar)
	local add = l.AddColumn
	l.AddColumn = function(self, name, ...)
		local c = add(self, name, ...)
		c.Header:SetFont("ZACUI_B")
		c.Header:SetTextColor(UI.WHITE)
		c.Header.Paint = function(_, w, h)
			surface.SetDrawColor(UI.PANEL)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(UI.LINE)
			surface.DrawRect(0, h - 1, w, 1)
			surface.DrawRect(w - 1, 0, 1, h)
		end
		return c
	end
	return l
end

function UI.AddLine(list, ...)
	local line = list:AddLine(...)
	for _, c in pairs(line.Columns) do c:SetFont("ZACUI") end
	line.Paint = function(self, w, h)
		local sel, hov = self:IsSelected(), self:IsHovered()
		if sel then
			surface.SetDrawColor(UI.WHITE)
			surface.DrawRect(0, 0, w, h)
		elseif hov then
			surface.SetDrawColor(UI.HOVER)
			surface.DrawRect(0, 0, w, h)
		end
		surface.SetDrawColor(255, 255, 255, 12)
		surface.DrawRect(0, h - 1, w, 1)
		local col = sel and UI.BLACK or (self.textCol or UI.WHITE)
		for _, c in pairs(self.Columns) do c:SetTextColor(col) end
	end
	return line
end

function UI.Menu()
	local m = DermaMenu()
	m.Paint = function(_, w, h) box(w, h, UI.BG, Color(255, 255, 255, 120)) end
	local api = {}
	function api:AddOption(text, fn)
		local o = m:AddOption(text, fn)
		o:SetFont("ZACUI")
		o.Paint = function(self, w, h)
			if self:IsHovered() then surface.SetDrawColor(UI.WHITE) surface.DrawRect(0, 0, w, h) end
			self:SetTextColor(self:IsHovered() and UI.BLACK or UI.WHITE)
		end
		return o
	end
	function api:AddSpacer()
		local s = m:AddSpacer()
		if IsValid(s) then s.Paint = function(_, w, h) surface.SetDrawColor(UI.LINE) surface.DrawRect(4, h / 2, w - 8, 1) end end
	end
	function api:Open() m:Open() end
	return api
end

local function dialog(title, text, h)
	local f = UI.Frame(title, 460, h)
	f:SetDrawOnTop(true)
	local lbl = vgui.Create("DLabel", f)
	lbl:Dock(TOP)
	lbl:SetTall(48)
	lbl:SetFont("ZACUI")
	lbl:SetTextColor(UI.WHITE)
	lbl:SetWrap(true)
	lbl:SetText(text)
	local bar = vgui.Create("DPanel", f)
	bar:Dock(BOTTOM)
	bar:SetTall(30)
	bar.Paint = nil
	return f, bar
end

function UI.Confirm(title, text, yes, onYes)
	local f, bar = dialog(title, text, 140)
	local no = UI.Button(bar, "NO", function() f:Remove() end)
	no:Dock(RIGHT)
	no:SetWide(90)
	local y = UI.Button(bar, yes or "YES", function() f:Remove() onYes() end)
	y:Dock(RIGHT)
	y:SetWide(math.max(90, y:GetWide()))
	y:DockMargin(0, 0, 8, 0)
	return f
end

function UI.Ask(title, text, default, onOk)
	local f, bar = dialog(title, text, 176)
	local e = UI.Entry(f)
	e:Dock(TOP)
	e:SetTall(26)
	e:SetValue(default or "")
	e:RequestFocus()
	local function ok() local v = e:GetValue() f:Remove() onOk(v) end
	e.OnEnter = ok
	local c = UI.Button(bar, "CANCEL", function() f:Remove() end)
	c:Dock(RIGHT)
	local o = UI.Button(bar, "OK", ok)
	o:Dock(RIGHT)
	o:SetWide(90)
	o:DockMargin(0, 0, 8, 0)
	return f
end

function UI.Tabs(parent, tabs)
	local bar = vgui.Create("DPanel", parent)
	bar:Dock(TOP)
	bar:SetTall(30)
	bar:DockMargin(0, 0, 0, 6)
	bar.Paint = function(_, w, h) surface.SetDrawColor(UI.LINE) surface.DrawRect(0, h - 1, w, 1) end
	local buttons = {}
	local function select(id)
		for _, t in ipairs(tabs) do
			t.panel:SetVisible(t.id == id)
			buttons[t.id].active = t.id == id
		end
	end
	for _, t in ipairs(tabs) do
		local b = UI.Button(bar, t.label, function() select(t.id) end)
		b:Dock(LEFT)
		b:DockMargin(0, 0, 4, 2)
		b:SetWide(math.max(b:GetWide(), 120))
		buttons[t.id] = b
		t.panel:SetParent(parent)
		t.panel:Dock(FILL)
	end
	return select
end
