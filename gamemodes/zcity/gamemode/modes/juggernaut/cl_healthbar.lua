-- Draw directly in screen coordinates: no model-matrix scaling of surface lines.
local function DrawVial(x, y, width, height, fraction, vertical)
	local function Point(u, v)
		if vertical then return {x = x + (1 - v / 18) * width, y = y + u / 180 * height} end
		return {x = x + u / 180 * width, y = y + v / 18 * height}
	end
	local function Polygon(color, coordinates)
		local points = {}
		for _, p in ipairs(coordinates) do points[#points + 1] = Point(p[1], p[2]) end
		surface.SetDrawColor(color)
		surface.DrawPoly(points)
	end
	local function Box(color, u, v, w, h)
		local a, b = Point(u, v), Point(u + w, v + h)
		surface.SetDrawColor(color)
		surface.DrawRect(math.min(a.x, b.x), math.min(a.y, b.y), math.abs(b.x - a.x), math.abs(b.y - a.y))
	end
	local white, black = Color(225, 225, 215), Color(8, 8, 8, 245)
	draw.NoTexture()
	-- Each polygon is convex; the previous single concave outline could lose its cap.
	Polygon(white, {{23,2},{175,2},{180,6},{180,12},{175,16},{23,16}})
	Polygon(black, {{25,4},{174,4},{178,7},{178,11},{174,14},{25,14}})
	local fill = 146 * math.Clamp(fraction, 0, 1)
	if fill > 0 then Box(Color(164,48,25), 174 - fill, 5, fill, 8) end
	-- Filled rectangles remain aligned with the vial at every scale.
	local longSize = vertical and height or width
	if longSize >= 80 then
		for i = 1, 19 do
			Box(Color(30,18,14,230), 28 + i * 7, 5, 1, i % 5 == 0 and 5 or 3)
		end
	end
	Box(white, 0, 0, 27, 18)
	Box(black, 2, 2, 23, 14)
end

local function HealthFraction(ply)
	local maximum = math.max(ply:GetNWInt("ChudJuggernautMaxHealth", 350), 1)
	return math.Clamp(ply:GetNWInt("ChudJuggernautHealth", maximum) / maximum, 0, 1)
end

hook.Add("HUDPaint", "ChudJuggernautHealthBar", function()
	if zb.CROUND ~= "juggernaut" or zb.ROUND_STATE == 3 then return end
	local viewer = LocalPlayer()
	if not IsValid(viewer) then return end
	for _, ply in player.Iterator() do
		if IsValid(ply) and ply ~= viewer and ply:Alive() and ply:GetNWBool("ChudJuggernautHP", false) then
            local body = ply:GetNWEntity("FakeRagdoll")
            if not IsValid(body) then body = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply end
			local head = body:LookupBone("ValveBiped.Bip01_Head1")
			local headPosition = head and body:GetBonePosition(head) or body:WorldSpaceCenter()
			local position = headPosition + Vector(0, 0, 14)
			local trace = util.TraceLine({start = EyePos(), endpos = headPosition, filter = {viewer, ply, body}, mask = MASK_VISIBLE})
			local screen = position:ToScreen()
			if screen.visible and not trace.Hit then
				local edge = (position + EyeAngles():Right() * 16):ToScreen()
				local projectedWidth = math.sqrt((edge.x - screen.x)^2 + (edge.y - screen.y)^2) * 2
				local width = math.Clamp(projectedWidth, 0, 180)
				local height = width / 10
				DrawVial(screen.x - width / 2, screen.y - height / 2, width, height, HealthFraction(ply), false)
			end
		end
	end
end)

hook.Add("HUDPaint", "ChudJuggernautPersonalHealth", function()
	if zb.CROUND ~= "juggernaut" or zb.ROUND_STATE == 3 then return end
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or not ply:GetNWBool("ChudJuggernautHP", false) then return end
	local maximum = math.max(ply:GetNWInt("ChudJuggernautMaxHealth", 350), 1)
	local health = math.Clamp(ply:GetNWInt("ChudJuggernautHealth", maximum), 0, maximum)
	local width, height = 24, 180
	local x, y = ScrW() - width - 36, ScrH() - height - 48
	local points = {
		{x = x + 2, y = y}, {x = x + 22, y = y},
		{x = x + 24, y = y + 2}, {x = x + 24, y = y + 24},
		{x = x + 21, y = y + 27}, {x = x + 21, y = y + 174},
		{x = x + 18, y = y + 179}, {x = x + 6, y = y + 179},
		{x = x + 3, y = y + 174}, {x = x + 3, y = y + 27},
		{x = x, y = y + 24}, {x = x, y = y + 2},
	}
	draw.NoTexture()
	surface.SetDrawColor(8, 8, 8, 240)
	surface.DrawPoly(points)
	-- Liquid drains from the top; remaining health stays at the bottom.
	local fill = math.floor(146 * health / maximum)
	if fill > 0 then
		surface.SetDrawColor(164, 48, 25, 255)
		surface.DrawRect(x + 5, y + 175 - fill, 14, fill)
	end
	surface.SetDrawColor(30, 18, 14, 230)
	for i = 1, 19 do
		local tickY = y + 29 + i * 7
		surface.DrawLine(x + 5, tickY, x + (i % 5 == 0 and 12 or 9), tickY)
	end
	surface.SetDrawColor(225, 225, 215, 255)
	for i, point in ipairs(points) do
		local nextPoint = points[i % #points + 1]
		surface.DrawLine(point.x, point.y, nextPoint.x, nextPoint.y)
	end
	surface.DrawLine(x + 2, y + 24, x + 22, y + 24)
end)
