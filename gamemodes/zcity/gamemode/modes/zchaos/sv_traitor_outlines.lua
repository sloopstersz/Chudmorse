if not SERVER then return end
-- Entity indices distinguish every teammate, including bots with identical SteamIDs.
util.AddNetworkString("CHAOS_TraitorOutlineRoster")

timer.Create("CHAOS_TraitorOutlineRoster", 0.5, 0, function()
    local active = zb and zb.CROUND == "chaos" and zb.ROUND_STATE == 1
    local roster = {}
    if active then
        for _, ply in player.Iterator() do
            if ply.isTraitor and ply:Alive() then roster[#roster + 1] = ply:EntIndex() end
        end
    end
    table.sort(roster)
    local signature = table.concat(roster, ",")

    for _, recipient in player.Iterator() do
        if not recipient:IsBot() then
            local allowed = active and recipient.isTraitor and recipient:Alive()
            local current = allowed and signature or ""
            if recipient.ChudOutlineRoster ~= current then
                recipient.ChudOutlineRoster = current
                net.Start("CHAOS_TraitorOutlineRoster")
                net.WriteUInt(allowed and #roster or 0, 16)
                if allowed then
                    for _, index in ipairs(roster) do net.WriteUInt(index, 16) end
                end
                net.Send(recipient)
            end
        end
    end
end)
