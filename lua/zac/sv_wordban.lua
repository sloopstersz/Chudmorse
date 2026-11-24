-- Automatic ban for slurs in chat. The message is never shown; the player is banned straight away
-- (1 hour by default - zac_wordban_minutes, 0 = permanent; synced to ULX like every ZAC ban) with the reason stated, and it shows up in the
-- zac_menu logs and the bans list. Superadmins are never auto-banned (so the owner can't lock
-- themselves out by quoting someone).
--   zac_wordban 0/1   turn it off / on
-- Catches common dodges: capitals, l33t letters (n1gg3r), repeated letters (niiigger), symbols
-- between letters (n.i.g.g.e.r) and spaced-out letters (n i g g e r).
local cv = CreateConVar("zac_wordban", "1", { FCVAR_ARCHIVE }, "1 = automatically ban players who use slurs in chat", 0, 1)
local cvMins = CreateConVar("zac_wordban_minutes", "60", { FCVAR_ARCHIVE }, "How long the automatic slur ban lasts in minutes (0 = permanent)", 0, 525600)
function ZAC.WordBanMinutes() return cvMins:GetInt() end
local cvShow = CreateConVar("zac_wordban_show", "3", { FCVAR_ARCHIVE }, "Seconds of firework before the ban (0 = ban straight away)", 0, 10)

-- the send-off: forced into a ragdoll (no getting up) and launched into the sky like a firework
local COLORS = { Color(255, 60, 60), Color(60, 255, 90), Color(70, 140, 255), Color(255, 220, 60), Color(255, 90, 230) }
local ROCKET = "weapons/rpg/rocket1.wav"
-- stop the rocket noise (it loops) on the player and their ragdoll
function ZAC.FireworkStop(ply)
	if not IsValid(ply) then return end
	if ply.ZACRocket then ply.ZACRocket:Stop() ply.ZACRocket = nil end
	ply:StopSound(ROCKET)
	if IsValid(ply.FakeRagdoll) then ply.FakeRagdoll:StopSound(ROCKET) end
	timer.Remove("zac_firework_" .. ply:EntIndex())
end
hook.Add("PlayerDisconnected", "zac_firework_stop", function(ply) ZAC.FireworkStop(ply) end)

