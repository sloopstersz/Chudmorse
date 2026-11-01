local MODE = MODE

MODE.name = "zzombies"
MODE.PrintName = "Z-Zombies"
MODE.Description = "Survive three phases of the outbreak, then get to the extraction point before the National Guard's window closes."

-- Infected players are on the survivors' team, so shooting a zombie counted as a teamkill.
-- Same flag the VIP and Juggernaut modes use to turn karma/guilt loss off.
MODE.GuiltDisabled = true

-- Three phases inside one round.
MODE.PhaseCount = 3
MODE.PhaseDuration = 300

-- Seconds of "Prepare for the next Phase" between one phase ending and the next starting.
MODE.PhaseCooldown = 60

-- Length of the riot-style startup screen, in seconds.
MODE.IntroDuration = 7

MODE.Phases = {
	[1] = {number = "One",   name = "Containment Outbreak"},
	[2] = {number = "Two",   name = "Escalation"},
	[3] = {number = "Three", name = "Infestation"}
}

-- Extraction, in the last phase. The clock starts when the phase does: after
-- ExtractionDelay the helicopter arrives and the National Guard come in, and the survivors
-- then have ExtractionWindow seconds to get out after the guard intro.
-- 170 seconds of approach + 10 seconds of intro + 120 seconds to extract = 300.
MODE.ExtractionDelay = 170   -- seconds from the start of the last phase until the helicopter arrives
MODE.ExtractionWindow = 120  -- seconds survivors have to extract once the National Guard are in
MODE.ExtractionRadius = 100  -- size of the extraction zone
MODE.ExtractionHold = 10     -- seconds you have to stay inside the zone to be extracted

-- National Guard arrival.
MODE.GuardMax = 5            -- most players that can be picked
MODE.GuardIntroDuration = 10 -- length of their intro, in seconds
MODE.GuardPreroll = 2        -- their song starts this many seconds before the intro does

-- Point groups for the zbattle toolgun.
zb = zb or {}
zb.Points = zb.Points or {}

-- Where survivors can reach extraction in the last phase.
zb.Points.zzombiesextraction = zb.Points.zzombiesextraction or {}
zb.Points.zzombiesextraction.Color = Color(60, 200, 90)
zb.Points.zzombiesextraction.Name = "zzombiesextraction"

-- Where the National Guard arrives.
zb.Points.zzombiesguard = zb.Points.zzombiesguard or {}
zb.Points.zzombiesguard.Color = Color(60, 90, 0)
zb.Points.zzombiesguard.Name = "zzombiesguard"

-- Ground-level landing locations for the downtime supply crate.
zb.Points.zzombiessupply = zb.Points.zzombiessupply or {}
zb.Points.zzombiessupply.Color = Color(230, 160, 45)
zb.Points.zzombiessupply.Name = "zzombiessupply"

-- Zombie respawn locations, editable and saved per map by the zbattle editor.
zb.Points.zzombiesspawn = zb.Points.zzombiesspawn or {}
zb.Points.zzombiesspawn.Color = Color(190, 30, 30)
zb.Points.zzombiesspawn.Name = "Zombie Spawns"

-- Indoor alternative: these points take priority over helicopter landing points.
zb.Points.zzombiesgroundextraction = zb.Points.zzombiesgroundextraction or {}
zb.Points.zzombiesgroundextraction.Color = Color(70, 220, 180)
zb.Points.zzombiesgroundextraction.Name = "Zombie Ground Extraction"
