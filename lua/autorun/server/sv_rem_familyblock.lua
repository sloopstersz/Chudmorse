if not SERVER then return end

local TAG = "[RemorseFamilyBlock] "

local function IsBorrower(ply, sid64)
	local owner = ply:OwnerSteamID64()

	if not owner or owner == "" then return false end

	local sid = tonumber(sid64) or tonumber(ply:SteamID64())
	local ownerNum = tonumber(owner)

	if not sid or not ownerNum then return false end

	return ownerNum ~= sid and ownerNum ~= 0
end

local function Check(kicker, ply, sid64)
	if not IsValid(ply) or ply:IsBot() then return end

	ply.rem_family_kicked = nil

	if IsBorrower(ply, sid64) then
		local sid = ply:SteamID64()
		local owner = ply:OwnerSteamID64()

		MsgN(TAG .. "rejected " .. ply:Name() .. " (" .. sid .. ") | game lent by " .. owner .. " | family sharing blocked")

		ply.rem_family_kicked = true
		kicker(ply)
	end
end

hook.Add("PlayerAuthed", "RemorseFamilyBlock", function(ply, sid)
	Check(function(p)
		p:Kick("Steam family sharing is not allowed on this server")
	end, ply, sid)
end)

hook.Add("PlayerInitialSpawn", "RemorseFamilyBlock", function(ply)
	if ply.rem_family_kicked then return end

	Check(function(p)
		p:Kick("Steam family sharing is not allowed on this server")
	end, ply)
end)
