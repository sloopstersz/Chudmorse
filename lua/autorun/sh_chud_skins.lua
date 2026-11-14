-- Chudmorse COIN gun skins: item list, and how a skin is drawn on a gun model.
-- A skin lives on the weapon entity (NW string "ChudSkin"), so every player sees
-- it and it stays on the gun when it is dropped, looted from a body or picked up.
if SERVER then AddCSLuaFile() end

ChudSkins = ChudSkins or {}

local P22_BODY = "models/zcity/skins/walther_p22/classic/walther2"
local P22_PARTS = "models/zcity/skins/walther_p22/classic/walther1"

-- Materials the stock model already uses, so a shop preview looks like the real gun.
ChudSkins.Weapons = {
    weapon_p22 = {name = "WALTHER P22", base = {[0] = P22_BODY, [1] = P22_PARTS}},
    weapon_deagle = {name = "DESERT EAGLE", base = {}},
    weapon_m1911 = {name = "COLT M1911", base = {}},
    weapon_hk_usp = {name = "HK USP", base = {}},
    weapon_combatknife = {name = "M7 BAYONET", base = {}},
    weapon_sogknife = {name = "SOG SEAL 2000", base = {}},
}

-- order: position in the shop list. sub: material slot -> texture swapped into
-- that slot's stock material. tint: $color2 applied to every gun material.
-- credit: who made the skin, shown under the gun name in the shop.
-- accent: the item's colour in the shop (card bar, showcase glow, buy button).
-- weapon: the gun the skin is equipped on (one skin equipped per weapon).
-- weapons: optional extra gun classes the same skin also goes on (e.g. 1911 variants).
-- replace: stock material path -> skin material, swapped wherever the model uses it.
ChudSkins.Items = {
    p22_red_dragon = {
        order = 1, name = "RED DRAGON", accent = Color(225, 45, 40), weapon = "weapon_p22", price = 500, category = "GUN SKINS", credit = "LOGAN",
        sub = {[0] = {from = P22_BODY, texture = "chudmorse/skins/p22_red_dragon"}},
    },
    p22_gold_finish = {
        order = 2, name = "GOLD FINISH", accent = Color(230, 185, 70), weapon = "weapon_p22", price = 1000, category = "GUN SKINS", credit = "LOGAN",
        sub = {[0] = {from = P22_BODY, texture = "chudmorse/skins/p22_gold_finish"}},
    },
    deagle_red_finish = {
        order = 3, name = "RED FINISH", accent = Color(200, 35, 35), weapon = "weapon_deagle", price = 250, category = "GUN SKINS", credit = "LOGAN",
        skin = 0, tint = Vector(1.7, 0.12, 0.12),
    },

    -- Gofitc5's skins
    p22_blackout_dragon = {
        order = 4, name = "BLACKOUT DRAGON", accent = Color(190, 30, 30), weapon = "weapon_p22", price = 750, category = "GUN SKINS", credit = "GOFITC5",
        sub = {[0] = {from = P22_BODY, texture = "chudmorse/skins/p22_red_dragon"},
               [1] = {from = P22_PARTS, texture = "chudmorse/skins/gofit/p22/walther1_black"}},
    },
    m1911_gofit = {
        order = 5, name = "PHOTO GRIP", accent = Color(200, 60, 70), weapon = "weapon_m1911", price = 500, category = "GUN SKINS", credit = "GOFITC5",
        weapons = {"weapon_m1911compact", "weapon_m1911custom", "weapon_m45"},
        replace = {
            ["models/weapons/1911/weapon_m1911_dm"] = "chudmorse/skins/gofit/m1911/weapon_m1911_dm",
            ["models/weapons/1911/weapon_w_m45_dm"] = "chudmorse/skins/gofit/m1911/weapon_w_m45_dm",
        },
    },
    usp_stardust = {
        order = 6, name = "STARDUST", accent = Color(235, 110, 170), weapon = "weapon_hk_usp", price = 500, category = "GUN SKINS", credit = "GOFITC5",
        replace = {
            ["models/weapons/tfa_ins2/usp_match/usp_weapon"] = "chudmorse/skins/gofit/usp/usp_weapon",
            ["models/weapons/tfa_ins2/usp_match/usp_match"] = "chudmorse/skins/gofit/usp/usp_match",
            ["models/weapons/tfa_ins2/usp_match/usp_suppressor"] = "chudmorse/skins/gofit/usp/usp_suppressor",
        },
    },
    m7_cyan_edge = {
        order = 7, name = "CYAN EDGE", accent = Color(40, 210, 230), weapon = "weapon_combatknife", price = 400, category = "MELEE SKINS", credit = "GOFITC5",
        replace = {["zaihny/cs2/weapons/m7bay/m7_bay"] = "chudmorse/skins/gofit/m7/m7_bay"},
    },

    -- Held and dropped SOG models use different textures, so both are replaced.
    -- (The held model is shared with the Buck knife, but only SOG knives can carry this skin.)
    sog_didi_camel = {
        order = 8, name = "DIDI CAMEL KNIFE", accent = Color(215, 215, 205), weapon = "weapon_sogknife", price = 5000, category = "MELEE SKINS",
        replace = {
            ["models/weapons/v_models/sw0rd/sw0rd"] = "chudmorse/skins/didi/sog_held_didi",
            ["models/weapons/sogknife/sog"] = "chudmorse/skins/didi/sog_dropped_didi",
        },
    },
}
-- class -> equip slot (the item's main weapon), for every class a skin can go on.
ChudSkins.ClassSlot = {}
for id, item in pairs(ChudSkins.Items) do
    item.id = id
    ChudSkins.ClassSlot[item.weapon] = item.weapon
    for _, class in ipairs(item.weapons or {}) do ChudSkins.ClassSlot[class] = item.weapon end
end

function ChudSkins.Covers(item, class)
    if not item then return false end
    if item.weapon == class then return true end
    for _, other in ipairs(item.weapons or {}) do if other == class then return true end end
    return false
end

function ChudSkins.Get(id)
    return isstring(id) and ChudSkins.Items[id] or nil
end

function ChudSkins.ItemsInCategory(category)
    local list = {}
    for _, item in pairs(ChudSkins.Items) do
        if item.category == category then list[#list + 1] = item end
    end
    table.SortByMember(list, "order", true)
    return list
end

function ChudSkins.WeaponName(class)
    local info = ChudSkins.Weapons[class]
    if info then return info.name end
    local stored = weapons.GetStored(class)
    return stored and string.upper(stored.PrintName or class) or class
end

if SERVER then return end

-- Player-owned items arrive from the server: {owned = {id = true}, equipped = {class = id}}.
ChudSkins.Mine = ChudSkins.Mine or {owned = {}, equipped = {}}

function ChudSkins.Owns(id) return ChudSkins.Mine.owned[id] == true end
function ChudSkins.IsEquipped(id)
    local item = ChudSkins.Get(id)
    return item ~= nil and ChudSkins.Mine.equipped[item.weapon] == id
end

net.Receive("ChudSkins.Sync", function()
    local mine = {owned = {}, equipped = {}}
    for _ = 1, net.ReadUInt(8) do mine.owned[net.ReadString()] = true end
    for _ = 1, net.ReadUInt(8) do
        local class = net.ReadString()
        mine.equipped[class] = net.ReadString()
    end
    ChudSkins.Mine = mine
    local message = net.ReadString()
    if message ~= "" then chat.AddText(Color(220, 220, 220), "[SHOP] ", color_white, message) end
    hook.Run("ChudSkinsUpdated", mine)
end)

-- action: "sync", "buy", "equip" or "unequip"
local actions = {sync = 0, buy = 1, equip = 2, unequip = 3}
function ChudSkins.Request(action, id)
    net.Start("ChudSkins.Action")
    net.WriteUInt(actions[action] or 0, 2)
    net.WriteString(id or "")
    net.SendToServer()
end

hook.Add("InitPostEntity", "ChudSkins.Sync", function() ChudSkins.Request("sync") end)

-- Material building. Copying the stock material keeps its normal map and shine;
-- only the texture (or colour) changes. Falls back to the shipped .vmt.
local flagKeys = {
    [0x40] = "$selfillum", [0x80] = "$additive", [0x100] = "$alphatest", [0x800] = "$model",
    [0x2000] = "$nocull", [0x100000] = "$basealphaenvmapmask", [0x200000] = "$translucent",
    [0x400000] = "$normalmapalphaenvmapmask", [0x8000000] = "$halflambert",
}
local skipKeys = {["$flags"] = true, ["$flags2"] = true, ["$flags_defined"] = true, ["$flags_defined2"] = true}
local built = {}

local function ShaderName(mat)
    local shader = string.lower(mat:GetShader() or "")
    if string.find(shader, "vertexlitgeneric", 1, true) then return "VertexLitGeneric" end
    if string.find(shader, "unlitgeneric", 1, true) then return "UnlitGeneric" end
    return mat:GetShader()
end

local function CopyMaterial(name, from, overrides)
    if built[name] ~= nil then return built[name] end
    local source = Material(from)
    if source:IsError() then built[name] = false return false end
    local values = {}
    for key, value in pairs(source:GetKeyValues()) do
        if skipKeys[string.lower(key)] then
        elseif isstring(value) then values[key] = value
        elseif isnumber(value) then values[key] = tostring(value)
        elseif isvector(value) then values[key] = string.format("[%g %g %g]", value.x, value.y, value.z)
        elseif type(value) == "ITexture" and not value:IsError() then values[key] = value:GetName() end
    end
    local flags = source:GetInt("$flags") or 0
    for bit_, key in pairs(flagKeys) do
        if bit.band(flags, bit_) ~= 0 then values[key] = "1" end
    end
    for key, value in pairs(overrides) do values[key] = value end
    local ok = pcall(CreateMaterial, name, ShaderName(source), values)
    built[name] = ok and ("!" .. name) or false
    return built[name]
end

local function IsGunMaterial(path)
    path = string.lower(path)
    return not (string.find(path, "hand", 1, true) or string.find(path, "arm", 1, true)
        or string.find(path, "glove", 1, true) or string.find(path, "sleeve", 1, true))
end

local function Normalize(path)
    return (string.lower(string.gsub(path or "", "\\", "/")))
end

-- Draw skin `id` on a gun model. Pass the weapon when the model belongs to one,
-- so its own look (bodygroups, stock materials) is restored first.
function ChudSkins.ApplyToModel(model, id, wep)
    if not IsValid(model) then return end
    id = id or ""
    local item = ChudSkins.Get(id)
    model:SetSubMaterial()
    if IsValid(wep) then
        if wep.ModelCreated then pcall(wep.ModelCreated, wep, model) end
    else
        local info = item and ChudSkins.Weapons[item.weapon]
        for slot, path in pairs(info and info.base or {}) do model:SetSubMaterial(slot, path) end
    end
    model.ChudSkin = id
    model.ChudSkinModel = model:GetModel()
    if not item then return end
    if item.skin then model:SetSkin(item.skin) end
    for slot, def in pairs(item.sub or {}) do
        local mat = CopyMaterial("chudskin_" .. id .. "_" .. slot, def.from, {["$basetexture"] = def.texture})
        model:SetSubMaterial(slot, mat or def.texture)
    end
    if item.replace then
        for i, path in ipairs(model:GetMaterials()) do
            local swap = item.replace[Normalize(path)]
            if not swap then
                -- The model's material may have another name but use the same texture.
                local tex = Material(path):GetTexture("$basetexture")
                if tex and not tex:IsError() then swap = item.replace[Normalize(tex:GetName())] end
            end
            if swap then model:SetSubMaterial(i - 1, swap) end
        end
    end
    if item.tint then
        local color = string.format("[%g %g %g]", item.tint.x, item.tint.y, item.tint.z)
        for i, path in ipairs(model:GetMaterials()) do
            if IsGunMaterial(path) then
                local mat = CopyMaterial("chudskin_" .. id .. "_" .. util.CRC(path), path, {["$color2"] = color})
                if mat then model:SetSubMaterial(i - 1, mat) end
            end
        end
    end
end

-- Weapon world models are client-side models made on demand, so keep them in
-- step with each gun's networked skin. This also covers guns on the ground,
-- holstered, held by other players and in ragdolls.
-- Melee weapons swap models (held vs dropped), so check each model they draw.
local function Sync(model, id, wep)
    if not IsValid(model) then return end
    if (model.ChudSkin or "") ~= id or (id ~= "" and model.ChudSkinModel ~= model:GetModel()) then
        ChudSkins.ApplyToModel(model, id, wep)
    end
end
timer.Create("ChudSkins.Apply", 0.2, 0, function()
    for class in pairs(ChudSkins.ClassSlot) do
        for _, wep in ipairs(ents.FindByClass(class)) do
            local id = wep:GetNWString("ChudSkin", "")
            Sync(wep.worldModel, id, wep)
            Sync(wep.worldModel2, id, wep)
        end
    end
end)
