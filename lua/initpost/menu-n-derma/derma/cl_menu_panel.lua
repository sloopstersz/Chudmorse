local PANEL = {}
local curent_panel 
local red_select = Color(192,0,0)
local menu_music_default_path = "sound/rem_mainmenu.mp3"
local menu_music_appearance_path = "sound/rem_appearencemenu.mp3"
local menu_music_shop_path = "sound/chudmorse/shop/rem_shop.mp3"
local menu_music_flags = "noblock noplay"
local menu_music_volume = 0.25
local menu_music_fade_speed = 1.8
local menu_music_station
local menu_music_generation = 0
local menu_music_station_path
local menu_music_station_lerp = 0
local menu_music_pending_station
local menu_music_pending_path
local menu_music_pending_lerp = 0
local menu_music_target_path = menu_music_default_path

DISCORD_URL = "https://discord.gg/475EmEdTgH"

local SOUND_MENU_SELECT = "ui/rem_select.wav"
local SOUND_MENU_HOVER = "ui/rem_hover.wav"
local SOUND_TYPEWRITER = "shitty/tap-resonant.wav"
local SOUND_TYPEWRITER_LEVEL = 55
local SOUND_TYPEWRITER_VOLUME = 0.25
local SOUND_TYPEWRITER_PITCH = 102

local function PlayTypewriterSound()
    local ply = LocalPlayer and LocalPlayer()
    if IsValid(ply) then
        ply:EmitSound(SOUND_TYPEWRITER, SOUND_TYPEWRITER_LEVEL, SOUND_TYPEWRITER_PITCH, SOUND_TYPEWRITER_VOLUME)
        return
    end
    surface.PlaySound(SOUND_TYPEWRITER)
end

local function StopMainMenuMusic()
    menu_music_generation = menu_music_generation + 1
    if menu_music_station then
        menu_music_station:Stop()
        menu_music_station = nil
    end
    menu_music_station_path = nil
    menu_music_station_lerp = 0
    if menu_music_pending_station then
        menu_music_pending_station:Stop()
        menu_music_pending_station = nil
    end
    menu_music_pending_path = nil
    menu_music_pending_lerp = 0
    menu_music_target_path = menu_music_default_path
end

cvars.AddChangeCallback("chud_barry_music", function()
    local target = menu_music_target_path
    StopMainMenuMusic()
    menu_music_target_path = target
end, "ChudBarryMenuMusic")

local function QueueMainMenuMusic(owner, path)
    path = path or menu_music_default_path
    menu_music_target_path = path

    if not IsValid(owner) or MainMenu ~= owner then return end
    if menu_music_station and menu_music_station_path == path and not menu_music_pending_station then return end
    if menu_music_pending_station and menu_music_pending_path == path then return end

    local generation = menu_music_generation
    sound.PlayFile(path, menu_music_flags, function(station)
        if not station then return end
        if generation ~= menu_music_generation or not IsValid(owner) or MainMenu ~= owner or menu_music_target_path ~= path then
            station:Stop()
            return
        end

        if menu_music_pending_station and menu_music_pending_station ~= station then
            menu_music_pending_station:Stop()
        end

        menu_music_pending_station = station
        menu_music_pending_path = path
        menu_music_pending_lerp = 0
        station:EnableLooping(true)
        station:SetVolume(0)
        station:Play()
    end)
end

local function UpdateMainMenuMusic(owner)
    if not IsValid(owner) or MainMenu ~= owner then
        StopMainMenuMusic()
        return
    end

    if menu_music_station and menu_music_station_path ~= menu_music_target_path and not menu_music_pending_station then
        QueueMainMenuMusic(owner, menu_music_target_path)
    end

    local fadeStep = FrameTime() * menu_music_fade_speed

    if menu_music_pending_station then
        menu_music_pending_lerp = math.min(1, menu_music_pending_lerp + fadeStep)
        menu_music_pending_station:SetVolume(menu_music_volume * menu_music_pending_lerp)

        if menu_music_station then
            menu_music_station_lerp = math.max(0, menu_music_station_lerp - fadeStep)
            menu_music_station:SetVolume(menu_music_volume * menu_music_station_lerp)

            if menu_music_station_lerp <= 0.001 then
                menu_music_station:Stop()
                menu_music_station = menu_music_pending_station
                menu_music_station_path = menu_music_pending_path
                menu_music_station_lerp = menu_music_pending_lerp
                menu_music_pending_station = nil
                menu_music_pending_path = nil
                menu_music_pending_lerp = 0
            end
        elseif menu_music_pending_lerp >= 0.999 then
            menu_music_station = menu_music_pending_station
            menu_music_station_path = menu_music_pending_path
            menu_music_station_lerp = 1
            menu_music_pending_station = nil
            menu_music_pending_path = nil
            menu_music_pending_lerp = 0
        end
    elseif menu_music_station then
        menu_music_station_lerp = math.min(1, menu_music_station_lerp + fadeStep)
        menu_music_station:SetVolume(menu_music_volume * menu_music_station_lerp)
    elseif menu_music_target_path then
        QueueMainMenuMusic(owner, menu_music_target_path)
    end
end

local function MenuUnit(num)
    return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
end

local function CreateMainMenuFonts()
    surface.CreateFont("ZCity_Menu_Tiny", {
        font = "Verily Serif Mono",
        size = ScreenScale(8),
        weight = 200
    })

    surface.CreateFont("ZCity_Menu_Small", {
        font = "Verily Serif Mono",
        size = ScreenScale(20),
        weight = 200
    })
end

hook.Add("OnScreenSizeChanged", "ZCity_MainMenu_Fonts", CreateMainMenuFonts)
CreateMainMenuFonts()

local Selects = {
    {Title = "Disconnect", BypassTransition = true, Func = function(luaMenu) luaMenu:PlayDisconnectCutscene() end},
    {Title = "Main Menu", Func = function(luaMenu) gui.ActivateGameUI() luaMenu:Close() end},
    {Title = "Loadout",
    GamemodeOnly = true,
    Func = function(luaMenu,pp) 
        if hg.DrawLoadoutMenu then
            hg.DrawLoadoutMenu(pp)
        end
    end},
    {Title = "Achievements", Func = function(luaMenu,pp) 
        hg.DrawAchievmentsMenu(pp)
    end},
    {Title = "Information", Func = function(luaMenu,pp)
        hg.DrawInformation(pp)
    end},
    {Title = "Keybinds", Func = function(luaMenu,pp)
        hg.DrawKeybinds(pp)
    end},
    {Title = "Settings", Func = function(luaMenu,pp) 
        hg.DrawSettings(pp) 
    end},
    {Title = "Appearance", Func = function(luaMenu,pp) hg.CreateApperanceMenu(pp) end},
    {Title = "Return", Func = function(luaMenu) luaMenu:Close() end},
}

local splasheh = {
    'LIKE HOMICIDED',
    'PLUV PLUV PLUVISKI',
    'LULU IS NOT DEAD | !PLUV',
    'THE TRAITOR WAS KILLED',
    'NAB HOMICIDE SERVER',
    'ALSO TRY MODDED HOMICIDE 2',
    'HOP ON Z-CITY',
    'JOHN Z-CITY',
    ':pluvrare:',
    'SAW51 IS REAL',
    'MORE SMALLTOWN',
    'MORE CLUE2022',
    'BACKROOMS == CLUE',
    'HELL IS NEAR',
    'I WISH YOU GOOD HEALTH, JASON STATHAM'
}


surface.CreateFont("ZC_MM_Title", {
    font = "Verily Serif Mono",
    size = ScreenScale(40),
    weight = 800,
    antialias = true
})
-- local Title = markup.Parse("error")

local Pluv = Material("pluv/pluvkid.jpg")
local LogoistMat = Material("vgui/chudmorse_logo.png", "noclamp smooth")

