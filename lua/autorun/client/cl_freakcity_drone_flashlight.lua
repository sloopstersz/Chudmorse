local projectedLight
local localEnabled = false
local activeDrone = NULL
local nextToggle = 0

local function removeProjectedLight()
    if projectedLight then
        projectedLight:Remove()
        projectedLight = nil
    end
end

local function getControlledDrone()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local drone
    if FreakCityDrone and FreakCityDrone.GetActive then
        drone = FreakCityDrone.GetActive(ply)
    else
        drone = ply:GetNWEntity("kamikaze_")
    end

    if not IsValid(drone) or not drone.GetDriver or drone:GetDriver() ~= ply then return nil end
    return drone
end

local function setFlashlight(enabled, drone)
    drone = IsValid(drone) and drone or getControlledDrone()
    if not IsValid(drone) then
        localEnabled = false
        activeDrone = NULL
        removeProjectedLight()
        return
    end

    localEnabled = enabled == true
    activeDrone = drone

    net.Start("FreakCityDrone_SetFlashlight")
        net.WriteBool(localEnabled)
    net.SendToServer()

    if not localEnabled then
        removeProjectedLight()
    end
end

local function toggleFlashlight()
    if CurTime() < nextToggle then return end

    local drone = getControlledDrone()
    if not IsValid(drone) then return end

    nextToggle = CurTime() + 0.2
    setFlashlight(not localEnabled, drone)
end

hook.Add("PlayerBindPress", "FreakCityDrone_FlashlightBind", function(ply, bind, pressed)
    if ply ~= LocalPlayer() or not pressed then return end
    bind = string.lower(bind or "")
    if not string.find(bind, "+zoom", 1, true) then return end
    if not IsValid(getControlledDrone()) then return end

    toggleFlashlight()
    return true
end)

hook.Add("PlayerButtonDown", "FreakCityDrone_FlashlightKey", function(ply, button)
    if ply ~= LocalPlayer() or button ~= KEY_Z then return end
    if not IsValid(getControlledDrone()) then return end
    toggleFlashlight()
end)

local function createProjectedLight()
    if projectedLight then return projectedLight end

    projectedLight = ProjectedTexture()
    if not projectedLight then return nil end

    projectedLight:SetTexture("effects/flashlight001")
    projectedLight:SetNearZ(4)
    projectedLight:SetFarZ(2200)
    projectedLight:SetFOV(62)
    projectedLight:SetBrightness(8)
    projectedLight:SetColor(Color(245, 248, 255))
    projectedLight:SetEnableShadows(false)

    return projectedLight
end

local function getCameraTransform(drone)
    local ply = LocalPlayer()
    local ang

    if FreakCityDrone and FreakCityDrone.GetCameraAngles then
        ang = FreakCityDrone.GetCameraAngles(ply)
    end

    ang = ang or ply:EyeAngles()

    local origin = drone:GetPos() + drone:GetForward() * 2 + drone:GetUp() * 3.7

    if FreakCityDrone and FreakCityDrone.BuildView then
        local view = FreakCityDrone.BuildView(ply, ply:EyePos(), ang, ply:GetFOV())
        if istable(view) then
            if isvector(view.origin) then origin = view.origin end
            if isangle(view.angles) then ang = view.angles end
        end
    end

    return origin, ang
end

local function drawFallbackLights(drone, origin, ang)
    local direction = ang:Forward()
    local trace = util.TraceLine({
        start = origin,
        endpos = origin + direction * 1800,
        filter = {drone, LocalPlayer()},
        mask = MASK_OPAQUE_AND_NPCS
    })

    local distance = math.min(origin:Distance(trace.HitPos), 1800)
    local positions = {
        {distance = 80, size = 260, brightness = 1.8},
        {distance = math.min(360, distance * 0.45), size = 430, brightness = 1.25},
        {distance = math.min(760, distance * 0.78), size = 560, brightness = 0.8}
    }

    for index, data in ipairs(positions) do
        if data.distance <= distance + 16 then
            local dynamic = DynamicLight(drone:EntIndex() * 8 + index)
            if dynamic then
                dynamic.pos = origin + direction * data.distance
                dynamic.r = 235
                dynamic.g = 242
                dynamic.b = 255
                dynamic.brightness = data.brightness
                dynamic.Decay = 1200
                dynamic.Size = data.size
                dynamic.DieTime = CurTime() + 0.08
            end
        end
    end
end

hook.Add("PreRender", "FreakCityDrone_CameraFlashlight", function()
    local drone = getControlledDrone()

    if not IsValid(drone) then
        localEnabled = false
        activeDrone = NULL
        removeProjectedLight()
        return
    end

    if drone ~= activeDrone then
        activeDrone = drone
        localEnabled = drone:GetNWBool("Kamikaze_Flashlight", false)
    elseif drone:GetNWBool("Kamikaze_Flashlight", false) ~= localEnabled then
        localEnabled = drone:GetNWBool("Kamikaze_Flashlight", false)
    end

    if not localEnabled then
        removeProjectedLight()
        return
    end

    local origin, ang = getCameraTransform(drone)
    local light = createProjectedLight()

    if light then
        light:SetPos(origin + ang:Forward() * 3)
        light:SetAngles(ang)
        light:Update()
    end

    drawFallbackLights(drone, origin, ang)
end)

hook.Add("EntityRemoved", "FreakCityDrone_RemoveFlashlightEntity", function(ent)
    if ent ~= activeDrone then return end
    localEnabled = false
    activeDrone = NULL
    removeProjectedLight()
end)

hook.Add("ShutDown", "FreakCityDrone_RemoveCameraFlashlight", removeProjectedLight)
hook.Add("OnReloaded", "FreakCityDrone_ReloadCameraFlashlight", function()
    localEnabled = false
    activeDrone = NULL
    removeProjectedLight()
end)
