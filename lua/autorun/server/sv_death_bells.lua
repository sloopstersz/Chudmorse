local NET_MESSAGE = "Chudmorse_PlayDeathBell"

util.AddNetworkString(NET_MESSAGE)

for index = 1, 4 do
    resource.AddFile("sound/chudmorse_death_bells/bell" .. index .. ".mp3")
end

hook.Add("PlayerDeath", "Chudmorse_RandomDeathBell", function()
    -- This sound belongs only to active Chud Beasts rounds. The original
    -- global hook had no mode check, so every gamemode triggered it.
    if not zb or zb.CROUND ~= "chudbeasts" or zb.ROUND_STATE ~= 1 then return end

    net.Start(NET_MESSAGE)
        net.WriteUInt(math.random(1, 4), 3)
    net.Broadcast()
end)
