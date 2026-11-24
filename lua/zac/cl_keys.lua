local down = {}

hook.Add("Think", "zac_keys", function()
	for _, k in ipairs(ZAC.Config.Keys) do
		local d = input.IsKeyDown(k)
		if d and not down[k] then
			local focus = vgui.GetKeyboardFocus()
			net.Start("zac_key")
			net.WriteUInt(k, 8)
			net.WriteBool(IsValid(focus))
			net.WriteBool(gui.IsGameUIVisible())
			net.SendToServer()
		end
		down[k] = d
	end
end)