function PANEL:InitializeMarkup()
	local mapname = game.GetMap()
	local prefix = string.find(mapname, "_")
	if prefix then
		mapname = string.sub(mapname, prefix + 1)
	end
	local gm = splasheh[math.random(#splasheh)] .. " | " .. string.NiceName(mapname) 

    if hg.PluvTown.Active then
        local text = "<font=ZC_MM_Title><colour=199,2,2>    </colour>City</font>\n<font=ZCity_Menu_Tiny><colour=105,105,105>" .. gm .. "</colour></font>"

        self.SelectedPluv = table.Random(hg.PluvTown.PluvMats)

        return markup.Parse(text)
    end

    local text = "<font=ZC_MM_Title><colour=199,2,2,255>Z</colour>-City</font>\n<font=ZCity_Menu_Tiny><colour=105,105,105>" .. gm .. "</colour></font>"
    return markup.Parse(text)
end

local color_red = Color(255,25,25,45)
local clr_gray = Color(255,255,255,25)
local clr_verygray = Color(10,10,19,235)
local appearance_preview = {
    width = 340,
    height = 920,
    right = 0,
    top = 210,
    enter_time = 1.35,
    enter_delay = 0.35,
    exit_time = 0.7,
    exit_delay = 0.05,
    ambient = Color(0, 0, 0, 255),
    light_right = Color(115, 115, 115, 255),
    light_left = Color(85, 85, 85, 255),
    light_front = Color(92, 92, 92, 255),
    light_back = Color(0, 0, 0, 255),
    light_top = Color(55, 55, 55, 255),
    light_bottom = Color(0, 0, 0, 255),
    fov = 16,
    cam_pos = Vector(100, 0, 65),
    look_ang = Angle(11, 180, 0),
    entity_ang = Angle(0, 0, 0),
    head_yaw = -45,
    head_pitch = 0,
    head_mouse_yaw = 7,
    head_mouse_pitch = 4,
    sequence = "idle_suitcase"
}
local disconnect_cutscene = {
    ui_fade_time = 0.45,
    walk_delay = 0.08,
    walk_time = 2.5,
    walk_distance = 135,
    walk_sequence = "walk_all",
    walk_playback_rate = 1,
    walk_ang = Angle(0, 90, 0),
    black_fade_time = 0.7,
    disconnect_delay = 0.05
}
local menu_profile = {
    left = 30,
    top = 90,
    min_width = 360,
    height = 160,
    medal_size = 50
}
local menu_title = {
    width = 300,
    offset_x = -11,
    spacing = 55
}
local menu_live = {
    drift_x = 14,
    drift_y = 10,
    shake_x = 1,
    shake_y = 1,
    title_x = 30,
    title_y = 25,
    title_mouse_x = 10,
    title_mouse_y = 7,
    title_float_x = 4,
    title_float_y = 3,
    title_hover_scale = 0.08,
    button_hover_scale = 0.008,
    button_drift_x = 4,
    button_drift_y = 1,
    button_shake_x = 0,
    button_shake_y = 0,
    profile_drift_x = 9,
    profile_drift_y = 6,
    bottom_drift_x = 10,
    bottom_drift_y = 6,
    logo_drift_x = 7,
    logo_drift_y = 4,
    enter_x = 18,
    enter_y = 12
}
local menu_profile_fallback_band = {
    icon = Material("vgui/mats_jack_awards/10")
}
local menu_profile_fallback_medal = {
    icon = Material("vgui/mats_jack_awards/pt")
}
local menu_news = {
    top = 24,
    height = 36,
    speed = 100,
    refresh = 2
}

local function MenuCanStartNet(messageName)
    return util.NetworkStringToID(messageName) ~= 0
end

hg.Leaderboard = hg.Leaderboard or {Rows = {}, NextRequest = 0}

function hg.Leaderboard.Request(limit)
    if not MenuCanStartNet("zb_sql_leaderboard") then return end
    if (hg.Leaderboard.NextRequest or 0) > CurTime() then return end
    hg.Leaderboard.NextRequest = CurTime() + 3

    net.Start("zb_sql_leaderboard")
        net.WriteUInt(math.Clamp(limit or 10, 1, 10), 8)
    net.SendToServer()
end

function hg.Leaderboard.Get(limit)
    hg.Leaderboard.Request(limit)

    local rows = hg.Leaderboard.Rows or {}
    if limit and #rows > limit then
        local trimmed = {}
        for i = 1, limit do
            trimmed[i] = rows[i]
        end
        return trimmed
    end

    return rows
end

function hg.Leaderboard.GetAwards(row)
    if not row or not zb or not zb.Experience or not zb.Experience.GetAwards then return menu_profile_fallback_band, menu_profile_fallback_medal end
    return zb.Experience.GetAwards({skill = row.skill or 0, exp = row.xp or 0})
end

function hg.Leaderboard.GetMedalName(row)
    local _, medal = hg.Leaderboard.GetAwards(row)
    return string.upper((medal and medal.name) or "UNRANKED")
end

if not hg.Leaderboard.NetHooked then
    net.Receive("zb_sql_leaderboard", function()
        local count = net.ReadUInt(8)
        local rows = {}

        for i = 1, count do
            rows[i] = {
                steamid = net.ReadString(),
                name = net.ReadString(),
                skill = net.ReadFloat(),
                xp = net.ReadUInt(32),
                kills = net.ReadUInt(16),
                deaths = net.ReadUInt(16),
                kd = net.ReadFloat()
            }
        end

        hg.Leaderboard.Rows = rows
    end)

    hg.Leaderboard.NetHooked = true
end

local function CleanupPreviewAccessories(ent)
    if not IsValid(ent) or not ent.modelAccess then return end
    for k, v in pairs(ent.modelAccess) do
        if IsValid(v) then
            v:Remove()
        end
        ent.modelAccess[k] = nil
    end
end

function PANEL:GetPreviewAppearance()
    if not hg or not hg.Appearance then return end
    local appearance
    if hg.Appearance.LoadAppearanceFile and hg.Appearance.SelectedAppearance then
        appearance = hg.Appearance.LoadAppearanceFile(hg.Appearance.SelectedAppearance:GetString())
    end
    appearance = appearance or (hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance())
    if not appearance or not hg.Appearance.PlayerModels then return end
    local tMdl = hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
    if not tMdl or not tMdl.mdl then return end
    return table.Copy(appearance), tMdl
end

function PANEL:GetProfileInfo()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return "Unknown", "0 XP", nil
    end

    local username = ply:GetNWString("PlayerName", "")
    if username == "" then
        username = ply:Nick()
    end

    local xp = tostring(math.floor(tonumber(ply.exp) or 0)) .. " XP"
    return username, xp, ply
end

function PANEL:GetLiveMouse()
    local mx, my = gui.MouseX(), gui.MouseY()
    if mx <= 0 and my <= 0 then
        mx = ScrW() * 0.5
        my = ScrH() * 0.5
    end
    local nx = math.Clamp((mx / ScrW() - 0.5) * 2, -1, 1)
    local ny = math.Clamp((my / ScrH() - 0.5) * 2, -1, 1)
    return mx, my, nx, ny
end

function PANEL:GetLiveOffset(xAmount, yAmount)
    local _, _, nx, ny = self:GetLiveMouse()
    return nx * xAmount, ny * yAmount
end

function PANEL:GetLiveShake(seedX, seedY, xAmount, yAmount)
    local t = RealTime()
    return math.sin(t * 1.8 + seedX) * xAmount, math.cos(t * 2.4 + seedY) * yAmount
end

function PANEL:Think()
    UpdateMainMenuMusic(self)
    self:ThinkCoinShop()
    if self.CoinShopMoving or self.CoinShopOpen then return end

    if self.DisconnectBlackStart then
        local blackFrac = math.Clamp((CurTime() - self.DisconnectBlackStart) / math.max(disconnect_cutscene.black_fade_time, 0.001), 0, 1)
        self.DisconnectBlackAlpha = 255 * blackFrac
    end

    if self.DisconnectWalkStart and CurTime() >= self.DisconnectWalkStart then
        local walkFrac = math.Clamp((CurTime() - self.DisconnectWalkStart) / disconnect_cutscene.walk_time, 0, 1)
        if walkFrac < 1 and CurTime() > (self.NextFootstep or 0) then
            self.NextFootstep = CurTime() + 0.38
            local vol = 1 - walkFrac
            if LocalPlayer and IsValid(LocalPlayer()) then
                LocalPlayer():EmitSound("player/footsteps/concrete" .. math.random(1,4) .. ".wav", 0, 100, vol)
            end
        end
    end

    self.LiveLerp = LerpFT(0.08, self.LiveLerp or 0, 1)
    self.LogoHoverLerp = LerpFT(0.12, self.LogoHoverLerp or 0, IsValid(self.logoPanel) and self.logoPanel:IsHovered() and 1 or 0)

    local enter = 1 - (self.LiveLerp or 0)
    local dockMouseX, dockMouseY = self:GetLiveOffset(MenuUnit(menu_live.drift_x), MenuUnit(menu_live.drift_y))
    local dockShakeX, dockShakeY = self:GetLiveShake(0.6, 1.1, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))

    if IsValid(self.lDock) and self.lDockBaseMargins then
        self.lDock:DockMargin(
            math.Round(self.lDockBaseMargins[1] + dockMouseX + dockShakeX - MenuUnit(menu_live.enter_x) * enter),
            math.Round(self.lDockBaseMargins[2] + dockMouseY + dockShakeY + MenuUnit(menu_live.enter_y) * enter),
            self.lDockBaseMargins[3],
            self.lDockBaseMargins[4]
        )
    end

    if IsValid(self.logoPanel) and self.logoBaseMargin then
        local logoMouseX, logoMouseY = self:GetLiveOffset(MenuUnit(menu_live.logo_drift_x), MenuUnit(menu_live.logo_drift_y))
        self.logoPanel:DockMargin(
            math.Round(logoMouseX),
            0,
            0,
            math.Round(self.logoBaseMargin + logoMouseY)
        )
    end

    if IsValid(self.profileInfo) and self.profileBasePos then
        local profileMouseX, profileMouseY = self:GetLiveOffset(MenuUnit(menu_live.profile_drift_x), MenuUnit(menu_live.profile_drift_y))
        local profileShakeX, profileShakeY = self:GetLiveShake(1.7, 2.3, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        self.profileInfo:SetPos(
            math.Round(self.profileBasePos[1] + profileMouseX + profileShakeX - MenuUnit(menu_live.enter_x) * enter),
            math.Round(self.profileBasePos[2] + profileMouseY + profileShakeY + MenuUnit(menu_live.enter_y) * enter)
        )
    end

    if IsValid(self.bottomDock) and self.bottomDockBasePos then
        local bottomMouseX, bottomMouseY = self:GetLiveOffset(MenuUnit(menu_live.bottom_drift_x), MenuUnit(menu_live.bottom_drift_y))
        local bottomShakeX, bottomShakeY = self:GetLiveShake(2.8, 3.1, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        self.bottomDock:SetPos(
            math.Round(self.bottomDockBasePos[1] + bottomMouseX + bottomShakeX - MenuUnit(menu_live.enter_x) * enter),
            math.Round(self.bottomDockBasePos[2] + bottomMouseY + bottomShakeY + MenuUnit(menu_live.enter_y) * enter)
        )
    end
end

function PANEL:CreateProfileInfo()
    local profile = vgui.Create("DPanel", self)
    self.profileInfo = profile
    profile:SetSize(MenuUnit(menu_profile.min_width), MenuUnit(menu_profile.height))
    profile:SetPos(MenuUnit(menu_profile.left), MenuUnit(menu_profile.top))
    self.profileBasePos = {MenuUnit(menu_profile.left), MenuUnit(menu_profile.top)}
    profile:SetMouseInputEnabled(false)
    profile:SetAlpha(0)
    profile.Paint = function() end

    local username = vgui.Create("DLabel", profile)
    username:SetPos(0, 0)
    username:SetFont("ZCity_Menu_Small")
    username:SetTextColor(color_white)
    username:SetContentAlignment(7)
    username:SetExpensiveShadow(1, Color(0, 0, 0, 225))

    local medal = vgui.Create("DPanel", profile)
    medal:SetPos(0, MenuUnit(28))
    medal:SetSize(MenuUnit(menu_profile.medal_size), MenuUnit(menu_profile.medal_size))
    medal.Band = nil
    medal.Medal = nil
    medal.Paint = function(this, w, h)
        if this.Band and this.Band.icon then
            surface.SetMaterial(this.Band.icon)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawTexturedRect(0, 0, w, h)
        end
        if this.Medal and this.Medal.icon then
            surface.SetMaterial(this.Medal.icon)
            surface.SetDrawColor(255,255,255,255)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    local xp = vgui.Create("DLabel", profile)
    xp:SetPos(MenuUnit(30), MenuUnit(31))
    xp:SetFont("ZCity_Menu_Small")
    xp:SetTextColor(Color(175, 175, 175))
    xp:SetContentAlignment(7)
    xp:SetExpensiveShadow(1, Color(0, 0, 0, 225))

    local lastExp = -1
    local lastSkill = -1
    function profile:Think()
        local nameText, xpText, ply = self:GetParent():GetProfileInfo()
        if username:GetText() != nameText then
            username:SetText(nameText)
            username:SizeToContents()
        end
        if xp:GetText() != xpText then
            xp:SetText(xpText)
            xp:SizeToContents()
        end
        if IsValid(ply) and (lastExp != (ply.exp or 0) or lastSkill != (ply.skill or 0) or not medal.Band or not medal.Medal) then
            if ply.GetAwards then
                medal.Band, medal.Medal = ply:GetAwards()
            else
                medal.Band, medal.Medal = menu_profile_fallback_band, menu_profile_fallback_medal
            end
            medal.Band = medal.Band or menu_profile_fallback_band
            medal.Medal = medal.Medal or menu_profile_fallback_medal
            lastExp = ply.exp or 0
            lastSkill = ply.skill or 0
        end
        local medalSize = MenuUnit(menu_profile.medal_size)
        medal:SetSize(medalSize, medalSize)
        medal:SetPos(0, username:GetTall() + MenuUnit(3))
        xp:SetPos(medalSize + MenuUnit(4), username:GetTall() + MenuUnit(5))
        profile:SetWide(math.max(MenuUnit(menu_profile.min_width), username:GetWide() + MenuUnit(8), xp:GetX() + xp:GetWide() + MenuUnit(8)))
    end

    timer.Simple(0, function()
        if not IsValid(profile) then return end
        profile:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
    end)
end

function PANEL:CreateTopPlayersTicker()
    local ticker = vgui.Create("DPanel", self)
    self.topPlayersTicker = ticker
    ticker:SetSize(ScrW(), MenuUnit(menu_news.height))
    ticker:SetPos(0, MenuUnit(menu_news.top))
    ticker:SetMouseInputEnabled(false)
    ticker:SetAlpha(0)
    ticker.Text = "TOP 3 PLAYERS: LOADING"
    ticker.Leaders = {}
    ticker.NextRefresh = 0
    ticker.Paint = function(this, w, h)
        if (this.NextRefresh or 0) <= CurTime() then
            local leaders = hg.Leaderboard.Get(3)
            this.Leaders = leaders
            this.Text = #leaders > 0 and "TOP 3 PLAYERS:" or "TOP 3 PLAYERS: NO SQL LEADERBOARD DATA"
            this.NextRefresh = CurTime() + menu_news.refresh
        end

        surface.SetDrawColor(0, 0, 0, 185)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 70)
        surface.DrawRect(0, h - MenuUnit(1), w, MenuUnit(1))

        surface.SetFont("ZCity_Menu_Tiny")
        local iconSize = MenuUnit(18)
        local gap = MenuUnit(18)
        local textW = surface.GetTextSize(this.Text)
        for i, data in ipairs(this.Leaders or {}) do
            textW = textW + surface.GetTextSize("   #" .. i .. " " .. string.upper(data.name) .. " XP " .. data.xp) + iconSize + gap
        end
        local span = w + textW + MenuUnit(80)
        local x = w - ((RealTime() * menu_news.speed) % span)
        local y = h / 2
        draw.SimpleTextOutlined(this.Text, "ZCity_Menu_Tiny", x, y, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 235))
        x = x + surface.GetTextSize(this.Text)

        for i, data in ipairs(this.Leaders or {}) do
            local label = "   #" .. i .. " " .. string.upper(data.name) .. " XP " .. data.xp
            draw.SimpleTextOutlined(label, "ZCity_Menu_Tiny", x, y, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 235))
            x = x + surface.GetTextSize(label) + MenuUnit(4)

            local _, medal = hg.Leaderboard.GetAwards(data)
            if medal and medal.icon then
                surface.SetMaterial(medal.icon)
                surface.SetDrawColor(255, 255, 255, 235)
                surface.DrawTexturedRect(x, y - iconSize / 2, iconSize, iconSize)
            end

            x = x + iconSize + gap
        end
    end

    timer.Simple(0, function()
        if IsValid(ticker) then
            ticker:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
        end
    end)
end

