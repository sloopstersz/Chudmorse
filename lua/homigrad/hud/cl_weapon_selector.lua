-- Chudmorse weapon selector: one card per slot, sitting on a U-shaped arc. The selected
-- slot is the big card at the bottom of the arc; the other slots ride up the sides.
-- A slot with more than one weapon shows them stacked: the selected one in front, the
-- rest peeking out above it (next one first). Scroll wheel steps through every weapon
-- (through the stack, then on to the next slot, wraps), slot keys 1-6 jump to / cycle a
-- slot, LMB or RMB equips, lastinv swaps back. Client only.

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
local ARC_WIDTH   = 0.42           -- horizontal radius of the U, * ScrH
local ARC_RISE    = 0.18           -- vertical radius (how fast the sides climb), * ScrH
local TOP_MARGIN  = 0.02           -- gap above the top of the selected slot's stack, * ScrH
local CARD_W      = 0.25           -- center card, * ScrH
local CARD_H      = 0.13
local SIDE_SCALE  = 0.65           -- side boxes vs the middle one
local SMALL_W     = 0.5            -- small (unselected) box, fraction of the big card
local SMALL_H     = 0.56
local VISIBLE     = 1.75           -- cards further than this (in steps) are hidden
local LINE_SPAN   = 1.02           -- arc line ends at the side cards, like the sketch
local LINE_THICK  = 3
local SHOW_TIME   = 4
local ICON_SCALE  = 0.92           -- icon size inside the small box (1 = fill it)
local STACK_BIG   = 0.30           -- visible strip of each stacked weapon on the big card, * card height
local STACK_SMALL = 0.24           -- same for the small side boxes
local STACK_MAX   = 3              -- stacked weapons shown above a card (more slide in as you flip)
local FLIP_SPEED  = 14             -- how fast the stack flips to the next weapon

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

