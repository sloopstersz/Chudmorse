local XDEBC_Language = "en"
local XDEBC_ActiveBarricades = {}
local XDEBC_ActiveNails = {}

if CLIENT then
	local lang = {}
	lang[ "zh-cn" ] = {
		[ "Weapon" ] = "钉锤",
		[ "Purpose" ] = "用木板封住门窗,或用来维修其它设施.",
		[ "Instruct" ] = "左键放置木板/维修物品/拆除物品\nE+左右键旋转木板\n右键打开放置模式面板\nR键快速切换模式",
		[ "Author" ] = "作者",
		[ "Purpose2" ] = "目的",
		[ "Mode" ] = "模式 : %MODE%",
		[ "Mode0" ] = "破坏",
		[ "Mode1" ] = "维修",
		[ "Mode2" ] = "钉子",
		[ "Mode3" ] = "放置",
		[ "Health" ] = "血量 : %HEALTH%",
		[ "Plank" ] = "木板",
		[ "Angle" ] = "角度",
	}
	lang[ "en" ] = {
		[ "Weapon" ] = "Barricade",
		[ "Purpose" ] = "Place wooden planks or repair things",
		[ "Instruct" ] = "M1 - place planks/repair or destroy things\nE+M1/E+M2 - rotate placement angle\nM2 - select placement mode\nR - quick switch",
		[ "Author" ] = "Author",
		[ "Purpose2" ] = "Purpose",
		[ "Mode" ] = "Mode : %MODE%",
		[ "Mode0" ] = "Destruct",
		[ "Mode1" ] = "Build / Repair",
		[ "Mode2" ] = "Nail",
		[ "Mode3" ] = "Build",
		[ "Health" ] = "Health : %HEALTH%",
		[ "Plank" ] = "Plank",
		[ "Angle" ] = "Angle",
	}
	lang[ "de" ] = {
		[ "Weapon" ] = "Barrikade",
		[ "Purpose" ] = "Holzbretter platzieren oder Dinge reparieren",
		[ "Instruct" ] = "M1 – Bretter platzieren/Dinge reparieren oder zerstören\nE+M1/E+M2 – Platzierungswinkel drehen\nM2 – Platzierungsmodus auswählen\nR - schnell umschalten",
		[ "Author" ] = "Autor",
		[ "Purpose2" ] = "Zweck",
		[ "Mode" ] = "Modus : %MODE%",
		[ "Mode0" ] = "Zerstören",
		[ "Mode1" ] = "Reparatur",
		[ "Mode2" ] = "Nagel",
		[ "Mode3" ] = "Ort",
		[ "Health" ] = "Gesundheit : %HEALTH%",
		[ "Plank" ] = "Planke",
		[ "Angle" ] = "Winkel",
	}
	lang[ "ru" ] = {
		[ "Weapon" ] = "Молоток",
		[ "Purpose" ] = "Ставьте деревянные доски или ремонтируйте вещи",
		[ "Instruct" ] = "ЛКМ — поставить доску, починить или уничтожить объект\nE + ЛКМ/ПКМ — повернуть доску\nПКМ — открыть меню размещения\nR — сменить режим",
		[ "Author" ] = "Автор",
		[ "Purpose2" ] = "Цель",
		[ "Mode" ] = "Режим : %MODE%",
		[ "Mode0" ] = "Уничтожить",
		[ "Mode1" ] = "Ремонт",
		[ "Mode2" ] = "Гвозди",
		[ "Mode3" ] = "Построить",
		[ "Health" ] = "Здоровье : %HEALTH%",
		[ "Plank" ] = "Планка",
		[ "Angle" ] = "Угол",
	}
	lang[ "fr" ] = {
		[ "Weapon" ] = "Marteau",
		[ "Purpose" ] = "Placer des planches de bois ou réparer des choses",
		[ "Instruct" ] = "M1 - placer des planches/réparer ou détruire des choses\nE+M1/E+M2 – faire pivoter l'angle de placement\nM2 – 2 - sélectionner le mode de placement\nR - commutateur rapide",
		[ "Author" ] = "Auteur",
		[ "Purpose2" ] = "Objectif",
		[ "Mode" ] = "Mode : %MODE%",
		[ "Mode0" ] = "Détruire",
		[ "Mode1" ] = "Réparation",
		[ "Mode2" ] = "Ongles",
		[ "Mode3" ] = "Lieu",
		[ "Health" ] = "Santé : %HEALTH%",
		[ "Plank" ] = "Planche",
		[ "Angle" ] = "Angle",
	}
	lang[ "pl" ] = {
		[ "Weapon" ] = "Młotek",
		[ "Purpose" ] = "Układanie drewnianych desek lub naprawa przedmiotów",
		[ "Instruct" ] = "M1 - stawiaj deski/naprawiaj lub niszcz rzeczy\nE+M1/E+M2 - obrócić kąt umieszczenia\nM2 - wybierz tryb umieszczania\nR - szybkie przełączanie",
		[ "Author" ] = "Autor",
		[ "Purpose2" ] = "Cel",
		[ "Mode" ] = "Tryb : %MODE%",
		[ "Mode0" ] = "Zniszczyć",
		[ "Mode1" ] = "Naprawa",
		[ "Mode2" ] = "Paznokcie",
		[ "Mode3" ] = "Miejsce",
		[ "Health" ] = "Zdrowie : %HEALTH%",
		[ "Plank" ] = "Deska",
		[ "Angle" ] = "Kąt",
	}
	lang[ "ja" ] = {
		[ "Weapon" ] = "ハンマー",
		[ "Purpose" ] = "木の板を置いたり、物を修理したりする",
		[ "Instruct" ] = "M1 - 板を置く/物を修理または破壊する\nE+M1/E+M2 - 配置角度を回転する\nM2 - 配置モードを選択します\nR - クイックスイッチ",
		[ "Author" ] = "著者",
		[ "Purpose2" ] = "目的",
		[ "Mode" ] = "モード : %MODE%",
		[ "Mode0" ] = "破壊",
		[ "Mode1" ] = "修理",
		[ "Mode2" ] = "釘",
		[ "Mode3" ] = "コンストラクト",
		[ "Health" ] = "健康 : %HEALTH%",
		[ "Plank" ] = "板",
		[ "Angle" ] = "角度",
	}
	local ln, lg = string.lower( GetConVar( "gmod_language" ):GetString() ), "en"
	if ln != nil and istable( lang[ ln ] ) then lg = ln end
	XDEBC_Language = lg
	for holder, text in pairs( lang[ lg ] ) do
		language.Add( "xdebc."..holder, text )
	end
	language.Add( "xdebc.ResourcesMaterials", lg == "ru" and "Материалы" or "Materials" )
	language.Add( "xdebc.ResourcesNails", lg == "ru" and "Гвозди" or "Nails" )
	language.Add( "xdebc.Category", lg == "ru" and "Баррикады" or "Barricade" )
	local placementReasons = lg == "ru" and {
		[ 1 ] = "Нет подходящей поверхности",
		[ 2 ] = "Место занято",
		[ 3 ] = "Достигнут лимит гвоздей",
		[ 4 ] = "Недостаточно гвоздей",
		[ 5 ] = "Достигнут лимит баррикад",
		[ 6 ] = "Недостаточно материалов",
		[ 7 ] = "Нужна поверхность пола",
		[ 8 ] = "Достигнут лимит пропов"
	} or {
		[ 1 ] = "No valid surface",
		[ 2 ] = "Space is blocked",
		[ 3 ] = "Nail limit reached",
		[ 4 ] = "Not enough nails",
		[ 5 ] = "Barricade limit reached",
		[ 6 ] = "Not enough materials",
		[ 7 ] = "A floor surface is required",
		[ 8 ] = "Prop limit reached"
	}
	for reasonID, reasonText in pairs( placementReasons ) do
		language.Add( "xdebc.PlaceReason"..reasonID, reasonText )
	end
	if lg == "ru" then
		local russianText = {
			[ "Weapon" ] = "Молоток",
			[ "Purpose" ] = "Ставьте деревянные доски или ремонтируйте объекты",
			[ "Instruct" ] = "ЛКМ — поставить доску, починить или уничтожить объект\nE + ЛКМ/ПКМ — повернуть доску\nПКМ — открыть меню размещения\nR — сменить режим",
			[ "Author" ] = "Автор",
			[ "Purpose2" ] = "Цель",
			[ "Mode" ] = "Режим : %MODE%",
			[ "Mode0" ] = "Уничтожить",
			[ "Mode1" ] = "Ремонт",
			[ "Mode2" ] = "Гвозди",
			[ "Mode3" ] = "Построить",
			[ "Health" ] = "Здоровье : %HEALTH%",
			[ "Plank" ] = "Доска",
			[ "Angle" ] = "Угол"
		}
		for holder, text in pairs( russianText ) do
			language.Add( "xdebc."..holder, text )
		end
		language.Add( "xdebc.ResourcesMaterials", "Материалы" )
		language.Add( "xdebc.ResourcesNails", "Гвозди" )
		language.Add( "xdebc.Category", "Баррикады" )
		local russianReasons = {
			[ 1 ] = "Нет подходящей поверхности",
			[ 2 ] = "Место занято",
			[ 3 ] = "Достигнут лимит гвоздей",
			[ 4 ] = "Недостаточно гвоздей",
			[ 5 ] = "Достигнут лимит баррикад",
			[ 6 ] = "Недостаточно материалов",
			[ 7 ] = "Нужна поверхность пола",
			[ 8 ] = "Достигнут лимит пропов"
		}
		for reasonID, reasonText in pairs( russianReasons ) do
			language.Add( "xdebc.PlaceReason"..reasonID, reasonText )
		end
	end
	language.Add( "weapon_xdebarricade", language.GetPhrase( "xdebc.Weapon" ) )
	surface.CreateFont( "xde_Select", { font = "Halflife2", size = 128, weight = 1, antialias = true, bold = true } )
	killicon.AddFont( "weapon_xdebarricade", "HL2MPTypeDeath", "6", Color( 255, 255, 255, 255 ) )
	surface.CreateFont( "xdebc_Font1", { font = "Terminal", size = 32, weight = 100, antialias = true, extended = true } )
	surface.CreateFont( "xdebc_Font2", { font = "Terminal", size = 24, weight = 100, antialias = true, extended = true } )
	surface.CreateFont( "xdebc_Font3", { font = "Terminal", size = 18, weight = 100, antialias = true, extended = true } )
end

if SERVER then
	local serverLanguage = string.lower( GetConVar( "gmod_language" ):GetString() )
	XDEBC_Language = serverLanguage == "ru" and "ru" or "en"
	local SVConvars = bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER )
	CreateConVar( "xdebc_hp", "10", SVConvars, "Maximum health multiplier for reinforced planks", 1, 100 )
	CreateConVar( "xdebc_nailhp", "5", SVConvars, "Maximum health multiplier for nails, hard cap is 100", 1, 10 )
	CreateConVar( "xdebc_plankhp", "100", SVConvars, "Maximum health for placed planks, hard cap is 5000", 1, 5000 )
	CreateConVar( "xdebc_npcdamage", "10", SVConvars, "Maximum damage an NPC can deal to a placed plank per hit", 1, 100 )
	CreateConVar( "xdebc_repairamount", "20", SVConvars, "Health restored to a barricade prop by one hammer hit", 1, 100 )
	CreateConVar( "xdebc_maxbarricades", "12", SVConvars, "Maximum barricade props owned by one player", 1, 100 )
	CreateConVar( "xdebc_maxnails", "50", SVConvars, "Maximum barricade nails placed by one player", 1, 200 )
else
	CreateClientConVar( "xdebc_max", "0", true, true, "Fully reinforce your planks when placed, admin only", 0, 1 )
end

sound.Add( {
	name = "xdebarricade.hitworld",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	pitch = { 90, 95 },
	sound = ")weapons/hammer/hit_world01.wav"
} )
sound.Add( {
	name = "xdebarricade.hit",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	pitch = { 100, 105 },
	sound = ")weapons/hammer/hit_melee01.wav"
} )
sound.Add( {
	name = "xdebarricade.hitplank",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	pitch = { 100, 105 },
	sound = {
		")weapons/plank/plank_hit-01.wav",
		")weapons/plank/plank_hit-02.wav",
		")weapons/plank/plank_hit-03.wav",
		")weapons/plank/plank_hit-04.wav"
	}
} )
sound.Add( {
	name = "xdebarricade.hitfix",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	pitch = { 100, 105 },
	sound = {
		")weapons/hammer/hit_nail01.wav",
		")weapons/hammer/hit_nail02.wav",
		")weapons/hammer/hit_nail03.wav",
		")weapons/hammer/hit_nail04.wav"
	}
} )
sound.Add( {
	name = "xdebarricade.hitmiss",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	pitch = { 100, 105 },
	sound = ")weapons/iceaxe/iceaxe_swing1.wav"
} )

