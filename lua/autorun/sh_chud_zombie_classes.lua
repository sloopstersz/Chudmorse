if SERVER then AddCSLuaFile() end

ZZZombieClasses = {
    runner = {painMultiplier = 0.8, limbDamageMultiplier = 1.5, name = "Runner", model = "models/player/zombie_fast.mdl", health = 100, stamina = 180, infinite = true, speed = 1.10, damage = 5, weapon = "weapon_hands_sh", description = "100 HP | 110% speed | Infinite stamina | 5 damage | 5% infection chance"},
    shambler = {painMultiplier = 0.5, limbDamageMultiplier = 1, name = "Shambler", model = "models/player/phoenix_zomb.mdl", health = 100, stamina = 180, speed = 1, damage = 10, weapon = "weapon_hands_sh", description = "100 HP | Normal speed | 180 stamina | 10 damage | 25% infection chance"},
    heavy = {painMultiplier = 0, limbDamageMultiplier = 1, name = "Heavy", model = "models/player/corpse1.mdl", health = 100, stamina = 120, speed = 0.90, damage = 25, weapon = "weapon_hands_sh", description = "100 HP | 90% speed | 120 stamina | 25 damage | 10% infection chance"}
}

function ZZIsZombie(ply)
    local mode = CurrentRound and CurrentRound()
    return IsValid(ply) and ply:IsPlayer() and mode and mode.name == "zzombies"
        and ZZZombieClasses[ply:GetNWString("ZZZombieClass", "")] ~= nil
end

function ZZGetZombieClass(ply)
    if ZZIsZombie(ply) then return ZZZombieClasses[ply:GetNWString("ZZZombieClass", "")] end
end

-- Shared by every pain calculation, including immediate pain hooks.
function ZZPainMultiplier(ply)
    local data = ZZGetZombieClass(ply)
    return data and data.painMultiplier or 1
end

function ZZLimbDamageMultiplier(ply)
    local data = ZZGetZombieClass(ply)
    return data and data.limbDamageMultiplier or 1
end

function ZZHeavySlotAvailable(ply)
    local count = 0
    for _, other in player.Iterator() do
        if other ~= ply and other:Alive() and ZZIsZombie(other)
            and other:GetNWString("ZZZombieClass", "") == "heavy" then count = count + 1 end
    end
    return count < 3
end

hook.Add("HG_MovementCalc_2", "ZZZombieClassSpeed", function(mul, ply)
    local data = ZZGetZombieClass(ply)
    if data and ply:Alive() then mul[1] = mul[1] * data.speed end
end)

function ZZZombieRespawnActive()
    local mode = CurrentRound and CurrentRound()
    return mode and mode.name == "zzombies" and zb.ROUND_STATE == 1
        and GetGlobalFloat("ZZ_CooldownEnd", 0) == 0
        and GetGlobalFloat("ZZ_PhaseEnd", 0) > CurTime()
end

