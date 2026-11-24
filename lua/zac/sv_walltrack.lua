-- WALL TRACKING (wallhack / ESP): the server knows who each player can actually see. Someone whose
-- crosshair keeps FOLLOWING an enemy they can't see (through walls, while that enemy moves around) is
-- reading their position from an ESP. Honest players can't do that for long.
--   Every 0.1 s, for each player: enemies within Range whose head / chest is within Degrees of their
--   crosshair are traced; if neither is visible (walls in the way) the time is added up. Following one
--   hidden, moving enemy for Seconds (enemy moved MinMove, view turned MinTurn degrees to keep on them)
--   = flag + cheat-rating points. Teammates (same EFZ team) are skipped.
-- Cheap: only enemies near the crosshair are traced, so it's a handful of traces per tick.
local cfg = ZAC.Config
local W = cfg.WallTrack or {}
local UNITS = 52.49

local function character(p)
	if hg and hg.GetCurrentCharacter then
		local ok, c = pcall(hg.GetCurrentCharacter, p)
		if ok and IsValid(c) then return c end
	end
	return p
end

local function headPos(p)
	local body = character(p)
	local bone = body:LookupBone("ValveBiped.Bip01_Head1")
	local pos = bone and body:GetBonePosition(bone)
	return pos or p:EyePos(), body
end

local function eyeOf(p)
	local body = character(p)
	if body ~= p then
		local bone = body:LookupBone("ValveBiped.Bip01_Head1")
		local pos = bone and body:GetBonePosition(bone)
		if pos then return pos, body end
	end
	return p:EyePos(), body
end

-- can a see b (head or chest), from a's eyes? Shared with the admin spectate overlay.
function ZAC.CanSee(a, b)
	local eye, aBody = eyeOf(a)
	local head, bBody = headPos(b)
	local filter = { a, aBody, b, bBody }
	local tr = util.TraceLine({ start = eye, endpos = head, mask = MASK_SHOT, filter = filter })
	if not tr.Hit then return true end
	local chest = bBody:WorldSpaceCenter()
	tr = util.TraceLine({ start = eye, endpos = chest, mask = MASK_SHOT, filter = filter })
	return not tr.Hit
end

local function teammates(a, b)
	local t = a:GetNWInt("ext_team", 0)
	return t ~= 0 and t == b:GetNWInt("ext_team", 0)
end

local function active(p) return IsValid(p) and p:Alive() and not p:IsBot() or (IsValid(p) and p:Alive() and cfg.Rating and cfg.Rating.RateBots) end

timer.Create("zac_walltrack", 0.1, 0, function()
	if W.Enabled == false then return end
	local now = CurTime()
	local cosMax = math.cos(math.rad(W.Degrees or 4))
	local range = (W.Range or 80) * UNITS
	local minRange = (W.MinRange or 4) * UNITS
	local plys = player.GetAll()
	for _, a in ipairs(plys) do
		if active(a) and a:GetObserverMode() == OBS_MODE_NONE then
			local eye = a:EyePos()
			local aim = a:GetAimVector()
			local track = a.ZACTrack or {}
			a.ZACTrack = track
			for _, b in ipairs(plys) do
				if b ~= a and IsValid(b) and b:Alive() and not teammates(a, b) then
					local head = headPos(b)
					local d = head - eye
					local dist = d:Length()
					local st = track[b]
					local hidden = false
					if dist > minRange and dist < range then
						local dot = aim:Dot(d / dist)
						if dot >= cosMax then hidden = not ZAC.CanSee(a, b) end
					end
					if hidden then
						if not st or now - st.last > 0.35 then
							st = { t0 = now, from = Vector(head), yaw = a:EyeAngles().y, turn = 0 }
							track[b] = st
						end
						local y = a:EyeAngles().y
						st.turn = st.turn + math.abs(math.AngleDifference(y, st.yaw))
						st.yaw = y
						st.last = now
						st.moved = head:Distance(st.from)
						if now - st.t0 >= (W.Seconds or 1.5) and st.moved >= (W.MinMove or 3) * UNITS and st.turn >= (W.MinTurn or 8)
							and (a.ZACWallNext or 0) < now then
							a.ZACWallNext = now + (W.Cooldown or 15)
							local msg = string.format("followed %s through walls for %.1fs (they moved %.0fm, view turned %.0f deg, %.0fm away)",
								b:Nick(), now - st.t0, st.moved / UNITS, st.turn, dist / UNITS)
							ZAC.Log("aim", ZAC.Who(a) .. " " .. msg, nil, a, b)
							if cfg.AlertAdmins then ZAC.AdminChat(a:Nick() .. " " .. msg) end
							if ZAC.RatingEvidence then ZAC.RatingEvidence(a, "walltrack", W.Points or 10, msg, b) end
							track[b] = nil
						end
					elseif st and now - st.last > 0.35 then
						track[b] = nil
					end
				end
			end
		end
	end
end)

hook.Add("PlayerDisconnected", "zac_walltrack", function(ply)
	for _, p in player.Iterator() do if p.ZACTrack then p.ZACTrack[ply] = nil end end
end)
