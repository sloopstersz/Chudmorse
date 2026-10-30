-- This message is sent only to the player responsible for the teamkill.
local currentChannel
local requestID = 0
net.Receive("ChudF4SavesLivesSound", function()
    local index = net.ReadUInt(2) + 1
    requestID = requestID + 1
    local thisRequest = requestID
    if IsValid(currentChannel) then currentChannel:Stop() end
    sound.PlayFile("sound/chudmorse/notifications/f4_" .. index .. ".mp3", "noplay", function(channel, errorID, errorName)
        if not IsValid(channel) then
            ErrorNoHalt("[F4 sound] " .. tostring(errorName) .. "\n")
            return
        end
        if thisRequest ~= requestID then channel:Stop() return end
        currentChannel = channel
        channel:SetVolume(1)
        channel:Play()
    end)
end)