local xdebc_Planks = { -- 模型路径, 原角度, 大小, 变化角度, 长度
	{ "models/props_debris/wood_board01a.mdl", Angle( -90, 0, 0 ), Vector( 1.75, 0, 64 ), Angle( 1, 0, 0 ), Vector( 1.75, 0, 64 ) },
	{ "models/props_debris/wood_board02a.mdl", Angle( -90, 0, 0 ), Vector( 1.75, 0, 32 ), Angle( 1, 0, 0 ), Vector( 1.75, 0, 32 ) },
	{ "models/props_debris/wood_board03a.mdl", Angle( -90, 0, 0 ), Vector( 1.75, 0, 64 ), Angle( 1, 0, 0 ), Vector( 1.75, 0, 64 ) },
	{ "models/props_debris/wood_board04a.mdl", Angle( -90, 0, 0 ), Vector( 1.75, 0, 32 ), Angle( 1, 0, 0 ), Vector( 1.75, 0, 32 ) },
	{ "models/props_debris/wood_board05a.mdl", Angle( -90, 0, 0 ), Vector( 1.75, 0, 64 ), Angle( 1, 0, 0 ), Vector( 1.75, 0, 64 ) },
	{ "models/props_debris/wood_board06a.mdl", Angle( -90, 0, 0 ), Vector( 1.75, 0, 32 ), Angle( 1, 0, 0 ), Vector( 1.75, 0, 32 ) },
	{ "models/props_debris/wood_board07a.mdl", Angle( -90, 0, 0 ), Vector( 6, 0, 64 ), Angle( 1, 0, 0 ), Vector( 6, 0, 64 ) },
	{ "models/props_wasteland/dockplank01b.mdl", Angle( 0, 90, 0 ), Vector( 0, -200, -0.75 ), Angle( 1, 0, 0 ), Vector( 0, -200, -0.75 ) },
	{ "models/props_c17/fence01b.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Fences", "floor" },
	{ "models/props_c17/fence01a.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Fences", "floor" },
	{ "models/props_c17/fence03a.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Fences", "floor" },

	{ "models/props_interiors/Furniture_shelf01a.mdl", Angle( 0, 90, 0 ), Vector( 48, 0, 72 ), Angle( 0, 0, 0 ), Vector( 48, 0, 72 ), "Furniture", "floor" },
	{ "models/props_c17/FurnitureTable002a.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 36 ), Angle( 0, 0, 0 ), Vector( 64, 0, 36 ), "Furniture", "floor" },
	{ "models/props_c17/FurnitureTable003a.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 36 ), Angle( 0, 0, 0 ), Vector( 64, 0, 36 ), "Furniture", "floor" },
	{ "models/props_c17/FurnitureShelf001a.mdl", Angle( 0, 90, 0 ), Vector( 48, 0, 72 ), Angle( 0, 0, 0 ), Vector( 48, 0, 72 ), "Furniture", "floor" },
	{ "models/props_wasteland/kitchen_shelf001a.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Furniture", "floor" },
	{ "models/props_wasteland/kitchen_shelf002a.mdl", Angle( 0, 90, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Furniture", "floor" },


	{ "models/props_debris/metal_panel02a.mdl", Angle( -90, 0, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Metal panels", "floor" },
	{ "models/props_debris/metal_panel01a.mdl", Angle( -90, 0, 0 ), Vector( 64, 0, 64 ), Angle( 0, 0, 0 ), Vector( 64, 0, 64 ), "Metal panels", "floor" },
}

local xdebc_PlankNames = {
	[ "models/props_debris/wood_board01a.mdl" ] = { ru = "Доска 01", en = "Debris Board 01" },
	[ "models/props_debris/wood_board02a.mdl" ] = { ru = "Доска 02", en = "Debris Board 02" },
	[ "models/props_debris/wood_board03a.mdl" ] = { ru = "Доска 03", en = "Debris Board 03" },
	[ "models/props_debris/wood_board04a.mdl" ] = { ru = "Доска 04", en = "Debris Board 04" },
	[ "models/props_debris/wood_board05a.mdl" ] = { ru = "Доска 05", en = "Debris Board 05" },
	[ "models/props_debris/wood_board06a.mdl" ] = { ru = "Доска 06", en = "Debris Board 06" },
	[ "models/props_debris/wood_board07a.mdl" ] = { ru = "Доска 07", en = "Debris Board 07" },
	[ "models/props_wasteland/dockplank01b.mdl" ] = { ru = "Настил", en = "Dock Plank" },
	[ "models/props_phx/construct/wood/wood_boardx1.mdl" ] = { ru = "Конструкционная доска 1", en = "Wood Construction Board 1" },
	[ "models/props_phx/construct/wood/wood_boardx2.mdl" ] = { ru = "Конструкционная доска 2", en = "Wood Construction Board 2" },
	[ "models/props_phx/construct/wood/wood_boardx4.mdl" ] = { ru = "Конструкционная доска 4", en = "Wood Construction Board 4" },
	[ "models/props_phx/construct/wood/wood_angle360.mdl" ] = { ru = "Деревянный угол 360", en = "Wood Angle 360" },
	[ "models/props_phx/construct/wood/wood_panel1x1.mdl" ] = { ru = "Деревянная панель 1x1", en = "Wood Panel 1x1" },
	[ "models/props_phx/construct/wood/wood_panel1x2.mdl" ] = { ru = "Деревянная панель 1x2", en = "Wood Panel 1x2" },
	[ "models/props_phx/construct/wood/wood_panel2x2.mdl" ] = { ru = "Деревянная панель 2x2", en = "Wood Panel 2x2" },
	[ "models/props_junk/wood_pallet001a.mdl" ] = { ru = "Деревянный поддон", en = "Wooden Pallet" },
	[ "models/props/de_prodigy/wood_pallet_01.mdl" ] = { ru = "Поддон Prodigy", en = "Prodigy Wooden Pallet" },
	[ "models/props_c17/fence01b.mdl" ] = { ru = "Секция забора 1", en = "Fence Section 01B" },
	[ "models/props_c17/fence01a.mdl" ] = { ru = "Секция забора 2", en = "Fence Section 01A" },
	[ "models/props_c17/fence03a.mdl" ] = { ru = "Секция забора 3", en = "Fence Section 03A" },
	[ "models/props_c17/FurnitureDresser001a.mdl" ] = { ru = "Комод", en = "Dresser" },
	[ "models/props_interiors/Furniture_shelf01a.mdl" ] = { ru = "Настенная полка", en = "Wall Shelf" },
	[ "models/props_c17/FurnitureTable002a.mdl" ] = { ru = "Стол 2", en = "Table 002" },
	[ "models/props_c17/FurnitureTable003a.mdl" ] = { ru = "Стол 3", en = "Table 003" },
	[ "models/props_c17/FurnitureDrawer002a.mdl" ] = { ru = "Тумба 2", en = "Drawer Cabinet 002" },
	[ "models/props_c17/FurnitureDrawer001a.mdl" ] = { ru = "Тумба 1", en = "Drawer Cabinet 001" },
	[ "models/props_c17/FurnitureShelf001a.mdl" ] = { ru = "Полка 1", en = "Shelf 001" },
	[ "models/props_wasteland/kitchen_shelf001a.mdl" ] = { ru = "Кухонная полка 1", en = "Kitchen Shelf 001" },
	[ "models/props_wasteland/kitchen_shelf002a.mdl" ] = { ru = "Кухонная полка 2", en = "Kitchen Shelf 002" },
	[ "models/props_junk/wood_crate001a.mdl" ] = { ru = "Деревянный ящик 1", en = "Wooden Crate 001" },
	[ "models/props_junk/wood_crate002a.mdl" ] = { ru = "Деревянный ящик 2", en = "Wooden Crate 002" },
	[ "models/props_debris/metal_panel02a.mdl" ] = { ru = "Металлическая панель 2", en = "Metal Panel 02A" },
	[ "models/props_debris/metal_panel01a.mdl" ] = { ru = "Металлическая панель 1", en = "Metal Panel 01A" }
}
local xdebc_PlankGroupNames = {
	[ "Wood boards" ] = { ru = "Деревянные доски", en = "Wood Boards" },
	[ "Wood construction" ] = { ru = "Деревянные конструкции", en = "Wood Construction" },
	[ "Fences" ] = { ru = "Заборы", en = "Fences" },
	[ "Furniture" ] = { ru = "Мебель", en = "Furniture" },
	[ "Crates" ] = { ru = "Ящики", en = "Crates" },
	[ "Metal panels" ] = { ru = "Металлические панели", en = "Metal Panels" }
}

local function xdebc_GetLocalizedText( text )
	return text and text[ XDEBC_Language == "ru" and "ru" or "en" ] or ""
end

local function xdebc_Text( russian, english )
	return XDEBC_Language == "ru" and russian or english
end

local function xdebc_GetPlankName( index )
	local model = xdebc_Planks[ index ] and xdebc_Planks[ index ][ 1 ]
	local name = xdebc_GetLocalizedText( xdebc_PlankNames[ model ] )
	if name != "" then return name end
	return model and string.NiceName( string.GetFileFromFilename( model ):gsub( "%.mdl$", "" ) ) or "Unknown"
end

local function xdebc_GetPlankGroupName( group )
	local name = xdebc_GetLocalizedText( xdebc_PlankGroupNames[ group ] )
	return name != "" and name or group
end

local function xdebc_IsMetalBarricade( source )
	if IsValid( source ) and source:GetNWBool( "XDEBC_Nail" ) then return true end
	local model = isstring( source ) and source or ( IsValid( source ) and source:GetModel() or "" )
	model = string.lower( model or "" )
	return string.find( model, "metal_panel", 1, true ) != nil
		or string.find( model, "fence", 1, true ) != nil
end

local function xdebc_GetMaterialSound( source, woodSound, metalSound )
	return xdebc_IsMetalBarricade( source ) and metalSound or woodSound
end

local function xdebc_PlayMaterialEffect( source, pos, normal )
	local eff = EffectData()
	eff:SetOrigin( pos )
	eff:SetNormal( normal or vector_up )
	eff:SetMagnitude( 1 )
	eff:SetRadius( 2 )
	eff:SetScale( 2 )
	util.Effect( xdebc_IsMetalBarricade( source ) and "Sparks" or "Dust", eff )
end

-- These are hard limits. Convars may reinforce a barricade, but never above
-- these values.
local XDEBC_PLANK_HARD_MAX = 5000
local XDEBC_NAIL_HARD_MAX = 100
local XDEBC_MATERIAL_COST = XDEBC_BARRICADE_MATERIAL_COST or 5
local XDEBC_NAIL_COST = XDEBC_BARRICADE_NAIL_COST or 1
local XDEBC_FLOOR_NORMAL_MIN = 0.7
local XDEBC_ModelBoundsCache = {}

local function xdebc_IsFloorSurface( tr )
	return tr.Hit and tr.HitNormal.z >= XDEBC_FLOOR_NORMAL_MIN
end

-- Nail placement follows the player's aim, matching the original weapon. This
-- allows the spike to be driven upward, downward or sideways into a prop.
function xdebc_GetModelBounds( model )
	if XDEBC_ModelBoundsCache[ model ] then
		local bounds = XDEBC_ModelBoundsCache[ model ]
		return bounds[ 1 ], bounds[ 2 ]
	end
	if !SERVER then return nil end

	local probe = ents.Create( "prop_dynamic" )
	if !IsValid( probe ) then return nil end
	probe:SetModel( model )
	probe:Spawn()
	probe:Activate()
	local mins, maxs = probe:GetModelBounds()
	probe:Remove()
	if !mins or !maxs then return nil end

	XDEBC_ModelBoundsCache[ model ] = { mins, maxs }
	return mins, maxs
end

local function xdebc_GetModelPlacementBounds( model, ang )
	local mins, maxs = xdebc_GetModelBounds( model )
	if !mins or !maxs then return nil end
	local lowest, radius = math.huge, 0
	for _, x in ipairs( { mins.x, maxs.x } ) do
		for _, y in ipairs( { mins.y, maxs.y } ) do
			for _, z in ipairs( { mins.z, maxs.z } ) do
				local offset = ang:Forward()*x +ang:Right()*y +ang:Up()*z
				lowest = math.min( lowest, offset.z )
				radius = math.max( radius, math.sqrt( offset.x*offset.x +offset.y*offset.y ) )
			end
		end
	end
	return -lowest, radius
end

local function xdebc_IsStrongBuild(model)
    model = string.lower(model or "")
    return model == "models/props_c17/fence01a.mdl" or model == "models/props_c17/fence01b.mdl"
        or model == "models/props_c17/fence03a.mdl" or model == "models/props_debris/metal_panel01a.mdl"
        or model == "models/props_debris/metal_panel02a.mdl"
end
local function xdebc_BuildCost(tab)
    return tab and xdebc_IsStrongBuild(tab[1]) and 10 or XDEBC_MATERIAL_COST
end

local function xdebc_GetHardMaxHealth( ent )
	if !IsValid( ent ) then return 0 end
    if ent:GetNWBool("XDEBC_Plank") and xdebc_IsStrongBuild(ent:GetModel()) then return 200 end
	if ent:GetNWBool( "XDEBC_Nail" ) then return XDEBC_NAIL_HARD_MAX end
	if ent:GetNWBool( "XDEBC_Plank" ) or ent:GetNWBool( "XDEBC_NailedProp" ) or ent.XDE_BCEnt != nil then return XDEBC_PLANK_HARD_MAX end
	return 0
end

-- Replicated server convars may not exist on the client during the first HUD
-- frame (before the server has sent them). Always use the normal defaults in
-- that short window instead of indexing a nil convar.
local function xdebc_GetConVarNumber( name, default )
	local cvar = GetConVar( name )
	return cvar and cvar:GetFloat() or default
end

local function xdebc_GetConfiguredMaxHealth( ent )
	if !IsValid( ent ) then return 0 end
	local maxHealth
	local networkedMaxHealth = ent:GetNWInt( "XDEBC_MP", 0 )
	if networkedMaxHealth > 0 then
		-- Health/MaxHealth of prop_physics is not reliably networked to every
		-- client. XDEBC_MP is the authoritative value for barricade repairs.
		maxHealth = networkedMaxHealth
	else
	if ent:GetNWBool( "XDEBC_Nail" ) then
		maxHealth = math.ceil( ent:GetMaxHealth()*math.max( 1, xdebc_GetConVarNumber( "xdebc_nailhp", 5 ) ) )
	elseif ent:GetNWBool( "XDEBC_Plank" ) or ent:GetNWBool( "XDEBC_NailedProp" ) or ent.XDE_BCEnt != nil then
		maxHealth = math.ceil( xdebc_GetConVarNumber( "xdebc_plankhp", 100 ) )
	else
		maxHealth = math.ceil( ent:GetMaxHealth()*math.max( 1, xdebc_GetConVarNumber( "xdebc_hp", 10 ) ) )
	end
	end
	local hardMax = xdebc_GetHardMaxHealth( ent )
	return hardMax > 0 and math.min( maxHealth, hardMax ) or maxHealth
end

local function xdebc_GetNetworkedHealth( ent )
	if !IsValid( ent ) then return 0, 0, false end
	local hp, maxHealth = ent:GetNWInt( "XDEBC_HP", 0 ), ent:GetNWInt( "XDEBC_MP", 0 )
	if hp > 0 and maxHealth > 0 then return hp, maxHealth, true end
	return ent:Health(), ent:GetMaxHealth(), false
end

local function xdebc_GetDisplayHealth( ent )
	if !IsValid( ent ) then return 0, 0 end
	local hp, maxHealth = xdebc_GetNetworkedHealth( ent )
	local hardMax = xdebc_GetHardMaxHealth( ent )
	if hardMax > 0 then
		hp = math.min( hp, hardMax )
		maxHealth = math.min( maxHealth, hardMax )
	end
	return hp, maxHealth
end

local function xdebc_GetBarricadeDisplayTarget( ent )
	if !IsValid( ent ) or !ent:GetNWBool( "XDEBC_BarricadeBlocker" ) then return ent end
	local board = ent:GetNWEntity( "XDEBC_BarricadeOwner" )
	return IsValid( board ) and board or ent
end

local function xdebc_GetPlayerResource( ply, resource )
	if isfunction( XDEBC_GetPlayerResource ) then
		return XDEBC_GetPlayerResource( ply, resource )
	end
	return 0
end

local function xdebc_HasInfiniteResources()
	local cvar = GetConVar( "xdebc_infinite_resources" )
	return cvar and cvar:GetBool() or false
end

local function xdebc_TakePlayerResource( ply, resource, amount )
	if xdebc_HasInfiniteResources() and ( resource == "Materials" or resource == "Nails" ) then
		return true
	end
	if isfunction( XDEBC_TakePlayerResource ) then
		return XDEBC_TakePlayerResource( ply, resource, amount )
	end
	return false
end

local function xdebc_AddPlayerResource( ply, resource, amount )
	if isfunction( XDEBC_AddPlayerResource ) then
		return XDEBC_AddPlayerResource( ply, resource, amount )
	end
	return 0
end

local function xdebc_RefundNail( nail )
	if !IsValid( nail ) or nail.XDEBC_NailRefunded then return 0 end
	if !nail.XDEBC_NailWasPlaced and !nail:GetNWBool( "XDEBC_Nail" )
	and !nail:GetNWBool( "XDEBC_NailResourcePaid" ) then return 0 end
	if nail.XDEBC_NailResourceFree or nail:GetNWBool( "XDEBC_NailResourceFree" ) then return 0 end

	nail.XDEBC_NailRefunded = true
	local owner = nail.XDEBC_BuilderOwner
	if !IsValid( owner ) then owner = nail:GetOwner() end
	if !IsValid( owner ) then return 0 end
	return xdebc_AddPlayerResource( owner, "Nails", XDEBC_NAIL_COST )
end

local function xdebc_TraceFilter( owner )
	return function( ent )
		if ent == owner then return false end
		if IsValid( ent ) and ( ent.XDEBC_BarricadeBlocker == true or ent:GetNWBool( "XDEBC_BarricadeBlocker" ) ) then
			return false
		end
		return true
	end
end

if SERVER then
	local function xdebc_IsOwnedBy( ent, ply )
		return IsValid( ent ) and ( ent.XDEBC_BuilderOwner == ply or ent:GetOwner() == ply )
	end

	function xdebc_CountOwnedBarricades( ply )
		local count = 0
		for ent in pairs( XDEBC_ActiveBarricades ) do
			if !IsValid( ent ) then
				XDEBC_ActiveBarricades[ ent ] = nil
			elseif ent:GetNWBool( "XDEBC_Plank" ) and xdebc_IsOwnedBy( ent, ply ) then
				count = count +1
			end
		end
		return count
	end

	function xdebc_CountOwnedNails( ply )
		local count = 0
		for ent in pairs( XDEBC_ActiveNails ) do
			if !IsValid( ent ) then
				XDEBC_ActiveNails[ ent ] = nil
			elseif ent:GetNWBool( "XDEBC_Nail" ) and xdebc_IsOwnedBy( ent, ply ) then
				count = count +1
			end
		end
		return count
	end

    local function xdebc_SalvageWood(ent, ply)
        if not IsValid(ent) or not IsValid(ply) or ent.XDEBC_Salvaged then return false end
        if ent:GetNWBool("XDEBC_Plank") or ent:GetNWBool("XDEBC_Nail") then return false end
        local class = ent:GetClass()
        if class ~= "prop_physics" and class ~= "prop_physics_multiplayer" and class ~= "func_physbox" then return false end
        local phys = ent:GetPhysicsObject()
        if not IsValid(phys) or not string.find(string.lower(phys:GetMaterial() or ""), "wood", 1, true) then return false end
        local hp = ent:Health() > 0 and ent:Health() or 100
        local maximum = math.max(ent:GetMaxHealth(), hp)
        hp = math.max(0, hp - 20)
        ent:SetHealth(hp)
        ent:SetNWInt("XDEBC_HP", hp)
        ent:SetNWInt("XDEBC_MP", maximum)
        if hp == 0 then
            ent.XDEBC_Salvaged = true
            xdebc_AddPlayerResource(ply, "Materials", 5)
            ent:Remove()
        end
        return true
    end
    XDEBC_SalvageWood = xdebc_SalvageWood

    function xdebc_AssemblePlank(ent, builder)
        if not IsValid(ent) or not ent:GetNWBool("XDEBC_Building") then return false end
        if ent.XDEBC_BuildExpires and CurTime() >= ent.XDEBC_BuildExpires then
            ent:Remove()
            return true
        end
        if ent.XDEBC_BuilderOwner ~= builder and not builder:IsAdmin() then return true end
        local maximum = ent:GetNWInt("XDEBC_MP", ent:GetMaxHealth())
        local hp = math.min(maximum, ent:Health() + 20)
        if hp >= maximum then
            local cost = ent.XDEBC_BuildCost or XDEBC_MATERIAL_COST
            if not xdebc_TakePlayerResource(builder, "Materials", cost) then
                builder:ChatPrint("You need " .. cost .. " materials to finish this barricade.")
                return true
            end
            ent.XDEBC_MaterialsPaid = cost
            ent.XDEBC_PaidBy = builder
            ent:SetNWBool("XDEBC_Building", false)
            ent:SetMaterial(ent.XDEBC_OriginalMaterial or "")
            ent:SetColor(ent.XDEBC_OriginalColor or Color(255, 255, 255, 255))
            xdebc_ConfigurePlankCollision(ent)
            xdebc_CreatePlankBlocker(ent)
            xdebc_RefreshPlankBlocker(ent)
            ent:CollisionRulesChanged()
        end
        ent:SetHealth(hp)
        ent:SetNWInt("XDEBC_HP", hp)
        return true
    end

    function xdebc_DismantlePlank(ent, remover)
        if not IsValid(ent) or not ent:GetNWBool("XDEBC_Plank") then return false end
        if not IsValid(remover) or not remover:IsPlayer() then return false end
        local owner = ent.XDEBC_BuilderOwner
        if not IsValid(owner) then owner = ent:GetOwner() end
        if not IsValid(owner) or (owner ~= remover and not remover:IsAdmin()) then return true end
        local hp = math.max(0, ent:Health() - 20)
        ent:SetHealth(hp)
        ent:SetNWInt("XDEBC_HP", hp)
        if hp == 0 then
            -- Unfinished placements were never paid for and cannot refund materials.
            if not ent:GetNWBool("XDEBC_Building") then
                local paid = ent.XDEBC_MaterialsPaid
                if paid == nil then paid = XDEBC_MATERIAL_COST end -- older completed props
                local recipient = IsValid(ent.XDEBC_PaidBy) and ent.XDEBC_PaidBy or owner
                xdebc_AddPlayerResource(recipient, "Materials", math.min(5, paid))
            end
            ent:Remove()
        end
        return true
    end

end

AddCSLuaFile()

SWEP.PrintName		= "#xdebc.Weapon"
SWEP.Author 		= "LemonCola3424, garikdev"
SWEP.Purpose 		= "#xdebc.Purpose"
SWEP.Instructions	= "#xdebc.Instruct"
SWEP.Category 		= "#xdebc.Category"

SWEP.ViewModelFOV	= 70
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/weapons/c_models/c_frying_pan/c_haming_pan.mdl"
SWEP.WorldModel		= "models/weapons/w_barricadeswep.mdl"
SWEP.Spawnable		= true
SWEP.AdminOnly		= false

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "None"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= true
SWEP.Secondary.Ammo			= "None"

SWEP.Weight					= 0
SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false
SWEP.RightOnce 				= false
SWEP.ReloadOnce 			= false

if SERVER then
	util.AddNetworkString( "xdebc_S2C_Gesture" )
	util.AddNetworkString( "xdebc_S2C_Menu" )
	util.AddNetworkString( "xdebc_C2S_Menu" )
	util.AddNetworkString( "xdebc_C2S_Model" )
	util.AddNetworkString( "xdebc_C2S_Finish" )
	util.AddNetworkString( "xdebc_C2S_Settings" )
	util.AddNetworkString( "xdebc_C2S_ResetSettings" )

	local XDEBC_Settings = {
		[ 1 ] = { "xdebc_materialcap", 1, 200 },
		[ 2 ] = { "xdebc_nailcap", 1, 200 },
		[ 3 ] = { "xdebc_maxbarricades", 1, 100 },
		[ 4 ] = { "xdebc_maxnails", 1, 200 },
		[ 5 ] = { "xdebc_plankhp", 1, 5000 },
		[ 6 ] = { "xdebc_repairamount", 1, 100 },
		[ 7 ] = { "xdebc_nailhp", 1, 10 },
		[ 8 ] = { "xdebc_npcdamage", 1, 100 },
		[ 9 ] = { "xdebc_infinite_resources", 0, 1 },
		[ 10 ] = { "xdebc_crate_materials", 0, 200 },
		[ 11 ] = { "xdebc_crate_nails", 0, 100 }
	}
	local XDEBC_DefaultSettings = { 40, 50, 12, 50, 100, 20, 5, 10, 0, 20, 8 }

	local function xdebc_GetActiveWeaponInMenu( ply )
		local wep = IsValid( ply ) and ply:GetActiveWeapon()
		if !IsValid( wep ) or wep:GetClass() != "weapon_xdebarricade" or !wep:GetXDE_Menu() then return nil end
		return wep
	end

	net.Receive( "xdebc_C2S_Settings", function( len, ply )
		if !IsValid( ply ) or !ply:IsPlayer() or !ply:IsAdmin() or len != 36 then return end
		local settingID = net.ReadUInt( 4 )
		local setting = XDEBC_Settings[ settingID ]
		if !setting then return end
		local rawValue = net.ReadFloat()
		if rawValue != rawValue or rawValue == math.huge or rawValue == -math.huge then return end
		local value = math.Clamp( math.Round( rawValue ), setting[ 2 ], setting[ 3 ] )
		local cvar = GetConVar( setting[ 1 ] )
		if !cvar then return end
		cvar:SetInt( value )
		if settingID == 1 or settingID == 2 then
			local resource = settingID == 1 and "Materials" or "Nails"
			for _, target in ipairs( player.GetAll() ) do
				XDEBC_SetPlayerResource( target, resource, XDEBC_GetPlayerResource( target, resource ) )
			end
		end
	end )

	net.Receive( "xdebc_C2S_ResetSettings", function( len, ply )
		if !IsValid( ply ) or !ply:IsPlayer() or !ply:IsAdmin() or len != 0 then return end

		for settingID, defaultValue in ipairs( XDEBC_DefaultSettings ) do
			local setting = XDEBC_Settings[ settingID ]
			local cvar = setting and GetConVar( setting[ 1 ] )
			if cvar then
				cvar:SetInt( math.Clamp( defaultValue, setting[ 2 ], setting[ 3 ] ) )
			end
		end

		for _, target in ipairs( player.GetAll() ) do
			XDEBC_SetPlayerResource( target, "Materials", XDEBC_GetPlayerResource( target, "Materials" ) )
			XDEBC_SetPlayerResource( target, "Nails", XDEBC_GetPlayerResource( target, "Nails" ) )
		end
	end )

	-- VJ-BASE must use its damage path for barricade boards, never its prop
	-- pushing path. OnlyDamage still lets VJ deal melee damage to the board.
	local function xdebc_SetVJDamageOnly( ent )
		if !IsValid( ent ) or !ent:IsNPC() then return end
		if ent.IsVJBaseSNPC != true then return end
		ent.PropInteraction = "OnlyDamage"
	end

	hook.Add( "OnEntityCreated", "xdebc_vj_barricade_damage_only", function( ent )
		timer.Simple( 0.1, function()
			xdebc_SetVJDamageOnly( ent )
		end )
	end )

	hook.Add( "InitPostEntity", "xdebc_vj_barricade_damage_only_existing", function()
		for _, ent in ipairs( ents.GetAll() ) do
			xdebc_SetVJDamageOnly( ent )
		end
	end )

	local XDEBC_BLOCKER_VERSION = 2
	local XDEBC_NextBlockerSweep = 0

	local function xdebc_RegisterBarricade( ent )
		if !IsValid( ent ) or !ent:GetNWBool( "XDEBC_Plank" ) then return end
		if XDEBC_ActiveBarricades[ ent ] then return end
		XDEBC_ActiveBarricades[ ent ] = true
		ent:CallOnRemove( "XDEBC_UnregisterBarricade", function( removed )
			XDEBC_ActiveBarricades[ removed ] = nil
		end )
	end

	local function xdebc_RegisterNail( ent )
		if !IsValid( ent ) or !ent:GetNWBool( "XDEBC_Nail" ) then return end
		if XDEBC_ActiveNails[ ent ] then return end
		XDEBC_ActiveNails[ ent ] = true
		ent:CallOnRemove( "XDEBC_UnregisterNail", function( removed )
			XDEBC_ActiveNails[ removed ] = nil
		end )
	end

	local function xdebc_AnglesDiffer( first, second )
		if !first or !second then return true end
		return math.abs( math.AngleDifference( first.p, second.p ) ) > 0.05
			or math.abs( math.AngleDifference( first.y, second.y ) ) > 0.05
			or math.abs( math.AngleDifference( first.r, second.r ) ) > 0.05
	end

	local function xdebc_GetPlankBlocker( ent )
		if !IsValid( ent ) then return nil end
		local blocker = ent.XDEBC_BarricadeBlocker
		if !isentity( blocker ) or !IsValid( blocker ) then return nil end
		return blocker
	end

	-- Keep both the networked Entity transform and its VPhysics transform in
	-- sync. SetAngles alone is not reliable for a frozen SOLID_VPHYSICS entity.
	local function xdebc_SyncPlankBlocker( ent, blocker )
		if !IsValid( ent ) or !IsValid( blocker ) then return false end

		local pos, ang = ent:GetPos(), ent:GetAngles()
		blocker:SetPos( pos )
		blocker:SetAngles( ang )

		local phys = blocker:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetPos( pos )
			phys:SetAngles( ang )
			phys:EnableMotion( false )
			phys:Sleep()
		end
		ent.XDEBC_LastBlockerPos = Vector( pos.x, pos.y, pos.z )
		ent.XDEBC_LastBlockerAng = Angle( ang.p, ang.y, ang.r )
		return true
	end

	-- The visible prop stays damageable/traceable. Players and NPCs collide
	-- only with the hidden exact-model copy below, so a parented prop cannot
	-- leave a second, differently rotated collision hull behind.
	function xdebc_ConfigurePlankCollision( ent )
		if !IsValid( ent ) or ent:GetClass() != "prop_physics" then return end
		if !ent:GetNWBool( "XDEBC_Plank" ) then return end

		-- Older barricades were parented to their support. Detach them while
		-- preserving the world transform; otherwise their render transform and
		-- physics transform can use different parent/local angle spaces.
		local pos, ang = ent:GetPos(), ent:GetAngles()
		if IsValid( ent:GetParent() ) then
			ent:SetParent()
			ent:SetPos( pos )
			ent:SetAngles( ang )
		end
		ent.XDEBC_BarricadeSolid = true
		ent:SetNotSolid( false )
		ent:RemoveSolidFlags( FSOLID_NOT_SOLID )
		ent:SetCollisionGroup( COLLISION_GROUP_NONE )
		ent:SetMoveType( MOVETYPE_NONE )
		ent:SetSolid( SOLID_OBB )
		ent:SetCustomCollisionCheck( true )
		ent:CollisionRulesChanged()
	end

	function xdebc_CreatePlankBlocker( ent )
        if IsValid(ent) and ent:GetNWBool("XDEBC_Building") then return end
		if !IsValid( ent ) or ent:GetClass() != "prop_physics" or !ent:GetNWBool( "XDEBC_Plank" ) then return end
		local oldBlocker = ent.XDEBC_BarricadeBlocker
		if isentity( oldBlocker ) and IsValid( oldBlocker ) then
			if oldBlocker:GetNWInt( "XDEBC_BarricadeBlockerVersion", 0 ) >= XDEBC_BLOCKER_VERSION
			and oldBlocker:GetNWBool( "XDEBC_BarricadeBlocker" )
			and oldBlocker:GetModel() == ent:GetModel() then
				xdebc_SyncPlankBlocker( ent, oldBlocker )
				return oldBlocker
			end
			oldBlocker:Remove()
		end
		ent.XDEBC_BarricadeBlocker = nil

		local blocker = ents.Create( "prop_physics" )
		if !IsValid( blocker ) then return end
		-- Use the same model instead of a generic box. This preserves the
		-- authored origin, center and collision shape for every barricade model.
		blocker:SetModel( ent:GetModel() )
		blocker:SetPos( ent:GetPos() )
		blocker:SetAngles( ent:GetAngles() )
		blocker:Spawn()
		blocker:Activate()
		local phys = blocker:GetPhysicsObject()
		if !IsValid( phys ) then
			blocker:Remove()
			return
		end
		blocker:SetNoDraw( true )
		blocker:RemoveSolidFlags( FSOLID_NOT_SOLID )
		blocker:SetNotSolid( false )
		blocker:SetMoveType( MOVETYPE_VPHYSICS )
		blocker:SetSolid( SOLID_VPHYSICS )
		blocker:SetCollisionGroup( COLLISION_GROUP_NONE )
		blocker.XDEBC_BarricadeBlocker = true
		blocker:SetNWBool( "XDEBC_BarricadeBlocker", true )
		blocker:SetNWInt( "XDEBC_BarricadeBlockerVersion", XDEBC_BLOCKER_VERSION )
		blocker.VJ_ID_Prop = false
		blocker.VJ_ID_Attackable = false
		blocker.VJ_ID_Destructible = false
		blocker.XDEBC_BarricadeOwner = ent
		blocker:SetNWEntity( "XDEBC_BarricadeOwner", ent )
		blocker:SetCustomCollisionCheck( true )
		blocker:CollisionRulesChanged()
		xdebc_SyncPlankBlocker( ent, blocker )
		ent.XDEBC_BarricadeBlocker = blocker
		ent:DeleteOnRemove( blocker )
		return blocker
	end

	function xdebc_RefreshPlankBlocker( ent )
        if IsValid(ent) and ent:GetNWBool("XDEBC_Building") then return end
		if !IsValid( ent ) then return end
		xdebc_RegisterBarricade( ent )
		local blocker = xdebc_GetPlankBlocker( ent )
		if !IsValid( blocker )
		or blocker:GetNWInt( "XDEBC_BarricadeBlockerVersion", 0 ) < XDEBC_BLOCKER_VERSION
		or !blocker:GetNWBool( "XDEBC_BarricadeBlocker" )
		or blocker:GetModel() != ent:GetModel() then
			blocker = xdebc_CreatePlankBlocker( ent )
		end
		if !IsValid( blocker ) then return end
		blocker:SetParent()
		blocker:SetNotSolid( false )
		blocker:RemoveSolidFlags( FSOLID_NOT_SOLID )
		blocker:SetMoveType( MOVETYPE_VPHYSICS )
		blocker:SetSolid( SOLID_VPHYSICS )
		blocker:SetCollisionGroup( COLLISION_GROUP_NONE )
		blocker.XDEBC_BarricadeOwner = ent
		blocker:SetNWEntity( "XDEBC_BarricadeOwner", ent )
		blocker:SetCustomCollisionCheck( true )
		blocker:CollisionRulesChanged()
		xdebc_SyncPlankBlocker( ent, blocker )
	end

	hook.Add( "Think", "xdebc_sync_barricade_blockers", function()
		if XDEBC_NextBlockerSweep > CurTime() then return end
		XDEBC_NextBlockerSweep = CurTime() +0.25
		for ent in pairs( XDEBC_ActiveBarricades ) do
			if !IsValid( ent ) or !ent:GetNWBool( "XDEBC_Plank" ) then
				XDEBC_ActiveBarricades[ ent ] = nil
				continue
			end

			local blocker = xdebc_GetPlankBlocker( ent )
			if !IsValid( blocker )
			or blocker:GetNWInt( "XDEBC_BarricadeBlockerVersion", 0 ) < XDEBC_BLOCKER_VERSION
			or !blocker:GetNWBool( "XDEBC_BarricadeBlocker" )
			or blocker:GetModel() != ent:GetModel() then
				if ( ent.XDEBC_NextBlockerRepair or 0 ) <= CurTime() then
					ent.XDEBC_NextBlockerRepair = CurTime() +1
					xdebc_RefreshPlankBlocker( ent )
				end
				continue
			end

			local pos, ang = ent:GetPos(), ent:GetAngles()
			local transformChanged = not ent.XDEBC_LastBlockerPos
				or ent.XDEBC_LastBlockerPos:DistToSqr( pos ) > 0.01
				or xdebc_AnglesDiffer( ent.XDEBC_LastBlockerAng, ang )
			local blockerDrifted = blocker:GetPos():DistToSqr( pos ) > 0.01
				or xdebc_AnglesDiffer( blocker:GetAngles(), ang )
			if transformChanged or blockerDrifted then
				xdebc_SyncPlankBlocker( ent, blocker )
			end
		end
	end )

	hook.Add( "ShouldCollide", "xdebc_board_collision", function( ent1, ent2 )
        if (IsValid(ent1) and ent1:GetNWBool("XDEBC_Building"))
            or (IsValid(ent2) and ent2:GetNWBool("XDEBC_Building")) then return false end
		local board, other
		if IsValid( ent1 ) and ( ent1.XDEBC_BarricadeSolid == true or ent1.XDEBC_BarricadeBlocker == true or ent1:GetNWBool( "XDEBC_BarricadeBlocker" ) ) then
			board, other = ent1, ent2
		elseif IsValid( ent2 ) and ( ent2.XDEBC_BarricadeSolid == true or ent2.XDEBC_BarricadeBlocker == true or ent2:GetNWBool( "XDEBC_BarricadeBlocker" ) ) then
			board, other = ent2, ent1
		end
		if !IsValid( board ) or !IsValid( other ) then return end
		local isBlocker = board.XDEBC_BarricadeBlocker == true or board:GetNWBool( "XDEBC_BarricadeBlocker" )
		if ( isBlocker and other == board.XDEBC_BarricadeOwner ) or ( !isBlocker and other == board.XDEBC_BarricadeBlocker ) then
			return false
		end
		if other:IsPlayer() or other:IsNPC() or other:IsNextBot() then
			-- The hidden oriented blocker is the only player/NPC collision
			-- volume. The visible prop remains traceable and damageable without
			-- creating a second overlapping hull that can trap players.
			return isBlocker
		end
	end )

	-- Engine entities such as prop_physics reliably expose their damage through
	-- OnTakeDamage. Forward it into the common barricade damage hook as well.
	local function xdebc_AddBarricadeDamageCallback( ent )
		if !IsValid( ent ) or ent:GetNWBool( "XDEBC_DamageCallback" ) then return end
		ent:SetNWBool( "XDEBC_DamageCallback", true )
		ent:AddCallback( "OnTakeDamage", function( target, dmg )
			if IsValid( target ) and dmg:GetDamage() > 0 then
				hook.Run( "EntityTakeDamage", target, dmg )
			end
		end )
	end

	function xdebc_MarkPlankDestructible( ent )
		if !IsValid( ent ) or ent:GetClass() != "prop_physics" then return end
		local isPlank = ent:GetNWBool( "XDEBC_Plank" )
		local isNail = ent:GetNWBool( "XDEBC_Nail" )
		local isNailedProp = ent:GetNWBool( "XDEBC_NailedProp" )
		if !isPlank and !isNail and !isNailedProp then return end
		if isPlank then
			xdebc_RegisterBarricade( ent )
		elseif isNail then
			xdebc_RegisterNail( ent )
		end
		-- Keep the standard VJ prop marker. Removing Attackable makes VJ
		-- ignore the board instead of damaging it.
		ent.VJ_ID_Prop = true
		ent.VJ_ID_Attackable = true
		ent.VJ_ID_Destructible = true
		local hardMax = xdebc_GetHardMaxHealth( ent )
		if ent:GetMaxHealth() > hardMax then
			ent:SetMaxHealth( hardMax )
		end
		if ent:Health() > hardMax then
			ent:SetHealth( hardMax )
		end
		if ent:GetNWInt( "XDEBC_MP", 0 ) > hardMax then
			ent:SetNWInt( "XDEBC_MP", hardMax )
		end
		if isPlank then
			xdebc_ConfigurePlankCollision( ent )
			xdebc_CreatePlankBlocker( ent )
			xdebc_RefreshPlankBlocker( ent )
		elseif isNailedProp then
			local nailedMax = math.min( XDEBC_PLANK_HARD_MAX, GetConVar( "xdebc_plankhp" ):GetInt() )
			if ent:GetMaxHealth() <= 0 then ent:SetMaxHealth( nailedMax ) end
			if ent:Health() <= 0 then ent:SetHealth( nailedMax ) end
			ent:SetNWInt( "XDEBC_HP", math.min( ent:Health(), nailedMax ) )
			ent:SetNWInt( "XDEBC_MP", nailedMax )
		end
		xdebc_AddBarricadeDamageCallback( ent )
		if isPlank then
			xdebc_AddBarricadeDamageCallback( xdebc_GetPlankBlocker( ent ) )
		end
	end

	hook.Add( "OnEntityCreated", "xdebc_mark_vj_destructible", function( ent )
		timer.Simple( 0, function()
			xdebc_MarkPlankDestructible( ent )
		end )
	end )

	hook.Add( "InitPostEntity", "xdebc_mark_existing_vj_destructible", function()
		for _, ent in ipairs( ents.FindByClass( "prop_physics" ) ) do
			xdebc_MarkPlankDestructible( ent )
		end
	end )

	-- Rebuild every service collider once after the addon is loaded. Entity Lua
	-- fields are lost on a script reload, so an old hidden prop may no longer
	-- be linked to its board even though it still collides in the world.
	timer.Simple( 0, function()
		for _, ent in ipairs( ents.FindByClass( "prop_physics" ) ) do
			if ent:GetNWBool( "XDEBC_BarricadeBlocker" ) then
				ent:Remove()
			end
		end
		for _, ent in ipairs( ents.FindByClass( "prop_physics" ) ) do
			xdebc_MarkPlankDestructible( ent )
		end
	end )
	
	function xdebc_Unfreeze( ent, removeNails )
		if !IsValid( ent ) or !IsValid( ent:GetPhysicsObject() ) then return end
		if !istable( ent.XDE_Planks ) then return end
		for k, v in pairs( ent.XDE_Planks ) do
			if !IsValid( v ) then continue end
			if removeNails and v:GetNWBool( "XDEBC_Nail" ) then
				xdebc_RefundNail( v )
				v:Remove()
				continue
			end
			if !v:IsInWorld() then
				xdebc_RefundNail( v )
				v:Remove()
				continue
			end
			if true then
				v:SetParent()
				if IsValid( v:GetPhysicsObject() ) then
					v:GetPhysicsObject():Wake()
					v:GetPhysicsObject():EnableMotion( true )
					xdebc_Unfreeze( v, removeNails )
				end
			end
		end
		ent.XDE_Planks = nil
	end

	function xdebc_ProtectSupport( ent )
		if !IsValid( ent ) or ent:IsWorld() or ent:IsEFlagSet( EFL_NO_DAMAGE_FORCES ) then return end
		ent:AddEFlags( EFL_NO_DAMAGE_FORCES )
		ent.XDEBC_AddedNoDamageForces = true
	end

	function xdebc_MarkNailedProp( ent, owner )
		if !IsValid( ent ) or ent:IsWorld() then return end
		if ent:GetNWBool( "XDEBC_Plank" ) or ent:GetNWBool( "XDEBC_Nail" ) then return end
		if ent:GetNWBool( "XDEBC_NailedProp" ) then return end

		local maxhp = math.min( XDEBC_PLANK_HARD_MAX, GetConVar( "xdebc_plankhp" ):GetInt() )
		local initialHP = math.min( 100, maxhp )
		ent:SetNWBool( "XDEBC_NailedProp", true )
		ent.XDEBC_NailedPropOwner = owner
		ent.VJ_ID_Prop = true
		ent.VJ_ID_Attackable = true
		ent.VJ_ID_Destructible = true
		ent:SetMaxHealth( maxhp )
		ent:SetHealth( initialHP )
		ent:SetNWInt( "XDEBC_HP", initialHP )
		ent:SetNWInt( "XDEBC_MP", maxhp )
	end

	function xdebc_RestoreSupport( ent, removed )
		if !IsValid( ent ) or !istable( ent.XDE_Planks ) then return end
		for _, part in pairs( ent.XDE_Planks ) do
			if part != removed and IsValid( part ) then return end
		end
		if ent.XDEBC_FrozenByBarricade then
			local phys = ent:GetPhysicsObject()
			if IsValid( phys ) then
				phys:EnableMotion( true )
				phys:Wake()
			end
			ent.XDEBC_FrozenByBarricade = nil
		end
		if ent.XDEBC_AddedNoDamageForces then
			ent:RemoveEFlags( EFL_NO_DAMAGE_FORCES )
			ent.XDEBC_AddedNoDamageForces = nil
		end
	end

	function xdebc_FreezeSupport( ent )
		if !IsValid( ent ) or ent:IsWorld() or ent.XDEBC_FrozenByBarricade then return end
		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) and phys:IsMotionEnabled() then
			phys:EnableMotion( false )
			phys:Sleep()
			ent.XDEBC_FrozenByBarricade = true
		end
	end

	net.Receive( "xdebc_C2S_Finish", function( len, ply )
		if !IsValid( ply ) or !ply:IsPlayer() or len > 0 then return end
		local wep = xdebc_GetActiveWeaponInMenu( ply )
		if !IsValid( wep ) then return end
		local vm = ply:GetViewModel()
		local drawSequence = vm:LookupSequence( "draw" )
		if drawSequence >= 0 then
			vm:SendViewModelMatchingSequence( drawSequence )
			vm:SetPlaybackRate( 1 )
		end
		wep:IdleAnim()
		wep:SetHoldType( "slam" )
		wep:SetNextSecondaryFire( CurTime() +0.2 )
		wep:SetXDE_Menu( false )
	end )

	net.Receive( "xdebc_C2S_Model", function( len, ply )
		if !IsValid( ply ) or !ply:IsPlayer() or len != 32 then return end
		local wep = xdebc_GetActiveWeaponInMenu( ply )
		local rawModelID = net.ReadFloat()
		if rawModelID != rawModelID or rawModelID == math.huge or rawModelID == -math.huge then return end
		local modelID = math.Round( rawModelID )
		if IsValid( wep ) and xdebc_Planks[ modelID ] and wep:GetNextSecondaryFire() <= CurTime() then
			wep:SetXDE_Mode( 3 )
			wep:SetXDE_Model( modelID )
			wep:SetNextSecondaryFire( CurTime() +0.05 )
		end
	end )

	net.Receive( "xdebc_C2S_Menu", function( len, ply )
		if !IsValid( ply ) or !ply:IsPlayer() or len != 32 then return end
		local wep = xdebc_GetActiveWeaponInMenu( ply )
		local rawMode = net.ReadFloat()
		if rawMode != rawMode or rawMode == math.huge or rawMode == -math.huge then return end
		local mode = math.Round( rawMode )
		if IsValid( wep ) and mode >= 0 and mode <= 3 and wep:GetNextSecondaryFire() <= CurTime() then
			wep:SetXDE_Mode( mode )
			wep:SetNextSecondaryFire( CurTime() +0.05 )
		end
	end )

	hook.Add( "EntityTakeDamage", "xdebc_takedmg", function( tar, dmg )
		if !IsValid( tar ) or dmg:GetDamage() <= 0 then return end

		local target = tar
		local attacker = dmg:GetAttacker()
		-- NPCs and bullets can hit the hidden oriented blocker instead of the
		-- visible board. Route that damage to the real barricade plank.
		if tar:GetNWBool( "XDEBC_BarricadeBlocker" ) then
			local owner = tar.XDEBC_BarricadeOwner
			if !IsValid( owner ) then
				owner = tar:GetNWEntity( "XDEBC_BarricadeOwner" )
			end
			if IsValid( owner ) and owner:GetNWBool( "XDEBC_Plank" ) then
				target = owner
			end
		end
		if IsValid( attacker ) and ( attacker:IsNPC() or attacker:IsNextBot() )
		and !tar:GetNWBool( "XDEBC_NailedProp" ) and istable( tar.XDE_Planks ) then
			local hitPos = dmg:GetDamagePosition()
			local closest, closestDist
			for _, part in pairs( tar.XDE_Planks ) do
				if IsValid( part ) and ( part:GetNWBool( "XDEBC_Plank" ) or part.XDE_BCEnt != nil ) then
					local distance = hitPos:DistToSqr( part:WorldSpaceCenter() )
					if !closestDist or distance < closestDist then
						closest, closestDist = part, distance
					end
				end
			end
			if IsValid( closest ) then
				target = closest
			end
		end

		local nail = target:GetNWBool( "XDEBC_Nail" )
		local nailedProp = target:GetNWBool( "XDEBC_NailedProp" )
		local plank = target:GetNWBool( "XDEBC_Plank" ) or nailedProp or target.XDE_BCEnt != nil
		if !nail and !plank then return end
		if tar == dmg:GetAttacker() then return true end
		if target != tar then xdebc_FreezeSupport( tar ) end

		-- Barricade parts should take damage, but never receive the physics impulse
		-- that normally makes prop_physics fly away after an NPC melee hit.
		dmg:SetDamageType( bit.bor( dmg:GetDamageType(), DMG_PREVENT_PHYSICS_FORCE ) )
		dmg:SetDamageForce( vector_origin )
		local tarPhys = tar:GetPhysicsObject()
		if IsValid( tarPhys ) then
			tarPhys:EnableMotion( false )
			tarPhys:Sleep()
			tarPhys:SetVelocityInstantaneous( vector_origin )
			tarPhys:SetAngleVelocityInstantaneous( vector_origin )
		end

		local hardMax = xdebc_GetHardMaxHealth( target )
		if target:GetMaxHealth() > hardMax then
			target:SetMaxHealth( hardMax )
		end
		if target:Health() > hardMax then
			target:SetHealth( hardMax )
		end
		local maxhp = math.min( target:GetNWInt( "XDEBC_MP", 0 ), hardMax )
		if maxhp <= 0 then
			maxhp = math.min( target:GetMaxHealth(), hardMax )
		end
		if maxhp <= 0 then
			maxhp = math.min( nail and 10 or GetConVar( "xdebc_plankhp" ):GetInt(), hardMax )
			target:SetMaxHealth( maxhp )
			target:SetHealth( maxhp )
		end

		local damage = dmg:GetDamage()
		if IsValid( attacker ) and ( attacker:IsNPC() or attacker:IsNextBot() ) then
			damage = math.min( damage, GetConVar( "xdebc_npcdamage" ):GetFloat() )
		end
		target:SetHealth( math.max( 0, target:Health() -damage ) )
		target:SetNWInt( "XDEBC_HP", target:Health() )
		target:SetNWInt( "XDEBC_MP", maxhp )
		dmg:SetDamage( 0 )

		if target:Health() <= 0 then
			if nail then
				xdebc_RefundNail( target )
				target:SetNWBool( "XDEBC_Nail", false )
				target:EmitSound( "Metal_Box.BulletImpact" )
			else
				target:EmitSound( xdebc_GetMaterialSound( target, "xdebarricade.hitplank", "Metal_Box.BulletImpact" ) )
			end
			timer.Simple( 0, function()
				if IsValid( target ) then
					if nailedProp and istable( target.XDE_Planks ) then
						for _, part in pairs( target.XDE_Planks ) do
							if IsValid( part ) then
								xdebc_RefundNail( part )
								part:Remove()
							end
						end
					end
					xdebc_PlayMaterialEffect( target, target:WorldSpaceCenter() -target:GetForward()*2, -target:GetForward() )
					target:Remove()
				end
			end )
		end

		return true
	end )

	hook.Add( "PostEntityTakeDamage", "xdebc_takedmg", function( tar, dmg, act )
		if !act or !IsValid( tar ) or dmg:GetDamage() <= 0 or tar:Health() <= 0 or tar:GetMaxHealth() <= 0 then return end
		local hardMax = xdebc_GetHardMaxHealth( tar )
		if hardMax > 0 then
			if tar:GetMaxHealth() > hardMax then tar:SetMaxHealth( hardMax ) end
			if tar:Health() > hardMax then tar:SetHealth( hardMax ) end
			tar:SetNWInt( "XDEBC_HP", tar:Health() )
			tar:SetNWInt( "XDEBC_MP", math.min( tar:GetNWInt( "XDEBC_MP", tar:GetMaxHealth() ), hardMax ) )
		elseif !tar:IsPlayer() and !tar:IsNPC() and !tar:IsNextBot() then
			tar:SetNWInt( "XDEBC_HP", tar:Health() )
			tar:SetNWInt( "XDEBC_MP", tar:GetMaxHealth() )
		end
	end )
else
	if IsValid( XDEBCMenu ) then XDEBCMenu:Remove() end
	XDEBCMenu = nil

	local function xdebc_FitMenuText( text, font, maxWidth )
		text = tostring( text or "" )
		surface.SetFont( font )
		if surface.GetTextSize( text ) <= maxWidth then return text end

		local suffix = "..."
		local length = utf8 and utf8.len and utf8.len( text ) or #text
		for i = length, 1, -1 do
			local part = utf8 and utf8.sub and utf8.sub( text, 1, i ) or string.sub( text, 1, i )
			if surface.GetTextSize( part..suffix ) <= maxWidth then
				return part..suffix
			end
		end
		return suffix
	end
	net.Receive( "xdebc_S2C_Gesture", function()
		local ent, act = net.ReadEntity(), math.Round( net.ReadFloat() )
		if IsValid( ent ) and ent:GetClass() == "weapon_xdebarricade" and IsValid( ent.Owner )
		and ent.Owner:GetActiveWeapon() == ent then
			ent:DoGesture( act )
		end
	end )

	net.Receive( "xdebc_S2C_Menu", function()
		local ply, mode, mdl = LocalPlayer(), math.Round( net.ReadFloat() ), math.Round( net.ReadFloat() )
		// surface.PlaySound( "common/wpn_hudon.wav" )
		timer.Remove( "xdebc_hidemenu" )
		if IsValid( XDEBCMenu ) then
			local pan = XDEBCMenu
			pan:Show()
			pan:SetAlpha( 1 )
			pan:AlphaTo( 255, 0.1 )
        	pan:SetMouseInputEnabled( true )
        	pan:SetKeyboardInputEnabled( true )
			pan.N_Close = SysTime() +0.15
			pan.N_Mode = mode
			pan.N_Model = mdl
			pan.N_Blur = SysTime()
			return
		end
		XDEBCMenu = vgui.Create( "DFrame" )
		local pan = XDEBCMenu
		pan:SetSize( 900, 650 )
		pan:Center()
		pan:MakePopup()
        pan:SetMouseInputEnabled( true )
        pan:SetKeyboardInputEnabled( true )
		pan:ShowCloseButton( false )
		pan:SetTitle( "" )
		pan:SetAlpha( 1 )
		pan:AlphaTo( 255, 0.2 )

		pan.N_Mode = mode
		pan.N_Model = mdl
		pan.N_Close = SysTime() +0.15
		pan.N_Blur = SysTime()
		pan.N_Delay = SysTime() +0.1

		function pan:Paint( w, h )
			Derma_DrawBackgroundBlur( pan, pan.N_Blur )
			draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 0, 0, 218 ) )
			surface.SetDrawColor( 170, 170, 170, 190 )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			local corner = 18
			surface.DrawRect( 0, 0, corner, 2 )
			surface.DrawRect( 0, 0, 2, corner )
			surface.DrawRect( w -corner, 0, corner, 2 )
			surface.DrawRect( w -2, 0, 2, corner )
			surface.DrawRect( 0, h -2, corner, 2 )
			surface.DrawRect( 0, h -corner, 2, corner )
			surface.DrawRect( w -corner, h -2, corner, 2 )
			surface.DrawRect( w -2, h -corner, 2, corner )
		end
		function pan:Think()
			local ply = LocalPlayer()
			if ( !IsValid( ply ) or !input.IsMouseDown( MOUSE_RIGHT ) or !IsValid( ply:GetActiveWeapon() ) or ply:GetActiveWeapon():GetClass() != "weapon_xdebarricade" )
			and pan.N_Close > 0 and pan.N_Close <= SysTime() then
				pan.N_Close = 0
                pan:AlphaTo( 1, 0.1 )
				pan:SetMouseInputEnabled( false )
				pan:SetKeyboardInputEnabled( false )
				net.Start( "xdebc_C2S_Finish" )
				net.SendToServer()
                timer.Create( "xdebc_hidemenu", 0.15, 1, function()
                    if IsValid( pan ) then pan:Hide() end
                end )
				// surface.PlaySound( "common/wpn_hudoff.wav" )
			end
		end

		local title = pan:Add( "DLabel" )
		title:SetPos( 30, 14 )
		title:SetSize( 700, 28 )
		title:SetText( xdebc_Text( "БАРРИКАДЫ / ВЫБОР КОНСТРУКЦИИ", "BARRICADE / CONSTRUCTION SELECT" ) )
		title:SetFont( "xdebc_Font2" )
		title:SetTextColor( Color( 230, 230, 230 ) )
		title:SetContentAlignment( 4 )

		local subtitle = pan:Add( "DLabel" )
		subtitle:SetPos( 32, 39 )
		subtitle:SetSize( 700, 18 )
		subtitle:SetText( xdebc_Text( "ВЫБЕРИТЕ МАТЕРИАЛ И ТИП ОБЪЕКТА", "SELECT MATERIAL AND OBJECT TYPE" ) )
		subtitle:SetFont( "xdebc_Font3" )
		subtitle:SetTextColor( Color( 145, 145, 145 ) )
		subtitle:SetContentAlignment( 4 )

        for i=1, 3 do
            local but = pan:Add( "DButton" )
            but:SetSize( 210, 58 )
            but:SetPos( 135 +( i -1 )*225, 555 )
            but:SetText( "" )
            but.B_Hover = false
            but.N_Lerp = 0
			but.N_Mode = i-1
			but.N_Clicked = 0
            function but:Paint( w, h )
                but.N_Lerp = Lerp( math.min( 1, FrameTime()*20 ), but.N_Lerp, ( but.B_Hover or but.N_Mode == pan.N_Mode ) and 1 or 0 )
                local ler, sel = but.N_Lerp, ( but.N_Mode == pan.N_Mode )
				local shade = 125 +ler*70
				local col = Color( shade, shade, shade, 255 )
				draw.RoundedBox( 0, 0, 0, w, h, sel and Color( 55, 55, 55, 235 ) or Color( 10, 10, 10, 220 ) )

				if but.N_Clicked > SysTime() then
					local cli = math.Clamp( ( but.N_Clicked-SysTime() )/0.2, 0, 1 )
					surface.SetDrawColor( col.r, col.g, col.b, cli*255 )
					surface.DrawRect( w/2, 0, w/2*( 1-cli ) +1, h )
					surface.DrawRect( w/2 -w/2*( 1-cli ) +1, 0, w/2*( 1-cli ), h )
				end

				surface.SetDrawColor( 0, 0, 0, 240 )
				surface.DrawOutlinedRect( 0, 0, w, h, 1 )
				surface.SetDrawColor( col )
				surface.DrawOutlinedRect( 0, 0, w, h, 1 )
				local c = 12
				surface.DrawRect( 0, 0, c, 2 )
				surface.DrawRect( 0, 0, 2, c )
				surface.DrawRect( w -c, 0, c, 2 )
				surface.DrawRect( w -2, 0, 2, c )
				surface.DrawRect( 0, h -2, c, 2 )
				surface.DrawRect( 0, h -c, 2, c )
				surface.DrawRect( w -c, h -2, c, 2 )
				surface.DrawRect( w -2, h -c, 2, c )

				draw.SimpleTextOutlined( language.GetPhrase( "xdebc.Mode"..but.N_Mode ), "xdebc_Font1", w/2, h/2,
				col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0 ) )
            end

            function but:OnCursorEntered() but.B_Hover = true end
            function but:OnCursorExited() but.B_Hover = false end
            function but:DoClick()
				if pan.N_Mode == but.N_Mode or pan.N_Delay > SysTime() then return end
				but.N_Clicked = SysTime() +0.2
				pan.N_Mode = but.N_Mode
				net.Start( "xdebc_C2S_Menu" )
				net.WriteFloat( but.N_Mode )
				net.SendToServer()
				surface.PlaySound( "weapons/shotgun/shotgun_empty.wav" )
            end
        end

		local scroll = pan:Add( "DScrollPanel" )
		scroll:SetPos( 28, 65 )
		scroll:SetSize( 844, 472 )
		function scroll:Paint( w, h )
			draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 0, 0, 145 ) )
			surface.SetDrawColor( 105, 105, 105, 170 )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		end
		local vbar = scroll:GetVBar()
		vbar:SetWide( 7 )
		vbar.Paint = function( self, w, h )
			draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 0, 0, 130 ) )
		end
		vbar.btnUp.Paint = function() end
		vbar.btnDown.Paint = function() end
		vbar.btnGrip.Paint = function( self, w, h )
			draw.RoundedBox( 0, 1, 0, w -2, h, Color( 145, 145, 145, 210 ) )
		end
		local icons = scroll:Add( "DIconLayout" )
		icons:Dock( TOP )
		icons:SetWide( 820 )
		icons:SetTall( 1800 )
		icons:SetSpaceX( 8 )
		icons:SetSpaceY( 8 )
		function icons:Paint( w, h )
			// surface.SetDrawColor( Color( 0, 0, 0 ) )
			// surface.DrawRect( 0, 0, w, h )
		end
		
		local currentGroup
		for i, v in ipairs( xdebc_Planks ) do
			local groupKey = v[ 6 ] or "Wood boards"
			local group = xdebc_GetPlankGroupName( groupKey )
			if group != currentGroup then
				currentGroup = group
				local header = icons:Add( "DPanel" )
				header:SetSize( 820, 30 )
				header.GroupName = group
				function header:Paint( w, h )
					surface.SetDrawColor( 125, 125, 125, 180 )
					surface.DrawRect( 0, h -1, w, 1 )
					surface.DrawRect( 0, h -4, 5, 3 )
					draw.SimpleText( self.GroupName, "xdebc_Font3", 10, h/2, Color( 185, 185, 185 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				end
			end
			local ww, hh = 190, 132
			local mdl = v[ 1 ]
            local but = icons:Add( "DButton" )
			but:SetSize( ww, hh )
			but:DockPadding( 0, 0, 0, 0 )
			but:DockMargin( 0, 0, 0, 0 )
            // but:SetPos( 12.5 +64*( i <= 4 and i -1 or i -5 ), 50 +( i <= 4 and 0 or 200 ) )
            but:SetText( "" )
			but:SetToolTip( group.." / "..xdebc_GetPlankName( i ) )
            but.B_Hover = false
            but.N_Lerp = 0
			but.N_Model = i
			but.N_Clicked = 0

			but.S_Name = xdebc_GetPlankName( i )
			but.S_DisplayName = xdebc_FitMenuText( but.S_Name, "xdebc_Font3", ww -18 )

            function but:Paint( w, h )
                but.N_Lerp = Lerp( math.min( 1, FrameTime()*20 ), but.N_Lerp, ( but.B_Hover or ( pan.N_Mode == 3 and but.N_Model == pan.N_Model ) ) and 1 or 0 )
                local ler, sel = but.N_Lerp, ( but.N_Model == pan.N_Model and pan.N_Mode == 3 )
				local shade = 125 +ler*70
				local col = Color( shade, shade, shade, 255 )
				draw.RoundedBox( 0, 0, 0, w, h, sel and Color( 55, 55, 55, 235 ) or Color( 10, 10, 10, 220 ) )
				draw.RoundedBox( 0, 7, 7, w -14, h -43, Color( 0, 0, 0, 170 ) )

				if but.N_Clicked > SysTime() then
					local cli = math.Clamp( ( but.N_Clicked-SysTime() )/0.2, 0, 1 )
					surface.SetDrawColor( col.r, col.g, col.b, cli*255 )
					surface.DrawRect( 0, 0, w, h )
				end

				draw.RoundedBox( 0, 4, h -32, w -8, 28, Color( 0, 0, 0, 220 ) )
				surface.SetDrawColor( 0, 0, 0, 240 )
				surface.DrawOutlinedRect( 0, 0, w, h, 1 )
				surface.SetDrawColor( col )
				surface.DrawOutlinedRect( 0, 0, w, h, 1 )
				local c = 11
				surface.DrawRect( 0, 0, c, 2 )
				surface.DrawRect( 0, 0, 2, c )
				surface.DrawRect( w -c, 0, c, 2 )
				surface.DrawRect( w -2, 0, 2, c )
				surface.DrawRect( 0, h -2, c, 2 )
				surface.DrawRect( 0, h -c, 2, c )
				surface.DrawRect( w -c, h -2, c, 2 )
				surface.DrawRect( w -2, h -c, 2, c )

				draw.SimpleTextOutlined( but.S_DisplayName,
					"xdebc_Font3", w/2, h -18,
					col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0 ) )
            end

            function but:OnCursorEntered() but.B_Hover = true end
            function but:OnCursorExited() but.B_Hover = false end
            function but:DoClick()
				if ( pan.N_Mode == 3 and pan.N_Model == but.N_Model ) or pan.N_Delay > SysTime() then return end
				but.N_Clicked = SysTime() +0.2
				pan.N_Model = but.N_Model
				pan.N_Mode = 3
				net.Start( "xdebc_C2S_Model" )
				net.WriteFloat( but.N_Model )
				net.SendToServer()
				surface.PlaySound( "weapons/shotgun/shotgun_empty.wav" )
            end

			local ico = but:Add( "ModelImage" )
			ico:SetPos( ww/2 -32, hh/2 -32 )
			ico:SetSize( 64, 64 )
			ico:SetModel( mdl )
			ico:SetMouseInputEnabled( false )
			ico:SetKeyboardInputEnabled( false )
        end
	end )
