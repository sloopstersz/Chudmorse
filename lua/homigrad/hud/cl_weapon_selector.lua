-- Chudmorse weapon selector: weapons sit on an arc. The selected weapon is the big
-- card at the top of the arc; the previous / next weapons hang lower on each side.
-- Scroll wheel slides along the arc (wraps), slot keys 1-6 jump to / cycle a slot,
-- LMB or RMB equips, lastinv swaps back. Client only.

hg = hg or {}
hg.WeaponSelector = hg.WeaponSelector or {}
local WS = hg.WeaponSelector

WS.Show = WS.Show or 0
WS.Transparent = WS.Transparent or 0
WS.Index = WS.Index or 1
WS.Target = WS.Target or 1
WS.Pos = WS.Pos or 1
WS.Pop = WS.Pop or 0
WS.Open = false

--;; ---------------------------------------------------------------- look
local C = {
    body      = Color(14, 14, 16, 235),
    bodySide  = Color(20, 20, 23, 215),
    frame     = Color(6, 6, 7, 245),
    edge      = Color(120, 120, 126),
    tag       = Color(78, 78, 84),
    shade     = Color(60, 60, 66),
    line      = Color(150, 150, 156),
    text      = Color(236, 236, 236),
    dim       = Color(150, 150, 154),
}

local ARC_STEP    = math.rad(34)   -- angle between neighbouring cards
local ARC_RADIUS  = 0.45           -- * ScrH
local ARC_TOP     = 0.075          -- apex height, * ScrH
local CARD_W      = 0.25           -- center card, * ScrH
local CARD_H      = 0.13
local SIDE_SCALE  = 0.85           -- side boxes vs the middle one
local SMALL_W     = 0.5            -- small (unselected) box, fraction of the big card
local SMALL_H     = 0.56
local VISIBLE     = 1.75           -- cards further than this (in steps) are hidden
local LINE_SPAN   = 1.02           -- arc line ends at the side cards, like the sketch
local LINE_THICK  = 3
local SHOW_TIME   = 4
local ICON_SCALE  = 0.7            -- icon size inside the small box (1 = fill it)

local gradDown = Material("vgui/gradient-d")

local function U(n) return math.max(1, math.floor(n * ScrH() / 1080 + 0.5)) end

local function CreateFonts()
    local f = "Verily Serif Mono"
    surface.CreateFont("ChudWS_Name",  {font = f, size = U(19), weight = 700, antialias = true, extended = true})
    surface.CreateFont("ChudWS_Small", {font = f, size = U(14), weight = 500, antialias = true, extended = true})
    surface.CreateFont("ChudWS_Tiny",  {font = f, size = U(12), weight = 800, antialias = true, extended = true})
end
CreateFonts()
hook.Add("OnScreenSizeChanged", "ChudWS_Fonts", CreateFonts)

--;; ---------------------------------------------------------------- weapons
function WS.GetPrintName(wep)
    local class = wep:GetClass()
    local phrase = language.GetPhrase(class)
    return phrase ~= class and phrase or wep:GetPrintName()
end

