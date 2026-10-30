if SERVER then AddCSLuaFile() end

ZZExfil = ZZExfil or {}
ZZExfil.Types = {
    news = {name = "News Helicopter", seats = 4, model = "news_helicoptor_hoveranim", height = 0, bone = 0, cabin = Vector(0, 0, 0), spacing = 28, width = 26},
    littlebird = {name = "Little Bird", seats = 4, model = "ah6_lb", height = 72, bone = 0, cabin = Vector(0, 0, 0), spacing = 28, width = 30, groups = {4, 5}},
    seastallion = {name = "Sea Stallion", seats = 12, model = "sea_stallion", height = 8, bone = 6, cabin = Vector(48, 0, 16), spacing = 28, width = 30},
    blackhawk = {name = "Black Hawk", seats = 8, model = "uh-60", height = -36, bone = 0, cabin = Vector(0, 0, 0), spacing = 26, width = 27, groups = {5, 6, 7, 8}},
    chinook = {name = "Chinook", seats = 16, model = "chinook", height = 0, bone = 1, cabin = Vector(48, 0, 16), spacing = 28, width = 32},
    hip = {name = "Mi-8 Hip", seats = 10, model = "hip", height = -72, bone = 6, cabin = Vector(16, -16, -16), spacing = 26, width = 28},
    nh90 = {name = "NH90", seats = 8, model = "nh-90", height = -72, bone = 0, cabin = Vector(16, 0, 16), spacing = 26, width = 28},
    venom = {name = "UH-1Y Venom", seats = 6, model = "uh1y", height = -54, bone = 6, cabin = Vector(0, 8, -16), spacing = 26, width = 25},
    osprey = {name = "V-22 Osprey", seats = 10, model = "v-22 osprey", height = -64, bone = 0, cabin = Vector(-48, 0, 64), spacing = 28, width = 32}
}
ZZExfil.Types.littlebird.sound = "lfs_custom/ah6/rotor_loop.wav"
ZZExfil.Types.hip.sound = "lfs_custom/ah6/rotor_loop.wav"
ZZExfil.Types.seastallion.sound = "lfs_custom/pavelow_heli.wav"
ZZExfil.Types.chinook.sound = "lfs_custom/pavelow_heli.wav"
ZZExfil.Types.blackhawk.sound = "lfs_custom/uh60_heli.wav"
ZZExfil.Types.nh90.sound = "lfs_custom/uh60_heli.wav"
ZZExfil.Types.venom.sound = "lfs_custom/uh9_heli.wav"
ZZExfil.Types.osprey.sound = "lfs_custom/uh9_heli.wav"
ZZExfil.Types.news.sound = "lfs_custom/helicopter_loop09louder.wav"
ZZExfil.Order = {"littlebird", "venom", "blackhawk", "nh90", "hip", "osprey", "seastallion", "chinook", "news"}

