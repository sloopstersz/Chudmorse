MODE.name = "event"

local MODE = MODE

local radius = nil
local mapsize = 7500

local EventersList = {}

ZonePos = ZonePos or Vector(0,0,0)

local roundend = false

local INTRO_DURATION = 10
local IntroStart = 0
local IntroTilts = {}

local function StopIntroSound()
    if MODE.RoundBeginSound then
        MODE.RoundBeginSound:Stop()
        MODE.RoundBeginSound = nil
    end
end

-- Same intro as homicide: black fade, sliding/tilted text with cursor parallax, round music
net.Receive("event_start",function()
    roundend = false
    zb.RemoveFade()

    IntroStart = CurTime()
    MODE.IntroFadeEndTime = CurTime() + INTRO_DURATION

    IntroTilts = {}
    for i = 1, 16 do
        IntroTilts[i] = (math.random() < 0.5) and 3 or -3
    end

    MODE.CursorLerpX = 0
    MODE.CursorLerpY = 0

    StopIntroSound()
    local lply = LocalPlayer()
    if IsValid(lply) then
        MODE.RoundBeginSound = CreateSound(lply, "rem_newroundcommence.mp3")
        MODE.RoundBeginSound:PlayEx(1, 100)
    end
end)


net.Receive("event_eventers_update", function()
    EventersList = {}
    local data = net.ReadTable()
    for _, id in ipairs(data) do
        EventersList[id] = true
    end
end)

local fighter = {
    color1 = Color(0,120,190)
}

local eventer = {
    color1 = Color(50,200,50)
}

function MODE:RenderScreenspaceEffects()
    local time_diff = (MODE.IntroFadeEndTime or 0) - CurTime()

    if time_diff > 0 then
        zb.RemoveFade()

        local fade = math.min(time_diff / 2.5, 1)

        surface.SetDrawColor(0, 0, 0, 255 * fade)
        surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
    end
end

local function intro_ease_out(x)
    return 1 - (1 - x) ^ 3
end

