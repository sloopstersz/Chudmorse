-- Registers the MWII / MWIII takedown animations with DynaBase so the Martial Artist back
-- moves (Cage Match, Sweet Dreams, Suplex Deluxe, Neck Trauma) can find their
-- execution_*_attacker_stand / execution_*_victim_stand sequences on the player models.
--
-- The animations live in models/mwiii/dynabase_player_anims.mdl, which comes from the
-- Workshop item "Modern Warfare II/III Takedowns" (id 3171024609).
--
-- This only registers when that model actually exists. DynaBase writes the model path into
-- the player base model without checking it, so registering a missing file could break the
-- player models for everyone.
local ANIM_MDL = "models/mwiii/dynabase_player_anims.mdl"

hook.Add("InitLoadAnimations", "wOS.DynaBase.MWIII", function()
    if not file.Exists(ANIM_MDL, "GAME") then return end

    wOS.DynaBase:RegisterSource({
        Name = "MWIII Takedowns/Downed Animations",
        Type = WOS_DYNABASE.EXTENSION,
        Male = ANIM_MDL,
        Female = ANIM_MDL,
        Zombie = ANIM_MDL,
    })

    hook.Add("PreLoadAnimations", "wOS.DynaBase.MWIII", function(gender)
        if gender == WOS_DYNABASE.SHARED then
            IncludeModel(ANIM_MDL)
        end
    end)
end)
