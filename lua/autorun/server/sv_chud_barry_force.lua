-- Admin toggle: force Barry's music kit on for every player.
-- While forced, players can't turn it off; running the command again releases it
-- and everyone goes back to their own chud_barry_music setting.
local function Reply(ply, text)
    if IsValid(ply) then ply:ChatPrint(text) else print(text) end
end

local function ToggleForce(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        Reply(ply, "Only admins can force Barry's music kit.")
        return
    end
    local on = not GetGlobalBool("ChudBarryForced", false)
    SetGlobalBool("ChudBarryForced", on)
    local who = IsValid(ply) and ply:Nick() or "Console"
    if on then
        PrintMessage(HUD_PRINTTALK, "[Chudmorse] " .. who .. " forced Barry's music kit on for everyone.")
    else
        PrintMessage(HUD_PRINTTALK, "[Chudmorse] " .. who .. " released Barry's music kit. Your own setting is back.")
    end
end

concommand.Add("chud_barry_force", function(ply) ToggleForce(ply) end)

hook.Add("PlayerSay", "ChudBarryForce", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t == "!barry" or t == "/barry" then
        ToggleForce(ply)
        return ""
    end
end)
