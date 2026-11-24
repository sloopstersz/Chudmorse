local UI = ZACUI
local frame
local state = { mask = 0, search = "" }
for i in ipairs(ZAC.Kinds) do state.mask = bit.bor(state.mask, bit.lshift(1, i - 1)) end

local ROLES = { damage = true, death = true, aim = true }

local function readPerson()
	local name, sid = net.ReadString(), net.ReadString()
	if sid == "" and name == "" then return nil end
	return { name = name, sid = sid }
end

local function readEntry()
	return {
		id = net.ReadUInt(32), t = net.ReadUInt(32), k = ZAC.Kinds[net.ReadUInt(4)] or "admin",
		m = net.ReadString(), x = net.ReadString(), a = readPerson(), v = readPerson(),
	}
end

local function cmd(act, arg, arg2)
	net.Start("zac_admin_cmd")
	net.WriteString(act)
	net.WriteString(arg or "")
	net.WriteString(arg2 or "")
	net.SendToServer()
end

local function requestLogs()
	net.Start("zac_logs_req")
	net.WriteUInt(state.mask, 8)
	net.WriteString(state.search)
	net.WriteBool(true)
	net.SendToServer()
end

local function requestGrabs()
	net.Start("zac_sg_list_req")
	net.SendToServer()
end

local function requestBans()
	net.Start("zac_bans_req")
	net.SendToServer()
end

local function find(hay, q) return hay and string.find(string.lower(hay), q, 1, true) end
local function matches(e)
	local ki = ZAC.KindIndex[e.k] or 1
	if bit.band(state.mask, bit.lshift(1, ki - 1)) == 0 then return false end
	local q = state.search
	if q == "" then return true end
	return find(e.m, q) or find(e.x, q) or (e.a and find(e.a.sid, q)) or (e.v and find(e.v.sid, q))
end

local function playerBySid(sid)
	for _, p in player.Iterator() do if p:SteamID() == sid then return p end end
end

local function askScreengrab(name, sid)
	UI.Confirm("Screengrab", "Do you want to screengrab " .. name .. " (" .. sid .. ")?\nThe picture pops up when it arrives and is saved.", "YES",
		function() cmd("screengrab", sid) end)
end

local function showLogsOf(sid)
	if not IsValid(frame) then return end
	state.search = string.lower(sid)
	if IsValid(frame.searchBox) then frame.searchBox:SetValue(sid) end
	frame.selectTab("logs")
	requestLogs()
end

local function showDetails(e)
	local f = UI.Frame(os.date("%Y-%m-%d %H:%M:%S", e.t) .. "  -  " .. (ZAC.KindLabel[e.k] or e.k), 820, 500)
	local bar = vgui.Create("DPanel", f)
	bar:Dock(BOTTOM)
	bar:SetTall(30)
	bar:DockMargin(0, 6, 0, 0)
	bar.Paint = nil
	local txt = vgui.Create("DTextEntry", f)
	txt:Dock(FILL)
	txt:SetMultiline(true)
	txt:SetFont("DebugFixed")
	txt:SetValue(e.m .. (e.x ~= "" and ("\n\n" .. e.x) or ""))
	txt.Paint = function(self, w, h)
		UI.Box(w, h, Color(0, 0, 0, 255))
		self:DrawTextEntryText(UI.WHITE, Color(110, 110, 110), UI.WHITE)
	end
	local copy = UI.Button(bar, "COPY ALL", function(self) SetClipboardText(txt:GetValue()) self.label = "COPIED" end)
	copy:Dock(LEFT)
	local function personButton(p, label)
		if not p or p.sid == "" then return end
		local b = UI.Button(bar, label .. ": " .. p.sid, function(self) SetClipboardText(p.sid) self.label = "COPIED " .. p.sid end)
		b:Dock(LEFT)
		b:DockMargin(8, 0, 0, 0)
	end
	personButton(e.a, ROLES[e.k] and "COPY OFFENDER" or "COPY PLAYER")
	personButton(e.v, "COPY VICTIM")
