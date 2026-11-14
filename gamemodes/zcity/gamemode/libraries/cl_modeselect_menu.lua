if CLIENT then
    local isMenuOpen = nil
    zb.availableModes = zb.availableModes or {}

    zb.RoundList = zb.RoundList or {}
    zb.nextround = zb.nextround or nil
    zb.forcemode = zb.forcemode or "random"
    local queueManagerInstance = nil

    --;; Chudmorse F6 menu: Z-City's queue/round select, styled after the remorseism / Chudmorse ESC menu

    ------------------------------------------------------------------
    -- Palette (same values as the ESC menu)
    ------------------------------------------------------------------
    local COL_BG        = Color(10, 10, 19, 235)     -- clr_verygray
    local COL_GRAD_R    = Color(18, 18, 18, 65)
    local COL_GRAD_D    = Color(100, 100, 100, 35)
    local COL_LINE      = Color(255, 255, 255, 25)   -- clr_gray
    local COL_LINE_HI   = Color(255, 255, 255, 70)
    local COL_ROW       = Color(0, 0, 0, 120)
    local COL_ROW_HOV   = Color(255, 255, 255, 10)
    local COL_RED       = Color(192, 0, 0, 255)      -- red_select
    local COL_RED_TITLE = Color(199, 2, 2, 255)
    local COL_RED_DIM   = Color(192, 0, 0, 90)
    local COL_TEXT      = Color(225, 225, 225, 255)
    local COL_TEXT_DIM  = Color(105, 105, 105, 255)
    local COL_OUTLINE   = Color(0, 0, 0, 235)

    local gradient_l = surface.GetTextureID("vgui/gradient-l")
    local gradient_r = surface.GetTextureID("vgui/gradient-r")
    local gradient_d = surface.GetTextureID("vgui/gradient-d")

    local function MenuUnit(num)
        return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
    end

    local MENU_FONT = "Verily Serif Mono"
    local function CreateF6Fonts()
        surface.CreateFont("ZB_QM_Title",    {font = MENU_FONT, size = math.max(22, MenuUnit(34)), weight = 800, antialias = true})
        surface.CreateFont("ZB_QM_Big",      {font = MENU_FONT, size = math.max(20, MenuUnit(30)), weight = 200, antialias = true})
        surface.CreateFont("ZB_QM_Category", {font = MENU_FONT, size = math.max(14, MenuUnit(16)), weight = 200, antialias = true})
        surface.CreateFont("ZB_QM_Item",     {font = MENU_FONT, size = math.max(15, MenuUnit(19)), weight = 200, antialias = true})
        surface.CreateFont("ZB_QM_Small",    {font = MENU_FONT, size = math.max(12, MenuUnit(14)), weight = 200, antialias = true})
        surface.CreateFont("ZB_QM_Btn",      {font = MENU_FONT, size = math.max(13, MenuUnit(16)), weight = 200, antialias = true})
    end
    CreateF6Fonts()
    hook.Add("OnScreenSizeChanged", "ZB_F6Menu_Fonts", CreateF6Fonts)

    -- ESC menu sounds; stock GMod fallbacks if the pack is missing them
    local function UISound(path, fallback)
        return file.Exists("sound/" .. path, "GAME") and path or fallback
    end
    local SND_CLICK   = UISound("ui/rem_select.wav", "ui/buttonclick.wav")
    local SND_RELEASE = UISound("ui/rem_select.wav", "ui/buttonclickrelease.wav")
    local SND_HOVER   = UISound("ui/rem_hover.wav", "ui/buttonrollover.wav")
    local SND_TYPE    = UISound("shitty/tap-resonant.wav", nil)

    local lastTypeSound = 0
    local function PlayTypeSound()
        if not SND_TYPE or RealTime() - lastTypeSound < 0.03 then return end
        lastTypeSound = RealTime()
        local ply = LocalPlayer()
        if IsValid(ply) then ply:EmitSound(SND_TYPE, 55, 102, 0.25) end
    end

    local function FT(speed) return math.Clamp(FrameTime() * speed * 60, 0, 1) end

    ------------------------------------------------------------------
    -- Net
    ------------------------------------------------------------------
    net.Receive("ZB_SendModesInfo", function()
        zb.availableModes = net.ReadTable()
        if IsValid(queueManagerInstance) then queueManagerInstance:RebuildModes() end
    end)

    net.Receive("ZB_SendRoundList", function()
        zb.RoundList = net.ReadTable()
        zb.nextround = net.ReadString()
        zb.forcemode = net.ReadString()
        if zb.forcemode == "" then zb.forcemode = "random" end
        table.insert(zb.RoundList, 1, zb.nextround)
        zb.nextround = nil
        if IsValid(queueManagerInstance) then queueManagerInstance:QueueUpdate() end
    end)

    net.Receive("ZB_NotifyRoundListChange", function()
        local playerName = net.ReadString()
        chat.AddText(COL_RED, "[F6] ", COL_TEXT, playerName, COL_TEXT_DIM, " has modified the game mode queue")
        net.Start("ZB_RequestRoundList")
        net.SendToServer()
    end)

    local function GetModeName(key)
        for _, mode in ipairs(zb.availableModes) do
            if mode.key == key then return mode.name end
        end
        return key
    end
    local function ForceActive()
        return zb.forcemode and zb.forcemode ~= "random" and zb.forcemode ~= ""
    end

    ------------------------------------------------------------------
    -- Drawing helpers
    ------------------------------------------------------------------
    local function DrawFrameBG(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_BG)
        if hg and hg.DrawBlur then hg.DrawBlur(self, 5) end
        surface.SetDrawColor(COL_GRAD_R)
        surface.SetTexture(gradient_r)
        surface.DrawTexturedRect(0, 0, w, h)
        surface.SetDrawColor(COL_BG)
        surface.SetTexture(gradient_l)
        surface.DrawTexturedRect(0, 0, w * 0.6, h)
        surface.SetDrawColor(COL_GRAD_D)
        surface.SetTexture(gradient_d)
        surface.DrawTexturedRect(0, 0, w, h)
        surface.SetDrawColor(COL_LINE)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function OutlinedText(text, font, x, y, col, ax, ay)
        draw.SimpleTextOutlined(text, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_CENTER, 1, COL_OUTLINE)
    end

    -- "Z-City" style title: first letter red, rest white, optional grey sub line
    local function DrawTitle(text, sub, x, y)
        local first, rest = text:sub(1, 1), text:sub(2)
        surface.SetFont("ZB_QM_Title")
        local fw, th = surface.GetTextSize(first)
        OutlinedText(first, "ZB_QM_Title", x, y, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        OutlinedText(rest, "ZB_QM_Title", x + fw, y, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if sub then
            draw.SimpleText(sub, "ZB_QM_Small", x + 2, y + th, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    -- Typewriter reveal: unrevealed characters show as '#', like the ESC menu buttons
    local function Typewrite(btn, text, speed)
        btn.TypeStart = btn.TypeStart or RealTime()
        local shown = math.min(#text, math.floor((RealTime() - btn.TypeStart) * (speed or 30)))
        if shown > (btn.TypeShown or 0) then
            btn.TypeShown = shown
            if btn.TypeSound then PlayTypeSound() end
        end
        if shown >= #text then return text end
        return text:sub(1, shown) .. string.rep("#", #text - shown)
    end

    -- Hover = flashing white/black text with inverse outline, growing underline, nudge right
    local function PaintRemText(btn, w, h, text, font, baseCol, align)
        local hovered = btn:IsHovered() and btn:IsEnabled()
        btn.HoverLerp = Lerp(FT(0.2), btn.HoverLerp or 0, hovered and 1 or 0)
        local col, outline = baseCol, COL_OUTLINE
        if hovered then
            local v = (0.5 + 0.5 * math.sin(CurTime() * 10)) * 255
            col = Color(v, v, v, 255)
            outline = Color(255 - v, 255 - v, 255 - v, 255)
        end
        surface.SetFont(font)
        local tw, th = surface.GetTextSize(text)
        local x
        if align == TEXT_ALIGN_CENTER then
            x = w / 2 - tw / 2
        else
            x = MenuUnit(6) + btn.HoverLerp * MenuUnit(6)
        end
        draw.SimpleTextOutlined(text, font, x, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, outline)
        if btn.HoverLerp > 0.01 then
            surface.SetDrawColor(btn.UnderlineCol or color_white)
            surface.DrawRect(x, h / 2 + th / 2, tw * btn.HoverLerp, math.max(1, MenuUnit(1)))
        end
    end

    -- Small framed button used inside the queue manager. style: nil | "red" | "white"
    local function RemButton(parent, text, style)
        local btn = vgui.Create("DButton", parent)
        btn:SetText("")
        btn.Label = text
        btn.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        local border = style == "red" and COL_RED_DIM or (style == "white" and COL_LINE_HI or COL_LINE)
        local textCol = style == "red" and COL_RED or COL_TEXT
        btn.UnderlineCol = style == "red" and COL_RED or color_white
        btn.Paint = function(self, w, h)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
            if self:IsHovered() then
                surface.SetDrawColor(COL_ROW_HOV)
                surface.DrawRect(0, 0, w, h)
            end
            surface.SetDrawColor(self:IsHovered() and (style == "red" and COL_RED or COL_LINE_HI) or border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            PaintRemText(self, w, h, Typewrite(self, self.Label, 40), "ZB_QM_Btn", textCol, TEXT_ALIGN_CENTER)
            return true
        end
        return btn
    end

    -- Thin toggle: outlined track, knob slides right and turns red when on
    local function CreateToggle(parent, getState, onClick)
        local toggle = vgui.Create("DButton", parent)
        toggle:SetText("")
        toggle:SetSize(MenuUnit(46), MenuUnit(22))
        local anim = getState() and 1 or 0
        toggle.Paint = function(self, w, h)
            anim = Lerp(FT(0.18), anim, getState() and 1 or 0)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(self:IsHovered() and COL_LINE_HI or COL_LINE)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local pad = math.max(3, MenuUnit(4))
            local ks = h - pad * 2
            local kx = Lerp(anim, pad, w - ks - pad)
            local g = Lerp(anim, 90, 0)
            surface.SetDrawColor(Lerp(anim, 90, COL_RED.r), g, g, 255)
            surface.DrawRect(kx, pad, ks, ks)
            return true
        end
        toggle.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        toggle.DoClick = function()
            surface.PlaySound(SND_CLICK)
            onClick()
        end
        return toggle
    end

    local function StyleScroll(scroll)
        local bar = scroll:GetVBar()
        bar:SetWide(math.max(4, MenuUnit(4)))
        bar:SetHideButtons(true)
        bar.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 90)
            surface.DrawRect(0, 0, w, h)
        end
        bar.btnGrip.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and COL_LINE_HI or COL_LINE)
            surface.DrawRect(0, 0, w, h)
        end
    end

    -- Section label: small grey caps text with a thin line under it (like the ESC ticker bar)
    local function CreateCategoryBar(parent, text)
        local bar = vgui.Create("DPanel", parent)
        bar:Dock(TOP)
        bar:SetTall(MenuUnit(28))
        bar:DockMargin(0, 0, 0, MenuUnit(8))
        bar.Paint = function(self, w, h)
            draw.SimpleText(string.upper(text), "ZB_QM_Category", 2, h / 2 - 1, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(COL_LINE)
            surface.DrawRect(0, h - 1, w, 1)
            surface.SetDrawColor(COL_RED)
            surface.DrawRect(0, h - 1, MenuUnit(24), 1)
        end
        return bar
    end

    local function AddCloseButton(parent, frame)
        local btn = vgui.Create("DButton", parent)
        btn:SetSize(MenuUnit(34), MenuUnit(34))
        btn:Dock(RIGHT)
        btn:DockMargin(0, MenuUnit(6), MenuUnit(4), MenuUnit(12))
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local col = self:IsHovered() and COL_RED or COL_TEXT
            local m = math.floor(w * 0.3)
            surface.SetDrawColor(COL_OUTLINE)
            for i = -2, 2 do
                surface.DrawLine(m, m + i, w - m, h - m + i)
                surface.DrawLine(w - m, m + i, m, h - m + i)
            end
            surface.SetDrawColor(col)
            for i = -1, 1 do
                surface.DrawLine(m, m + i, w - m, h - m + i)
                surface.DrawLine(w - m, m + i, m, h - m + i)
            end
            return true
        end
        btn.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        btn.DoClick = function()
            surface.PlaySound(SND_RELEASE)
            frame:Close()
        end
        return btn
    end

    -- Header: red-letter title + grey sub line + thin divider
    local function CreateHeader(parent, frame, title, subFunc)
        local header = vgui.Create("DPanel", parent)
        header:Dock(TOP)
        header:SetTall(MenuUnit(64))
        header:DockMargin(0, 0, 0, MenuUnit(10))
        header.Paint = function(self, w, h)
            DrawTitle(title, subFunc and subFunc() or nil, MenuUnit(14), MenuUnit(4))
            surface.SetDrawColor(COL_LINE)
            surface.DrawRect(MenuUnit(14), h - 1, w - MenuUnit(28), 1)
        end
        AddCloseButton(header, frame)
        return header
    end

    local function MapSub()
        local mapname = game.GetMap()
        local prefix = string.find(mapname, "_")
        if prefix then mapname = string.sub(mapname, prefix + 1) end
        return string.NiceName(mapname) .. " | " .. player.GetCount() .. " players"
    end

    local function MakeContent(frame, pad)
        pad = pad or MenuUnit(10)
        local content = vgui.Create("DPanel", frame)
        content.Paint = nil
        frame.PerformLayout = function(_, w, h)
            content:SetPos(pad, pad)
            content:SetSize(w - pad * 2, h - pad * 2)
        end
        return content
    end

    local function NewFrame(w, h)
        local frame = vgui.Create("ZFrame")
        frame:SetSize(w, h)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:SetBorder(false)
        frame:MakePopup()
        frame.Paint = DrawFrameBG
        return frame
    end

    ------------------------------------------------------------------
    -- Queue manager
    ------------------------------------------------------------------
    local function CreateAvailableRow(parent, mode, manager)
        local row = vgui.Create("DPanel", parent)
        row:SetTall(MenuUnit(46))
        row:Dock(TOP)
        row:DockMargin(0, 0, MenuUnit(6), MenuUnit(6))
        local blocked = (mode.canlaunch == 0)
        row:SetTooltip(blocked and "Cannot launch (no points / blocked)" or (mode.canlaunch == 1 and "Ready to launch" or mode.key))
        row.Paint = function(self, w, h)
            local forced = (zb.forcemode == mode.key)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
            if self:IsHovered() or self:IsChildHovered() then
                surface.SetDrawColor(COL_ROW_HOV)
                surface.DrawRect(0, 0, w, h)
            end
            surface.SetDrawColor(forced and COL_RED or COL_LINE)
            surface.DrawRect(0, 0, math.max(2, MenuUnit(3)), h)
            local ds = math.max(6, MenuUnit(7))
            surface.SetDrawColor(blocked and COL_RED or COL_TEXT)
            surface.DrawRect(MenuUnit(14), h / 2 - ds / 2, ds, ds)
            OutlinedText(mode.name, "ZB_QM_Item", MenuUnit(30), h / 2 - (blocked and MenuUnit(6) or 0), forced and COL_RED or COL_TEXT)
            if blocked then
                draw.SimpleText("blocked", "ZB_QM_Small", MenuUnit(31), h / 2 + MenuUnit(10), COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        local toggle = CreateToggle(row,
            function() return zb.forcemode == mode.key end,
            function()
                local target = (zb.forcemode == mode.key) and "random" or mode.key
                net.Start("AdminSetGameMode")
                    net.WriteString("setforcemode")
                    net.WriteString(target)
                    net.WriteBool(false)
                net.SendToServer()
                zb.forcemode = target
            end)
        toggle:Dock(RIGHT)
        local tm = math.floor((MenuUnit(46) - MenuUnit(22)) / 2)
        toggle:DockMargin(MenuUnit(8), tm, MenuUnit(12), tm)
        toggle:SetTooltip("Force this mode every round")
        local addBtn = RemButton(row, "+ Queue")
        addBtn:SetWide(MenuUnit(84))
        addBtn:Dock(RIGHT)
        addBtn:DockMargin(MenuUnit(6), MenuUnit(9), 0, MenuUnit(9))
        addBtn.DoClick = function()
            table.insert(zb.RoundList, mode.key)
            surface.PlaySound(SND_CLICK)
            manager:QueueUpdate()
        end
        return row
    end

    local function OpenQueueManager()
        if IsValid(queueManagerInstance) then queueManagerInstance:Close() end
        local ROW_H, ROW_GAP = MenuUnit(40), MenuUnit(6)
        local STRIDE = ROW_H + ROW_GAP
        local frame = NewFrame(math.Clamp(ScrW() * 0.62, 900, 1280), math.Clamp(ScrH() * 0.72, 560, 780))
        queueManagerInstance = frame
        local content = MakeContent(frame)
        CreateHeader(content, frame, "Game Mode Queue", function()
            return ForceActive() and ("Forced: " .. GetModeName(zb.forcemode)) or "Drag to reorder | top row plays next"
        end)
        local body = vgui.Create("DPanel", content)
        body:Dock(FILL)
        body:DockMargin(MenuUnit(14), 0, MenuUnit(14), MenuUnit(4))
        body.Paint = nil
        local leftPanel = vgui.Create("DPanel", body)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(frame:GetWide() * 0.55)
        leftPanel:DockMargin(0, 0, MenuUnit(10), 0)
        leftPanel.Paint = nil
        CreateCategoryBar(leftPanel, "Available Game Modes")
        local searchBar = vgui.Create("DTextEntry", leftPanel)
        searchBar:Dock(TOP)
        searchBar:DockMargin(0, 0, MenuUnit(6), MenuUnit(8))
        searchBar:SetTall(MenuUnit(32))
        searchBar:SetFont("ZB_QM_Item")
        searchBar.Paint = function(self, w, h)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(self:HasFocus() and COL_LINE_HI or COL_LINE)
            surface.DrawRect(0, h - 1, w, 1)
            self:DrawTextEntryText(COL_TEXT, COL_RED, COL_TEXT)
            if self:GetText() == "" then
                draw.SimpleText("Search game modes...", "ZB_QM_Item", MenuUnit(6), h / 2, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        local dscroll = vgui.Create("DScrollPanel", leftPanel)
        dscroll:Dock(FILL)
        StyleScroll(dscroll)
        local queuePanel = vgui.Create("DPanel", body)
        queuePanel:Dock(FILL)
        queuePanel:DockMargin(MenuUnit(10), 0, 0, 0)
        queuePanel.Paint = nil
        CreateCategoryBar(queuePanel, "Round Queue")
        local btnBar = vgui.Create("DPanel", queuePanel)
        btnBar:Dock(BOTTOM)
        btnBar:SetTall(MenuUnit(36))
        btnBar:DockMargin(0, MenuUnit(8), 0, 0)
        btnBar.Paint = nil
        local applyBtn = RemButton(btnBar, "Apply Queue", "white")
        applyBtn.DoClick = function()
            net.Start("ZB_UpdateRoundList")
                net.WriteTable(table.Copy(zb.RoundList))
                net.WriteBool(true)
            net.SendToServer()
            chat.AddText(COL_RED, "[F6] ", COL_TEXT, "Game mode queue has been set!")
            surface.PlaySound(SND_CLICK)
        end
        local clearBtn = RemButton(btnBar, "Clear Queue", "red")
        clearBtn.DoClick = function()
            zb.RoundList = {}
            frame:QueueUpdate()
            surface.PlaySound(SND_CLICK)
            chat.AddText(COL_RED, "[F6] ", COL_TEXT_DIM, "Queue cleared (press Apply to save)")
        end
        btnBar.PerformLayout = function(self, w, h)
            local gap = MenuUnit(8)
            local half = (w - gap) / 2
            applyBtn:SetPos(0, 0)
            applyBtn:SetSize(half, h)
            clearBtn:SetPos(half + gap, 0)
            clearBtn:SetSize(half, h)
        end
        local queueList = vgui.Create("DPanel", queuePanel)
        queueList:Dock(FILL)
        queueList.rows = {}
        queueList.scroll = 0
        queueList.scrollTarget = 0
        queueList.dragging = nil
        queueList.dragIndex = nil
        queueList.grabDY = 0
        queueList.Paint = function(self, w, h)
            if #self.rows == 0 then
                draw.SimpleText("Queue is empty, modes are picked randomly.", "ZB_QM_Item", 4, MenuUnit(10), COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
        queueList.PaintOver = function(self, w, h)
            local contentH = #self.rows * STRIDE
            if contentH > h + 2 then
                local barH = math.max(24, h * (h / contentH))
                local maxScroll = contentH - h
                local barY = maxScroll > 0 and (self.scroll / maxScroll) * (h - barH) or 0
                local bw = math.max(2, MenuUnit(3))
                surface.SetDrawColor(0, 0, 0, 90)
                surface.DrawRect(w - bw, 0, bw, h)
                surface.SetDrawColor(COL_LINE_HI)
                surface.DrawRect(w - bw, barY, bw, barH)
            end
        end
        queueList.OnMouseWheeled = function(self, delta)
            self.scrollTarget = self.scrollTarget - delta * STRIDE * 0.9
            return true
        end
        queueList.Think = function(self)
            local h = self:GetTall()
            local w = self:GetWide()
            local contentH = #self.rows * STRIDE
            local maxScroll = math.max(0, contentH - h)
            if self.dragging and IsValid(self.dragging) then
                local _, my = self:LocalCursorPos()
                local desiredY = math.Clamp(my - self.grabDY, -ROW_H * 0.5, h - ROW_H * 0.5)
                self.dragging.animY = desiredY
                self.dragging:SetPos(0, desiredY)
                self.dragging:MoveToFront()
                local minIndex = ForceActive() and 2 or 1
                local newIndex = math.Clamp(math.Round((desiredY + self.scroll) / STRIDE) + 1, minIndex, #self.rows)
                if newIndex ~= self.dragIndex then
                    local rowObj = table.remove(self.rows, self.dragIndex)
                    table.insert(self.rows, newIndex, rowObj)
                    local key = table.remove(zb.RoundList, self.dragIndex)
                    table.insert(zb.RoundList, newIndex, key)
                    self.dragIndex = newIndex
                    surface.PlaySound(SND_HOVER)
                end
                if my < 26 then self.scrollTarget = self.scrollTarget - 8 end
                if my > h - 26 then self.scrollTarget = self.scrollTarget + 8 end
            end
            self.scrollTarget = math.Clamp(self.scrollTarget, 0, maxScroll)
            self.scroll = Lerp(FrameTime() * 12, self.scroll, self.scrollTarget)
            if math.abs(self.scroll - self.scrollTarget) < 0.4 then self.scroll = self.scrollTarget end
            for i, row in ipairs(self.rows) do
                if not IsValid(row) then continue end
                row.queueIndex = i
                if row:GetWide() ~= w then row:SetSize(w, ROW_H) end

                local wantCursor = row:IsLocked() and "arrow" or "sizeall"
                if row.curCursor ~= wantCursor then
                    row:SetCursor(wantCursor)
                    row.curCursor = wantCursor
                end
                if row ~= self.dragging then
                    local targetY = (i - 1) * STRIDE - self.scroll
                    row.animY = Lerp(FrameTime() * 16, row.animY or targetY, targetY)
                    if math.abs(row.animY - targetY) < 0.4 then row.animY = targetY end
                    row:SetPos(0, row.animY)
                end
            end
        end

        local function MakeQueueRow(modeKey)
            local row = vgui.Create("DPanel", queueList)
            row:SetTall(ROW_H)
            row:SetCursor("sizeall")
            row.animY = 0
            row.Paint = function(self, w, h)
                local idx = self.queueIndex or 1
                local isNext = (idx == 1)
                local forced = isNext and ForceActive()
                local dragging = (queueList.dragging == self)
                surface.SetDrawColor(COL_ROW)
                surface.DrawRect(0, 0, w, h)
                if dragging or self:IsHovered() or self:IsChildHovered() then
                    surface.SetDrawColor(dragging and Color(255, 255, 255, 22) or COL_ROW_HOV)
                    surface.DrawRect(0, 0, w, h)
                end
                local barCol = forced and COL_RED or (isNext and COL_TEXT or COL_LINE)
                surface.SetDrawColor(barCol)
                surface.DrawRect(0, 0, math.max(2, MenuUnit(3)), h)
                local gx0 = MenuUnit(12)
                if forced then
                    -- padlock
                    surface.SetDrawColor(COL_RED)
                    surface.DrawRect(gx0, h / 2 - 1, 12, 9)
                    surface.DrawOutlinedRect(gx0 + 2, h / 2 - 7, 8, 8, 2)
                else
                    local g = dragging and 225 or 105
                    surface.SetDrawColor(g, g, g)
                    for gy = 0, 2 do
                        for gx = 0, 1 do
                            surface.DrawRect(gx0 + 1 + gx * 5, h / 2 - 7 + gy * 6, 3, 3)
                        end
                    end
                end
                local label = isNext and (forced and "FORCE" or "NEXT") or ("#" .. idx)
                local lcol = forced and COL_RED or (isNext and COL_TEXT or COL_TEXT_DIM)
                draw.SimpleText(label, "ZB_QM_Small", MenuUnit(32), h / 2, lcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                OutlinedText(GetModeName(modeKey), "ZB_QM_Item", MenuUnit(88), h / 2, forced and COL_RED or COL_TEXT)
                if dragging then
                    surface.SetDrawColor(COL_LINE_HI)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end
            end
            row.IsLocked = function(self)
                return ForceActive() and (self.queueIndex or 1) == 1
            end
            row.OnMousePressed = function(self, code)
                if code ~= MOUSE_LEFT then return end
                if self:IsLocked() then
                    surface.PlaySound(SND_RELEASE)
                    return
                end
                queueList.dragging = self
                queueList.dragIndex = self.queueIndex
                local _, my = queueList:LocalCursorPos()
                queueList.grabDY = my - self.animY
                self:MouseCapture(true)
                surface.PlaySound(SND_CLICK)
            end
            row.OnMouseReleased = function(self, code)
                if queueList.dragging == self then
                    queueList.dragging = nil
                    queueList.dragIndex = nil
                    self:MouseCapture(false)
                    surface.PlaySound(SND_RELEASE)
                end
            end
            local removeBtn = vgui.Create("DButton", row)
            removeBtn:SetWide(MenuUnit(30))
            removeBtn:Dock(RIGHT)
            removeBtn:DockMargin(4, MenuUnit(6), MenuUnit(8), MenuUnit(6))
            removeBtn:SetText("")
            removeBtn:SetCursor("hand")
            removeBtn:SetTooltip("Remove from queue")
            removeBtn.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
            removeBtn.Paint = function(self, w, h)
                OutlinedText("x", "ZB_QM_Item", w / 2, h / 2 - 1, self:IsHovered() and COL_RED or COL_TEXT_DIM, TEXT_ALIGN_CENTER)
                return true
            end
            removeBtn.Think = function(self)
                self:SetVisible(not row:IsLocked())
            end
            removeBtn.DoClick = function()
                if row:IsLocked() then return end
                surface.PlaySound(SND_RELEASE)
                table.remove(zb.RoundList, row.queueIndex or 1)
                frame:QueueUpdate()
            end
            return row
        end

        -- Modes regular admins can queue/force (superadmins see everything the server sends)
        local allowedModes = {
            ["tdm"] = true, ["cstrike"] = true, ["hmcd"] = true,
            ["hl2dm"] = true, ["riot"] = true, ["gwars"] = true,
            ["criresp"] = true, ["event"] = true, ["bartvshomer"] = true,
            ["chudbeasts"] = true, ["turfwars"] = true, ["chaos"] = true,
            ["hl2tdm"] = true, ["zzombies"] = true, ["president"] = true,
            ["vip"] = true, ["juggernaut"] = true, ["framed"] = true,
        }

        function frame:RebuildModes()
            dscroll:Clear()
            local filter = (IsValid(searchBar) and searchBar:GetValue() or ""):lower()
            for i, mode in SortedPairsByMemberValue(zb.availableModes, "canlaunch", true) do
                if not LocalPlayer():IsSuperAdmin() and not allowedModes[mode.key] then continue end
                if filter ~= "" and not string.find(mode.name:lower(), filter, 1, true) then continue end
                CreateAvailableRow(dscroll, mode, self)
            end
        end

        function frame:QueueUpdate()
            for _, r in ipairs(queueList.rows) do
                if IsValid(r) then r:Remove() end
            end
            queueList.rows = {}
            queueList.dragging = nil
            queueList.dragIndex = nil
            local w = queueList:GetWide()
            for idx, modeKey in ipairs(zb.RoundList) do
                local row = MakeQueueRow(modeKey)
                row.queueIndex = idx
                row.animY = (idx - 1) * STRIDE - queueList.scroll
                row:SetSize(w, ROW_H)
                row:SetPos(0, row.animY)
                queueList.rows[idx] = row
            end
            local maxScroll = math.max(0, #zb.RoundList * STRIDE - queueList:GetTall())
            queueList.scrollTarget = math.Clamp(queueList.scrollTarget, 0, maxScroll)
        end

        searchBar.OnChange = function()
            frame:RebuildModes()
        end

        frame:RebuildModes()
        frame:QueueUpdate()

        frame.OnClose = function()
            queueManagerInstance = nil
        end

        net.Start("ZB_RequestRoundList")
        net.SendToServer()
    end

    ------------------------------------------------------------------
    -- Player SQL Stats (superadmin), carried over from the old F6 menu
    ------------------------------------------------------------------
    local function StyleElement(element, bgColor)
        element.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
        element.Paint = function(self, w, h)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
            if self:IsHovered() then
                surface.SetDrawColor(COL_ROW_HOV)
                surface.DrawRect(0, 0, w, h)
            end
            surface.SetDrawColor(self:IsHovered() and COL_LINE_HI or COL_LINE)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if self.GetText and self:GetText() ~= "" and self.ClassName ~= "DPanel" then
                self.RemLabel = self.RemLabel or self:GetText()
                self:SetTextColor(Color(0, 0, 0, 0))
                PaintRemText(self, w, h, self.RemLabel, "ZB_QM_Btn", COL_TEXT, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function StylePanel(panel)
        panel.Paint = function(self, w, h)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
        end
    end

    local function StyleEntry(entry)
        entry:SetFont("ZB_QM_Item")
        entry.Paint = function(self, w, h)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(self:HasFocus() and COL_LINE_HI or COL_LINE)
            surface.DrawRect(0, h - 1, w, 1)
            self:DrawTextEntryText(COL_TEXT, COL_RED, COL_TEXT)
            if self:GetText() == "" and self.GetPlaceholderText and (self:GetPlaceholderText() or "") ~= "" then
                draw.SimpleText(self:GetPlaceholderText(), "ZB_QM_Item", 4, h / 2, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function StyleList(list)
        list:SetHeaderHeight(MenuUnit(26))
        list:SetDataHeight(MenuUnit(24))
        list.Paint = function(self, w, h)
            surface.SetDrawColor(COL_ROW)
            surface.DrawRect(0, 0, w, h)
        end
        for _, col in ipairs(list.Columns) do
            col.Header:SetFont("ZB_QM_Small")
            col.Header:SetTextColor(COL_TEXT_DIM)
            col.Header.Paint = function(self, w, h)
                surface.SetDrawColor(COL_LINE)
                surface.DrawRect(0, h - 1, w, 1)
            end
        end
        if list.VBar then
            list.VBar:SetHideButtons(true)
            list.VBar.Paint = function(self, w, h) surface.SetDrawColor(0, 0, 0, 90) surface.DrawRect(0, 0, w, h) end
            list.VBar.btnGrip.Paint = function(self, w, h) surface.SetDrawColor(self:IsHovered() and COL_LINE_HI or COL_LINE) surface.DrawRect(0, 0, w, h) end
        end
    end

    local function StyleListLine(line, active)
        for _, lbl in ipairs(line.Columns) do
            lbl:SetFont("ZB_QM_Small")
            lbl:SetTextColor(active and COL_TEXT or COL_TEXT_DIM)
        end
        line.Paint = function(self, w, h)
            if self:IsSelected() then
                surface.SetDrawColor(COL_RED_DIM)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(COL_RED)
                surface.DrawRect(0, 0, math.max(2, MenuUnit(3)), h)
            elseif self:IsHovered() then
                surface.SetDrawColor(COL_ROW_HOV)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end

    local statsPanelInstance = nil
    local adminStatsRows = {}

    local pendingAdminStats
    local statsStatus = "Loading..."
    local statsLastActivity = 0
    local function StatsStatus(text)
        statsStatus = text
        statsLastActivity = RealTime()
        if IsValid(statsPanelInstance) then statsPanelInstance:SetTitle("Player SQL Stats - " .. text) end
    end
    local function StatsFailed(text)
        pendingAdminStats = nil
        StatsStatus(text .. " - press Refresh")
    end
    timer.Create("ChudSQLClientTimeout", 2, 0, function()
        if IsValid(statsPanelInstance) and statsLastActivity > 0 and RealTime() - statsLastActivity > 35
            and (pendingAdminStats or statsStatus == "Loading...") then
            StatsFailed("No data received; check that both SQL menu files are installed on the server")
        end
    end)

    net.Receive("ZB_AdminStatsChunkV2", function()
        local id = net.ReadUInt(32)
        local count, index, size = net.ReadUInt(16), net.ReadUInt(16), net.ReadUInt(16)
        if count < 1 or count > 2048 or index < 1 or index > count or size < 1 or size > 4096 then
            StatsFailed("Invalid data chunk") return
        end
        local bytes = net.ReadData(size)
        if not bytes or #bytes ~= size then StatsFailed("Invalid data chunk") return end
        if index == 1 then pendingAdminStats = {id = id, count = count, nextIndex = 1, parts = {}} end
        local pending = pendingAdminStats
        if not pending or pending.id ~= id or pending.count ~= count or pending.nextIndex ~= index then StatsFailed("Transfer interrupted") return end
        StatsStatus("Receiving " .. index .. "/" .. count)
        pending.parts[index] = bytes
        pending.nextIndex = index + 1
        net.Start("ZB_AdminStatsAckV2")
            net.WriteUInt(id, 32)
            net.WriteUInt(index, 16)
        net.SendToServer()
        if index ~= count then return end
        pendingAdminStats = nil
        local json = util.Decompress(table.concat(pending.parts))
        if not json or #json > 32 * 1024 * 1024 then StatsFailed("Could not decompress SQL data") return end
        -- The server-generated snapshot has a strict byte limit but can legitimately
        -- exceed the default 15,000 JSON keys with per-player achievements.
        local rows = util.JSONToTable(json, true)
        if not istable(rows) then StatsFailed("Could not decode SQL data") return end
        for _, row in ipairs(rows) do
            if not istable(row) or not isstring(row.steamid) then StatsFailed("Invalid SQL row") return end
        end
        adminStatsRows = rows
        StatsStatus(tostring(#rows) .. " players loaded")
        if IsValid(statsPanelInstance) and statsPanelInstance.RefreshRows then statsPanelInstance:RefreshRows() end
    end)

    net.Receive("ZB_AdminStatsSaveResult", function()
        local ok = net.ReadBool()
        local message = net.ReadString()

        chat.AddText(ok and Color(0, 255, 0) or Color(255, 80, 80), message)
    end)

    local function OpenPlayerStatsMenu()
        if not LocalPlayer():IsSuperAdmin() then return end
        if IsValid(statsPanelInstance) then return end

        local frame = NewFrame(900, 560)
        statsPanelInstance = frame
        frame.SetTitle = function() end -- status lives in the header sub line now
        local pad = MenuUnit(10)
        frame:DockPadding(pad, pad, pad, pad)
        CreateHeader(frame, frame, "Player SQL Stats", function() return statsStatus end)

        local topPanel = vgui.Create("DPanel", frame)
        topPanel:Dock(TOP)
        topPanel:SetTall(35)
        topPanel:DockMargin(MenuUnit(14), 0, MenuUnit(14), MenuUnit(8))
        topPanel.Paint = nil

        local search = vgui.Create("DTextEntry", topPanel)
        search:Dock(FILL)
        search:SetPlaceholderText("Search name or SteamID64")
        StyleEntry(search)

        local refreshBtn = vgui.Create("DButton", topPanel)
        refreshBtn:Dock(RIGHT)
        refreshBtn:SetWide(100)
        refreshBtn:DockMargin(MenuUnit(8), 0, 0, 0)
        refreshBtn:SetText("Refresh")
        StyleElement(refreshBtn)

        local leftPanel = vgui.Create("DPanel", frame)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(350)
        leftPanel:DockMargin(MenuUnit(14), 0, MenuUnit(8), MenuUnit(4))
        StylePanel(leftPanel)

        local list = vgui.Create("DListView", leftPanel)
        list:Dock(FILL)
        list:AddColumn("Player")
        list:AddColumn("SteamID64")
        list:AddColumn("Status")
        StyleList(list)

        local rightPanel = vgui.Create("DScrollPanel", frame)
        rightPanel:Dock(FILL)
        rightPanel:DockMargin(0, 0, MenuUnit(14), MenuUnit(4))
        StyleScroll(rightPanel)

        local selectedRow
        local entries = {}
        local achievementEntries = {}

        local function AddEntry(parent, label, key, value)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 0, MenuUnit(6), 4)
            StylePanel(row)

            local title = vgui.Create("DLabel", row)
            title:Dock(LEFT)
            title:SetWide(110)
            title:SetText(label)
            title:SetTextColor(COL_TEXT_DIM)
            title:SetFont("ZB_QM_Small")
            title:SetTextInset(MenuUnit(8), 0)

            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            StyleEntry(entry)
            entry:SetText(tostring(value or 0))

            entries[key] = entry
        end

        local function AddAchievementEntry(parent, key, value)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 0, MenuUnit(6), 4)
            StylePanel(row)

            local title = vgui.Create("DLabel", row)
            title:Dock(LEFT)
            title:SetWide(110)
            title:SetText(key)
            title:SetTextColor(COL_TEXT_DIM)
            title:SetFont("ZB_QM_Small")
            title:SetTextInset(MenuUnit(8), 0)

            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            StyleEntry(entry)
            entry:SetText(tostring(value or 0))

            achievementEntries[key] = entry
        end

        local function ShowPlayer(row)
            selectedRow = row
            entries = {}
            achievementEntries = {}
            rightPanel:Clear()

            if not row then return end

            local title = vgui.Create("DLabel", rightPanel)
            title:Dock(TOP)
            title:SetTall(32)
            title:SetFont("ZB_QM_Item")
            title:SetText(row.name .. " | " .. row.steamid .. (row.active and " | ACTIVE" or ""))
            title:SetTextColor(row.active and COL_RED or COL_TEXT)

            AddEntry(rightPanel, "XP", "experience", row.experience)
            AddEntry(rightPanel, "Skill", "skill", row.skill)
            AddEntry(rightPanel, "Deaths", "deaths", row.deaths)
            AddEntry(rightPanel, "Kills", "kills", row.kills)
            AddEntry(rightPanel, "Suicides", "suicides", row.suicides)
            AddEntry(rightPanel, "Headshots", "headshots", row.headshots)
            AddEntry(rightPanel, "Karma", "karma", row.karma)

            local achTitle = vgui.Create("DLabel", rightPanel)
            achTitle:Dock(TOP)
            achTitle:SetTall(28)
            achTitle:SetFont("ZB_QM_Category")
            achTitle:SetText("ACHIEVEMENTS")
            achTitle:SetTextColor(COL_TEXT_DIM)

            for key, value in SortedPairs(row.achievements or {}) do
                AddAchievementEntry(rightPanel, key, value)
            end

            local saveBtn = vgui.Create("DButton", rightPanel)
            saveBtn:Dock(TOP)
            saveBtn:SetTall(34)
            saveBtn:DockMargin(0, 8, 0, 0)
            saveBtn:SetText("Save Stats")
            StyleElement(saveBtn)
            saveBtn.DoClick = function()
                if not selectedRow then return end

                local data = {name = selectedRow.name}
                for key, entry in pairs(entries) do
                    data[key] = entry:GetText()
                end

                data.achievements = {}
                for key, entry in pairs(achievementEntries) do
                    data.achievements[key] = entry:GetText()
                end

                net.Start("ZB_AdminStatsSave")
                    net.WriteString(selectedRow.steamid)
                    net.WriteTable(data)
                net.SendToServer()
            end
        end

        function frame:RefreshRows()
            local needle = search:GetText():lower()
            list:Clear()

            for _, row in ipairs(adminStatsRows) do
                local name = tostring(row.name or "Unknown")
                local steamID64 = tostring(row.steamid or "")

                if needle == "" or name:lower():find(needle, 1, true) or steamID64:find(needle, 1, true) then
                    local line = list:AddLine(name, steamID64, row.active and "Online" or "Offline")
                    line.RowData = row
                    StyleListLine(line, row.active)
                end
            end
        end

        list.OnRowSelected = function(panel, index, line)
            ShowPlayer(line.RowData)
        end

        search.OnValueChange = function()
            frame:RefreshRows()
        end

        refreshBtn.DoClick = function()
            StatsStatus("Loading...")
            net.Start("ZB_AdminStatsRequest")
            net.SendToServer()
        end

        frame.OnClose = function()
            statsPanelInstance = nil
        end

        frame:RefreshRows()
        StatsStatus("Loading...")
        net.Start("ZB_AdminStatsRequest")
        net.SendToServer()
    end
    ------------------------------------------------------------------
    -- F6 admin panel: ESC-menu style text buttons
    ------------------------------------------------------------------
    local function OpenAdminMenu()
        if IsValid(isMenuOpen) then return end
        local frame = NewFrame(MenuUnit(460), 200)
        isMenuOpen = frame
        local content = MakeContent(frame)
        CreateHeader(content, frame, "Admin Panel", MapSub)

        local list = vgui.Create("DPanel", content)
        list:Dock(FILL)
        list:DockMargin(MenuUnit(8), 0, MenuUnit(8), 0)
        list.Paint = nil

        local buttons = {}
        local function BigButton(text, danger)
            local btn = vgui.Create("DButton", list)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, MenuUnit(2))
            btn:SetTall(MenuUnit(44))
            btn:SetText("")
            btn.TypeSound = true
            btn.TypeStart = RealTime() + #buttons * 0.08 -- stagger the reveal like the ESC menu
            btn.UnderlineCol = danger and COL_RED or color_white
            btn.OnCursorEntered = function() surface.PlaySound(SND_HOVER) end
            btn.Paint = function(self, w, h)
                local shown = RealTime() >= self.TypeStart and Typewrite(self, text, 25) or string.rep("#", #text)
                PaintRemText(self, w, h, shown, "ZB_QM_Big", danger and COL_RED or COL_TEXT)
                return true
            end
            buttons[#buttons + 1] = btn
            return btn
        end

        local manageBtn = BigButton("Game Mode Queue")
        manageBtn.DoClick = function()
            surface.PlaySound(SND_CLICK)
            OpenQueueManager()
        end

        if LocalPlayer():IsSuperAdmin() then
            local statsBtn = BigButton("Player SQL Stats")
            statsBtn.DoClick = function()
                surface.PlaySound(SND_CLICK)
                OpenPlayerStatsMenu()
            end
        end

        local endBtn = BigButton("End Round", true)
        endBtn.DoClick = function()
            surface.PlaySound(SND_CLICK)
            net.Start("AdminEndRound")
            net.SendToServer()
            frame:Close()
        end

        -- padding (10*2) + header (64+10) + buttons (44+2 each) + bottom breathing room
        frame:SetTall(MenuUnit(20) + MenuUnit(74) + #buttons * (MenuUnit(44) + MenuUnit(2)) + MenuUnit(12))
        frame:Center()

        frame.OnClose = function()
            isMenuOpen = false
        end
    end

    hook.Add("InitPostEntity", "RequestModeData", function()
        if LocalPlayer():IsAdmin() then
            timer.Simple(2, function()
                net.Start("ZB_RequestRoundList")
                net.SendToServer()
            end)
        end
    end)

    local f6Key = KEY_F6

    hook.Add("PlayerButtonDown", "OpenAdminMenuF6", function(ply, key)
        if key == f6Key and LocalPlayer():IsAdmin() and not IsValid(isMenuOpen) then
            OpenAdminMenu()
        end
    end)
end
