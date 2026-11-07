-- Install the paired content pack on the SERVER as well as clients.
resource.AddFile("models/chudmorse/dragon/bsmodimations_beasthact.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/bsmodimations_beasthact.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/bsmodimations_beasthact.mdl")
resource.AddFile("models/chudmorse/dragon/bsmodimations_beasthact.sw.vtx")
resource.AddFile("models/chudmorse/dragon/bsmodimations_beasthact.vvd")
resource.AddFile("models/chudmorse/dragon/c_limbs_beasthact.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/c_limbs_beasthact.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/c_limbs_beasthact.mdl")
resource.AddFile("models/chudmorse/dragon/c_limbs_beasthact.sw.vtx")
resource.AddFile("models/chudmorse/dragon/c_limbs_beasthact.vvd")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_player.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_player.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_player.mdl")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_player.sw.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_player.vvd")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_target.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_target.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_target.mdl")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_target.sw.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_brawlerhact_target.vvd")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_player.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_player.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_player.mdl")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_player.sw.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_player.vvd")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_target.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_target.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_target.mdl")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_target.sw.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_rushhact_target.vvd")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_player.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_player.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_player.mdl")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_player.sw.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_player.vvd")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_target.dx80.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_target.dx90.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_target.mdl")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_target.sw.vtx")
resource.AddFile("models/chudmorse/dragon/killmove_tigerdrop_target.vvd")

local sequences = {
    {"models/chudmorse/dragon/c_limbs_beasthact.mdl", "killmove_beasthact_piledive"},
    {"models/chudmorse/dragon/bsmodimations_beasthact.mdl", "killmove_beasthact_piledive"},
    {"models/chudmorse/dragon/killmove_brawlerhact_player.mdl", "killmove_brawlerhact_brawling"},
    {"models/chudmorse/dragon/killmove_brawlerhact_target.mdl", "killmove_brawlerhact_brawling"},
    {"models/chudmorse/dragon/killmove_brawlerhact_player.mdl", "killmove_brawlerhact_finishingblow"},
    {"models/chudmorse/dragon/killmove_brawlerhact_target.mdl", "killmove_brawlerhact_finishingblow"},
    {"models/chudmorse/dragon/killmove_brawlerhact_player.mdl", "killmove_brawlerhact_disarming"},
    {"models/chudmorse/dragon/killmove_brawlerhact_target.mdl", "killmove_brawlerhact_disarming"},
    {"models/chudmorse/dragon/killmove_rushhact_player.mdl", "killmove_rushhact_barrage"},
    {"models/chudmorse/dragon/killmove_rushhact_target.mdl", "killmove_rushhact_barrage"},
    {"models/chudmorse/dragon/killmove_rushhact_player.mdl", "killmove_rushhact_crushing"},
    {"models/chudmorse/dragon/killmove_rushhact_target.mdl", "killmove_rushhact_crushing"},
    {"models/chudmorse/dragon/killmove_rushhact_player.mdl", "killmove_rushhact_crushing_wall"},
    {"models/chudmorse/dragon/killmove_rushhact_target.mdl", "killmove_rushhact_crushing_wall"},
    {"models/chudmorse/dragon/killmove_tigerdrop_player.mdl", "killmove_tigerdrop"},
    {"models/chudmorse/dragon/killmove_tigerdrop_target.mdl", "killmove_tigerdrop"},
}
local function CheckDragonContent(reply)
    local failures = 0
    for _, entry in ipairs(sequences) do
        local model, sequence = entry[1], entry[2]
        if not file.Exists(model, "GAME") then
            failures = failures + 1
            reply("MISSING SERVER MODEL: " .. model)
        elseif not WWE or not WWE.SeqExists or not WWE.SeqExists(model, sequence) then
            failures = failures + 1
            reply("UNAVAILABLE SERVER ANIMATION: " .. model .. " / " .. sequence)
        end
    end
    reply(failures == 0 and "All Dragon Style animation pairs are available on the server."
        or (failures .. " failed checks. Install chudmorse_content_pack on the server and restart."))
end
hook.Add("InitPostEntity", "ChudDragonDedicatedContent", function()
    CheckDragonContent(function(message) print("[Dragon Style] " .. message) end)
end)
concommand.Add("chud_dragon_check", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    CheckDragonContent(function(message)
        print("[Dragon Style] " .. message)
        if IsValid(ply) then ply:ChatPrint("[Dragon Style] " .. message) end
    end)
end)
