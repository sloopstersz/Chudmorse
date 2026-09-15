if not SERVER then return end

-- Chudmorse music bundled with the separate FPV addon.
-- Keep the actual sound files under sound/chudmorse_music/.
local musicFiles = {
    "sound/chudmorse_music/receive_you_tech_trance_arrange.mp3",
    "sound/chudmorse_music/reign.mp3",
    "sound/chudmorse_music/tusk.mp3",
}

for _, path in ipairs(musicFiles) do
    resource.AddFile(path)
end
