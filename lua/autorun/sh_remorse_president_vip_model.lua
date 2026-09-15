-- Bundled CS:S VIP model registration for the Remorse President mode.
if SERVER then
    AddCSLuaFile()
end

player_manager.AddValidModel("Remorse_President_VIP", "models/male_09_vip/vip_player/male_09_vip_player.mdl")
player_manager.AddValidHands("Remorse_President_VIP", "models/male_09_vip/vip_hands/c_arms_vip.mdl", 0, "00000000")
list.Set("PlayerOptionsAnimations", "Remorse_President_VIP", { "pose_standing_02", "pose_standing_04" })
