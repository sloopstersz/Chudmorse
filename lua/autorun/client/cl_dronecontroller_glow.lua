AddCSLuaFile()

hook.Add("Think", "DroneController_GKeyInput", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    --print("[DEBUG] Think hook running")

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end
    --print("[DEBUG] Holding weapon:", wep:GetClass())

    if wep:GetClass() ~= "weapon_dronecontroller_ful" then return end

    wep.GKeyPressedLast = wep.GKeyPressedLast or false

    if input.IsKeyDown(KEY_G) then
        if not wep.GKeyPressedLast then
            wep.GKeyPressedLast = true
            --print("[DEBUG] G key pressed (Integrated Glow)")

            local drones = ents.FindByClass("kamikaze")
            local closestDrone = nil
            local closestDistSqr = 2000 ^ 2

            for _, drone in ipairs(drones) do
                local distSqr = ply:GetPos():DistToSqr(drone:GetPos())
                if distSqr < closestDistSqr then
                    closestDistSqr = distSqr
                    closestDrone = drone
                end
            end

            if IsValid(closestDrone) then
                wep.HighlightTarget = closestDrone
                wep.HighlightExpireTime = CurTime() + 2
                surface.PlaySound("kamikaze/cod_mw_blip1.wav")
				print("[HALO DEBUG] Applying halo to")
            else
                --print("[DEBUG] No drone found nearby.")
                wep.HighlightTarget = nil
            end
        end
    else
        wep.GKeyPressedLast = false
    end
end)

hook.Add("PostDrawTranslucentRenderables", "DroneController_GlowEffect", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_dronecontroller_ful" then return end

    --print("[HALO] PostDraw called")

    local ent = wep.HighlightTarget
    if not IsValid(ent) then return end

    if not wep.HighlightExpireTime or CurTime() > wep.HighlightExpireTime then
        wep.HighlightTarget = nil
        return
    end

    --print("[HALO] Drawing halo on", ent)
    halo.Add({ent}, Color(255, 0, 0), 5, 5, 50, true, true)
end)
--[[
-- 每幀檢查是否按下 G 並尋找最近的無人機
hook.Add("Think", "DroneController_GKeyInput", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_dronecontroller" then return end

    -- 初始化狀態
    wep.GKeyPressedLast = wep.GKeyPressedLast or false

    if input.IsKeyDown(KEY_G) then
        if not wep.GKeyPressedLast then
            wep.GKeyPressedLast = true
            print("[DEBUG] G key pressed (Integrated Glow)")

            -- 搜尋最近無人機
            local drones = ents.FindByClass("kamikaze")
            local closestDrone = nil
            local closestDistSqr = 400 ^ 2

            for _, drone in ipairs(drones) do
                local distSqr = ply:GetPos():DistToSqr(drone:GetPos())
                if distSqr < closestDistSqr then
                    closestDistSqr = distSqr
                    closestDrone = drone
                end
            end

            if IsValid(closestDrone) then
                wep.HighlightTarget = closestDrone
                wep.HighlightExpireTime = CurTime() + 2
                print("[HALO DEBUG] Applying halo to", closestDrone)
            else
                print("[DEBUG] No drone found nearby.")
                wep.HighlightTarget = nil
            end
        end
    else
        wep.GKeyPressedLast = false
    end
end)

-- 畫紅色光環
hook.Add("PostDrawTranslucentRenderables", "DroneController_GlowEffect", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_dronecontroller" then return end

    local ent = wep.HighlightTarget
    if not IsValid(ent) then return end

    if not wep.HighlightExpireTime or CurTime() > wep.HighlightExpireTime then
        wep.HighlightTarget = nil
        return
    end

    halo.Add({ent}, Color(255, 0, 0), 5, 5, 2, true, true)
end)
--]]
