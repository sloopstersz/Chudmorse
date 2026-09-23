
MODE.name = "chudbeasts"
MODE.PrintName = "Chud Beasts"

local MODE = MODE

local radius = nil
local mapsize = 7500
-- MODE.MapSize = mapsize

StartTime = StartTime or 0

zb.ROUND_START = zb.ROUND_START or 0

ZonePos = ZonePos or Vector(0,0,0)
dmmusic = dmmusic or nil

local roundend = false

local CHUD_BEAST_MUSIC = "sound/chudbeasts/beats.mp3"
local CHUD_BEAST_MUSIC_VOLUME = 0.30
local CHUD_BEAST_INTRO_DURATION = 8.5
local musicWanted = false
local musicLoadAttempts = 0

local healthFontFace = hg_font_default or "Arial"
if hg_font and hg_font:GetString() ~= "" then
	healthFontFace = hg_font:GetString()
end

surface.CreateFont("ZB_ChudBeastsHealth", {
	font = healthFontFace,
	size = ScreenScale(11),
	weight = 400,
	antialias = true
})

local function getMusicVolume()
	local cv = GetConVar("snd_musicvolume")
	return cv and cv:GetFloat() or 1
end

local function stopMusic()
	timer.Remove("ChudBeasts_MusicRetry")

	if IsValid(dmmusic) then
		dmmusic:Stop()
		dmmusic = nil
	end
end

local function restartMusic()
	stopMusic()
	if not musicWanted then return end

	musicLoadAttempts = musicLoadAttempts + 1

	-- Load locally from the addon, then explicitly start the BASS channel in
	-- the callback.  The old version relied on HUDPaint to call :Play(), so a
	-- successfully loaded track could remain silent if that HUD path did not run.
	sound.PlayFile(CHUD_BEAST_MUSIC, "noplay noblock", function(station, errID, err)
		if not musicWanted then
			if IsValid(station) then station:Stop() end
			return
		end

		if IsValid(station) then
			musicLoadAttempts = 0
			dmmusic = station
			station:SetVolume(CHUD_BEAST_MUSIC_VOLUME * getMusicVolume())
			station:Play()
		else
			print("[Chud Beasts] Failed to load round music:", errID, err)

			-- Give the client a few chances in case the resource finished mounting
			-- just after the round-start net message arrived.
			if musicWanted and musicLoadAttempts < 5 then
				timer.Create("ChudBeasts_MusicRetry", 1, 1, restartMusic)
			end
		end
	end)
end

-- Keep playback alive independently of MODE:HUDPaint.  This also makes the
-- local MP3 loop even if the mode HUD is hidden or another panel is open.
hook.Add("Think", "ChudBeasts_MusicPlayback", function()
	if not musicWanted or not IsValid(dmmusic) then return end

	local length = dmmusic:GetLength() or 0
	if length > 0 and dmmusic:GetTime() >= length - 0.15 then
		dmmusic:SetTime(0)
		dmmusic:Play()
	elseif dmmusic:GetState() ~= GMOD_CHANNEL_PLAYING then
		dmmusic:Play()
	end
end)

net.Receive("chudbeasts_start",function()	
	roundend = false
	musicWanted = true
	musicLoadAttempts = 0

	restartMusic()

	zb.RemoveFade()
	
    StartTime = CurTime()
	MODE.DynamicFadeScreenEndTime = CurTime() + CHUD_BEAST_INTRO_DURATION
	MODE.CursorLerpX = 0
	MODE.CursorLerpY = 0
	MODE.RoundTextTilts = {}
	for index = 1, 3 do
		MODE.RoundTextTilts[index] = math.random() < 0.5 and 3 or -3
	end
    ZonePos = net.ReadVector()
    --surface.PlaySound("snd_jack_hmcd_deathmatch.mp3")
end)

local fighter = {
    objective = "Kill everyone.",
    name = "Chud Beast",
    color1 = Color(0,120,190)
}

