-- hidden per-PC ID for alt detection (sv_alts.lua). Kept in two places so clearing one doesn't reset it.
local FILE = "zc_cache/ui_state.dat"
local function load()
	local t = cookie.GetString("zc_ui_state", "")
	if t == "" then t = file.Read(FILE, "DATA") or "" end
	return string.Trim(t)
end
local function store(t)
	cookie.Set("zc_ui_state", t)
	file.CreateDir("zc_cache")
	file.Write(FILE, t)
end
net.Receive("zac_dev_set", function() store(net.ReadString()) end)
local function send()
	local t = load()
	if t ~= "" then store(t) end -- copy into whichever place was missing it
	net.Start("zac_dev") net.WriteString(t) net.SendToServer()
end
hook.Add("InitPostEntity", "zac_dev", function() timer.Simple(3, send) end)
