-- kamikaze_signal.lua
if SERVER then return end

local next_rand_noise = 0
local end_rand_noise = 0
local rand_cache = 0
local rand_next = 0
local smooth_noise = 0

-- Материал для шума
local NOISE_MAT = Material("effects/fpv_noise")

function GetDroneNoiseLevel(drone)
    local ct = CurTime()
    
    if not drone.CachedProxNoise then drone.CachedProxNoise = 0 end
    
    -- Базовый постоянный шум (всегда есть легкий шум)
    local baseNoise = 15  -- Постоянный легкий шум 15%
    
    -- Случайные скачки помех (редко)
    if ct > next_rand_noise then
        if next_rand_noise == 0 then
            next_rand_noise = ct + math.random(20, 40)
            rand_cache = 0
        else
            end_rand_noise = ct + math.random(1, 3)
            next_rand_noise = ct + math.random(30, 60)
        end
    end
    
    if ct < end_rand_noise then
        if ct > rand_next then
            rand_next = ct + 0.1
            rand_cache = math.random(30, 70)
        end
    else
        rand_cache = 0
    end
    
    -- Помехи от сервера
    local interference = drone:GetNWInt("Kamikaze_Interference", 0)
    
    -- 📡 Зависимость от расстояния до игрока
    local ply = LocalPlayer()
    local distFactor = 0
    
    if IsValid(ply) then
        local dist_to_player = drone:GetPos():Distance(ply:GetPos()) / 39.37 -- в метрах
        
        -- Чем дальше, тем больше помех (50м - 300м)
        if dist_to_player > 50 then
            distFactor = math.min(80, (dist_to_player - 50) / 3.125)
        end
    end
    
    -- Общий уровень помех (максимум 100) с базовым шумом
    local target = math.min(100, math.max(
        baseNoise,
        rand_cache,
        interference,
        distFactor
    ))
    
    -- Плавная интерполяция
    smooth_noise = Lerp(FrameTime() * 3, smooth_noise, target)
    
    return smooth_noise
end

function DrawSignalBars(x, y, level)
    local bars = 4
    local bar_width = 12
    local bar_spacing = 4
    local total_width = bars * (bar_width + bar_spacing) - bar_spacing
    
    -- Фон
    surface.SetDrawColor(0, 0, 0, 150)
    surface.DrawRect(x - 5, y - 5, total_width + 10, 35)
    
    for i = 1, bars do
        local bar_level = (i / bars) * 100
        local bar_height = 8 + i * 4
        
        -- Цвет в зависимости от уровня сигнала
        if level > bar_level + 20 then
            surface.SetDrawColor(80, 80, 80, 200)  -- Нет сигнала
        elseif level > bar_level then
            surface.SetDrawColor(255, 200, 0, 200) -- Желтый (слабый)
        else
            surface.SetDrawColor(0, 255, 0, 200)   -- Зеленый (хороший)
        end
        
        -- Черная обводка
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(x + (i-1) * (bar_width + bar_spacing) - 1, y + 25 - bar_height - 1, bar_width + 2, bar_height + 2)
        
        -- Сам бар
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(x + (i-1) * (bar_width + bar_spacing), y + 25 - bar_height, bar_width, bar_height)
    end
    
    -- Текст с уровнем сигнала (проценты)
    surface.SetFont("FPV_OSD_Small")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(x, y + 30)
    surface.DrawText(string.format("%d%%", math.max(0, 100 - math.Round(level))))
    
    return total_width + 20
end

-- Функция для отрисовки шума поверх экрана (ПОСТОЯННАЯ)
function DrawNoiseOverlay(noiseLevel, sw, sh)
    -- Всегда рисуем легкий шум, даже при низком уровне
    local ns = 15 + noiseLevel / 3
    local sx, sy = (CurTime() * ns) % 1, (CurTime() * ns * 1.2) % 1
    
    -- Прозрачность: минимум 20, увеличивается с уровнем помех
    local alpha = math.min(180, 20 + noiseLevel * 1.6)
    
    surface.SetMaterial(NOISE_MAT)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRectUV(0, 0, sw, sh, sx, sy, sx + 1.5, sy + 1.5)
end

-- Функция для потери сигнала (черный экран)
function DrawSignalLoss(noiseLevel, sw, sh)
    if noiseLevel > 98 then
        -- Полная потеря - черный экран
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, sw, sh)
        return true
    elseif noiseLevel > 85 then
        -- Сильные помехи - темный экран с шумом
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, sw, sh)
        return false
    end
    return false
end