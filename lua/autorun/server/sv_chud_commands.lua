local function Reply(ply, text)
    if IsValid(ply) then ply:ChatPrint(text) else print(text) end
end

concommand.Add("coins", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then
        Reply(ply, "Only admins can give COIN.")
        return
    end
    local amount = tonumber(args[#args])
    if #args < 2 or not amount or amount ~= amount or amount <= 0 or amount > 1000000000 or amount ~= math.floor(amount) then
        Reply(ply, 'Usage: coins "player name" <positive whole amount>')
        return
    end
    local name = string.lower(table.concat(args, " ", 1, #args - 1))
    local exact, partial = {}, {}
    for _, target in ipairs(player.GetHumans()) do
        local nick = string.lower(target:Nick())
        if nick == name or target:SteamID64() == name then
            exact[#exact + 1] = target
        elseif string.find(nick, name, 1, true) then
            partial[#partial + 1] = target
        end
    end
    local matches = #exact > 0 and exact or partial
    if #matches ~= 1 then
        Reply(ply, #matches == 0 and "No matching player found." or "Multiple players match. Use the full name or SteamID64.")
        return
    end
    local target = matches[1]
    if not ChudCoin or not ChudCoin.Add or not ChudCoin.Add(target, amount) then
        Reply(ply, "Could not save COIN. Check the balance limit and server database.")
        return
    end
    Reply(ply, "Gave " .. amount .. " COIN to " .. target:Nick() .. ".")
    if target ~= ply then Reply(target, "You received " .. amount .. " COIN.") end
end)

-- Self-only death command: remove the body, never the player entity.
concommand.Add("didimoney", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if (ply.ChudDidimoneyNext or 0) > CurTime() then return end
    ply.ChudDidimoneyNext = CurTime() + 2
    if hook.Run("CanPlayerSuicide", ply) == false then return end
    if not hg or not hg.Fake or not ply.organism then return end
    hg.Fake(ply)
    local body = ply.FakeRagdoll
    ply:Kill()
    local function RemoveBody()
        if not IsValid(ply) or ply:Alive() then return end
        local bodies = {body, ply.RagdollDeath, ply.FakeRagdoll,
            ply:GetNWEntity("RagdollDeath"), ply:GetNWEntity("FakeRagdoll")}
        for _, rag in pairs(bodies) do
            if IsValid(rag) and not rag:IsPlayer() then
                -- Use the normal full-body gib effect when this corpse is removed.
                rag.hg_no_fullbody_remove_gib = nil
                rag.override = nil
                if hg.TrackFullBodyRagdollRemove then hg.TrackFullBodyRagdollRemove(rag) end
                rag:Remove()
            end
        end
        ply.RagdollDeath, ply.FakeRagdoll = nil, nil
        ply:SetNWEntity("RagdollDeath", NULL)
        ply:SetNWEntity("FakeRagdoll", NULL)
        if hg.ragdollFake then hg.ragdollFake[ply] = nil end
    end
    timer.Simple(0, RemoveBody)
end)
