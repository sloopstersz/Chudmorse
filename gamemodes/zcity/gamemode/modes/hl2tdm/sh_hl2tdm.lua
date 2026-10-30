local MODE = MODE
MODE.name = "hl2tdm"
MODE.PrintName = "Half-Life 2 TDM"
MODE.Chance = 0.03
MODE.LootSpawn = false
MODE.ForBigMaps = false
MODE.OverrideSpawn = true
MODE.VoteTime = 10
MODE.start_time = 19
MODE.Scenarios = {
    {name = "7 Hour War", description = "Combine Vs National Guard", opposition = "National Guard"},
    {name = "Point Insertion", description = "Civil Vs Refugee", opposition = "Refugee"},
    {name = "The Uprising", description = "Combine Vs Rebel", opposition = "Rebel"},
    {name = "Red Letter Day", description = "Combine Vs Freeman and Rebel", opposition = "Freeman and Rebels"}
}
function MODE.GuiltCheck(attacker, victim)
    return attacker:Team() == victim:Team() and 1 or 0, true
end