end

if CLIENT then
	SWEP.Slot				= 0
	SWEP.SlotPos			= 10
	SWEP.DrawAmmo			= false
	SWEP.DrawCrosshair		= false
	SWEP.UseHands           = true
	SWEP.SwayScale			= 0
	SWEP.BobScale			= 0
	SWEP.BounceWeaponIcon	= false

	SWEP.CrossMove 			= 0
	SWEP.PosFX 				= -1
	SWEP.PosFY 				= -1
	SWEP.HoloModel 			= nil

	function SWEP:GetViewModelPosition( pos, ang )
		pos = pos +ang:Forward()*2 +ang:Right()*1 +ang:Up()*-1.5
		ang:RotateAroundAxis( ang:Right(), -3 )
		ang:RotateAroundAxis( ang:Up(), 2 )
		return pos, ang
	end

	-- Some gamemodes replace GM:PostDrawViewModel and skip the standard hands pass.
	-- Draw the player's normal viewmodel hands from the weapon hook instead.
	function SWEP:ViewModelDrawn( vm )
		local ply = LocalPlayer()
		if !IsValid( ply ) then return end

		local hands = ply:GetHands()
		if !IsValid( hands ) then
			if ( self.XDEBC_NextHandsSetup or 0 ) <= CurTime() then
				self.XDEBC_NextHandsSetup = CurTime() + 1
				ply:SetupHands()
			end
			hands = ply:GetHands()
		end
		if IsValid( hands ) then
			hands:DrawModel()
		end
	end

	function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )
		draw.Text( {
			text = "c",
			pos = { x +wide/2, y +tall/2 },
			font = "xde_Select",
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
			color = Color( 255, 255, 255 )
		} )
		y = y+10
		x = x+10
		wide = wide-20
		self:PrintWeaponInfo( x+wide+20, y +tall*0.95, alpha )
	end

	local Mat = Material( "gui/gradient_up" )

	function SWEP:PrintWeaponInfo( x, y, alpha )
		if self.InfoMarkup == nil then
			local str, title_color, text_color = "", "<color=255,255,255,255>", "<color=200,200,200,255>"
			str = "<font=TargetID>"
			if ( self.Author != "" ) then str = str..title_color..language.GetPhrase( "xdebc.Author" )..": </color>"..text_color..self.Author.."</color>\n" end
			if ( self.Purpose != "" ) then str = str..title_color..language.GetPhrase( "xdebc.Purpose2" )..": </color>"..text_color..language.GetPhrase( self.Purpose ).."</color>\n" end
			if ( self.Instructions != "" ) then str = str..title_color.."\n</color>"..text_color..language.GetPhrase( self.Instructions ).."</color>\n" end
			self.InfoMarkup = markup.Parse( str, 350 )
		end
		local xx, yy, ww, hh = x-6, y-6, 362, self.InfoMarkup:GetHeight() +24
		draw.RoundedBox( 0, xx, yy, ww, hh, Color( 100, 100, 100, 255, alpha ) )
		surface.SetDrawColor( 55, 55, 55, 255 )
		surface.SetMaterial( Mat )
		surface.DrawTexturedRect( xx, yy, ww, hh )
		surface.SetDrawColor( 255, 255, 255, 255 )
		surface.DrawOutlinedRect( xx, yy, ww, hh, 2 )
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawOutlinedRect( xx, yy, ww, hh, 1 )
		self.InfoMarkup:Draw( x + 5, y + 5, nil, nil, alpha )
		self.InfoMarkup = nil
	end 

	function SWEP:DrawResourceHUD()
		local materials = xdebc_GetPlayerResource( LocalPlayer(), "Materials" )
		local nails = xdebc_GetPlayerResource( LocalPlayer(), "Nails" )
		local infinite = xdebc_HasInfiniteResources()
		local materialCap = isfunction( XDEBC_GetResourceCap ) and XDEBC_GetResourceCap( "Materials" ) or XDEBC_MATERIAL_CAP or 40
		local nailCap = isfunction( XDEBC_GetResourceCap ) and XDEBC_GetResourceCap( "Nails" ) or XDEBC_NAIL_CAP or 50
		local right, top = ScrW() -24, 24
		local materialColor = !infinite and materials <= 0 and Color( 255, 0, 0, 255 ) or Color( 255, 255, 255, 255 )
		local nailColor = !infinite and nails <= 0 and Color( 255, 0, 0, 255 ) or Color( 255, 255, 255, 255 )
		local outline = Color( 0, 0, 0, 255 )
		local materialAmount = infinite and "∞" or materials.." / "..materialCap
		local nailAmount = infinite and "∞" or nails.." / "..nailCap
		local materialText = language.GetPhrase( "xdebc.ResourcesMaterials" ).." : "..materialAmount
		local nailText = language.GetPhrase( "xdebc.ResourcesNails" ).." : "..nailAmount

		surface.SetFont( "xdebc_Font2" )
		local materialWidth = surface.GetTextSize( materialText )
		local nailWidth = surface.GetTextSize( nailText )
		local left = right -math.max( materialWidth, nailWidth ) -12
		local boxRight, boxTop = right +4, top -6
		local boxBottom, corner = top +58, 13
		local cornerColor = !infinite and ( materials <= 0 or nails <= 0 ) and Color( 255, 0, 0, 255 ) or Color( 255, 255, 255, 255 )

		local function HudLine( x, y, w, h )
			surface.SetDrawColor( 0, 0, 0, 255 )
			surface.DrawRect( x, y, w, h )
			surface.SetDrawColor( cornerColor )
			surface.DrawRect( x +1, y +1, math.max( 1, w -2 ), math.max( 1, h -2 ) )
		end

		HudLine( left, boxTop, 3, corner )
		HudLine( left, boxTop, corner, 3 )
		HudLine( boxRight -3, boxTop, 3, corner )
		HudLine( boxRight -corner, boxTop, corner, 3 )
		HudLine( left, boxBottom -corner, 3, corner )
		HudLine( left, boxBottom -3, corner, 3 )
		HudLine( boxRight -3, boxBottom -corner, 3, corner )
		HudLine( boxRight -corner, boxBottom -3, corner, 3 )

		draw.SimpleTextOutlined(
			materialText,
			"xdebc_Font2", right, top, materialColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, outline
		)
		draw.SimpleTextOutlined(
			nailText,
			"xdebc_Font2", right, top +28, nailColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, outline
		)
	end

	local Shiny = Material( "models/shiny" )
	local Wiref = Material( "models/wireframe" )
	function SWEP:DoHolo( mdl, pos, ang, col, wf )
		if !IsValid( self.HoloModel ) then
			local ent = ClientsideModel( mdl, RENDERGROUP_BOTH )
			ent:SetPos( pos )
			ent:SetAngles( ang )
			ent:SetNoDraw( true )
			ent:SetColor( col )
			ent.Wireframed = wf
			self.HoloModel = ent

			function ent:RenderOverride()
				local col = ent:GetColor()
				render.SuppressEngineLighting( true )
				render.SetColorModulation( col.r/255, col.g/255, col.b/255 )

				render.SetBlend( 0.75 )
				render.MaterialOverride( ent.Wireframed == true and Wiref or Shiny )
				ent:DrawModel()

				render.SetBlend( 0.5 )
				render.MaterialOverride()
				ent:DrawModel()

				render.SuppressEngineLighting( false )
				render.SetBlend( 1 )
				render.MaterialOverride()
				render.SetColorModulation( 1, 1, 1 )
			end
		else
			local ent = self.HoloModel
			ent.Wireframed = wf
			if ent:GetModel() != mdl then
				ent:SetupBones()
				ent:SetModel( mdl )
			end
			ent:SetPos( pos )
			ent:SetAngles( ang )
			ent:SetColor( col )
			ent:DrawModel()
		end
	end

	function SWEP:DrawHUD()
		local own = LocalPlayer()
		if !IsValid( own ) or !own:Alive() then return end
		if GetConVar( "cl_drawhud" ):GetInt() <= 0 then return end
		self:DrawResourceHUD()
		if vgui.CursorVisible() then self.CrossMove = 0 return end
		
		local ww, hh = ScrW()/2, ScrH()/2
		local mode, height, col = self:GetXDE_Mode(), 0, Color( 255, 255, 255 )

		if mode <= 1 then -- 破坏与维修
			local tr = util.TraceLine( {
				start = own:GetShootPos(),
				endpos = own:GetShootPos() +own:GetAimVector()*96,
				filter = xdebc_TraceFilter( own ),
				mask = MASK_SHOT_HULL
			} )
			if !IsValid( tr.Entity ) then
				tr = util.TraceHull( {
					start = own:GetShootPos(),
					endpos = own:GetShootPos() +own:GetAimVector()*96,
					filter = xdebc_TraceFilter( own ),
					mins = Vector( -2, -2, -2 ),
					maxs = Vector( 2, 2, 2 ),
					mask = MASK_SHOT_HULL
				} )
			end
			local ent, si, txt = tr.Entity, self.CrossMove, ""
			local al, md = false, self:GetXDE_Mode()
			if IsValid( ent ) then
				-- The trace can hit the hidden collision blocker. Use the visible
				-- board as the display target, so the same status is shown for
				-- everyone when they aim at a barricade.
				ent = xdebc_GetBarricadeDisplayTarget( ent )
				if !ent:IsWorld() then
					ww, hh = ent:WorldSpaceCenter():ToScreen().x, ent:WorldSpaceCenter():ToScreen().y
				end
				if md == 0 then
					if ent:Health() > 0 or ent:GetNWBool( "XDEBC_Nail" ) then col = Color( 255, 0, 0 )
					else col = Color( 255, 255, 0 ) end
				elseif md == 1 then
					if ( ent:IsNPC() or ent:IsPlayer() or ent:IsNextBot() ) or ent:Health() <= 0 or ent:GetMaxHealth() <= 0 then
						col = Color( 255, 255, 0 )
						else
						local hp, mp = xdebc_GetNetworkedHealth( ent )
						local mhp = 0
						mhp = xdebc_GetConfiguredMaxHealth( ent )
						local hardMax = xdebc_GetHardMaxHealth( ent )
						if hardMax > 0 then
							hp = math.min( hp, hardMax )
							mp = math.min( mp, hardMax )
							mhp = math.min( mhp, hardMax )
						end
						if hp >= mhp then col = Color( 0, 255, 255 )
						else col = Color( 0, 255, 0 ) end
					end
				end
				al = true
			end

			ww = math.Clamp( ww, si*2, ScrW() -si*2 )
			hh = math.Clamp( hh, si*2, ScrH() -si*2 )
			self.PosFX = self.PosFX == -1 and ww or Lerp( math.min( 1, FrameTime()*20 ), self.PosFX, ww )
			self.PosFY = self.PosFY == -1 and hh or Lerp( math.min( 1, FrameTime()*20 ), self.PosFY, hh )
			local ww, hh = self.PosFX, self.PosFY
			
			self.CrossMove = Lerp( math.min( 1, FrameTime()*20 ), self.CrossMove, al and 24 or 48 )
			height = self.CrossMove*2

			self.PosFX = math.Clamp( self.PosFX, 0, ScrW() -48 )
			self.PosFY = math.Clamp( self.PosFY, 0, ScrH() -48 )

			local lines = {}
			local function NiceLine( x, y, w, h )
				surface.SetDrawColor( 0, 0, 0, 255 )
				surface.DrawRect( x, y, w, h )
				table.insert( lines, { x, y, w, h } )
			end

			// surface.DrawLine( ww-si, hh-si, ww-si, hh -si/2 ) surface.DrawLine( ww-si, hh-si, ww -si/2, hh -si )
			// surface.DrawLine( ww+si, hh+si, ww+si, hh +si/2 ) surface.DrawLine( ww+si, hh+si, ww +si/2, hh +si )
			// surface.DrawLine( ww-si, hh+si, ww-si, hh +si/2 ) surface.DrawLine( ww-si, hh+si, ww -si/2, hh+si )
			// surface.DrawLine( ww+si, hh-si, ww+si, hh -si/2 ) surface.DrawLine( ww+si, hh-si, ww +si/2, hh-si )

			ww, hh, si = math.Round( ww ), math.Round( hh ), math.Round( si )
			NiceLine( ww-si, hh-si, 3, si/2 +3 ) NiceLine( ww-si, hh-si, si/2 +3, 3 )
			NiceLine( ww +si/2, hh-si, si/2 +3, 3 ) NiceLine( ww +si, hh-si, 3, si/2 +3 )
			NiceLine( ww-si, hh +si/2, 3, si/2 +3 ) NiceLine( ww-si, hh +si, si/2 +3, 3 )
			NiceLine( ww +si, hh +si/2, 3, si/2 +3 ) NiceLine( ww +si/2, hh+si, si/2 +3, 3 )

			surface.SetDrawColor( col )
			for k, v in ipairs( lines ) do
				surface.SetDrawColor( 0, 0, 0, 255 )
				draw.RoundedBox( 0, v[1] +1, v[2] +1, v[3] -2, v[4] -2, col )
			end

			if IsValid( ent ) and !ent:IsNPC() and !ent:IsPlayer() and !ent:IsNextBot() then
				local hp, mp = xdebc_GetNetworkedHealth( ent )
				local hardMax = xdebc_GetHardMaxHealth( ent )
				if hardMax > 0 then
					hp = math.min( hp, hardMax )
					mp = math.min( mp, hardMax )
				end
				if ( hp > 0 and mp > 0 ) or ent:GetNWBool( "XDEBC_Nail" ) then
					local str = string.Replace( language.GetPhrase( "xdebc.Health" ), "%HEALTH%", ( hp.." / "..mp ) )
					draw.SimpleTextOutlined( str, "xdebc_Font2", ww, hh +si*3.2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0 ) )
				end
			end
		elseif mode == 2 then -- 钉子
			local tr = util.TraceLine( {
				start = own:GetShootPos(),
				endpos = own:GetShootPos() +own:GetAimVector()*96,
				filter = xdebc_TraceFilter( own ),
				mask = MASK_SHOT_HULL
			} )

			local yes = ( tr.Hit and !tr.Entity:IsPlayer() and !tr.Entity:IsNextBot() and !tr.Entity:IsNPC() )
			col = ( yes and Color( 0, 255, 0 ) or Color( 255, 255, 0 ) )
			if self:GetXDE_Cant() then col = Color( 255, 0, 0 ) end

			local po1, an1 = self:GetXDE_Pos(), self:GetXDE_Ang()
			if yes and self:GetNextPrimaryFire() <= CurTime() then
				cam.Start3D()
				self:DoHolo( "models/props_mining/railroad_spike01.mdl", po1, an1, col )
				cam.End3D()
			end
			
			local ww, hh = ScrW()/2, ScrH()/2 +64
			self.PosFX = self.PosFX == -1 and ww or Lerp( math.min( 1, FrameTime()*20 ), self.PosFX, ww )
			self.PosFY = self.PosFY == -1 and hh or Lerp( math.min( 1, FrameTime()*20 ), self.PosFY, hh )
			self.PosFX = math.Clamp( self.PosFX, 0, ScrW() -48 )
			self.PosFY = math.Clamp( self.PosFY, 0, ScrH() -48 )
			height = self.CrossMove*2
		else -- 建造
			local tab = xdebc_Planks[ self:GetXDE_Model() ]
			local tr = util.TraceLine( {
				start = own:GetShootPos(),
				endpos = own:GetShootPos() +own:GetAimVector()*96,
				filter = xdebc_TraceFilter( own ),
				mask = MASK_SHOT_HULL
			} )

			local yes = ( tr.Hit and ( !tr.Entity:IsNPC() and !tr.Entity:IsPlayer() and !tr.Entity:IsNextBot() ) )
			col = ( yes and Color( 0, 255, 0 ) or Color( 255, 255, 0 ) )
			if self:GetXDE_Cant() then col = Color( 255, 0, 0 ) end

			if yes and self:GetNextPrimaryFire() <= CurTime() then
				local pi = 3.141592654
				local po1, an1 = self:GetXDE_Pos(), self:GetXDE_Ang()
				cam.Start3D()
				self:DoHolo( tab[ 1 ], po1, an1, col, true )
				cam.End3D()
			end

			local ww, hh = ScrW()/2, ScrH()/2 +64
			self.PosFX = self.PosFX == -1 and ww or Lerp( math.min( 1, FrameTime()*20 ), self.PosFX, ww )
			self.PosFY = self.PosFY == -1 and hh or Lerp( math.min( 1, FrameTime()*20 ), self.PosFY, hh )
			self.PosFX = math.Clamp( self.PosFX, 0, ScrW() -48 )
			self.PosFY = math.Clamp( self.PosFY, 0, ScrH() -48 )
			height = self.CrossMove*2
		end

		local str = string.Replace( language.GetPhrase( "xdebc.Mode" ), "%MODE%", language.GetPhrase( "xdebc.Mode"..math.Clamp( self:GetXDE_Mode(), 0, 3 ) ) )
		draw.SimpleTextOutlined( str, "xdebc_Font2", self.PosFX, self.PosFY +height, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0 ) )
		local reasonID = self:GetXDE_Reason()
		if ( mode == 2 or mode == 3 ) and reasonID > 0 then
			local reason = language.GetPhrase( "xdebc.PlaceReason"..reasonID )
			draw.SimpleTextOutlined( reason, "xdebc_Font3", self.PosFX, self.PosFY +height +24,
				Color( 255, 90, 90 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0 ) )
		end
	end
