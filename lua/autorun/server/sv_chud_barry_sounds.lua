AddCSLuaFile("chud_barry/sh_manifest.lua")
include("chud_barry/sh_manifest.lua")
local kit = ChudBarryMusic
util.AddNetworkString("ChudBarryPreference")
kit.Listeners = kit.Listeners or {}
net.Receive("ChudBarryPreference", function(_, ply) kit.Listeners[ply] = net.ReadBool() end)
hook.Add("PlayerDisconnected", "ChudBarryPreference", function(ply) kit.Listeners[ply] = nil end)
hook.Add("PlayerInitialSpawn", "ChudBarryPreference", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then net.Start("ChudBarryPreference") net.Send(ply) end
    end)
end)
kit.ServerOriginal = kit.ServerOriginal or {}
local original = kit.ServerOriginal
local entity = FindMetaTable("Entity")
original.EntityEmitSound = original.EntityEmitSound or entity.EmitSound
original.EmitSound = original.EmitSound or EmitSound
original.StopSound = original.StopSound or entity.StopSound
local routing, currentFilter = false, nil
-- Preserve explicit recipient filters used for private sounds.
entity.EmitSound = function(ent, name, level, pitch, volume, channel, flags, dsp, filter)
    local previous = currentFilter
    currentFilter = filter
    local result = original.EntityEmitSound(ent, name, level, pitch, volume, channel, flags, dsp, filter)
    currentFilter = previous
    return result
end
EmitSound = function(name, pos, index, channel, volume, level, flags, pitch, dsp, filter)
    local previous = currentFilter
    currentFilter = filter
    local result = original.EmitSound(name, pos, index, channel, volume, level, flags, pitch, dsp, filter)
    currentFilter = previous
    return result
end
local function Split(filter, pos, level)
    local recipients = filter
    if not recipients then
        recipients = RecipientFilter()
        if level == 0 then recipients:AddAllPlayers() else recipients:AddPAS(pos) end
    end
    local normal, barry = RecipientFilter(), RecipientFilter()
    for _, ply in ipairs(recipients:GetPlayers()) do
        if kit.Listeners[ply] then barry:AddPlayer(ply) else normal:AddPlayer(ply) end
    end
    return normal, barry
end
hook.Add("EntityEmitSound", "ChudBarryServerSounds", function(data)
    if routing then return end
    local replacement = kit.Replacement(data.SoundName)
    if replacement == data.SoundName then return end
    local pos = data.Pos or (IsValid(data.Entity) and data.Entity:GetPos()) or vector_origin
    local normal, barry = Split(currentFilter, pos, data.SoundLevel)
    if #barry:GetPlayers() == 0 then return end
    local index = IsValid(data.Entity) and data.Entity:EntIndex() or 0
    routing = true
    if #normal:GetPlayers() > 0 then
        original.EmitSound(data.SoundName, pos, index, data.Channel, data.Volume, data.SoundLevel, data.Flags, data.Pitch, data.DSP, normal)
    end
    original.EmitSound(replacement, pos, index, data.Channel, data.Volume, data.SoundLevel, data.Flags, data.Pitch, data.DSP, barry)
    routing = false
    return false
end)
entity.StopSound = function(ent, path)
    original.StopSound(ent, path)
    local replacement = kit.Replacement(path)
    if replacement ~= path then original.StopSound(ent, replacement) end
end
-- Sound patches keep engine handles: pair the original and replacement patches,
-- forwarding volume/pitch/fade/stop operations without changing the caller's type.
original.CreateSound = original.CreateSound or CreateSound
kit.Patches = kit.Patches or setmetatable({}, {__mode = "k"})
local patchMeta = FindMetaTable("CSoundPatch")
if patchMeta then
    original.PatchMethods = original.PatchMethods or {}
    for _, method in ipairs({"Play", "PlayEx", "Stop", "FadeOut", "ChangeVolume", "ChangePitch", "SetSoundLevel", "SetDSP"}) do
        if patchMeta[method] then
            original.PatchMethods[method] = original.PatchMethods[method] or patchMeta[method]
            local fn = original.PatchMethods[method]
            patchMeta[method] = function(patch, ...)
                local previous = routing
                if kit.Patches[patch] then routing = true end
                local result = fn(patch, ...)
                if kit.Patches[patch] then fn(kit.Patches[patch], ...) end
                routing = previous
                return result
            end
        end
    end
end
CreateSound = function(ent, path, filter)
    local replacement = kit.Replacement(path)
    if not patchMeta or replacement == path then return original.CreateSound(ent, path, filter) end
    if not filter then filter = RecipientFilter() filter:AddAllPlayers() end
    local normal, barry = Split(filter, IsValid(ent) and ent:GetPos() or vector_origin, 75)
    local first = original.CreateSound(ent, path, normal)
    local second = original.CreateSound(ent, replacement, barry)
    if first and second then kit.Patches[first] = second end
    return first
end
