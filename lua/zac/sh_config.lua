ZAC = ZAC or {}

ZAC.Config = {
	-- who can use ZAC: admins, and moderators (the ULX "moderator" group, or anything inheriting from it)
	IsAdmin = function(ply)
		if not IsValid(ply) then return false end
		if ply:IsAdmin() then return true end
		for g in pairs(ZAC.Config and ZAC.Config.ModGroups or { moderator = true }) do
			if ply:IsUserGroup(g) or (ply.CheckGroup and ply:CheckGroup(g)) then return true end
		end
		return false
	end,
	ModGroups = { moderator = true },
	-- moderators can do everything in ZAC except these (real admins only)
	AdminOnlyActions = { whitelist = true, unwhitelist = true, unlink = true, rating_clear = true, clearrating = true, discord_test = true },
	ChatCommands = { ["!ac"] = true, ["/ac"] = true, ["!logs"] = true, ["/logs"] = true },
	ScreengrabChatCommands = { ["!sg"] = true, ["/sg"] = true, ["!screengrab"] = true },

	Keys = {
		KEY_INSERT, KEY_HOME, KEY_PAGEUP, KEY_DELETE, KEY_END, KEY_PAGEDOWN,
		KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12,
	},

}

ZAC.Kinds = { "key", "damage", "death", "aim", "screen", "access", "admin", "chat", "integrity" }
ZAC.KindIndex = {}
for i, k in ipairs(ZAC.Kinds) do ZAC.KindIndex[k] = i end
ZAC.KindLabel = {
	key = "Keybinds", damage = "Damage", death = "Deaths", aim = "Aim flags",
	screen = "Screengrabs", access = "Joins / bans", admin = "Admin", chat = "Chat", integrity = "Cheat checks",
}

ZAC.KeyNames = {
	[KEY_INSERT] = "INSERT", [KEY_HOME] = "HOME", [KEY_PAGEUP] = "PAGE UP", [KEY_DELETE] = "DELETE",
	[KEY_END] = "END", [KEY_PAGEDOWN] = "PAGE DOWN", [KEY_F7] = "F7", [KEY_F8] = "F8", [KEY_F9] = "F9",
	[KEY_F10] = "F10", [KEY_F11] = "F11", [KEY_F12] = "F12",
}
ZAC.KeySet = {}
for _, k in ipairs(ZAC.Config.Keys) do ZAC.KeySet[k] = true end
