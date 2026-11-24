-- ZAC integrity report (flags only - nothing here bans anyone). The server asks every so often; this answers
-- with what it sees on this PC:
--   * game functions that should be the engine's own but were replaced by Lua (cheats detour render.Capture
--     to hide from screengrabs, net.Start / RunConsoleCommand to hide what they send, debug.getinfo to hide
--     themselves...)
--   * where every hook / net receiver / console command came from. Injected cheats register from files the
--     server never sent (the server checks the list)
--   * convars that should match the server's (sv_allowcslua / sv_cheats forced on = clientside Lua bypass)
local FUNCS = {
	"render.Capture", "render.CapturePixels", "render.RenderView", "render.UpdateScreenEffectTexture",
	"net.Start", "net.SendToServer", "net.WriteString", "net.ReadString",
	"RunConsoleCommand", "RunString", "CompileString", "CompileFile",
	"debug.getinfo", "debug.sethook", "debug.getupvalue", "debug.getlocal",
	"util.TraceLine", "util.TraceHull", "cam.Start3D", "input.IsMouseDown", "file.Read", "file.Exists",
	"GetConVar", "GetConVarNumber", "LocalPlayer", "hook.Call",
}
local function get(path)
	local t = _G
	for part in string.gmatch(path, "[^%.]+") do
		if not istable(t) then return nil end
		t = rawget(t, part)
	end
	return t
end

-- hook.Call is Lua in GMod; the rest are C. A replaced C function is Lua.
local LUA_OK = { ["hook.Call"] = true }

-- where a function's code comes from, and the line it ends on ({ path, srcOf(f) } keeps both)
local function srcOf(f)
	local ok, i = pcall(debug.getinfo, f, "S")
	return ok and istable(i) and tostring(i.short_src or i.source or "?") or "?", ok and istable(i) and tonumber(i.lastlinedefined) or 0
end

local function report()
	local out = { detours = {}, sources = {}, cvars = {} }
	for _, path in ipairs(FUNCS) do
		local f = get(path)
		if isfunction(f) and not LUA_OK[path] then
			local ok, i = pcall(debug.getinfo, f, "S")
			if ok and istable(i) and i.what ~= "C" then out.detours[#out.detours + 1] = { path, srcOf(f) } end
		elseif f == nil and not LUA_OK[path] then
			out.detours[#out.detours + 1] = { path, "(missing)" }
		end
	end
	-- per source file: hooks, net receivers, console commands, and the highest line a function of it ends on
	-- (a cheat naming its code after a real file is caught when its functions sit past that file's end)
	local function count(fn, kind)
		local src, line = srcOf(fn)
		local s = out.sources[src] or { 0, 0, 0, 0 }
		out.sources[src] = s
		s[kind] = s[kind] + 1
		if line > s[4] then s[4] = line end
	end
	for _, list in pairs(hook.GetTable()) do
		for _, fn in pairs(list) do if isfunction(fn) then count(fn, 1) end end
	end
	for _, fn in pairs(net.Receivers or {}) do if isfunction(fn) then count(fn, 2) end end
	local cmds = concommand.GetTable()
	for _, fn in pairs(cmds or {}) do if isfunction(fn) then count(fn, 3) end end
	-- timers are another usual place injected code hides
	if timer.GetTable then for _, tm in pairs(timer.GetTable() or {}) do if istable(tm) and isfunction(tm.Func) then count(tm.Func, 1) end end end
	for _, n in ipairs({ "sv_allowcslua", "sv_cheats", "host_timescale", "mat_wireframe", "r_drawothermodels", "mat_fullbright", "mat_dxlevel" }) do
		local cv = GetConVar(n)
		out.cvars[n] = cv and cv:GetString() or "?"
	end
	return out
end

net.Receive("zac_int_req", function()
	local token = net.ReadUInt(32)
	local ok, data = pcall(report)
	local json = util.TableToJSON(ok and data or { err = tostring(data) }) or "{}"
	local z = util.Compress(json) or ""
	if #z > 60000 then z = util.Compress(util.TableToJSON({ detours = ok and data.detours or {}, cvars = ok and data.cvars or {}, big = true })) or "" end
	net.Start("zac_int_rep")
	net.WriteUInt(token, 32)
	net.WriteUInt(#z, 16)
	net.WriteData(z, #z)
	net.SendToServer()
end)
