-- Persist connected time per player on this server, across rounds and maps.
local key = "chud_playtime_seconds"
local function Update(ply, save)
    if not IsValid(ply) or ply:IsBot() then return end
    local now = SysTime()
    if not ply.ChudPlaytimeSession then
        ply.ChudPlaytimeTotal = math.max(tonumber(ply:GetPData(key, "0")) or 0, 0)
        ply.ChudPlaytimeSession = now
    end
    local total = ply.ChudPlaytimeTotal + math.max(now - ply.ChudPlaytimeSession, 0)
    ply:SetNWFloat("ChudPlaytimeSeconds", total)
    if save then ply:SetPData(key, tostring(math.floor(total))) end
end

hook.Add("PlayerInitialSpawn", "ChudPlaytime", function(ply) Update(ply, false) end)
hook.Add("PlayerDisconnected", "ChudPlaytime", function(ply) Update(ply, true) end)
timer.Create("ChudPlaytime", 30, 0, function()
    for _, ply in ipairs(player.GetHumans()) do Update(ply, true) end
end)
hook.Add("ShutDown", "ChudPlaytime", function()
    for _, ply in ipairs(player.GetHumans()) do Update(ply, true) end
end)
