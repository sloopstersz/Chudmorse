-- Bundled Payday 2 Bulldozer model registration for Remorse Juggernaut mode.
if SERVER then
    AddCSLuaFile()
end

list.Set("PlayerOptionsAnimations", "PD2_Bulldozer", {"idle_all_angry", "idle_all_01", "menu_walk"})
player_manager.AddValidModel("PD2_Bulldozer", "models/mark2580/payday2/pd2_bulldozer_player.mdl")
player_manager.AddValidHands("PD2_Bulldozer", "models/mark2580/payday2/bulldozer_c_arms.mdl", 0, "00000000")
