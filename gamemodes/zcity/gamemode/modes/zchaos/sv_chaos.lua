if not SERVER then return end
local MODE = MODE
resource.AddFile("sound/chaos/rem_chaos.mp3")
local excluded = {weapon_ags_30_handheld = true, weapon_slugcat = true}

-- Spawnable SENTs also include cars, helicopters and map utilities. Only
-- recognised pickup/item families belong in the CHAOS loot pool.
local itemBases = {
    ammo_base = true, armor_base = true, attachment_base = true,
    ent_zcity_clothes_base = true, ent_jack_hmcd_loot_base = true,
    bomb = true, rem_bomb_base = true, firework_base = true
}
local itemClasses = {
    ent_hg_cyanide_plotnypih = true, ent_hg_bugbait = true,
    ent_hg_hmcd_radio = true, ent_hg_molotov = true,
    ent_hg_snowball = true, ent_zcity_match = true
}
local function IsChaosItem(class, data)
    local seen = {}
    while isstring(class) and not seen[class] do
        seen[class] = true
        if itemBases[class] or itemClasses[class] then return true end
        if string.StartWith(class, "ent_ammo_") or string.StartWith(class, "ent_armor_")
            or string.StartWith(class, "ent_att_") or string.StartWith(class, "item_") then return true end
        if not data then return false end
        if data.IsZPickup or data.IsLoot then return true end
        class = data.Base
        data = isstring(class) and scripted_ents.Get(class) or nil
    end
    return false
end

function MODE:BuildChaosLoot()
    local pool, seen = {}, {}
    local function Add(class, tab)
        if not isstring(class) or class == "" or excluded[class] or seen[class] then return end
        seen[class] = true
        pool[#pool + 1] = {class = class, tab = tab}
    end
    for _, entry in ipairs(weapons.GetList()) do
        local class = entry.ClassName
        local data = weapons.Get(class) or entry
        if data.Spawnable or data.AdminSpawnable or data.AdminOnly then Add(class, "Weapons") end
    end
    for class, stored in pairs(scripted_ents.GetList()) do
        local data = scripted_ents.Get(class) or stored.t
        if data and (data.Spawnable or data.AdminSpawnable or data.AdminOnly) and IsChaosItem(class, data) then
            local tab = "ChaosEntities"
            if string.StartWith(class, "ent_ammo_") and hg.ammotypeshuy and hg.ammotypeshuy[string.sub(class, 10)] then
                tab = "Ammo"
            elseif string.StartWith(class, "ent_armor_") then tab = "Armor"
            elseif string.StartWith(class, "ent_att_") then tab = "Attachments" end
            Add(class, tab)
        end
    end
    table.sort(pool, function(a, b) return a.class < b.class end)
    self.ChaosLootPool = pool
    self.ChaosLootRefresh = CurTime() + 30
    return pool
end

function MODE:GenerateChaosLoot(ply, ent, func)
    local pool = self.ChaosLootPool
    if not pool or CurTime() >= (self.ChaosLootRefresh or 0) then pool = self:BuildChaosLoot() end
    if #pool == 0 then return end
    -- One flat draw: every registered item has exactly one ticket, including admin items.
    local item = pool[math.random(1, #pool)]
    local amount
    if item.tab == "Ammo" then
        local ammo = hg.ammotypeshuy[string.sub(item.class, 10)]
        local definition = ammo and hg.ammoents and hg.ammoents[ammo.name]
        amount = definition and definition.Count or 30
    end
    if func then return func(item.class, amount, item.tab) end
    return item.class, amount, item.tab
end

