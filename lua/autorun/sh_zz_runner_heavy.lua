if SERVER then AddCSLuaFile() end
ZZAbilities = ZZAbilities or {}
local A = ZZAbilities
A.Slam = nil

local function ActiveClass(ply, class)
    return ZZInfection and ZZInfection.Active() and IsValid(ply) and ply:IsPlayer() and ply:Alive()
        and ZZIsZombie(ply) and ply:GetNWString("ZZZombieClass") == class and ply:Team() ~= TEAM_SPECTATOR
        and not IsValid(ply.FakeRagdoll) and not ply:InVehicle() and not ply.ZZExfilBoarded
end

-- Predicted on both sides; normal movement still performs collision and gravity.
-- No move-type or gravity changes are left behind when Space is released.
hook.Add("SetupMove", "ZZRunnerWallClimb", function(ply, mv, cmd)
    if not ActiveClass(ply, "runner") or ply:GetMoveType() ~= MOVETYPE_WALK or not cmd:KeyDown(IN_JUMP) then return end
    local forward = Angle(0, mv:GetAngles().y, 0):Forward()
    local start = mv:GetOrigin() + Vector(0, 0, 36)
    local wall = util.TraceHull({start = start, endpos = start + forward * 42,
        mins = Vector(-4, -4, -8), maxs = Vector(4, 4, 8), filter = ply, mask = MASK_PLAYERSOLID_BRUSHONLY})
    if not wall.Hit or wall.StartSolid or math.abs(wall.HitNormal.z) > 0.25 then return end
    local mins, maxs = ply:GetHull()
    if ply:Crouching() then mins, maxs = ply:GetHullDuck() end
    local ceiling = util.TraceHull({start = mv:GetOrigin(), endpos = mv:GetOrigin() + Vector(0, 0, 18),
        mins = mins, maxs = maxs, filter = ply, mask = MASK_PLAYERSOLID})
    if ceiling.StartSolid then return end
    ply:SetGroundEntity(NULL)
    local velocity = wall.HitNormal * -30
    velocity.z = ceiling.Hit and 0 or 160
    mv:SetVelocity(velocity)
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)
    mv:RemoveKey(IN_JUMP)
end)

function A.CanSlam() return false, "Ground Slam has been removed." end
A.SlamTarget = nil
hook.Remove("radialOptions", "ZZHeavySlam")
if SERVER then
    util.AddNetworkString("ZZHeavySlam")
    net.Receive("ZZHeavySlam", function() end)
else
    hook.Add("radialOptions", "ZZHeavySlam", function()
        if not ActiveClass(LocalPlayer(), "runner") then return end
        hg.radialOptions[#hg.radialOptions + 1] = {function()
            chat.AddText(Color(220, 220, 220), "Wall Crawl: face a wall and hold SPACE to climb. Release SPACE to stop. No point cost.")
        end, "Wall Crawl\nHold SPACE | Free", nil, nil, Material("icon16/arrow_up.png")}
    end)
    hook.Add("HUDPaint", "ZZRunnerClimbHint", function()
        if not ActiveClass(LocalPlayer(), "runner") then return end
        draw.SimpleText("Hold SPACE against a wall to climb", "DermaDefaultBold", 24, ScrH() * 0.72 + 52, Color(220, 220, 220))
    end)
end
