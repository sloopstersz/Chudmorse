-- Chudmorse COIN gun skins: ownership, buying, equipping and putting skins on guns.
if not ChudSkins then include("autorun/sh_chud_skins.lua") end

resource.AddFile("materials/chudmorse/skins/p22_red_dragon.vmt")
resource.AddFile("materials/chudmorse/skins/p22_gold_finish.vmt")
-- Gofitc5's skins (each .vmt sends its matching .vtf; extra textures listed separately)
for _, vmt in ipairs({"m1911/weapon_m1911_dm", "m1911/weapon_w_m45_dm", "usp/usp_weapon", "usp/usp_match",
    "usp/usp_suppressor", "m7/m7_bay"}) do
    resource.AddFile("materials/chudmorse/skins/gofit/" .. vmt .. ".vmt")
end
for _, vtf in ipairs({"m1911/weapon_m1911_dm", "m1911/weapon_m1911_nm", "m1911/weapon_w_m45_dm", "m1911/weapon_w_m45_nm",
    "usp/usp_d", "usp/usp_n", "usp/usp_g", "usp/usp_si", "usp/match_d", "usp/match_n", "usp/match_g",
    "usp/suppressor_d", "usp/suppressor_n", "m7/m7_bay_c", "m7/m7_bay_n", "m7/m7_bay_m", "p22/walther1_black"}) do
    resource.AddSingleFile("materials/chudmorse/skins/gofit/" .. vtf .. ".vtf")
end
resource.AddFile("materials/chudmorse/skins/didi/sog_held_didi.vmt")
resource.AddFile("materials/chudmorse/skins/didi/sog_dropped_didi.vmt")
resource.AddFile("materials/chudmorse/fakeouts/realshop.vmt")
resource.AddFile("materials/chud/realshop.vtf")
resource.AddFile("materials/chud/didicamel.png")
resource.AddFile("materials/chud/fort.png")
resource.AddFile("materials/chud/chuddy.png")
resource.AddFile("materials/chud/skelle.png")
resource.AddFile("materials/chud/car.png")
resource.AddFile("materials/chud/jerry.png")
resource.AddFile("sound/rem_chudtoken.mp3")

util.AddNetworkString("ChudSkins.Sync")
util.AddNetworkString("ChudSkins.Action")
util.AddNetworkString("ChudSkins.JackpotNotice")
util.AddNetworkString("ChudSkins.JackpotTimer")
util.AddNetworkString("ChudSkins.JackpotHuntTimer")
CreateConVar("chud_coin_jackpot_chance", "65000", 0,
    "Denominator for the Coin Shop jackpot crate chance; set to 1 to guarantee it.", 1, 65000)
for _, fakeout in pairs(ChudSkins.CrateFakeouts) do
    CreateConVar(fakeout.convar, tostring(fakeout.chance), 0,
        "Denominator for the " .. fakeout.name .. " fakeout chance; set to 1 to guarantee it.", 1, 65000)
end

function ChudSkins.GetCrateFakeoutChance(fakeout)
    local convar = GetConVar(fakeout.convar)
    return math.max(convar and convar:GetInt() or fakeout.chance, 1)
end

local ready = sql.Query([[CREATE TABLE IF NOT EXISTS chud_skins (
    steamid TEXT NOT NULL, item TEXT NOT NULL, equipped INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (steamid, item))]]) ~= false
local activeJackpots = setmetatable({}, {__mode = "k"})

local function Load(ply)
    if ply.ChudSkinData then return ply.ChudSkinData end
    local data = {owned = {}, equipped = {}, temporary = {}}
    if ready and not ply:IsBot() then
        local rows = sql.Query("SELECT item, equipped FROM chud_skins WHERE steamid = " .. sql.SQLStr(ply:SteamID64()))
        for _, row in ipairs(istable(rows) and rows or {}) do
            local item = ChudSkins.Get(row.item)
            if item then
                data.owned[item.id] = true
                if tonumber(row.equipped) == 1 then data.equipped[item.weapon] = item.id end
            end
        end
    end
    ply.ChudSkinData = data
    return data
