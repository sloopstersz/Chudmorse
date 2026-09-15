AddCSLuaFile()

-- Проверяем, не мавик ли это (для него другой HUD или его отсутствие)
local function IsMavicDrone(drone)
    if not IsValid(drone) then return false end
    return drone:GetClass() == "dji_mavic3" or drone:GetClass():find("mavic")
end

-- Подключаем систему сигналов и помех
include("kamikaze_signal.lua")

-- Загружаем текстуры интерфейса
local centerFPV = Material("HUD/CenterFPV.png")
local tangashFPV = Material("HUD/tangashFPV.png")

-- Регистрация шрифтов в стиле OSD
surface.CreateFont("FPV_OSD_Main", {
    font      = "VCR OSD Mono Cyr",
    size      = 32,
    weight    = 400,
    outline   = true,
    antialias = false,
    extended  = true,
})

surface.CreateFont("FPV_OSD_Small", {
    font      = "VCR OSD Mono Cyr",
    size      = 20,
    weight    = 400,
    outline   = true,
    antialias = false,
    extended  = true,
})

surface.CreateFont("FPV_OSD_Tiny", {
    font      = "VCR OSD Mono Cyr",
    size      = 16,
    weight    = 400,
    outline   = true,
    antialias = false,
    extended  = true,
})

-- 📊 Логика FPS счетчика (имитация OSD)
local fpsDropTimer = 0
local fpsDropActive = false
local currentFPS = 30

hook.Add("Think", "Kamikaze_FPS_Drop", function()
    local ct = CurTime()
    if not fpsDropActive and ct > fpsDropTimer then
        if math.random(1, 100) <= 5 then
            fpsDropActive = true
            timer.Simple(math.random(2, 4), function()
                fpsDropActive = false
                fpsDropTimer = ct + math.random(30, 60)
            end)
        else
            fpsDropTimer = ct + math.random(10, 20)
        end
    end
    currentFPS = fpsDropActive and 29 or 30
end)

-- 🎭 Функция отрисовки "Мягкого шума"
local function DrawSoftNoise(level, w, h)
    -- Умножаем уровень помех на 0.5, чтобы они были в два раза прозрачнее
    local softened_level = math.Clamp(level * 0.5, 0, 100)
    if softened_level > 0 then
        DrawNoiseOverlay(softened_level, w, h)
    end
end

hook.Add("HUDPaint", "KamikazeDrone_HUD", function()
    local ply = LocalPlayer()
    local drone = ply:GetNWEntity("kamikaze_")

    -- Проверки на валидность и вид от 3-го лица
    if not IsValid(drone) or IsMavicDrone(drone) then return end
    if drone:GetNWBool("thirdperson") then return end
    if drone ~= ply:GetNWEntity("kamikaze_") then return end

    local screenW = ScrW()
    local screenH = ScrH()
    local centerX = screenW / 2
    local centerY = screenH / 2
    
    -- 📡 Получаем уровень помех из системы сигналов
    local noise_level = GetDroneNoiseLevel(drone)
    
    -- Отрисовка смягченных визуальных помех
    DrawSoftNoise(noise_level, screenW, screenH)
    
    -- Проверка критической потери сигнала
    local signalLost = DrawSignalLoss(noise_level, screenW, screenH)
    if signalLost then return end
    
    -- 🎯 Отрисовка центрального прицела
    surface.SetMaterial(centerFPV)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(centerX - 25.5, centerY - 19, 51, 38)
    
    -- 📐 Авиагоризонт (динамический наклон)
    local ang = drone:GetAngles()
    local roll = math.Clamp(ang.r, -45, 45)
    
    surface.SetMaterial(tangashFPV)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRectRotated(centerX, centerY - 50, 635, 15, roll)
    
    -- 📡 Полоски уровня сигнала
    DrawSignalBars(math.max(24, screenW * 0.02), 45, noise_level)
    
    -- 🔋 Отрисовка данных батареи
    local totalVolt = drone:GetNWFloat("Kamikaze_BatteryTotal", 16.8)
    local cellVolt = drone:GetNWFloat("Kamikaze_BatteryCell", 4.2)
    local pct = drone:GetNWFloat("Kamikaze_BatteryPct", 1.0)
    
    local topY = 80
    
    surface.SetFont("FPV_OSD_Main")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(centerX - 150, topY)
    surface.DrawText(string.format("%.1fV", totalVolt))
    surface.SetTextPos(centerX + 50, topY)
    surface.DrawText(string.format("%.2fV", cellVolt))
    
    surface.SetFont("FPV_OSD_Small")
    surface.SetTextPos(centerX - 150, topY + 35)
    surface.DrawText("TOTAL")
    surface.SetTextPos(centerX + 50, topY + 35)
    surface.DrawText("CELL")
    
    -- Процент заряда в центре сверху
    surface.SetTextPos(centerX - 30, topY + 70)
    surface.DrawText(string.format("%d%%", math.Round(pct * 100)))
    
    -- ⚠️ Предупреждение о низком заряде (мигающее)
    if pct < 0.2 and pct > 0 then
        surface.SetFont("FPV_OSD_Tiny")
        local alpha = 200 + 55 * math.sin(CurTime() * 5)
        surface.SetTextColor(255, 255, 255, alpha)
        surface.SetTextPos(centerX - 40, centerY + 60)
        surface.DrawText("LOW BATTERY")
    end
    
    -- 🌙 Статус фонаря
    if drone:GetNWBool("Kamikaze_Flashlight", false) then
        surface.SetFont("FPV_OSD_Small")
        surface.SetTextColor(255, 220, 150, 255)
        surface.SetTextPos(centerX + 200, topY)
        surface.DrawText("LIGHT")
    end
    
    -- 📊 Отрисовка FPS
    surface.SetFont("FPV_OSD_Small")
    surface.SetTextColor(255, 255, 255, 200)
    surface.SetTextPos(centerX - 25, screenH - 40)
    surface.DrawText(string.format("FPS %d", currentFPS))
end)