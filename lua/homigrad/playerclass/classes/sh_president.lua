local CLASS = player.RegClass("president")

local PRESIDENT_MODEL = "models/male_09_vip/vip_player/male_09_vip_player.mdl"

local function ResetToDefaultBodygroups(ent)
    if not IsValid(ent) then return end

    ent:SetSkin(0)

    local count = ent:GetNumBodyGroups() or 0
    for id = 0, count - 1 do
        ent:SetBodygroup(id, 0)
    end
end

local function ApplyPresidentVIPModel(ply)
    if not IsValid(ply) then return end

    util.PrecacheModel(PRESIDENT_MODEL)
    ply:SetModel(PRESIDENT_MODEL)
    ply:SetSubMaterial()
    ResetToDefaultBodygroups(ply)
end

function CLASS.Off(self)

end

function CLASS.On(self)
    if CLIENT then return end

    ApplyAppearance(self, nil, nil, nil, true)
    ApplyPresidentVIPModel(self)

    local appearance = self.CurAppearance
        or (hg.Appearance and hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance())
        or {}

    -- Do not layer Remorse clothes/accessories over the VIP model.
    appearance.AAttachments = ""
    appearance.AColthes = ""

    self:SetNetVar("Accessories", "")
    self.CurAppearance = appearance
    self:SetNWString("PlayerName", self:Nick())

    -- Appearance/playerclass setup can run again during the same spawn tick.
    -- Re-assert the VIP model and its stock/default bodygroups afterward.
    timer.Simple(0, function()
        if not IsValid(self) then return end
        ApplyPresidentVIPModel(self)
    end)

    timer.Simple(0.25, function()
        if not IsValid(self) or not self:Alive() then return end
        if self.PlayerClassName ~= "president" then return end
        ApplyPresidentVIPModel(self)
    end)
end

function CLASS.Guilt(self, victim)
    if CLIENT then return end
    return 1
end
