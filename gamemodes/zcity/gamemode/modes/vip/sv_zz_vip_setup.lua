-- VIP map setup and diagnostics. Explicit Point Editor locations always take priority.
if not SERVER then return end
local MODE = MODE
local generated, generatedMap
local groups = {"President_Defenders", "President_Attackers", "President_Task1", "President_Task2", "President_Task3"}
local function Saved(group)
    local result = {}
    for _, point in ipairs(zb.GetMapPoints(group) or {}) do
        if isvector(point.pos) then result[#result + 1] = point end
    end
    return result
end
local function BuildFallback()
    local candidates = {}
    local function Add(pos)
        if not util.IsInWorld(pos) then return end
        local floor = util.TraceLine({start=pos+Vector(0,0,64), endpos=pos-Vector(0,0,256), mask=MASK_SOLID_BRUSHONLY})
        if not floor.Hit or floor.StartSolid or floor.HitNormal.z < 0.7 then return end
        local standing = floor.HitPos + Vector(0,0,4)
        local hull = util.TraceHull({start=standing, endpos=standing, mins=Vector(-16,-16,0), maxs=Vector(16,16,72), mask=MASK_PLAYERSOLID})
        if hull.Hit or hull.StartSolid then return end
        for _, old in ipairs(candidates) do if old:DistToSqr(standing)<(MODE.HoldRadius*2+16)^2 then return end end
        candidates[#candidates+1]=standing
    end
    local seeds={}
    for _, class in ipairs({"info_player_start","info_player_deathmatch","info_player_counterterrorist","info_player_terrorist","info_player_combine","info_player_rebel","gmod_player_start"}) do
        for _, ent in ipairs(ents.FindByClass(class)) do seeds[#seeds+1]=ent:GetPos() Add(ent:GetPos()) end
    end
    for _, name in ipairs({"Spawnpoint","Terrorist","CounterTerrorist"}) do
        if zb.Points[name] then for _, point in ipairs(Saved(name)) do seeds[#seeds+1]=point.pos Add(point.pos) end end
    end
    -- Connected navigation areas produce better routes than unrelated map locations.
    if navmesh and navmesh.GetNearestNavArea and seeds[1] then
        local first=navmesh.GetNearestNavArea(seeds[1],false,1000,false,true)
        if IsValid(first) then
            local queue,seen={first},{[first:GetID()]=true}
            local cursor=1
            while cursor<=#queue and cursor<=512 do
                local area=queue[cursor] cursor=cursor+1
                Add(area:GetCenter())
                for _, nextArea in ipairs(area:GetAdjacentAreas()) do
                    if not seen[nextArea:GetID()] then seen[nextArea:GetID()]=true queue[#queue+1]=nextArea end
                end
            end
        end
    end
    -- Sandbox maps may have no navmesh. Sample clear, grounded positions near spawns.
    if #candidates<5 then
        for i=1,math.min(#seeds,8) do
            for _, radius in ipairs({384,768,1152}) do
                for step=0,7 do
                    local a=step*math.pi/4
                    local pos=seeds[i]+Vector(math.cos(a)*radius,math.sin(a)*radius,0)
                    local line=util.TraceLine({start=seeds[i]+Vector(0,0,40),endpos=pos+Vector(0,0,40),mask=MASK_SOLID_BRUSHONLY})
                    if not line.Hit then Add(pos) end
                end
            end
        end
    end
    local result={}
    -- Reserve all manual locations so fallback objectives never overlap them.
    local chosen={}
    for _, group in ipairs(groups) do
        result[group]=Saved(group)
        for _, point in ipairs(result[group]) do chosen[#chosen+1]=point.pos end
    end
    for _, group in ipairs(groups) do
        if #result[group]==0 then
            local best,bestDistance
            for _, pos in ipairs(candidates) do
                local distance=math.huge
                for _, used in ipairs(chosen) do distance=math.min(distance,pos:DistToSqr(used)) end
                if distance>(MODE.HoldRadius*2+16)^2 and (not bestDistance or distance>bestDistance) then best,bestDistance=pos,distance end
            end
            if best then result[group]={{pos=best,ang=Angle(0,0,0)}} chosen[#chosen+1]=best end
        end
    end
    return result
end
function MODE:GetVIPPoints(group)
    local saved=Saved(group)
    if #saved>0 then return saved end
    if not generated or generatedMap~=game.GetMap() then
        generatedMap=game.GetMap()
        generated=BuildFallback()
    end
    return generated[group] or {}
end
function MODE:VIPLaunchReason()
    local count=0
    for _, ply in player.Iterator() do if ply:Team()~=TEAM_SPECTATOR then count=count+1 end end
    if count<3 then return "VIP needs at least 3 participants (VIP, guard, attacker); currently "..count.."." end
    for _, group in ipairs(groups) do
        if #self:GetVIPPoints(group)==0 then return "No usable "..group.." location. Stand at a suitable spot and use chud_vip_point "..group end
    end
    if not self:BuildRoute(false) then return "VIP objectives overlap. Place the three task points more than 320 units apart." end
end
local function Reply(ply,text)
    if IsValid(ply) then ply:ChatPrint(text) else print(text) end
end
local function Allowed(ply) return not IsValid(ply) or ply:IsAdmin() end
concommand.Add("chud_vip_status",function(ply)
    if not Allowed(ply) then return end
    generated=nil
    local mode=zb.modes.vip
    if not mode then Reply(ply,"VIP is not registered. Restart the server after installing the patch.") return end
    local reason=mode:VIPLaunchReason()
    Reply(ply,reason or "VIP is ready. Select VIP Escort for the next round.")
    for _, group in ipairs(groups) do
        Reply(ply,group..": "..#mode:GetVIPPoints(group).." location(s), "..(#Saved(group)>0 and "manual" or "automatic"))
    end
end)
concommand.Add("chud_vip_point",function(ply,_,args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local group=args[1]
    if not table.HasValue(groups,group) then Reply(ply,"Usage: chud_vip_point "..table.concat(groups," | ")) return end
    local point={pos=ply:GetPos(),ang=Angle(0,ply:EyeAngles().y,0)}
    zb.Points[group].Points={point}
    zb.SaveMapPoints(group,{point})
    generated=nil
    Reply(ply,"Saved "..group.." at your position.")
end)
