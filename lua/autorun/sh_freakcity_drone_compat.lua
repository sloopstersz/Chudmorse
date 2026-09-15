if SERVER then
    AddCSLuaFile()
end

FreakCityDrone = FreakCityDrone or {}

function FreakCityDrone.GetActive(ply)
    if not IsValid(ply) then return nil, nil end

    local drone = ply:GetNWEntity("kamikaze_")
    if not IsValid(drone) then
        drone = ply:GetNWEntity("active_mavic")
    end

    if not IsValid(drone) then return nil, nil end

    local class = drone:GetClass()
    if class == "dji_mavic3" or string.find(class, "mavic", 1, true) then
        return drone, "mavic"
    elseif class == "fpv_at" then
        return drone, "at"
    end

    return drone, "kamikaze"
end

if SERVER then
    util.AddNetworkString("FreakCityDrone_SetFlashlight")
    util.AddNetworkString("FreakCityDrone_CameraAim")

    net.Receive("FreakCityDrone_SetFlashlight", function(_, ply)
        local enabled = net.ReadBool()
        local drone = FreakCityDrone.GetActive(ply)
        if not IsValid(drone) or not drone.GetDriver or drone:GetDriver() ~= ply then return end
        if drone.FCWaterFailure or drone.FCExploded or drone:GetNWBool("Kamikaze_DeadBattery", false) then return end
        drone:SetNWBool("Kamikaze_Flashlight", enabled)
    end)

    net.Receive("FreakCityDrone_CameraAim", function(_, ply)
        local pitch = math.Clamp(net.ReadFloat(), -85, 85)
        local yaw = math.NormalizeAngle(net.ReadFloat())
        local drone = FreakCityDrone.GetActive(ply)
        if not IsValid(drone) or not drone.GetDriver or drone:GetDriver() ~= ply then return end
        if CurTime() < (ply.FCNextDroneAimUpdate or 0) then return end
        ply.FCNextDroneAimUpdate = CurTime() + 0.01
        drone.FCCameraAim = Angle(pitch, yaw, 0)
    end)

    hook.Add("StartCommand", "FreakCityDrone_LockPlayerBody", function(ply, cmd)
        local drone = FreakCityDrone.GetActive(ply)
        if not IsValid(drone) or not drone.GetDriver or drone:GetDriver() ~= ply then return end

        local state = ply.FCDroneState
        local locked = state and state.ang or ply:EyeAngles()
        cmd:SetViewAngles(Angle(locked.p, locked.y, 0))
        cmd:ClearMovement()
    end)

    hook.Add("KeyPress", "FreakCityDrone_Controls", function(ply, key)
        local drone = FreakCityDrone.GetActive(ply)
        if not IsValid(drone) or drone:GetDriver() ~= ply then return end

        if key == IN_USE and drone.SetDriver then
            drone:SetNWBool("Kamikaze_Flashlight", false)
            drone:SetDriver(NULL)
        end
    end)

    hook.Add("SetupPlayerVisibility", "FreakCityDrone_PVS", function(ply)
        local drone = FreakCityDrone.GetActive(ply)
        if IsValid(drone) then
            AddOriginToPVS(drone:GetPos())
        end
    end)

    local function cleanupPlayerDrone(ply)
        local drone = FreakCityDrone.GetActive(ply)
        if IsValid(drone) and drone.SetDriver then
            drone:SetNWBool("Kamikaze_Flashlight", false)
            drone:SetDriver(NULL)
        end
    end

    hook.Add("PlayerDeath", "FreakCityDrone_DeathCleanup", cleanupPlayerDrone)
    hook.Add("PlayerDisconnected", "FreakCityDrone_DisconnectCleanup", cleanupPlayerDrone)
    return
end

local fullscreen = CreateClientConVar("fc_drone_fullscreen", "1", true, false, "Use fullscreen drone camera", 0, 1)
local sensitivity = CreateClientConVar("fc_drone_camera_sensitivity", "1", true, false, "Drone free camera sensitivity", 0.1, 5)
local freeLook = {
    drone = NULL,
    pitch = 0,
    yaw = 0,
    bodyPitch = 0,
    bodyYaw = 0,
    nextSend = 0
}

local function resetFreeLook(drone)
    freeLook.drone = IsValid(drone) and drone or NULL

    if IsValid(drone) then
        local ang = drone:GetAngles()
        local bodyAng = LocalPlayer():EyeAngles()
        freeLook.pitch = math.Clamp(math.NormalizeAngle(ang.p), -85, 85)
        freeLook.yaw = math.NormalizeAngle(ang.y)
        freeLook.bodyPitch = math.NormalizeAngle(bodyAng.p)
        freeLook.bodyYaw = math.NormalizeAngle(bodyAng.y)
        freeLook.nextSend = 0
    else
        freeLook.pitch = 0
        freeLook.yaw = 0
        freeLook.bodyPitch = 0
        freeLook.bodyYaw = 0
        freeLook.nextSend = 0
    end
end

local function updateFreeLookDrone()
    local drone = FreakCityDrone.GetActive(LocalPlayer())
    if drone ~= freeLook.drone then
        resetFreeLook(drone)
    end
    return drone
end

local function sendCameraAim(drone, force)
    if not IsValid(drone) or drone:GetDriver() ~= LocalPlayer() then return end
    if not force and RealTime() < freeLook.nextSend then return end

    freeLook.nextSend = RealTime() + 0.015
    net.Start("FreakCityDrone_CameraAim")
        net.WriteFloat(freeLook.pitch)
        net.WriteFloat(freeLook.yaw)
    net.SendToServer()
end

