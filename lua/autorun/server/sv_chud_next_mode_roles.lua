-- Scoreboard assignments apply once, when the matching mode chooses its roles.
util.AddNetworkString("Chud_SetNextModeRole")
local pending = {}
local labels = {juggernaut = "Juggernaut", vip = "VIP", infector = "Infector"}

net.Receive("Chud_SetNextModeRole", function(_, admin)
    if not IsValid(admin) or not admin:IsSuperAdmin() then return end
    local target = net.ReadEntity()
    local role = net.ReadString()
    if not labels[role] or not IsValid(target) or not target:IsPlayer() then return end
    pending[role] = target
    admin:ChatPrint(target:Nick() .. " will be " .. labels[role] .. " in the next matching gamemode round.")
end)

function ChudTakeNextModeRole(role, candidates)
    local target = pending[role]
    if not IsValid(target) then pending[role] = nil return end
    for _, ply in ipairs(candidates) do
        if ply == target then
            pending[role] = nil
            return target
        end
    end
    -- Spectators remain queued until they join a matching round.
end