-- Kept for compatibility: [slot][pos] = weapon, same ordering as before.
function WS.GetWeaponTable(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local list = ply:GetWeapons()
    local out = {[0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}}

    table.sort(list, function(a, b) return (a.SlotPos or 0) > (b.SlotPos or 0) end)

    for _, wep in ipairs(list) do
        local tbl = out[math.Clamp(wep.Slot or 0, 0, 5)]
        local minPos = math.min(wep.SlotPos or 1, #tbl + 1) - 1
        tbl[tbl[minPos] and #tbl + 1 or minPos] = wep
    end

    return out
end

-- Flat list in slot order: { {wep = , slot = }, ... }
local function BuildList(ply)
    local tbl = WS.GetWeaponTable(ply)
    local list = {}
    if not tbl then return list end

    for slot = 0, 5 do
        local s = tbl[slot]
        for pos = 0, table.maxn(s) do
            local wep = s[pos]
            if IsValid(wep) then list[#list + 1] = {wep = wep, slot = slot} end
        end
    end

    return list
end

local function IndexOf(list, wep)
    if not IsValid(wep) then return end
    for i, e in ipairs(list) do
        if e.wep == wep then return i end
    end
end

local function Wrap(i, n) return (i - 1) % n + 1 end

-- shortest signed distance from a to b on a ring of n
local function RingDelta(a, b, n)
    local d = (b - a) % n
    if d >= n / 2 then d = d - n end
    return d
end

function WS.GetSelectedWeapon()
    local e = WS.List and WS.List[WS.Index]
    return e and e.wep
end

local function SetIndex(idx, n)
    if idx == WS.Index then return end
    WS.Target = WS.Target + RingDelta(WS.Index, idx, n)
    WS.Index = idx
    WS.Pop = 1
end

local function OpenAt(list, ply)
    local idx = IndexOf(list, ply:GetActiveWeapon()) or 1
    WS.Index, WS.Target, WS.Pos = idx, idx, idx
    WS.Open = true
    WS.Pop = 0.6
end

--;; ---------------------------------------------------------------- drawing
local function DrawLine(x1, y1, x2, y2, thick)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.5 then return end
    surface.DrawTexturedRectRotated((x1 + x2) * 0.5, (y1 + y2) * 0.5, len + 1, thick, -math.deg(math.atan2(dy, dx)))
end

local function ArcPoint(t, cx, apexY, R)
    local a = t * ARC_STEP
    return cx + R * math.sin(a), apexY + R * (1 - math.cos(a))
end

local function Outline(x, y, w, h, col, a, thick)
    surface.SetDrawColor(col.r, col.g, col.b, a)
    surface.DrawOutlinedRect(x, y, w, h, thick)
end

local function DrawIcon(wep, x, y, w, h, alpha, angle)
    if w <= 2 or h <= 2 then return end
    local mat, tex, box

    if wep.IconOverride and wep.IconOverride ~= "" and wep.WepSelectIcon2 then
        mat, box = wep.WepSelectIcon2, wep.WepSelectIcon2box
    elseif isnumber(wep.WepSelectIcon) then
        tex = wep.WepSelectIcon
    elseif wep.WepSelectIcon then
        mat = wep.WepSelectIcon
    elseif wep.DrawWeaponSelection then
        wep:DrawWeaponSelection(x, y, w, h, alpha)
        return
    else
        return
    end

    -- fit a 2:1 icon (1:1 for "box" icons) inside the rect
    local aspect = box and 1 or 2
    local dw = math.min(w, h * aspect)
    local dh = dw / aspect

    surface.SetDrawColor(255, 255, 255, alpha)
    if tex then surface.SetTexture(tex) else surface.SetMaterial(mat) end

    render.PushFilterMag(TEXFILTER.ANISOTROPIC)
    render.PushFilterMin(TEXFILTER.ANISOTROPIC)
    surface.DrawTexturedRectRotated(x + w * 0.5, y + h * 0.5, dw, dh, angle or 0)
    render.PopFilterMin()
    render.PopFilterMag()
end

local function Text(str, font, x, y, col, a, alignX, alignY)
    draw.SimpleText(str, font, x + 1, y + 1, Color(0, 0, 0, a * 0.9), alignX, alignY)
    draw.SimpleText(str, font, x, y, ColorAlpha(col, a), alignX, alignY)
end

local function FitName(str, font, maxW)
    surface.SetFont(font)
    if surface.GetTextSize(str) <= maxW then return str end
    local chars = {}
    for _, code in utf8.codes(str) do chars[#chars + 1] = utf8.char(code) end
    while #chars > 1 do
        chars[#chars] = nil
        local cut = table.concat(chars) .. "..."
        if surface.GetTextSize(cut) <= maxW then return cut end
    end
    return "..."
end

-- card geometry for arc offset t (in steps from the center).
-- Every weapon is a small box around its icon. The selected one grows into the big
-- card, with the small box sitting in its middle on the arc.
local function CardGeo(t, cx, apexY, R, fade, appear)
    local H = ScrH()
    local depth = math.abs(t)
    local near = math.min(depth, 1)
    local g = {t = t, near = near, isCenter = depth < 0.5}

    -- 0 = small box, 1 = big card (eased so it snaps open as it reaches the middle)
    local open = 1 - near
    open = open * open * (3 - 2 * open)
    g.open = open

    local scale = Lerp(near, 1, SIDE_SCALE) * (1 + 0.06 * WS.Pop * open)
    local sw, sh = H * CARD_W * SMALL_W * scale, H * CARD_H * SMALL_H * scale
    local bw, bh = H * CARD_W * scale, H * CARD_H * scale

    local drop = (1 - appear) * H * 0.04
    g.ax, g.ay = ArcPoint(t, cx, apexY, R)
    g.ay = g.ay - drop

    -- small box: threaded on the arc in the middle, hangs from it at the sides
    local sCenterY = g.ay + Lerp(open, sh * 0.5 - sh * 0.08, 0)
    g.sx, g.sy, g.sw, g.sh = g.ax - sw * 0.5, sCenterY - sh * 0.5, sw, sh

    -- big card around it
    local bx, by = g.ax - bw * 0.5, sCenterY - bh * 0.42

    g.x = Lerp(open, g.sx, bx)
    g.y = Lerp(open, g.sy, by)
    g.w = Lerp(open, sw, bw)
    g.h = Lerp(open, sh, bh)

    g.a = 255 * fade * Lerp(near, 1, 0.8)
    g.fade = fade
    g.pad = U(8) * scale
    return g
end

local function DrawBody(g)
    if g.a <= 1 then return end
    local body = C.body
    surface.SetDrawColor(body.r, body.g, body.b, body.a * g.fade)
    surface.DrawRect(g.x, g.y, g.w, g.h)
    if g.open > 0.01 then
        surface.SetMaterial(gradDown)
        surface.SetDrawColor(C.shade.r, C.shade.g, C.shade.b, 90 * g.a / 255 * g.open)
        surface.DrawTexturedRect(g.x, g.y + g.h * 0.4, g.w, g.h * 0.6)
        draw.NoTexture()
    end
    Outline(g.x, g.y, g.w, g.h, C.edge, g.a * Lerp(g.open, 0.75, 1), U(2))
end

local function DrawContents(g, e, activeWep)
    if g.a <= 1 then return end
    local wep = e.wep
    local a, pad, open = g.a, g.pad, g.open

    -- icon always sits in the small box
    local iw, ih = g.sw * ICON_SCALE, g.sh * ICON_SCALE
    local swing = math.sin(CurTime() * 1.5) * 6 * open
    DrawIcon(wep, g.ax - iw * 0.5, g.sy + (g.sh - ih) * 0.5, iw, ih, a, swing)

    if open <= 0.02 then return end
    local oa = a * open

    local name = WS.GetPrintName(wep)
    local belowY = g.sy + g.sh
    local nameY = belowY + (g.y + g.h - belowY) * 0.5
    Text(FitName(name, "ChudWS_Name", g.w - pad * 2), "ChudWS_Name", g.ax, nameY, C.text, oa, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    Text(tostring(e.slot + 1), "ChudWS_Tiny", g.x + pad, g.y + pad * 0.7, C.text, oa, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    if wep == activeWep then
        local tag = "EQUIPPED"
        surface.SetFont("ChudWS_Tiny")
        local tw, th = surface.GetTextSize(tag)
        local tx, ty = g.x + g.w - pad - tw, g.y + pad * 0.7
        surface.SetDrawColor(C.tag.r, C.tag.g, C.tag.b, oa * 0.9)
        surface.DrawRect(tx - U(4), ty - U(1), tw + U(8), th + U(2))
        draw.SimpleText(tag, "ChudWS_Tiny", tx, ty, Color(255, 255, 255, oa), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

function WS.WeaponSelectorDraw(ply)
    if not IsValid(ply) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then
        WS.Open = false
        return
    end

    if WS.Show < CurTime() then
        WS.Open = false
        WS.Transparent = 0
        return
    end

    local list = BuildList(ply)
    local n = #list
    if n < 1 then return end
    WS.List = list

    -- keep the same weapon selected if the inventory changed under us
    if IsValid(WS.SelWep) then
        local idx = IndexOf(list, WS.SelWep)
        if idx then SetIndex(idx, n) end
    end
    WS.Index = Wrap(WS.Index, n)
    WS.SelWep = list[WS.Index].wep

    local ft = FrameTime()
    WS.Transparent = Lerp(math.min(ft * 10, 1), WS.Transparent, math.Clamp(WS.Show - CurTime(), 0, 1))
    WS.Pos = WS.Pos + (WS.Target - WS.Pos) * math.min(ft * 14, 1)
    WS.Pop = math.max(WS.Pop - ft * 4, 0)

    local fade = WS.Transparent
    local appear = 1 - (1 - math.Clamp(fade, 0, 1)) ^ 3
    local H = ScrH()
    local cx = ScrW() * 0.5
    local R = H * ARC_RADIUS
    local apexY = H * ARC_TOP + (1 - appear) * -H * 0.03
    local activeWep = ply:GetActiveWeapon()

    -- cards, far ones first
    local cards = {}
    for i, e in ipairs(list) do
        local t = n == 1 and 0 or RingDelta(WS.Pos, i, n)
        local depth = math.abs(t)
        if depth <= VISIBLE then
            local edge = depth > 1 and math.Clamp((VISIBLE - depth) / (VISIBLE - 1), 0, 1) or 1
            cards[#cards + 1] = {e = e, g = CardGeo(t, cx, apexY, R, fade * edge, appear)}
        end
    end
    table.sort(cards, function(a, b) return math.abs(a.g.t) > math.abs(b.g.t) end)


    -- arc line (behind the cards)
    if n > 1 then
        draw.NoTexture()
        local segs = 40
        local lineY = (1 - appear) * H * 0.04
        local px, py
        for i = 0, segs do
            local t = -LINE_SPAN + (2 * LINE_SPAN) * i / segs
            local x, y = ArcPoint(t, cx, apexY, R)
            y = y - lineY
            if px then
                local edgeFade = math.Clamp((LINE_SPAN - math.abs(t)) / 0.12 + 0.35, 0, 1)
                surface.SetDrawColor(C.line.r, C.line.g, C.line.b, 220 * fade * edgeFade)
                DrawLine(px, py, x, y, U(LINE_THICK))
            end
            px, py = x, y
        end
    end

    draw.NoTexture()
    for _, c in ipairs(cards) do DrawBody(c.g) end

    for _, c in ipairs(cards) do DrawContents(c.g, c.e, activeWep) end

    -- position counter under the arc
    Text(WS.Index .. " / " .. n, "ChudWS_Tiny", cx, apexY + H * CARD_H * 0.62 + U(10), C.dim, 200 * fade, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

--;; ---------------------------------------------------------------- input
local slotKeys = {slot1 = 0, slot2 = 1, slot3 = 2, slot4 = 3, slot5 = 4, slot6 = 5}

local function GetActiveTool(ply, tool)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" or wep.Mode ~= tool then return end
    return wep:GetToolObject(tool)
end

local function SelectorBlocked(ply)
    local wep = ply:GetActiveWeapon()
    local tool = GetActiveTool(ply, "submaterial")
    if tool and IsValid(ply:GetEyeTraceNoCursor().Entity) then return true end

    return (IsAiming and IsAiming(ply))
        or (IsValid(wep) and wep:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK))
        or (ply.organism and ply.organism.pain and ply.organism.pain > 100)
        or GetGlobalBool("RadialInventory", false)
end

local function Tick()
    surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin" .. math.random(10) .. ".ogg")
end

function WS.ChangeSelectionWep(ply, key)
    if not IsValid(ply) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if ply.organism and ply.organism.otrub then return end
    if SelectorBlocked(ply) then return end

    local slot = slotKeys[key]
    if not (slot or key == "invnext" or key == "invprev" or key == "lastinv") then return end

    if key == "lastinv" then
        if IsValid(WS.LastInv) then
            WS.Show = 0
            local old = ply:GetActiveWeapon()
            input.SelectWeapon(WS.LastInv)
            WS.LastInv = old
        end
        return
    end

    local list = BuildList(ply)
    local n = #list
    if n < 1 then return end
    WS.List = list

    local wasOpen = WS.Open and WS.Show > CurTime()
    if not wasOpen then OpenAt(list, ply) end
    WS.Index = Wrap(WS.Index, n)

    if slot then
        -- slot key: first weapon of that slot, or the next one in it if already there
        local first, nextInSlot
        local cur = list[WS.Index]
        for i, e in ipairs(list) do
            if e.slot == slot then
                first = first or i
                if wasOpen and cur.slot == slot and i > WS.Index and not nextInSlot then nextInSlot = i end
            end
        end
        if not first then return end
        SetIndex(nextInSlot or first, n)
    elseif key == "invnext" then
        WS.Index = Wrap(WS.Index + 1, n)
        WS.Target = WS.Target + 1
        WS.Pop = 1
    else
        WS.Index = Wrap(WS.Index - 1, n)
        WS.Target = WS.Target - 1
        WS.Pop = 1
    end

    WS.SelWep = list[WS.Index].wep
    WS.Show = CurTime() + SHOW_TIME
    Tick()
end

function WS.SetActuallyWeapon(ply, cmd)
    if not IsValid(ply) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if WS.Show <= CurTime() then return end
    if not (cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)) then return end

    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)

    if WS.Selected and WS.Selected > CurTime() then return end

    local wep = WS.GetSelectedWeapon()
    if IsValid(wep) then
        local active = ply:GetActiveWeapon()
        if wep ~= active then WS.LastInv = active end
        input.SelectWeapon(wep)
    end

    WS.Selected = CurTime() + 0.2
    WS.Show = CurTime() + 0.2
    WS.Pop = 1
    surface.PlaySound("arc9_eft_shared/weapon_generic_spin" .. math.random(1, 10) .. ".ogg")
end

hook.Add("PlayerBindPress", "WeaponSelector_PlayerBindPress", WS.ChangeSelectionWep)
hook.Add("HUDPaint", "WeaponSelector_Draw", function() WS.WeaponSelectorDraw(LocalPlayer()) end)
hook.Add("StartCommand", "WeaponSelector_StartCommand", WS.SetActuallyWeapon)

hook.Add("HUDShouldDraw", "WeaponSelector_HUDShouldDraw", function(name)
    if name == "CHudWeaponSelection" then return false end
end)
