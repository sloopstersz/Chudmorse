--;; ===================================
--;; Chudmorse map vote menu (client) - spotlight + live board layout
--;; F3 hides/shows it, 1-8 votes, stars rate the current map.
--;; ===================================
zb = zb or {}

local MV = {
    data = nil,          -- payload from ZB_RockTheVote_start
    voters = {},         -- [option] = {entindex, ...}
    players = 0,
    myVote = nil,
    result = nil,        -- {opt, map}
    rating = {avg = 0, count = 0, mine = 0, rated = false},
    frame = nil,
    hidden = false,
}

local C = {
    bg        = Color(12, 12, 14, 242),
    header    = Color(0, 0, 0, 210),
    red       = Color(200, 30, 36),
    redDark   = Color(70, 12, 15, 235),
    card      = Color(30, 30, 33, 230),
    cardHover = Color(46, 46, 51, 240),
    cardLow   = Color(20, 20, 22, 230),
    badge     = Color(8, 8, 9, 235),
    edge      = Color(120, 120, 126),
    text      = Color(236, 236, 236),
    dim       = Color(150, 150, 154),
    faint     = Color(255, 255, 255, 24),
    black     = Color(0, 0, 0, 220),
    silver    = Color(215, 215, 220),
    gold      = Color(235, 235, 240),   -- lit stars: bright silver
    starOff   = Color(70, 70, 75),
    rateBg    = Color(22, 22, 25, 235),
}

local OPTION_SLOT = {extend = 6, reroll = 7, random = 8}
local SLOT_OPTION = {[6] = "extend", [7] = "reroll", [8] = "random"}
local OPTION_COLOR = {extend = C.edge, reroll = C.edge, random = C.edge}

local gradUp = Material("gui/gradient_up")
local gradDown = Material("gui/gradient_down")

local function U(n)
    return math.floor(n * ScrH() / 1080 + 0.5)
end

local function CreateFonts()
    local f = "Verily Serif Mono"
    surface.CreateFont("ChudMV_Label", {font = f, size = U(14), weight = 800})
    surface.CreateFont("ChudMV_Title", {font = f, size = U(22), weight = 500})
    surface.CreateFont("ChudMV_Timer", {font = f, size = U(40), weight = 600})
    surface.CreateFont("ChudMV_Tiny",  {font = f, size = U(11), weight = 600})
    surface.CreateFont("ChudMV_Small", {font = f, size = U(14), weight = 400})
    surface.CreateFont("ChudMV_Name",  {font = f, size = U(19), weight = 700})
    surface.CreateFont("ChudMV_Pct",   {font = f, size = U(25), weight = 800})
    surface.CreateFont("ChudMV_Num",   {font = f, size = U(14), weight = 800})
    surface.CreateFont("ChudMV_Big",   {font = f, size = U(36), weight = 800})
    surface.CreateFont("ChudMV_Spot",  {font = f, size = U(32), weight = 800})
    surface.CreateFont("ChudMV_Huge",  {font = f, size = U(46), weight = 800})
end
hook.Add("OnScreenSizeChanged", "ChudMV_Fonts", function()
    CreateFonts()
    if IsValid(MV.frame) then zb.BuildMapVote() end
end)
CreateFonts()

--;; ---------- helpers ----------
local thumbs = {}
local function Thumb(map)
    if not map or map == "" then return nil end
    if thumbs[map] ~= nil then return thumbs[map] or nil end
    for _, path in ipairs({"maps/thumb/" .. map .. ".png", "maps/" .. map .. ".png"}) do
        local mat = Material(path, "smooth")
        if not mat:IsError() then
            thumbs[map] = mat
            return mat
        end
    end
    thumbs[map] = false
    return nil
end

local function Prefix(map)
    local p = map:match("^([^_]+)_")
    return p and p:upper() or nil
end

local function PrettyName(map)
    if not map or map == "" then return "?" end
    local parts = string.Explode("_", map)
    if #parts > 1 then table.remove(parts, 1) end
    for i, p in ipairs(parts) do
        parts[i] = string.upper(string.Left(p, 1)) .. string.sub(p, 2)
    end
    return table.concat(parts, " ")
end

local function Fit(text, font, maxw)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxw then return text end
    while #text > 1 and surface.GetTextSize(text .. "...") > maxw do
        text = text:sub(1, -2)
    end
    return text .. "..."
end

local function DrawStar(cx, cy, r, col, rot)
    local pts = {}
    for i = 0, 9 do
        local a = math.rad(-90 + (rot or 0) + i * 36)
        local rr = (i % 2 == 0) and r or r * 0.45
        pts[i + 1] = {x = cx + math.cos(a) * rr, y = cy + math.sin(a) * rr}
    end
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly({pts[2], pts[4], pts[6], pts[8], pts[10]})
    for i = 1, 9, 2 do
        surface.DrawPoly({pts[i == 1 and 10 or i - 1], pts[i], pts[i + 1]})
    end
end

local function Outline(x, y, w, h, col, t)
    surface.SetDrawColor(col)
    surface.DrawOutlinedRect(x, y, w, h, t or 1)
end

