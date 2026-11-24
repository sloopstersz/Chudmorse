-- Small pieces, sent slowly: a whole 1080p/1440p picture in big pieces could overflow the network
-- buffer and kick the player.
local CHUNK = 16000
local GAP = 0.12
-- The picture is shrunk to at most 1280x720 before it's saved (keeps the shape of the screen), so it's
-- ~100-200 KB instead of several MB, uploads in a second or two and never hitches the game.
local MAX_W, MAX_H = 1280, 720
local want

net.Receive("zac_sg_req", function()
	want = { token = net.ReadUInt(32), quality = net.ReadUInt(7), code = net.ReadString() }
end)

-- is this still the game's own function, or did a script replace it? (Lua cheats that hide from
-- screengrabs usually wrap render.Capture.) Sent with the picture, the server logs it.
local function native(f) if not isfunction(f) then return false end local i = debug.getinfo(f, "S") return i and i.what == "C" end
local function tamperFlags()
	local b = 0
	if not native(render.Capture) then b = b + 1 end
	if not native(render.UpdateScreenEffectTexture) then b = b + 2 end
	if not native(render.PushRenderTarget) then b = b + 4 end
	if not native(render.RenderView) then b = b + 8 end
	return b
end

local rt, fbMat
surface.CreateFont("zac_v_stamp", { font = "Arial", size = 18, weight = 800, antialias = true })
local function capture(q, code)
	local sw, sh = ScrW(), ScrH()
	local w, h = sw, sh
	if w > MAX_W then w, h = MAX_W, math.floor(MAX_W * sh / sw) end
	if h > MAX_H then w, h = math.floor(MAX_H * sw / sh), MAX_H end
	rt = rt or GetRenderTargetEx("zac_v_rt", MAX_W, MAX_H, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGB888)
	fbMat = fbMat or CreateMaterial("zac_v_fb", "UnlitGeneric", { ["$basetexture"] = "_rt_FullFrameFB", ["$ignorez"] = 1, ["$vertexcolor"] = 1 })
	-- copy what's on screen (game + HUD + menus) and draw it shrunk into our own picture
	render.UpdateScreenEffectTexture()
	render.PushRenderTarget(rt)
	render.Clear(0, 0, 0, 255, true, true)
	cam.Start2D()
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(fbMat)
	surface.DrawTexturedRect(0, 0, w, h)
	-- the check code the admin sees next to the picture: if it's missing or different, the
	-- picture was swapped for a fake one
	if code and code ~= "" then
		surface.SetFont("zac_v_stamp")
		local tw, th = surface.GetTextSize(code)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(w - tw - 14, h - th - 10, tw + 10, th + 6)
		surface.SetTextColor(255, 255, 255, 255)
		surface.SetTextPos(w - tw - 9, h - th - 7)
		surface.DrawText(code)
	end
	cam.End2D()
	local data = render.Capture({ format = "jpg", quality = q, x = 0, y = 0, w = w, h = h, alpha = false })
	render.PopRenderTarget()
	return data
end

hook.Add("PostRender", "zac_sg_capture", function()
	if not want then return end
	local w = want
	want = nil
	local flags = tamperFlags()
	local ok, data = pcall(capture, w.quality, w.code)
	if not ok or not data or #data == 0 then
		-- fallback: the old full-size capture
		data = render.Capture({ format = "jpg", quality = math.min(w.quality, 40), x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false })
	end
	if not data or #data == 0 then return end
	local total = math.ceil(#data / CHUNK)
	if total > 255 then return end
	for i = 1, total do
		timer.Simple(i * GAP, function()
			local part = string.sub(data, (i - 1) * CHUNK + 1, i * CHUNK)
			net.Start("zac_sg_chunk")
			net.WriteUInt(w.token, 32)
			net.WriteUInt(i, 8)
			net.WriteUInt(total, 8)
			net.WriteUInt(flags, 8)
			net.WriteUInt(#part, 16)
			net.WriteData(part, #part)
			net.SendToServer()
		end)
	end
end)

local incoming = {}

-- Shown as a normal game texture (written to data/zac_view/), not a web page: the old DHTML viewer
-- pushed megabytes of base64 into the browser and crashed some clients.
local viewN = 0
function ZAC.ShowScreengrab(title, data, code)
	if not data or string.sub(data, 1, 2) ~= "\255\216" then chat.AddText(color_white, "[AC] That screengrab is damaged.") return end
	file.CreateDir("zac_view")
	for _, old in ipairs(file.Find("zac_view/*.jpg", "DATA") or {}) do file.Delete("zac_view/" .. old) end
	viewN = viewN + 1
	local name = "zac_view/sg_" .. os.time() .. "_" .. viewN .. ".jpg"
	file.Write(name, data)
	local mat = Material("../data/" .. name, "smooth noclamp")
	if not mat or mat:IsError() then chat.AddText(color_white, "[AC] Couldn't open that screengrab.") return end
	local iw, ih = mat:Width(), mat:Height()
	if iw <= 0 or ih <= 0 then iw, ih = 16, 9 end

	local f = ZACUI.Frame("Screengrab - " .. title, math.min(ScrW() * 0.85, 1600), math.min(ScrH() * 0.85, 960))
	if code and code ~= "" then
		local note = vgui.Create("DLabel", f)
		note:Dock(BOTTOM)
		note:SetTall(24)
		note:SetTextColor(color_white)
		note:SetText("  Check code: " .. code .. "  - it must be in the bottom-right corner of the picture. Missing or different = a cheat swapped the picture.")
	end
	local pic = vgui.Create("DPanel", f)
	pic:Dock(FILL)
	pic.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, w, h)
		local s = math.min(w / iw, h / ih)
		local dw, dh = iw * s, ih * s
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(mat)
		surface.DrawTexturedRect((w - dw) / 2, (h - dh) / 2, dw, dh)
	end
end

net.Receive("zac_sg_view", function()
	local token = net.ReadUInt(32)
	local idx, total = net.ReadUInt(8), net.ReadUInt(8)
	local title = net.ReadString()
	local code = net.ReadString()
	local data = net.ReadData(net.ReadUInt(16))
	local t = incoming[token] or { parts = {}, got = 0 }
	incoming[token] = t
	if not t.parts[idx] then t.parts[idx], t.got = data, t.got + 1 end
	if t.got >= total then
		incoming[token] = nil
		ZAC.ShowScreengrab(title, table.concat(t.parts), code)
	end
end)
