local cfg = ZAC.Config
local HISTORY = "zac/chat_history.txt"

local function chatLine(name, text, team)
	return string.format("%s%s: \"%s\"", team and "[TEAM] " or "", name, text)
end

function ZAC.LogChat(ply, text, team)
	if not cfg.ChatLog or not IsValid(ply) or not ply:IsPlayer() then return end
	text = string.sub(tostring(text or ""), 1, 400)
	if string.Trim(text) == "" then return end
	if ply.ZACLastChat == text and ply.ZACLastChatT == CurTime() then return end
	ply.ZACLastChat, ply.ZACLastChatT = text, CurTime()

	ZAC.Log("chat", chatLine(ply:Nick(), text, team), nil, ply)
	if cfg.ChatHistory then
		file.CreateDir("zac")
		file.Append(HISTORY, util.TableToJSON({ t = os.time(), n = ply:Nick(), s = ply:SteamID(), m = text, team = team or nil }) .. "\n")
	end
end

local function capture(ply, text, team)
	local ok, err = pcall(ZAC.LogChat, ply, text, team)
	if not ok then ErrorNoHalt("[ZAC] chat log: " .. tostring(err) .. "\n") end
end
hook.Add("PlayerSay", "zac_chatlog", capture, HOOK_MONITOR_HIGH)
hook.Remove("PlayerSay", "zac_chatlog_fallback")

local function loadHistory()
	if not cfg.ChatHistory or not file.Exists(HISTORY, "DATA") then return end
	local raw = file.Read(HISTORY, "DATA") or ""
	local lines = string.Explode("\n", raw)
	local first = math.max(1, #lines - (cfg.ChatMemory or 20000))
	local entries = {}
	for i = first, #lines do
		local t = lines[i] ~= "" and util.JSONToTable(lines[i])
		if istable(t) and t.m then
			ZAC.NextId = ZAC.NextId + 1
			entries[#entries + 1] = { id = ZAC.NextId, t = tonumber(t.t) or 0, k = "chat", m = chatLine(tostring(t.n or "?"), tostring(t.m), t.team),
				a = { name = tostring(t.n or "?"), sid = tostring(t.s or "") } }
		end
	end
	for _, e in ipairs(ZAC.Logs) do entries[#entries + 1] = e end
	ZAC.Logs = entries
	if #lines > (cfg.ChatMemory or 20000) * 2 then
		file.Write(HISTORY, table.concat(lines, "\n", first, #lines))
	end
	ExtLogZ(string.format("[ZAC] chat history: %d lines loaded", #entries))
end
if not ZAC._chatLoaded then
	ZAC._chatLoaded = true
	loadHistory()
end