local function intro_draw_text(text, fontname, x, y, r, g, b, a, ang)
    local m = Matrix()
    m:Translate(Vector(x, y, 0))
    m:Rotate(Angle(0, ang, 0))
    m:Translate(Vector(-x, -y, 0))

    cam.PushModelMatrix(m)
        draw.SimpleText(text, fontname, x, y, Color(r, g, b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.PopModelMatrix()
end

local function with_article(word)
    if string.find(string.lower(word), "^[aeiou]") then
        return "an " .. word
    end
    return "a " .. word
end

function MODE:HUDPaint()
    local lply = LocalPlayer()
    if not IsValid(lply) then return end
    if lply:Team() == TEAM_SPECTATOR then return end

    local t = CurTime() - IntroStart
    if t > INTRO_DURATION then
        StopIntroSound()
        return
    end

    local sw, sh = ScrW(), ScrH()
    local out_fade = math.Clamp((INTRO_DURATION - t) / 1.5, 0, 1)

    if MODE.RoundBeginSound then
        MODE.RoundBeginSound:ChangeVolume(out_fade, 0)
    end

    MODE.CursorLerpX = Lerp(FrameTime() * 6, MODE.CursorLerpX or 0, (gui.MouseX() - sw * 0.5) / (sw * 0.5))
    MODE.CursorLerpY = Lerp(FrameTime() * 6, MODE.CursorLerpY or 0, (gui.MouseY() - sh * 0.5) / (sh * 0.5))

    local cursor_reach = ScreenScale(7)
    local cox = math.Clamp(MODE.CursorLerpX, -1, 1) * cursor_reach
    local coy = math.Clamp(MODE.CursorLerpY, -1, 1) * cursor_reach

    local isEventer = EventersList[lply:SteamID()]
    local roleName = isEventer and "Eventer" or GetGlobalString("ZB_EventRole", "Player")
    local roleColor = isEventer and eventer.color1 or fighter.color1
    local eventName = GetGlobalString("ZB_EventName", "Event")
    local objective = GetGlobalString("ZB_EventObjective", "")

    local elements = {
        {text = eventName, font = "ZB_HomicideHeader", col = color_white, x = sw * 0.5, y = sh * 0.1, dir = "left", delay = 0, plx = 0.9},
        {text = "You are " .. with_article(roleName), font = "ZB_HomicideMediumLarge", col = roleColor, x = sw * 0.5, y = sh * 0.5, dir = "right", delay = 0.7, plx = 1.1},
    }

    if objective ~= "" then
        elements[#elements + 1] = {text = objective, font = "ZB_HomicideMedium", col = color_white, x = sw * 0.5, y = sh * 0.9, dir = "bottom", delay = 1.4, plx = 1.3, notilt = true}
    end

    for i, el in ipairs(elements) do
        local appear = intro_ease_out(math.Clamp((t - el.delay) / 2.0, 0, 1))
        local a = 255 * appear * out_fade

        if a > 1 then
            local slide = 1 - appear
            local x, y = el.x, el.y

            if el.dir == "left" then
                x = x - slide * ScreenScale(220)
            elseif el.dir == "right" then
                x = x + slide * ScreenScale(220)
            elseif el.dir == "bottom" then
                y = y + slide * ScreenScale(120)
            end

            x = x + cox * el.plx
            y = y + coy * el.plx

            local tilt = el.notilt and 0 or (IntroTilts[i] or 3) * appear

            intro_draw_text(el.text, el.font, x, y, el.col.r, el.col.g, el.col.b, a, tilt)
        end
    end
end

-- No end-of-round leaderboard for events: just note that the round ended.
net.Receive("event_end",function()
	net.ReadEntity()
	roundend = CurTime()
end)

function MODE:RoundStart()
    for i, ply in player.Iterator() do
		ply.won = nil
    end

    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end


---------------------------------------------------------------------------
-- Event Loot Manager (Chudmorse style)
--   open with !eventloot or zb_event_loot_menu
---------------------------------------------------------------------------

local LootState = {
	items = {}, defaults = {}, enabled = false, interval = 8, perWave = 1,
	nextWave = 0, active = false, maxItems = 128, presets = {},
}
local ItemByClass = {}
local TotalWeight, DefaultTotal = 0, 0
local MaxItemPct, MaxDefaultPct = 0, 0

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
	text = Color(225, 225, 225),
	dim = Color(150, 150, 150),
	faint = Color(95, 95, 105),
}

local SND_HOVER, SND_SELECT, SND_ERROR = "ui/rem_hover.wav", "ui/rem_select.wav", "buttons/button10.wav"

local function U(n)
	return math.max(1, math.floor(n * math.min(ScrW(), ScrH()) / 1000))
end

local function CreateLootFonts()
	surface.CreateFont("ChudLoot_Title", {font = "Verily Serif Mono", size = math.max(22, U(34)), weight = 200})
	surface.CreateFont("ChudLoot_Body", {font = "Verily Serif Mono", size = math.max(16, U(20)), weight = 200})
	surface.CreateFont("ChudLoot_Small", {font = "Verily Serif Mono", size = math.max(13, U(15)), weight = 200})
end
CreateLootFonts()
hook.Add("OnScreenSizeChanged", "ChudLoot_Fonts", CreateLootFonts)

local function RecalcTotals()
	ItemByClass, TotalWeight, DefaultTotal = {}, 0, 0
	for _, item in ipairs(LootState.items or {}) do
		ItemByClass[item[2]] = item
		TotalWeight = TotalWeight + item[1]
	end
	for _, item in ipairs(LootState.defaults or {}) do
		DefaultTotal = DefaultTotal + item[1]
	end

	MaxItemPct, MaxDefaultPct = 0, 0
	for _, item in ipairs(LootState.items or {}) do
		MaxItemPct = math.max(MaxItemPct, item[1] / math.max(TotalWeight, 1) * 100)
	end
	for _, item in ipairs(LootState.defaults or {}) do
		MaxDefaultPct = math.max(MaxDefaultPct, item[1] / math.max(DefaultTotal, 1) * 100)
	end
end

local function Fit(text, font, maxW)
	surface.SetFont(font)
	if maxW <= 0 or surface.GetTextSize(text) <= maxW then return text end
	while #text > 1 and surface.GetTextSize(text .. "...") > maxW do
		text = text:sub(1, -2)
	end
	return text .. "..."
end

---------------------------------------------------------------------------
-- Item catalog (every weapon / entity the client knows about)
---------------------------------------------------------------------------

local Catalog, CatalogByClass

local function IsBaseClass(class)
	return class:find("_base$") ~= nil or class:find("^base_") ~= nil or class:find("_base_") ~= nil
end

local function DisplayName(name, class)
	if not isstring(name) or name == "" then return class end
	if name:sub(1, 1) == "#" then name = language.GetPhrase(name:sub(2)) end
	return name
end

local function KindOf(class, isWeapon)
	if class == "*ammo*" or class:find("ammo") then return "ammo" end
	if class:find("armor") then return "armor" end
	if isWeapon then return "weapon" end
	return "other"
end

local function BuildCatalog()
	Catalog, CatalogByClass = {}, {}

	local function add(class, name, kind, spawnable)
		if CatalogByClass[class] then return end
		local e = {class = class, name = DisplayName(name, class), kind = kind, spawnable = spawnable}
		e.search = string.lower(e.name .. " " .. class)
		Catalog[#Catalog + 1] = e
		CatalogByClass[class] = e
	end

	add("*ammo*", "Random Ammo", "ammo", true)

	for _, w in ipairs(weapons.GetList()) do
		local class = w.ClassName
		if isstring(class) and not IsBaseClass(class) then
			add(class, w.PrintName, KindOf(class, true), (w.Spawnable or w.AdminSpawnable) and true or false)
		end
	end

	for class, data in pairs(scripted_ents.GetList()) do
		local t = data.t or {}
		local typ = t.Type or data.type
		if isstring(class) and not IsBaseClass(class) and typ ~= "brush" and typ ~= "point" and typ ~= "filter" then
			add(class, t.PrintName, KindOf(class, false), (t.Spawnable or t.AdminSpawnable) and true or false)
		end
	end

	table.sort(Catalog, function(a, b)
		if a.class == "*ammo*" then return b.class ~= "*ammo*" end
		if b.class == "*ammo*" then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
end

local function NameOf(class)
	if class == "*ammo*" then return "Random Ammo" end
	local e = CatalogByClass and CatalogByClass[class]
	return e and e.name or class
end

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------

local IconCache = {}

local function TryMaterial(path)
	if not isstring(path) or path == "" then return end
	path = path:gsub("^materials/", "")
	local check = path:find("%.%a+$") and path or (path .. ".vmt")
	if not file.Exists("materials/" .. check, "GAME") then return end
	local mat = Material(path, "smooth mips")
	if mat and not mat:IsError() then return mat end
end

local function GetIcon(class)
	local cached = IconCache[class]
	if cached ~= nil then return cached or nil end

	local w = weapons.GetStored(class)
	local e = scripted_ents.GetStored(class)
	local mat = TryMaterial(w and w.IconOverride)
		or TryMaterial(e and e.t and e.t.IconOverride)
		or TryMaterial("entities/" .. class .. ".png")
		or TryMaterial("vgui/entities/" .. class)

	IconCache[class] = mat or false
	return mat
end

local KindLetter = {weapon = "W", armor = "A", ammo = "+", other = "E"}

local function DrawIcon(class, x, y, s, alpha)
	alpha = alpha or 255
	surface.SetDrawColor(0, 0, 0, 160 * alpha / 255)
	surface.DrawRect(x, y, s, s)

	local mat = GetIcon(class)
	if mat then
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255, alpha)
		surface.DrawTexturedRect(x, y, s, s)
	else
		local kind = (CatalogByClass and CatalogByClass[class] and CatalogByClass[class].kind) or KindOf(class, class:find("^weapon_") ~= nil)
		draw.SimpleText(KindLetter[kind] or "?", "ChudLoot_Body", x + s / 2, y + s / 2, ColorAlpha(C.faint, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(C.line.r, C.line.g, C.line.b, C.line.a * alpha / 255)
	surface.DrawOutlinedRect(x, y, s, s, 1)
end

---------------------------------------------------------------------------
-- Networking helpers
---------------------------------------------------------------------------

local function SendAction(action, writer)
	net.Start("event_loot_action")
	net.WriteString(action)
	if writer then writer() end
	net.SendToServer()
end

local function Debounce(key, delay, fn)
	timer.Create("ChudLoot_" .. key, delay, 1, fn)
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local function ChudButton(parent, label, onClick, opts)
	opts = opts or {}
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.Label = label
	b.Font = opts.font or "ChudLoot_Small"
	b.Danger = opts.danger
	b.Filled = opts.filled

	function b:SizeToLabel(pad)
		surface.SetFont(self.Font)
		local text = isfunction(self.Label) and self.Label(self) or self.Label
		local tw = surface.GetTextSize(text)
		self:SetWide(tw + (pad or U(14)) * 2)
	end

	b.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
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

local function ChudEntry(parent, placeholder, font)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont(font or "ChudLoot_Body")
	e:SetUpdateOnType(true)
	e:SetDrawLanguageID(false)
	e.Placeholder = placeholder
	e.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, 170)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(self:HasFocus() and C.red or C.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		if self:GetText() == "" and self.Placeholder then
			draw.SimpleText(self.Placeholder, self:GetFont(), U(6), h / 2, C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		self:DrawTextEntryText(C.text, C.redDim, C.text)
	end
	return e
end

-- [-] [value] [+] ; onCommit(value) fires on enter / focus loss / after button clicks
local function ChudStepper(parent, value, min, max, onCommit, opts)
	opts = opts or {}
	local p = vgui.Create("DPanel", parent)
	p:SetPaintBackground(false)
	p.Value = value
	p.Min, p.Max = min, max

	local bw = opts.buttonWidth or U(24)

	local minus = ChudButton(p, "-", nil, {font = "ChudLoot_Body"})
	minus:Dock(LEFT)
	minus:SetWide(bw)

	local plus = ChudButton(p, "+", nil, {font = "ChudLoot_Body"})
	plus:Dock(RIGHT)
	plus:SetWide(bw)

	local entry = ChudEntry(p, nil, opts.font or "ChudLoot_Small")
	entry:Dock(FILL)
	entry:DockMargin(U(2), 0, U(2), 0)
	entry:SetNumeric(true)
	entry:SetText(tostring(value))
	entry:SetUpdateOnType(false)
	p.Entry = entry

	if opts.suffix then
		local paint = entry.Paint
		entry.Paint = function(self, w, h)
			paint(self, w, h)
			if not self:HasFocus() then
				draw.SimpleText(opts.suffix, "ChudLoot_Small", w - U(5), h / 2, C.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	local key = "stepper" .. tostring(p)

	function p:Commit(v, delayed)
		v = math.Clamp(math.floor(tonumber(v) or self.Value), self.Min, self.Max)
		self.Value = v
		if not entry:HasFocus() then entry:SetText(tostring(v)) end
		if onCommit then
			if delayed then
				Debounce(key, 0.35, function() if IsValid(p) then onCommit(p.Value) end end)
			else
				onCommit(v)
			end
		end
	end

	function p:SetValue(v)
		if entry:HasFocus() or timer.Exists("ChudLoot_" .. key) then return end
		self.Value = v
		entry:SetText(tostring(v))
	end

	local function step(dir)
		local amount = input.IsShiftDown() and (opts.bigStep or 10) or 1
		p:Commit(p.Value + dir * amount, true)
		if opts.onPreview then opts.onPreview(p.Value) end
	end

	minus.DoClick = function() surface.PlaySound(SND_SELECT) step(-1) end
	plus.DoClick = function() surface.PlaySound(SND_SELECT) step(1) end
	minus.OnCursorEntered = function() end
	plus.OnCursorEntered = function() end

	entry.OnEnter = function(self) p:Commit(self:GetValue()) if opts.onPreview then opts.onPreview(p.Value) end end
	entry.OnLoseFocus = function(self)
		p:Commit(self:GetValue())
		if opts.onPreview then opts.onPreview(p.Value) end
	end

	p.OnMouseWheeled = function(self, delta) step(delta > 0 and 1 or -1) return true end
	entry.OnMouseWheeled = function(self, delta) step(delta > 0 and 1 or -1) return true end

	return p
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

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

local MAX_BROWSER_ROWS = 150
local FILTERS = {
	{id = "all", label = "ALL"},
	{id = "weapon", label = "WEAPONS"},
	{id = "armor", label = "ARMOR"},
	{id = "ammo", label = "AMMO"},
	{id = "other", label = "OTHER"},
}
local SORTS = {"chance", "name", "added"}

local MenuPrefs = {filter = "all", spawnableOnly = nil, sort = "chance", addWeight = 5, leftTab = "items"}

local function OpenLootMenu()
	if IsValid(LootPollingMenu) then LootPollingMenu:Remove() end
	if not Catalog then BuildCatalog() end
	RecalcTotals()

	if MenuPrefs.spawnableOnly == nil then
		local spawnableWeapons = 0
		for _, e in ipairs(Catalog) do
			if e.kind == "weapon" and e.spawnable then spawnableWeapons = spawnableWeapons + 1 end
		end
		MenuPrefs.spawnableOnly = spawnableWeapons >= 10
	end

	local P = U(14)
	local W = math.min(math.Clamp(ScrW() * 0.82, 900, 1500), ScrW() - 20)
	local H = math.min(math.Clamp(ScrH() * 0.82, 600, 920), ScrH() - 20)

	local f = vgui.Create("EditablePanel")
	LootPollingMenu = f
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
	header:DockPadding(P, P, P, 0)
	header.Paint = function(self, w, h)
		draw.SimpleText("EVENT LOOT", "ChudLoot_Title", P, U(10), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		surface.SetFont("ChudLoot_Title")
		local tw, th = surface.GetTextSize("EVENT LOOT")
		local eventName = string.upper(GetGlobalString("ZB_EventName", "Event"))
		draw.SimpleText("//  " .. eventName, "ChudLoot_Body", P + tw + U(12), U(10) + th / 2, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("CLICK AN ITEM ON THE LEFT TO ADD IT  ·  WEIGHTS ARE RELATIVE  ·  SHIFT = STEP 10  ·  SCROLL OVER A NUMBER TO NUDGE IT",
			"ChudLoot_Small", P, U(12) + th, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if f.ToastText then
			local age = CurTime() - f.ToastTime
			if age < 3.5 then
				local a = 255 * math.Clamp(3.5 - age, 0, 1)
				local col = f.ToastError and ColorAlpha(C.redHi, a) or ColorAlpha(C.text, a)
				draw.SimpleText(f.ToastText, "ChudLoot_Body", w - P - U(48), U(10) + th / 2, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetDrawColor(C.line)
		surface.DrawRect(P, h - 1, w - P * 2, 1)
	end

	local close = ChudButton(header, "X", function() f:Remove() end, {font = "ChudLoot_Body", danger = true})
	close:SetSize(U(36), U(36))
	header.PerformLayout = function(self, w, h)
		close:SetPos(w - P - close:GetWide(), U(10))
	end

	-------------------------------------------------------------------
	-- Footer: spawning controls
	-------------------------------------------------------------------
	local footer = vgui.Create("DPanel", f)
	footer:Dock(BOTTOM)
	footer:SetTall(U(64))
	footer:DockPadding(P, U(14), P, U(14))
	footer.Paint = function(self, w, h)
		surface.SetDrawColor(C.line)
		surface.DrawRect(P, 0, w - P * 2, 1)
	end

	local function FooterLabel(text)
		local l = vgui.Create("DLabel", footer)
		l:SetFont("ChudLoot_Small")
		l:SetTextColor(C.dim)
		l:SetText(text)
		l:SizeToContents()
		l:Dock(LEFT)
		l:DockMargin(U(16), 0, U(6), 0)
		return l
	end

	local toggle = ChudButton(footer, function()
		return LootState.enabled and "LOOT SPAWNING: ON" or "LOOT SPAWNING: OFF"
	end, function()
		SendAction("toggle", function() net.WriteBool(not LootState.enabled) end)
	end, {font = "ChudLoot_Body", filled = function() return LootState.enabled end})
	toggle:Dock(LEFT)
	surface.SetFont("ChudLoot_Body")
	toggle:SetWide(surface.GetTextSize("LOOT SPAWNING: OFF") + U(28))

	FooterLabel("EVERY")
	local interval = ChudStepper(footer, LootState.interval, 2, 120, function(v)
		SendAction("interval", function() net.WriteUInt(v, 8) end)
	end, {suffix = "s", bigStep = 5})
	interval:Dock(LEFT)
	interval:SetWide(U(110))

	FooterLabel("BOXES / WAVE")
	local perWave = ChudStepper(footer, LootState.perWave, 1, 10, function(v)
		SendAction("perwave", function() net.WriteUInt(v, 8) end)
	end, {bigStep = 5})
	perWave:Dock(LEFT)
	perWave:SetWide(U(100))

	local spawnNow = ChudButton(footer, "SPAWN WAVE NOW", function() SendAction("spawnnow") end)
	spawnNow:Dock(LEFT)
	spawnNow:DockMargin(U(16), 0, 0, 0)
	spawnNow:SizeToLabel()

	local clearLoot = ChudButton(footer, "CLEAR SPAWNED LOOT", function() SendAction("clearloot") end, {danger = true})
	clearLoot:Dock(LEFT)
	clearLoot:DockMargin(U(6), 0, 0, 0)
	clearLoot:SizeToLabel()

	local status = vgui.Create("DPanel", footer)
	status:Dock(FILL)
	status:DockMargin(U(16), 0, U(16), 0)
	status.Paint = function(self, w, h)
		local text, col
		if not LootState.active then
			text, col = "WAITING FOR EVENT ROUND", C.faint
		elseif not LootState.enabled then
			text, col = "SPAWNING OFF", C.faint
		else
			local left = math.max(0, math.ceil((LootState.nextWave or 0) - CurTime()))
			text, col = left > 0 and ("NEXT WAVE IN " .. left .. "S") or "SPAWNING...", C.red
		end
		draw.SimpleText(text, "ChudLoot_Small", 0, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
	left:SetWide(math.floor((W - P * 3) * 0.44))
	left:DockPadding(U(10), U(10), U(10), U(10))
	left.Paint = PanelBG

	local right = vgui.Create("DPanel", body)
	right:Dock(FILL)
	right:DockMargin(P, 0, 0, 0)
	right:DockPadding(U(10), U(10), U(10), U(10))
	right.Paint = PanelBG

	-------------------------------------------------------------------
	-- Left: tabs (ITEMS / SAVED TABLES)
	-------------------------------------------------------------------
	local tabRow = vgui.Create("DPanel", left)
	tabRow:Dock(TOP)
	tabRow:SetTall(U(30))
	tabRow:DockMargin(0, 0, 0, U(10))
	tabRow:SetPaintBackground(false)

	local itemsView = vgui.Create("DPanel", left)
	itemsView:Dock(FILL)
	itemsView:SetPaintBackground(false)

	local savedView = vgui.Create("DPanel", left)
	savedView:Dock(FILL)
	savedView:SetPaintBackground(false)

	local function ShowLeftTab(id)
		MenuPrefs.leftTab = id
		itemsView:SetVisible(id == "items")
		savedView:SetVisible(id == "saved")
		left:InvalidateLayout()
	end

	local itemsTab = ChudButton(tabRow, "ITEMS", function() ShowLeftTab("items") end,
		{font = "ChudLoot_Body", filled = function() return MenuPrefs.leftTab == "items" end})
	itemsTab:Dock(LEFT)
	itemsTab:DockMargin(0, 0, U(4), 0)
	itemsTab:SizeToLabel(U(18))

	local savedTab = ChudButton(tabRow, function()
		return "SAVED TABLES (" .. #(LootState.presets or {}) .. ")"
	end, function() ShowLeftTab("saved") end,
		{font = "ChudLoot_Body", filled = function() return MenuPrefs.leftTab == "saved" end})
	savedTab:Dock(LEFT)
	surface.SetFont("ChudLoot_Body")
	savedTab:SetWide(surface.GetTextSize("SAVED TABLES (00)") + U(36))

	-------------------------------------------------------------------
	-- Left: item browser
	-------------------------------------------------------------------
	local searchRow = vgui.Create("DPanel", itemsView)
	searchRow:Dock(TOP)
	searchRow:SetTall(U(34))
	searchRow:SetPaintBackground(false)

	local addWeight = ChudStepper(searchRow, MenuPrefs.addWeight, 1, 1000, function(v)
		MenuPrefs.addWeight = v
	end)
	addWeight:Dock(RIGHT)
	addWeight:SetWide(U(110))

	local addLabel = vgui.Create("DLabel", searchRow)
	addLabel:SetFont("ChudLoot_Small")
	addLabel:SetTextColor(C.dim)
	addLabel:SetText("ADD AT")
	addLabel:SizeToContents()
	addLabel:Dock(RIGHT)
	addLabel:DockMargin(U(10), 0, U(6), 0)

	local search = ChudEntry(searchRow, "Search weapons & entities...")
	search:Dock(FILL)

	local filterRow = vgui.Create("DPanel", itemsView)
	filterRow:Dock(TOP)
	filterRow:SetTall(U(28))
	filterRow:DockMargin(0, U(8), 0, U(8))
	filterRow:SetPaintBackground(false)

	local browser = vgui.Create("DScrollPanel", itemsView)
	browser:Dock(FILL)
	StyleScroll(browser)

	local browserInfo = vgui.Create("DLabel", itemsView)
	browserInfo:Dock(BOTTOM)
	browserInfo:DockMargin(0, U(6), 0, 0)
	browserInfo:SetFont("ChudLoot_Small")
	browserInfo:SetTextColor(C.faint)
	browserInfo:SetText("")

	local function RebuildBrowser()
		browser:Clear()

		local query = string.lower(string.Trim(search:GetValue() or ""))
		local shown, matched = 0, 0
		local rowH = U(44)

		for _, e in ipairs(Catalog) do
			local ok = (MenuPrefs.filter == "all" or e.kind == MenuPrefs.filter)
				and (not MenuPrefs.spawnableOnly or e.spawnable)
				and (query == "" or e.search:find(query, 1, true) ~= nil)

			if ok then
				matched = matched + 1
				if shown < MAX_BROWSER_ROWS then
					shown = shown + 1
					local row = browser:Add("DButton")
					row:SetText("")
					row:Dock(TOP)
					row:SetTall(rowH)
					row:DockMargin(0, 0, U(4), U(3))
					row.Entry = e

					row.Paint = function(self, w, h)
						local inTable = ItemByClass[e.class] ~= nil
						local hov = self:IsHovered()
						surface.SetDrawColor(hov and C.rowHover or C.row)
						surface.DrawRect(0, 0, w, h)
						if inTable then
							surface.SetDrawColor(C.red)
							surface.DrawRect(0, 0, U(3), h)
						end

						local pad = U(6)
						local s = h - pad * 2
						DrawIcon(e.class, pad + U(3), pad, s, inTable and 140 or 255)

						local tx = pad * 2 + s + U(6)
						draw.SimpleText(Fit(e.name, "ChudLoot_Body", w - tx - U(100)), "ChudLoot_Body", tx, h * 0.36, inTable and C.dim or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(e.class, "ChudLoot_Small", tx, h * 0.72, C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

						if inTable then
							draw.SimpleText("IN TABLE", "ChudLoot_Small", w - U(10), h / 2, C.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
						elseif hov then
							draw.SimpleText("+ ADD  " .. MenuPrefs.addWeight, "ChudLoot_Small", w - U(10), h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
						end
					end

					row.DoClick = function()
						if ItemByClass[e.class] then
							surface.PlaySound(SND_ERROR)
							f:Toast(e.name .. " is already in the table", true)
							if f.FlashRow then f.FlashRow(e.class) end
							return
						end
						surface.PlaySound(SND_SELECT)
						SendAction("add", function()
							net.WriteString(e.class)
							net.WriteUInt(MenuPrefs.addWeight, 16)
						end)
					end

					row.DoRightClick = function()
						local m = DermaMenu()
						if not ItemByClass[e.class] then
							for _, wgt in ipairs({1, 5, 10, 25, 50, 100}) do
								m:AddOption("Add with weight " .. wgt, function()
									SendAction("add", function()
										net.WriteString(e.class)
										net.WriteUInt(wgt, 16)
									end)
								end)
							end
							m:AddSpacer()
						end
						m:AddOption("Copy class name", function() SetClipboardText(e.class) end)
						m:Open()
					end
				end
			end
		end

		if matched == 0 then
			browserInfo:SetText("NOTHING MATCHES" .. (MenuPrefs.spawnableOnly and "  ·  TRY TURNING OFF 'SPAWNABLE ONLY'" or ""))
		elseif matched > shown then
			browserInfo:SetText("SHOWING " .. shown .. " OF " .. matched .. "  ·  TYPE TO NARROW IT DOWN")
		else
			browserInfo:SetText(matched .. " ITEMS")
		end
	end

	for _, flt in ipairs(FILTERS) do
		local b = ChudButton(filterRow, flt.label, function()
			MenuPrefs.filter = flt.id
			RebuildBrowser()
		end, {filled = function() return MenuPrefs.filter == flt.id end})
		b:Dock(LEFT)
		b:DockMargin(0, 0, U(4), 0)
		b:SizeToLabel(U(9))
	end

	local spawnableBtn = ChudButton(filterRow, function()
		return MenuPrefs.spawnableOnly and "SPAWNABLE ONLY" or "SHOWING ALL"
	end, function()
		MenuPrefs.spawnableOnly = not MenuPrefs.spawnableOnly
		RebuildBrowser()
	end)
	spawnableBtn:Dock(RIGHT)
	surface.SetFont("ChudLoot_Small")
	spawnableBtn:SetWide(surface.GetTextSize("SPAWNABLE ONLY") + U(18))

	search.OnValueChange = function()
		Debounce("search", 0.15, function() if IsValid(browser) then RebuildBrowser() end end)
	end

	-------------------------------------------------------------------
	-- Right: loot table
	-------------------------------------------------------------------
	local tableHeader = vgui.Create("DPanel", right)
	tableHeader:Dock(TOP)
	tableHeader:SetTall(U(34))
	tableHeader:DockMargin(0, 0, 0, U(8))
	tableHeader.Paint = function(self, w, h)
		draw.SimpleText("LOOT TABLE", "ChudLoot_Body", 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("ChudLoot_Body")
		local tw = surface.GetTextSize("LOOT TABLE")
		local info
		if #LootState.items > 0 then
			info = #LootState.items .. " / " .. (LootState.maxItems or 128) .. " ITEMS  ·  TOTAL WEIGHT " .. TotalWeight
		else
			info = "USING DEFAULT TABLE"
		end
		draw.SimpleText(info, "ChudLoot_Small", tw + U(12), h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local resetBtn = ChudButton(tableHeader, "RESET", function()
		Derma_Query("Clear the whole event loot table?\nEvents will fall back to the default table.", "Reset loot table",
			"Clear it", function() SendAction("reset") end,
			"Cancel", function() end)
	end, {danger = true})
	resetBtn:Dock(RIGHT)
	resetBtn:SizeToLabel()

	local importBtn = ChudButton(tableHeader, "IMPORT DEFAULT", function() SendAction("import") end)
	importBtn:Dock(RIGHT)
	importBtn:DockMargin(0, 0, U(6), 0)
	importBtn:SizeToLabel()

	local sortBtn = ChudButton(tableHeader, function() return "SORT: " .. string.upper(MenuPrefs.sort) end, nil)
	sortBtn:Dock(RIGHT)
	sortBtn:DockMargin(0, 0, U(6), 0)
	surface.SetFont("ChudLoot_Small")
	sortBtn:SetWide(surface.GetTextSize("SORT: CHANCE") + U(24))

	-- column titles
	local columns = vgui.Create("DPanel", right)
	columns:Dock(TOP)
	columns:SetTall(U(18))
	columns:DockMargin(0, 0, U(10), U(4))

	local list = vgui.Create("DScrollPanel", right)
	list:Dock(FILL)
	StyleScroll(list)

	local ROW_H = U(48)
	local COL_WEIGHT = U(120)
	local COL_REMOVE = U(30)
	local COL_CHANCE = U(170)

	columns.Paint = function(self, w, h)
		local xRemove = w - COL_REMOVE
		local xWeight = xRemove - U(8) - COL_WEIGHT
		local xChance = xWeight - U(12) - COL_CHANCE
		draw.SimpleText("ITEM", "ChudLoot_Small", U(10), h / 2, C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("DROP CHANCE", "ChudLoot_Small", xChance, h / 2, C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("WEIGHT", "ChudLoot_Small", xWeight + COL_WEIGHT / 2, h / 2, C.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local rows = {}

	-- draws name/class/chance for a table row; readOnly rows are the default-table preview
	local function PaintLootRow(self, w, h, item, total, maxChance, readOnly)
		local hov = self:IsHovered() or (self:IsChildHovered())
		local flash = self.FlashTime and math.Clamp(1 - (CurTime() - self.FlashTime), 0, 1) or 0

		surface.SetDrawColor(hov and C.rowHover or C.row)
		surface.DrawRect(0, 0, w, h)
		if flash > 0 then
			surface.SetDrawColor(C.red.r, C.red.g, C.red.b, 90 * flash)
			surface.DrawRect(0, 0, w, h)
		end

		local alpha = readOnly and 150 or 255
		local pad = U(6)
		local s = h - pad * 2
		DrawIcon(item[2], pad, pad, s, alpha)

		local xRemove = w - COL_REMOVE
		local xWeight = xRemove - U(8) - COL_WEIGHT
		local xChance = xWeight - U(12) - COL_CHANCE

		local tx = pad * 2 + s + U(4)
		local nameCol = readOnly and C.dim or C.text
		local textW = xChance - tx - U(12)
		draw.SimpleText(Fit(NameOf(item[2]), "ChudLoot_Body", textW), "ChudLoot_Body", tx, h * 0.36, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local valid = item[2] == "*ammo*" or (CatalogByClass and CatalogByClass[item[2]] ~= nil)
		draw.SimpleText(Fit(item[2] .. (valid and "" or "  (NOT INSTALLED)"), "ChudLoot_Small", textW), "ChudLoot_Small", tx, h * 0.72, valid and C.faint or C.redHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local pct = total > 0 and (item[1] / total * 100) or 0
		local barW = COL_CHANCE - U(56)
		local barH = U(6)
		local barY = h / 2 - barH / 2
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(xChance, barY, barW, barH)
		surface.SetDrawColor(C.red.r, C.red.g, C.red.b, alpha)
		surface.DrawRect(xChance, barY, math.max(1, barW * (maxChance > 0 and pct / maxChance or 0)), barH)
		local pctText = pct >= 10 and string.format("%.0f%%", pct) or string.format("%.1f%%", pct)
		draw.SimpleText(pctText, "ChudLoot_Small", xChance + COL_CHANCE, h / 2, readOnly and C.dim or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		if readOnly then
			draw.SimpleText(tostring(item[1]), "ChudLoot_Small", xWeight + COL_WEIGHT / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local function SortedItems(source)
		local sorted = {}
		for i, item in ipairs(source) do sorted[i] = {item = item, order = i} end
		table.sort(sorted, function(a, b)
			if MenuPrefs.sort == "chance" then
				if a.item[1] ~= b.item[1] then return a.item[1] > b.item[1] end
				return a.order < b.order
			elseif MenuPrefs.sort == "name" then
				return string.lower(NameOf(a.item[2])) < string.lower(NameOf(b.item[2]))
			end
			return a.order < b.order
		end)
		return sorted
	end

	local lastSignature

	local function BuildEmptyState()
		local banner = list:Add("DPanel")
		banner:Dock(TOP)
		banner:SetTall(U(96))
		banner:DockMargin(0, 0, U(4), U(10))
		banner.Paint = function(self, w, h)
			surface.SetDrawColor(C.redDim)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText("NO CUSTOM LOOT YET", "ChudLoot_Body", w / 2, U(22), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Events drop the default table below until you add items.", "ChudLoot_Small", w / 2, U(44), C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local imp = ChudButton(banner, "IMPORT DEFAULT TABLE TO EDIT IT", function() SendAction("import") end, {filled = true})
		imp:SizeToLabel()
		imp:SetTall(U(26))
		banner.PerformLayout = function(self, w, h)
			imp:SetPos(w / 2 - imp:GetWide() / 2, h - imp:GetTall() - U(10))
		end

		local defaults = LootState.defaults or {}
		for _, entry in ipairs(SortedItems(defaults)) do
			local row = list:Add("DPanel")
			row:Dock(TOP)
			row:SetTall(ROW_H)
			row:DockMargin(0, 0, U(4), U(3))
			row.Paint = function(self, w, h) PaintLootRow(self, w, h, entry.item, DefaultTotal, MaxDefaultPct, true) end
		end
	end

	local function RebuildTable()
		list:Clear()
		rows = {}

		if #LootState.items == 0 then
			BuildEmptyState()
			return
		end

		for _, entry in ipairs(SortedItems(LootState.items)) do
			local class = entry.item[2]
			local row = list:Add("DPanel")
			row:Dock(TOP)
			row:SetTall(ROW_H)
			row:DockMargin(0, 0, U(4), U(3))
			row.Class = class
			rows[class] = row

			row.Paint = function(self, w, h)
				local item = ItemByClass[class]
				if not item then return end
				PaintLootRow(self, w, h, item, TotalWeight, MaxItemPct, false)
			end

			local remove = ChudButton(row, "X", function()
				SendAction("remove", function() net.WriteString(class) end)
			end, {danger = true})

			local stepper = ChudStepper(row, entry.item[1], 1, 1000, function(v)
				SendAction("weight", function()
					net.WriteString(class)
					net.WriteUInt(v, 16)
				end)
			end, {onPreview = function(v)
				local item = ItemByClass[class]
				if item then
					item[1] = v
					RecalcTotals()
				end
			end})
			row.Stepper = stepper

			row.PerformLayout = function(self, w, h)
				local bh = U(28)
				remove:SetSize(COL_REMOVE, bh)
				remove:SetPos(w - COL_REMOVE, h / 2 - bh / 2)
				stepper:SetSize(COL_WEIGHT, bh)
				stepper:SetPos(w - COL_REMOVE - U(8) - COL_WEIGHT, h / 2 - bh / 2)
			end

			row.OnMousePressed = function(self, code)
				if code ~= MOUSE_RIGHT then return end
				local m = DermaMenu()
				m:AddOption("Copy class name", function() SetClipboardText(class) end)
				m:AddOption("Remove from table", function()
					SendAction("remove", function() net.WriteString(class) end)
				end)
				m:Open()
			end
		end
	end

	f.FlashRow = function(class)
		local row = rows[class]
		if IsValid(row) then
			row.FlashTime = CurTime()
			list:ScrollToChild(row)
		end
	end

	sortBtn.DoClick = function()
		surface.PlaySound(SND_SELECT)
		local idx = 1
		for i, s in ipairs(SORTS) do if s == MenuPrefs.sort then idx = i end end
		MenuPrefs.sort = SORTS[idx % #SORTS + 1]
		RebuildTable()
		lastSignature = nil
	end

	-------------------------------------------------------------------
	-- Left: saved tables
	-------------------------------------------------------------------
	local saveRow = vgui.Create("DPanel", savedView)
	saveRow:Dock(TOP)
	saveRow:SetTall(U(34))
	saveRow:SetPaintBackground(false)

	local presetName = ChudEntry(saveRow, "Name this loot table...")
	presetName:Dock(FILL)
	presetName:SetUpdateOnType(true)

	local function PresetExists(name)
		for _, p in ipairs(LootState.presets or {}) do
			if p.name == name then return p end
		end
	end

	local function DoSavePreset()
		local name = string.Trim(presetName:GetValue() or "")
		if name == "" then
			surface.PlaySound(SND_ERROR)
			f:Toast("Type a name for the loot table first", true)
			presetName:RequestFocus()
			return
		end
		local send = function()
			SendAction("preset_save", function() net.WriteString(name) end)
		end
		if PresetExists(name) then
			Derma_Query("A saved table called '" .. name .. "' already exists.\nOverwrite it with the current loot table?",
				"Overwrite saved table", "Overwrite", send, "Cancel", function() end)
		else
			send()
		end
	end

	local saveBtn = ChudButton(saveRow, "SAVE CURRENT", DoSavePreset, {filled = true})
	saveBtn:Dock(RIGHT)
	saveBtn:DockMargin(U(6), 0, 0, 0)
	saveBtn:SizeToLabel()
	presetName.OnEnter = function() DoSavePreset() end

	local savedHint = vgui.Create("DLabel", savedView)
	savedHint:Dock(TOP)
	savedHint:DockMargin(0, U(8), 0, U(8))
	savedHint:SetFont("ChudLoot_Small")
	savedHint:SetTextColor(C.dim)
	savedHint:SetText("SAVES THE TABLE ON THE RIGHT  ·  LOADING REPLACES IT  ·  CLICK A NAME TO REUSE IT")
	savedHint:SizeToContents()

	local savedList = vgui.Create("DScrollPanel", savedView)
	savedList:Dock(FILL)
	StyleScroll(savedList)

	local lastPresetSignature

	local function RebuildSaved()
		savedList:Clear()
		local presets = LootState.presets or {}

		if #presets == 0 then
			local empty = savedList:Add("DPanel")
			empty:Dock(TOP)
			empty:SetTall(U(80))
			empty.Paint = function(self, w, h)
				draw.SimpleText("NO SAVED TABLES YET", "ChudLoot_Body", w / 2, h * 0.4, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("Build a loot table, name it above and hit SAVE CURRENT.", "ChudLoot_Small", w / 2, h * 0.7, C.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			return
		end

		for _, preset in ipairs(presets) do
			local row = savedList:Add("DButton")
			row:SetText("")
			row:Dock(TOP)
			row:SetTall(U(48))
			row:DockMargin(0, 0, U(4), U(3))

			local del = ChudButton(row, "X", function()
				Derma_Query("Delete the saved table '" .. preset.name .. "'?", "Delete saved table",
					"Delete", function()
						SendAction("preset_delete", function() net.WriteString(preset.name) end)
					end, "Cancel", function() end)
			end, {danger = true})

			local load = ChudButton(row, "LOAD", function()
				local send = function()
					SendAction("preset_load", function() net.WriteString(preset.name) end)
				end
				if #LootState.items > 0 then
					Derma_Query("Replace the current loot table (" .. #LootState.items .. " items) with '" .. preset.name .. "'?",
						"Load saved table", "Load it", send, "Cancel", function() end)
				else
					send()
				end
			end)
			load:SizeToLabel(U(16))

			row.PerformLayout = function(self, w, h)
				local bh = U(28)
				del:SetSize(U(30), bh)
				del:SetPos(w - U(30) - U(8), h / 2 - bh / 2)
				load:SetTall(bh)
				load:SetPos(w - U(30) - U(14) - load:GetWide(), h / 2 - bh / 2)
			end

			row.Paint = function(self, w, h)
				local selected = string.Trim(presetName:GetValue() or "") == preset.name
				surface.SetDrawColor((self:IsHovered() or self:IsChildHovered()) and C.rowHover or C.row)
				surface.DrawRect(0, 0, w, h)
				if selected then
					surface.SetDrawColor(C.red)
					surface.DrawRect(0, 0, U(3), h)
				end
				local tx = U(12)
				local maxW = w - tx - U(30) - U(22) - load:GetWide()
				draw.SimpleText(Fit(preset.name, "ChudLoot_Body", maxW), "ChudLoot_Body", tx, h * 0.36, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				local when = (preset.saved or 0) > 0 and os.date("%b %d %Y, %H:%M", preset.saved) or "unknown date"
				draw.SimpleText(Fit(preset.count .. " ITEMS  ·  SAVED " .. string.upper(when), "ChudLoot_Small", maxW), "ChudLoot_Small", tx, h * 0.72, C.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			row.DoClick = function()
				surface.PlaySound(SND_SELECT)
				presetName:SetText(preset.name)
			end
		end
	end

	local function PresetSignature()
		local parts = {}
		for i, p in ipairs(LootState.presets or {}) do parts[i] = p.name .. ":" .. tostring(p.saved) end
		return table.concat(parts, "|")
	end

	-------------------------------------------------------------------
	-- State updates
	-------------------------------------------------------------------
	local function Signature()
		local classes = {}
		for i, item in ipairs(LootState.items) do classes[i] = item[2] end
		return table.concat(classes, "|")
	end

	function f:OnStateUpdated(previousClasses)
		local sig = Signature()
		if sig ~= lastSignature then
			lastSignature = sig
			RebuildTable()

			-- flash anything that was just added
			if previousClasses then
				for _, item in ipairs(LootState.items) do
					if not previousClasses[item[2]] and IsValid(rows[item[2]]) then
						f.FlashRow(item[2])
					end
				end
			end
		else
			for class, row in pairs(rows) do
				local item = ItemByClass[class]
				if IsValid(row) and item and IsValid(row.Stepper) then
					row.Stepper:SetValue(item[1])
				end
			end
		end

		interval:SetValue(LootState.interval)
		perWave:SetValue(LootState.perWave)

		local presetSig = PresetSignature()
		if presetSig ~= lastPresetSignature then
			lastPresetSignature = presetSig
			RebuildSaved()
		end
	end

	ShowLeftTab(MenuPrefs.leftTab)
	RebuildBrowser()
	f:OnStateUpdated()
	timer.Simple(0, function() if IsValid(search) then search:RequestFocus() end end)

	return f
end

---------------------------------------------------------------------------
-- Net
---------------------------------------------------------------------------

net.Receive("event_loot_sync", function()
	local previous = {}
	for class in pairs(ItemByClass) do previous[class] = true end

	local state = net.ReadTable()
	LootState.items = state.items or {}
	LootState.defaults = state.defaults or {}
	LootState.enabled = state.enabled and true or false
	LootState.interval = state.interval or 8
	LootState.perWave = state.perWave or 1
	LootState.nextWave = state.nextWave or 0
	LootState.active = state.active and true or false
	LootState.maxItems = state.maxItems or 128
	LootState.presets = state.presets or {}
	RecalcTotals()

	if IsValid(LootPollingMenu) and LootPollingMenu.OnStateUpdated then
		LootPollingMenu:OnStateUpdated(previous)
	end
end)

net.Receive("event_loot_wave", function()
	LootState.nextWave = net.ReadFloat()
	LootState.active = true
end)

net.Receive("event_loot_notify", function()
	local msg = net.ReadString()
	local isError = net.ReadBool()

	if IsValid(LootPollingMenu) and LootPollingMenu.Toast then
		LootPollingMenu:Toast(msg, isError)
		if isError then surface.PlaySound(SND_ERROR) end
	else
		notification.AddLegacy(msg, isError and NOTIFY_ERROR or NOTIFY_GENERIC, 4)
	end
end)

net.Receive("event_loot_open", function()
	OpenLootMenu()
end)

concommand.Add("zb_event_loot_menu", function()
	if IsValid(LootPollingMenu) then
		LootPollingMenu:Remove()
		return
	end
	RunConsoleCommand("zb_event_lootpoll")
end)

-- rebuild the item catalog if weapons/entities get reloaded
hook.Add("OnReloaded", "ChudLoot_Catalog", function()
	Catalog, CatalogByClass = nil, nil
	IconCache = {}
end)
