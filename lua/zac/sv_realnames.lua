local cfg = ZAC.Config
local ENTITY = FindMetaTable("Entity")

if not ENTITY.ZACOrigSetNWString then ENTITY.ZACOrigSetNWString = ENTITY.SetNWString end
local origSet = ENTITY.ZACOrigSetNWString

function ENTITY:SetNWString(key, value, ...)
	if cfg.RealNames and key == "PlayerName" and IsValid(self) and self:IsPlayer() then
		value = self:Nick()
	end
	return origSet(self, key, value, ...)
end

local function apply(ply)
	if not cfg.RealNames or not IsValid(ply) then return end
	local real = ply:Nick()
	if ply:GetNWString("PlayerName", "") ~= real then origSet(ply, "PlayerName", real) end
	local rag = ply.FakeRagdoll
	if IsValid(rag) and rag:GetNWString("PlayerName", "") ~= real then origSet(rag, "PlayerName", real) end
end

hook.Add("PlayerInitialSpawn", "zac_realnames", function(ply) timer.Simple(1, function() apply(ply) end) end)
hook.Add("PlayerSpawn", "zac_realnames", function(ply) timer.Simple(0.2, function() apply(ply) end) end)
timer.Create("zac_realnames", 2, 0, function()
	for _, ply in player.Iterator() do apply(ply) end
end)
hook.Add("player_changename", "zac_realnames", function(data)
	local ply = Player(data.userid or 0)
	if IsValid(ply) then timer.Simple(0.1, function() apply(ply) end) end
end)
gameevent.Listen("player_changename")
