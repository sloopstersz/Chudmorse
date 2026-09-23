local deathBells = {
    "chudmorse_death_bells/bell1.mp3",
    "chudmorse_death_bells/bell2.mp3",
    "chudmorse_death_bells/bell3.mp3",
    "chudmorse_death_bells/bell4.mp3"
}

net.Receive("Chudmorse_PlayDeathBell", function()
    local soundPath = deathBells[net.ReadUInt(3)]
    if soundPath then
        surface.PlaySound(soundPath)
    end
end)