local function TextShadow(text, font, x, y, col, ax, ay)
    draw.SimpleText(text, font, x + 1, y + 2, C.black, ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

--;; ---------- juice: springs, particles, shake ----------
-- Damped spring on obj.s toward target. Kick obj.sv for a bounce.
local function Spring(obj, target, k, damp)
    local dt = math.min(FrameTime(), 1 / 30)
    obj.s = obj.s or 1
    obj.sv = ((obj.sv or 0) + (target - obj.s) * (k or 300) * dt) * math.max(0, 1 - (damp or 16) * dt)
    obj.s = obj.s + obj.sv * dt
    return obj.s
end

-- Draws with a scale around (x, y) in panel space; panel paints are offset in screen space.
local function WithScale(panel, x, y, scale, fn)
    if math.abs(scale - 1) < 0.005 then fn() return end
    local sx, sy = panel:LocalToScreen(x, y)
    local m = Matrix()
    m:Translate(Vector(sx, sy, 0))
    m:Scale(Vector(scale, scale, 1))
    m:Translate(Vector(-sx, -sy, 0))
    cam.PushModelMatrix(m, true)
    fn()
    cam.PopModelMatrix()
end

local particles = {}

-- Converts a point inside any child panel to frame space (particles live there).
local function ToFrame(panel, x, y)
    if not IsValid(MV.frame) then return x, y end
    return MV.frame:ScreenToLocal(panel:LocalToScreen(x, y))
end

local function Emit(x, y, n, o)
    for _ = 1, n do
        if #particles > 500 then return end
        local a = o.angle and (o.angle + math.Rand(-o.spread, o.spread)) or math.Rand(0, math.pi * 2)
        local sp = math.Rand(o.speed[1], o.speed[2])
        local col = istable(o.col) and o.col[math.random(#o.col)] or o.col
        table.insert(particles, {
            x = x + math.Rand(-(o.jitter or 0), o.jitter or 0),
            y = y + math.Rand(-(o.jitter or 0), o.jitter or 0),
            vx = math.cos(a) * sp, vy = math.sin(a) * sp - (o.up or 0),
            g = o.gravity or 500, drag = o.drag or 1.5,
            born = CurTime(), life = math.Rand(o.life[1], o.life[2]),
            size = math.Rand(o.size[1], o.size[2]),
            rot = math.Rand(0, 360), vr = math.Rand(-500, 500),
            col = col, kind = o.kind or "dot",
        })
    end
end

local function DrawParticles()
    local dt = math.min(FrameTime(), 1 / 30)
    local now = CurTime()
    local old = DisableClipping(true)
    for i = #particles, 1, -1 do
        local p = particles[i]
        local t = (now - p.born) / p.life
        if t >= 1 then
            table.remove(particles, i)
        else
            p.vx = p.vx * math.max(0, 1 - p.drag * dt)
            p.vy = (p.vy + p.g * dt) * math.max(0, 1 - p.drag * dt)
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            p.rot = p.rot + p.vr * dt
            local a = 255 * (1 - t * t)
            local col = Color(p.col.r, p.col.g, p.col.b, a)
            local size = p.size * (1 - t * 0.6)
            if p.kind == "star" then
                DrawStar(p.x, p.y, size, col, p.rot)
            elseif p.kind == "shard" then
                local r = math.rad(p.rot)
                local function pt(px, py)
                    return {x = p.x + (px * math.cos(r) - py * math.sin(r)) * size, y = p.y + (px * math.sin(r) + py * math.cos(r)) * size}
                end
                draw.NoTexture()
                surface.SetDrawColor(col)
                surface.DrawPoly({pt(0, -1), pt(0.8, 0.7), pt(-0.6, 0.5)})
            else
                surface.SetDrawColor(col)
                surface.DrawRect(p.x - size / 2, p.y - size / 2, size, size)
            end
        end
    end
    DisableClipping(old)
end

local function Shake(mag, dur)
    MV.shake = {t = CurTime(), mag = mag, dur = dur}
end

local function Count(opt)
    local v = opt and MV.voters[opt]
    return v and #v or 0
end

local function TotalVotes()
    local n = 0
    for _, v in pairs(MV.voters) do n = n + #v end
    return n
end

local function TopCount()
    local top = 0
    for _, v in pairs(MV.voters) do top = math.max(top, #v) end
    return top
end

local function Offered(opt)
    local d = MV.data
    if not d or not opt then return false end
    if OPTION_SLOT[opt] then return table.HasValue(d.options or {}, opt) end
    return table.HasValue(d.maps or {}, opt)
end

local function IsOut(opt)
    local d = MV.data
    return d and d.phase == 2 and d.runoff and opt ~= d.runoff[1] and opt ~= d.runoff[2]
end

local function Votable(opt)
    return MV.data and not MV.result and Offered(opt) and not IsOut(opt)
end

local function SlotOption(i)
    if SLOT_OPTION[i] then return SLOT_OPTION[i] end
    return MV.data and MV.data.maps and MV.data.maps[i]
end

local function OptionLabel(opt)
    if opt == "extend" then return "Extend map" end
    if opt == "reroll" then return "None of these" end
    if opt == "random" then return "Random map" end
    return PrettyName(opt)
end

local voteCD = 0
local function CastVote(opt)
    if not Votable(opt) or voteCD > CurTime() or MV.myVote == opt then return end
    voteCD = CurTime() + 0.4
    MV.myVote = opt
    MV.focus = opt
    net.Start("ZB_RockTheVote_vote")
        net.WriteString(opt)
    net.SendToServer()
    surface.PlaySound("garrysmod/ui_click.wav")
    return true
end

-- Click feedback for a card: squash-and-bounce, a ripple and red sparks.
local function PunchCard(card, cx, cy)
    if not IsValid(card) then return end
    local w, h = card:GetSize()
    cx, cy = cx or w / 2, cy or h / 2
    card.bulge = card.bulge or {s = 1, sv = 0}
    card.bulge.sv = card.bulge.sv - 2.2
    card.ripples = card.ripples or {}
    table.insert(card.ripples, {x = cx, y = cy, t = CurTime()})
    local fx, fy = ToFrame(card, cx, cy)
    local accent = card.opt and OPTION_COLOR[card.opt] or C.red
    Emit(fx, fy, 14, {speed = {120, 380}, life = {0.35, 0.7}, size = {U(2), U(5)}, gravity = 700, up = 120, col = {color_white, C.silver, C.edge}})
end

local function PaintRipples(s, w, h, accent)
    if not s.ripples then return end
    for i = #s.ripples, 1, -1 do
        local r = s.ripples[i]
        local t = (CurTime() - r.t) / 0.5
        if t >= 1 then
            table.remove(s.ripples, i)
        else
            local rad = (1 - (1 - t) ^ 3) * w * 0.9
            local a = 200 * (1 - t)
            surface.DrawCircle(r.x, r.y, rad, accent.r, accent.g, accent.b, a)
            surface.DrawCircle(r.x, r.y, rad + 1, accent.r, accent.g, accent.b, a * 0.6)
            surface.DrawCircle(r.x, r.y, rad * 0.6, 255, 255, 255, a * 0.35)
        end
    end
end

-- Percentage that pops whenever its vote count changes.
local function PaintPct(s, text, x, y, ax)
    local count = s.lastCount
    if s.popCount ~= count then
        if s.popCount ~= nil then s.pop = {s = 1, sv = 9} end
        s.popCount = count
    end
    s.pop = s.pop or {s = 1, sv = 0}
    local sc = Spring(s.pop, 1, 320, 14)
    WithScale(s, x, y, sc, function()
        TextShadow(text, "ChudMV_Pct", x, y, C.text, ax, TEXT_ALIGN_CENTER)
    end)
end

--;; Shows who voted for a card as small avatars.
local function SyncAvatars(card, opt)
    local list = MV.voters[opt] or {}
    local sig = table.concat(list, ",")
    if card.avatarSig == sig then return end
    card.avatarSig = sig

    for _, a in ipairs(card.avatars or {}) do
        if IsValid(a) then a:Remove() end
    end
    card.avatars = {}
    card.avatarExtra = 0

    local shown = 0
    for _, idx in ipairs(list) do
        local ply = Entity(idx)
        if IsValid(ply) and ply:IsPlayer() then
            if shown >= card.maxAvatars then
                card.avatarExtra = card.avatarExtra + 1
            else
                local s = card.avatarSize
                local a = vgui.Create("AvatarImage", card)
                a:SetSize(s, s)
                a:SetPos(card.avatarX + shown * (s + U(6)), card.avatarY)
                a:SetPlayer(ply, 32)
                a:SetMouseInputEnabled(false)
                table.insert(card.avatars, a)
                shown = shown + 1
            end
        end
    end
end

--;; ---------- shared drawing for the board layout ----------
local function DrawCover(mat, x, y, w, h, zoom, alpha)
    zoom = zoom or 1
    local us = 1 / zoom
    local vs = math.min(1, h / w) / zoom
    surface.SetDrawColor(255, 255, 255, alpha or 255)
    surface.SetMaterial(mat)
    surface.DrawTexturedRectUV(x, y, w, h, 0.5 - us / 2, 0.5 - vs / 2, 0.5 + us / 2, 0.5 + vs / 2)
end

local function NumberBox(num, x, y, s)
    surface.SetDrawColor(C.badge)
    surface.DrawRect(x, y, s, s)
    Outline(x, y, s, s, Color(255, 255, 255, 40))
    draw.SimpleText(tostring(num), "ChudMV_Num", x + s / 2, y + s / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function OptionGlyph(opt, x, y, s, big)
    surface.SetDrawColor(18, 18, 20, 255)
    surface.DrawRect(x, y, s, s)
    Outline(x, y, s, s, Color(255, 255, 255, 30))
    local font = big and "ChudMV_Huge" or "ChudMV_Name"
    if opt == "extend" then
        draw.SimpleText("+" .. (MV.data and MV.data.extendRounds or 8), font, x + s / 2, y + s / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    elseif opt == "reroll" then
        draw.SimpleText("?", font, x + s / 2, y + s / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        local d = math.floor(s * 0.5)
        local dx, dy = x + (s - d) / 2, y + (s - d) / 2
        draw.RoundedBox(math.max(2, d / 8), dx, dy, d, d, C.silver)
        local pip = math.max(2, math.floor(d * 0.15))
        for _, p in ipairs({{0.27, 0.27}, {0.73, 0.27}, {0.5, 0.5}, {0.27, 0.73}, {0.73, 0.73}}) do
            draw.RoundedBox(pip / 2, dx + d * p[1] - pip / 2, dy + d * p[2] - pip / 2, pip, pip, C.badge)
        end
    end
end

local function RatingOf(map)
    local r = MV.data and MV.data.ratings and MV.data.ratings[map]
    return r and r[1] or 0, r and r[2] or 0
end

local function RatingText(map)
    local avg, n = RatingOf(map)
    if n == 0 then return "NEW" end
    return string.format("%.1f/10  (%d)", avg, n)
end

local function OptionDesc(opt)
    local d = MV.data
    if opt == "extend" then
        if not Offered(opt) then return "Extend limit reached" end
        return "Stay on " .. PrettyName(d.current) .. " for " .. (d.extendRounds or 8) .. " more rounds"
    elseif opt == "reroll" then
        if not Offered(opt) then return "Already rerolled once" end
        return "Throw these out and get new maps"
    end
    return "Any map on the server"
end

local function LeaderOpt()
    local best, bestN = nil, 0
    for opt, list in pairs(MV.voters) do
        if #list > bestN and Offered(opt) then best, bestN = opt, #list end
    end
    return best
end

--;; ---------- board rows ----------
local function PaintRow(s, w, h)
    local opt = s.curOpt
    if not opt then
        surface.SetDrawColor(C.cardLow)
        surface.DrawRect(0, 0, w, h)
        return true
    end

    local hov = s:IsHovered() and Votable(opt)
    s.hf = Lerp(FrameTime() * 12, s.hf or 0, hov and 1 or 0)
    local bg = C.card
    surface.SetDrawColor(Lerp(s.hf, bg.r, C.cardHover.r), Lerp(s.hf, bg.g, C.cardHover.g), Lerp(s.hf, bg.b, C.cardHover.b), bg.a)
    surface.DrawRect(0, 0, w, h)

    -- the row itself is the vote bar
    local count, total = Count(opt), TotalVotes()
    local leader = count > 0 and count == TopCount()
    s.barFrac = Lerp(FrameTime() * 7, s.barFrac or 0, total > 0 and count / total or 0)
    surface.SetDrawColor(255, 255, 255, leader and 34 or 18)
    surface.DrawRect(0, 0, w * s.barFrac, h)
    if s.barFrac > 0.002 then
        surface.SetDrawColor(255, 255, 255, leader and 120 or 60)
        surface.DrawRect(w * s.barFrac - 1, 0, 2, h)
    end

    -- left edge: red only for your own vote
    surface.SetDrawColor(MV.myVote == opt and C.red or Color(255, 255, 255, 25))
    surface.DrawRect(0, 0, U(3), h)

    local bs = U(22)
    NumberBox(s.slot, U(12), h / 2 - bs / 2, bs)

    local ix = U(12) + bs + U(10)
    local iw, ih = math.floor(h * 1.5), h - U(12)
    local isMap = not OPTION_SLOT[opt]
    if isMap then
        local mat = Thumb(opt)
        if mat then
            DrawCover(mat, ix, U(6), iw, ih, 1 + 0.15 * s.hf, 230)
        else
            surface.SetDrawColor(36, 36, 40, 255)
            surface.DrawRect(ix, U(6), iw, ih)
            draw.SimpleText(Prefix(opt) or "?", "ChudMV_Num", ix + iw / 2, U(6) + ih / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    else
        iw = ih
        OptionGlyph(opt, ix, U(6), ih)
    end

    local tx = ix + iw + U(12)
    local pctX = w - U(14)
    local nameW = w - tx - U(240)
    draw.SimpleText(Fit(OptionLabel(opt), "ChudMV_Name", nameW), "ChudMV_Name", tx, h * 0.36, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if isMap then
        local sub = (Prefix(opt) or "MAP")
        draw.SimpleText(sub, "ChudMV_Tiny", tx, h * 0.72, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("ChudMV_Tiny")
        local sw = surface.GetTextSize(sub)
        local _, n = RatingOf(opt)
        draw.SimpleText("·  " .. RatingText(opt), "ChudMV_Tiny", tx + sw + U(8), h * 0.72, n == 0 and C.text or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText(Fit(OptionDesc(opt), "ChudMV_Tiny", nameW), "ChudMV_Tiny", tx, h * 0.72, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local pct = total > 0 and math.Round(count / total * 100) or 0
    s.lastCount = count
    PaintPct(s, pct .. "%", pctX, h / 2, TEXT_ALIGN_RIGHT)
    draw.SimpleText(count == 1 and "1 vote" or (count .. " votes"), "ChudMV_Tiny", pctX - U(70), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    PaintRipples(s, w, h, C.silver)

    if hov then Outline(0, 0, w, h, Color(255, 255, 255, 70 * s.hf)) end
    if MV.result and MV.result.opt == opt then
        Outline(0, 0, w, h, Color(255, 255, 255, 150 + math.sin(CurTime() * 6) * 100), 2)
    end
    if IsOut(opt) or not Offered(opt) then
        surface.SetDrawColor(6, 6, 7, 200)
        surface.DrawRect(0, 0, w, h)
        if IsOut(opt) then
            draw.SimpleText("OUT", "ChudMV_Num", w - U(14), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    return true
end

local function RowThink(s)
    local opt = s.fixedOpt or SlotOption(s.slot)
    s.curOpt = opt
    if opt then SyncAvatars(s, opt) end

    local hov = s:IsHovered() and Votable(opt)
    if hov then MV.focus, MV.focusT = opt, CurTime() end
    s.bulge = s.bulge or {s = 1, sv = 0}
    if hov and not s.hovWas then
        s.bulge.sv = s.bulge.sv + 1.4
        surface.PlaySound("garrysmod/ui_hover.wav")
    end
    s.hovWas = hov

    local b = Spring(s.bulge, hov and 1.06 or 1, 300, 14)
    s.curY = Lerp(math.min(FrameTime() * 9, 1), s.curY or s.targetY, s.targetY)
    s:SetPos(s.baseX + (b - 1) * U(160), math.floor(s.curY + 0.5))
    s:SetCursor(Votable(opt) and "hand" or "arrow")
end

--;; ---------- spotlight (left side) with reviews ----------
local function SpotOpt()
    if MV.result then return MV.result.opt end
    if MV.focus and (Offered(MV.focus) or MV.focus == MV.myVote) then return MV.focus end
    return MV.myVote or LeaderOpt() or (MV.data.maps and MV.data.maps[1])
end

local wrapCache = {}
local function Wrap(text, font, maxw)
    local key = font .. maxw .. text
    if wrapCache[key] then return wrapCache[key] end
    surface.SetFont(font)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if surface.GetTextSize(try) <= maxw then
            line = try
        else
            if line ~= "" then table.insert(lines, line) end
            while #word > 1 and surface.GetTextSize(word) > maxw do
                local cut = #word
                while cut > 1 and surface.GetTextSize(word:sub(1, cut)) > maxw do cut = cut - 1 end
                table.insert(lines, word:sub(1, cut))
                word = word:sub(cut + 1)
            end
            line = word
        end
    end
    if line ~= "" then table.insert(lines, line) end
    wrapCache[key] = lines
    return lines
end

local function ScoreShade(score)
    local k = math.Clamp((score - 1) / 9, 0, 1)
    return Color(Lerp(k, 45, 225), Lerp(k, 45, 225), Lerp(k, 50, 230))
end

local function ReviewsFor(opt)
    local d = MV.data
    if not d or not d.reviews then return nil end
    if opt == "extend" then return d.reviews[d.current] or {} end
    if OPTION_SLOT[opt] then return nil end
    return d.reviews[opt] or {}
end

local function DrawReview(rv, x, y, w)
    local chip = U(38)
    local col = ScoreShade(rv.s or 0)
    surface.SetDrawColor(C.badge)
    surface.DrawRect(x, y, chip, chip)
    draw.SimpleText(tostring(rv.s or "?"), "ChudMV_Name", x + chip / 2, y + chip / 2 - U(3), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 20)
    surface.DrawRect(x, y + chip - U(3), chip, U(3))
    surface.SetDrawColor(col)
    surface.DrawRect(x, y + chip - U(3), chip * (rv.s or 0) / 10, U(3))

    local tx, tw = x + chip + U(10), w - chip - U(10)
    draw.SimpleText(Fit(rv.n ~= "" and rv.n or "Someone", "ChudMV_Tiny", tw), "ChudMV_Tiny", tx, y + U(6), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    local lines = Wrap(rv.r or "", "ChudMV_Small", tw)
    local ly = y + U(16)
    for _, line in ipairs(lines) do
        draw.SimpleText(line, "ChudMV_Small", tx, ly, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        ly = ly + U(17)
    end
    if istable(rv.g) and #rv.g > 0 then
        local tagx = tx
        surface.SetFont("ChudMV_Tiny")
        for _, tag in ipairs(rv.g) do
            local label = "#" .. tag
            local tw2 = surface.GetTextSize(label) + U(10)
            if tagx + tw2 > tx + tw then break end
            surface.SetDrawColor(255, 255, 255, 14)
            surface.DrawRect(tagx, ly + U(2), tw2, U(16))
            draw.SimpleText(label, "ChudMV_Tiny", tagx + tw2 / 2, ly + U(10), C.silver, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            tagx = tagx + tw2 + U(4)
        end
        ly = ly + U(20)
    end
    return math.max(chip, ly - y) + U(12)
end

local function DrawSpot(panel, opt, x, y, w, h)
    local imgH = math.floor(math.min(h * 0.36, U(230)))
    local isMap = not OPTION_SLOT[opt]
    local imgMap = isMap and opt or (opt == "extend" and MV.data.current) or nil

    surface.SetDrawColor(C.cardLow)
    surface.DrawRect(x, y, w, h)

    local mat = imgMap and Thumb(imgMap)
    if mat then
        DrawCover(mat, x, y, w, imgH, 1.06 + math.sin(CurTime() * 0.4) * 0.04, 255)
    elseif isMap then
        surface.SetDrawColor(30, 30, 33, 255)
        surface.DrawRect(x, y, w, imgH)
        draw.SimpleText(Prefix(opt) or "?", "ChudMV_Huge", x + w / 2, y + imgH / 2, Color(255, 255, 255, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        surface.SetDrawColor(20, 20, 22, 255)
        surface.DrawRect(x, y, w, imgH)
    end
    if not isMap then
        local s = math.floor(imgH * 0.45)
        OptionGlyph(opt, x + w / 2 - s / 2, y + imgH / 2 - s / 2 - U(10), s, true)
    end
    surface.SetDrawColor(0, 0, 0, 235)
    surface.SetMaterial(gradUp)
    surface.DrawTexturedRect(x, y + imgH * 0.35, w, imgH * 0.65 + 1)

    local tag
    if MV.result and MV.result.opt == opt then tag = opt == "extend" and "STAYING" or "NEXT MAP"
    elseif MV.myVote == opt then tag = "YOUR VOTE"
    elseif Count(opt) > 0 and Count(opt) == TopCount() then tag = "LEADING"
    end
    if tag then
        surface.SetFont("ChudMV_Tiny")
        local tw = surface.GetTextSize(tag) + U(14)
        surface.SetDrawColor(MV.myVote == opt and not MV.result and C.red or C.badge)
        surface.DrawRect(x + U(12), y + U(12), tw, U(22))
        draw.SimpleText(tag, "ChudMV_Tiny", x + U(12) + tw / 2, y + U(23), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local count, total = Count(opt), TotalVotes()
    local pct = total > 0 and math.Round(count / total * 100) or 0
    draw.SimpleText(pct .. "%", "ChudMV_Pct", x + w - U(14), y + U(23), C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local sub = isMap and (Prefix(opt) or "MAP") or "OPTION"
    draw.SimpleText(sub, "ChudMV_Tiny", x + U(16), y + imgH - U(46), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    TextShadow(Fit(OptionLabel(opt), "ChudMV_Spot", w - U(32)), "ChudMV_Spot", x + U(16), y + imgH - U(20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- stat line: score + votes
    local sy = y + imgH + U(24)
    if imgMap then
        local avg, n = RatingOf(imgMap)
        if n > 0 then
            draw.SimpleText(string.format("%.1f", avg), "ChudMV_Pct", x + U(16), sy, ScoreShade(avg), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetFont("ChudMV_Pct")
            local aw = surface.GetTextSize(string.format("%.1f", avg))
            draw.SimpleText("/10  ·  " .. n .. (n == 1 and " rating" or " ratings"), "ChudMV_Small", x + U(18) + aw, sy + U(3), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("NEW  ·  not rated yet", "ChudMV_Small", x + U(16), sy, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    else
        draw.SimpleText(Fit(OptionDesc(opt), "ChudMV_Small", w - U(120)), "ChudMV_Small", x + U(16), sy, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    draw.SimpleText(count == 1 and "1 vote" or (count .. " votes"), "ChudMV_Small", x + w - U(16), sy, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- most used tags
    local tagMap = imgMap
    local tc = tagMap and MV.data.tagCounts and MV.data.tagCounts[tagMap]
    if tc and #tc > 0 then
        local tagx = x + U(16)
        for _, pair in ipairs(tc) do
            local label = "#" .. pair[1] .. "  " .. pair[2]
            surface.SetFont("ChudMV_Tiny")
            local tw2 = surface.GetTextSize(label) + U(14)
            if tagx + tw2 > x + w - U(16) then break end
            surface.SetDrawColor(255, 255, 255, 22)
            surface.DrawRect(tagx, sy + U(18), tw2, U(20))
            Outline(tagx, sy + U(18), tw2, U(20), Color(255, 255, 255, 30))
            draw.SimpleText(label, "ChudMV_Tiny", tagx + tw2 / 2, sy + U(28), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            tagx = tagx + tw2 + U(6)
        end
        sy = sy + U(26)
    end

    -- reviews
    local list = ReviewsFor(opt)
    local ly = sy + U(28)
    surface.SetDrawColor(255, 255, 255, 18)
    surface.DrawRect(x + U(16), ly, w - U(32), 1)
    if not list then
        draw.SimpleText("Press " .. (OPTION_SLOT[opt] or "?") .. " to vote for this", "ChudMV_Small", x + U(16), ly + U(24), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return
    end

    local label = opt == "extend" and ("REVIEWS OF " .. string.upper(PrettyName(MV.data.current))) or "REVIEWS"
    draw.SimpleText(Fit(label, "ChudMV_Tiny", w - U(80)), "ChudMV_Tiny", x + U(16), ly + U(16), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(#list .. (#list == 1 and " review" or " reviews"), "ChudMV_Tiny", x + w - U(16), ly + U(16), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local top = ly + U(32)
    local areaH = y + h - U(10) - top
    if #list == 0 then
        draw.SimpleText("No written reviews yet.", "ChudMV_Small", x + U(16), top + U(10), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return
    end

    -- scrollable list (mouse wheel over the left panel)
    local sx, sy2 = panel:LocalToScreen(math.max(0, x), top)
    local ex, ey = panel:LocalToScreen(math.min(panel:GetWide(), x + w), top + areaH)
    render.SetScissorRect(sx, sy2, ex, ey, true)
    local cy = top - (MV.reviewScroll or 0)
    for _, rv in ipairs(list) do
        cy = cy + DrawReview(rv, x + U(16), cy, w - U(32))
    end
    render.SetScissorRect(0, 0, 0, 0, false)

    local contentH = cy + (MV.reviewScroll or 0) - top
    MV.reviewMax = math.max(0, contentH - areaH)
    if MV.reviewMax > 0 then
        local barH = math.max(U(20), areaH * areaH / contentH)
        local by = top + (areaH - barH) * ((MV.reviewScroll or 0) / MV.reviewMax)
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawRect(x + w - U(6), by, U(3), barH)
        if (MV.reviewScroll or 0) < MV.reviewMax - 2 then
            surface.SetDrawColor(C.cardLow.r, C.cardLow.g, C.cardLow.b, 255)
            surface.SetMaterial(gradUp)
            surface.DrawTexturedRect(x, top + areaH - U(30), w - U(8), U(30))
        end
    end
end

local function PaintSpotlight(s, w, h)
    local opt = SpotOpt()
    if not opt then return end
    if opt ~= MV.spotOpt then
        MV.spotPrev, MV.spotOpt, MV.spotT = MV.spotOpt, opt, CurTime()
        MV.reviewScroll, MV.reviewScrollTarget = 0, 0
    end
    MV.reviewScrollTarget = math.Clamp(MV.reviewScrollTarget or 0, 0, MV.reviewMax or 0)
    MV.reviewScroll = Lerp(math.min(FrameTime() * 14, 1), MV.reviewScroll or 0, MV.reviewScrollTarget)

    local t = math.Clamp((CurTime() - (MV.spotT or 0)) / 0.22, 0, 1)
    local e = 1 - (1 - t) ^ 3
    if MV.spotPrev and t < 1 then
        surface.SetAlphaMultiplier(1 - e)
        DrawSpot(s, MV.spotPrev, -U(30) * e, 0, w, h)
    end
    surface.SetAlphaMultiplier(e)
    DrawSpot(s, MV.spotOpt, U(30) * (1 - e), 0, w, h)
    surface.SetAlphaMultiplier(1)
    return true
end

--;; ---------- rate + review (slider, 1-10) ----------
local SPARK_COLS = {color_white, color_white, C.silver, C.silver, Color(150, 150, 156), C.red}

local function MakeBarCrack()
    -- a jagged line running along the bar, plus a few splits across it
    local main, x = {}, 0
    while x < 1 do
        table.insert(main, {x = x, y = math.Rand(-0.9, 0.9)})
        x = x + math.Rand(0.04, 0.09)
    end
    table.insert(main, {x = 1, y = math.Rand(-0.6, 0.6)})
    local splits = {}
    for _ = 1, 4 do
        local sx = math.Rand(0.08, 0.92)
        table.insert(splits, {{x = sx, y = -1.8}, {x = sx + math.Rand(-0.02, 0.02), y = math.Rand(-0.3, 0.3)}, {x = sx + math.Rand(-0.03, 0.03), y = 1.8}})
    end
    return {main = main, splits = splits, t = CurTime()}
end

local function SliderX(s, v)
    local pad = s.trackPad
    return pad + (v - 1) / 9 * (s:GetWide() - pad * 2)
end

local function SliderValue(s, x)
    local pad = s.trackPad
    return math.Clamp(math.Round((x - pad) / (s:GetWide() - pad * 2) * 9) + 1, 1, 10)
end

local function KnobScreen(s, v)
    return ToFrame(s, SliderX(s, v), s:GetTall() / 2)
end

local function RateFX(score)
    local s = MV.slider
    if not IsValid(s) then return end
    s.knob = s.knob or {s = 1, sv = 0}
    s.knob.sv = s.knob.sv + 10

    if score == 1 then
        MV.crack = MakeBarCrack()
        surface.PlaySound("physics/glass/glass_cup_break1.wav")
        Shake(U(7), 0.35)
        local w, h = s:GetWide(), s:GetTall()
        for k = 1, 5 do
            local fx, fy = ToFrame(s, s.trackPad + (w - s.trackPad * 2) * (k - 0.5) / 5, h / 2)
            Emit(fx, fy, 3, {kind = "shard", speed = {50, 180}, up = 90, gravity = 1100, life = {0.6, 1.0}, size = {U(3), U(6)}, col = {Color(110, 110, 116), Color(70, 70, 75)}})
            Emit(fx, fy, 4, {speed = {20, 90}, gravity = 250, drag = 3, life = {0.4, 0.9}, size = {U(1), U(3)}, jitter = U(6), col = {Color(90, 90, 95), Color(55, 55, 60)}})
        end
        return
    end

    MV.crack = nil
    local fx, fy = KnobScreen(s, score)

    if score == 10 then
        s.boomAt = CurTime()
        surface.PlaySound("buttons/button9.wav")
        timer.Simple(0.3, function()
            if not IsValid(s) then return end
            local bx, by = KnobScreen(s, 10)
            Emit(bx, by, 46, {speed = {180, 560}, up = 80, gravity = 420, life = {0.7, 1.3}, size = {U(2), U(6)}, col = SPARK_COLS})
            Emit(bx, by, 26, {speed = {60, 260}, gravity = 180, life = {0.3, 0.7}, size = {U(1), U(3)}, col = SPARK_COLS})
            -- a shower along the whole bar
            for k = 1, 9 do
                local px, py = ToFrame(s, SliderX(s, k), s:GetTall() / 2)
                Emit(px, py, 3, {speed = {40, 200}, up = 140, gravity = 500, life = {0.5, 0.9}, size = {U(1), U(3)}, col = SPARK_COLS})
            end
            surface.PlaySound("garrysmod/balloon_pop_cute.wav")
            Shake(U(4), 0.25)
            MV.rateFlash = CurTime()
        end)
    else
        Emit(fx, fy, score >= 8 and 16 or 7, {speed = {60, 240}, up = 100, gravity = 500, life = {0.4, 0.8}, size = {U(1), U(4)}, col = SPARK_COLS})
        surface.PlaySound("garrysmod/ui_click.wav")
    end
end

local function TagMask(set)
    local mask = 0
    for i, tag in ipairs(MV.data and MV.data.tagList or {}) do
        if set[tag] then mask = mask + 2 ^ (i - 1) end
    end
    return mask
end

local function SetFromList(list)
    local set = {}
    for _, tag in ipairs(list or {}) do set[tag] = true end
    return set
end

local function SendRating(score, text, mask)
    if MV.rateCD and MV.rateCD > CurTime() then return false end
    MV.rateCD = CurTime() + 0.5
    MV.rating.mine = score
    net.Start("ZB_MapVote_Rate")
        net.WriteUInt(score, 4)
        net.WriteBool(text ~= nil)
        if text ~= nil then net.WriteString(text) end
        net.WriteBool(mask ~= nil)
        if mask ~= nil then net.WriteUInt(mask, 8) end
    net.SendToServer()
    return true
end

local function ReviewChanged()
    local entry = MV.reviewEntry
    local text = IsValid(entry) and string.Trim(entry:GetValue() or "") or ""
    local mask = TagMask(MV.tagSel or {})
    local changed = text ~= (MV.rating.myText or "") or mask ~= TagMask(SetFromList(MV.rating.myTags))
    return changed and (text ~= "" or mask ~= 0), text, mask
end

local function PaintSlider(s, w, h)
    local pad = s.trackPad
    local cy = h / 2
    local th = U(8)
    local mine = MV.rating.mine
    local v = s.dragging and s.dragVal or mine
    local cracked = not s.dragging and mine == 1 and MV.crack

    local ox, oy = 0, 0
    if cracked then
        local ct = CurTime() - MV.crack.t
        if ct < 0.35 then
            local m = U(4) * (1 - ct / 0.35)
            ox, oy = math.Rand(-m, m), math.Rand(-m, m)
        end
    end

    local old = DisableClipping(true)
    -- track
    draw.RoundedBox(th / 2, pad + ox, cy - th / 2 + oy, w - pad * 2, th, Color(255, 255, 255, cracked and 12 or 22))
    for k = 1, 10 do
        local tx = SliderX(s, k) + ox
        surface.SetDrawColor(255, 255, 255, (v > 0 and k <= v) and 0 or 50)
        surface.DrawRect(tx - 1, cy + th / 2 + U(4) + oy, 2, U(4))
    end

    -- fill
    if v > 0 then
        local fx = SliderX(s, v)
        s.fillX = Lerp(math.min(FrameTime() * 18, 1), s.fillX or pad, fx)
        local fillCol = cracked and Color(80, 80, 86) or ScoreShade(v)
        draw.RoundedBox(th / 2, pad + ox, cy - th / 2 + oy, math.max(th, s.fillX - pad), th, fillCol)
    else
        s.fillX = pad
    end

    if cracked then
        local L, W = pad + ox, w - pad * 2
        local function line(pts, col, dy)
            surface.SetDrawColor(col)
            for k = 1, #pts - 1 do
                local a, b = pts[k], pts[k + 1]
                surface.DrawLine(L + a.x * W, cy + oy + a.y * th + dy, L + b.x * W, cy + oy + b.y * th + dy)
            end
        end
        local dark = Color(6, 6, 7, 255)
        line(MV.crack.main, dark, 0) line(MV.crack.main, dark, 1)
        line(MV.crack.main, Color(C.red.r, C.red.g, C.red.b, 200), -1)
        for _, sp in ipairs(MV.crack.splits) do line(sp, dark, 0) end
    end

    -- knob
    s.knob = s.knob or {s = 1, sv = 0}
    local mx, my = s:CursorPos()
    local kx = (v > 0 and s.fillX or pad) + ox
    local nearKnob = s:IsHovered() and math.abs(mx - kx) < U(18)
    local target = s.dragging and 1.3 or (nearKnob and 1.45 or (s:IsHovered() and 1.12 or 1))
    local sc = Spring(s.knob, target, 340, 13)
    local kcol = v > 0 and (cracked and Color(110, 110, 116) or color_white) or Color(120, 120, 126)

    if s.boomAt then
        local t = (CurTime() - s.boomAt) / 0.3
        if t < 1 then
            sc = 1 + t * t * 1.8
            s.knob.s, s.knob.sv = sc, 0
            kcol = color_white
            local gr = U(11) * sc * 1.8
            draw.RoundedBox(gr, kx - gr, cy + oy - gr, gr * 2, gr * 2, Color(255, 255, 255, 40 * t))
        else
            s.boomAt = nil
            s.knob.s, s.knob.sv = 0.2, 14
        end
    end

    local r = math.floor(U(11) * sc)
    if nearKnob or s.dragging then
        local gr = r + U(5)
        draw.RoundedBox(gr, kx - gr, cy + oy - gr, gr * 2, gr * 2, Color(255, 255, 255, 30))
    end
    draw.RoundedBox(r, kx - r, cy + oy - r, r * 2, r * 2, Color(0, 0, 0, 200))
    local ri = math.max(1, r - U(2))
    draw.RoundedBox(ri, kx - ri, cy + oy - ri, ri * 2, ri * 2, kcol)

    -- bubble while dragging
    if s.dragging and v > 0 then
        local bw, bh = U(34), U(24)
        local by = cy - r - U(10) - bh
        surface.SetDrawColor(C.badge)
        surface.DrawRect(kx - bw / 2, by, bw, bh)
        Outline(kx - bw / 2, by, bw, bh, Color(255, 255, 255, 60))
        draw.SimpleText(tostring(v), "ChudMV_Num", kx, by + bh / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if v == 0 and not s:IsHovered() then
        draw.SimpleText("slide to rate  ->", "ChudMV_Tiny", pad + U(22), cy - U(14), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    DisableClipping(old)
    return true
end

local function SliderThink(s)
    if s.dragging then
        local v = SliderValue(s, (s:CursorPos()))
        if v ~= s.dragVal then
            s.dragVal = v
            s.knob = s.knob or {s = 1, sv = 0}
            s.knob.sv = s.knob.sv + 4
            MV.scorePop = {s = 1, sv = 6}
            surface.PlaySound("garrysmod/ui_hover.wav")
        end
        if not input.IsMouseDown(MOUSE_LEFT) then s:OnMouseReleased(MOUSE_LEFT) end
    end
    s:SetCursor(s.dragging and "sizewe" or "hand")
end

local function SliderPressed(s, code)
    if code ~= MOUSE_LEFT then return end
    s.dragging = true
    s:MouseCapture(true)
    s.dragVal = SliderValue(s, (s:CursorPos()))
    MV.scorePop = {s = 1, sv = 6}
    surface.PlaySound("garrysmod/ui_hover.wav")
end

local function SliderReleased(s, code)
    if code ~= MOUSE_LEFT or not s.dragging then return end
    s.dragging = false
    s:MouseCapture(false)
    local v = s.dragVal
    if v and v >= 1 and SendRating(v) then RateFX(v) end
end

local function PaintRateBox(s, w, h)
    local d = MV.data
    surface.SetDrawColor(C.rateBg)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(255, 255, 255, 25)
    surface.DrawRect(0, 0, w, 1)

    if MV.rateFlash then
        local t = (CurTime() - MV.rateFlash) / 0.6
        if t < 1 then
            surface.SetDrawColor(255, 255, 255, 60 * (1 - t))
            surface.DrawRect(0, 0, w, h)
        else
            MV.rateFlash = nil
        end
    end

    -- title row
    draw.SimpleText("RATE", "ChudMV_Tiny", U(14), U(18), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    surface.SetFont("ChudMV_Tiny")
    local lw = surface.GetTextSize("RATE")
    draw.SimpleText(Fit(PrettyName(d.current), "ChudMV_Name", w * 0.4), "ChudMV_Name", U(22) + lw, U(18), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local rated = MV.rating.rated
    local pillTxt = "+" .. (d.rateKarma or 5) .. " KARMA"
    local pw = surface.GetTextSize(pillTxt) + U(20)
    local ph = U(22)
    local px = w - U(14) - pw
    draw.RoundedBox(ph / 2, px, U(18) - ph / 2, pw, ph, rated and Color(60, 60, 64, 230) or C.edge)
    draw.RoundedBox(ph / 2 - 1, px + 1, U(18) - ph / 2 + 1, pw - 2, ph - 2, rated and Color(28, 28, 30, 230) or Color(45, 45, 50, 255))
    draw.SimpleText(pillTxt, "ChudMV_Tiny", px + pw / 2, U(18), rated and C.dim or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local avgTxt = MV.rating.count > 0 and string.format("%.1f/10 avg  ·  %d rating%s", MV.rating.avg, MV.rating.count, MV.rating.count == 1 and "" or "s") or "No ratings yet"
    draw.SimpleText(avgTxt, "ChudMV_Tiny", px - U(12), U(18), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    if MV.karmaPop then
        local t = (CurTime() - MV.karmaPop) / 1.1
        if t < 1 then
            local old = DisableClipping(true)
            local y = U(18) - U(36) * (1 - (1 - t) ^ 2)
            draw.SimpleTextOutlined(pillTxt, "ChudMV_Num", px + pw / 2, y, Color(255, 255, 255, 255 * (1 - t)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200 * (1 - t)))
            DisableClipping(old)
        else
            MV.karmaPop = nil
        end
    end

    -- big score readout to the right of the slider
    local sl = MV.slider
    local v = IsValid(sl) and sl.dragging and sl.dragVal or MV.rating.mine
    local bx = w - U(14) - s.scoreW
    local sy = IsValid(sl) and select(2, sl:GetPos()) + sl:GetTall() / 2 or U(56)
    MV.scorePop = MV.scorePop or {s = 1, sv = 0}
    local sc = Spring(MV.scorePop, 1, 320, 13)
    WithScale(s, bx + s.scoreW / 2, sy, sc, function()
        if v > 0 then
            draw.SimpleText(tostring(v), "ChudMV_Huge", bx + s.scoreW / 2 - U(8), sy, (v == 1 and MV.crack and not (IsValid(sl) and sl.dragging)) and C.dim or ScoreShade(math.max(v, 4)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("/10", "ChudMV_Tiny", bx + s.scoreW - U(6), sy + U(10), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("-", "ChudMV_Huge", bx + s.scoreW / 2, sy, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    -- character counter under the review box
    local entry = MV.reviewEntry
    if IsValid(entry) then
        local ex, ey = entry:GetPos()
        local len = utf8.len(entry:GetValue() or "") or 0
        local max = d.reviewMax or 140
        local hint
        if MV.rating.mine == 0 then
            hint = "Slide to give a score first, then tag or review it"
        elseif MV.rating.myText and MV.rating.myText ~= "" then
            hint = "Your review is posted. Post again to replace it"
        else
            hint = "Pick up to " .. (d.maxTags or 3) .. " tags and/or write a review"
        end
        local hy = ey + entry:GetTall() + U(12)
        draw.SimpleText(hint, "ChudMV_Tiny", ex, hy, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(len .. "/" .. max, "ChudMV_Tiny", ex + entry:GetWide(), hy, len >= max and C.red or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    return true
end

local function TryPostReview()
    local entry = MV.reviewEntry
    if not IsValid(entry) or MV.rating.mine == 0 then return end
    local ok, text, mask = ReviewChanged()
    if not ok then return end
    if not SendRating(MV.rating.mine, text, mask) then return end
    MV.rating.myText = text
    local tags = {}
    for i, tag in ipairs(MV.data.tagList or {}) do
        if (MV.tagSel or {})[tag] then table.insert(tags, tag) end
    end
    MV.rating.myTags = tags
    entry:KillFocus()
    surface.PlaySound("garrysmod/content_downloaded.wav")
    local btn = MV.postBtn
    if IsValid(btn) then
        btn.pop = {s = 1, sv = 8}
        local w, h = btn:GetSize()
        local fx, fy = ToFrame(btn, w / 2, h / 2)
        Emit(fx, fy, 14, {speed = {60, 260}, up = 80, gravity = 500, life = {0.4, 0.8}, size = {U(1), U(4)}, col = SPARK_COLS})
    end
end

--;; ---------- frame ----------
local function Ring(cx, cy, r, thick, frac, col)
    if frac <= 0 then return end
    draw.NoTexture()
    surface.SetDrawColor(col)
    local seg = 60
    local steps = seg * frac
    local ri = r - thick
    for i = 0, math.ceil(steps) - 1 do
        local a1 = math.rad(-90 + i / seg * 360)
        local a2 = math.rad(-90 + math.min(i + 1, steps) / seg * 360)
        surface.DrawPoly({
            {x = cx + math.cos(a1) * r,  y = cy + math.sin(a1) * r},
            {x = cx + math.cos(a2) * r,  y = cy + math.sin(a2) * r},
            {x = cx + math.cos(a2) * ri, y = cy + math.sin(a2) * ri},
            {x = cx + math.cos(a1) * ri, y = cy + math.sin(a1) * ri},
        })
    end
end

local function PaintFrame(s, w, h)
    local d = MV.data
    if not d then return end
    local L = s.leftW

    if hg and hg.DrawBlur then hg.DrawBlur(s, 4) end
    surface.SetDrawColor(C.bg)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(6, 6, 7, 245)
    surface.DrawRect(0, 0, L, h)
    surface.SetDrawColor(255, 255, 255, 18)
    surface.DrawRect(L, 0, 1, h)
    Outline(0, 0, w, h, Color(255, 255, 255, 22))

    local pad = s.pad
    local rx, rw = L + pad, w - L - pad * 2

    -- header
    local label, title
    if MV.result then
        label = "RESULT"
        if MV.result.opt == "extend" then
            title = "Staying on " .. PrettyName(d.current)
        else
            title = PrettyName(MV.result.map) .. " is next"
        end
    elseif d.phase == 2 then
        label = "RUNOFF"
        title = OptionLabel(d.runoff[1]) .. "  vs  " .. OptionLabel(d.runoff[2])
    else
        label = "NEXT MAP"
        title = "Pick where we go next"
    end
    draw.SimpleText(label, "ChudMV_Label", rx, pad + U(10), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(Fit(title, "ChudMV_Title", rw - U(110)), "ChudMV_Title", rx, pad + U(36), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local voted = TotalVotes()
    local sub = voted .. "/" .. math.max(MV.players, voted) .. " voted  ·  "
        .. (d.phase == 2 and "most votes wins" or "click or press 1-8  ·  50%+ wins, else top two face off")
    draw.SimpleText(Fit(sub, "ChudMV_Small", rw - U(110)), "ChudMV_Small", rx, pad + U(62), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- countdown ring
    local left = math.max(0, (d.endTime or 0) - CurTime())
    local secs = MV.result and 0 or math.ceil(left)
    local frac = MV.result and 0 or math.Clamp(left / math.max(d.duration or 1, 1), 0, 1)
    local urgent = secs > 0 and secs <= 5
    if secs ~= MV.lastSecs then
        if urgent and MV.lastSecs then
            MV.timerPop = {s = 1, sv = 7}
            surface.PlaySound("buttons/blip1.wav")
        end
        MV.lastSecs = secs
    end
    MV.timerPop = MV.timerPop or {s = 1, sv = 0}
    local tsc = Spring(MV.timerPop, 1, 320, 12)
    local cr = U(34)
    local cx, cy = w - pad - cr, pad + U(38)
    Ring(cx, cy, cr, U(4), 1, Color(255, 255, 255, 18))
    Ring(cx, cy, cr, U(4), frac, urgent and C.red or C.silver)
    WithScale(s, cx, cy, tsc, function()
        draw.SimpleText(tostring(secs), "ChudMV_Pct", cx, cy, urgent and C.red or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    -- divider between maps and the extra options
    local dy = s.dividerY
    surface.SetDrawColor(255, 255, 255, 20)
    surface.DrawRect(rx, dy, rw / 2 - U(20), 1)
    surface.DrawRect(rx + rw / 2 + U(20), dy, rw / 2 - U(20), 1)
    draw.SimpleText("OR", "ChudMV_Tiny", rx + rw / 2, dy, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function SortRows(f)
    local rows = f.mapRows
    local order = {}
    for _, r in ipairs(rows) do table.insert(order, r) end
    table.sort(order, function(a, b)
        local ao, bo = (a.curOpt and IsOut(a.curOpt)) and 1 or 0, (b.curOpt and IsOut(b.curOpt)) and 1 or 0
        if ao ~= bo then return ao < bo end
        local ac, bc = Count(a.curOpt), Count(b.curOpt)
        if ac ~= bc then return ac > bc end
        return a.slot < b.slot
    end)
    for i, r in ipairs(order) do
        r.targetY = f.mapTop + (i - 1) * (f.mapRowH + f.rowGap)
        r.rank = i
    end
end

local function SetHidden(hidden)
    MV.hidden = hidden
    if not IsValid(MV.frame) then return end
    MV.frame:SetVisible(not hidden)
    if not hidden then
        MV.frame:MakePopup()
        MV.frame:SetKeyboardInputEnabled(false)
    end
end

-- Hover bulge for a card: springs its size around its resting rect.
function zb.BuildMapVote()
    if IsValid(MV.frame) then MV.frame:Remove() end
    if not MV.data then return end

    local W = math.min(U(1200), ScrW() - U(40))
    local H = math.min(U(740), ScrH() - U(40))
    local pad, gap = U(20), U(6)
    local L = math.floor(W * 0.38)

    local f = vgui.Create("EditablePanel")
    f:SetSize(W, H)
    f:Center()
    f:MakePopup()
    f:SetKeyboardInputEnabled(false)
    f.pad, f.leftW = pad, L
    f.Paint = PaintFrame
    f.PaintOver = function() DrawParticles() end
    MV.frame = f
    MV.cards = {}
    MV.spotOpt, MV.spotPrev = nil, nil
    table.Empty(particles)

    f.baseX, f.baseY = f:GetPos()
    f.openT = CurTime()
    f:SetAlpha(0)
    f:AlphaTo(255, 0.2)
    f.Think = function(s)
        SortRows(s)

        -- only take the keyboard while the review box is in use
        local entry = MV.reviewEntry
        local wantKb = IsValid(entry) and (entry:HasFocus() or entry:IsHovered())
        if wantKb ~= s.kbOn then
            s.kbOn = wantKb
            s:SetKeyboardInputEnabled(wantKb)
        end

        local t = math.Clamp((CurTime() - s.openT) / 0.35, 0, 1)
        local x, y = s.baseX, s.baseY + U(40) * (1 - t) ^ 3
        local sh = MV.shake
        if sh then
            local k = (CurTime() - sh.t) / sh.dur
            if k >= 1 then
                MV.shake = nil
            else
                local m = sh.mag * (1 - k)
                x, y = x + math.Rand(-m, m), y + math.Rand(-m, m)
            end
        end
        s:SetPos(x, y)
    end

    -- left: selected map + its reviews
    local spot = vgui.Create("DPanel", f)
    spot:SetPos(pad, pad)
    spot:SetSize(L - pad * 2, H - pad * 2)
    spot.Paint = PaintSpotlight
    spot.OnMouseWheeled = function(_, delta)
        MV.reviewScrollTarget = (MV.reviewScrollTarget or 0) - delta * U(60)
        return true
    end

    -- right: header, board, rate box
    local rx, rw = L + pad, W - L - pad * 2

    local cr = U(34)

    local rateH = U(196)
    local rateY = H - pad - rateH
    local top = pad + U(90)
    local avail = rateY - U(14) - top - U(26)
    local mapRowH = math.floor(math.min(U(52), (avail - gap * 7) / 7.4))
    local optRowH = math.floor(mapRowH * 0.8)
    f.mapTop, f.mapRowH, f.rowGap = top, mapRowH, gap
    f.mapRows = {}

    local function MakeRow(slot, y, h, delay, fixed)
        local r = vgui.Create("DButton", f)
        r:SetText("")
        r:SetSize(rw, h)
        r.baseX, r.targetY, r.curY = rx, y, y
        r:SetPos(rx, y)
        r.slot, r.fixedOpt = slot, fixed
        r.avatarSize = U(18)
        r.maxAvatars = 4
        r.avatarX = rw - U(130) - r.maxAvatars * (r.avatarSize + U(6))
        r.avatarY = math.floor(h / 2 - r.avatarSize / 2)
        r.Paint = PaintRow
        r.Think = RowThink
        r.DoClick = function(s)
            MV.focus = s.curOpt
            if CastVote(s.curOpt) then PunchCard(s, s:CursorPos()) end
        end
        r:SetAlpha(0)
        r:AlphaTo(255, 0.2, delay)
        MV.cards[slot] = r
        return r
    end

    for i = 1, 5 do
        table.insert(f.mapRows, MakeRow(i, top + (i - 1) * (mapRowH + gap), mapRowH, 0.05 * i))
    end
    f.dividerY = top + 5 * (mapRowH + gap) + U(10)
    local optTop = f.dividerY + U(14)
    for i, opt in ipairs({"extend", "reroll", "random"}) do
        MakeRow(OPTION_SLOT[opt], optTop + (i - 1) * (optRowH + gap), optRowH, 0.3 + 0.05 * i, opt)
    end

    -- rate + review box
    local box = vgui.Create("DPanel", f)
    box:SetPos(rx, rateY)
    box:SetSize(rw, rateH)
    box.scoreW = U(80)
    box.Paint = PaintRateBox

    local slider = vgui.Create("DPanel", box)
    slider:SetPos(U(4), U(38))
    slider:SetSize(rw - box.scoreW - U(28), U(36))
    slider.trackPad = U(14)
    slider.Paint = PaintSlider
    slider.Think = SliderThink
    slider.OnMousePressed = SliderPressed
    slider.OnMouseReleased = SliderReleased
    MV.slider = slider

    local postW = U(96)
    local entry = vgui.Create("DTextEntry", box)
    entry:SetPos(U(14), U(118))
    entry:SetSize(rw - U(28) - postW - U(8), U(32))
    entry:SetFont("ChudMV_Small")
    entry:SetPlaceholderText("Write a review of " .. PrettyName(MV.data.current) .. "...")
    entry:SetPlaceholderColor(Color(120, 120, 126))
    entry:SetTextColor(C.text)
    entry:SetCursorColor(C.text)
    entry:SetHighlightColor(Color(200, 30, 36, 120))
    entry:SetDrawLanguageID(false)
    entry:SetUpdateOnType(true)
    entry:SetValue(MV.draft or MV.rating.myText or "")
    entry.Paint = function(s, w, h)
        surface.SetDrawColor(10, 10, 11, 240)
        surface.DrawRect(0, 0, w, h)
        Outline(0, 0, w, h, s:HasFocus() and C.silver or Color(255, 255, 255, s:IsHovered() and 60 or 30))
        s:DrawTextEntryText(s:GetTextColor(), s:GetHighlightColor(), s:GetCursorColor())
        if s:GetValue() == "" and not s:HasFocus() then
            draw.SimpleText(s:GetPlaceholderText(), "ChudMV_Small", U(5), h / 2, Color(120, 120, 126), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    entry.AllowInput = function(s, ch)
        return (utf8.len(s:GetValue() or "") or 0) >= (MV.data.reviewMax or 140)
    end
    entry.OnValueChange = function(s, val) MV.draft = val end
    entry.OnEnter = function() TryPostReview() end
    MV.reviewEntry = entry

    local post = vgui.Create("DButton", box)
    post:SetText("")
    post:SetPos(rw - U(14) - postW, U(118))
    post:SetSize(postW, U(32))
    post.Paint = function(s, w, h)
        local can = MV.rating.mine > 0 and ReviewChanged()
        s:SetCursor(can and "hand" or "arrow")
        s.hf = Lerp(FrameTime() * 12, s.hf or 0, (can and s:IsHovered()) and 1 or 0)
        s.pop = s.pop or {s = 1, sv = 0}
        local sc = Spring(s.pop, 1 + 0.06 * s.hf, 320, 13)
        WithScale(s, w / 2, h / 2, sc, function()
            local g = can and (40 + 30 * s.hf) or 22
            surface.SetDrawColor(g, g, g + 4, 240)
            surface.DrawRect(0, 0, w, h)
            Outline(0, 0, w, h, can and C.silver or Color(70, 70, 76))
            draw.SimpleText("Post", "ChudMV_Name", w / 2, h / 2, can and C.text or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        return true
    end
    post.DoClick = function() TryPostReview() end
    MV.postBtn = post

    -- tag chips
    local chipX = U(14)
    for _, tag in ipairs(MV.data.tagList or {}) do
        if (MV.data.lockedTags or {})[tag] then continue end
        local label = "#" .. tag
        surface.SetFont("ChudMV_Tiny")
        local cw = surface.GetTextSize(label) + U(20)
        if chipX + cw > rw - U(14) then break end
        local chip = vgui.Create("DButton", box)
        chip:SetText("")
        chip:SetPos(chipX, U(84))
        chip:SetSize(cw, U(24))
        chipX = chipX + cw + U(6)
        chip.Paint = function(s, w, h)
            local on = MV.tagSel and MV.tagSel[tag]
            s.spr = s.spr or {s = 1, sv = 0}
            local sc = Spring(s.spr, s:IsHovered() and 1.1 or 1, 340, 13)
            local ox = 0
            if s.denyAt and CurTime() - s.denyAt < 0.3 then
                ox = math.sin((CurTime() - s.denyAt) * 60) * U(3) * (1 - (CurTime() - s.denyAt) / 0.3)
            end
            local old = DisableClipping(true)
            WithScale(s, w / 2, h / 2, sc, function()
                if on then
                    surface.SetDrawColor(C.silver)
                    surface.DrawRect(ox, 0, w, h)
                else
                    surface.SetDrawColor(18, 18, 20, 240)
                    surface.DrawRect(ox, 0, w, h)
                    Outline(ox, 0, w, h, Color(255, 255, 255, s:IsHovered() and 90 or 35))
                end
                draw.SimpleText(label, "ChudMV_Tiny", w / 2 + ox, h / 2, on and C.badge or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end)
            DisableClipping(old)
            return true
        end
        chip.OnCursorEntered = function(s)
            s.spr = s.spr or {s = 1, sv = 0}
            s.spr.sv = s.spr.sv + 4
        end
        chip.DoClick = function(s)
            MV.tagSel = MV.tagSel or {}
            s.spr = s.spr or {s = 1, sv = 0}
            if MV.tagSel[tag] then
                MV.tagSel[tag] = nil
                s.spr.sv = s.spr.sv - 6
                surface.PlaySound("garrysmod/ui_hover.wav")
                return
            end
            if table.Count(MV.tagSel) >= (MV.data.maxTags or 3) then
                s.denyAt = CurTime()
                surface.PlaySound("buttons/button10.wav")
                return
            end
            MV.tagSel[tag] = true
            s.spr.sv = s.spr.sv + 10
            local fx, fy = ToFrame(s, s:GetWide() / 2, s:GetTall() / 2)
            Emit(fx, fy, 8, {speed = {40, 180}, up = 80, gravity = 500, life = {0.3, 0.6}, size = {U(1), U(3)}, col = SPARK_COLS})
            surface.PlaySound("garrysmod/ui_click.wav")
        end
    end

    SetHidden(MV.hidden)
end

local function ShowMenu()
    if not MV.data then return end
    if not IsValid(MV.frame) then zb.BuildMapVote() end
    SetHidden(false)
end

local function CloseMenu()
    if IsValid(MV.frame) then MV.frame:Remove() end
    MV.data, MV.result, MV.myVote, MV.voters = nil, nil, nil, {}
    MV.hidden = false
end

--;; ---------- input: F3 toggles, 1-8 vote ----------
local chatOpen = false
hook.Add("StartChat", "ChudMV_Chat", function() chatOpen = true end)
hook.Add("FinishChat", "ChudMV_Chat", function() chatOpen = false end)

local keyWas = {}
local function JustPressed(key)
    local down = input.IsKeyDown(key)
    local was = keyWas[key]
    keyWas[key] = down
    return down and not was
end

hook.Add("Think", "ChudMV_Keys", function()
    if not MV.data then return end

    local f3 = JustPressed(KEY_F3)
    local nums = {}
    for i = 1, 8 do nums[i] = JustPressed(KEY_1 + i - 1) end

    if chatOpen or gui.IsGameUIVisible() or gui.IsConsoleVisible() or IsValid(vgui.GetKeyboardFocus()) then return end

    if f3 then
        if MV.hidden or not IsValid(MV.frame) then ShowMenu() else SetHidden(true) end
    end

    if MV.hidden or not IsValid(MV.frame) then return end
    for i = 1, 8 do
        if nums[i] and CastVote(SlotOption(i)) then PunchCard(MV.cards and MV.cards[i]) end
    end
end)

hook.Add("PlayerBindPress", "ChudMV_Binds", function(ply, bind, pressed)
    if not MV.data then return end
    if bind:find("gm_showspare1", 1, true) then return true end
    if not MV.hidden and IsValid(MV.frame) and bind:find("^slot[1-8]") then return true end
end)

--;; ---------- networking ----------
local function MapVoteChat(...)
    chat.AddText(color_white, ...)
end

net.Receive("ZB_RockTheVote_start", function()
    local d = net.ReadTable()
    local wasPhase = MV.data and MV.data.phase

    MV.data = d
    MV.result = nil
    MV.myVote = d.myVote
    local cur = d.ratings and d.ratings[d.current]
    MV.rating = {avg = cur and cur[1] or 0, count = cur and cur[2] or 0, mine = d.myRating or 0, rated = d.rated and true or false, myText = d.myReview or ""}
    d.reviews = d.reviews or {}
    MV.rating.myTags = d.myTags or {}
    d.tagCounts = d.tagCounts or {}
    if not wasPhase then
        MV.draft, MV.crack, MV.focus = nil, nil, nil
        MV.tagSel = SetFromList(MV.rating.myTags)
    end

    MV.hidden = false
    zb.BuildMapVote()
    system.FlashWindow()

    if d.phase == 2 then
        MapVoteChat("No map got 50%+. Head to head: ", C.silver, OptionLabel(d.runoff[1]), color_white, " vs ", C.silver, OptionLabel(d.runoff[2]))
        surface.PlaySound("buttons/blip1.wav")
    elseif wasPhase then
        MapVoteChat("Rerolled! Vote for one of the new maps. (press [F3] if the vote is hidden)")
    else
        MapVoteChat("Vote for the next map! (press [F3] if the vote is hidden)")
    end
end)

net.Receive("ZB_RockTheVote_voteCLreg", function()
    MV.voters = net.ReadTable() or {}
    MV.players = net.ReadUInt(8)
end)

net.Receive("ZB_RockTheVote_end", function()
    local opt = net.ReadString()
    local map = net.ReadString()
    if not MV.data then return end

    MV.result = {opt = opt, map = map}
    surface.PlaySound("buttons/blip1.wav")

    if opt == "extend" then
        MapVoteChat("Staying on ", C.silver, PrettyName(MV.data.current), color_white, " for " .. (MV.data.extendRounds or 8) .. " more rounds.")
        timer.Create("ChudMV_Close", 4, 1, CloseMenu)
    elseif opt == "random" then
        MapVoteChat("Random map won. Next map: ", C.silver, PrettyName(map))
    else
        MapVoteChat("Next map: ", C.silver, PrettyName(map))
    end
end)

net.Receive("ZB_MapVote_Rating", function()
    MV.rating.avg = math.Round(net.ReadFloat(), 1)
    MV.rating.count = net.ReadUInt(16)
    MV.rating.mine = net.ReadUInt(4)
    local rated = net.ReadBool()
    if rated and not MV.rating.rated then MV.karmaPop = CurTime() end
    MV.rating.rated = rated
    MV.rating.myText = net.ReadString()
    local reviews = net.ReadTable()
    MV.rating.myTags = net.ReadTable() or {}
    local tagCounts = net.ReadTable() or {}
    if MV.data then
        local cur = MV.data.current
        MV.data.reviews = MV.data.reviews or {}
        MV.data.reviews[cur] = reviews
        MV.data.tagCounts = MV.data.tagCounts or {}
        MV.data.tagCounts[cur] = tagCounts
        MV.data.ratings = MV.data.ratings or {}
        MV.data.ratings[cur] = {MV.rating.avg, MV.rating.count}
    end
end)

net.Receive("RTVMenu", ShowMenu)

-- kept for anything that still calls the old API
function zb.IsRTVActive()
    return MV.data ~= nil
end

function zb.RTVMenu()
    ShowMenu()
end

concommand.Add("chud_mapvote", function()
    if MV.hidden or not IsValid(MV.frame) then ShowMenu() else SetHidden(true) end
end)
