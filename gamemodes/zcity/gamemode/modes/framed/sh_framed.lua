local MODE = MODE
MODE.name = "framed"
MODE.PrintName = "Framed"
MODE.Chance = 0.1
MODE.ForBigMaps = false
MODE.SubModes = false
MODE.Description = "One killer, a list of targets, and a crowd of suspects. Nobody knows who is who."

--\\ Text
MODE.Title = "Framed!"
MODE.Subtitle = "It can be me, It could be you or him..."

MODE.CrewRoles = {
	civilian = {
		line = "You are a civilian.",
		sub = "Stay in crowds make the killer job harder.",
		color = Color(60, 205, 90),
	},
	cop = {
		line = "You are a police officer",
		sub = "Try not to kill the innocents and find out who is the killer.",
		color = Color(50, 120, 255),
	},
}

-- Shown (top right) to the killer when a target dies and it was NOT the killer's work.
MODE.TargetDownLines = {
	"Looks like someone did the job for me",
	"Idiots, it's too easy",
	"Wow, That saves up time",
	"Better for me",
}

MODE.EndTextEscaped = "The killer has gotten away with his crimes"
MODE.EndTextFailed = "The killer failed..."
--//

--\\ Tunables
MODE.KillTime = 11 * 60            -- seconds the killer has, counted from the moment the killer is released
MODE.KillerIntroDuration = 10      -- killer sees the MW3 style briefing and is held in place for this long (F skips it)
MODE.CrewIntroDuration = 10        -- civilians / cops get the riot style text intro for this long
MODE.KillerSkipKey = KEY_F         -- key the killer presses to skip the briefing

MODE.BigLobbyThreshold = 10        -- more than this many players = big lobby
MODE.SmallLobbyTargets = 3         -- targets in a small lobby
MODE.BigLobbyTargets = 5           -- targets in a big lobby
MODE.FourCopsMinPlayers = 12       -- below this there are 3 cops, from this on there are 4
--//

--\\ Intro music (files live in sound/framed/, played with sound.PlayFile like the other modes)
MODE.Sounds = {
	killer = "sound/framed/killer_intro.mp3",
	civilian = "sound/framed/civilian_intro.mp3",
	cop = "sound/framed/cop_intro.mp3",
}

MODE.MusicVolume = 0.6             -- built-in loudness of the intro tracks (1 = the file's own level). framed_music_volume multiplies this.

MODE.KillerMusicFadeIn = 0.6       -- seconds
MODE.KillerMusicFadeStart = 7      -- seconds after the briefing starts when the music begins to get quieter
MODE.KillerMusicFadeOut = 5        -- seconds it takes to reach silence (7 + 5 = it ends 2s after the briefing is over)
MODE.KillerMusicSkipFade = 2       -- seconds, when the killer skips the briefing with F
MODE.CrewMusicFadeOut = 6          -- seconds, civilians: starts after CrewIntroDuration, cops: starts when the startup screen is done
--//


MODE.NumberWords = {"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"}

function MODE.GetTargetCount(playerCount)
	return math.Clamp(math.floor((playerCount > MODE.BigLobbyThreshold) and MODE.BigLobbyTargets or MODE.SmallLobbyTargets), 1, 15)
end

-- Always leaves at least as many civilians as cops so tiny lobbies still work.
function MODE.GetCopCount(playerCount)
	local want = (playerCount >= MODE.FourCopsMinPlayers) and 4 or 3
	return math.Clamp(math.min(want, math.floor((playerCount - 1) / 2)), 0, 4)
end

--\\ Killer briefing hold (killer can look around but not move / act while the briefing plays)
function MODE.IsHeld(ply)
	if not IsValid(ply) then return false end

	if SERVER then
		return (ply.FramedHoldUntil or 0) > CurTime()
	end

	return ply == LocalPlayer() and (MODE.HoldUntil or 0) > CurTime()
end

function MODE:StartCommand(ply, cmd)
	if not MODE.IsHeld(ply) then return end

	cmd:ClearMovement()

	for _, key in ipairs({IN_ATTACK, IN_ATTACK2, IN_USE, IN_JUMP, IN_DUCK}) do
		cmd:RemoveKey(key)
	end
end

function MODE:Move(ply, mv)
	if not MODE.IsHeld(ply) then return end

	mv:SetVelocity(vector_origin)
	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)

	return true
end

function MODE:HG_MovementCalc_2(mul, ply, cmd, mv)
	if not MODE.IsHeld(ply) then return end

	if cmd then cmd:RemoveKey(IN_ATTACK) cmd:RemoveKey(IN_ATTACK2) end
	-- Attack buttons are removed from CUserCmd above; Move handles speed/velocity.
end

function MODE:PlayerCanLegAttack(ply)
	if MODE.IsHeld(ply) then return false end
end
--//