hook.Add("InputMouseApply", "FreakCityDrone_FreeCamera", function(cmd, x, y)
    local drone = updateFreeLookDrone()
    if not IsValid(drone) or drone:GetDriver() ~= LocalPlayer() then return end

    local scale = 0.022 * sensitivity:GetFloat()
    freeLook.yaw = math.NormalizeAngle(freeLook.yaw - x * scale)
    freeLook.pitch = math.Clamp(freeLook.pitch + y * scale, -85, 85)
    cmd:SetViewAngles(Angle(freeLook.bodyPitch, freeLook.bodyYaw, 0))
    sendCameraAim(drone, true)
    return true
end)

hook.Add("CreateMove", "FreakCityDrone_SyncFlightDirection", function(cmd)
    local drone = updateFreeLookDrone()
    if not IsValid(drone) or drone:GetDriver() ~= LocalPlayer() then return end

    cmd:SetViewAngles(Angle(freeLook.bodyPitch, freeLook.bodyYaw, 0))
    sendCameraAim(drone, false)
end)


local function copyVector(vec)
    return Vector(vec.x, vec.y, vec.z)
end

local function copyAngle(ang)
    return Angle(ang.p, ang.y, ang.r)
end

function FreakCityDrone.BuildView(ply, pos, ang, fov, znear, zfar)
    if not fullscreen:GetBool() then return nil end

    local drone = FreakCityDrone.GetActive(ply)
    if not IsValid(drone) or drone:GetDriver() ~= ply then return nil end
    if drone ~= freeLook.drone then resetFreeLook(drone) end

    local result
    if drone.CalcView then
        result = drone:CalcView(ply, pos, ang, fov)
    end

    result = istable(result) and result or {}
    result.origin = isvector(result.origin) and copyVector(result.origin) or drone:GetPos() + drone:GetForward() * 2 + drone:GetUp() * 4
    result.angles = Angle(freeLook.pitch, freeLook.yaw, 0)
    result.fov = tonumber(result.fov) or tonumber(fov) or 90
    result.znear = tonumber(result.znear) or 1
    result.zfar = tonumber(result.zfar) or zfar
    result.drawviewer = false
    result.drawviewmodel = false
    result.x = 0
    result.y = 0
    result.w = ScrW()
    result.h = ScrH()
    result.aspectratio = ScrW() / math.max(ScrH(), 1)

    return result
end

function FreakCityDrone.GetCameraAngles(ply)
    local drone = updateFreeLookDrone()
    if not IsValid(drone) or drone:GetDriver() ~= ply then return nil end
    return Angle(freeLook.pitch, freeLook.yaw, 0)
end

local function applyView(target, source)
    if not istable(target) or not istable(source) then return end
    target.origin = source.origin
    target.angles = source.angles
    target.fov = source.fov
    target.znear = source.znear
    target.zfar = source.zfar
    target.drawviewer = false
    target.drawviewmodel = false
    target.x = 0
    target.y = 0
    target.w = ScrW()
    target.h = ScrH()
    target.aspectratio = ScrW() / math.max(ScrH(), 1)
end

hook.Add("CalcView", "FreakCityDrone_FullscreenView", function(ply, pos, ang, fov, znear, zfar)
    return FreakCityDrone.BuildView(ply, pos, ang, fov, znear, zfar)
end)

hook.Add("HG_CalcView", "FreakCityDrone_HGDirectView", function(ply, pos, ang, fov, znear, zfar)
    return FreakCityDrone.BuildView(ply, pos, ang, fov, znear, zfar)
end)

hook.Add("Camera", "FreakCityDrone_HomigradCamera", function(ply, pos, ang, view)
    local droneView = FreakCityDrone.BuildView(ply, pos, ang, istable(view) and view.fov or nil, istable(view) and view.znear or nil, istable(view) and view.zfar or nil)
    if not droneView then return end
    applyView(view, droneView)
    return view
end)

hook.Add("PostHGCalcView", "FreakCityDrone_PostHGView", function(ply, view)
    local droneView = FreakCityDrone.BuildView(ply, view.origin, view.angles, view.fov, view.znear, view.zfar)
    if droneView then applyView(view, droneView) end
end)

hook.Add("PostPostHGCalcView", "FreakCityDrone_FinalHGView", function(ply, view)
    return FreakCityDrone.BuildView(ply, view.origin, view.angles, view.fov, view.znear, view.zfar)
end)

hook.Add("ShouldDrawLocalPlayer", "FreakCityDrone_DrawRealPlayer", function(ply)
    local drone = FreakCityDrone.GetActive(ply)
    if IsValid(drone) then return true end
end)

hook.Add("PreDrawViewModel", "FreakCityDrone_HideViewModel", function()
    local drone = FreakCityDrone.GetActive(LocalPlayer())
    if IsValid(drone) then return true end
end)

hook.Add("StartCommand", "FreakCityDrone_BlockPlayerMovement", function(ply, cmd)
    local drone = FreakCityDrone.GetActive(ply)
    if IsValid(drone) then cmd:ClearMovement() end
end)

hook.Add("ContextMenuOpen", "FreakCityDrone_BlockContextMenu", function()
    local drone = FreakCityDrone.GetActive(LocalPlayer())
    if IsValid(drone) then return false end
end)

hook.Add("SpawnMenuOpen", "FreakCityDrone_BlockSpawnMenu", function()
    local drone = FreakCityDrone.GetActive(LocalPlayer())
    if IsValid(drone) then return false end
end)

local hiddenHud = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudDamageIndicator = true,
    CHudCrosshair = true,
    CHudWeaponSelection = true
}

hook.Add("HUDShouldDraw", "FreakCityDrone_HideDefaultHUD", function(name)
    local drone = FreakCityDrone.GetActive(LocalPlayer())
    if IsValid(drone) and hiddenHud[name] then return false end
end)