end

local function buildLogs(panel)
	local top = vgui.Create("DPanel", panel)
	top:Dock(TOP)
	top:SetTall(28)
	top:DockMargin(0, 0, 0, 6)
	top.Paint = nil

	for i, k in ipairs(ZAC.Kinds) do
		local bitv = bit.lshift(1, i - 1)
		local t = UI.Toggle(top, ZAC.KindLabel[k], bit.band(state.mask, bitv) ~= 0, function(on)
			state.mask = on and bit.bor(state.mask, bitv) or bit.band(state.mask, bit.bnot(bitv))
			requestLogs()
		end)
		t:Dock(LEFT)
		t:DockMargin(0, 0, 6, 0)
	end

	local refresh = UI.Button(top, "REFRESH", requestLogs)
	refresh:Dock(RIGHT)
	local search = UI.Entry(top, "Search name / SteamID / text...")
	search:Dock(RIGHT)
	search:SetWide(240)
	search:DockMargin(0, 0, 6, 0)
	search:SetValue(state.search)
	search:SetUpdateOnType(true)
	search.OnValueChange = function(_, v)
		state.search = string.lower(string.Trim(v or ""))
		timer.Create("zac_search", 0.4, 1, requestLogs)
	end
	frame.searchBox = search

	local list = UI.List(panel)
	list:Dock(FILL)
	list:AddColumn("Time"):SetFixedWidth(110)
	list:AddColumn("Type"):SetFixedWidth(90)
	list:AddColumn("Offender / player"):SetFixedWidth(170)
	list:AddColumn("Victim"):SetFixedWidth(170)
	list:AddColumn("Event")
	frame.list = list

	function list:AddEntry(e)
		local line = UI.AddLine(self, os.date("%m-%d %H:%M:%S", e.t), ZAC.KindLabel[e.k] or e.k,
			e.a and e.a.name or "", e.v and e.v.name or "", e.m)
		line.entry = e
		line:SetSortValue(1, e.id)
		if e.k == "death" or e.k == "aim" or e.k == "chat" then line.textCol = Color(255, 255, 255) else line.textCol = Color(200, 200, 200) end
		return line
	end

	list.DoDoubleClick = function(_, _, line) if line.entry then showDetails(line.entry) end end
	list.OnRowRightClick = function(_, _, line)
		local e = line.entry
		if not e then return end
		local m = UI.Menu()
		local role = ROLES[e.k] and "offender's" or "player's"
		if e.a and e.a.sid ~= "" then
			m:AddOption("Copy " .. role .. " SteamID  (" .. e.a.name .. ")", function() SetClipboardText(e.a.sid) end)
		end
		if e.v and e.v.sid ~= "" then
			m:AddOption("Copy victim's SteamID  (" .. e.v.name .. ")", function() SetClipboardText(e.v.sid) end)
		end
		m:AddSpacer()
		if (e.k == "damage" or e.k == "death") and e.a and e.a.sid ~= "" and e.v and e.v.sid ~= "" and e.a.sid ~= e.v.sid and ZAC.RequestView then
			m:AddOption(e.k == "death" and "View the killing shot" or "View", function() ZAC.RequestView(e.id, frame) end)
		end
		m:AddOption("Details", function() showDetails(e) end)
		m:AddOption("Copy line", function() SetClipboardText(os.date("[%Y-%m-%d %H:%M:%S] ", e.t) .. e.m) end)
		if e.x ~= "" then
			m:AddOption(e.k == "death" and "Copy death report" or "Copy details", function() SetClipboardText(e.m .. "\n" .. e.x) end)
		end
		m:AddSpacer()
		if e.a and e.a.sid ~= "" then
			m:AddOption("Show " .. role .. " logs  (" .. e.a.name .. ")", function() showLogsOf(e.a.sid) end)
			if playerBySid(e.a.sid) then
				m:AddOption("Screengrab " .. e.a.name, function() askScreengrab(e.a.name, e.a.sid) end)
			end
		end
		if e.v and e.v.sid ~= "" then
			m:AddOption("Show victim's logs  (" .. e.v.name .. ")", function() showLogsOf(e.v.sid) end)
		end
		if e.a and e.a.sid ~= "" then
			m:AddSpacer()
			m:AddOption("Ban " .. e.a.name .. "...", function()
				local default = e.k == "chat" and ("Chat: " .. string.sub(e.m, 1, 80)) or "Cheating"
				UI.Ask("Ban " .. e.a.name, "Reason (\"please appeal in the discord\" is added):", default, function(reason)
					cmd("ban", e.a.sid, reason)
				end)
			end)
		end
		m:Open()
	end
