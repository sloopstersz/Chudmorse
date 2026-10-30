-- Nails lock only doors they actually penetrate, never nearby doors.
local doors = {prop_door_rotating = true, prop_door = true, func_door = true, func_door_rotating = true}
local tracked = {}
local function HasNails(door)
    local state = tracked[door]
    if not state then return false end
    for nail in pairs(state.nails) do
        if IsValid(nail) then return true end
    end
    return false
end
local function HasWedge(door)
    for _, wedge in ipairs(ents.FindByClass("ent_hg_jam")) do
        if wedge.Blocking then
            for _, blocked in pairs(wedge.Doors or {}) do
                if blocked == door then return true end
            end
        end
    end
    return false
end
local function Release(door)
    local state = tracked[door]
    if not state or HasNails(door) then return end
    tracked[door] = nil
    if IsValid(door) then
        door:SetNWBool("XDEBC_NailedDoor", false)
        if state.wasUnlocked and not HasWedge(door) then door:Fire("Unlock", "", 0) end
    end
end
function XDEBC_WedgeDoor(door, nail)
    if not IsValid(door) or not doors[door:GetClass()] or not IsValid(nail) then return end
    local state = tracked[door]
    if not state then
        local locked = door:GetInternalVariable("m_bLocked")
        state = {nails = {}, wasUnlocked = locked == false or locked == 0}
        tracked[door] = state
    end
    if state.nails[nail] then return end
    state.nails[nail] = true
    door:SetNWBool("XDEBC_NailedDoor", true)
    door:Fire("Lock", "", 0)
    nail:CallOnRemove("XDEBC_DoorWedge_" .. door:EntIndex(), function(removed)
        state.nails[removed] = nil
        Release(door)
    end)
end
-- Map buttons and other tools must not open/unlock a door while nails remain.
hook.Add("AcceptInput", "XDEBC_NailedDoor", function(ent, input)
    if not HasNails(ent) then return end
    input = string.lower(input)
    if input == "unlock" or input == "open" or input == "openawayfrom" or input == "toggle" then return true end
end)
timer.Create("XDEBC_NailedDoorLock", 0.25, 0, function()
    for door in pairs(tracked) do
        if not IsValid(door) then tracked[door] = nil
        elseif HasNails(door) then door:Fire("Lock", "", 0)
        else Release(door) end
    end
end)
hook.Add("PostCleanupMap", "XDEBC_NailedDoor", function() tracked = {} end)