function PANEL:CreateAppearancePreview()
    local tbl, tMdl = self:GetPreviewAppearance()
    if not tbl or not tMdl then return end

    if hg.Appearance and hg.Appearance.PrecacheModels then
        hg.Appearance.PrecacheModels()
    end

    local holderW = MenuUnit(appearance_preview.width)
    local holderH = MenuUnit(appearance_preview.height)
    local targetX = ScrW() - holderW - MenuUnit(appearance_preview.right)
    local targetY = MenuUnit(appearance_preview.top)

    self.previewHolder = vgui.Create("DPanel", self)
    local holder = self.previewHolder
    holder:SetSize(holderW, holderH)
    holder:SetPos(targetX, ScrH())
    holder:SetAlpha(0)
    holder.TargetX = targetX
    holder.TargetY = targetY
    holder.ClosedY = ScrH()
    holder:SetMouseInputEnabled(false)
    holder.Paint = function() end
    holder.Think = function(this)
        if not this.AppearanceFollow then return end
        local x, y = this:GetPos()
        local targetPosX = this.TargetX or x
        local targetPosY = this.TargetY or y
        local nextX = LerpFT(0.18, x, targetPosX)
        local nextY = LerpFT(0.18, y, targetPosY)
        if math.abs(targetPosX - nextX) < 1 then
            nextX = targetPosX
        end
        if math.abs(targetPosY - nextY) < 1 then
            nextY = targetPosY
        end
        this:SetPos(math.Round(nextX), math.Round(nextY))
    end

    local preview = vgui.Create("DModelPanel", holder)
    self.previewModel = preview
    preview.OwnerMenu = self
    preview:Dock(FILL)
    preview:SetModel(util.IsValidModel(tostring(tMdl.mdl)) and tostring(tMdl.mdl) or "models/player/group01/female_01.mdl")
    preview:SetFOV(appearance_preview.fov)
    preview:SetLookAng(appearance_preview.look_ang)
    preview:SetCamPos(appearance_preview.cam_pos)
    preview:SetAmbientLight(appearance_preview.ambient)
    preview:SetDirectionalLight(BOX_RIGHT, appearance_preview.light_right)
    preview:SetDirectionalLight(BOX_LEFT, appearance_preview.light_left)
    preview:SetDirectionalLight(BOX_FRONT, appearance_preview.light_front)
    preview:SetDirectionalLight(BOX_BACK, appearance_preview.light_back)
    preview:SetDirectionalLight(BOX_TOP, appearance_preview.light_top)
    preview:SetDirectionalLight(BOX_BOTTOM, appearance_preview.light_bottom)
    preview:SetMouseInputEnabled(false)
    preview.AppearanceTable = tbl

    local oldPaint = preview.Paint
    preview.Paint = function(pnl, w, h)
        DisableClipping(true)
        oldPaint(pnl, w, h)
        DisableClipping(false)
    end

    function preview:LayoutEntity(ent)
        local appearance = self.AppearanceTable
        if not appearance or not hg or not hg.Appearance or not hg.Appearance.PlayerModels then return end

        local modelData = hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
        if not modelData or not modelData.mdl then return end

        local colorData = appearance.AColor or color_white
        ent:SetNWVector("PlayerColor", Vector((colorData.r or 255) / 255, (colorData.g or 255) / 255, (colorData.b or 255) / 255))

        local targetPos = Vector(0, 0, 0)
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene then
            if self.OwnerMenu.DisconnectWalkStart and CurTime() >= self.OwnerMenu.DisconnectWalkStart then
                local walkFrac = math.Clamp((CurTime() - self.OwnerMenu.DisconnectWalkStart) / disconnect_cutscene.walk_time, 0, 1)
                targetPos = Vector(0, walkFrac * disconnect_cutscene.walk_distance, 0)
            end
        end
        ent:SetPos(targetPos)

        local targetEntityAngle = self.EntityAngleOverride or appearance_preview.entity_ang
        self.EntityAngle = LerpAngle(RealFrameTime() * 6, self.EntityAngle or targetEntityAngle, targetEntityAngle)
        ent:SetAngles(self.EntityAngle)

        local sequenceName = self.SequenceNameOverride or appearance_preview.sequence
        local seq = ent:LookupSequence(sequenceName)
        
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene and (not seq or seq < 0) then
            local fallbacks = {"walk_suitcase", "walk_all", "walk", "walk_all_suitcase"}
            for _, v in ipairs(fallbacks) do
                seq = ent:LookupSequence(v)
                if seq and seq >= 0 then
                    sequenceName = v
                    break
                end
            end
        end

        if (not seq or seq < 0) and sequenceName != appearance_preview.sequence then
            sequenceName = appearance_preview.sequence
            seq = ent:LookupSequence(sequenceName)
        end
        if seq and seq >= 0 then
            if self.ActiveSequenceName != sequenceName then
                ent:ResetSequence(seq)
                self.ActiveSequenceName = sequenceName
            end
            ent:SetPlaybackRate(self.SequencePlaybackRate or 1)
            ent:FrameAdvance(RealFrameTime() * (self.SequencePlaybackRate or 1))
        end

        local owner = self.OwnerMenu
        local nx, ny = 0, 0
        if IsValid(owner) and owner.GetLiveMouse then
            local _, _, newNX, newNY = owner:GetLiveMouse()
            nx, ny = newNX, newNY
        end
        local targetYaw = appearance_preview.head_yaw - nx * appearance_preview.head_mouse_yaw
        local targetPitch = appearance_preview.head_pitch - ny * appearance_preview.head_mouse_pitch
        self.HeadYawLerp = LerpFT(0.08, self.HeadYawLerp or appearance_preview.head_yaw, targetYaw)
        self.HeadPitchLerp = LerpFT(0.08, self.HeadPitchLerp or appearance_preview.head_pitch, targetPitch)
        ent:SetPoseParameter("head_yaw", self.HeadYawLerp)
        ent:SetPoseParameter("head_pitch", self.HeadPitchLerp)
        
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene then
            ent:SetPoseParameter("move_x", 1)
            ent:SetPoseParameter("move_y", 0)
        end
        
        ent:SetSubMaterial()
        self:SetCamPos(self.CamPosOverride or appearance_preview.cam_pos)
        self:SetFOV(self.FOVOverride or appearance_preview.fov)
        self:SetLookAng(self.LookAngOverride or appearance_preview.look_ang)

        if ent:GetModel() != modelData.mdl then
            CleanupPreviewAccessories(ent)
            ent:SetModel(modelData.mdl)
            self:SetModel(modelData.mdl)
            self.ActiveSequenceName = nil
        end

        local clothes = appearance.AClothes or {}
        local mats = ent:GetMaterials()
        for k, v in SortedPairs(modelData.submatSlots or {}) do
            if k ~= "main" and k ~= "pants" and k ~= "boots" then continue end
            local slot
            for i = 1, #mats do
                if mats[i] == v then
                    slot = i - 1
                    break
                end
            end
            if slot == nil then continue end
            local sexID = modelData.sex and 2 or 1
            local clothMat = hg.Appearance.Clothes[sexID] and hg.Appearance.Clothes[sexID][clothes[k]]
            ent:SetSubMaterial(slot, clothMat or (hg.Appearance.Clothes[sexID] and hg.Appearance.Clothes[sexID].normal) or nil)
        end

        local facemapSlot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelData.mdl]
        for i = 1, #mats do
            if facemapSlot and hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][appearance.AFacemap] then
                ent:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][appearance.AFacemap])
            end
        end

        appearance.ABodygroups = appearance.ABodygroups or {}
        for k, v in SortedPairs(ent:GetBodyGroups()) do
            if not appearance.ABodygroups[v.name] then continue end
            local bodygroupData = hg.Appearance.Bodygroups[v.name]
            local bodygroupSet = bodygroupData and bodygroupData[modelData.sex and 2 or 1] and bodygroupData[modelData.sex and 2 or 1][appearance.ABodygroups[v.name]]
            if not bodygroupSet then continue end
            for i = 0, #v.submodels do
                if bodygroupSet[1] == v.submodels[i] then
                    ent:SetBodygroup(k - 1, i)
                    break
                end
            end
        end
    end

    function preview:PostDrawModel(ent)
        local appearance = self.AppearanceTable
        if not appearance or not appearance.AAttachments then return end
        for _, attach in ipairs(appearance.AAttachments) do
            local accessoryData = hg.Accessories and hg.Accessories[attach]
            if accessoryData then
                DrawAccesories(ent, ent, attach, accessoryData, false, true)
            end
        end
        ent:SetupBones()
    end

    function preview:OnRemove()
        if IsValid(self.Entity) then
            CleanupPreviewAccessories(self.Entity)
        end
    end

    timer.Simple(0, function()
        if not IsValid(holder) then return end
        holder:MoveTo(targetX, targetY, appearance_preview.enter_time, 0, appearance_preview.enter_delay)
        holder:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
    end)
end

function PANEL:Init()
    self:SetAlpha(0)
    self:SetSize(ScrW(), ScrH())
    self:Center()
    self:SetTitle("")
    self:SetDraggable(false)
    self:SetBorder(false)
    self:SetColorBG(clr_verygray)
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    curent_panel = nil
    self.Title, self.TitleShadow = self:InitializeMarkup()
    self.LiveLerp = 0
    self.LogoHoverLerp = 0
    self.DisconnectCutscene = false
    self.DisconnectBackgroundAlpha = 255
    self.DisconnectBlackAlpha = 0
    self:UseDefaultMenuMusic()

    timer.Simple(0, function()
        if self.First then
            self:First()
        end
    end)

    self.lDock = vgui.Create("DPanel", self)
    local lDock = self.lDock
    lDock:Dock(LEFT)
    lDock:SetSize(ScrW() / 3, ScrH())
    lDock:DockMargin(0, MenuUnit(90), MenuUnit(10), MenuUnit(90))
    self.lDockBaseMargins = {0, MenuUnit(90), MenuUnit(10), MenuUnit(90)}
    lDock.Paint = function(this, w, h)
        if hg.PluvTown.Active then
            surface.SetDrawColor(color_white)
            surface.SetMaterial(self.SelectedPluv or Pluv)
            surface.DrawTexturedRect(0, MenuUnit(27), MenuUnit(35), MenuUnit(27))
        end
    end

    self:CreateAppearancePreview()
    self:CreateProfileInfo()
    self:CreateTopPlayersTicker()
    self:CreateCoinShopArrow()

    self.Buttons = {}
    for k, v in ipairs(Selects) do
        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end
        self:AddSelect(lDock, v.Title, v)
    end

    local logoPanel = vgui.Create("DPanel", lDock)
    local logoAspect = math.max(1, LogoistMat:Height()) / math.max(1, LogoistMat:Width())
    if LogoistMat:IsError() then
        print("[Chudmorse] WARNING: materials/vgui/chudmorse_logo.png failed to load. Make sure that file exists at exactly that path (case-sensitive) inside your addon, then fully rejoin/restart the game.")
    end
    self.logoPanel = logoPanel
    logoPanel:Dock(BOTTOM)
    logoPanel:SetTall(1)
    logoPanel:SetMouseInputEnabled(false) -- purely decorative now; must stay off or it can steal clicks from the button list below it
    logoPanel:DockMargin(0, 0, 0, MenuUnit(menu_title.spacing))
    self.logoBaseMargin = MenuUnit(menu_title.spacing)
    local LOGO_EXTRA_DROP = MenuUnit(75) -- centers the logo between the profile header and the button list; raise/lower to taste

    logoPanel.Think = function(this)
        local maxW = math.max(1, this:GetWide() - MenuUnit(12))
        local drawW = math.min(MenuUnit(menu_title.width), maxW)
        local drawH = drawW * logoAspect
        this:SetTall(math.ceil(drawH * (1 + menu_live.title_hover_scale) + MenuUnit(8)))
        local x, y = this:GetPos()
        this:SetPos(x, y + LOGO_EXTRA_DROP)
    end
    logoPanel.Paint = function(this, w, h)
        local driftX, driftY = self:GetLiveOffset(MenuUnit(menu_live.logo_drift_x), MenuUnit(menu_live.logo_drift_y))
        local shakeX, shakeY = self:GetLiveShake(6.4, 7.2, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        local scale = 1 + (self.LogoHoverLerp or 0) * menu_live.title_hover_scale
        local maxW = math.max(1, w - MenuUnit(12))
        local baseW = math.min(MenuUnit(menu_title.width), maxW)
        local baseH = baseW * logoAspect
        local drawW = baseW * scale
        local drawH = baseH * scale
        local maxX = math.max(0, w - drawW)
        local maxY = math.max(0, h - drawH)
        local drawX = math.Clamp(MenuUnit(menu_title.offset_x) + driftX + shakeX, 0, maxX)
        local drawY = math.Clamp((h - drawH) * 0.5 + driftY + shakeY, 0, maxY)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(LogoistMat)
        surface.DrawTexturedRect(drawX, drawY, drawW, drawH)
    end


    local bottomDock = vgui.Create("DPanel", self)
    self.bottomDock = bottomDock
    bottomDock:SetPos(ScreenScale(1), ScrH() - ScrH()/10)
    bottomDock:SetSize(ScreenScale(190), ScreenScaleH(40))
    self.bottomDockBasePos = {ScreenScale(1), ScrH() - ScrH()/10}
    bottomDock.Paint = function(this, w, h) end
    self.panelparrent = vgui.Create("DPanel", self)
    self.panelparrent:SetPos(0, 0)
    self.panelparrent:SetSize(ScrW(), ScrH())
    self.panelparrent:MoveToBack()
    self.panelparrent.Paint = function(this, w, h) end
    
    local git = vgui.Create("DLabel", bottomDock)
    git:Dock(BOTTOM)
    git:DockMargin(ScreenScale(10), 0, 0, 0)
    git:SetFont("ZCity_Menu_Tiny")
    git:SetTextColor(clr_gray)
    git:SetText("GitHub: github.com/" .. hg.GitHub_ReposOwner .. "/" .. hg.GitHub_ReposName)
    git:SetContentAlignment(4)
    git:SetMouseInputEnabled(true)
    git:SizeToContents()

    function git:DoClick()
        gui.OpenURL("https://github.com/" .. hg.GitHub_ReposOwner .. "/" .. hg.GitHub_ReposName)
    end

    local CHUDMORSE_DISCORD_URL = "https://discord.gg/GqBvFKHEYA"
    local clr_discord = Color(88, 101, 242)
    local clr_discord_hover = Color(150, 158, 255)

    local discord = vgui.Create("DLabel", bottomDock)
    discord:Dock(BOTTOM)
    discord:DockMargin(ScreenScale(10), 0, 0, 0)
    discord:SetFont("ZCity_Menu_Tiny")
    discord:SetTextColor(clr_discord)
    discord:SetText("Chudmorse Discord: discord.gg/GqBvFKHEYA")
    discord:SetContentAlignment(4)
    discord:SetMouseInputEnabled(true)
    discord:SetCursor("hand")
    discord:SizeToContents()

    function discord:DoClick()
        gui.OpenURL(CHUDMORSE_DISCORD_URL)
    end

    function discord:OnCursorEntered()
        self:SetTextColor(clr_discord_hover)
    end

    function discord:OnCursorExited()
        self:SetTextColor(clr_discord)
    end

    local version = vgui.Create("DLabel", bottomDock)
    version:Dock(BOTTOM)
    version:DockMargin(ScreenScale(10), 0, 0, 0)
    version:SetFont("ZCity_Menu_Tiny")
    version:SetTextColor(clr_gray)
    version:SetText(hg.Version)
    version:SetContentAlignment(4)
    version:SizeToContents()

    local zteam = vgui.Create("DLabel", bottomDock)
    zteam:Dock(BOTTOM)
    zteam:DockMargin(ScreenScale(10), 0, 0, 0)
    zteam:SetFont("ZCity_Menu_Tiny")
    zteam:SetTextColor(clr_gray)
    zteam:SetText("EARLY-ACCESS")
    zteam:SetContentAlignment(4)
    zteam:SizeToContents()
end

function PANEL:First( ply )
    self:AlphaTo( 255, 0.1, 0, nil )
end

local gradient_d = surface.GetTextureID("vgui/gradient-d")
local gradient_r = surface.GetTextureID("vgui/gradient-r")
local gradient_l = surface.GetTextureID("vgui/gradient-l")
local menu_gradient_right = Color(18,18,18,65)

local clr_1 = Color(100,100,100,35)
function PANEL:Paint(w,h)
    local backgroundAlpha = math.Clamp(self.DisconnectBackgroundAlpha or 255, 0, 255)
    if backgroundAlpha > 0 then
        local bgMul = backgroundAlpha / 255
        draw.RoundedBox(0, 0, 0, w, h, Color(self.ColorBG.r, self.ColorBG.g, self.ColorBG.b, (self.ColorBG.a or 255) * bgMul))
        hg.DrawBlur(self, 5)
        surface.SetDrawColor(menu_gradient_right.r, menu_gradient_right.g, menu_gradient_right.b, menu_gradient_right.a * bgMul)
        surface.SetTexture(gradient_r)
        surface.DrawTexturedRect(0,0,w,h)
        surface.SetDrawColor(self.ColorBG.r, self.ColorBG.g, self.ColorBG.b, (self.ColorBG.a or 255) * bgMul)
        surface.SetTexture(gradient_l)
        surface.DrawTexturedRect(0,0,w,h)
        surface.SetDrawColor(clr_1.r, clr_1.g, clr_1.b, clr_1.a * bgMul)
        surface.SetTexture(gradient_d)
        surface.DrawTexturedRect(0,0,w,h)
    end
    if (self.DisconnectBlackAlpha or 0) > 0 then
        surface.SetDrawColor(0, 0, 0, self.DisconnectBlackAlpha)
        surface.DrawRect(0, 0, w, h)
    end
end

function PANEL:PlayDisconnectCutscene()
    if self.DisconnectCutscene or self.CoinShopOpen or self.CoinShopMoving then return end
    self.DisconnectCutscene = true
    self.DisconnectFadeStart = CurTime()
    self.DisconnectBackgroundAlpha = 255
    self.DisconnectBlackAlpha = 0
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)

    StopMainMenuMusic()

    if IsValid(self.previewHolder) then
        self.previewHolder:SetVisible(true)
        self.previewHolder:SetAlpha(255)
    end

    if IsValid(self.previewModel) then
        self.previewModel.SequenceNameOverride = disconnect_cutscene.walk_sequence
        self.previewModel.SequencePlaybackRate = disconnect_cutscene.walk_playback_rate
        self.previewModel.EntityAngleOverride = disconnect_cutscene.walk_ang
        self.previewModel.ActiveSequenceName = nil
    end

    for _, child in ipairs(self:GetChildren()) do
        if child != self.previewHolder then
            child:AlphaTo(0, disconnect_cutscene.ui_fade_time, 0, function()
                if IsValid(child) then
                    child:SetVisible(false)
                end
            end)
        end
    end

    local function startBlackFade()
        if not IsValid(self) then return end
        self.DisconnectBlackStart = CurTime()
        self.DisconnectBlackAlpha = 0
        timer.Simple(disconnect_cutscene.black_fade_time + disconnect_cutscene.disconnect_delay, function()
            if IsValid(self) then
                RunConsoleCommand("disconnect")
            end
        end)
    end

    self.DisconnectWalkStart = CurTime() + disconnect_cutscene.ui_fade_time + disconnect_cutscene.walk_delay

    timer.Simple(disconnect_cutscene.ui_fade_time + disconnect_cutscene.walk_delay + disconnect_cutscene.walk_time, function()
        if IsValid(self) then
            startBlackFade()
        end
    end)