end

local ratings = {}
local RATE_NAME = { "LEGIT", "SUSPECT", "CHEATING" }
local RATE_COL = { Color(120, 220, 120), Color(240, 190, 70), Color(255, 90, 80) }

local function fillSimple(list)
	list:Clear()
	for _, p in player.Iterator() do
		local l = UI.AddLine(list, p:Nick(), p:SteamID())
		l.ply = p
	end
end

local function requestRatings()
	net.Start("zac_ratings_req")
	net.SendToServer()
end

local function fillPlayers(list)
	list:Clear()
	local rows = {}
	for _, p in player.Iterator() do rows[#rows + 1] = p end
	table.sort(rows, function(a, b)
		local ra, rb = ratings[a:SteamID()], ratings[b:SteamID()]
		local sa, sb = ra and ra.score or 0, rb and rb.score or 0
		if sa ~= sb then return sa > sb end
		return a:Nick() < b:Nick()
	end)
	for _, p in ipairs(rows) do
		local r = ratings[p:SteamID()] or { level = 1, score = 0, reasons = {} }
		local l = UI.AddLine(list, RATE_NAME[r.level] or "LEGIT", r.score, p:Nick(), p:SteamID(), p:Ping())
		l.ply = p
		l.textCol = RATE_COL[r.level]
		l:SetSortValue(2, r.score)
		if #r.reasons > 0 then l:SetTooltip(table.concat(r.reasons, "\n")) end
	end
end

net.Receive("zac_ratings", function()
	ratings = {}
	for _ = 1, net.ReadUInt(8) do
		local r = { sid = net.ReadString(), level = net.ReadUInt(2), score = net.ReadUInt(16), reasons = {} }
		for i = 1, net.ReadUInt(4) do r.reasons[i] = net.ReadString() end
		ratings[r.sid] = r
	end
	if IsValid(frame) and frame.fillPlayers then frame.fillPlayers() end
end)

local function buildPlayers(panel)
	local bar = vgui.Create("DPanel", panel)
	bar:Dock(BOTTOM)
	bar:SetTall(30)
	bar:DockMargin(0, 6, 0, 0)
	bar.Paint = function(_, w, h) draw.SimpleText("Hover a player for why they're rated that way   |   Right-click: spectate, screengrab, integrity check, watch net, steam check, alts, kick, ban", "ZACUI", 0, h / 2, UI.DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
	local list = UI.List(panel)
	list:Dock(FILL)
	list:AddColumn("Status"):SetFixedWidth(110)
	list:AddColumn("Score"):SetFixedWidth(60)
	list:AddColumn("Name")
	list:AddColumn("SteamID"):SetFixedWidth(190)
	list:AddColumn("Ping"):SetFixedWidth(60)
	local rb = UI.Button(bar, "REFRESH", function() fillPlayers(list) requestRatings() end)
	rb:Dock(RIGHT)
	fillPlayers(list)
	requestRatings()
	timer.Create("zac_ratings_poll", 5, 0, function()
		if not IsValid(list) then timer.Remove("zac_ratings_poll") return end
		if list:IsVisible() then requestRatings() end
	end)

	list.OnRowRightClick = function(_, _, line)
		local p = line.ply
		if not IsValid(p) then return end
		local sid, name = p:SteamID(), p:Nick()
		local m = UI.Menu()
		m:AddOption("Spectate (live)", function()
			cmd("spectate", sid)
			if IsValid(frame) then frame:Close() end
		end)
		m:AddOption("Screengrab", function() askScreengrab(name, sid) end)
		m:AddOption("Show their logs", function() showLogsOf(sid) end)
		-- the newer checks (results print in your console ~ and go to Discord)
		m:AddSpacer()
		local function told(t) chat.AddText(Color(120, 200, 255), "[AC] ", color_white, t .. "  - results in your console (~)") end
		m:AddOption("Integrity check (injected Lua / cheat signs)", function() cmd("integrity", sid) told("Checking " .. name .. "'s PC...") end)
		m:AddOption("Watch net messages - 2 minutes", function() cmd("netwatch", sid, "120") told("Watching what " .. name .. " sends for 2 min") end)
		m:AddOption("Watch net messages - 10 minutes", function() cmd("netwatch", sid, "600") told("Watching what " .. name .. " sends for 10 min") end)
		m:AddOption("Stop watching net messages", function() cmd("netwatch", sid, "0") end)
		m:AddOption("Steam check (VAC / level / account age)", function() cmd("steamcheck", sid) told("Steam check on " .. name) end)
		m:AddOption("Other accounts on their PC (alts)", function() cmd("alts", sid) told("Alts of " .. name) end)
		m:AddSpacer()
		local r = ratings[sid]
		if r and #r.reasons > 0 then
			m:AddOption("Why " .. (RATE_NAME[r.level] or "LEGIT") .. "?  (score " .. r.score .. ")", function()
				chat.AddText(RATE_COL[r.level], "[AC] " .. name .. ": " .. (RATE_NAME[r.level] or "LEGIT") .. ", score " .. r.score)
				for _, line in ipairs(r.reasons) do chat.AddText(color_white, "   " .. line) end
			end)
		end
		m:AddOption("Clear cheat rating", function() cmd("rating_clear", sid) timer.Simple(0.5, requestRatings) end)
		m:AddOption("Copy SteamID  (" .. sid .. ")", function() SetClipboardText(sid) end)
		m:AddOption("Copy SteamID64", function() SetClipboardText(IsValid(p) and p:SteamID64() or "") end)
		m:AddSpacer()
		m:AddOption("Kick...", function()
			UI.Ask("Kick " .. name, "Reason:", "Kicked by an admin", function(reason) cmd("kick", sid, reason) end)
		end)
		m:AddOption("Ban...", function()
			UI.Ask("Ban " .. name, "Reason (\"please appeal in the discord\" is added):", "Cheating", function(reason)
				cmd("ban", sid, reason)
			end)
		end)
		m:Open()
	end
	-- one button: integrity-check everyone online (one every 0.4 s - the server takes a command at most every 0.3 s)
	local ib = UI.Button(bar, "CHECK EVERYONE", function()
		local list2 = {}
		for _, pl in ipairs(player.GetHumans()) do if pl ~= LocalPlayer() then list2[#list2 + 1] = pl:SteamID() end end
		for i, s2 in ipairs(list2) do timer.Simple(i * 0.4, function() cmd("integrity", s2) end) end
		chat.AddText(Color(120, 200, 255), "[AC] ", color_white, "Integrity check on " .. #list2 .. " player(s) - results in your console (~) and Discord")
	end)
	ib:SetWide(150)
	ib:Dock(RIGHT)
	ib:DockMargin(0, 0, 6, 0)
	frame.fillPlayers = function() fillPlayers(list) end
end

local function buildScreengrabs(panel)
	local left = vgui.Create("DPanel", panel)
	left:Dock(LEFT)
	left:SetWide(380)
	left:DockMargin(0, 0, 8, 0)
	left.Paint = nil
	local lh = vgui.Create("DPanel", left)
	lh:Dock(TOP)
	lh:SetTall(26)
	lh.Paint = function(_, w, h) draw.SimpleText("PLAYERS ONLINE  -  click one to screengrab", "ZACUI_B", 0, h / 2, UI.WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
	local plist = UI.List(left)
	plist:Dock(FILL)
	plist:AddColumn("Name")
	plist:AddColumn("SteamID"):SetFixedWidth(170)
	local prb = UI.Button(left, "REFRESH PLAYERS", function() fillSimple(plist) end)
	prb:Dock(BOTTOM)
	prb:SetTall(28)
	prb:DockMargin(0, 6, 0, 0)
	fillSimple(plist)
	plist.OnRowSelected = function(_, _, line)
		local p = line.ply
		plist:ClearSelection()
		if IsValid(p) then askScreengrab(p:Nick(), p:SteamID()) end
	end

	local right = vgui.Create("DPanel", panel)
	right:Dock(FILL)
	right.Paint = nil
	local rh = vgui.Create("DPanel", right)
	rh:Dock(TOP)
	rh:SetTall(26)
	rh.Paint = function(_, w, h) draw.SimpleText("SAVED SCREENGRABS  -  click one to look at it", "ZACUI_B", 0, h / 2, UI.WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
	local glist = UI.List(right)
	glist:Dock(FILL)
	glist:AddColumn("Taken"):SetFixedWidth(140)
	glist:AddColumn("Player")
	glist:AddColumn("SteamID"):SetFixedWidth(170)
	glist:AddColumn("By"):SetFixedWidth(130)
	glist:AddColumn("KB"):SetFixedWidth(50)
	local grb = UI.Button(right, "REFRESH LIST", requestGrabs)
	grb:Dock(BOTTOM)
	grb:SetTall(28)
	grb:DockMargin(0, 6, 0, 0)
	glist.OnRowSelected = function(_, _, line)
		glist:ClearSelection()
		if not line.file then return end
		net.Start("zac_sg_open")
		net.WriteString(line.file)
		net.SendToServer()
		chat.AddText(color_white, "[AC] Opening the screengrab of " .. (line.name or "?") .. "...")
	end
	glist.OnRowRightClick = function(_, _, line)
		local m = UI.Menu()
		m:AddOption("Copy SteamID  (" .. line.sid .. ")", function() SetClipboardText(line.sid) end)
		m:AddOption("Show their logs", function() showLogsOf(line.sid) end)
		m:Open()
	end
	frame.grabList = glist
	requestGrabs()
end

local function buildBans(panel)
	local list = UI.List(panel)
	list:Dock(FILL)
	list:AddColumn("SteamID"):SetFixedWidth(180)
	list:AddColumn("Name"):SetFixedWidth(150)
	list:AddColumn("Date"):SetFixedWidth(130)
	list:AddColumn("By"):SetFixedWidth(170)
	list:AddColumn("Reason")
	frame.bans = list
	list.OnRowRightClick = function(_, _, line)
		local m = UI.Menu()
		m:AddOption("Unban " .. line.sid, function()
			UI.Confirm("Unban", "Unban " .. line.sid .. "?", "UNBAN", function()
				cmd("unban", line.sid)
				timer.Simple(0.5, requestBans)
			end)
		end)
		m:AddOption("Copy SteamID  (" .. line.sid .. ")", function() SetClipboardText(line.sid) end)
		m:Open()
	end
	local rb = UI.Button(panel, "REFRESH", requestBans)
	rb:Dock(BOTTOM)
	rb:SetTall(28)
	rb:DockMargin(0, 6, 0, 0)
	requestBans()
end

local function open(tab)
	if IsValid(frame) then
		frame.selectTab(tab)
		frame:MakePopup()
		return
	end
	frame = UI.Frame("ZCity Anti-Cheat", math.min(ScrW() - 40, 1400), math.min(ScrH() - 40, 820))
	frame.OnRemove = function()
		net.Start("zac_menu_closed")
		net.SendToServer()
	end

	local panels = {}
	for _, id in ipairs({ "logs", "players", "screengrabs", "bans" }) do
		panels[id] = vgui.Create("DPanel", frame)
		panels[id].Paint = nil
	end
	frame.selectTab = UI.Tabs(frame, {
		{ id = "logs", label = "LOGS", panel = panels.logs },
		{ id = "players", label = "PLAYERS", panel = panels.players },
		{ id = "screengrabs", label = "SCREENGRABS", panel = panels.screengrabs },
		{ id = "bans", label = "BANS", panel = panels.bans },
	})
	buildLogs(panels.logs)
	buildPlayers(panels.players)
	buildScreengrabs(panels.screengrabs)
	buildBans(panels.bans)
	frame.selectTab(tab)
	requestLogs()
end

net.Receive("zac_open", function()
	local tab = net.ReadString()
	open((tab == "screengrabs" or tab == "players" or tab == "bans") and tab or "logs")
end)

net.Receive("zac_logs", function()
	local n = net.ReadUInt(12)
	local entries = {}
	for i = 1, n do entries[i] = readEntry() end
	if not IsValid(frame) or not IsValid(frame.list) then return end
	frame.list:Clear()
	for _, e in ipairs(entries) do frame.list:AddEntry(e) end
	frame.list:SortByColumn(1, true)
end)

net.Receive("zac_log_live", function()
	local e = readEntry()
	if not IsValid(frame) or not IsValid(frame.list) or not matches(e) then return end
	frame.list:AddEntry(e)
	frame.list:SortByColumn(1, true)
	-- keep the live list at 1500 lines: drop the oldest. GetLines() has gaps once lines were removed
	-- (lines[1] can be nil), so find the lowest ID instead of taking [1]
	local lines = frame.list:GetLines()
	local n, oldest = 0, nil
	for _, ln in pairs(lines) do
		n = n + 1
		if IsValid(ln) and (not oldest or ln:GetID() < oldest:GetID()) then oldest = ln end
	end
	if n > 1500 and IsValid(oldest) then frame.list:RemoveLine(oldest:GetID()) end
end)

net.Receive("zac_sg_list", function()
	local rows = {}
	for i = 1, net.ReadUInt(9) do
		rows[i] = { file = net.ReadString(), name = net.ReadString(), sid = net.ReadString(), t = net.ReadUInt(32), by = net.ReadString(), kb = net.ReadUInt(16) }
	end
	if not IsValid(frame) or not IsValid(frame.grabList) then return end
	frame.grabList:Clear()
	for _, r in ipairs(rows) do
		local l = UI.AddLine(frame.grabList, os.date("%Y-%m-%d %H:%M:%S", r.t), r.name, r.sid, r.by, r.kb)
		l.file, l.name, l.sid = r.file, r.name, r.sid
		l:SetSortValue(1, r.t)
	end
end)

net.Receive("zac_bans", function()
	local rows = {}
	for i = 1, net.ReadUInt(10) do
		rows[i] = { sid64 = net.ReadString(), name = net.ReadString(), reason = net.ReadString(), t = net.ReadUInt(32), by = net.ReadString() }
	end
	if not IsValid(frame) or not IsValid(frame.bans) then return end
	frame.bans:Clear()
	for _, r in ipairs(rows) do
		local sid = string.StartWith(r.sid64, "STEAM_") and r.sid64 or util.SteamIDFrom64(r.sid64)
		local l = UI.AddLine(frame.bans, sid, r.name, os.date("%Y-%m-%d %H:%M", r.t), r.by, r.reason)
		l.sid, l.sid64 = sid, r.sid64
	end
end)
