include("chud_barry/sh_manifest.lua")
local kit = ChudBarryMusic
local enabled = CreateClientConVar("chud_barry_music", "0", true, false, "Toggle all sounds in Barry's sound pack", 0, 1)
function kit.Resolve(path)
    return enabled:GetBool() and kit.Replacement(path) or path
end
kit.Original = kit.Original or {}
local original = kit.Original
original.PlayFile = original.PlayFile or sound.PlayFile
original.PlaySound = original.PlaySound or surface.PlaySound
original.CreateSound = original.CreateSound or CreateSound
original.Play = original.Play or sound.Play
original.EmitSound = original.EmitSound or EmitSound
sound.PlayFile = function(path, flags, callback)
    return original.PlayFile(kit.Resolve(path), flags, callback)
end
surface.PlaySound = function(path) return original.PlaySound(kit.Resolve(path)) end
sound.Play = function(path, ...) return original.Play(kit.Resolve(path), ...) end
EmitSound = function(path, ...) return original.EmitSound(kit.Resolve(path), ...) end
CreateSound = function(ent, path, ...) return original.CreateSound(ent, kit.Resolve(path), ...) end
hook.Add("EntityEmitSound", "ChudBarryMusic", function(data)
    local replacement = kit.Resolve(data.SoundName)
    if replacement ~= data.SoundName then data.SoundName = replacement return true end
end)
-- Stop either variant even when the setting changed after the sound started.
local entity = FindMetaTable("Entity")
original.StopSound = original.StopSound or entity.StopSound
entity.StopSound = function(ent, path)
    original.StopSound(ent, path)
    local replacement = kit.Replacement(path)
    if replacement ~= path then original.StopSound(ent, replacement) end
end
local function SendPreference()
    if not IsValid(LocalPlayer()) or util.NetworkStringToID("ChudBarryPreference") == 0 then return end
    net.Start("ChudBarryPreference") net.WriteBool(enabled:GetBool()) net.SendToServer()
end
hook.Add("InitPostEntity", "ChudBarryPreference", SendPreference)
cvars.AddChangeCallback("chud_barry_music", SendPreference, "ChudBarryPreference")
net.Receive("ChudBarryPreference", SendPreference)
