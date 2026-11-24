local server = {
	LogMemory = 6000,
	LogToFile = true,
	PrintToConsole = true,
	-- which log kinds are printed to the server console (chat/damage/death/key are left out: too spammy)
	ConsoleKinds = { access = true, admin = true, aim = true, screen = true },
	MaxSend = 400,
	ViewMemory = 4000,

	ChatLog = true,
	ChatMemory = 20000,
	ChatHistory = true,

	-- true = force everyone's display name (PlayerName) to their Steam name. Off so Z-City
	-- appearance names and player class names (Gordon, SWAT, callsigns...) work. ZAC menus/logs use Steam names anyway.
	RealNames = false,

	HitMemory = 180,
	EnvDamageLogEvery = 2,

	-- (family-shared accounts are always allowed in - never kicked or banned for it; only noted in the log)
	BanMessage = "You've been banned from this server please appeal in the discord",

	AimCheck = true,
	SnapDegrees = 35,
	SnapWindow = 0.15,
	SnapSettle = 1.5,
	SnapCooldown = 2,
	HeadshotMinHits = 40,
	HeadshotRatio = 0.6,
	AlertAdmins = true,

	-- SILENT AIM: the shot landed on the victim, but the shooter's view was pointing somewhere else.
	-- The server sees both the view angle it was sent and where the bullet went, so "server silent" /
	-- "silent" aim can't hide this. Angle is measured from the shooter's eye.
	SilentCheck = true,
	SilentDegrees = 20,       -- view this many degrees off the bullet = off-angle shot (gun spread + recoil is well under this)
	SilentMinDist = 200,      -- ~4 m: closer than this a small hitbox offset looks like a big angle, so ignore
	SilentMinHits = 3,        -- off-angle bullet hits needed before it flags (a single flick isn't enough)
	SilentWindow = 12,        -- ... within this many seconds
	SilentCooldown = 8,
	SilentPoints = 22,        -- cheat-rating points per flag (one clean catch ~= SUSPECT)

	SpeedCheck = {
		Enabled = true,
		Window = 6,     -- seconds averaged
		Ratio = 1.2,    -- flag above 120% of the server tickrate
		Cooldown = 30,
		Points = 12,    -- cheat-rating points per flag
	},

	Rating = {
		HalfLife = 1200,
		Suspect = 25,
		Cheating = 60,
		CheatingKinds = 2,
		KindMin = 8,
		MaxEvidence = 60,
		RateBots = false,

		EngageWindow = 8,
		InstantDeath = 1.0,
		HeadKillPoints = 5,
		HeadKillDistance = { { 8, 0.4 }, { 20, 1 }, { 40, 1.4 }, { math.huge, 1.8 } },

		SnapHead = 14,
		SnapBody = 5,

		KillWindow = 25,
		OneTapMinDist = 15,
		OneTapMinKills = 8,
		OneTapFloor = 0.45,
		OneTapScale = 60,
		OneTapMax = 18,

		HSWindow = 80,
		HSMinHits = 30,
		HSPrior = 20,
		HSBaseline = 0.2,
		HSFloor = 0.38,
		HSScale = 120,
		HSMax = 20,
	},

	-- Discord cheat-bot log (the webhook URL is in sv_secrets.lua)
	Discord = {
		Enabled = true,
		AimEvery = 120,     -- at most one aim-flag post per player this often (seconds); the rest are counted
		PostOnStart = true, -- "Anti-cheat online" post on every map load
	},

	-- Steam account checks on join (needs the Steam Web API key in sv_secrets.lua)
	SteamCheck = {
		Enabled = true,
		BanVAC = true,           -- a VAC ban on an account under VACLevelUnder = permanent ban (appeal in the Discord)
		VACLevelUnder = 3,       -- Steam level 0, 1 and 2. Admins / whitelisted are never banned. zac_steam_autoban 0 = off
		BanPrivateLevel = false, -- private profile (level can't be read): true = ban too, false = only logged
		BanGameBans = false,     -- other game bans (not VAC) too
		Exempt = {},             -- extra SteamIDs never banned by this (admins and zac whitelist are always exempt)
		BanMessage = "Your Steam account isn't allowed here please appeal in the discord",
		CacheHours = 12,
		Delay = 6,               -- seconds after joining (lets ULX give admins their rank first)
	},

	-- Auto-bans from the cheat rating. Admins / whitelisted are never auto-banned.
	AutoBan = {
		Enabled = true,
		Cheating = true,     -- rated CHEATING = permanent ban
		NearScore = 50,      -- this score or more (CHEATING is 60) from 2+ kinds of evidence = NearMinutes ban
		NearKinds = 2,
		NearMinutes = 10080, -- 7 days (0 = permanent)
		Message = "Cheating",
	},

	-- Airstuck / held movement and tick manipulation (sv_airstuck.lua)
	AirStuck = {
		Enabled = true,
		Gap = 0.5,          -- seconds without movement commands = held
		CountMin = 0.8,     -- held at least this long in the air = an incident (logged, counts towards a flag)
		Drop = 1.0,         -- held this long in the air = put back on the ground
		BlockFor = 0.75,    -- seconds after it ends: no shooting / damage
		Count = 2,          -- incidents in the air within Window seconds = flag
		LongHold = 2.5,     -- one hold this long (connection fine, not timing out) = flag straight away
		GroundHold = 2.0,   -- held this long ON the ground (freeze / teleport cheats) = an incident too
		Window = 60,
		Cooldown = 60,
		Points = 15,
		TickCheck = true,
		FutureTicks = 66,   -- commands stamped this many ticks ahead of the server...
		FutureCount = 20,   -- ...this many times in 3 s = tick manipulation flag
		TickPoints = 20,
	},

	-- Following hidden enemies through walls with the crosshair (sv_walltrack.lua)
	WallTrack = {
		Enabled = false, -- (off: it logged people just looking at each other through walls)
		Degrees = 4,     -- crosshair within this many degrees of a hidden enemy
		Seconds = 1.5,   -- for this long without a break...
		MinMove = 3,     -- ...while they moved at least this many metres
		MinTurn = 8,     -- ...and the view turned this many degrees to keep on them
		Range = 80, MinRange = 4, -- metres
		Points = 8,
		Cooldown = 15,
	},

	ScreengrabQuality = 55, -- JPG quality of the (720p) picture: ~100-200 KB
	ScreengrabTimeout = 60,
	ScreengrabMaxBytes = 4 * 1024 * 1024,
	ScreengrabKeep = 200,
}
for k, v in pairs(server) do ZAC.Config[k] = v end