local function chudBeastsEaseOut(value)
	return 1 - (1 - value) ^ 3
end

local function drawChudBeastsIntroText(text, font, x, y, color, alpha, angle)
	local matrix = Matrix()
	matrix:Translate(Vector(x, y, 0))
	matrix:Rotate(Angle(0, angle or 0, 0))
	matrix:Translate(Vector(-x, -y, 0))

	cam.PushModelMatrix(matrix)
		draw.SimpleText(text, font, x, y, Color(color.r, color.g, color.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.PopModelMatrix()
end

--local zonemodel = ClientsideModel("models/hunter/misc/sphere375x375.mdl",RENDERGROUP_TRANSLUCENT)
--zonemodel:SetNoDraw(true)
--zonemodel:SetMaterial("hmcd_dmzone")

local mat = Material("hmcd_dmzone")

local mapsize = 7500

function MODE:PostDrawTranslucentRenderables(bDepth, bSkybox, isDraw3DSkybox)
	if(!bSkybox and !isDraw3DSkybox)then
		--render.SetMaterial(mat)
		--render.DrawSphere( ZonePos, -(mapsize * math.max(( (zb.ROUND_START + 300) - CurTime()) / 300,0.025)), 60, 60, color_white )
	end
	--zonemodel:DrawModel()
end

function MODE:RenderScreenspaceEffects()
end

function MODE:HUDPaint()
	if zb.ROUND_START + 5 > CurTime() then
		draw.SimpleText( string.FormattedTime(zb.ROUND_START + 5 - CurTime(), "%02i:%02i:%02i"	), "ZB_HomicideMedium", sw * 0.5, sh * 0.75, Color(255,55,55), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		local ply = LocalPlayer()
		if IsValid(dmmusic) then
			if dmmusic:GetTime() >= (dmmusic:GetLength() - 1) then
				restartMusic()

				return
			end

			if dmmusic:GetState() != GMOD_CHANNEL_PLAYING then
				dmmusic:Play()
				
				return
			end

			-- Keep the main track at a steady level. Adrenaline rises when another
			-- player dies, which previously made the music surge with the death bell.
				local maxVolume = ply:Alive() and ply.organism and ply.organism.otrub and 0.1 or 1
			local vol = math.Clamp((CurTime() - (zb.ROUND_START + 7)), 0.1, maxVolume)
			if roundend then
				vol = math.Clamp((roundend - CurTime() + 1) / 2, 0.1, maxVolume)
			end
			local musicVolume = GetConVar("snd_musicvolume"):GetFloat()
			dmmusic:SetVolume(vol * musicVolume * CHUD_BEAST_MUSIC_VOLUME)
		end
	end
	
	for i, ply in player.Iterator() do
		if ply == LocalPlayer() or not ply:Alive() then continue end
		local tr = hg.eyeTrace(ply)
		-- eyeTrace can temporarily return nil while a player/model is being
		-- initialized or during a nested RenderView. Fall back to EyePos so one
		-- missing trace cannot break HUDPaint every frame.
		local pos = (tr and isvector(tr.StartPos) and tr.StartPos or ply:EyePos()) + vector_up * 15
		local posscr = pos:ToScreen()
		draw.SimpleTextOutlined(ply:Name(), "ScoreboardDefault", posscr.x, posscr.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 220))
	end

	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) or not localPlayer:Alive() or localPlayer:Team() == TEAM_SPECTATOR then return end

	-- Local-player health bar at the bottom of the screen. This HUD is scoped
	-- to Chud Beasts because it is drawn only by this mode's HUDPaint.
	local health = math.max(localPlayer:Health(), 0)
	local maxHealth = math.max(localPlayer:GetMaxHealth(), 1)
	local healthFraction = math.Clamp(health / maxHealth, 0, 1)
	local barWidth = math.min(ScrW() * 0.34, 520)
	local barHeight = 24
	local barX = (ScrW() - barWidth) * 0.5
	-- Keep the bar comfortably above the bottom HUD/menu strip.
	local barY = ScrH() - 100

	surface.SetDrawColor(20, 20, 20, 220)
	surface.DrawRect(barX - 3, barY - 3, barWidth + 6, barHeight + 6)
	surface.SetDrawColor(55, 55, 55, 245)
	surface.DrawRect(barX, barY, barWidth, barHeight)
	surface.SetDrawColor(255 * (1 - healthFraction), 210 * healthFraction, 45, 255)
	surface.DrawRect(barX, barY, barWidth * healthFraction, barHeight)
	draw.SimpleTextOutlined("HEALTH", "ZB_ChudBeastsHealth", ScrW() * 0.5, barY + barHeight * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 230))

	local elapsed = CurTime() - StartTime
	if elapsed < 0 or elapsed > CHUD_BEAST_INTRO_DURATION then return end
	if zb and zb.RemoveFade then zb.RemoveFade() end

	local timeLeft = CHUD_BEAST_INTRO_DURATION - elapsed
	local backgroundFade = math.min(timeLeft / 2.5, 1)
	local outFade = math.Clamp(timeLeft / 1.5, 0, 1)

	-- Normal Remorse intro: black background first, then sliding and tilted text.
	surface.SetDrawColor(0, 0, 0, 255 * backgroundFade)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)

	MODE.CursorLerpX = Lerp(FrameTime() * 6, MODE.CursorLerpX or 0, (gui.MouseX() - sw * 0.5) / (sw * 0.5))
	MODE.CursorLerpY = Lerp(FrameTime() * 6, MODE.CursorLerpY or 0, (gui.MouseY() - sh * 0.5) / (sh * 0.5))

	local cursorReach = ScreenScale(7)
	local cursorX = math.Clamp(MODE.CursorLerpX, -1, 1) * cursorReach
	local cursorY = math.Clamp(MODE.CursorLerpY, -1, 1) * cursorReach
	local elements = {
		{ text = "Chud Beasts", font = "ZB_HomicideHeader", color = color_white, x = sw * 0.5, y = sh * 0.1, dir = "left", delay = 0, parallax = 0.9, tilt = true },
		{ text = "You are a " .. fighter.name, font = "ZB_HomicideMediumLarge", color = fighter.color1, x = sw * 0.5, y = sh * 0.5, dir = "right", delay = 0.7, parallax = 1.1, tilt = true },
		{ text = fighter.objective, font = "ZB_HomicideMedium", color = color_white, x = sw * 0.5, y = sh * 0.9, dir = "bottom", delay = 1.4, parallax = 1.3, tilt = false }
	}

	for index, element in ipairs(elements) do
		local appear = chudBeastsEaseOut(math.Clamp((elapsed - element.delay) / 2, 0, 1))
		local alpha = 255 * appear * outFade
		if alpha <= 1 then continue end

		local slide = 1 - appear
		local x = element.x + cursorX * element.parallax
		local y = element.y + cursorY * element.parallax
		if element.dir == "left" then x = x - slide * ScreenScale(220) end
		if element.dir == "right" then x = x + slide * ScreenScale(220) end
		if element.dir == "bottom" then y = y + slide * ScreenScale(120) end

		local angle = element.tilt and ((MODE.RoundTextTilts or {})[index] or 3) * appear or 0
		drawChudBeastsIntroText(element.text, element.font, x, y, element.color, alpha, angle)
	end
