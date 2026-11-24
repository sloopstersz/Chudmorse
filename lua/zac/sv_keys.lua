local function logKey(ply, key, source, typing, menu)
	if not ZAC.KeySet[key] then return end
	ply.ZACKeyLast = ply.ZACKeyLast or {}
	if (ply.ZACKeyLast[key] or 0) > CurTime() - 0.4 then return end
	ply.ZACKeyLast[key] = CurTime()

	local ctx = {}
	if typing then ctx[#ctx + 1] = "typing" end
	if menu then ctx[#ctx + 1] = "escape menu open" end
	if source == "client" then ctx[#ctx + 1] = "client only" end
	ZAC.Log("key", string.format("%s pressed %s%s", ZAC.Who(ply), ZAC.KeyNames[key] or ("key " .. key),
		#ctx > 0 and ("  [" .. table.concat(ctx, ", ") .. "]") or ""), nil, ply)
end

hook.Add("PlayerButtonDown", "zac_keys", function(ply, button)
	if IsValid(ply) and ZAC.KeySet[button] then logKey(ply, button, "server", false, false) end
end)

net.Receive("zac_key", function(_, ply)
	local key = net.ReadUInt(8)
	local typing = net.ReadBool()
	local menu = net.ReadBool()
	local now = CurTime()
	if (ply.ZACKeyWin or 0) < now then ply.ZACKeyWin, ply.ZACKeyCount = now + 1, 0 end
	ply.ZACKeyCount = ply.ZACKeyCount + 1
	if ply.ZACKeyCount > 12 then return end
	timer.Simple(0.15, function()
		if IsValid(ply) then logKey(ply, key, "client", typing, menu) end
	end)
end)
