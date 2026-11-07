-- DRAGON STYLE HIT SETTINGS (server). Times are seconds from animation start.
-- fraction = 0.65 means 65% of the paired move duration; use time instead for exact seconds.
-- bone selects where the blood appears. Set blood=false for a closed fracture.
-- breakArm = "rarm" or "larm" applies a real organism fracture (1 = broken).
-- Each move deals damage ONCE, independently of the number of visual blood hits.
-- Sounds use built-in game assets. Override any hit with sound="path.wav",
-- sound={"first.wav", "second.wav"}, or sound=false to silence that impact.
-- Per-hit soundLevel, volume, pitchMin and pitchMax override these defaults.
local IMPACTS = {"physics/body/body_medium_impact_hard1.wav", "physics/body/body_medium_impact_hard2.wav", "physics/body/body_medium_impact_hard3.wav"}
local BREAKS = {"physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav"}
local HEAD = "ValveBiped.Bip01_Head1"
local ARM = "ValveBiped.Bip01_R_Forearm"
return {
    dragon_beast_piledive = {hits = {{fraction = 0.65, bone = HEAD}}},
    default = {impactSounds = IMPACTS, fractureSounds = BREAKS, soundLevel = 75, volume = 1, pitchMin = 95, pitchMax = 105, damage = 55, damageFraction = 0.65, hits = {{fraction = 0.65, bone = HEAD}}},
    dragon_brawling = {hits = {{time = 0.25, bone = HEAD}, {time = 0.9, bone = HEAD}, {time = 2.5, bone = HEAD}}},
    dragon_disarming = {hits = {{time = 1.4, bone = HEAD}, {time = 3.1, bone = HEAD}}},
    dragon_rush_barrage = {hits = {{time = 1, bone = HEAD}, {time = 2, bone = HEAD}, {time = 3, bone = HEAD}, {time = 4.2, bone = HEAD}, {time = 5.8, bone = HEAD}}},
    dragon_rush_crushing = {hits = {{time = 0.7, bone = ARM, blood = false, breakArm = "rarm"}, {time = 2, bone = HEAD}}},
    dragon_rush_wall = {hits = {{time = 1, bone = ARM, blood = false, breakArm = "rarm"}, {time = 3.8, bone = HEAD}, {time = 6.7, bone = HEAD}}},
    dragon_tigerdrop = {hits = {{time = 0.1, bone = "ValveBiped.Bip01_Spine2", disarm = true}}},
}
