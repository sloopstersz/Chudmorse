-- Chudmorse: VIP-only player models (Appearance editor > VIP button)
--
-- HOW TO USE
--   Custom playermodels go in VIP_CUSTOM_MODELS (they're registered and made VIP-only).
--   To make an existing appearance model VIP-only, put its name in VIP_MODELS below. Use the names exactly as they show in the Model menu,
--   e.g. "Male JohnWick", "Female Zoey". Those models then:
--     - disappear from the normal Model list for everyone,
--     - show up under the VIP button (bottom of the editor, under the presets) for VIP and above,
--     - are refused by the server for anyone below VIP (they get a normal model instead),
--     - are never handed out as a random appearance.
--
--   "VIP and above" = anyone in a group listed in VIP_GROUPS, anyone whose ULX group inherits
--   from one of them, and every admin / superadmin (owner, co-owner, ...).
--
-- Shared file: the server enforces it, the client only uses it to build the menu.

hg = hg or {}
hg.Appearance = hg.Appearance or {}

-------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------
local VIP_MODELS = {
	-- "Male JohnWick",
	-- "Male Travis",
	-- "Female Zoey",
}

-- Custom playermodels that are VIP-only. { "Name in the menu", "model path", female? }
-- They're added as appearance models (saved with your look, re-applied every spawn/round)
-- and automatically put on the VIP list. Their content must be on the server's Workshop collection.
-- These aren't Z-City bodies: clothes, facemaps and clothing styles don't change them.
local VIP_CUSTOM_MODELS = {
	{ "Rizzler (Costco)",       "models/dannio/pm/rizzler_costco.mdl" },
	{ "Big Justice (Costco)",   "models/dannio/pm/bigjustice_costco.mdl" },
	{ "AJ (Costco)",            "models/dannio/pm/aj_costco.mdl" },
	{ "Big Boss",               "models/player/big_boss.mdl" },
	{ "Old Snake",              "models/player/old_snake.mdl" },
	{ "Snake (MGS2)",           "models/ats/mgs2snake/mgs2snake.mdl" },
	{ "Chimp",                  "models/player/chimpanzee/chimp.mdl" },
	{ "Clown",                  "models/electric/clown/clown_pm.mdl" },
	{ "Dr. House",              "models/bunny/doctor_house/doctor_house.mdl" },
	{ "Freddy",                 "models/i6nis/freddy_player.mdl" },
	{ "Bonnie",                 "models/i6nis/bonnie_player.mdl" },
	{ "Chica",                  "models/i6nis/chica_player.mdl", true },
	{ "Foxy",                   "models/i6nis/foxy_player.mdl" },
	{ "Jesse",                  "models/player/jessev2.mdl" },
	{ "Walter",                 "models/player/walterv2.mdl" },
	{ "Gus Fring",              "models/gustavo_fring/gustavo_los_pollos.mdl" },
	{ "Master Chief",           "models/player/h3_masterchief_player.mdl" },
	{ "Tony Soprano",           "models/player/efeber/tonysop.mdl" },
	{ "Tung Tung Tung Sahur",   "models/gacommissions/tungtungtungsahur.mdl" },
	{ "Wheelchair Man",         "models/player/group02/wheelchair_man.mdl" },
	{ "Felix Kranken",          "models/player/ntwffelixkranken.mdl" },
	{ "Rosemary",               "models/player/ntwfrosemary.mdl", true },
	{ "Rick",                   "models/player/rickality/rick2.mdl" },
	{ "Morty",                  "models/player/rickality/morty.mdl" },
	{ "Kiryu",                  "models/kiryu/kiryu_kazuma.mdl" },
	{ "Tank (L4D)",             "models/player/pizzaroll/l4dtank.mdl" },
	{ "MatPat",                 "models/humans/panman/matpat_09.mdl" },
	{ "Skeleton",               "models/player/skeleton.mdl" },
}

-- PERSONAL models: only the listed Steam64 IDs can use them (not other VIPs, not admins).
-- They show under the VIP button for those players only, and the server refuses them for anyone else.
--   Custom model:   { "Name in the menu", "model path", female?, { "7656119...", "7656119..." } }
--   Existing model: { "Male JohnWick", nil, nil, { "7656119..." } }   (use its Model-menu name)
-- Find a Steam64 ID with ulx/status in console or steamid.io.
local PERSONAL_MODELS = {
	-- { "My Custom Guy", "models/player/my_guy.mdl", false, { "76561198000000000" } },
}

-- ULX group names that count as VIP (lowercase). Groups inheriting from these count too.
local VIP_GROUPS = { "vip" } -- add more, e.g. { "vip", "donator" }
-------------------------------------------------------------------------------

hg.Appearance.VIPModels = {}
for _, name in ipairs(VIP_MODELS) do
	hg.Appearance.VIPModels[name] = true
end

-- personal models: name -> set of allowed Steam64 IDs
hg.Appearance.ModelOwners = {}
for _, entry in ipairs(PERSONAL_MODELS) do
	local owners = {}
	for _, id in ipairs(entry[4] or {}) do owners[string.Trim(tostring(id))] = true end
	hg.Appearance.ModelOwners[entry[1]] = owners
	hg.Appearance.VIPModels[entry[1]] = true -- keeps it out of the normal list and random looks
	if entry[2] then
		VIP_CUSTOM_MODELS[#VIP_CUSTOM_MODELS + 1] = { entry[1], entry[2], entry[3] }
	end
end
for _, entry in ipairs(VIP_CUSTOM_MODELS) do
	hg.Appearance.VIPModels[entry[1]] = true
end

-- register the custom models as appearance models (same table the validator and sv_init use)
local function AddCustomVIPModels()
	local models = hg.Appearance.PlayerModels
	if not istable(models) then return end
	models[1] = models[1] or {}
	models[2] = models[2] or {}

	for _, entry in ipairs(VIP_CUSTOM_MODELS) do
		local name, mdl, bFemale = entry[1], string.lower(entry[2]), entry[3] == true
		models[bFemale and 2 or 1][name] = {
			mdl = mdl,
			submatSlots = {}, -- no Z-City clothing slots
			sex = bFemale,
			vipCustom = true -- kept out of FuckYouModels (no Z-City bandage hands etc.)
		}
		if hg.Appearance.FuckYouModels then
			if hg.Appearance.FuckYouModels[1] then hg.Appearance.FuckYouModels[1][mdl] = nil end
			if hg.Appearance.FuckYouModels[2] then hg.Appearance.FuckYouModels[2][mdl] = nil end
		end
	end
end

AddCustomVIPModels()
hook.Add("Initialize", "Chud_VIPModels_AddCustom", AddCustomVIPModels)
hg.Appearance.VIPGroups = VIP_GROUPS

function hg.Appearance.IsVIPModel(name)
	return isstring(name) and hg.Appearance.VIPModels[name] == true
end

function hg.Appearance.IsVIP(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if ply:IsAdmin() or ply:IsSuperAdmin() then return true end

	local group = string.lower(ply:GetUserGroup() or "")
	for _, g in ipairs(VIP_GROUPS) do
		if group == g then return true end
		if ply.CheckGroup and ply:CheckGroup(g) then return true end
	end

	return false
end

function hg.Appearance.CanUseModel(ply, name)
	if not hg.Appearance.IsVIPModel(name) then return true end
	local owners = hg.Appearance.ModelOwners[name]
	if owners then
		return IsValid(ply) and ply:IsPlayer() and owners[ply:SteamID64() or ""] == true
	end
	return hg.Appearance.IsVIP(ply)
end

-- VIP button shows for VIPs and for anyone who owns a personal model
function hg.Appearance.CanSeeVIPMenu(ply)
	if hg.Appearance.IsVIP(ply) then return true end
	if not IsValid(ply) then return false end
	local id = ply:SteamID64() or ""
	for _, owners in pairs(hg.Appearance.ModelOwners) do
		if owners[id] then return true end
	end
	return false
end

-- a random model of the given sex that isn't VIP-only
function hg.Appearance.GetRandomNonVIPModel(bFemale)
	local models = hg.Appearance.PlayerModels or {}
	local pool = {}
	for name in pairs(models[bFemale and 2 or 1] or {}) do
		if not hg.Appearance.IsVIPModel(name) then pool[#pool + 1] = name end
	end
	if #pool == 0 then
		for sexID = 1, 2 do
			for name in pairs(models[sexID] or {}) do
				if not hg.Appearance.IsVIPModel(name) then pool[#pool + 1] = name end
			end
		end
	end
	return pool[math.random(#pool)] or "Male 07"
end

-- random appearances (bots, players without a saved look, failed loads) never use VIP models
local function PatchRandomAppearance()
	local original = hg.Appearance.GetRandomAppearance
	if not isfunction(original) or hg.Appearance.__ChudVIPRandomPatched then return end
	hg.Appearance.__ChudVIPRandomPatched = true

	hg.Appearance.GetRandomAppearance = function(...)
		local tbl = original(...)
		if istable(tbl) and hg.Appearance.IsVIPModel(tbl.AModel) then
			local models = hg.Appearance.PlayerModels or {}
			local md = (models[1] or {})[tbl.AModel] or (models[2] or {})[tbl.AModel]
			tbl.AModel = hg.Appearance.GetRandomNonVIPModel(md and md.sex)
		end
		return tbl
	end
end

PatchRandomAppearance()
hook.Add("Initialize", "Chud_VIPModels_PatchRandom", PatchRandomAppearance)

if SERVER then
	-- called from sv_init WearAppearance before anything is applied
	function hg.Appearance.EnforceVIPModel(ply, tbl)
		if not istable(tbl) or hg.Appearance.CanUseModel(ply, tbl.AModel) then return tbl end

		local models = hg.Appearance.PlayerModels or {}
		local md = (models[1] or {})[tbl.AModel] or (models[2] or {})[tbl.AModel]
		local wanted = tbl.AModel
		tbl.AModel = hg.Appearance.GetRandomNonVIPModel(md and md.sex)

		if IsValid(ply) and ply.ChatPrint and not (ply.IsBot and ply:IsBot()) then
			local why = hg.Appearance.ModelOwners[wanted] and "a personal model" or "a VIP model"
			ply:ChatPrint(wanted .. " is " .. why .. ", you got " .. tbl.AModel .. " instead.")
		end

		return tbl
	end
end