function ZAC.Firework(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	ZAC.FireworkStop(ply)
	ply.ZACRocket = CreateSound(ply, ROCKET)
	ply.ZACRocket:SetSoundLevel(90)
	ply.ZACRocket:Play()
	ply:GodEnable() -- nothing kills them before the ban
	if ply:InVehicle() then ply:ExitVehicle() end
	if ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
	if hg and hg.Fake then pcall(hg.Fake, ply, nil, nil, true) end
	local function body() return IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply end
	local function launch(force)
		local e = body()
		if e:IsRagdoll() then
			for i = 0, e:GetPhysicsObjectCount() - 1 do
				local ph = e:GetPhysicsObjectNum(i)
				if IsValid(ph) then ph:SetVelocity(Vector(math.Rand(-60, 60), math.Rand(-60, 60), force) + VectorRand() * 40) end
			end
		else
			e:SetVelocity(Vector(0, 0, force))
		end
	end
	timer.Simple(0.1, function() if IsValid(ply) then launch(1100) end end)
	-- keep them ragdolled and pushing up, with a spark trail
	local id = "zac_firework_" .. ply:EntIndex()
	local show = math.max(cvShow:GetFloat(), 0.5)
	local ticks = math.floor(show / 0.1)
	timer.Create(id, 0.1, ticks, function()
		if not IsValid(ply) then timer.Remove(id) return end
		-- no getting up: ragdoll them again straight away
		if hg and hg.Fake and not IsValid(ply.FakeRagdoll) and ply:Alive() then pcall(hg.Fake, ply, nil, nil, true) end
		if timer.RepsLeft(id) > ticks * 0.4 then launch(700) end
		local ed = EffectData()
		ed:SetOrigin(body():WorldSpaceCenter())
		ed:SetMagnitude(2) ed:SetScale(1) ed:SetRadius(4)
		util.Effect("Sparks", ed, true, true)
		if timer.RepsLeft(id) == 0 then
			-- the bang (and the rocket noise stops)
			local pos = body():WorldSpaceCenter()
			if ply.ZACRocket then ply.ZACRocket:Stop() ply.ZACRocket = nil end
			ply:StopSound(ROCKET)
			if IsValid(ply.FakeRagdoll) then ply.FakeRagdoll:StopSound(ROCKET) end
			sound.Play("ambient/explosions/explode_" .. math.random(1, 4) .. ".wav", pos, 120, 110)
			sound.Play("weapons/flaregun/fire.wav", pos, 100, 80)
			for k = 1, 6 do
				local ex = EffectData()
				ex:SetOrigin(pos + VectorRand() * 60)
				ex:SetScale(2) ex:SetMagnitude(4)
				util.Effect(k == 1 and "Explosion" or "cball_explode", ex, true, true)
			end
			for k = 1, 5 do
				local c = COLORS[k]
				local b = EffectData()
				b:SetOrigin(pos + VectorRand() * 80)
				b:SetStart(Vector(c.r, c.g, c.b))
				util.Effect("balloon_pop", b, true, true)
			end
		end
	end)
end

-- written with repeated letters squashed (nigger -> niger, faggot -> fagot)
local WORDS = {
	niger = "n-word", nigers = "n-word", niga = "n-word", nigas = "n-word", nigaz = "n-word",
	fag = "f-slur", fags = "f-slur", fagot = "f-slur", fagots = "f-slur",
	foid = "foid", foids = "foid",
}

local LEET = { ["0"] = "o", ["1"] = "i", ["!"] = "i", ["|"] = "i", ["3"] = "e", ["4"] = "a", ["@"] = "a", ["5"] = "s", ["$"] = "s", ["7"] = "t", ["9"] = "g", ["6"] = "g" }

local function squash(w)
	local out, last = {}, nil
	for i = 1, #w do
		local c = string.sub(w, i, i)
		if c ~= last then out[#out + 1] = c last = c end
	end
	return table.concat(out)
end

-- returns the matched label or nil
-- "fag" is also British slang for a cigarette: don't ban when it's clearly about smoking
local SMOKE = { "smoke", "smoking", "cig", "ciggy", "ciggie", "lighter", "tobacco", "rollie", "baccy", "lung",
	"for a fag", "a fag break", "fag break", "have a fag", "having a fag", "pack of fags", "packet of fags", "box of fags", "need a fag", "want a fag", "spare a fag", "got a fag" }
local function smokeTalk(t)
	for _, s in ipairs(SMOKE) do if string.find(t, s, 1, true) then return true end end
	return false
end

local function check(text)
	local t = string.lower(text or "")
	local raw = t
	t = string.gsub(t, ".", function(c) return LEET[c] or c end)
	-- symbols between letters (n.i.g.g.e.r / n-i-g-g-e-r) -> joined
	t = string.gsub(t, "(%a)[%.%-_%*,'`~]+(%a)", "%1%2")
	t = string.gsub(t, "(%a)[%.%-_%*,'`~]+(%a)", "%1%2")
	local words = {}
	for w in string.gmatch(t, "%a+") do words[#words + 1] = w end
	for _, w in ipairs(words) do
		local sq = squash(w)
		local hit = WORDS[sq]
		if hit and not ((sq == "fag" or sq == "fags") and smokeTalk(raw)) then return hit end
	end
	-- spaced out single letters: "n i g g e r"
	local run = ""
	for i = 1, #words + 1 do
		local w = words[i]
		if w and #w == 1 then run = run .. w
		else
			if #run >= 3 then local hit = WORDS[squash(run)] if hit then return hit end end
			run = ""
		end
	end
end
ZAC.WordBanCheck = check

-- the whole thing: announce, log, firework, then ban (bots are kicked instead - they have no real SteamID)
function ZAC.WordBanPunish(ply, hit, text)
	if not IsValid(ply) or ply.ZACFireworked then return end
	if ZAC.ManualOnly and ZAC.ManualOnly() then
		ZAC.Log("access", (ZAC.Who and ZAC.Who(ply) or ply:Nick()) .. " used a slur (not banned: manual mode): " .. hit,
			"Message: " .. string.sub(text or "", 1, 200) .. "\nTo ban by hand: zac ban " .. ply:SteamID() .. " hate speech", ply)
		return
	end
	ply.ZACFireworked = true
	local mins = ZAC.WordBanMinutes()
	local length = mins <= 0 and "permanent" or (mins % 60 == 0 and (mins / 60 .. " hour" .. (mins == 60 and "" or "s")) or (mins .. " min"))
	local reason = "Automatic ban (" .. length .. "): hate speech in chat (" .. hit .. ")"
	local sid64, name, ip, bot = ply:SteamID(), ply:Nick(), ply:IPAddress(), ply:IsBot() -- (a SteamID, despite the name)
	ZAC.Log("access", (ZAC.Who and ZAC.Who(ply) or name) .. " was auto-banned: " .. hit, "Message: " .. string.sub(text or "", 1, 200), ply)
	for _, p in player.Iterator() do
		if p ~= ply then p:ChatPrint("[ZAC] " .. name .. " was banned: " .. reason) end
	end
	ZAC.Firework(ply)
	-- banned after the show (by SteamID, so leaving early doesn't dodge it)
	timer.Simple(cvShow:GetFloat(), function()
		ZAC.FireworkStop(ply) -- silence the moment they're banned
		if bot then
			if IsValid(ply) then ply.ZACFireworked = nil ply:Kick(ZAC.PublicMessage and ZAC.PublicMessage() or reason) end
		elseif ZAC.Ban then
			ZAC.Ban(sid64, reason, name, ip, "ZAC (auto)", nil, ZAC.WordBanMinutes())
		end
	end)
end

hook.Add("PlayerSay", "zac_wordban", function(ply, text)
	if not cv:GetBool() or not IsValid(ply) or ply:IsBot() then return end
	local hit = check(text)
	if not hit then return end
	if ply:IsSuperAdmin() then return end
	ZAC.WordBanPunish(ply, hit, text)
	return "" -- the message is never shown
end, HOOK_HIGH)

-- testing (superadmins / server console), nothing gets banned:
--   zac_firework_test            fireworks you
--   zac_firework_test bot        fireworks the first player whose name contains "bot"
--   zac_wordban_test <text>      says whether that text would trigger the auto-ban
concommand.Add("zac_firework_test", function(ply, _, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local target = IsValid(ply) and ply or nil
	if args[1] then
		local q = string.lower(args[1])
		for _, p in player.Iterator() do if string.find(string.lower(p:Nick()), q, 1, true) then target = p break end end
	end
	if not IsValid(target) then print("[ZAC] Nobody to firework.") return end
	ZAC.Firework(target)
	timer.Simple(cvShow:GetFloat() + 1, function() if IsValid(target) then ZAC.FireworkStop(target) target:GodDisable() end end)
	local m = "[ZAC] Firework test on " .. target:Nick() .. " (no ban)."
	if IsValid(ply) then ply:ChatPrint(m) else print(m) end
end)

concommand.Add("zac_wordban_test", function(ply, _, args, argStr)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local function say(m) if IsValid(ply) then ply:ChatPrint(m) else print(m) end end
	-- a player's name (e.g. bot01): run the whole auto-ban on them as if they'd said a slur
	local q = string.lower(args[1] or "")
	if q ~= "" and #args == 1 then
		for _, p in player.Iterator() do
			if string.find(string.lower(p:Nick()), q, 1, true) then
				if p == ply then say("[ZAC] Not on yourself - use zac_firework_test for that.") return end
				say("[ZAC] Running the auto-ban on " .. p:Nick() .. (p:IsBot() and " (bot: kicked instead of banned)" or " - this WILL ban them"))
				ZAC.WordBanPunish(p, "test", "(zac_wordban_test)")
				return
			end
		end
	end
	-- otherwise: does this text trigger it?
	local hit = check(argStr or "")
	say("[ZAC] \"" .. tostring(argStr) .. "\" -> " .. (hit and ("WOULD BAN (" .. hit .. ")") or "fine"))
end)
