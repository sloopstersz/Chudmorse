--;; ===================================
--;; Chudmorse map vote menu (client)
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

local function PaintVoterRow(card, w, h, opt)
    if Count(opt) == 0 then
        draw.SimpleText("No votes yet", "ChudMV_Small", card.avatarX, card.avatarY + card.avatarSize / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        for _, a in ipairs(card.avatars or {}) do
            if IsValid(a) then
                local x, y = a:GetPos()
                Outline(x - 1, y - 1, a:GetWide() + 2, a:GetTall() + 2, Color(255, 255, 255, 60))
            end
        end
        if (card.avatarExtra or 0) > 0 then
            local x = card.avatarX + #card.avatars * (card.avatarSize + U(6))
            draw.SimpleText("+" .. card.avatarExtra, "ChudMV_Small", x, card.avatarY + card.avatarSize / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function PaintRatingBadge(map, rx, y)
    local r = MV.data.ratings and MV.data.ratings[map]
    local avg, n = r and r[1] or 0, r and r[2] or 0
    local isNew = n == 0
    local txt = isNew and "NEW" or string.format("%.1f (%d)", avg, n)
    local col = isNew and C.silver or C.edge

    surface.SetFont("ChudMV_Num")
    local tw = surface.GetTextSize(txt)
    local bh = U(22)
    local bw = tw + U(34)
    local x = rx - bw

    draw.RoundedBox(bh / 2, x, y, bw, bh, col)
    draw.RoundedBox(bh / 2 - 1, x + 1, y + 1, bw - 2, bh - 2, C.badge)
    DrawStar(x + U(14), y + bh / 2, U(6), C.silver)
    draw.SimpleText(txt, "ChudMV_Num", x + U(24), y + bh / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function PaintNumberBadge(num, x, y)
    local s = U(24)
    surface.SetDrawColor(C.badge)
    surface.DrawRect(x, y, s, s)
    draw.SimpleText(tostring(num), "ChudMV_Num", x + s / 2, y + s / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    return s
end

local function PaintCardState(s, w, h, opt, accent)
    local pct = TotalVotes() > 0 and Count(opt) / TotalVotes() or 0
    s.barFrac = Lerp(FrameTime() * 8, s.barFrac or 0, pct)

    surface.SetDrawColor(C.faint)
    surface.DrawRect(0, h - U(3), w, U(3))
    surface.SetDrawColor(accent)
    surface.DrawRect(0, h - U(3), w * s.barFrac, U(3))

    PaintRipples(s, w, h, accent)

    -- hover: glowing edge + a light sweep across the card
    local hf = s.hf or 0
    if hf > 0.01 then
        Outline(0, 0, w, h, Color(255, 255, 255, 90 * hf), 1)
        local sweep = ((CurTime() - (s.hoverAt or 0)) * 1.6) % 2.2 - 0.6
        if sweep < 1.2 then
            surface.SetDrawColor(255, 255, 255, 18 * hf)
            draw.NoTexture()
            local x = sweep * w
            surface.DrawPoly({{x = x, y = 0}, {x = x + U(40), y = 0}, {x = x + U(10), y = h}, {x = x - U(30), y = h}})
        end
    end

    if MV.result and MV.result.opt == opt then
        local pulse = 150 + math.sin(CurTime() * 6) * 100
        Outline(0, 0, w, h, Color(255, 255, 255, pulse), 2)
    elseif MV.myVote == opt then
        Outline(0, 0, w, h, C.red, 2)
    end

    if IsOut(opt) or not Offered(opt) then
        surface.SetDrawColor(6, 6, 7, 195)
        surface.DrawRect(0, 0, w, h)
        if IsOut(opt) then
            draw.SimpleText("OUT", "ChudMV_Pct", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

--;; ---------- map card ----------
local function PaintMapCard(s, w, h)
    local opt = SlotOption(s.slot)
    if not opt then
        surface.SetDrawColor(C.cardLow)
        surface.DrawRect(0, 0, w, h)
        return true
    end

    s.hf = Lerp(FrameTime() * 10, s.hf or 0, (s:IsHovered() and Votable(opt)) and 1 or 0)
    local bg = C.card
    surface.SetDrawColor(Lerp(s.hf, bg.r, C.cardHover.r), Lerp(s.hf, bg.g, C.cardHover.g), Lerp(s.hf, bg.b, C.cardHover.b), bg.a)
    surface.DrawRect(0, 0, w, h)

    -- thumbnail (square art cropped to the card)
    local th = math.floor(h * 140 / 220)
    local mat = Thumb(opt)
    if mat then
        -- slow zoom into the art while hovered
        local zoom = 1 + 0.12 * s.hf
        local frac = math.Clamp(th / w, 0, 1) / zoom
        local u = 0.5 / zoom
        local v0 = 0.5 - frac / 2
        surface.SetDrawColor(255, 255, 255, 220 + 35 * s.hf)
        surface.SetMaterial(mat)
        surface.DrawTexturedRectUV(0, 0, w, th, 0.5 - u, v0, 0.5 + u, v0 + frac)
    else
        surface.SetDrawColor(40, 40, 42, 255)
        surface.DrawRect(0, 0, w, th)
        draw.SimpleText(Prefix(opt) or "?", "ChudMV_Big", w / 2, th / 2, Color(150, 150, 150, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    surface.SetDrawColor(0, 0, 0, 200)
    surface.SetMaterial(gradUp)
    surface.DrawTexturedRect(0, th * 0.45, w, th * 0.55)

    -- badges
    local bx = U(10) + PaintNumberBadge(s.slot, U(10), U(12)) + U(6)
    local prefix = Prefix(opt)
    if prefix then
        surface.SetFont("ChudMV_Tiny")
        local pw = surface.GetTextSize(prefix) + U(10)
        surface.SetDrawColor(8, 8, 9, 200)
        surface.DrawRect(bx, U(14), pw, U(20))
        Outline(bx, U(14), pw, U(20), Color(255, 255, 255, 110))
        draw.SimpleText(prefix, "ChudMV_Tiny", bx + pw / 2, U(24), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    PaintRatingBadge(opt, w - U(10), U(12))

    -- leading + percentage
    local count, total = Count(opt), TotalVotes()
    if count > 0 and count == TopCount() then
        surface.SetFont("ChudMV_Tiny")
        local lw = surface.GetTextSize("LEADING") + U(12)
        surface.SetDrawColor(C.badge)
        surface.DrawRect(U(10), th - U(28), lw, U(20))
        Outline(U(10), th - U(28), lw, U(20), Color(255, 255, 255, 140))
        draw.SimpleText("LEADING", "ChudMV_Tiny", U(10) + lw / 2, th - U(18), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local pct = total > 0 and math.Round(count / total * 100) or 0
    s.lastCount = count
    PaintPct(s, pct .. "%", w - U(10), th - U(16), TEXT_ALIGN_RIGHT)

    -- name + votes
    local votesTxt = count == 1 and "1 vote" or (count .. " votes")
    surface.SetFont("ChudMV_Small")
    local vw = surface.GetTextSize(votesTxt)
    draw.SimpleText(votesTxt, "ChudMV_Small", w - U(12), th + U(18), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(Fit(PrettyName(opt), "ChudMV_Name", w - vw - U(34)), "ChudMV_Name", U(12), th + U(18), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    PaintVoterRow(s, w, h, opt)
    PaintCardState(s, w, h, opt, C.silver)
    return true
end

--;; ---------- option cards ----------
local function PaintOptionIcon(opt, x, y, s)
    if opt == "extend" then
        local mat = MV.data and Thumb(MV.data.current)
        if mat then
            surface.SetDrawColor(255, 255, 255, 200)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(x, y, s, s)
        else
            surface.SetDrawColor(36, 36, 40, 255)
            surface.DrawRect(x, y, s, s)
        end
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(x, y, s, s)
        draw.SimpleTextOutlined("+" .. (MV.data and MV.data.extendRounds or 8), "ChudMV_Big", x + s / 2, y + s / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
    elseif opt == "reroll" then
        surface.SetDrawColor(18, 18, 20, 255)
        surface.DrawRect(x, y, s, s)
        local p = U(14)
        Outline(x + p, y + p, s - p * 2, s - p * 2, C.edge, 2)
        draw.SimpleText("?", "ChudMV_Big", x + s / 2, y + s / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        surface.SetDrawColor(18, 18, 20, 255)
        surface.DrawRect(x, y, s, s)
        local d = math.floor(s * 0.56)
        local dx, dy = x + (s - d) / 2, y + (s - d) / 2
        draw.RoundedBox(U(6), dx, dy, d, d, C.silver)
        local pip = math.max(2, math.floor(d * 0.14))
        local function dot(fx, fy)
            draw.RoundedBox(pip / 2, dx + d * fx - pip / 2, dy + d * fy - pip / 2, pip, pip, C.badge)
        end
        dot(0.27, 0.27) dot(0.73, 0.27) dot(0.5, 0.5) dot(0.27, 0.73) dot(0.73, 0.73)
    end
end

local function OptionDesc(opt)
    local d = MV.data
    if opt == "extend" then
        if not Offered(opt) then return "Extend limit reached for this map" end
        return "Stay on " .. PrettyName(d.current) .. " for " .. (d.extendRounds or 8) .. " more rounds"
    elseif opt == "reroll" then
        if not Offered(opt) then return "Already rerolled once" end
        return "Reroll for new maps"
    end
    return "Any map on the server"
end

local function PaintOptionCard(s, w, h)
    local opt = s.opt
    local accent = OPTION_COLOR[opt]

    s.hf = Lerp(FrameTime() * 10, s.hf or 0, (s:IsHovered() and Votable(opt)) and 1 or 0)
    local bg = C.card
    surface.SetDrawColor(Lerp(s.hf, bg.r, C.cardHover.r), Lerp(s.hf, bg.g, C.cardHover.g), Lerp(s.hf, bg.b, C.cardHover.b), bg.a)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(accent)
    surface.DrawRect(0, 0, U(3), h)

    local iconS = U(68)
    local ix, iy = U(12), U(11)
    -- the icon bulges and wobbles while the card is hovered
    s.icon = s.icon or {s = 1, sv = 0}
    local hovering = s:IsHovered() and Votable(opt)
    if hovering and not s.iconWas then s.icon.sv = s.icon.sv + 5 end
    s.iconWas = hovering
    local isc = Spring(s.icon, hovering and (1.16 + math.sin(CurTime() * 7) * 0.025) or 1, 340, 15)
    local old = DisableClipping(true)
    WithScale(s, ix + iconS / 2, iy + iconS / 2, isc, function()
        PaintOptionIcon(opt, ix, iy, iconS)
        PaintNumberBadge(OPTION_SLOT[opt], ix - U(2), iy - U(1))
    end)
    DisableClipping(old)

    local count, total = Count(opt), TotalVotes()
    local pct = total > 0 and math.Round(count / total * 100) or 0
    local tx = ix + iconS + U(14)

    s.lastCount = count
    PaintPct(s, pct .. "%", w - U(14), U(20), TEXT_ALIGN_RIGHT)
    draw.SimpleText(count == 1 and "1 vote" or (count .. " votes"), "ChudMV_Small", w - U(14), U(41), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local textW = w - tx - U(90)
    draw.SimpleText(OptionLabel(opt), "ChudMV_Name", tx, U(20), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(Fit(OptionDesc(opt), "ChudMV_Small", textW), "ChudMV_Small", tx, U(38), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    PaintVoterRow(s, w, h, opt)
    PaintCardState(s, w, h, opt, C.silver)
    return true
end

--;; ---------- rating strip ----------
local function MakeCrack()
    local pts, x = {{x = 0.08, y = -0.95}}, 0.08
    for k = 1, 5 do
        x = math.Clamp(x + math.Rand(-0.38, 0.38), -0.42, 0.42)
        table.insert(pts, {x = x, y = -0.95 + k * 0.38})
    end
    local bp = pts[math.random(2, 4)]
    local dir = math.random() < 0.5 and -1 or 1
    local b1 = {x = bp.x + dir * math.Rand(0.25, 0.4), y = bp.y + math.Rand(0.15, 0.3)}
    local b2 = {x = b1.x + dir * math.Rand(0.15, 0.3), y = b1.y + math.Rand(0.1, 0.25)}
    return {pts = pts, branch = {bp, b1, b2}, t = 0}
end

local function StarCenter(b)
    local w, h = b:GetSize()
    return ToFrame(b, w / 2, h / 2)
end

local STAR_COLS = {color_white, color_white, C.silver, C.silver, Color(160, 160, 166), C.red}

local function RateFX(stars)
    local list = MV.stars or {}
    for j = 1, stars do
        if IsValid(list[j]) then list[j].kickAt = CurTime() + (j - 1) * 0.06 end
    end

    if stars == 1 then
        MV.crack = MakeCrack()
        MV.crack.t = CurTime()
        surface.PlaySound("physics/glass/glass_cup_break1.wav")
        Shake(U(7), 0.35)
        timer.Simple(0.1, function()
            local b = list[1]
            if not IsValid(b) then return end
            local fx, fy = StarCenter(b)
            Emit(fx, fy, 7, {kind = "shard", speed = {60, 200}, up = 80, gravity = 1100, life = {0.6, 1.0}, size = {U(3), U(6)}, col = {Color(110, 110, 116), Color(70, 70, 75)}})
            Emit(fx, fy, 14, {speed = {20, 110}, gravity = 250, drag = 3, life = {0.4, 0.9}, size = {U(1), U(3)}, jitter = U(6), col = {Color(90, 90, 95), Color(55, 55, 60)}})
        end)
        return
    end

    MV.crack = nil

    if stars == 5 then
        local b5 = list[5]
        if IsValid(b5) then b5.boomAt = CurTime() end
        surface.PlaySound("buttons/button9.wav")
        timer.Simple(0.3, function()
            if not IsValid(b5) then return end
            local fx, fy = StarCenter(b5)
            Emit(fx, fy, 38, {kind = "star", speed = {180, 560}, up = 80, gravity = 420, life = {0.7, 1.3}, size = {U(3), U(8)}, col = STAR_COLS})
            Emit(fx, fy, 24, {speed = {80, 300}, gravity = 200, life = {0.3, 0.7}, size = {U(2), U(4)}, col = STAR_COLS})
            for j = 1, 4 do
                if IsValid(list[j]) then
                    local sx, sy = StarCenter(list[j])
                    Emit(sx, sy, 5, {kind = "star", speed = {60, 220}, up = 120, gravity = 500, life = {0.5, 0.9}, size = {U(2), U(4)}, col = STAR_COLS})
                end
            end
            surface.PlaySound("garrysmod/balloon_pop_cute.wav")
            Shake(U(4), 0.25)
            MV.rateFlash = CurTime()
        end)
    elseif IsValid(list[stars]) then
        local fx, fy = StarCenter(list[stars])
        Emit(fx, fy, stars == 4 and 14 or 6, {kind = "star", speed = {60, 240}, up = 100, gravity = 500, life = {0.4, 0.8}, size = {U(2), U(4)}, col = STAR_COLS})
        surface.PlaySound("garrysmod/ui_click.wav")
    end
end

local function SendRating(stars)
    if MV.rateCD and MV.rateCD > CurTime() then return end
    MV.rateCD = CurTime() + 0.5
    MV.rating.mine = stars
    net.Start("ZB_MapVote_Rate")
        net.WriteUInt(stars, 3)
    net.SendToServer()
    RateFX(stars)
end

local function PaintRatingStar(s, w, h, i, rate)
    local hover = rate.hoverStar
    local mine = MV.rating.mine
    local lit = hover > 0 and i <= hover or (hover == 0 and i <= mine)
    local col = lit and C.gold or C.starOff

    local target, rot = 1, 0
    if hover > 0 and i <= hover then
        target = i == hover and 1.4 or 1.15
        if i == hover then rot = math.sin(CurTime() * 12) * 10 end
    end

    s.spr = s.spr or {s = 1, sv = 0}
    local sc
    if s.boomAt then
        -- the 5th star swells, spins and goes white-hot, then bursts
        local t = (CurTime() - s.boomAt) / 0.3
        if t < 1 then
            sc = 1 + t * t * 1.4
            rot = rot + t * 220
            col = Color(255, 255, 255)
            s.spr.s, s.spr.sv = sc, 0
        else
            s.boomAt = nil
            s.spr.s, s.spr.sv = 0.15, 16
        end
    end
    sc = sc or Spring(s.spr, target, 360, 13)

    local ox, oy = 0, 0
    local cracked = i == 1 and mine == 1 and hover == 0
    if cracked then
        MV.crack = MV.crack or MakeCrack()
        col = Color(95, 95, 100)
        local ct = CurTime() - MV.crack.t
        if ct < 0.35 then
            local m = U(4) * (1 - ct / 0.35)
            ox, oy = math.Rand(-m, m), math.Rand(-m, m)
        end
    end

    local cx, cy = w / 2 + ox, h / 2 + U(1) + oy
    local r = (w / 2 - U(1)) * sc
    local old = DisableClipping(true)
    if lit and hover > 0 then
        DrawStar(cx, cy, r * 1.3, Color(255, 255, 255, 40), rot)
    end
    DrawStar(cx, cy, r, col, rot)

    if cracked then
        local crack = MV.crack
        local function line(pts, col2, off)
            surface.SetDrawColor(col2)
            for k = 1, #pts - 1 do
                local a, b = pts[k], pts[k + 1]
                surface.DrawLine(cx + a.x * r + off, cy + a.y * r, cx + b.x * r + off, cy + b.y * r)
            end
        end
        local dark = Color(8, 8, 9, 255)
        line(crack.pts, dark, 0) line(crack.pts, dark, 1)
        line(crack.pts, Color(C.red.r, C.red.g, C.red.b, 200), -1)
        line(crack.branch, dark, 0)
    end
    DisableClipping(old)
    return true
end

local function PaintRatingStrip(s, w, h)
    local d = MV.data
    surface.SetDrawColor(C.rateBg)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(C.edge)
    surface.DrawRect(0, 0, U(3), h)

    if MV.rateFlash then
        local t = (CurTime() - MV.rateFlash) / 0.6
        if t < 1 then
            surface.SetDrawColor(255, 255, 255, 70 * (1 - t))
            surface.DrawRect(0, 0, w, h)
        else
            MV.rateFlash = nil
        end
    end

    local tw, thh = U(72), U(50)
    local mat = Thumb(d.current)
    if mat then
        surface.SetDrawColor(255, 255, 255, 230)
        surface.SetMaterial(mat)
        surface.DrawTexturedRectUV(U(12), U(10), tw, thh, 0, 0.15, 1, 0.85)
    else
        surface.SetDrawColor(36, 36, 40, 255)
        surface.DrawRect(U(12), U(10), tw, thh)
    end

    draw.SimpleText("RATE THE MAP YOU JUST PLAYED", "ChudMV_Tiny", U(98), U(22), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(Fit(PrettyName(d.current), "ChudMV_Name", s.starsX - U(110)), "ChudMV_Name", U(98), U(43), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- karma pill
    local rated = MV.rating.rated
    local pillTxt = "+" .. (d.rateKarma or 5) .. " KARMA"
    surface.SetFont("ChudMV_Tiny")
    local pw = surface.GetTextSize(pillTxt) + U(22)
    local ph = U(24)
    local px, py = s.pillX, h / 2 - ph / 2
    draw.RoundedBox(ph / 2, px, py, pw, ph, rated and Color(60, 60, 64, 230) or C.edge)
    draw.RoundedBox(ph / 2 - 1, px + 1, py + 1, pw - 2, ph - 2, rated and Color(28, 28, 30, 230) or Color(45, 45, 50, 255))
    draw.SimpleText(pillTxt, "ChudMV_Tiny", px + pw / 2, h / 2, rated and C.dim or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if MV.karmaPop then
        local t = (CurTime() - MV.karmaPop) / 1.1
        if t < 1 then
            local old = DisableClipping(true)
            local y = h / 2 - U(46) * (1 - (1 - t) ^ 2)
            draw.SimpleTextOutlined(pillTxt, "ChudMV_Num", px + pw / 2, y, Color(255, 255, 255, 255 * (1 - t)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200 * (1 - t)))
            DisableClipping(old)
        else
            MV.karmaPop = nil
        end
    end

    local hint
    if rated then
        hint = "Thanks for rating!"
    elseif MV.rating.mine > 0 then
        hint = "You gave it " .. MV.rating.mine .. "/5. Click to update"
    else
        hint = "How was it? Click a star"
    end

    -- average on the right
    local avgTxt = MV.rating.count > 0 and string.format("%.1f  ·  %d rating%s", MV.rating.avg, MV.rating.count, MV.rating.count == 1 and "" or "s") or "No ratings yet"
    surface.SetFont("ChudMV_Small")
    local aw = surface.GetTextSize(avgTxt)
    draw.SimpleText(avgTxt, "ChudMV_Small", w - U(14), h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    local sr = U(7)
    local sx = w - U(14) - aw - U(12) - sr
    for i = 5, 1, -1 do
        local fill = MV.rating.count > 0 and i <= math.floor(MV.rating.avg + 0.5)
        DrawStar(sx, h / 2, sr, fill and C.silver or C.starOff)
        sx = sx - sr * 2 - U(4)
    end

    local hx = px + pw + U(14)
    draw.SimpleText(Fit(hint, "ChudMV_Small", math.max(U(40), sx - hx - U(10))), "ChudMV_Small", hx, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    return true
end

--;; ---------- frame ----------
local function PaintFrame(s, w, h)
    local d = MV.data
    if not d then return end

    if hg and hg.DrawBlur then hg.DrawBlur(s, 4) end
    surface.SetDrawColor(C.bg)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(C.header)
    surface.SetMaterial(gradDown)
    surface.DrawTexturedRect(0, 0, w, U(110))
    surface.SetDrawColor(C.red)
    surface.DrawRect(0, 0, w, U(3))

    local pad = U(22)

    local label, title
    if MV.result then
        label = "RESULT"
        if MV.result.opt == "extend" then
            title = "Staying on " .. PrettyName(d.current) .. " for " .. (d.extendRounds or 8) .. " more rounds"
        elseif MV.result.opt == "random" then
            title = "Random pick: " .. PrettyName(MV.result.map) .. ". Changing map..."
        else
            title = "Next map: " .. PrettyName(MV.result.map) .. ". Changing map..."
        end
    elseif d.phase == 2 then
        label = "RUNOFF"
        title = "Head to head: " .. OptionLabel(d.runoff[1]) .. " vs " .. OptionLabel(d.runoff[2])
    else
        label = "MAP VOTE"
        title = "Vote for the next map"
    end
    draw.SimpleText(label, "ChudMV_Label", pad, U(28), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(Fit(title, "ChudMV_Title", w - pad * 2 - U(160)), "ChudMV_Title", pad, U(53), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local left = math.max(0, (d.endTime or 0) - CurTime())
    local secs = MV.result and 0 or math.ceil(left)
    if secs ~= MV.lastSecs then
        if secs > 0 and secs <= 5 and MV.lastSecs then
            MV.timerPop = {s = 1, sv = 7}
            surface.PlaySound("buttons/blip1.wav")
        end
        MV.lastSecs = secs
    end
    MV.timerPop = MV.timerPop or {s = 1, sv = 0}
    local tsc = Spring(MV.timerPop, 1, 320, 12)
    local urgent = secs > 0 and secs <= 5
    WithScale(s, w - pad, U(36), tsc, function()
        draw.SimpleText(tostring(secs), "ChudMV_Timer", w - pad, U(36), urgent and C.red or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)
    draw.SimpleText("SECONDS LEFT", "ChudMV_Tiny", w - pad, U(60), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local frac = MV.result and 0 or math.Clamp(left / math.max(d.duration or 1, 1), 0, 1)
    surface.SetDrawColor(C.faint)
    surface.DrawRect(pad, U(95), w - pad * 2, U(3))
    surface.SetDrawColor(C.silver)
    surface.DrawRect(pad, U(95), (w - pad * 2) * frac, U(3))

    local voted = TotalVotes()
    draw.SimpleText(voted .. " of " .. math.max(MV.players, voted) .. " players voted", "ChudMV_Small", pad, U(118), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    local hint = d.phase == 2
        and "Click or press the card's number  ·  Most votes wins, ties are random"
        or "Click or press 1-8  ·  50%+ wins outright, otherwise the top two go head to head"
    draw.SimpleText(hint, "ChudMV_Small", w - pad, U(118), C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
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
local function CardThink(s, opt)
    local hov = s:IsHovered() and Votable(opt)
    s.bulge = s.bulge or {s = 1, sv = 0}
    if hov and not s.hovWas then
        s.hoverAt = CurTime()
        s.bulge.sv = s.bulge.sv + 1.6
        s:MoveToFront()
        surface.PlaySound("garrysmod/ui_hover.wav")
    end
    s.hovWas = hov
    local sc = Spring(s.bulge, hov and 1.05 or 1, 300, 14)
    local w, h = math.floor(s.baseW * sc + 0.5), math.floor(s.baseH * sc + 0.5)
    if w ~= s:GetWide() or h ~= s:GetTall() then
        s:SetSize(w, h)
        s:SetPos(s.baseX - (w - s.baseW) / 2, s.baseY - (h - s.baseH) / 2)
    end
    s:SetCursor(Votable(opt) and "hand" or "arrow")
end

local function PlaceCard(c, x, y, w, h, delay)
    c.baseX, c.baseY, c.baseW, c.baseH = x, y, w, h
    c:SetPos(x, y)
    c:SetSize(w, h)
    c:SetAlpha(0)
    c:AlphaTo(255, 0.22, delay)
    c.bulge = {s = 0.85, sv = 0}
end

function zb.BuildMapVote()
    if IsValid(MV.frame) then MV.frame:Remove() end
    if not MV.data then return end

    local W = math.min(U(1240), ScrW() - U(40))
    local H = U(600)
    local pad, gap = U(22), U(12)
    local inner = W - pad * 2

    local f = vgui.Create("EditablePanel")
    f:SetSize(W, H)
    f:Center()
    f:MakePopup()
    f:SetKeyboardInputEnabled(false)
    f.Paint = PaintFrame
    f.PaintOver = function() DrawParticles() end
    MV.frame = f
    MV.cards, MV.stars = {}, {}
    table.Empty(particles)

    -- slide + fade in, and screen shake on big moments
    f.baseX, f.baseY = f:GetPos()
    f.openT = CurTime()
    f:SetAlpha(0)
    f:AlphaTo(255, 0.18)
    f.Think = function(s)
        local t = math.Clamp((CurTime() - s.openT) / 0.3, 0, 1)
        local x, y = s.baseX, s.baseY - U(26) * (1 - t) ^ 3
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

    -- 5 map cards
    local cw = math.floor((inner - gap * 4) / 5)
    for i = 1, 5 do
        local c = vgui.Create("DButton", f)
        c:SetText("")
        PlaceCard(c, pad + (i - 1) * (cw + gap), U(139), cw, U(220), 0.04 * i)
        c.slot = i
        MV.cards[i] = c
        c.avatarX, c.avatarY, c.avatarSize = U(12), U(186), U(20)
        c.maxAvatars = math.max(1, math.floor((cw - U(50)) / (U(20) + U(6))))
        c.Paint = PaintMapCard
        c.Think = function(s)
            local opt = SlotOption(s.slot)
            if opt then SyncAvatars(s, opt) end
            CardThink(s, opt)
        end
        c.DoClick = function(s)
            if CastVote(SlotOption(s.slot)) then PunchCard(s, s:CursorPos()) end
        end
    end

    -- extend / none of these / random
    local ow = math.floor((inner - gap * 2) / 3)
    for i, opt in ipairs({"extend", "reroll", "random"}) do
        local c = vgui.Create("DButton", f)
        c:SetText("")
        PlaceCard(c, pad + (i - 1) * (ow + gap), U(372), ow, U(95), 0.24 + 0.05 * i)
        c.opt = opt
        MV.cards[OPTION_SLOT[opt]] = c
        c.avatarX, c.avatarY, c.avatarSize = U(94), U(62), U(18)
        c.maxAvatars = math.max(1, math.floor((ow - U(130)) / (U(18) + U(6))))
        c.Paint = PaintOptionCard
        c.Think = function(s)
            SyncAvatars(s, s.opt)
            CardThink(s, s.opt)
        end
        c.DoClick = function(s)
            if CastVote(s.opt) then PunchCard(s, s:CursorPos()) end
        end
    end

    -- rate the map you just played
    local rate = vgui.Create("DPanel", f)
    rate:SetPos(pad, U(485))
    rate:SetSize(inner, U(70))
    rate.starsX = U(420)
    rate.pillX = rate.starsX + 5 * U(36) + U(16)
    rate.Paint = PaintRatingStrip
    rate.hoverStar = 0
    for i = 1, 5 do
        local b = vgui.Create("DButton", rate)
        b:SetText("")
        b:SetSize(U(34), U(34))
        b:SetPos(rate.starsX + (i - 1) * U(36), U(18))
        MV.stars[i] = b
        b.Paint = function(s, w, h) return PaintRatingStar(s, w, h, i, rate) end
        b.Think = function(s)
            if s.kickAt and CurTime() >= s.kickAt then
                s.kickAt = nil
                s.spr = s.spr or {s = 1, sv = 0}
                s.spr.sv = s.spr.sv + 10
            end
        end
        b.OnCursorEntered = function(s)
            rate.hoverStar = i
            s.spr = s.spr or {s = 1, sv = 0}
            s.spr.sv = s.spr.sv + 6
            surface.PlaySound("garrysmod/ui_hover.wav")
        end
        b.OnCursorExited = function() if rate.hoverStar == i then rate.hoverStar = 0 end end
        b.DoClick = function() SendRating(i) end
    end

    -- hide button
    local hide = vgui.Create("DButton", f)
    hide:SetText("")
    hide:SetSize(U(106), U(28))
    hide:SetPos(W - pad - U(106), H - U(38))
    hide.Paint = function(s, w, h)
        local hov = s:IsHovered()
        s.hf = Lerp(FrameTime() * 12, s.hf or 0, hov and 1 or 0)
        if s.hf > 0.01 then
            local old = DisableClipping(true)
            surface.SetDrawColor(255, 255, 255, 20 * s.hf)
            surface.DrawRect(-U(3) * s.hf, -U(3) * s.hf, w + U(6) * s.hf, h + U(6) * s.hf)
            DisableClipping(old)
        end
        surface.SetDrawColor(hov and 40 or 22, hov and 40 or 22, hov and 44 or 25, 235)
        surface.DrawRect(0, 0, w, h)
        Outline(0, 0, w, h, hov and C.silver or Color(90, 90, 96, 200))
        draw.SimpleText("Hide  [F3]", "ChudMV_Small", w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return true
    end
    hide.DoClick = function() SetHidden(true) end

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
    chat.AddText(C.red, "[Map Vote] ", color_white, ...)
end

net.Receive("ZB_RockTheVote_start", function()
    local d = net.ReadTable()
    local wasPhase = MV.data and MV.data.phase

    MV.data = d
    MV.result = nil
    MV.myVote = d.myVote
    local cur = d.ratings and d.ratings[d.current]
    MV.rating = {avg = cur and cur[1] or 0, count = cur and cur[2] or 0, mine = d.myRating or 0, rated = d.rated and true or false}

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
    MV.rating.mine = net.ReadUInt(3)
    local rated = net.ReadBool()
    if rated and not MV.rating.rated then MV.karmaPop = CurTime() end
    MV.rating.rated = rated
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