end

-- Keep the supplied art intact; UVs select only the coin, not the example zero.
surface.CreateFont("ChudCoinShopTitle", {font = "Verily Serif Mono", size = MenuUnit(52), weight = 500, antialias = true})
local coinSource = Material("chudmorse/shop/coin_source.png", "smooth")
local coinTexture = coinSource:GetTexture("$basetexture")
-- The white artwork adds light; black contributes nothing, so no black box is drawn.
local coinIcon = coinTexture and CreateMaterial("ChudCoinShopWhiteIcon", "UnlitGeneric", {
    ["$basetexture"] = coinTexture:GetName(),
    ["$additive"] = "1", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1",
    ["$nolod"] = "1"
}) or coinSource

local function CoinShopReveal(panel, text, key)
    local count = math.Clamp(math.floor((CurTime() - (panel.CoinRevealStart or CurTime())) * 15), 0, #text)
    panel.CoinRevealCounts = panel.CoinRevealCounts or {}
    if count > (panel.CoinRevealCounts[key] or 0) then PlayTypewriterSound() end
    panel.CoinRevealCounts[key] = count
    return text:sub(1, count) .. string.rep("#", #text - count)
end

local function StyleCoinShopButton(button, label, arrow)
    button.CoinRevealStart = CurTime()
    button.CoinRevealCounts = {}
    button.HoverLerp = 0
    button.LineLerp = 0
    button.Think = function(btn)
        local hovered = btn:IsHovered()
        if hovered and not btn.WasHovered then surface.PlaySound(SOUND_MENU_HOVER) end
        btn.WasHovered = hovered
        btn.HoverLerp = LerpFT(0.2, btn.HoverLerp or 0, hovered and 1 or 0)
        btn.LineLerp = LerpFT(0.2, btn.LineLerp or 0, hovered and 1 or 0)
    end
    button.Paint = function(btn, w, h)
        local tint, outline = Color(225, 225, 225), Color(0, 0, 0)
        if btn:IsHovered() then
            local v = (0.5 + 0.5 * math.sin(CurTime() * 10)) * 255
            tint, outline = Color(v, v, v), Color(255 - v, 255 - v, 255 - v)
        end
        local matrix = Matrix()
        local scale = 1 + (btn.HoverLerp or 0) * menu_live.button_hover_scale
        matrix:Translate(Vector(w * (1 - scale) * 0.5, h * (1 - scale) * 0.5, 0))
        matrix:Scale(Vector(scale, scale, 1))
        cam.PushModelMatrix(matrix)
        if arrow then
            draw.SimpleTextOutlined(CoinShopReveal(btn, arrow, "arrow"), "ChudCoinShopTitle", w * 0.5, h * 0.35, tint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outline)
        end
        local font = arrow and "ZCity_Menu_Tiny" or "ZCity_Menu_Small"
        local text = CoinShopReveal(btn, label, "label")
        local x, y = arrow and w * 0.5 or MenuUnit(8), arrow and h * 0.8 or h * 0.5
        draw.SimpleTextOutlined(text, font, x, y, tint, arrow and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, outline)
        surface.SetFont(font)
        local tw, th = surface.GetTextSize(text)
        surface.SetDrawColor(255, 255, 255, 255 * (btn.LineLerp or 0))
        surface.DrawRect(arrow and (w - tw) * 0.5 or MenuUnit(8), y + th * 0.5, tw * (btn.LineLerp or 0), math.max(1, MenuUnit(1)))
        cam.PopModelMatrix()
        return true
    end
end

function PANEL:CreateCoinShopArrow()
    local wallet = vgui.Create("DPanel", self)
    self.CoinWallet = wallet
    wallet:SetMouseInputEnabled(false)
    wallet:SetSize(MenuUnit(340), MenuUnit(64))
    wallet:SetVisible(false)
    wallet.Think = function(this)
        local page = IsValid(self.CoinCategoryPage) and self.CoinCategoryPage or self.CoinShopPage
        if not IsValid(page) then return end
        if IsValid(self.CoinCategoryPage) then
            local mx,my = self:GetLiveOffset(MenuUnit(menu_live.profile_drift_x),MenuUnit(menu_live.profile_drift_y))
            this:SetPos(ScrW()-this:GetWide()-MenuUnit(24)+mx,MenuUnit(menu_news.top+menu_news.height+10)+my)
            return
        end
        this:SetPos(
            math.Round(page:GetX() + page:GetWide() - this:GetWide()),
            math.Round(page:GetY() - this:GetTall() - MenuUnit(16))
        )
    end
    wallet.Paint = function(_, w, h)
        local ply = LocalPlayer()
        local coins = IsValid(ply) and ply:GetNWInt("ChudCoin", 0) or 0
        local text = string.Comma(coins)
        surface.SetFont("ZCity_Menu_Small")
        local textW = surface.GetTextSize(text)
        surface.SetFont("ZCity_Menu_Tiny")
        local labelW = surface.GetTextSize("COIN")
        local gap = MenuUnit(10)
        -- Icon, amount, then the COIN label beside it, right-aligned so nothing overlaps.
        local x = w - (h + gap + textW + gap + labelW)
        surface.SetMaterial(coinIcon)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawTexturedRectUV(x, 0, h, h, 0, 0, 108 / 184, 108 / 111)
        draw.SimpleText(text, "ZCity_Menu_Small", x + h + gap, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("COIN", "ZCity_Menu_Tiny", x + h + gap + textW + gap, h * 0.5, Color(160, 160, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local arrow = vgui.Create("DButton", self)
    self.CoinShopArrow = arrow
    arrow:SetSize(MenuUnit(90), MenuUnit(110))
    local arrowX = ScrW() - arrow:GetWide() - MenuUnit(16)
    local arrowY = ScrH() * 0.5 - arrow:GetTall() * 0.5
    arrow:SetPos(arrowX, arrowY)
    arrow:SetAlpha(255)
    arrow:SetMouseInputEnabled(true)
    arrow:SetText("")
    StyleCoinShopButton(arrow, "SHOP", ">")
    local hoverThink = arrow.Think
    arrow.Think = function(button)
        hoverThink(button)
        if self.CoinShopMoving or self.CoinShopOpen or self.DisconnectCutscene then return end
        local mx, my = self:GetLiveOffset(MenuUnit(menu_live.button_drift_x), MenuUnit(menu_live.button_drift_y))
        local sx, sy = self:GetLiveShake(0.91, 1.27, MenuUnit(menu_live.button_shake_x), MenuUnit(menu_live.button_shake_y))
        button:SetPos(math.Round(arrowX + mx * 0.3 + sx + button.HoverLerp * MenuUnit(2)), math.Round(arrowY + my * 0.1 + sy))
    end
    arrow.DoClick = function() self:TravelToCoinShop(true) end
end

-- Supplied artwork stays unchanged on disk. The cached render material inverts
-- black ink to white; additive blending makes the white source background disappear.
local shopArt = {
    pistol = {path="pistol_clean", aspect=235/160, white=true},
    rifle = {path="pistol_clean", aspect=235/160, white=true},
    knife = {path="knife_straight_clean", aspect=213/46, white=true},
    diagonal = {path="knife_diagonal", aspect=478/182, uv={74/626,220/626,552/626,402/626}},
    hat = {path="hat", aspect=254/161, uv={153/560,200/560,407/560,361/560}},
    beanie = {path="beanie", aspect=900/700, uv={440/1797,175/980,1340/1797,875/980}}
}
local function ShopSilhouette(kind, x, y, w, h, tint)
    local art = shopArt[kind]
    if not art then return end
    if not art.material then
        local source = Material("chudmorse/shop/" .. art.path .. ".png", "smooth")
        if source:IsError() then return end
        if art.white then
            -- These replacement images already contain white artwork on black.
            local texture = source:GetTexture("$basetexture")
            if not texture then return end
            art.material = CreateMaterial("ChudShopWhite_" .. art.path, "UnlitGeneric", {
                ["$basetexture"]=texture:GetName(), ["$additive"]="1",
                ["$vertexalpha"]="1", ["$vertexcolor"]="1"
            })
        else
        local target = GetRenderTarget("ChudShopInk_" .. art.path, 512, 512)
        render.PushRenderTarget(target)
        render.Clear(255,255,255,0,true,true)
        cam.Start2D()
        -- RGB = destination * (1 - source); alpha = source alpha.
        render.OverrideBlend(true, BLEND_ZERO, BLEND_ONE_MINUS_SRC_COLOR, BLENDFUNC_ADD, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD)
        surface.SetDrawColor(255,255,255,255)
        surface.SetMaterial(source)
        local uv = art.uv or {0,0,1,1}
        surface.DrawTexturedRectUV(0,0,512,512,uv[1],uv[2],uv[3],uv[4])
        render.OverrideBlend(false)
        cam.End2D()
        render.PopRenderTarget()
        art.material = CreateMaterial("ChudShopInkMat_" .. art.path,"UnlitGeneric", {
            ["$basetexture"]=target:GetName(), ["$additive"]="1",
            ["$vertexalpha"]="1", ["$vertexcolor"]="1", ["$translucent"]="1"
        })
        end
    end
    local dw = math.min(w, h * art.aspect)
    local dh = dw / art.aspect
    surface.SetMaterial(art.material)
    surface.SetDrawColor(tint)
    surface.DrawTexturedRect(x+(w-dw)*0.5,y+(h-dh)*0.5,dw,dh)
end

-- COIN store item page: item list on the left, a spotlit showcase on the right.
-- Each item's accent colour (sh_chud_skins.lua) runs through its card and showcase.
-- Soft round spotlight. Additive, so it only ever brightens the dark backdrop.
local shopGlow = CreateMaterial("ChudShopSpotGlow", "UnlitGeneric", {
    ["$basetexture"] = "sprites/glow04", ["$additive"] = "1", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1",
})
local shopFadeUp = surface.GetTextureID("vgui/gradient-d")
-- Used to hide arm/hand meshes on first-person models in the preview.
local shopHidden = CreateMaterial("ChudShopHiddenMesh", "UnlitGeneric", {["$basetexture"] = "color/white", ["$nodraw"] = "1", ["$alpha"] = "0"})
local shopFadeRight = surface.GetTextureID("vgui/gradient-r")
local SHOP_NEUTRAL = Color(225,225,225)
local SHOP_MUTED = Color(150,150,160)
local SHOP_DIM = Color(95,95,105)

local function ShopAccent(item)
    return item and item.accent or SHOP_NEUTRAL
end

local function ShopFont(name,size,weight)
    local scale = math.min(ScrW(),ScrH()) / 1000
    surface.CreateFont(name,{font="Verily Serif Mono",size=math.max(12,math.floor(size*scale)),weight=weight or 300,antialias=true})
end

-- Four corner ticks around a box.
local function ShopBrackets(x,y,w,h,len,thick,col)
    surface.SetDrawColor(col)
    surface.DrawRect(x,y,len,thick)               surface.DrawRect(x,y,thick,len)
    surface.DrawRect(x+w-len,y,len,thick)         surface.DrawRect(x+w-thick,y,thick,len)
    surface.DrawRect(x,y+h-thick,len,thick)       surface.DrawRect(x,y+h-len,thick,len)
    surface.DrawRect(x+w-len,y+h-thick,len,thick) surface.DrawRect(x+w-thick,y+h-len,thick,len)
end

-- Small rounded tag, returns its width so tags can be laid out in a row.
local function ShopTag(text,font,x,y,fg,bg,alignRight)
    surface.SetFont(font)
    local tw,th = surface.GetTextSize(text)
    local padX,padY = MenuUnit(8),MenuUnit(3)
    local w,h = tw+padX*2,th+padY*2
    if alignRight then x = x-w end
    draw.RoundedBox(MenuUnit(3),x,y,w,h,bg)
    draw.SimpleText(text,font,x+padX,y+padY,fg)
    return w,h
end

local function ShopCoinPrice(price,font,x,y,col,alignRight)
    local text = string.Comma(price)
    surface.SetFont(font)
    local tw,th = surface.GetTextSize(text)
    local icon = th*1.05
    local gap = MenuUnit(6)
    if alignRight then x = x-(icon+gap+tw) end
    surface.SetMaterial(coinIcon)
    surface.SetDrawColor(255,255,255)
    surface.DrawTexturedRectUV(x,y+(th-icon)*0.5,icon,icon,0,0,108/184,108/111)
    draw.SimpleText(text,font,x+icon+gap,y,col)
end

function PANEL:OpenCoinCategory(category)
    if self.CoinShopMoving or IsValid(self.CoinCategoryPage) then return end
    local detail = vgui.Create("DPanel", self)
    self.CoinCategoryPage = detail
    detail:SetSize(ScrW(), ScrH())
    detail:SetPos(0, 0)
    detail.CoinRevealStart = CurTime()
    detail:SetAlpha(0)
    detail:AlphaTo(255, 0.15, 0)
    self.CoinShopPage:SetVisible(false)
    if IsValid(self.previewHolder) then self.previewHolder:SetVisible(false) end
    local title = category == "MELEE SKINS" and "KNIVES" or category
    ShopFont("ChudShopPageTitle",34) ShopFont("ChudShopPageMedium",26) ShopFont("ChudShopPageSmall",20) ShopFont("ChudShopPageTiny",16)
    ShopFont("ChudShopHero",64,400) ShopFont("ChudShopHeroSub",24) ShopFont("ChudShopKicker",15,500) ShopFont("ChudShopCardName",24,400)

    -- Real shop items (sh_chud_skins.lua). Bought skins leave the shop and live in INVENTORY.
    local isInventory = category == "INVENTORY"
    local selected
    local function ItemList()
        if not ChudSkins then return {} end
        local list = {}
        if isInventory then
            for _,item in pairs(ChudSkins.Items) do
                if ChudSkins.Owns(item.id) then list[#list+1] = item end
            end
            table.SortByMember(list,"order",true)
        else
            for _,item in ipairs(ChudSkins.ItemsInCategory(category)) do
                if not ChudSkins.Owns(item.id) then list[#list+1] = item end
            end
        end
        return list
    end
    local itemCount = 0

    local left = vgui.Create("DPanel",detail)
    local right = vgui.Create("DPanel",detail)
    local headerH = MenuUnit(56)
    left.Paint = function(pnl,w,h)
        surface.SetDrawColor(12,12,18,200)
        surface.DrawRect(0,0,w,h)
        draw.SimpleText(isInventory and "OWNED" or "FOR SALE","ChudShopKicker",MenuUnit(16),MenuUnit(12),SHOP_MUTED)
        draw.SimpleText(itemCount .. (itemCount == 1 and " ITEM" or " ITEMS"),"ChudShopKicker",w-MenuUnit(16),MenuUnit(12),SHOP_DIM,TEXT_ALIGN_RIGHT)
        surface.SetDrawColor(255,255,255,30)
        surface.DrawRect(MenuUnit(16),headerH-1,w-MenuUnit(32),1)
    end

    local list = vgui.Create("DScrollPanel",left)
    local bar = list:GetVBar()
    bar:SetWide(MenuUnit(4))
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(_,w,h) draw.RoundedBox(2,0,0,w,h,Color(255,255,255,40)) end
    list.Paint = function(pnl,w,h)
        if #list:GetCanvas():GetChildren() > 0 then return end
        draw.SimpleText(isInventory and "NOTHING HERE YET" or (ChudSkins and #ChudSkins.ItemsInCategory(category) > 0 and "YOU OWN EVERYTHING HERE" or "COMING SOON"),
            "ChudShopPageSmall",w*0.5,h*0.4,SHOP_MUTED,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText(isInventory and "Skins you buy show up here." or "Check back later for new drops.",
            "ChudShopPageTiny",w*0.5,h*0.4+MenuUnit(26),SHOP_DIM,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end

    -- Showcase: spotlight, accent glow, corner brackets, then the name block and action button.
    local infoH = MenuUnit(200)
    right.Paint = function(pnl,w,h)
        surface.SetDrawColor(9,9,14,215)
        surface.DrawRect(0,0,w,h)
        local accent = ShopAccent(selected)
        local stageH = h-infoH
        if selected then
            pnl.GlowLerp = Lerp(FrameTime()*6,pnl.GlowLerp or 0,1)
            local cx,cy = w*0.5,stageH*0.5
            surface.SetMaterial(shopGlow)
            surface.SetDrawColor(accent.r,accent.g,accent.b,120*pnl.GlowLerp)
            surface.DrawTexturedRect(cx-w*0.42,cy-stageH*0.62,w*0.84,stageH*1.24)
            surface.SetDrawColor(255,255,255,22*pnl.GlowLerp)
            surface.DrawTexturedRect(cx-w*0.22,cy-stageH*0.36,w*0.44,stageH*0.72)
            -- floor line the gun "sits" over
            surface.SetTexture(shopFadeRight)
            surface.SetDrawColor(accent.r,accent.g,accent.b,90)
            surface.DrawTexturedRect(w*0.5,stageH-MenuUnit(30),w*0.35,1)
            surface.SetTexture(shopFadeRight)
            surface.DrawTexturedRectRotated(w*0.325,stageH-MenuUnit(30)+0.5,w*0.35,1,180)
        end
        local inset = MenuUnit(18)
        ShopBrackets(inset,inset,w-inset*2,stageH-inset*2,MenuUnit(18),math.max(1,MenuUnit(2)),Color(255,255,255,selected and 70 or 25))
        draw.SimpleText(isInventory and "INVENTORY" or "PREVIEW","ChudShopKicker",inset+MenuUnit(12),inset+MenuUnit(10),SHOP_DIM)
        if selected and ChudSkins.IsEquipped(selected.id) then
            ShopTag("EQUIPPED","ChudShopKicker",w-inset-MenuUnit(12),inset+MenuUnit(8),color_black,accent,true)
        end
        -- info block
        surface.SetDrawColor(255,255,255,22)
        surface.DrawRect(inset,stageH,w-inset*2,1)
        if not selected then
            draw.SimpleText("SELECT AN ITEM","ChudShopPageSmall",w*0.5,stageH*0.5,SHOP_DIM,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            return
        end
        surface.SetDrawColor(accent)
        surface.DrawRect(inset,stageH+MenuUnit(24),MenuUnit(4),MenuUnit(120))
        local tx = inset+MenuUnit(20)
        draw.SimpleText(ChudSkins.WeaponName(selected.weapon),"ChudShopKicker",tx,stageH+MenuUnit(24),accent)
        draw.SimpleText(selected.name,"ChudShopHero",tx,stageH+MenuUnit(42),color_white)
        surface.SetFont("ChudShopHero")
        local _,heroH = surface.GetTextSize("W")
        local tagY = stageH+MenuUnit(50)+heroH
        local tagX = tx
        tagX = tagX + ShopTag(selected.category or "SKIN","ChudShopKicker",tagX,tagY,SHOP_MUTED,Color(255,255,255,14)) + MenuUnit(8)
        if selected.credit then
            ShopTag("BY " .. selected.credit,"ChudShopKicker",tagX,tagY,accent,Color(accent.r,accent.g,accent.b,28))
        end
    end

    local preview = vgui.Create("DModelPanel",right)
    preview:SetFOV(40)
    preview:SetMouseInputEnabled(false)
    preview.LayoutEntity=function() end -- still, side-on, no spin
    -- Frame the gun itself: measure the gun's mesh in the pose it is drawn in
    -- (arm meshes skipped), then fit that box into the panel, centred.
    local function IsArmMaterial(path)
        path = string.lower(path or "")
        for _,word in ipairs({"hand","arm","glove","sleeve"}) do
            if string.find(path,word,1,true) then return true end
        end
        return false
    end
    -- Measures the gun's mesh in its drawn pose. Parts that float apart from the
    -- main body (spare reload magazines) come back in `loose` so they can be hidden.
    local function MeshBounds(ent)
        local ok,meshes,binds = pcall(util.GetModelMeshes,ent:GetModel(),0,0)
        if not ok or not istable(meshes) or not istable(binds) then return end
        local cache = {}
        local boxes = {}
        for _,part in ipairs(meshes) do
            if not IsArmMaterial(part.material) then
                for _,vert in ipairs(part.triangles or {}) do
                    local pos = Vector(0,0,0)
                    local total,top,topW = 0,nil,-1
                    for _,w in ipairs(vert.weights or {}) do
                        local m = cache[w.bone]
                        if m == nil then
                            local bone = ent:GetBoneMatrix(w.bone)
                            m = (bone and binds[w.bone]) and (bone * binds[w.bone].matrix) or false
                            cache[w.bone] = m
                        end
                        if m then
                            pos = pos + (m * vert.pos) * w.weight
                            total = total + w.weight
                            if w.weight > topW then top,topW = w.bone,w.weight end
                        end
                    end
                    if total > 0 and top then
                        pos = pos / total
                        local box = boxes[top]
                        if box then
                            box.mins.x,box.mins.y,box.mins.z = math.min(box.mins.x,pos.x),math.min(box.mins.y,pos.y),math.min(box.mins.z,pos.z)
                            box.maxs.x,box.maxs.y,box.maxs.z = math.max(box.maxs.x,pos.x),math.max(box.maxs.y,pos.y),math.max(box.maxs.z,pos.z)
                            box.count = box.count + 1
                            box.verts[#box.verts+1] = pos
                        else
                            boxes[top] = {mins = Vector(pos), maxs = Vector(pos), count = 1, verts = {pos}}
                        end
                    end
                end
            end
        end
        -- Group bones whose boxes touch; the biggest group is the gun.
        local ids = table.GetKeys(boxes)
        local parent = {}
        for _,id in ipairs(ids) do parent[id] = id end
        local function root(id) while parent[id] ~= id do id = parent[id] end return id end
        local pad = 0.75
        for i = 1,#ids do
            for j = i+1,#ids do
                local A,B = boxes[ids[i]],boxes[ids[j]]
                if A.mins.x-pad <= B.maxs.x and B.mins.x-pad <= A.maxs.x and A.mins.y-pad <= B.maxs.y and B.mins.y-pad <= A.maxs.y
                    and A.mins.z-pad <= B.maxs.z and B.mins.z-pad <= A.maxs.z then
                    parent[root(ids[i])] = root(ids[j])
                end
            end
        end
        local groups = {}
        for _,id in ipairs(ids) do
            local r = root(id)
            groups[r] = groups[r] or {bones = {}, count = 0}
            table.insert(groups[r].bones,id)
            groups[r].count = groups[r].count + boxes[id].count
        end
        local main
        for _,g in pairs(groups) do if not main or g.count > main.count then main = g end end
        if not main then return end
        local mins,maxs
        local keep = {}
        for _,id in ipairs(main.bones) do
            keep[id] = true
            local box = boxes[id]
            mins = mins and Vector(math.min(mins.x,box.mins.x),math.min(mins.y,box.mins.y),math.min(mins.z,box.mins.z)) or Vector(box.mins)
            maxs = maxs and Vector(math.max(maxs.x,box.maxs.x),math.max(maxs.y,box.maxs.y),math.max(maxs.z,box.maxs.z)) or Vector(box.maxs)
        end
        local loose = {}
        for _,id in ipairs(ids) do if not keep[id] then loose[#loose+1] = id end end
        local verts = {}
        for _,id in ipairs(main.bones) do
            for _,v in ipairs(boxes[id].verts) do verts[#verts+1] = v end
        end
        return mins,maxs,loose,keep,verts
    end
    -- Eigenvectors of a symmetric 3x3 matrix (Jacobi), largest eigenvalue first.
    local function Eigen3(m)
        local a = {{m[1][1],m[1][2],m[1][3]},{m[2][1],m[2][2],m[2][3]},{m[3][1],m[3][2],m[3][3]}}
        local v = {{1,0,0},{0,1,0},{0,0,1}}
        for _ = 1,40 do
            local p,q,big = 1,2,math.abs(a[1][2])
            if math.abs(a[1][3]) > big then p,q,big = 1,3,math.abs(a[1][3]) end
            if math.abs(a[2][3]) > big then p,q,big = 2,3,math.abs(a[2][3]) end
            if big < 1e-9 then break end
            local theta = (a[q][q]-a[p][p])/(2*a[p][q])
            local t = (theta >= 0 and 1 or -1)/(math.abs(theta)+math.sqrt(theta*theta+1))
            local c = 1/math.sqrt(t*t+1)
            local sn = t*c
            for k = 1,3 do
                local akp,akq = a[k][p],a[k][q]
                a[k][p],a[k][q] = c*akp-sn*akq, sn*akp+c*akq
            end
            for k = 1,3 do
                local apk,aqk = a[p][k],a[q][k]
                a[p][k],a[q][k] = c*apk-sn*aqk, sn*apk+c*aqk
            end
            for k = 1,3 do
                local vkp,vkq = v[k][p],v[k][q]
                v[k][p],v[k][q] = c*vkp-sn*vkq, sn*vkp+c*vkq
            end
        end
        local list = {}
        for i = 1,3 do list[i] = {val = a[i][i], vec = Vector(v[1][i],v[2][i],v[3][i])} end
        table.sort(list,function(x,y) return x.val > y.val end)
        return list[1].vec,list[2].vec,list[3].vec
    end
    -- Camera basis from the gun's own shape: long axis runs left-right,
    -- the thin axis faces the camera, so we always see the flat side.
    local function ShapeBasis(verts)
        if #verts < 8 then return end
        local mean = Vector(0,0,0)
        for _,v in ipairs(verts) do mean = mean + v end
        mean = mean / #verts
        local c = {{0,0,0},{0,0,0},{0,0,0}}
        for _,v in ipairs(verts) do
            local d = {v.x-mean.x, v.y-mean.y, v.z-mean.z}
            for i = 1,3 do for j = 1,3 do c[i][j] = c[i][j] + d[i]*d[j] end end
        end
        local long,mid = Eigen3(c)
        long:Normalize() mid:Normalize()
        -- Keep the old orientation habit: long axis points towards +X/+Y, "up" points up.
        if (math.abs(long.x) >= math.abs(long.y) and long.x or long.y) < 0 then long = -long end
        if mid.z < 0 or (math.abs(mid.z) < 0.2 and mid:Dot(Vector(0,0,1)) < 0) then mid = -mid end
        local right,up = long,mid
        local forward = up:Cross(right)
        forward:Normalize()
        up = right:Cross(forward)
        local lo = Vector(math.huge,math.huge,math.huge)
        local hi = Vector(-math.huge,-math.huge,-math.huge)
        for _,v in ipairs(verts) do
            local d = v - mean
            local x,y,z = d:Dot(right),d:Dot(up),d:Dot(forward)
            lo.x,lo.y,lo.z = math.min(lo.x,x),math.min(lo.y,y),math.min(lo.z,z)
            hi.x,hi.y,hi.z = math.max(hi.x,x),math.max(hi.y,y),math.max(hi.z,z)
        end
        local mid3 = (lo+hi)*0.5
        local center = mean + right*mid3.x + up*mid3.y + forward*mid3.z
        return {right = right, up = up, forward = forward, center = center, size = hi-lo}
    end
    -- Hide loose parts, but never a bone the gun itself hangs from.
    local function HideLoose(ent,loose,keep)
        local ancestor = {}
        for id in pairs(keep or {}) do
            local p = ent:GetBoneParent(id)
            while p and p >= 0 and not ancestor[p] do ancestor[p] = true p = ent:GetBoneParent(p) end
        end
        for _,id in ipairs(loose or {}) do
            if not ancestor[id] then ent:ManipulateBoneScale(id,vector_origin) end
        end
    end
    local function FramePreview()
        local ent = preview.Entity
        if not IsValid(ent) then return end
        ent:SetPos(vector_origin)
        ent:SetAngles(angle_zero)
        ent:InvalidateBoneCache()
        ent:SetupBones()
        local mins,maxs,loose,keep,verts = MeshBounds(ent)
        preview.MeshFramed = mins ~= nil and (maxs-mins):Length() >= 1
        if preview.MeshFramed then HideLoose(ent,loose,keep) end
        preview.GunBasis = preview.MeshFramed and ShapeBasis(verts) or nil
        if not preview.MeshFramed then mins,maxs = ent:GetRenderBounds() end
        preview.GunMins,preview.GunMaxs = mins,maxs
        preview.FramedSize = nil
    end
    -- Bones are only guaranteed once the model has drawn, so measure again then.
    preview.PostDrawModel = function(pnl)
        if pnl.MeshFramed or (pnl.FrameTries or 0) >= 3 then return end
        pnl.FrameTries = (pnl.FrameTries or 0) + 1
        FramePreview()
    end
    -- Re-fit whenever the panel changes size (the cards slide and resize).
    preview.Think = function(pnl)
        local w,h = pnl:GetSize()
        if not pnl.GunMins or w < 2 or h < 2 then return end
        local key = w .. "x" .. h
        if pnl.FramedSize == key then return end
        pnl.FramedSize = key
        local tanH = math.tan(math.rad(pnl:GetFOV()*0.5))
        local tanV = tanH*h/w
        local b = pnl.GunBasis
        if b then
            local dist = math.max(b.size.x*0.5/tanH, b.size.y*0.5/tanV)*1.3 + b.size.z*0.5
            pnl:SetCamPos(b.center - b.forward*dist)
            pnl:SetLookAng(b.forward:AngleEx(b.up))
            return
        end
        pnl.aLookAngle = nil
        local mins,maxs = pnl.GunMins,pnl.GunMaxs
        local center = (mins+maxs)*0.5
        local extent = maxs-mins
        -- Look across the gun so the barrel runs left to right.
        local alongY = extent.y > extent.x
        local across = alongY and extent.y or extent.x
        local depth = alongY and extent.x or extent.y
        local tanH = math.tan(math.rad(pnl:GetFOV()*0.5))
        local tanV = tanH*h/w
        local margin = 1.3
        local dist = math.max(across*0.5/tanH, extent.z*0.5/tanV)*margin + depth*0.5
        pnl:SetLookAt(center)
        pnl:SetCamPos(center + (alongY and Vector(dist,0,0) or Vector(0,-dist,0)))
    end
    local function ShowPreview(item)
        local weaponData = weapons.GetStored(item.weapon)
        -- Melee weapons keep their real model in DroppedWorldModel / WorldModelReal.
        local model
        for _,key in ipairs({"WorldModelFake","DroppedWorldModel","WorldModelReal","WorldModel"}) do
            local path = weaponData and weaponData[key]
            if isstring(path) and path ~= "" and file.Exists(path,"GAME") then model = path break end
        end
        preview:SetModel(model or "models/weapons/w_pistol.mdl")
        local ent = preview.Entity
        if not IsValid(ent) then return end
        -- Pose the gun in its idle animation so loose parts (mags, slides) sit in place.
        local idle = weaponData and weaponData.AnimList and weaponData.AnimList.idle
        for _,name in ipairs({idle or "", "idle", "base_idle", "draw"}) do
            local seq = name ~= "" and ent:LookupSequence(name) or -1
            if seq and seq >= 0 then ent:ResetSequence(seq) ent:SetCycle(0) ent:SetPlaybackRate(0) break end
        end
        ChudSkins.ApplyToModel(ent,item.id)
        -- First-person models can carry arms; keep only the weapon on show.
        for i,path in ipairs(ent:GetMaterials()) do
            if IsArmMaterial(path) then ent:SetSubMaterial(i-1,"!ChudShopHiddenMesh") end
        end
        preview.FrameTries = 0
        FramePreview()
        preview:SetAlpha(0)
        preview:AlphaTo(255,0.25,0)
    end

    local buy=vgui.Create("DButton",right)
    buy:SetText("")
    local function BuyState()
        if not selected then return end
        if ChudSkins.IsEquipped(selected.id) then return "UNEQUIP","unequip","outline" end
        if ChudSkins.Owns(selected.id) then return "EQUIP","equip","solid" end
        local coins = IsValid(LocalPlayer()) and LocalPlayer():GetNWInt("ChudCoin",0) or 0
        if coins < selected.price then return "NEED " .. string.Comma(selected.price - coins) .. " MORE COIN",nil,"locked" end
        return "BUY","buy","solid"
    end
    buy.Paint=function(btn,w,h)
        local label,action,style = BuyState()
        if not label then return end
        local waiting = (btn.WaitUntil or 0) > CurTime()
        local accent = ShopAccent(selected)
        local hover = action and btn:IsHovered() and not waiting
        btn.HoverLerp = Lerp(FrameTime()*10,btn.HoverLerp or 0,hover and 1 or 0)
        local radius = MenuUnit(4)
        if style == "solid" then
            local boost = 1+0.18*btn.HoverLerp
            draw.RoundedBox(radius,0,0,w,h,Color(math.min(255,accent.r*boost),math.min(255,accent.g*boost),math.min(255,accent.b*boost),waiting and 120 or 235))
        elseif style == "outline" then
            draw.RoundedBox(radius,0,0,w,h,Color(255,255,255,8+20*btn.HoverLerp))
            surface.SetDrawColor(accent.r,accent.g,accent.b,170)
            surface.DrawOutlinedRect(0,0,w,h,math.max(1,MenuUnit(2)))
        else
            draw.RoundedBox(radius,0,0,w,h,Color(255,255,255,8))
        end
        local dark = style == "solid" and (accent.r*0.3+accent.g*0.59+accent.b*0.11) > 150
        local fg = style == "locked" and SHOP_DIM or (dark and Color(15,15,15) or color_white)
        if waiting then label = "..." end
        if action == "buy" and not waiting then
            draw.SimpleText(label,"ChudShopPageMedium",MenuUnit(20),h*0.5,fg,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            surface.SetFont("ChudShopPageMedium")
            local _,th = surface.GetTextSize("0")
            ShopCoinPrice(selected.price,"ChudShopPageMedium",w-MenuUnit(20),h*0.5-th*0.5,fg,true)
        else
            draw.SimpleText(label,"ChudShopPageMedium",w*0.5,h*0.5,fg,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end
    buy.OnCursorEntered=function() surface.PlaySound(SOUND_MENU_HOVER) end
    buy.DoClick=function(btn)
        local _,action = BuyState()
        if not action or (btn.WaitUntil or 0) > CurTime() then return end
        surface.PlaySound(SOUND_MENU_SELECT)
        btn.WaitUntil = CurTime() + 2
        ChudSkins.Request(action,selected.id)
    end

    local function Select(item)
        local changed = selected ~= item
        selected = item
        preview:SetVisible(item ~= nil)
        buy:SetVisible(item ~= nil)
        if item and changed then right.GlowLerp = 0 ShowPreview(item) end
    end
    -- Item cards: accent bar, name, weapon, price tag or status tag.
    local function BuildRows()
        list:Clear()
        local items = ItemList()
        itemCount = #items
        if selected and not table.HasValue(items,selected) then selected = nil end
        for i,item in ipairs(items) do
            local row = list:Add("DButton")
            row:SetText("")
            row:Dock(TOP)
            row:DockMargin(MenuUnit(12),i == 1 and MenuUnit(12) or MenuUnit(8),MenuUnit(12),0)
            row:SetTall(MenuUnit(78))
            row.CoinRevealStart=CurTime()
            row.Paint = function(btn,w,h)
                local active = selected == item
                local accent = ShopAccent(item)
                btn.ActiveLerp = Lerp(FrameTime()*10,btn.ActiveLerp or 0,active and 1 or 0)
                btn.HoverLerp = Lerp(FrameTime()*10,btn.HoverLerp or 0,btn:IsHovered() and 1 or 0)
                local a,hv = btn.ActiveLerp,btn.HoverLerp
                draw.RoundedBox(MenuUnit(4),0,0,w,h,Color(255,255,255,6+8*hv))
                if a > 0.01 then
                    surface.SetTexture(shopFadeRight)
                    surface.SetDrawColor(accent.r,accent.g,accent.b,45*a)
                    surface.DrawTexturedRectRotated(w*0.5,h*0.5,w,h,180)
                end
                surface.SetDrawColor(accent.r,accent.g,accent.b,120+135*a)
                surface.DrawRect(0,MenuUnit(10)*(1-a),MenuUnit(3)+MenuUnit(2)*a,h-MenuUnit(20)*(1-a))
                local x = MenuUnit(18)+MenuUnit(4)*a
                draw.SimpleText(CoinShopReveal(btn,item.name,"name"),"ChudShopCardName",x,MenuUnit(12),color_white)
                draw.SimpleText(ChudSkins.WeaponName(item.weapon),"ChudShopKicker",x,MenuUnit(46),SHOP_MUTED)
                if ChudSkins.IsEquipped(item.id) then
                    ShopTag("EQUIPPED","ChudShopKicker",w-MenuUnit(14),h*0.5-MenuUnit(11),color_black,accent,true)
                elseif ChudSkins.Owns(item.id) then
                    ShopTag("OWNED","ChudShopKicker",w-MenuUnit(14),h*0.5-MenuUnit(11),SHOP_MUTED,Color(255,255,255,14),true)
                else
                    surface.SetFont("ChudShopPageSmall")
                    local _,th = surface.GetTextSize("0")
                    ShopCoinPrice(item.price,"ChudShopPageSmall",w-MenuUnit(16),h*0.5-th*0.5,color_white,true)
                end
            end
            row.OnCursorEntered=function() surface.PlaySound(SOUND_MENU_HOVER) end
            row.DoClick=function() if selected ~= item then surface.PlaySound(SOUND_MENU_SELECT) Select(item) end end
        end
        Select(selected or items[1])
    end
    BuildRows()
    hook.Add("ChudSkinsUpdated",detail,function()
        buy.WaitUntil = nil
        BuildRows()
    end)
    if ChudSkins then ChudSkins.Request("sync") end

    -- Page background and header band.
    detail.Paint = function(pnl,w,h)
        if hg.DrawBlur then hg.DrawBlur(pnl,5) end
        surface.SetDrawColor(7,7,11,240)
        surface.DrawRect(0,0,w,h)
        local accent = ShopAccent(selected)
        surface.SetTexture(shopFadeUp)
        surface.SetDrawColor(accent.r,accent.g,accent.b,18)
        surface.DrawTexturedRect(0,h*0.55,w,h*0.45)
        local top=MenuUnit(menu_news.top+menu_news.height+8)
        draw.SimpleText("CHUDMORSE  /  COIN STORE","ChudShopKicker",MenuUnit(26),top+MenuUnit(10),SHOP_MUTED)
        draw.SimpleText(CoinShopReveal(pnl,title,"header"),"ChudShopPageTitle",MenuUnit(25),top+MenuUnit(28),color_white)
        surface.SetDrawColor(255,255,255,30)
        surface.DrawRect(MenuUnit(26),top+MenuUnit(76),w-MenuUnit(52),1)
        surface.SetDrawColor(accent)
        surface.DrawRect(MenuUnit(26),top+MenuUnit(75),MenuUnit(60),math.max(2,MenuUnit(3)))
    end
    detail.Think = function(pnl)
        local mx,my=self:GetLiveOffset(MenuUnit(menu_live.profile_drift_x),MenuUnit(menu_live.profile_drift_y))
        local sx,sy=self:GetLiveShake(1.7,2.3,MenuUnit(menu_live.shake_x),MenuUnit(menu_live.shake_y))
        local pad,gap=MenuUnit(26),MenuUnit(18)
        local top=MenuUnit(menu_news.top+menu_news.height+100)
        local usable = pnl:GetWide()-pad*2-gap
        local lw = math.floor(usable*0.36)
        local rw = usable-lw
        local ch=math.max(MenuUnit(240),pnl:GetTall()-top-MenuUnit(80))
        left:SetSize(lw,ch)
        right:SetSize(rw,ch)
        local leftTarget = pad+mx+sx
        local rightTarget = pad+lw+gap+mx+sx
        local targetY = top+my+sy
        local exitLeft,exitRight = -lw-MenuUnit(180),pnl:GetWide()+MenuUnit(180)
        if not pnl.CardsSlideStarted then
            pnl.CardsSlideStarted = true
            left:SetPos(exitLeft,targetY)
            right:SetPos(exitRight,targetY)
        end
        if pnl.Closing then leftTarget,rightTarget=exitLeft,exitRight end
        local step=math.Clamp(FrameTime()*8,0,1)
        local function slide(card,x)
            local nx=Lerp(step,card:GetX(),x)
            local ny=Lerp(step,card:GetY(),targetY)
            if math.abs(nx-x)<1 then nx=x end
            if math.abs(ny-targetY)<1 then ny=targetY end
            card:SetPos(nx,ny)
        end
        slide(left,leftTarget)
        slide(right,rightTarget)
        list:SetPos(0,headerH);list:SetSize(lw,ch-headerH-MenuUnit(8))
        local inset = MenuUnit(18)
        local stageH = ch-infoH
        preview:SetPos(inset*2,inset*2)
        preview:SetSize(rw-inset*4,math.max(20,stageH-inset*4))
        local bw = math.floor(rw*0.36)
        buy:SetSize(bw,MenuUnit(58))
        buy:SetPos(rw-inset-bw,ch-inset-MenuUnit(58))
        if IsValid(self.CoinWallet) then self.CoinWallet:Think() end
    end
    detail:Think()
    local back = vgui.Create("DButton",detail)
    back:SetText("")
    StyleCoinShopButton(back,"<  BACK")
    local hoverThink = back.Think
    back.Think = function(btn)
        hoverThink(btn)
        surface.SetFont("ChudShopPageSmall")
        local tw,th = surface.GetTextSize("#######")
        local bw,bh = surface.GetTextSize("<  BACK")
        btn:SetSize(math.max(tw,bw)+MenuUnit(32),math.max(th,bh)+MenuUnit(24))
        btn:SetPos(MenuUnit(14),detail:GetTall()-btn:GetTall()-MenuUnit(10))
    end
    back.Paint = function(btn,w,h)
        local shade = btn:IsHovered() and (0.5+0.5*math.sin(CurTime()*10))*255 or 225
        draw.SimpleTextOutlined(CoinShopReveal(btn,"<  BACK","label"),"ChudShopPageSmall",MenuUnit(8),h*0.5,Color(shade,shade,shade),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER,1,Color(0,0,0))
    end
    back:Think()
    back.DoClick = function()
        if detail.Closing then return end
        detail.Closing = true
        detail:SetMouseInputEnabled(false)
        surface.PlaySound(SOUND_MENU_SELECT)
        detail:Stop()
        detail:AlphaTo(0,0.2,0,function()
            if not IsValid(self) or not IsValid(detail) then return end
            detail:Remove()
            self.CoinCategoryPage = nil
            if IsValid(self.CoinShopPage) then
                self.CoinShopPage:SetVisible(true)
                self.CoinShopPage:MoveToFront()
                for _,tile in ipairs(self.CoinShopPage.Tiles) do
                    tile.CoinRevealStart=CurTime()
                    tile.CoinRevealCounts={}
                end
            end
            if IsValid(self.previewHolder) then self.previewHolder:SetVisible(true) end
            if IsValid(self.CoinWallet) then self.CoinWallet:MoveToFront();self.CoinWallet:Think() end
        end)
    end
    detail:MoveToFront()
    if IsValid(self.topPlayersTicker) then self.topPlayersTicker:MoveToFront() end
    if IsValid(self.CoinWallet) then self.CoinWallet:MoveToFront();self.CoinWallet:Think() end
end

function PANEL:CreateCoinShopPage()
    local page = vgui.Create("DPanel", self)
    self.CoinShopPage = page
    page:SetPos(ScrW() * 0.42, ScrH() * 0.2)
    page:SetSize(ScrW() * 0.51, ScrH() * 0.68)
    page:SetAlpha(0)
    page:SetMouseInputEnabled(false)
    page.Think = function(this)
        if self.CoinShopMoving then return end
        local mouseX, mouseY = self:GetLiveOffset(MenuUnit(menu_live.profile_drift_x), MenuUnit(menu_live.profile_drift_y))
        local shakeX, shakeY = self:GetLiveShake(1.7, 2.3, MenuUnit(menu_live.shake_x), MenuUnit(menu_live.shake_y))
        this:SetPos(math.Round(ScrW() * 0.42 + mouseX + shakeX), math.Round(ScrH() * 0.2 + mouseY + shakeY))
        if IsValid(self.CoinWallet) then self.CoinWallet:Think() end
    end
    page.Tiles = {}
    page.Paint = function(_, w, h)
        if not page.Category then return end
        draw.SimpleText(CoinShopReveal(page, page.Category, "categoryTitle"), "ChudCoinShopTitle", MenuUnit(8), MenuUnit(8), color_white)
        local text = page.Category == "INVENTORY" and "YOUR INVENTORY IS EMPTY" or "COMING SOON"
        draw.SimpleText(text, "ZCity_Menu_Tiny", MenuUnit(12), h * 0.3, Color(180,180,180))
    end
    local categories = {"INVENTORY", "GUN SKINS", "MELEE SKINS", "COSMETICS"}
    for i, title in ipairs(categories) do
        local tile = vgui.Create("DButton", page)
        page.Tiles[i] = tile
        tile:SetText("")
        StyleCoinShopButton(tile, title)
        tile.Paint = function(btn, w, h)
            surface.SetDrawColor(0,0,0,230)
            surface.DrawRect(0,0,w,h)
            local tint = Color(240,240,240)
            if btn:IsHovered() then
                local v = 150 + 105 * (0.5 + 0.5 * math.sin(CurTime()*10))
                tint = Color(v,v,v)
            end
            surface.SetDrawColor(tint)
            surface.DrawOutlinedRect(1,1,w-2,h-2,2)
            local fontSize = math.max(14, math.min(MenuUnit(34), math.floor(w / (#title * 0.7))))
            local font = "ChudShopTile" .. fontSize
            if not page.TileFonts then page.TileFonts = {} end
            if not page.TileFonts[font] then
                surface.CreateFont(font,{font="Verily Serif Mono",size=fontSize,weight=400,antialias=true})
                page.TileFonts[font]=true
            end
            local label = CoinShopReveal(btn,title,"tile")
            local y = i==1 and h*0.04 or (i==2 and h*0.60 or i==3 and h*0.40 or h*0.40)
            if i==1 then
                ShopSilhouette("pistol",w*0.07,h*0.15,w*0.86,h*0.25,tint)
                ShopSilhouette("diagonal",w*0.10,h*0.43,w*0.80,h*0.22,tint)
                ShopSilhouette("beanie",w*0.12,h*0.70,w*0.60,h*0.25,tint)
            elseif i==2 then
                ShopSilhouette("pistol",w*0.06,h*0.05,w*0.57,h*0.82,tint)
            elseif i==3 then
                ShopSilhouette("knife",w*0.05,h*0.02,w*0.74,h*0.35,tint)
                ShopSilhouette("diagonal",w*0.30,h*0.65,w*0.66,h*0.32,tint)
            else
                ShopSilhouette("hat",w*0.68,h*0.10,w*0.28,h*0.78,tint)
            end
            local tx = i==1 and w*0.5 or i==2 and w*0.97 or i==3 and w*0.5 or w*0.035
            local align = i==1 and TEXT_ALIGN_CENTER or i==2 and TEXT_ALIGN_RIGHT or i==3 and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT
            draw.SimpleTextOutlined(label,font,tx,y,tint,align,TEXT_ALIGN_TOP,1,Color(0,0,0))
            surface.SetDrawColor(255,255,255,255*(btn.LineLerp or 0))
            surface.DrawRect(w*0.05,h-MenuUnit(8),w*0.9*(btn.LineLerp or 0),2)
        end
        tile.DoClick = function()
            if self.CoinShopMoving then return end
            surface.PlaySound(SOUND_MENU_SELECT)
            self:OpenCoinCategory(title)
        end
    end
    page.PerformLayout = function(this,w,h)
        local gap = math.max(6,MenuUnit(8))
        local footer = IsValid(this.BackButton) and this.BackButton:GetTall()+MenuUnit(24) or MenuUnit(85)
        local gridH = math.max(60,h-footer)
        local leftW = math.floor((w-gap)*0.45)
        local rightW = w-leftW-gap
        this.Tiles[1]:SetPos(0,0)
        this.Tiles[1]:SetSize(leftW,gridH)
        local rowH = (gridH-gap*2)/3
        for i=2,4 do
            this.Tiles[i]:SetPos(leftW+gap,(i-2)*(rowH+gap))
            this.Tiles[i]:SetSize(rightW,rowH)
        end
    end
    local back = vgui.Create("DButton", page)
    back:SetText("")
    back:SetSize(MenuUnit(180), MenuUnit(50))
    back:SetPos(0, page:GetTall() - back:GetTall())
    StyleCoinShopButton(back, "<  BACK")
    -- Use the actual menu font metrics, including the reveal's wider hashes.
    local hoverThink = back.Think
    back.Think = function(btn)
        hoverThink(btn)
        surface.SetFont("ZCity_Menu_Small")
        local textW, textH = surface.GetTextSize("<  BACK")
        local revealW, revealH = surface.GetTextSize("#######")
        local width = math.ceil(math.max(textW, revealW) + MenuUnit(32))
        local height = math.ceil(math.max(textH, revealH) + MenuUnit(24))
        if btn:GetWide() ~= width or btn:GetTall() ~= height then btn:SetSize(width, height); page:InvalidateLayout() end
        btn:SetPos(MenuUnit(8), page:GetTall() - height - MenuUnit(8))
    end
    back:Think()
    page.BackButton = back
    back.DoClick = function()
        if self.CoinShopMoving then return end
        if page.Category then
            surface.PlaySound(SOUND_MENU_SELECT)
            page.Category = nil
            for _, tile in ipairs(page.Tiles) do
                tile.CoinRevealStart = CurTime()
                tile.CoinRevealCounts = {}
                tile:SetVisible(true)
            end
        else
            self:TravelToCoinShop(false)
        end
    end
    page:InvalidateLayout(true)
end

-- Pull the two pages horizontally; the preview stays in its idle pose.
function PANEL:TravelToCoinShop(open)
    if self.DisconnectCutscene or self.SwitchingPanel or self.CoinShopMoving then return end
    if open == (self.CoinShopOpen == true) then return end
    self.CoinShopMoving = true
    self.CoinShopDestination = open
    self.CoinShopTravelStart = RealTime()
    if open then self:SetMenuMusic(menu_music_shop_path) else self:UseDefaultMenuMusic() end
    -- Shared header remains in place while the pages pull underneath it.
    if IsValid(self.topPlayersTicker) then
        self.topPlayersTicker:Stop()
        self.topPlayersTicker:SetVisible(true)
        self.topPlayersTicker:SetAlpha(255)
        self.topPlayersTicker:SetPos(0, MenuUnit(menu_news.top))
        self.topPlayersTicker:SetSize(ScrW(), MenuUnit(menu_news.height))
        self.topPlayersTicker:MoveToFront()
    end
    surface.PlaySound(SOUND_MENU_SELECT)
    if open then
        self.CoinShopSavedChildren = {}
        for _, child in ipairs(self:GetChildren()) do
            if child ~= self.previewHolder and child ~= self.CoinWallet and child ~= self.topPlayersTicker then
                self.CoinShopSavedChildren[child] = {
                    visible = child:IsVisible(), alpha = child:GetAlpha(), mouse = child:IsMouseInputEnabled(),
                    x = child:GetX(), y = child:GetY(), dock = child:GetDock()
                }
                child:Stop()
                child:Dock(NODOCK)
                child:SetMouseInputEnabled(false)
            end
        end
        self:CreateCoinShopPage()
        if IsValid(self.CoinWallet) then
            self.CoinWallet:SetVisible(true)
            self.CoinWallet:SetAlpha(255)
        end
        self.CoinShopPage:SetAlpha(255)
        self.CoinShopPage:SetX(ScrW() * 1.42)
        self.CoinShopPage.CoinRevealStart = CurTime()
        self.CoinShopPage.BackButton.CoinRevealStart = CurTime()
    else
        if IsValid(self.CoinShopPage) then self.CoinShopPage:SetMouseInputEnabled(false) end
        for child, saved in pairs(self.CoinShopSavedChildren or {}) do
            if IsValid(child) then
                child:SetVisible(saved.visible)
                child:SetAlpha(saved.alpha)
            end
        end
    end
    local holder = self.previewHolder
    if IsValid(holder) then
        if open then
            self.CoinShopHome = {x = holder.TargetX or holder:GetX(), y = holder.TargetY or holder:GetY(), follow = holder.AppearanceFollow}
        end
        holder:Stop()
        holder.AppearanceFollow = false
        holder:SetVisible(true)
        holder:SetAlpha(255)
        holder:SetY(self.CoinShopHome.y)
        holder:MoveToFront()
    end
    if IsValid(self.previewModel) then
        self.previewModel.SequenceNameOverride = nil
        self.previewModel.SequencePlaybackRate = nil
        self.previewModel.EntityAngleOverride = nil
        self.previewModel.ActiveSequenceName = nil
    end
    if IsValid(self.CoinWallet) then self.CoinWallet:MoveToFront() end
    self:ThinkCoinShop()
    if IsValid(self.CoinWallet) then self.CoinWallet:Think() end
end

function PANEL:ThinkCoinShop()
    if not self.CoinShopMoving then return end
    local fraction = math.Clamp((RealTime() - self.CoinShopTravelStart) / 0.65, 0, 1)
    local eased = fraction * fraction * (3 - 2 * fraction)
    local progress = self.CoinShopDestination and eased or (1 - eased)
    for child, saved in pairs(self.CoinShopSavedChildren or {}) do
        if IsValid(child) then child:SetPos(saved.x - ScrW() * progress, saved.y) end
    end
    if IsValid(self.CoinShopPage) then
        self.CoinShopPage:SetX(ScrW() * 0.42 + ScrW() * (1 - progress))
    end
    if IsValid(self.previewHolder) and self.CoinShopHome then
        self.previewHolder:SetX(Lerp(progress, self.CoinShopHome.x, ScrW() * 0.24 - self.previewHolder:GetWide() * 0.5))
    end
    if fraction < 1 then return end
    self.CoinShopMoving = false
    self.CoinShopOpen = self.CoinShopDestination
    if self.CoinShopOpen then
        for child in pairs(self.CoinShopSavedChildren or {}) do
            if IsValid(child) then child:SetVisible(false) end
        end
        if IsValid(self.CoinShopPage) then
            self.CoinShopPage:SetMouseInputEnabled(true)
            self.CoinShopPage:MoveToFront()
        end
    else
        if IsValid(self.CoinShopPage) then self.CoinShopPage:Remove() end
        if IsValid(self.CoinWallet) then self.CoinWallet:SetVisible(false) end
        for child, saved in pairs(self.CoinShopSavedChildren or {}) do
            if IsValid(child) then
                child:SetPos(saved.x, saved.y)
                child:Dock(saved.dock)
                child:SetVisible(saved.visible)
                child:SetMouseInputEnabled(saved.mouse)
                child:SetAlpha(saved.alpha)
            end
        end
        if IsValid(self.CoinShopArrow) then
            self.CoinShopArrow.CoinRevealStart = CurTime()
            self.CoinShopArrow.CoinRevealCounts = {}
            self.CoinShopArrow.WasHovered = false
            self.CoinShopArrow:Stop()
            self.CoinShopArrow:SetVisible(true)
            self.CoinShopArrow:SetAlpha(255)
            self.CoinShopArrow:SetMouseInputEnabled(true)
            self.CoinShopArrow:MoveToFront()
        end
        if IsValid(self.CoinWallet) then self.CoinWallet:MoveToFront() end
        self.CoinShopSavedChildren = nil
        if IsValid(self.previewHolder) then self.previewHolder.AppearanceFollow = self.CoinShopHome.follow end
    end
end

function PANEL:ResetCurrentPanel()
    curent_panel = nil
end

function PANEL:AddSelect( pParent, strTitle, tbl )
    local id = #self.Buttons + 1
    self.Buttons[id] = vgui.Create( "DLabel", pParent )
    local btn = self.Buttons[id]
    btn:SetText( string.rep("#", #(curent_panel == string.lower(strTitle) and strTitle ~= 'Traitor Role' and '[ '..strTitle..' ]' or strTitle)) )
    btn:SetMouseInputEnabled( true )
    btn:SizeToContents()
    btn:SetFont( "ZCity_Menu_Small" )
    btn:SetTall( MenuUnit(42) )
    btn:Dock(BOTTOM)
    btn:DockMargin(MenuUnit(15),MenuUnit(2),0,0)
    btn.Func = tbl.Func
    btn.HoveredFunc = tbl.HoveredFunc
    local luaMenu = self 
    if tbl.CreatedFunc then tbl.CreatedFunc(btn, self, luaMenu) end
    btn.RColor = Color(225,225,225)
    btn.OpenTime = CurTime()
    btn.LineLerp = 0
    btn.HoverLerp = 0
    btn.HoverOffset = 0.5
    function btn:DoClick()
        if luaMenu.DisconnectCutscene then return end
        if luaMenu.SwitchingPanel then return end
        surface.PlaySound(SOUND_MENU_SELECT)

        if tbl.BypassTransition then
            btn.Func(luaMenu)
            return
        end

        for _, child in ipairs(luaMenu:GetChildren()) do
            if child ~= luaMenu.panelparrent and not (strTitle == "Appearance" and child == luaMenu.previewHolder) then
                child:AlphaTo(0, 0.2, 0, function()
                    if IsValid(child) then child:SetVisible(false) end
                end)
            end
        end

        luaMenu.SwitchingPanel = true
        local oldPanel = luaMenu.panelparrent
        local function openPanel()
            if IsValid(luaMenu.panelparrent) then
                luaMenu.panelparrent:Remove()
            end
            luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)
            
            luaMenu.panelparrent:SetPos(0, 0)
            luaMenu.panelparrent:SetSize(ScrW(), ScrH())
            luaMenu.panelparrent:MoveToFront()
            luaMenu.panelparrent.Paint = function(this, w, h) end

            -- Route the two large content pages explicitly. This prevents a stale
            -- callback/panel from ever sending Achievements to Information (or vice versa).
            luaMenu.ActiveMenuPage = strTitle
            if strTitle == "Achievements" then
                if hg.DrawAchievmentsMenu then
                    hg.DrawAchievmentsMenu(luaMenu.panelparrent)
                else
                    ErrorNoHalt("[Chudmorse] Achievements page renderer is missing.\n")
                end
            elseif strTitle == "Information" then
                if hg.DrawInformation then
                    hg.DrawInformation(luaMenu.panelparrent)
                else
                    ErrorNoHalt("[Chudmorse] Information page renderer is missing.\n")
                end
            else
                btn.Func(luaMenu,luaMenu.panelparrent)
            end

            curent_panel = string.lower(strTitle)
            luaMenu.SwitchingPanel = false
        end

        if IsValid(oldPanel) then
            oldPanel:AlphaTo(0,0.2,0,openPanel)
        else
            openPanel()
        end
    end

    function btn:Think()
        local isHovered = self:IsHovered() or (IsValid(self:GetChild(0)) and self:GetChild(0):IsHovered()) or (IsValid(self:GetChild(0)) and IsValid(self:GetChild(0):GetChild(0)) and self:GetChild(0):GetChild(0):IsHovered())
        if isHovered and not self.WasHovered then
            surface.PlaySound(SOUND_MENU_HOVER)
        end
        self.WasHovered = isHovered

        self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, isHovered and 1 or 0)
        self.LineLerp = LerpFT(0.2, self.LineLerp or 0, isHovered and 1 or 0)
        local mouseX, mouseY = luaMenu:GetLiveOffset(MenuUnit(menu_live.button_drift_x), MenuUnit(menu_live.button_drift_y))
        local shakeX, shakeY = luaMenu:GetLiveShake(id * 0.91, id * 1.27, MenuUnit(menu_live.button_shake_x), MenuUnit(menu_live.button_shake_y))
        self:DockMargin(
            math.Round(MenuUnit(15) + mouseX * 0.3 + shakeX + self.HoverLerp * (self.HoverOffset or MenuUnit(2))),
            math.Round(MenuUnit(2) + mouseY * 0.1 + shakeY),
            0,
            0
        )

        local elapsed = CurTime() - self.OpenTime
        local charsToShow = math.floor(elapsed * 15)
        local targetText = (curent_panel == string.lower(strTitle) and strTitle ~= 'Traitor Role') and '[ '..strTitle..' ]' or strTitle
        local len = #targetText

        if charsToShow > len then charsToShow = len end
        if self.TypewriterTarget ~= targetText then
            self.TypewriterTarget = targetText
            self.LastTypewriterChars = 0
        end
        if charsToShow > 0 and charsToShow > (self.LastTypewriterChars or 0) then
            PlayTypewriterSound()
        end
        self.LastTypewriterChars = charsToShow

        local ntxt = ""
        for i = 1, len do
            if i <= charsToShow then
                ntxt = ntxt .. targetText:sub(i, i)
            else
                ntxt = ntxt .. "#"
            end
        end

        if self:GetText() ~= ntxt then
            self:SetText(ntxt)
            self:SizeToContents()
        end
    end

    function btn:Paint(w, h)
        local isHovered = self:IsHovered() or (IsValid(self:GetChild(0)) and self:GetChild(0):IsHovered()) or (IsValid(self:GetChild(0)) and IsValid(self:GetChild(0):GetChild(0)) and self:GetChild(0):GetChild(0):IsHovered())
        local flash = isHovered and (0.5 + 0.5 * math.sin(CurTime() * 10)) or 0
        
        local textColor = self.RColor
        local outlineColor = Color(0, 0, 0, 255)

        if isHovered then
            local v = flash * 255
            textColor = Color(v, v, v, 255)
            local inv = 255 - v
            outlineColor = Color(inv, inv, inv, 255)
        end

        surface.SetFont(self:GetFont())
        local tw, th = surface.GetTextSize(self:GetText())
        local scale = 1 + (self.HoverLerp or 0) * menu_live.button_hover_scale
        local matrix = Matrix()
        matrix:Translate(Vector(0, h * (1 - scale) * 0.5, 0))
        matrix:Scale(Vector(scale, scale, 1))
        cam.PushModelMatrix(matrix)
        draw.SimpleTextOutlined(self:GetText(), self:GetFont(), 0, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, outlineColor)

        if self.LineLerp and self.LineLerp > 0.01 then
            surface.SetDrawColor(255, 255, 255, 255 * self.LineLerp)
            surface.DrawRect(0, h / 2 + th / 2, tw * self.LineLerp, math.max(1, MenuUnit(1)))
        end
        cam.PopModelMatrix()
        return true
    end
end

function PANEL:Close()
    if self.DisconnectCutscene then return end
    StopMainMenuMusic()
    if IsValid(self.previewModel) and IsValid(self.previewModel.Entity) then
        CleanupPreviewAccessories(self.previewModel.Entity)
    end
    if IsValid(self.previewHolder) then
        self.previewHolder.AppearanceFollow = false
        self.previewHolder:MoveTo(self.previewHolder.TargetX or self.previewHolder:GetX(), self.previewHolder.ClosedY or ScrH(), appearance_preview.exit_time, 0, appearance_preview.exit_delay)
        self.previewHolder:AlphaTo(0, appearance_preview.exit_time * 0.75, appearance_preview.exit_delay)
    end
    self:AlphaTo(0, appearance_preview.exit_time, 0, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
end

function PANEL:OnRemove()
    StopMainMenuMusic()
end

function PANEL:SetMenuMusic(path)
    QueueMainMenuMusic(self, path)
end

function PANEL:UseDefaultMenuMusic()
    self:SetMenuMusic(menu_music_default_path)
end

function PANEL:UseAppearanceMenuMusic()
    self:SetMenuMusic(menu_music_appearance_path)
end

vgui.Register( "ZMainMenu", PANEL, "ZFrame")

hook.Add("OnPauseMenuShow","OpenMainMenu",function()
    local run = hook.Run("OnShowZCityPause")
    if run != nil then
        return run
    end

    if MainMenu and IsValid(MainMenu) then
        if MainMenu.DisconnectCutscene then
            return false
        end
        MainMenu:Close()
        MainMenu = nil
        return false
    end

    MainMenu = vgui.Create("ZMainMenu")
    MainMenu:MakePopup()
    return false
end)