if SERVER then
    util.AddNetworkString("ZZZombieClassMenu")
    util.AddNetworkString("ZZZombieChooseClass")
    util.AddNetworkString("ZZZombieRespawn")
    util.AddNetworkString("ZZZombieFastRespawn")
    local function Active()
        local mode = CurrentRound and CurrentRound()
        return mode and mode.name == "zzombies" and zb.ROUND_STATE == 1
    end

    function ZZClearZombie(ply)
        if ply.PlayerClassName == "headcrabzombie" and ply:GetNWString("ZZZombieClass", "") ~= "" then
            ply:SetPlayerClass()
        end
        ply.ZZZombieChoicePending = nil
        ply:SetNWString("ZZZombieSelectedClass", "")
        ply:SetNWBool("ZZZombieCanChoose", false)
        ply:SetNWString("ZZZombieClass", "")
        ply:SetNWBool("ZZFirstInfected", false)
        ply.ZZZombieStaminaTime = nil
        ply:SetNWBool("ZZIntelligence", false)
        ply:SetNWBool("ZZInfectionSpit", false)
        ply:SetNWFloat("ZZZombieRespawnAt", 0)
        ply:SetNWBool("ZZZombieFastRespawnPaid", false)
        ply:SetMaxHealth(100)
        if ply:Alive() then ply:SetHealth(math.min(ply:Health(), 100)) end
    end

    function ZZEquipZombieWeapon(ply, selectWeapon)
        local data = ZZGetZombieClass(ply)
        if not data or not ply:Alive() or OverrideSpawn or IsValid(ply.FakeRagdoll) then return end
        local weapon = ply:GetWeapon(data.weapon)
        if not IsValid(weapon) then
            weapon = ply:Give(data.weapon)
            selectWeapon = true
        end
        if not IsValid(weapon) then return end
        weapon.ZombieClaws = true
        if selectWeapon then ply:SelectWeapon(data.weapon) end
        if weapon.SetFists then weapon:SetFists(true) end
        return weapon
    end

    function ZZApplyZombieClass(ply, id, keepModel, firstInfected)
        local data = ZZZombieClasses[id]
        if not data or not IsValid(ply) or not ply:Alive() then return false end
        if id == "heavy" and not ZZHeavySlotAvailable(ply) then return false end
        local characterName = ply:GetNWString("PlayerName", ply:Nick())
        local accessories = ply:GetNetVar("Accessories", "")
        local accessoryColors = table.Copy(ply:GetNetVar("AccessoryColors", {}))
        local clothingColor = ply:GetPlayerColor()
        -- Appearance preservation does not grant the starting infected restriction.
        ply:SetNWBool("ZZFirstInfected", firstInfected == true and id == "shambler")
        ply:SetNWString("ZZZombieClass", id)
        ply:SetNWBool("ZZZombieCanChoose", false)
        ply.ZZZombieChoicePending = nil
        ply:SetNWString("ZZZombieSelectedClass", "")
        ply:SetTeam(0)
        ply:SetPlayerClass("headcrabzombie", {ZZZombie = true, keepAppearance = keepModel == true})
        ply:StripWeapons()
        ply:RemoveAllAmmo()
        if not keepModel then
            ply:SetModel(data.model)
            ply:SetSkin(0)
            ply:SetSubMaterial()
            ply:SetBodyGroups("0000000000000000")
        end
        ply:SetNetVar("Accessories", accessories)
        ply:SetNetVar("AccessoryColors", accessoryColors)
        ply:SetPlayerColor(clothingColor)
        ply:SetNWVector("PlayerColor", clothingColor)
        if keepModel then ply:SetNWString("PlayerName", characterName) end
        ply:SetWalkSpeed(100)
        ply:SetRunSpeed(350)
        ply:SetMaxHealth(data.health)
        ply:SetHealth(data.health)
        if ply.organism and ply.organism.stamina then
            ply.organism.stamina.range = data.stamina
            ply.organism.stamina.max = data.stamina
            ply.organism.stamina[1] = data.stamina
        end
        ply:SetMaxHealth(data.health)
        ply:SetHealth(data.health)
        ZZEquipZombieWeapon(ply, true)
        -- Finish after the other spawn callbacks and inventory cleanup.
        timer.Simple(0, function()
            if IsValid(ply) and ply:Alive() and ply:GetNWString("ZZZombieClass", "") == id then
                ZZEquipZombieWeapon(ply, true)
            end
        end)
        -- Reassert identity after class callbacks; appearance is independent of role.
        ply:SetNWString("ZZZombieClass", id)
        ply:SetNWBool("ZZFirstInfected", firstInfected == true and id == "shambler")
        if not ZZIsZombie(ply) or ply.PlayerClassName ~= "headcrabzombie" then return false end
        if ZZInfection and ZZInfection.Clear then ZZInfection.Clear(ply) end
        if ZZUpdateZombieOrganism then ZZUpdateZombieOrganism(ply, ply.organism) end
        zb.GiveRole(ply, firstInfected and characterName or data.name, Color(190, 30, 30))
        return true
    end

    -- Keep normal organs and injuries; only these sensations and class stamina differ.
    function ZZUpdateZombieOrganism(ply, org)
        local data = ZZGetZombieClass(ply)
        if not data or not ply:Alive() or not org then return end
        if data.painMultiplier == 0 then
            org.pain, org.painadd, org.avgpain = 0, 0, 0
            org.nearpainlimit, org.painUnconscious = false, false
            org.painUnconsciousTime = 0
        end
        org.shock, org.disorientation = 0, 0
        org.panicattack, org.panicattackadd, org.depression = 0, 0, 0
        org.panicattackActive = false
        if org.stamina then
            org.stamina.range = data.stamina
            if data.infinite then
                org.stamina[1] = org.stamina.max
                org.stamina.sub, org.stamina.subadd = 0, 0
            end
        end
    end

    hook.Add("PlayerDeath", "ZZZombieClassChoice", function(ply)
        if not Active() or ply:IsBot() or ply.ZZ_Extracted or ply.ZZGuardReserved then return end
        ply.ZZZombieChoicePending = true
        ply:SetNWFloat("ZZZombieRespawnAt", 0)
        ply:SetNWBool("ZZIntelligence", false)
        ply:SetNWBool("ZZInfectionSpit", false)
        ply:SetNWBool("ZZZombieFastRespawnPaid", false)
        ply:SetNWString("ZZZombieSelectedClass", "")
        ply:SetNWBool("ZZZombieCanChoose", ZZZombieRespawnActive() and true or false)
        timer.Simple(0.3, function()
            if IsValid(ply) and not ply:Alive() and ZZZombieRespawnActive() and ply.ZZZombieChoicePending then
                net.Start("ZZZombieClassMenu") net.Send(ply)
            end
        end)
    end)

    -- Preserve dead players' choices across downtime, but never permit a
    -- respawn until the next phase actually starts.
    local nextChoiceUpdate = 0
    hook.Add("Think", "ZZZombieRespawnAvailability", function()
        if CurTime() < nextChoiceUpdate then return end
        nextChoiceUpdate = CurTime() + 0.25
        for _, ply in player.Iterator() do
            if Active() and ZZIsZombie(ply) and ply:Alive() then ZZEquipZombieWeapon(ply, false) end
            if not Active() then
                ply.ZZZombieChoicePending = nil
                ply:SetNWString("ZZZombieSelectedClass", "")
            end
            local allowed = ZZZombieRespawnActive() and not ply:Alive()
                and not ply:IsBot() and not ply.ZZ_Extracted and not ply.ZZGuardReserved and ply.ZZZombieChoicePending == true
            allowed = allowed and true or false
            if ply:GetNWBool("ZZZombieCanChoose", false) ~= allowed then
                ply:SetNWBool("ZZZombieCanChoose", allowed)
                if allowed then net.Start("ZZZombieClassMenu") net.Send(ply) end
            end
        end
    end)

    net.Receive("ZZZombieChooseClass", function(_, ply)
        local id = net.ReadString()
        if not ZZZombieRespawnActive() or not IsValid(ply) or ply:IsBot() or ply:Alive() or ply.ZZ_Extracted
            or ply.ZZGuardReserved or not ply.ZZZombieChoicePending or not ZZZombieClasses[id] then return end
        if id == "heavy" and not ZZHeavySlotAvailable(ply) then
            ply:ChatPrint("All 3 Heavy slots are occupied. Choose another class.")
            return
        end
        if ply:GetNWString("ZZZombieSelectedClass", "") == "" then
            ply:SetNWFloat("ZZZombieRespawnAt", CurTime() + 10)
        end
        ply:SetNWString("ZZZombieSelectedClass", id)
    end)

    net.Receive("ZZZombieFastRespawn", function() end) -- Retired R-key purchase.

    function ZZRespawnSelected(ply)
        if not ZZZombieRespawnActive() or not IsValid(ply) or ply:IsBot() or ply:Alive() or ply.ZZ_Extracted
            or ply.ZZGuardReserved or not ply.ZZZombieChoicePending then return end
        if CurTime() < ply:GetNWFloat("ZZZombieRespawnAt", 0) then return end
        local id = ply:GetNWString("ZZZombieSelectedClass", "")
        if not ZZZombieClasses[id] or (ply.ZZZombieNextChoice or 0) > CurTime() then return end
        if id == "heavy" and not ZZHeavySlotAvailable(ply) then
            ply:SetNWString("ZZZombieSelectedClass", "")
            ply:ChatPrint("All 3 Heavy slots are occupied. Choose another class.")
            net.Start("ZZZombieClassMenu") net.Send(ply)
            return
        end
        ply.ZZZombieNextChoice = CurTime() + 1
        ply.ZZZombieChoicePending = nil
        ply:SetNWString("ZZZombieSelectedClass", "")
        ply:SetNWBool("ZZZombieCanChoose", false)
        ply.ZZZombieSpawning = true
        ply:UnSpectate()
        ply:SetTeam(0)
        ply:Spawn()
        ply.ZZZombieSpawning = nil
        if not ply:Alive() or not ZZZombieRespawnActive() then return end
        ply:SetMoveType(MOVETYPE_WALK)
        ply:Freeze(false)
        if not ZZApplyZombieClass(ply, id) then ZZApplyZombieClass(ply, "shambler") end
        local points = zb.GetMapPoints("zzombiesspawn") or {}
        local positions = zb.TranslatePointsToVectors(points)
        local available = {}
        local mins, maxs = ply:GetHull()
        for _, pos in ipairs(positions) do
            local trace = util.TraceHull({start = pos + Vector(0, 0, 2), endpos = pos + Vector(0, 0, 2),
                mins = mins, maxs = maxs, filter = ply, mask = MASK_PLAYERSOLID})
            if not trace.StartSolid and not trace.AllSolid then available[#available + 1] = pos end
        end
        if #available > 0 then
            local pos = zb:GetRandomSpawn(ply, available)
            if pos then ply:SetPos(pos + Vector(0, 0, 2)) end
        elseif ply.GetRandomSpawn then
            ply:GetRandomSpawn()
        end
        return true
    end
    net.Receive("ZZZombieRespawn", function(_, ply) ZZRespawnSelected(ply) end)

    hook.Add("PlayerSpawn", "ZZZombieReset", function(ply)
        if not OverrideSpawn and not ply.ZZZombieSpawning then ZZClearZombie(ply) end
    end)
    hook.Add("PlayerCanPickupWeapon", "ZZZombieWeapons", function(ply, wep)
        local data = ZZGetZombieClass(ply)
        if data and wep:GetClass() ~= data.weapon then return false end
    end)
else
    local frame
    local useWasDown, fastWasDown = false, false
    surface.CreateFont("ZZClassTitle", {font = "Georgia", size = 30, weight = 500})
    surface.CreateFont("ZZClassText", {font = "Georgia", size = 20, weight = 500})
    surface.CreateFont("ZZClassRespawn", {font = "Georgia", size = 32, weight = 700})
    local white, red = Color(230, 225, 220), Color(195, 35, 35)
    local traits = {
        runner = {"110% PLAYER SPEED", "NO STAMINA LOSS", "NORMAL HEALTH", "LOW DAMAGE"},
        shambler = {"NORMAL SPEED", "NORMAL STAMINA", "NORMAL HEALTH"},
        heavy = {"90% PLAYER SPEED", "120 STAMINA", "NORMAL HEALTH", "HIGH DAMAGE",}
    }
    local function Eligible()
        local ply = LocalPlayer()
        return IsValid(ply) and not ply:Alive() and ZZZombieRespawnActive()
            and ply:GetNWBool("ZZZombieCanChoose", false)
    end
    local function OpenMenu()
        if not Eligible() or IsValid(frame) then return end
        local ply = LocalPlayer()
        if ZZZombieClasses[ply:GetNWString("ZZZombieSelectedClass", "")] then return end
        local width = math.min(ScrW() - 32, 1020)
        local height = math.min(ScrH() - 48, 450)
        local x, y = (ScrW() - width) / 2, (ScrH() - height) / 2
        frame = vgui.Create("DPanel")
        frame:SetSize(width, height)
        frame:SetPos(x, ScrH() + 8)
        frame:MoveTo(x, y, 0.45, 0, 0.4)
        frame:MakePopup()
        frame:SetKeyboardInputEnabled(false)
        frame.Paint = function(self, w, h)
            surface.SetDrawColor(5, 5, 5, 235) surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(white) surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("CHOOSE YOUR INFECTED", "ZZClassTitle", w / 2, 20, white, TEXT_ALIGN_CENTER)
        end
        local gap, margin = 12, 18
        local cardWidth = (width - margin * 2 - gap * 2) / 3
        local fontScale = math.min(1, cardWidth / 290, (height - 86) / 320)
        surface.CreateFont("ZZCardTitle", {font = "Georgia", size = math.max(12, math.floor(30 * fontScale)), weight = 500})
        surface.CreateFont("ZZCardText", {font = "Georgia", size = math.max(9, math.floor(20 * fontScale)), weight = 500})
        for index, id in ipairs({"runner", "shambler", "heavy"}) do
            local classID, data = id, ZZZombieClasses[id]
            local button = vgui.Create("DButton", frame)
            button:SetPos(margin + (index - 1) * (cardWidth + gap), 68)
            button:SetSize(cardWidth, height - 86)
            button:SetText("")
            button.Paint = function(self, w, h)
                local full = classID == "heavy" and not ZZHeavySlotAvailable(LocalPlayer())
                local tint = (full or self:IsHovered()) and red or white
                surface.SetDrawColor(self:IsHovered() and Color(40, 12, 12, 245) or Color(12, 12, 14, 245))
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(tint) surface.DrawOutlinedRect(0, 0, w, h, 1)
                -- Fit the same three cards on smaller screens without clipping text.
                local scale = math.min(1, w / 290, h / 320)
                draw.SimpleText(string.upper(data.name), "ZZCardTitle", w / 2, 24 * scale, tint, TEXT_ALIGN_CENTER)
                for row, text in ipairs(traits[classID]) do
                    draw.SimpleText(text, "ZZCardText", 18 * scale, (65 + row * 32) * scale, white)
                end
                draw.SimpleText(full and "FULL (3 ALIVE)" or "SELECT", "ZZCardTitle", w / 2, h - 44 * scale, tint, TEXT_ALIGN_CENTER)
            end
            button.DoClick = function()
                if classID == "heavy" and not ZZHeavySlotAvailable(LocalPlayer()) then return end
                net.Start("ZZZombieChooseClass") net.WriteString(classID) net.SendToServer()
                -- Keep the panel until the server acknowledges this selection.
                -- This avoids showing a respawn prompt for a rejected request.
            end
        end
    end
    net.Receive("ZZZombieClassMenu", function() timer.Simple(0.1, OpenMenu) end)
    hook.Add("Think", "ZZZombieClassAutoPopup", function()
        local down = input.IsKeyDown(KEY_E)
        local eligible = Eligible()
        local ply = LocalPlayer()
        local selected = eligible and ZZZombieClasses[ply:GetNWString("ZZZombieSelectedClass", "")]
        if not eligible or selected then
            if IsValid(frame) then frame:Remove() end
        else
            OpenMenu()
        end
        if selected and down and not useWasDown and CurTime() >= ply:GetNWFloat("ZZZombieRespawnAt", 0) and not vgui.CursorVisible() and not gui.IsConsoleVisible() then
            net.Start("ZZZombieRespawn") net.SendToServer()
        end
        useWasDown = down
    end)
    hook.Add("HUDPaint", "ZZZombieRespawnPrompt", function()
        if not Eligible() then return end
        local data = ZZZombieClasses[LocalPlayer():GetNWString("ZZZombieSelectedClass", "")]
        if not data then return end
        local ply = LocalPlayer()
        local remaining = math.max(0, ply:GetNWFloat("ZZZombieRespawnAt", 0) - CurTime())
        local message = remaining > 0 and ("RESPAWN IN " .. math.ceil(remaining) .. "s") or "PRESS E TO RESPAWN"
        draw.SimpleTextOutlined(message, "ZZClassRespawn", ScrW() / 2, ScrH() * 0.72,
            red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
        draw.SimpleText(string.upper(data.name), "ZZClassText", ScrW() / 2, ScrH() * 0.72 + 30,
            white, TEXT_ALIGN_CENTER)
        draw.SimpleText("1: INSTANT RESPAWN (50)   2: INTELLIGENCE (75)   3: INFECTION SPIT (100)",
            "DermaDefaultBold", ScrW() / 2, ScrH() * 0.72 + 62, white, TEXT_ALIGN_CENTER)
        local upgrades = (ply:GetNWBool("ZZIntelligence", false) and "Intelligence owned  " or "")
            .. (ply:GetNWBool("ZZInfectionSpit", false) and "Spit owned  " or "")
        draw.SimpleText(upgrades .. "Points: " .. ply:GetNWInt("ZZZombiePoints", 0), "DermaDefaultBold",
            ScrW() / 2, ScrH() * 0.72 + 82, white, TEXT_ALIGN_CENTER)
    end)
    concommand.Add("zzombies_class", OpenMenu)
end

hook.Add("CalcMainActivity", "ZZZombieAnimations", function(ply, vel)
    if not ZZIsZombie(ply) or not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:InVehicle() then return end
    local anim = vel:LengthSqr() <= 0 and ACT_HL2MP_IDLE_ZOMBIE or ACT_HL2MP_RUN_ZOMBIE
    if ply:IsFlagSet(FL_ANIMDUCKING) then anim = ACT_HL2MP_WALK_CROUCH_ZOMBIE_01 end
    if not ply:IsOnGround() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
        anim = vel:Length2DSqr() >= 17000 and ACT_HL2MP_RUN_ZOMBIE_FAST or ACT_HL2MP_JUMP_SLAM
    end
    return anim, -1
end)
