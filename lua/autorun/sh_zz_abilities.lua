if SERVER then AddCSLuaFile() end
ZZAbilities = ZZAbilities or {}
-- Retain harmless compatibility stubs for older clients and gas entities.
function ZZAbilities.CanUseAirborne() return false, "Airborne Infection has been removed." end
function ZZAbilities.HasGasMask(ply) return ply.armors and ply.armors.face == "mask2" end
hook.Remove("radialOptions", "ZZZombieAbilities")
if SERVER then
    util.AddNetworkString("ZZUseAirborne")
    net.Receive("ZZUseAirborne", function() end)
    local function Cleanup()
        for _, cloud in ipairs(ents.FindByClass("zz_infection_gas")) do cloud:Remove() end
    end
    hook.Add("ZB_EndRound", "ZZAirborneCleanup", Cleanup)
    hook.Add("PostCleanupMap", "ZZAirborneCleanup", Cleanup)
    timer.Simple(0, Cleanup)
end
