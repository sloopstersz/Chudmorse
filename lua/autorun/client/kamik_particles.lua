AddCSLuaFile()
game.AddParticles( "particles/kamik_bomb.pcf") 

if CLIENT then
    killicon.Add("drone", "vgui/killicons/kamikaze_k", Color(255, 80, 0, 191))
	killicon.Add("drone_shrapnel_burst", "vgui/killicons/kamikaze_k", Color(255, 80, 0, 191))
	killicon.Add("kamikaze", "vgui/killicons/kamikaze_k", Color(255, 80, 0, 191))
end
