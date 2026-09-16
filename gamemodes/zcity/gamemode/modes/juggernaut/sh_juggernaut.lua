local MODE = MODE

zb = zb or {}

MODE.name = "juggernaut"
MODE.PrintName = "juggernaut"
MODE.Description = "One heavily armored Juggernaut fights the surviving victims."

-- Juggernaut-specific ZBattle Point Editor group.
-- Only the Fat Chud needs a dedicated editor spawn; everyone else keeps normal spawns.
zb.Points.JUGGERNAUT_FAT_CHUD_SPAWN = zb.Points.JUGGERNAUT_FAT_CHUD_SPAWN or {}
zb.Points.JUGGERNAUT_FAT_CHUD_SPAWN.Color = Color(0, 0, 190)
zb.Points.JUGGERNAUT_FAT_CHUD_SPAWN.Name = "Fat Chud Spawn"