end

function SWEP:IdleAnim()
	if CLIENT then return end
	local own = self.Owner
	timer.Remove( "weapon_idle"..self:EntIndex() )
	timer.Create( "weapon_idle"..self:EntIndex(), self:SequenceDuration() +FrameTime()*10, 1, function()
		if IsValid( self ) and IsValid( own ) and own:GetActiveWeapon() == self then
			self:SendWeaponAnim( ACT_VM_IDLE )
		end
	end )
	if false then

	local XDEBC_QSettings = {
		{ 1, "Материалы (макс.)", 1, 200 },
		{ 2, "Гвозди (макс.)", 1, 200 },
		{ 3, "Баррикады (макс.)", 1, 100 },
		{ 4, "Гвозди на карте", 1, 200 },
		{ 5, "HP доски (макс.)", 1, 5000 },
		{ 6, "Ремонт HP", 1, 100 },
		{ 7, "HP гвоздя", 1, 10 },
		{ 8, "Урон NPC / удар", 1, 100 }
	}

	local function xdebc_SendQSetting( settingID, value )
		net.Start( "xdebc_C2S_Settings" )
		net.WriteUInt( settingID, 4 )
		net.WriteFloat( value )
		net.SendToServer()
	end

	hook.Add( "PopulateToolMenu", "xdebc_barricade_settings_menu", function()
		spawnmenu.AddToolMenuOption( "Utilities", "Server", "XDEBC_BarricadeSettings", "Barricade", "", "", function( panel )
			panel:ClearControls()
			panel:Help( "Настройки баррикад. Изменять их может только администратор." )

			if !LocalPlayer():IsAdmin() then
				panel:Help( "Недостаточно прав для изменения серверных настроек." )
				return
			end

			for _, setting in ipairs( XDEBC_QSettings ) do
				local settingID, label, minValue, maxValue = setting[ 1 ], setting[ 2 ], setting[ 3 ], setting[ 4 ]
				local cvarName = settingID == 1 and "xdebc_materialcap"
					or settingID == 2 and "xdebc_nailcap"
					or settingID == 3 and "xdebc_maxbarricades"
					or settingID == 4 and "xdebc_maxnails"
					or settingID == 5 and "xdebc_plankhp"
					or settingID == 6 and "xdebc_repairamount"
					or settingID == 7 and "xdebc_nailhp"
					or "xdebc_npcdamage"
				local cvar = GetConVar( cvarName )
				local slider = vgui.Create( "DNumSlider", panel )
				slider:SetText( label )
				slider:SetTooltip( label )
				slider:SetMin( minValue )
				slider:SetMax( maxValue )
				slider:SetDecimals( 0 )
				slider:SetValue( cvar and cvar:GetInt() or minValue )
				slider:Dock( TOP )
				slider:DockMargin( 0, 3, 0, 3 )
				if IsValid( slider.Label ) then slider.Label:SetFont( "xdebc_Font3" ) end
				if IsValid( slider.TextArea ) then slider.TextArea:SetFont( "xdebc_Font3" ) end

				function slider:OnValueChanged( value )
					if self.XDEBC_Initializing then return end
					timer.Create( "xdebc_q_setting_"..settingID, 0.1, 1, function()
						if IsValid( self ) then xdebc_SendQSetting( settingID, self:GetValue() ) end
					end )
				end

				slider.XDEBC_Initializing = true
				slider:SetValue( cvar and cvar:GetInt() or minValue )
				slider.XDEBC_Initializing = false
				panel:AddItem( slider )
			end

			local reset = vgui.Create( "DButton", panel )
			reset:SetText( "Сбросить настройки" )
			reset:SetFont( "xdebc_Font3" )
			reset:Dock( TOP )
			reset:DockMargin( 0, 8, 0, 3 )
			function reset:DoClick()
				local defaults = { 40, 50, 12, 50, 100, 20, 5, 10 }
				for id, value in ipairs( defaults ) do xdebc_SendQSetting( id, value ) end
				timer.Simple( 0.2, function()
					if IsValid( panel ) then panel:InvalidateLayout( true ) end
				end )
			end
			panel:AddItem( reset )
		end )
	end )
	end
