if SERVER then AddCSLuaFile() end
-- Z-Zombies is shelved for a rework. Engine code (fists, organism, HUD, phrases)
-- still calls these helpers, some without nil checks, so keep safe defaults:
-- nobody is a zombie. The reworked mode can simply redefine them.
-- Delete this file once Z-Zombies is back.

ZZIsZombie = ZZIsZombie or function() return false end
ZZGetZombieClass = ZZGetZombieClass or function() return nil end
ZZUpdateZombieOrganism = ZZUpdateZombieOrganism or function() end
ZZShowPropHealth = ZZShowPropHealth or function() end
