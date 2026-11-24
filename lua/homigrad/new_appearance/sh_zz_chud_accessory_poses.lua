-- Accessory poses (Appearance > Poses), shared between server and clients.
--
-- A player's pose tweaks are stored in their appearance as
--   APoses = { [accessoryKey] = { x, y, z, pitch, yaw, roll } }
-- offsets added on top of the accessory's default pose (works for male and female models).
-- The client sends them with the rest of the appearance, the server cleans them with
-- SanitizeAccessoryPoses and networks them as the "AccessoryPoses" netvar (sv_init.lua),
-- and DrawAccesories (cl_init.lua) applies them for everyone.

hg = hg or {}
hg.Appearance = hg.Appearance or {}

local POS_LIMIT = 8      -- units each way (the editor sliders go to 5)
local ANG_LIMIT = 180    -- degrees each way
local MAX_POSES = 6      -- one per accessory slot

function hg.Appearance.SanitizeAccessoryPoses(poses, attachments)
	if not istable(poses) then return {} end

	local equipped
	if istable(attachments) then
		equipped = {}
		for _, key in pairs(attachments) do
			if isstring(key) then equipped[key] = true end
		end
	end

	local out, count = {}, 0
	for key, offset in pairs(poses) do
		if count >= MAX_POSES then break end
		if not isstring(key) or not istable(offset) then continue end
		if not (hg.Accessories and hg.Accessories[key]) then continue end
		if equipped and not equipped[key] then continue end

		local clean, changed = {}, false
		for i = 1, 6 do
			local v = tonumber(offset[i]) or 0
			if v ~= v then v = 0 end -- NaN
			local limit = i <= 3 and POS_LIMIT or ANG_LIMIT
			v = math.Round(math.Clamp(v, -limit, limit), 2)
			if v ~= 0 then changed = true end
			clean[i] = v
		end

		if changed then
			out[key] = clean
			count = count + 1
		end
	end

	return out
end

if hg.Appearance.ValidateFunctions then
	hg.Appearance.ValidateFunctions.APoses = function(tbl)
		return tbl == nil or istable(tbl)
	end
end