end

if CLIENT then
	local XDEBC_QSettings = {
		{ 1, xdebc_Text( "Материалы", "Materials" ), 1, 200, xdebc_Text( "Максимум материалов в инвентаре", "Maximum materials a player can carry" ) },
		{ 2, xdebc_Text( "Гвозди", "Nails" ), 1, 200, xdebc_Text( "Максимум гвоздей в инвентаре", "Maximum nails a player can carry" ) },
		{ 3, xdebc_Text( "Баррикады", "Barricades" ), 1, 100, xdebc_Text( "Максимум установленных баррикад", "Maximum barricades owned by one player" ) },
		{ 4, xdebc_Text( "Гвозди на карте", "Placed Nails" ), 1, 200, xdebc_Text( "Максимум установленных гвоздей", "Maximum nails placed by one player" ) },
		{ 5, xdebc_Text( "HP доски", "Board HP" ), 1, 5000, xdebc_Text( "Максимальное здоровье доски", "Maximum health of placed boards" ) },
		{ 6, xdebc_Text( "Ремонт HP", "Repair HP" ), 1, 100, xdebc_Text( "Сколько здоровья восстанавливает молоток", "Health restored by one hammer hit" ) },
		{ 7, xdebc_Text( "HP гвоздя", "Nail HP" ), 1, 10, xdebc_Text( "Множитель здоровья гвоздя", "Nail health multiplier" ) },
		{ 8, xdebc_Text( "Урон NPC", "NPC Damage" ), 1, 100, xdebc_Text( "Урон NPC по баррикаде за один удар", "NPC damage to a barricade per hit" ) },
		{ 10, xdebc_Text( "Материалы в ящике", "Materials in supply crate" ), 0, 200, xdebc_Text( "Запас материалов в новом ящике", "Materials given by a newly spawned crate" ) },
		{ 11, xdebc_Text( "Гвозди в ящике", "Nails in supply crate" ), 0, 100, xdebc_Text( "Запас гвоздей в новом ящике", "Nails given by a newly spawned crate" ) }
	}

	local function xdebc_SendQSetting( settingID, value )
		net.Start( "xdebc_C2S_Settings" )
		net.WriteUInt( settingID, 4 )
		net.WriteFloat( value )
		net.SendToServer()
	end

	local function xdebc_ResetQSettings()
		net.Start( "xdebc_C2S_ResetSettings" )
		net.SendToServer()
	end

	hook.Add( "PopulateToolMenu", "xdebc_barricade_settings_menu", function()
		spawnmenu.AddToolMenuOption( "Utilities", "Server", "XDEBC_BarricadeSettings", xdebc_Text( "Баррикады", "Barricade" ), "", "", function( panel )
			panel:ClearControls()
			panel.Paint = function( self, w, h )
				draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 0, 0, 210 ) )
				surface.SetDrawColor( 170, 170, 170, 190 )
				surface.DrawOutlinedRect( 0, 0, w, h, 1 )
				local corner = 14
				surface.DrawRect( 0, 0, corner, 2 )
				surface.DrawRect( 0, 0, 2, corner )
				surface.DrawRect( w -corner, 0, corner, 2 )
				surface.DrawRect( w -2, 0, 2, corner )
				surface.DrawRect( 0, h -2, corner, 2 )
				surface.DrawRect( 0, h -corner, 2, corner )
				surface.DrawRect( w -corner, h -2, corner, 2 )
				surface.DrawRect( w -2, h -corner, 2, corner )
			end
			local info = panel:Help( xdebc_Text( "Настройки баррикад. Изменять их может только администратор.", "Barricade settings. Only administrators can change them." ) )
			if IsValid( info ) then
				info:SetFont( "xdebc_Font3" )
				info:SetTextColor( Color( 210, 210, 210 ) )
			end

			if !IsValid( LocalPlayer() ) or !LocalPlayer():IsAdmin() then
				local denied = panel:Help( xdebc_Text( "Недостаточно прав для изменения серверных настроек.", "You do not have permission to change server settings." ) )
				if IsValid( denied ) then denied:SetTextColor( Color( 210, 210, 210 ) ) end
				return
			end

			for _, setting in ipairs( XDEBC_QSettings ) do
				local settingID, label, minValue, maxValue, tooltip = setting[ 1 ], setting[ 2 ], setting[ 3 ], setting[ 4 ], setting[ 5 ]
				local cvarName = settingID == 1 and "xdebc_materialcap"
					or settingID == 2 and "xdebc_nailcap"
					or settingID == 3 and "xdebc_maxbarricades"
					or settingID == 4 and "xdebc_maxnails"
					or settingID == 5 and "xdebc_plankhp"
					or settingID == 6 and "xdebc_repairamount"
					or settingID == 7 and "xdebc_nailhp"
					or settingID == 8 and "xdebc_npcdamage"
					or settingID == 10 and "xdebc_crate_materials"
					or "xdebc_crate_nails"
				local cvar = GetConVar( cvarName )
				local slider = vgui.Create( "DNumSlider", panel )
				slider:SetText( label )
				slider:SetMin( minValue )
				slider:SetMax( maxValue )
				slider:SetDecimals( 0 )
				slider:SetValue( cvar and cvar:GetInt() or minValue )
				slider:SetTooltip( tooltip or label )
				slider:SetTall( 38 )
				slider:Dock( TOP )
				slider:DockMargin( 0, 3, 0, 3 )
				function slider:Paint( w, h )
					draw.RoundedBox( 0, 0, 0, w, h, Color( 10, 10, 10, 205 ) )
					surface.SetDrawColor( 120, 120, 120, 220 )
					surface.DrawOutlinedRect( 0, 0, w, h, 1 )
				end
				if IsValid( slider.Label ) then
					slider.Label:SetFont( "xdebc_Font3" )
					slider.Label:SetTextColor( Color( 210, 210, 210 ) )
					slider.Label:SetWide( 150 )
				end
				if IsValid( slider.TextArea ) then
					slider.TextArea:SetFont( "xdebc_Font3" )
					slider.TextArea:SetTextColor( Color( 220, 220, 220 ) )
					slider.TextArea:SetWide( 44 )
					if isfunction( slider.TextArea.SetDrawBackground ) then slider.TextArea:SetDrawBackground( true ) end
					if isfunction( slider.TextArea.SetDrawBorder ) then slider.TextArea:SetDrawBorder( true ) end
					if isfunction( slider.TextArea.SetBGColor ) then slider.TextArea:SetBGColor( Color( 0, 0, 0, 190 ) ) end
				end
				if IsValid( slider.Slider ) then
					function slider.Slider:Paint( w, h )
						draw.RoundedBox( 0, 0, h/2 -1, w, 2, Color( 145, 145, 145, 230 ) )
					end
					if IsValid( slider.Slider.Knob ) then
						function slider.Slider.Knob:Paint( w, h )
							draw.RoundedBox( 0, 0, 0, w, h, Color( 195, 195, 195, 255 ) )
							surface.SetDrawColor( 25, 25, 25, 255 )
							surface.DrawOutlinedRect( 0, 0, w, h, 1 )
						end
					end
				end
				panel.XDEBC_Sliders = panel.XDEBC_Sliders or {}
				panel.XDEBC_Sliders[ settingID ] = slider

				function slider:OnValueChanged( value )
					if self.XDEBC_Initializing then return end
					timer.Create( "xdebc_q_setting_"..settingID, 0.1, 1, function()
						if IsValid( self ) then xdebc_SendQSetting( settingID, self:GetValue() ) end
					end )
				end

				slider.XDEBC_Initializing = true
				slider:SetValue( cvar and cvar:GetInt() or minValue )
				slider.XDEBC_Initializing = false
				panel:AddItem( slider )
			end

			local reset = vgui.Create( "DButton", panel )
			reset:SetText( xdebc_Text( "Сбросить настройки", "Reset settings" ) )
			reset:SetFont( "xdebc_Font3" )
			local infinite = vgui.Create( "DCheckBoxLabel", panel )
			infinite:SetText( xdebc_Text( "Бесконечные материалы и гвозди", "Infinite materials and nails" ) )
			infinite:SetTooltip( xdebc_Text( "Материалы и гвозди не расходуются при строительстве", "Materials and nails are not consumed while building" ) )
			infinite:SetFont( "xdebc_Font3" )
			infinite:SetTextColor( Color( 210, 210, 210 ) )
			infinite:SetTall( 32 )
			infinite:Dock( TOP )
			infinite:DockMargin( 0, 7, 0, 3 )
			local infiniteCvar = GetConVar( "xdebc_infinite_resources" )
			infinite.XDEBC_Initializing = true
			infinite:SetValue( infiniteCvar and infiniteCvar:GetBool() and 1 or 0 )
			infinite.XDEBC_Initializing = false
			function infinite:OnChange( value )
				if self.XDEBC_Initializing then return end
				xdebc_SendQSetting( 9, value and 1 or 0 )
			end
			panel.XDEBC_InfiniteResources = infinite
			panel:AddItem( infinite )
			if IsValid( infinite.Button ) then
				function infinite.Button:Paint( w, h )
					draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 0, 0, 210 ) )
					surface.SetDrawColor( 165, 165, 165, 240 )
					surface.DrawOutlinedRect( 0, 0, w, h, 1 )
					if self:GetChecked() then
						surface.SetDrawColor( 205, 205, 205, 255 )
						surface.DrawRect( 4, 4, w -8, h -8 )
					end
				end
			end

			reset:SetTextColor( Color( 220, 220, 220 ) )
			reset:SetTall( 36 )
			reset:Dock( TOP )
			reset:DockMargin( 0, 8, 0, 3 )
			function reset:Paint( w, h )
				draw.RoundedBox( 0, 0, 0, w, h, Color( 25, 25, 25, 230 ) )
				surface.SetDrawColor( 150, 150, 150, 255 )
				surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			end
			function reset:DoClick()
				local defaults = { 40, 50, 12, 50, 100, 20, 5, 10, 0, 20, 8 }
				xdebc_ResetQSettings()
				for id, value in ipairs( defaults ) do
					local slider = panel.XDEBC_Sliders and panel.XDEBC_Sliders[ id ]
					if IsValid( slider ) then
						slider.XDEBC_Initializing = true
						slider:SetValue( value )
						slider.XDEBC_Initializing = false
					end
				end
				if IsValid( panel.XDEBC_InfiniteResources ) then
					panel.XDEBC_InfiniteResources.XDEBC_Initializing = true
					panel.XDEBC_InfiniteResources:SetValue( 0 )
					panel.XDEBC_InfiniteResources.XDEBC_Initializing = false
				end
			end
			panel:AddItem( reset )
		end )
	end )