end

local function Send(ply, message)
    local data = Load(ply)
    local owned, equipped = table.GetKeys(data.owned), {}
    for class, id in pairs(data.equipped) do equipped[#equipped + 1] = {class, id} end
    net.Start("ChudSkins.Sync")
    net.WriteUInt(#owned, 8)
    for _, id in ipairs(owned) do net.WriteString(id) end
    net.WriteUInt(#equipped, 8)
    for _, pair in ipairs(equipped) do net.WriteString(pair[1]) net.WriteString(pair[2]) end
    net.WriteString(message or "")
    net.Send(ply)
end

local function SetJackpotTimer(ply, running)
    net.Start("ChudSkins.JackpotTimer")
    net.WriteBool(running)
    if running then net.WriteFloat(30) end
    net.Send(ply)

    net.Start("ChudSkins.JackpotHuntTimer")
    net.WriteBool(running)
    net.WriteString(ply:SteamID64())
    if running then
        net.WriteString(ply:Nick())
        net.WriteFloat(30)
    end
    net.Broadcast()
end

local function SetEquipped(ply, class, id)
    local data = Load(ply)
    local current = data.equipped[class]
    if (id and data.temporary[id]) or (not id and data.temporary[current]) then
        local jackpot = ply.ChudSkinJackpot
        if jackpot then jackpot.temporarySlots[class] = true end
        data.equipped[class] = id
        return
    end
    if ply.ChudSkinJackpot then ply.ChudSkinJackpot.temporarySlots[class] = nil end

    local sid = sql.SQLStr(ply:SteamID64())
    local others = {}
    for otherId, item in pairs(ChudSkins.Items) do
        if item.weapon == class then others[#others + 1] = sql.SQLStr(otherId) end
    end
    sql.Begin()
    sql.Query("UPDATE chud_skins SET equipped = 0 WHERE steamid = " .. sid .. " AND item IN (" .. table.concat(others, ",") .. ")")
    if id then sql.Query("UPDATE chud_skins SET equipped = 1 WHERE steamid = " .. sid .. " AND item = " .. sql.SQLStr(id)) end
    sql.Commit()
    data.equipped[class] = id
end

local handlers = {
    [0] = function(ply) Send(ply) end,
    [1] = function(ply, item) -- buy, then equip it
        local data = Load(ply)
        if data.owned[item.id] then Send(ply) return end
        if not (ChudCoin and ChudCoin.TrySpend and ChudCoin.TrySpend(ply, item.price)) then
            Send(ply, "Not enough COIN for " .. item.name .. ".")
            return
        end
        local saved = sql.Query("INSERT OR IGNORE INTO chud_skins (steamid, item, equipped) VALUES ("
            .. sql.SQLStr(ply:SteamID64()) .. ", " .. sql.SQLStr(item.id) .. ", 0)") ~= false
        if not saved then
            ChudCoin.Add(ply, item.price)
            Send(ply, "Purchase failed, your COIN was refunded.")
            return
        end
        data.owned[item.id] = true
        SetEquipped(ply, item.weapon, item.id)
        Send(ply, "Bought and equipped " .. item.name .. " for the " .. ChudSkins.WeaponName(item.weapon) .. ".")
    end,
    [2] = function(ply, item) -- equip
        if not Load(ply).owned[item.id] then Send(ply) return end
        SetEquipped(ply, item.weapon, item.id)
        Send(ply, item.name .. " equipped. It applies to guns you spawn with or take from containers.")
    end,
    [3] = function(ply, item) -- unequip
        if Load(ply).equipped[item.weapon] == item.id then SetEquipped(ply, item.weapon, nil) end
        Send(ply, item.name .. " unequipped.")
    end,
}

local function IsRTVStarted()
    return zb and zb.votestarted == true
end

local function ClearJackpotWeaponSkins(ply, revert, data, temporary)
    for _, wep in ipairs(ents.GetAll()) do
        if wep.ChudSkinJackpotOwner ~= ply then continue end

        if revert then
            local slot = ChudSkins.ClassSlot[wep:GetClass()]
            local equipped = slot and data.equipped[slot]
            local skin = equipped and not temporary[equipped] and equipped or wep.ChudSkinJackpotPreviousSkin or ""
            wep:SetNWString("ChudSkin", skin)
        end

        wep.ChudSkinJackpotOwner = nil
        wep.ChudSkinJackpotPreviousSkin = nil
    end
end

local function ClearTemporaryJackpot(ply, message)
    if not IsValid(ply) then return end

    local data = Load(ply)
    local temporary = data.temporary or {}
    local jackpot = ply.ChudSkinJackpot
    for class in pairs(jackpot and jackpot.temporarySlots or {}) do
        data.equipped[class] = jackpot.originalEquipped[class]
    end

    ClearJackpotWeaponSkins(ply, true, data, temporary)

    for id in pairs(temporary) do
        data.owned[id] = nil
    end
    data.temporary = {}
    ply.ChudSkinJackpot = nil
    activeJackpots[ply] = nil
    SetJackpotTimer(ply, false)
    Send(ply, message or "The temporary Coin Shop jackpot has ended.")
end

local function MakeJackpotPermanent(ply)
    if not ready then
        ErrorNoHalt("[ChudSkins] Could not save the Coin Shop jackpot: skin database is unavailable.\n")
        return false
    end

    local data = Load(ply)
    local jackpot = ply.ChudSkinJackpot
    local temporaryEquipped = {}
    for class in pairs(jackpot and jackpot.temporarySlots or {}) do
        local id = data.equipped[class]
        if id and data.temporary[id] then temporaryEquipped[class] = id end
    end

    local sid = sql.SQLStr(ply:SteamID64())
    sql.Begin()
    for id in pairs(ChudSkins.Items) do
        local result = sql.Query("INSERT OR IGNORE INTO chud_skins (steamid, item, equipped) VALUES ("
            .. sid .. ", " .. sql.SQLStr(id) .. ", 0)")
        if result == false then
            sql.Query("ROLLBACK")
            ErrorNoHalt("[ChudSkins] Could not save every Coin Shop jackpot item for " .. ply:SteamID64() .. ".\n")
            return false
        end
    end
    sql.Commit()

    for id in pairs(ChudSkins.Items) do
        data.owned[id] = true
        data.temporary[id] = nil
    end
    data.temporary = {}
    for class, id in pairs(temporaryEquipped) do
        SetEquipped(ply, class, id)
    end
    ClearJackpotWeaponSkins(ply, false, data, data.temporary)
    ply.ChudSkinJackpot = nil
    activeJackpots[ply] = nil
    SetJackpotTimer(ply, false)
    return true
end

function ChudSkins.StartJackpot(ply)
    if not IsValid(ply) or not ply:IsPlayer() or ply:IsBot() or not ply:Alive() or IsRTVStarted() then return false end
    if ply.ChudSkinJackpot then return false end

    local data = Load(ply)
    data.temporary = data.temporary or {}
    for id in pairs(ChudSkins.Items) do
        if not data.owned[id] then
            data.owned[id] = true
            data.temporary[id] = true
        end
    end

    local jackpot = {
        failed = false,
        startedAt = CurTime(),
        originalEquipped = table.Copy(data.equipped),
        temporarySlots = {},
    }
    ply.ChudSkinJackpot = jackpot
    activeJackpots[ply] = true
    Send(ply, "Every Coin Shop skin is temporarily yours. Stay alive for 30 seconds before RTV to keep them.")
    SetJackpotTimer(ply, true)

    net.Start("ChudSkins.JackpotNotice")
    net.WriteString(ply:Nick())
    net.WriteString(ply:SteamID64())
    net.Broadcast()

    local timerName = "ChudSkins.Jackpot." .. ply:UserID()
    timer.Create(timerName, 30, 1, function()
        if not IsValid(ply) or ply.ChudSkinJackpot ~= jackpot then return end
        if jackpot.failed or not ply:Alive() or IsRTVStarted() then return end

        if MakeJackpotPermanent(ply) then
            PrintMessage(HUD_PRINTTALK, "[Chud Shop Token] " .. ply:Nick()
                .. " survived 30 seconds and now owns all Coin Shop skins!")
            Send(ply, "You survived 30 seconds. Every Coin Shop skin is now permanently yours.")
        end
    end)

    return true
end

net.Receive("ChudSkins.Action", function(_, ply)
    if not IsValid(ply) or (ply.ChudSkinNext or 0) > CurTime() then return end
    ply.ChudSkinNext = CurTime() + 0.4
    local action, id = net.ReadUInt(2), net.ReadString()
    local item = ChudSkins.Get(id)
    if action ~= 0 and not item then return end
    handlers[action](ply, item)
end)

hook.Add("PlayerInitialSpawn", "ChudSkins.Load", function(ply)
    Load(ply)
    for jackpotPly in pairs(activeJackpots) do
        if not IsValid(jackpotPly) or not jackpotPly.ChudSkinJackpot then continue end

        net.Start("ChudSkins.JackpotHuntTimer")
        net.WriteBool(true)
        net.WriteString(jackpotPly:SteamID64())
        net.WriteString(jackpotPly:Nick())
        net.WriteFloat(math.max(30 - (CurTime() - (jackpotPly.ChudSkinJackpot.startedAt or CurTime())), 0))
        net.Send(ply)
    end
end)
hook.Add("PlayerDeath", "ChudSkins.JackpotDeath", function(victim)
    local jackpot = IsValid(victim) and victim.ChudSkinJackpot
    if jackpot then
        jackpot.failed = true
        timer.Remove("ChudSkins.Jackpot." .. victim:UserID())
        PrintMessage(HUD_PRINTTALK, "[Chud Shop Token] " .. victim:Nick()
            .. " died before surviving 30 seconds. The temporary shop skins are lost.")
        ClearTemporaryJackpot(victim, "You died and lost the temporary Coin Shop jackpot.")
    end
end)
hook.Add("PlayerDisconnected", "ChudSkins.JackpotDisconnect", function(ply)
    timer.Remove("ChudSkins.Jackpot." .. ply:UserID())
    activeJackpots[ply] = nil
end)
hook.Add("ChudSkinsRTVStarted", "ChudSkins.JackpotRTV", function()
    for ply in pairs(activeJackpots) do
        timer.Remove("ChudSkins.Jackpot." .. ply:UserID())
        ClearTemporaryJackpot(ply)
    end
end)

-- A gun gets its skin once, from the first player to receive it, and only when it
-- is new to the world: given on spawn (ply:Give) or taken out of a container.
-- Guns lying on the map and guns someone dropped keep whatever they already have.
hook.Add("WeaponEquip", "ChudSkins.Apply", function(wep, ply)
    local slot = IsValid(wep) and ChudSkins.ClassSlot[wep:GetClass()]
    if not slot or wep.ChudSkinDecided then return end
    wep.ChudSkinDecided = true
    if wep.IsSpawned and wep.init then return end -- loose ground loot / dropped gun
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local data = Load(ply)
    local id = data.equipped[slot]
    if id and ChudSkins.Covers(ChudSkins.Get(id), wep:GetClass()) then
        if data.temporary[id] then
            wep.ChudSkinJackpotOwner = ply
            wep.ChudSkinJackpotPreviousSkin = wep:GetNWString("ChudSkin", "")
        end
        wep:SetNWString("ChudSkin", id)
    end
end)

-- File reload: refresh connected players.