end

local CreateEndMenu = nil
local wonply = nil

net.Receive("chudbeasts_end",function()
	musicWanted = false

	local ent = net.ReadEntity()
	wonply = nil
	if IsValid(ent) then
		ent.won = true
		wonply = ent
	end
	
	roundend = CurTime()

	hook.Remove("Think", "ZoneSoundThink")
	
	if(MODE.SoundStation and MODE.SoundStation:IsValid())then
		MODE.SoundStation:Stop()
		MODE.SoundStation = nil
	end

	-- Fade is handled by HUDPaint for a moment, then stop the Chud Beasts
	-- track so it never leaks into the next gamemode.
	timer.Simple(2, function()
		stopMusic()
	end)
	
    CreateEndMenu()
end)

local colGray = Color(85,85,85,255)
local colRed = Color(217,201,99)
local colRedUp = Color(207,181,59)

local colBlue = Color(10,10,160)
local colBlueUp = Color(40,40,160)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(255,255,255)

local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)

local blurMat = Material("pp/blurscreen")
local Dynamic = 0

BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function()
	-- Remorse's global round summary supplies the MVP and personal stats screen.
	if hg and hg.RoundSummaryEnabled then return end
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end
	Dynamic = 0
	hmcdEndMenu = vgui.Create("ZFrame")

    surface.PlaySound("ambient/alarms/warningbell1.wav")

	local sizeX,sizeY = ScrW() / 2.5 ,ScrH() / 1.2
	local posX,posY = ScrW() / 1.3 - sizeX / 2,ScrH() / 2 - sizeY / 2

	hmcdEndMenu:SetPos(posX,posY)
	hmcdEndMenu:SetSize(sizeX,sizeY)
	--hmcdEndMenu:SetBackgroundColor(colGray)
	hmcdEndMenu:MakePopup()
	hmcdEndMenu:SetKeyboardInputEnabled(false)
	hmcdEndMenu:ShowCloseButton(false)

	local closebutton = vgui.Create("DButton",hmcdEndMenu)
	closebutton:SetPos(5,5)
	closebutton:SetSize(ScrW() / 20,ScrH() / 30)
	closebutton:SetText("")
	
	closebutton.DoClick = function()
		if IsValid(hmcdEndMenu) then
			hmcdEndMenu:Close()
			hmcdEndMenu = nil
		end
	end

	closebutton.Paint = function(self,w,h)
		surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
		surface.SetFont( "ZB_InterfaceMedium" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Close")
		surface.SetTextPos( lengthX - lengthX/1.1, 4)
		surface.DrawText("Close")
	end

    hmcdEndMenu.Paint = function(self,w,h)
		BlurBackground(self)
		local txt = (wonply and wonply:GetPlayerName() or "Nobody").." won!"
		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize(txt)
		surface.SetTextPos(w / 2 - lengthX/2,20)
		surface.DrawText(txt)

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end
	
	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
	function DScrollPanel:Paint( w, h )
		BlurBackground(self)

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	for i,ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		local but = vgui.Create("DButton",DScrollPanel)
		but:SetSize(100,50)
		but:Dock(TOP)
		but:DockMargin( 8, 6, 8, -1 )
		but:SetText("")
		but.Paint = function(self,w,h)
			local col1 = (ply.won and colRed) or (ply:Alive() and colBlue) or colGray
            local col2 = (ply.won and colRedUp) or (ply:Alive() and colBlueUp) or colSpect1
			
			surface.SetDrawColor(col1.r,col1.g,col1.b,col1.a)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(col2.r,col2.g,col2.b,col2.a)
			surface.DrawRect(0,h/2,w,h/2)

            local col = ply:GetPlayerColor():ToColor()
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			
			surface.SetTextColor(0,0,0,255)
			surface.SetTextPos(w / 2 + 1,h/2 - lengthY/2 + 1)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

			surface.SetTextColor(col.r,col.g,col.b,col.a)
			surface.SetTextPos(w / 2,h/2 - lengthY/2)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

            
			local col = colSpect2
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			surface.SetTextPos(15,h/2 - lengthY/2)
			surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")

			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:Frags() or "He quited..." )
			surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
			surface.DrawText(ply:Frags() or "He quited...")
		end

		function but:DoClick()
			if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
			gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
		end

		DScrollPanel:AddItem(but)
	end

	return true
end

function MODE:RoundStart()
    for i,ply in player.Iterator() do
		ply.won = nil
    end

    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end