end

function SWEP:DoGesture( act )
	local own = self.Owner
	if CLIENT then
		own:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, act, true )
	else
		net.Start( "xdebc_S2C_Gesture" )
		net.WriteEntity( self )
		net.WriteFloat( act )
		net.Broadcast()
	end
end

function SWEP:SetupDataTables()
	self:NetworkVar( "Int", 0, "XDE_Mode" )
	self:NetworkVar( "Int", 1, "XDE_Angle" )
	self:NetworkVar( "Int", 2, "XDE_Model" )
	self:NetworkVar( "Int", 3, "XDE_Reason" )
	self:NetworkVar( "Bool", 0, "XDE_Menu" )
	self:NetworkVar( "Bool", 1, "XDE_Cant" )
	self:NetworkVar( "Vector", 0, "XDE_Pos" )
	self:NetworkVar( "Angle", 0, "XDE_Ang" )
	self:NetworkVarNotify( "XDE_Mode", function()
		if CLIENT then
			self.CrossMove = 0
			self.PosFX = ScrW()/2
			self.PosFY = ScrH()/2
		end
	end )
end

function SWEP:Initialize()
	if SERVER then
		self:SetXDE_Menu( false )
		self:SetXDE_Cant( false )
		self:SetXDE_Reason( 0 )
		self:SetXDE_Mode( 3 )
		self:SetXDE_Model( 1 )
	end
	self:SetHoldType( "slam" )
	self.RightOnce = false
