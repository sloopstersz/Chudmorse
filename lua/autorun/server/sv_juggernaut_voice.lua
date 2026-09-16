-- Fat Chud / Juggernaut combat voice lines.
-- Works for the actual Juggernaut round and for admins assigning the
-- juggernaut player class from the context menu.

local JUGGERNAUT_VOICE_LINES = {
    "juggernaut/voices/dozer1.mp3",
    "juggernaut/voices/dozer2.mp3",
    "juggernaut/voices/dozer3.mp3",
    "juggernaut/voices/dozer4.mp3",
    "juggernaut/voices/dozer5.mp3",
    "juggernaut/voices/dozer6.mp3",
    "juggernaut/voices/dozer7.mp3"
}

local VOICE_COOLDOWN = 7.5

local function IsFatChudClass(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and ply.PlayerClassName == "juggernaut"
end

local function IsFatChud(ply)
    return IsFatChudClass(ply) and ply:Alive()
end

local function PlayFatChudVoice(ply)
    if not IsFatChud(ply) then return false end
    if (ply.RemorseNextJuggernautVoice or 0) > CurTime() then return false end

    local count = #JUGGERNAUT_VOICE_LINES
    if count <= 0 then return false end

    local index = math.random(count)
    if count > 1 and index == ply.RemorseLastJuggernautVoice then
        index = (index % count) + 1
    end

    ply.RemorseLastJuggernautVoice = index
    ply.RemorseNextJuggernautVoice = CurTime() + VOICE_COOLDOWN

    -- Entity EmitSound keeps the line positional/3D instead of broadcasting it globally.
    ply:EmitSound(JUGGERNAUT_VOICE_LINES[index], 90, 100, 1, CHAN_AUTO)
    return true
end

-- The Fat Chud must never fall back to Remorse's normal human/class voice lines.
-- This is a final safety net in addition to the phrase-system checks in
-- sv_phrases.lua. It only blocks speech-like sounds, not guns, footsteps,
-- armor, equipment, etc. The seven Dozer clips are always allowed.
local ALLOWED_FAT_CHUD_VOICES = {}
for _, snd in ipairs(JUGGERNAUT_VOICE_LINES) do
    ALLOWED_FAT_CHUD_VOICES[string.lower(snd)] = true
end

local BLOCKED_VOICE_PREFIXES = {
    "vo/",
    "screams/",
    "zcitysnd/male/",
    "zcitysnd/female/",
    "mercenary/",
    "specops/",
    "national_guard/",
    "n51/",
    "zbattle/laugh/",
    "ground_control/radio/ghetto/"
}

local function IsSpeechSound(soundName)
    local snd = string.lower(soundName or "")
    if snd == "" then return false end
    if ALLOWED_FAT_CHUD_VOICES[snd] then return false end

    for _, prefix in ipairs(BLOCKED_VOICE_PREFIXES) do
        if string.StartWith(snd, prefix) then
            return true
        end
    end

    -- Catch common voice folders/sound names used by addons without
    -- accidentally muting ordinary weapon/equipment sounds.
    if string.find(snd, "/vo/", 1, true) then return true end
    if string.find(snd, "scream", 1, true) then return true end
    if string.find(snd, "moan", 1, true) then return true end
    if string.find(snd, "laugh", 1, true) then return true end

    return false
end

hook.Add("EntityEmitSound", "RemorseJuggernautExclusiveVoices", function(soundData)
    local ent = soundData.Entity
    if not IsValid(ent) then return end

    local ply = ent
    if not ply:IsPlayer() and hg and hg.RagdollOwner then
        ply = hg.RagdollOwner(ent)
    end

    if not IsFatChudClass(ply) then return end
    if not IsSpeechSound(soundData.SoundName or soundData.OriginalSoundName) then return end

    return false
end)

-- A Juggernaut kill always tries to play a taunt, subject to the cooldown.
hook.Add("PlayerDeath", "RemorseJuggernautKillVoice", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == victim then return end
    if not IsFatChud(attacker) then return end

    PlayFatChudVoice(attacker)
end)

-- Taking a meaningful hit can also trigger a line, but only occasionally so
-- automatic weapons do not make the voice spam constantly.
hook.Add("EntityTakeDamage", "RemorseJuggernautDamageVoice", function(ent, dmgInfo)
    local ply = ent
    if not IsValid(ply) then return end

    if not ply:IsPlayer() and hg and hg.RagdollOwner then
        ply = hg.RagdollOwner(ply)
    end

    if not IsFatChud(ply) then return end
    if dmgInfo:GetDamage() < 20 then return end
    if math.random(1, 100) > 25 then return end

    PlayFatChudVoice(ply)
end)
