if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("zz_infection/sh_core.lua")
    AddCSLuaFile("zz_infection/cl_effects.lua")
end
include("zz_infection/sh_core.lua")
if SERVER then include("zz_infection/sv_infection.lua") else include("zz_infection/cl_effects.lua") end