function ZZExfil.IsSurvivor(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == 0
        and not ply.ZZExfilBoarded and not ply.ZZ_Extracted and not (ZZIsZombie and ZZIsZombie(ply))
end

-- All nine source-addon types have equal odds, independent of player count.
function ZZExfil.ChooseType()
    return ZZExfil.Order[math.random(1, #ZZExfil.Order)]
end

if SERVER then
    function ZZExfil.Spawn(mode, point, count)
        local id = ZZExfil.ChooseType()
        local data = ZZExfil.Types[id]
        local path = "models/exfil_coldwar/" .. data.model .. ".mdl"
        if not util.IsValidModel(path) then
            ErrorNoHalt("[Z-Zombies] Missing helicopter content: " .. path .. "\n")
            return
        end
        local heli = ents.Create("zz_exfil_helicopter")
        if not IsValid(heli) then return end
        heli.ExfilMode, heli.TypeID, heli.LandingPoint = mode, id, point
        heli:SetPos(point + Vector(0, 0, data.height))
        heli:SetAngles(Angle(0, 0, 0))
        heli:Spawn()
        mode.ExfilHelicopter = heli
        return heli
    end
    concommand.Add("zzombies_exfil_helicopter", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        local text = "Extraction randomly chooses from all nine helicopter types, with their original 4-16 seat capacities, regardless of player count."
        if IsValid(ply) then ply:ChatPrint(text) else print(text) end
    end)
    hook.Add("CanPlayerEnterVehicle", "ZZExfilSeats", function(ply, seat)
        if not IsValid(seat.ZZExfilHeli) then return end
        if seat.ZZExfilHeli.State ~= "boarding" or not ZZExfil.IsSurvivor(ply) then return false end
    end)
    hook.Add("CanExitVehicle", "ZZExfilFlightLock", function(seat, ply)
        local heli = seat.ZZExfilHeli
        if IsValid(heli) and heli.State == "departing" and not heli.Releasing then return false end
    end)
    -- Mark any corpse immediately, before other death cleanup hooks remove it.
    hook.Add("Ragdoll_Create", "ZZExfilNoGibs", function(ply, body)
        if IsValid(ply) and ply.ZZExfilBoarded and IsValid(body) then
            body.hg_no_fullbody_remove_gib = true
            body.override = true
        end
    end)
    hook.Add("KeyPress", "ZZExfilBoard", function(ply, key)
        if key ~= IN_USE or not ZZExfil.IsSurvivor(ply) or ply:InVehicle() or IsValid(ply.FakeRagdoll) then return end
        local mode = CurrentRound and CurrentRound()
        if not mode or mode.name ~= "zzombies" then return end
        local heli = mode.ExfilHelicopter
        if IsValid(heli) then heli:Use(ply) end
    end)
else
    hook.Add("PopulateToolMenu", "ZZExfilSettings", function()
        spawnmenu.AddToolMenuOption("Utilities", "Admin", "ZZExfil", "Zombie extraction", "", "", function(panel)
            panel:Help("Every extraction randomly selects one of nine helicopter types. Each keeps its original capacity (4-16 seats). Player count does not affect selection.")
        end)
    end)
    hook.Remove("HUDPaint", "ZZExfilBoardPrompt")
end

hook.Remove("EntityEmitSound", "ZZExfilSilent")

if SERVER then
    for _, data in pairs(ZZExfil.Types) do resource.AddFile("sound/" .. data.sound) end
    hook.Add("PlayerSpawn", "ZZExfilRestorePlayer", function(ply)
        if ply.ZZExfilPreviousTeam == nil then return end
        local previousTeam = ply.ZZExfilPreviousTeam
        ply.ZZExfilPreviousTeam = nil
        ply.ZZExfilBoarded = nil
        ply:SetNWBool("ZZExfilBoarded", false)
        ply:SetNWBool("ZZExfilSurvivor", false)
        ply:SetNWEntity("ZZExfilHeli", NULL)
        ply:UnSpectate()
        ply:SetNoDraw(false)
        ply:SetNotSolid(false)
        ply:SetMoveType(MOVETYPE_WALK)
        if ply:Team() == TEAM_SPECTATOR then ply:SetTeam(previousTeam) end
    end)
    hook.Add("EntityTakeDamage", "ZZExfilProtectSpectator", function(ply)
        if IsValid(ply) and ply:IsPlayer() and ply.ZZExfilPreviousTeam ~= nil then return true end
    end)
else
    hook.Add("HUDPaint", "ZZExfilPassengerCount", function()
        if not zb or zb.CROUND ~= "zzombies" then return end
        local heli = GetGlobalEntity("ZZ_ExfilHelicopter")
        if not IsValid(heli) then return end
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local boarded = ply:GetNWBool("ZZExfilBoarded", false)
        if not boarded then
            if not ZZExfil.IsSurvivor(ply) or heli:GetNWString("State") ~= "boarding" then return end
            local point = heli:GetNWVector("LandingPoint")
            local delta = ply:GetPos() - point
            if delta:Length2DSqr() > 240 * 240 or math.abs(delta.z) > 160 then return end
            local tr = util.TraceLine({start = ply:EyePos(), endpos = point + Vector(0, 0, 48),
                mask = MASK_SOLID_BRUSHONLY, filter = {ply, heli}})
            if tr.Hit then return end
            draw.SimpleText("PRESS E TO BOARD", "DermaLarge", ScrW() / 2, ScrH() * 0.85 - 32,
                Color(230, 45, 45), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        draw.SimpleText("HELICOPTER: " .. heli:GetNWInt("Passengers") .. " / " .. heli:GetNWInt("Capacity"),
            "DermaLarge", ScrW() / 2, ScrH() * 0.85, Color(230, 230, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end