end

function SWEP:Deploy() local own = self.Owner
	self:SetHoldType( "slam" )
	self:IdleAnim()
	self.RightOnce = false
	if SERVER then
		self:SetXDE_Menu( false )
	end
	self:NextThink( CurTime() )
	return true
end

function SWEP:PrimaryAttack() local own = self.Owner
	if !IsValid( own ) or !own:IsPlayer() then return end
	if self:GetNextPrimaryFire() > CurTime() or self:GetNextSecondaryFire() > CurTime() then return end

	local mode = self:GetXDE_Mode()
	if own:KeyDown( IN_USE ) and mode == 3 then
		self:SetXDE_Angle( self:GetXDE_Angle()%360 -15*( own:KeyDown( IN_SPEED ) and 1 or 2 ) )
		self:EmitSound( "buttons/lightswitch2.wav", 60, 110, 0.5, CHAN_ITEM )
		self:SetNextSecondaryFire( CurTime() +0.2 )
		return
	end

	if mode == 0 or mode == 1 then
		own:LagCompensation( true )
		local tr = util.TraceLine( {
			start = own:GetShootPos(),
			endpos = own:GetShootPos() +own:GetAimVector()*96,
			filter = xdebc_TraceFilter( own ),
			mask = MASK_SHOT_HULL
		} )
		if !IsValid( tr.Entity ) then
			tr = util.TraceHull( {
				start = own:GetShootPos(),
				endpos = own:GetShootPos() +own:GetAimVector()*96,
				filter = xdebc_TraceFilter( own ),
				mins = Vector( -2, -2, -2 ),
				maxs = Vector( 2, 2, 2 ),
				mask = MASK_SHOT_HULL
			} )
		end
		local ent, yes = tr.Entity, false
		local livingTarget = IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() )
		if SERVER then
			if livingTarget and ent:Health() > 0 and ent:GetMaxHealth() > 0 then
				own:EmitSound( "xdebarricade.hit" )
			elseif tr.Hit then
				if IsValid( ent ) and ent:Health() > 0 then
					if mode == 0 then
						own:EmitSound( xdebc_GetMaterialSound( ent, "xdebarricade.hitworld", "Metal_Box.BulletImpact" ) )
					else
						local mhp = xdebc_GetConfiguredMaxHealth( ent )
						if ent:Health() >= mhp then
							own:EmitSound( xdebc_GetMaterialSound( ent, "xdebarricade.hitworld", "Metal_Box.BulletImpact" ) )
						else
							own:EmitSound( xdebc_GetMaterialSound( ent, "xdebarricade.hitfix", "Metal_Box.BulletImpact" ) )
						end
					end
					yes = true
				else
					own:EmitSound( "xdebarricade.hitworld" )
				end
			else
				own:EmitSound( "xdebarricade.hitmiss" )
			end
		end
		if SERVER and IsValid( ent ) then
			local dismantled = (mode == 0 and (XDEBC_SalvageWood(ent, own) or xdebc_DismantlePlank(ent, own)))
                or (mode == 1 and xdebc_AssemblePlank(ent, own))
			if !dismantled then
				-- The barricade hammer must never deal melee damage to players,
				-- NPCs or NextBots. It only repairs props in mode 1 and damages /
				-- dismantles non-living entities in mode 0.
				if livingTarget then
					-- Hit sound/animation is handled above; intentionally no damage.
				elseif mode == 0 then
					local dmg = DamageInfo()
					dmg:SetAttacker( own )
					dmg:SetInflictor( self )
					dmg:SetDamage(20)
					dmg:SetDamageType( DMG_CLUB )
					dmg:SetDamagePosition( tr.HitPos )
					dmg:SetDamageForce( own:EyeAngles():Forward()*16384 )
					ent:DispatchTraceAttack( dmg, tr, tr.HitNormal )
				elseif ent:Health() > 0 and ent:GetMaxHealth() > 0 then
					local mhp = xdebc_GetConfiguredMaxHealth( ent )
                    if ent:Health() < mhp and xdebc_TakePlayerResource(own, "Materials", 5) then
					if ent:Health() < mhp then
						local pos = tr.HitPos +tr.HitNormal
						timer.Simple( 0, function()
							if IsValid( ent ) then xdebc_PlayMaterialEffect( ent, pos, tr.HitNormal ) end
						end )
					end
					ent:RemoveAllDecals()
					if ent:IsOnFire() then ent:Extinguish() end
					local repairAmount = 20
					ent:SetHealth( math.min( mhp, ent:Health() +repairAmount ) )
					ent:SetNWInt( "XDEBC_MP", mhp )
                    end
				end
				if !ent:IsPlayer() and !ent:IsNPC() and !ent:IsNextBot() then
					ent:SetNWInt( "XDEBC_HP", ent:Health() )
					if ent:GetNWInt( "XDEBC_MP", 0 ) <= 0 then
						ent:SetNWInt( "XDEBC_MP", ent:GetMaxHealth() )
					end
				end
			end
		end
		self:SendWeaponAnim( ACT_VM_HITCENTER )
		if SERVER then
			self:DoGesture( mode == 0 and ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE or ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE )
		end
		self:IdleAnim()
		own:LagCompensation( false )
		self:SetNextPrimaryFire( CurTime() +( mode == 0 and 0.8 or 0.4 ) )
		self:SetNextSecondaryFire( CurTime() +0.2 )
	elseif mode == 2 and own:CheckLimit( "props" ) then
		own:LagCompensation( true )
		local tr = util.TraceLine( {
			start = own:GetShootPos(),
			endpos = own:GetShootPos() +own:GetAimVector()*96,
			filter = xdebc_TraceFilter( own ),
			mask = MASK_SHOT_HULL
		} )
		local yes = ( tr.Hit and !tr.Entity:IsPlayer() and !tr.Entity:IsNextBot() and !tr.Entity:IsNPC() )
		if SERVER and yes and !self:GetXDE_Cant() then
			local maxNails = GetConVar( "xdebc_maxnails" ):GetInt()
			if xdebc_CountOwnedNails( own ) >= maxNails then
				self:SetNextPrimaryFire( CurTime() +0.4 )
				self:SetNextSecondaryFire( CurTime() +0.2 )
				own:LagCompensation( false )
				return
			end
			if !xdebc_HasInfiniteResources() and xdebc_GetPlayerResource( own, "Nails" ) < XDEBC_NAIL_COST then
				self:SetNextPrimaryFire( CurTime() +0.4 )
				self:SetNextSecondaryFire( CurTime() +0.2 )
				own:LagCompensation( false )
				return
			end
			local ent = tr.Entity
			self:SendWeaponAnim( ACT_VM_HITKILL )
			if SERVER then
				self:DoGesture( ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM )
			end
			self:IdleAnim()
			local pos, ang = self:GetXDE_Pos(), self:GetXDE_Ang()
			local nai = ents.Create( "prop_physics" )
			nai:SetModel( "models/props_mining/railroad_spike01.mdl" )
			nai:SetPos( pos )
			nai:SetAngles( ang )
			nai:Spawn()
			if !xdebc_TakePlayerResource( own, "Nails", XDEBC_NAIL_COST ) then
				nai:Remove()
				self:SetNextPrimaryFire( CurTime() +0.4 )
				self:SetNextSecondaryFire( CurTime() +0.2 )
				own:LagCompensation( false )
				return
			end
			nai.XDEBC_NailWasPlaced = true
			nai.XDEBC_NailResourceFree = xdebc_HasInfiniteResources()
			nai:SetNWBool( "XDEBC_NailResourcePaid", !nai.XDEBC_NailResourceFree )
			nai:SetNWBool( "XDEBC_NailResourceFree", nai.XDEBC_NailResourceFree )
			nai:CallOnRemove( "XDEBC_RefundNail", function( removed )
				xdebc_RefundNail( removed )
			end )
			nai:SetCollisionGroup( COLLISION_GROUP_WORLD )
			nai:AddEFlags( EFL_NO_DAMAGE_FORCES )
			nai.XDE_BCEnt = ent
			xdebc_ProtectSupport( ent )
			xdebc_MarkNailedProp( ent, own )
			nai:SetNWBool( "XDEBC_Nail", true )
			nai.VJ_ID_Prop = true
			nai.VJ_ID_Attackable = true
			nai.VJ_ID_Destructible = true
			nai:GetPhysicsObject():SetMass( 1 )
			nai:SetMaxHealth( 10 )
			nai:SetHealth( 10 )
			if own:IsAdmin() and own:GetInfoNum( "xdebc_max", 0 ) > 0 then
				local mhp = math.min( XDEBC_NAIL_HARD_MAX, math.ceil( nai:GetMaxHealth()*math.max( 1, GetConVar( "xdebc_nailhp" ):GetFloat() ) ) )
				nai:SetMaxHealth( mhp )
				nai:SetHealth( mhp )
			end
			nai.XDEBC_BuilderOwner = own
			nai:SetOwner( own )
            if XDEBC_WedgeDoor then XDEBC_WedgeDoor(ent, nai) end

			local pos, nor = nai:WorldSpaceCenter(), ang:Forward()
			constraint.NoCollide( nai, ent, 0, tr.PhysicsBone )
			local wld, fil, lat = 1, {}, nil
			while wld <= 8 do
				local t2 = util.TraceLine( {
					start = pos -nor*6,
					endpos = pos +nor*8,
					filter = { own, nai, unpack( fil ) },
					mask = MASK_SHOT_HULL
				} )
				
				// debugoverlay.Line( pos -nor*6, pos +nor*8, 10, t2.Hit and Color( 255, 0, 0 ) or Color( 255, 255, 255 ) )
				if !t2.Hit and wld == 1 then break end
				
				local bon, tar = t2.PhysicsBone, t2.Entity
				if ( !IsValid( tar ) and tar != Entity( 0 ) ) or tar == lat then
					break
				else
					wld = wld +1
					if tar == Entity( 0 ) or ( !NADMOD or NADMOD.PlayerCanTouch( own, tar ) ) then
						constraint.Weld( nai, tar, 0, bon, 0, true )
                        if XDEBC_WedgeDoor then XDEBC_WedgeDoor(tar, nai) end
					end
					constraint.NoCollide( nai, tar, 0, bon )
					lat = tar
					table.insert( fil, lat )
				end
				if tar == Entity( 0 ) then
					nai:GetPhysicsObject():EnableMotion( false )
				end
			end
			if NADMOD then
				NADMOD.PlayerMakePropOwner( own, nai )
			end
			hook.Run( "PlayerSpawnedProp", own, nai:GetModel(), nai )

			undo.Create( "#xdebc.Mode2" )
			undo.AddEntity( nai )
			undo.SetPlayer( own )
			undo.Finish()

			cleanup.Add( own, "props", nai )
			local nor = tr.HitNormal
			timer.Simple( 0, function()
				xdebc_PlayMaterialEffect( nai, pos +nor, nor )
			end )

			own:EmitSound( "Metal_Box.BulletImpact" )
			self:SetNextPrimaryFire( CurTime() +0.8 )
			self:SetNextSecondaryFire( CurTime() +0.2 )

			if !ent:IsWorld() then
				local dmg = DamageInfo()
				dmg:SetAttacker( own )
				dmg:SetInflictor( self )
				dmg:SetDamage( 1 )
				dmg:SetDamageType( DMG_CLUB )
				dmg:SetDamagePosition( tr.HitPos )
				dmg:SetDamageForce( own:EyeAngles():Forward()*1024 )
				ent:DispatchTraceAttack( dmg, tr, tr.HitNormal )

				if !istable( ent.XDE_Planks ) then ent.XDE_Planks = {} end
				nai:CallOnRemove( "XDE_RestoreSupport", function( removed )
					xdebc_RestoreSupport( ent, removed )
				end )
				ent:CallOnRemove( "XDE_DropPlanks", function()
					xdebc_Unfreeze( ent, true )
				end )
				table.insert( ent.XDE_Planks, nai )
			end
		else
			self:SetNextSecondaryFire( CurTime() +0.2 )
		end
		own:LagCompensation( false )

	elseif mode == 3 and own:CheckLimit( "props" ) then
		own:LagCompensation( true )
		local tab = xdebc_Planks[ self:GetXDE_Model() ]
		local tr = util.TraceLine( {
			start = own:GetShootPos(),
			endpos = own:GetShootPos() +own:GetAimVector()*96,
			filter = xdebc_TraceFilter( own ),
			mask = MASK_SHOT_HULL
		} )

		local yes = ( tr.Hit and ( !tr.Entity:IsNPC() and !tr.Entity:IsPlayer() and !tr.Entity:IsNextBot() ) )
		local floorOnly = tab[ 7 ] == "floor"
		if SERVER and yes and floorOnly and !xdebc_IsFloorSurface( tr ) then
			self:SetNextPrimaryFire( CurTime() +0.4 )
			self:SetNextSecondaryFire( CurTime() +0.2 )
			own:LagCompensation( false )
			return
		end
		if SERVER and yes and !self:GetXDE_Cant() then
			local maxBarricades = GetConVar( "xdebc_maxbarricades" ):GetInt()
			if xdebc_CountOwnedBarricades( own ) >= maxBarricades then
				self:SetNextPrimaryFire( CurTime() +0.4 )
				self:SetNextSecondaryFire( CurTime() +0.2 )
				own:LagCompensation( false )
				return
			end

			local pi = 3.141592654
			local pos, ang = self:GetXDE_Pos(), self:GetXDE_Ang()
			local ori, deg = Vector( 0, 0, 0 ), self:GetXDE_Angle()
			if true then
				local ent = tr.Entity
				self:SendWeaponAnim( ACT_VM_HITKILL )
				if SERVER then
					self:DoGesture( ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM )
				end
				self:IdleAnim()
				-- A board is a regular prop_physics. VJ-BASE can therefore find it
				-- through its normal prop interaction and deal damage to its HP.
				local plk = ents.Create( "prop_physics" )
				if !IsValid( plk ) then
					own:ChatPrint( xdebc_Text( "Не удалось создать доску", "Failed to create barricade board" ) )
					own:LagCompensation( false )
					return
				end
				plk:SetModel( tab[ 1 ] )
				plk:SetPos( pos )
				plk:SetAngles( ang )
				plk:Spawn()
                plk.XDEBC_BuildCost = xdebc_BuildCost(tab)
                plk.XDEBC_MaterialsPaid = 0
                plk:SetNWBool("XDEBC_Building", true)
                plk.XDEBC_OriginalMaterial = plk:GetMaterial()
                plk.XDEBC_OriginalColor = plk:GetColor()
                plk:SetMaterial("models/wireframe")
                plk:SetColor(Color(255, 255, 255, 255))
                plk.XDEBC_BuildExpires = CurTime() + 20
                timer.Simple(20, function()
                    if IsValid(plk) and plk:GetNWBool("XDEBC_Building") then
                        plk:Remove()
                    end
                end)
				plk:Activate()
				plk:AddEFlags( EFL_NO_DAMAGE_FORCES )
				plk:SetNWBool( "XDEBC_Plank", true )
				xdebc_ConfigurePlankCollision( plk )
				-- Leave the VJ attackable marker enabled. The NPC is put into
				-- PropInteraction = OnlyDamage above, so it cannot push this prop.
				plk.VJ_ID_Prop = true
				plk.VJ_ID_Attackable = true
				plk.VJ_ID_Destructible = true
				plk.XDE_BCEnt = ent
				xdebc_ProtectSupport( ent )
				xdebc_FreezeSupport( ent )

				local plkPhys = plk:GetPhysicsObject()
				if IsValid( plkPhys ) then
					plkPhys:EnableMotion( false )
					plkPhys:Sleep()
				end
				if !ent:IsWorld() then
					-- Keep the board in world space. The support is frozen while it
					-- has boards attached, so parenting would only introduce a
					-- second local transform that can desync collision rotation.
					constraint.NoCollide( plk, ent, 0, tr.PhysicsBone )
					if !istable( ent.XDE_Planks ) then ent.XDE_Planks = {} end
					plk:CallOnRemove( "XDE_RestoreSupport", function( removed )
						xdebc_RestoreSupport( ent, removed )
					end )
					ent:CallOnRemove( "XDE_DropPlanks", function()
						xdebc_Unfreeze( ent, true )
					end )
					table.insert( ent.XDE_Planks, plk )
				end
				xdebc_ConfigurePlankCollision( plk )
				xdebc_CreatePlankBlocker( plk )
				xdebc_RefreshPlankBlocker( plk )
				timer.Simple( 0, function()
					if IsValid( plk ) then
						xdebc_ConfigurePlankCollision( plk )
						xdebc_RefreshPlankBlocker( plk )
					end
				end )

				-- The Q-menu value is the authoritative maximum for every placed prop.
				local plankHP = math.min( XDEBC_PLANK_HARD_MAX, GetConVar( "xdebc_plankhp" ):GetInt() )
				if xdebc_IsStrongBuild(tab[1]) then plankHP = 200 end
                local initialPlankHP = 0 -- Repair-mode hammer hits assemble in 20-HP steps.
				plk:SetMaxHealth( plankHP )
				plk:SetHealth( initialPlankHP )
				plk:SetNWInt( "XDEBC_HP", initialPlankHP )
				plk:SetNWInt( "XDEBC_MP", plankHP )
				plk.XDEBC_BuilderOwner = own
				plk:SetOwner( own )
				undo.Create( "#xdebc.Plank" )
				undo.AddEntity( plk )
				undo.SetPlayer( own )
				undo.Finish()
				cleanup.Add( own, "props", plk )
				local nor = tr.HitNormal
				timer.Simple( 0, function()
					xdebc_PlayMaterialEffect( plk, pos +nor, nor )
				end )
				own:EmitSound( xdebc_GetMaterialSound( plk, "xdebarricade.hitplank", "Metal_Box.BulletImpact" ) )
				self:SetNextPrimaryFire( CurTime() +0.8 )
				self:SetNextSecondaryFire( CurTime() +0.2 )
			else
				self:SetNextSecondaryFire( CurTime() +0.2 )
			end
		else
			self:SetNextSecondaryFire( CurTime() +0.2 )
		end
		own:LagCompensation( false )
	end
