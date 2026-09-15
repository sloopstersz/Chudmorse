hook.Add("Think", "JuggernautClearEffects", function()
    if not IsValid(LocalPlayer()) then return end
    
    if LocalPlayer():GetPlayerClass() == "juggernaut" and LocalPlayer():Alive() then
        LocalPlayer():SetDSP(0, false)
        
        if LocalPlayer().organism then
            LocalPlayer().organism.disorientation = 0
            LocalPlayer().organism.immobilization = 0
        end
    end
end)

hook.Add("RenderScreenspaceEffects", "JuggernautNoConcussion", function()
    if LocalPlayer():GetPlayerClass() == "juggernaut" and LocalPlayer():Alive() then
        return true
    end
end)

hook.Add("PostRender", "JuggernautNoBlur", function()
    if LocalPlayer():GetPlayerClass() == "juggernaut" and LocalPlayer():Alive() then
        DrawColorModify({
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0,
            ["$pp_colour_contrast"] = 1,
            ["$pp_colour_colour"] = 1,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        })
    end
end)