-- one group per slot that has weapons: { slot = , items = { flat indices } }
local function BuildGroups(list)
    local groups, groupOf = {}, {}
    for i, e in ipairs(list) do
        local g = groups[#groups]
        if not g or g.slot ~= e.slot then
            g = {slot = e.slot, items = {}}
            groups[#groups + 1] = g
        end
        g.items[#g.items + 1] = i
        groupOf[i] = #groups
    end
    return groups, groupOf
end

local function IndexOf(list, wep)
    if not IsValid(wep) then return end
    for i, e in ipairs(list) do
        if e.wep == wep then return i end
    end
end

local WS_Reverse = CreateClientConVar("hg_weaponselector_reverse", "0", true, false, "Reverse which way the arc weapon selector rolls", 0, 1)

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

-- the arc moves in slot (group) steps; WS.Index is still the flat weapon index
local function SetIndex(idx, n)
    if idx == WS.Index then return end
    local groups, groupOf = WS.Groups or {}, WS.GroupOf or {}
    local G = #groups
    if G > 0 and groupOf[idx] then
        local cur = Wrap(math.Round(WS.Target), G)
        WS.Target = WS.Target + RingDelta(cur, groupOf[idx], G)
    end
    WS.Index = idx
    WS.Pop = 1
end

local function OpenAt(list, ply)
    local idx = IndexOf(list, ply:GetActiveWeapon()) or 1
    local g = WS.GroupOf and WS.GroupOf[idx] or 1
    WS.Index, WS.Target, WS.Pos = idx, g, g
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

-- U-shaped arc (half an ellipse): lowest at the middle (t = 0), rising towards the sides
local function ArcPoint(t, cx, baseY, R)
    local a = t * ARC_STEP
    return cx + R * math.sin(a), baseY - R * (ARC_RISE / ARC_WIDTH) * (1 - math.cos(a))
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
-- Every slot is a small box around its icon, standing on the arc. The selected one grows
-- into the big card (still standing on the arc), with the icon box in its upper part.
local function CardGeo(t, cx, baseY, R, fade, appear)
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
    g.ax, g.ay = ArcPoint(t, cx, baseY, R)
    g.ay = g.ay - drop

    -- small box stands on the arc; on the big card it sits in the upper part
    local bx, by = g.ax - bw * 0.5, g.ay - bh
    local sCenterY = Lerp(open, g.ay - sh * 0.5, by + bh * 0.42)
    g.sx, g.sy, g.sw, g.sh = g.ax - sw * 0.5, sCenterY - sh * 0.5, sw, sh

    g.x = Lerp(open, g.sx, bx)
    g.y = Lerp(open, g.sy, by)
    g.w = Lerp(open, sw, bw)
    g.h = Lerp(open, sh, bh)

    g.a = 255 * fade * Lerp(near, 1, 0.8)
    g.fade = fade
    g.pad = U(8) * scale
    g.stripH = Lerp(open, sh * STACK_SMALL, bh * STACK_BIG)
    return g
end

-- copy of a card's geometry moved up/down by dy, with its alpha scaled
local function ShiftGeo(g, dy, alpha)
    local c = {}
    for k, v in pairs(g) do c[k] = v end
    c.y, c.sy, c.ay = g.y + dy, g.sy + dy, g.ay + dy
    c.a = g.a * alpha
    c.fade = g.fade * alpha
    return c
end

local function DrawBody(g)
    if g.a <= 1 then return end
    local body = g.back and C.bodySide or C.body
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

-- One slot = a deck of cards. items = flat indices, s = which item is in front (0-based,
-- fractional while flipping). Card at depth d sits d strips higher; depth 0 is the front.
-- While flipping, the card leaving the front slides down and fades out as it reappears
-- at the back of the deck (and the other way round when scrolling backwards).
-- Strip above the selected card showing the weapon the next scroll goes to, when it's
-- in another slot (so there's always something ahead, even on a slot's last weapon).
local function DrawNextStrip(g, nextE)
    if not nextE or g.open <= 0.02 then return end
    local c = ShiftGeo(g, -g.stripH, 0.9)
    c.back = true
    c.open = g.open * 0.6
    draw.NoTexture()
    DrawBody(c)
    local la = c.a * g.open
    Text(FitName("Next: " .. WS.GetPrintName(nextE.wep), "ChudWS_Small", g.w - g.pad * 2), "ChudWS_Small", g.ax, c.y + g.stripH * 0.5, C.dim, la, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawSlot(g, list, items, s, activeWep, nextE)
    local m = #items
    -- nothing left ahead in this slot: preview the next weapon instead
    if nextE and s >= m - 1 - 0.001 then DrawNextStrip(g, nextE) end
    if m == 1 then
        DrawBody(g)
        DrawContents(g, list[items[1]], activeWep)
        return
    end

    local lim = math.min(m - 1, STACK_MAX)
    local layers, leaving = {}, nil

    -- only the weapons still ahead in this slot are stacked; ones you've scrolled past are gone
    for p = 0, m - 1 do
        local d = p - s
        local e = list[items[p + 1]]

        if d >= 0 then
            local backA = math.Clamp(lim + 1 - d, 0, 1)
            if backA > 0.01 then layers[#layers + 1] = {d = d, e = e, alpha = backA} end
        elseif d > -1 then
            -- the card just passed slides down and fades out
            leaving = {e = e, t = 1 + d}  -- 1 = fully in front, 0 = gone
        end
    end

    table.sort(layers, function(a, b) return a.d > b.d end)

    for _, L in ipairs(layers) do
        local c = ShiftGeo(g, -L.d * g.stripH, L.alpha)
        local frontness = math.Clamp(1 - L.d * 2, 0, 1)
        c.back = frontness < 0.5
        c.open = g.open * (0.6 + 0.4 * frontness)
        draw.NoTexture()
        DrawBody(c)

        -- stacked cards show their name in the strip that peeks out
        if frontness < 1 then
            local la = c.a * (1 - frontness)
            local font = g.open > 0.5 and "ChudWS_Small" or "ChudWS_Tiny"
            Text(FitName(WS.GetPrintName(L.e.wep), font, g.w - g.pad), font, g.ax, c.y + g.stripH * 0.5, C.dim, la, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        if frontness > 0 then
            local cc = ShiftGeo(g, -L.d * g.stripH, L.alpha * frontness)
            DrawContents(cc, L.e, activeWep)
        end
    end

    if leaving and leaving.t > 0.01 then
        local c = ShiftGeo(g, (1 - leaving.t) * g.h * 0.55, leaving.t)
        draw.NoTexture()
        DrawBody(c)
        DrawContents(c, leaving.e, activeWep)
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
    local groups, groupOf = BuildGroups(list)
    WS.Groups, WS.GroupOf = groups, groupOf
    local G = #groups

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
    local R = H * ARC_WIDTH
    local activeWep = ply:GetActiveWeapon()
    local activeIdx = IndexOf(list, activeWep)

    -- flip state of the selected slot's deck
    local selGroup = groupOf[WS.Index]
    local selItems = groups[selGroup].items
    local selPos = 0
    for p, idx in ipairs(selItems) do if idx == WS.Index then selPos = p - 1 break end end
    local m = #selItems
    if WS.StackGroup ~= groups[selGroup].slot or not WS.StackTarget then
        WS.StackGroup = groups[selGroup].slot
        WS.StackTarget, WS.StackPos = selPos, selPos
    else
        WS.StackTarget = selPos
    end
    WS.StackPos = WS.StackPos + (WS.StackTarget - WS.StackPos) * math.min(ft * FLIP_SPEED, 1)

    -- dock to the top: the selected slot's whole deck fits under TOP_MARGIN
    local bigH = H * CARD_H
    local deckH = math.max(math.min(math.max(m - 1 - selPos, 0), STACK_MAX), #groups > 1 and 1 or 0) * bigH * STACK_BIG
    local wantBase = H * TOP_MARGIN + deckH + bigH
    WS.BaseY = WS.BaseY and Lerp(math.min(ft * 12, 1), WS.BaseY, wantBase) or wantBase
    local baseY = WS.BaseY + (1 - appear) * -H * 0.03

    -- one card per slot, far ones first
    local cards = {}
    for gi, grp in ipairs(groups) do
        -- mirrored so the arc rolls the same way as the wheel (scroll down -> arc moves right);
        -- Settings > "Reverse weapon selector scroll" puts it back
        local t = G == 1 and 0 or RingDelta(WS.Pos, gi, G) * (WS_Reverse:GetBool() and 1 or -1)
        local depth = math.abs(t)
        if depth <= VISIBLE then
            local edge = depth > 1 and math.Clamp((VISIBLE - depth) / (VISIBLE - 1), 0, 1) or 1

            -- front weapon: the selected one (animated flip), else the equipped one, else the first
            local items = grp.items
            local s
            if gi == selGroup then
                s = WS.StackPos
            else
                s = 0
                for p, idx in ipairs(items) do
                    if idx == activeIdx then s = p - 1 end
                end
            end

            local nextE
            if gi == selGroup and G > 1 then
                nextE = list[groups[Wrap(gi + 1, G)].items[1]]
            end
            cards[#cards + 1] = {
                items = items,
                s = s,
                nextE = nextE,
                g = CardGeo(t, cx, baseY, R, fade * edge, appear)
            }
        end
    end
    table.sort(cards, function(a, b) return math.abs(a.g.t) > math.abs(b.g.t) end)


    -- arc line (behind the cards)
    if G > 1 then
        draw.NoTexture()
        local segs = 40
        local lineY = (1 - appear) * H * 0.04
        local px, py
        for i = 0, segs do
            local t = -LINE_SPAN + (2 * LINE_SPAN) * i / segs
            local x, y = ArcPoint(t, cx, baseY, R)
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
    for _, c in ipairs(cards) do
        DrawSlot(c.g, list, c.items, c.s, activeWep, c.nextE)
    end

    -- position counter under the arc
    Text(WS.Index .. " / " .. n, "ChudWS_Tiny", cx, baseY + U(12), C.dim, 200 * fade, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
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
    WS.Groups, WS.GroupOf = BuildGroups(list)

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
    else
        -- step one weapon; the arc only moves when that leaves the slot's stack
        local dir = key == "invnext" and 1 or -1
        local newIdx = Wrap(WS.Index + dir, n)
        if WS.GroupOf[newIdx] ~= WS.GroupOf[WS.Index] then WS.Target = WS.Target + dir end
        WS.Index = newIdx
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

-- Settings > "Classic weapon selector": 1 = the old card selector (cl_weapon_selector_classic.lua)
local classicVar = CreateClientConVar("hg_weaponselector_classic", "0", true, false, "Use the old card weapon selector instead of the arc", 0, 1)
local function Classic()
    local c = hg.WeaponSelectorClassic
    return classicVar:GetBool() and c and c.WeaponSelectorDraw and c or nil
end

hook.Add("PlayerBindPress", "WeaponSelector_PlayerBindPress", function(ply, key, pressed)
    local c = Classic()
    if c then return c.ChangeSelectionWep(ply, key) end
    return WS.ChangeSelectionWep(ply, key)
end)
hook.Add("HUDPaint", "WeaponSelector_Draw", function()
    local c = Classic()
    if c then
        WS.Show, WS.Open = 0, false
        return c.WeaponSelectorDraw(LocalPlayer())
    end
    WS.WeaponSelectorDraw(LocalPlayer())
end)
hook.Add("StartCommand", "WeaponSelector_StartCommand", function(ply, cmd)
    local c = Classic()
    if c then return c.SetActuallyWeapon(ply, cmd) end
    return WS.SetActuallyWeapon(ply, cmd)
end)

hook.Add("HUDShouldDraw", "WeaponSelector_HUDShouldDraw", function(name)
    if name == "CHudWeaponSelection" then return false end
end)