end

function SWEP:SecondaryAttack() local own = self.Owner
	if !IsValid( own ) or !own:IsPlayer() then return end
	if self:GetNextSecondaryFire() > CurTime() or self.RightOnce then return end

	local mode = self:GetXDE_Mode()
	if own:KeyDown( IN_USE ) and mode == 3 then
		self:SetXDE_Angle( self:GetXDE_Angle()%360 +15*( own:KeyDown( IN_SPEED ) and 1 or 2 ) )
		self:EmitSound( "buttons/lightswitch2.wav", 60, 110, 0.5, CHAN_ITEM )
		self:SetNextSecondaryFire( CurTime() +0.2 )
		return
	end

	if SERVER then
		net.Start( "xdebc_S2C_Menu" )
		net.WriteFloat( self:GetXDE_Mode() )
		net.WriteFloat( self:GetXDE_Model() )
		net.Send( own )
		timer.Remove( "weapon_idle"..self:EntIndex() )
		local vm = own:GetViewModel()
		local holsterSequence = vm:LookupSequence( "holster" )
		if holsterSequence >= 0 then
			vm:SendViewModelMatchingSequence( holsterSequence )
			vm:SetPlaybackRate( 1 )
		end
		self:SetXDE_Menu( true )
		self:SetHoldType( "passive" )
	end
	self.RightOnce = true
	self:SetNextSecondaryFire( CurTime() +0.2 )
end

function SWEP:Reload() local own = self.Owner
	if !IsValid( own ) or !own:IsPlayer() or self:GetXDE_Menu() then return end
	if self:GetNextSecondaryFire() > CurTime() or self.ReloadOnce or self.RightOnce then return end
	if SERVER then
		-- Build -> Build / Repair -> Destruct -> Nail -> Build
        local nextMode = {[3] = 1, [1] = 0, [0] = 2, [2] = 3}
        self:SetXDE_Mode(nextMode[self:GetXDE_Mode()] or 3)
	end
	self.ReloadOnce = true
	self:SetNextSecondaryFire( CurTime() +0.1 )
end

function SWEP:Think() local own = self.Owner
	if !IsValid( own ) or !own:IsPlayer() then return end
	if !own:KeyDown( IN_ATTACK2 ) and self.RightOnce and self:GetNextPrimaryFire() <= CurTime() and !self:GetXDE_Menu() then
		self.RightOnce = false
	end
		if !own:KeyDown( IN_RELOAD ) and self.ReloadOnce and self:GetNextPrimaryFire() <= CurTime() and !self:GetXDE_Menu() then
			self.ReloadOnce = false
		end
	if SERVER and self:GetXDE_Mode() >= 2 then
		own:LagCompensation( true )
		local mode = self:GetXDE_Mode()
		local tab = xdebc_Planks[ self:GetXDE_Model() ]
		local reason = 0
		local tr = util.TraceLine( {
			start = own:GetShootPos(),
			endpos = own:GetShootPos() +own:GetAimVector()*96,
			filter = xdebc_TraceFilter( own ),
			mask = MASK_SHOT_HULL
		} )
		local yes = tr.Hit and ( !tr.Entity:IsNPC() and !tr.Entity:IsPlayer() and !tr.Entity:IsNextBot() )
		local floorOnly = tab and tab[ 7 ] == "floor"

		if !yes then
			reason = tr.Hit and 2 or 1
		elseif mode == 2 then
			-- Match the original weapon: the nail follows the player's aim, so it
			-- can be driven upward, downward or sideways into the prop. Holding
			-- sprint switches to the strict surface-normal direction.
			local pos, ang = tr.HitPos, own:EyeAngles()
			if own:KeyDown( IN_SPEED ) then
				pos = Vector( math.Round( pos.x/2 )*2, math.Round( pos.y/2 )*2, math.Round( pos.z/2 )*2 )
				ang = tr.HitNormal:Angle() +Angle( 180, 0, 180 )
			end
			pos = pos -ang:Up()*2 -ang:Forward()*2
			self:SetXDE_Pos( pos )
			self:SetXDE_Ang( ang )

			if !own:CheckLimit( "props" ) then
				reason = 8
			elseif xdebc_CountOwnedNails( own ) >= GetConVar( "xdebc_maxnails" ):GetInt() then
				reason = 3
			elseif !xdebc_HasInfiniteResources() and xdebc_GetPlayerResource( own, "Nails" ) < XDEBC_NAIL_COST then
				reason = 4
			end
		else
			local deg = self:GetXDE_Angle()
			local pos, ang = tr.HitPos, tr.HitNormal:Angle()
			if own:KeyDown( IN_SPEED ) then
				pos = Vector( math.Round( pos.x/2 )*2, math.Round( pos.y/2 )*2, math.Round( pos.z/2 )*2 )
			end

			if floorOnly then
				-- Floor props use their authored upright orientation. The old
				-- surface-normal transform rotated them onto their sides and
				-- ignored the placement angle.
				ang = Angle( 0, own:EyeAngles().y +deg, 0 )
				if tab[ 8 ] == "vertical" then
					ang:RotateAroundAxis( ang:Right(), 90 )
				end
			else
				ang:RotateAroundAxis( ang:Forward(), tab[ 2 ].pitch +tab[ 4 ].pitch*deg )
				ang:RotateAroundAxis( ang:Right(), tab[ 2 ].yaw +tab[ 4 ].yaw*deg )
				ang:RotateAroundAxis( ang:Up(), tab[ 2 ].roll +tab[ 4 ].roll*deg )
			end

			local po2, po3
			if floorOnly then
				-- Place floor props by their real model bounds so furniture
				-- rests on the traced surface instead of floating from a
				-- hand-written offset.
				local floorOffset, radius = xdebc_GetModelPlacementBounds( tab[ 1 ], ang )
				floorOffset = floorOffset or tab[ 3 ].z
				radius = radius or tab[ 5 ].x/2
				local groundLift = tab[ 8 ] == "vertical" and 8 or 0
				po2 = pos +ang:Up()*( floorOffset +groundLift )
				po3 = po2 +ang:Forward()*radius
			else
				po2 = pos +( ang:Forward()*tab[ 3 ].x/2 +ang:Right()*tab[ 3 ].y/2 +ang:Up()*tab[ 3 ].z )
				po3 = pos +( ang:Forward()*tab[ 5 ].x/2 +ang:Right()*tab[ 5 ].y/2 +ang:Up()*tab[ 5 ].z )
			end

			self:SetXDE_Pos( po2 )
			self:SetXDE_Ang( ang )

			local t2 = util.QuickTrace( pos +tr.HitNormal, ( po3 -pos )*2 +tr.HitNormal, nil )
			if floorOnly and !xdebc_IsFloorSurface( tr ) then
				reason = 7
			elseif t2.HitWorld or t2.HitSky or ( IsValid( t2.Entity ) and ( t2.Entity:IsNPC() or t2.Entity:IsPlayer() ) ) then
				reason = 2
			elseif !own:CheckLimit( "props" ) then
				reason = 8
			elseif xdebc_CountOwnedBarricades( own ) >= GetConVar( "xdebc_maxbarricades" ):GetInt() then
				reason = 5
			end
		end

		self:SetXDE_Cant( reason != 0 )
		self:SetXDE_Reason( reason )
		own:LagCompensation( false )
	elseif SERVER then
		self:SetXDE_Cant( false )
		self:SetXDE_Reason( 0 )
	end
	self:NextThink( CurTime() +0.25 )
	return true
end

function SWEP:Holster()
	timer.Remove( "weapon_idle"..self:EntIndex() )
	if CLIENT then
		self.CrossMove = 0
		self.PosFX, self.PosFY = -1, -1
		if IsValid( self.HoloModel ) then
			self.HoloModel:Remove()
			self.HoloModel = nil
		end
	else
		self:SetXDE_Menu( false )
	end
	return true
end

-- Match server collision during client movement prediction, so walking through
-- an unfinished plan does not rubber-band. Weapon traces still hit the model.
if CLIENT then
    hook.Add("ShouldCollide", "XDEBC_UnfinishedPlan", function(a, b)
        if (IsValid(a) and a:GetNWBool("XDEBC_Building"))
            or (IsValid(b) and b:GetNWBool("XDEBC_Building")) then return false end
    end)
end
