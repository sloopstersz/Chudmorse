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

util.AddNetworkString("ChudSkins.Sync")
util.AddNetworkString("ChudSkins.Action")

local ready = sql.Query([[CREATE TABLE IF NOT EXISTS chud_skins (
    steamid TEXT NOT NULL, item TEXT NOT NULL, equipped INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (steamid, item))]]) ~= false

local function Load(ply)
    if ply.ChudSkinData then return ply.ChudSkinData end
    local data = {owned = {}, equipped = {}}
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

local function SetEquipped(ply, class, id)
    local sid = sql.SQLStr(ply:SteamID64())
    local others = {}
    for otherId, item in pairs(ChudSkins.Items) do
        if item.weapon == class then others[#others + 1] = sql.SQLStr(otherId) end
    end
    sql.Begin()
    sql.Query("UPDATE chud_skins SET equipped = 0 WHERE steamid = " .. sid .. " AND item IN (" .. table.concat(others, ",") .. ")")
    if id then sql.Query("UPDATE chud_skins SET equipped = 1 WHERE steamid = " .. sid .. " AND item = " .. sql.SQLStr(id)) end
    sql.Commit()
    Load(ply).equipped[class] = id
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

net.Receive("ChudSkins.Action", function(_, ply)
    if not IsValid(ply) or (ply.ChudSkinNext or 0) > CurTime() then return end
    ply.ChudSkinNext = CurTime() + 0.4
    local action, id = net.ReadUInt(2), net.ReadString()
    local item = ChudSkins.Get(id)
    if action ~= 0 and not item then return end
    handlers[action](ply, item)
end)

hook.Add("PlayerInitialSpawn", "ChudSkins.Load", function(ply) Load(ply) end)

-- A gun gets its skin once, from the first player to receive it, and only when it
-- is new to the world: given on spawn (ply:Give) or taken out of a container.
-- Guns lying on the map and guns someone dropped keep whatever they already have.
hook.Add("WeaponEquip", "ChudSkins.Apply", function(wep, ply)
    local slot = IsValid(wep) and ChudSkins.ClassSlot[wep:GetClass()]
    if not slot or wep.ChudSkinDecided then return end
    wep.ChudSkinDecided = true
    if wep.IsSpawned and wep.init then return end -- loose ground loot / dropped gun
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local id = Load(ply).equipped[slot]
    if id and ChudSkins.Covers(ChudSkins.Get(id), wep:GetClass()) then wep:SetNWString("ChudSkin", id) end
end)

-- File reload: refresh connected players.
for _, ply in ipairs(player.GetHumans()) do
    ply.ChudSkinData = nil
    Send(ply)
end
