-- Turf War class screen, adapted to VIP's validated loadout protocol.
local MODE=MODE
local classEndTime,selectedClass,selectTeam,selectModel=0,1,0,""
local ChudVIPClassMenu
local classes={}
local tex_gradient_r=Material("vgui/gradient-r")
local tex_gradient_l=Material("vgui/gradient-l")
local tex_gradient_d=Material("vgui/gradient-d")
local confirmedEnd, confirmedRole = 0, ""
local function SelectionEnd()
    return math.max(confirmedEnd, GetGlobalFloat("ChudVIPLoadoutEnds", 0))
end
local function SelectionRole()
    if confirmedEnd > CurTime() then return confirmedRole end
    return LocalPlayer():GetNWString("ChudVIPRole", "")
end
local function CanChoose()
    local p = LocalPlayer()
    if not IsValid(p) or CurTime() >= SelectionEnd() then return false end
    if confirmedEnd > CurTime() then return confirmedRole ~= "" end
    return zb.CROUND == "vip" and zb.ROUND_STATE == 0
        and p:GetNWBool("ChudVIPPreparing", false) and SelectionRole() ~= ""
end
local function BuildClasses()
    classes={}
    for _, key in ipairs(ChudVIPClassOrder) do
        local data=ChudVIPClasses[key]
        if data and data.role == (SelectionRole() == "SWAT" and "Guard" or SelectionRole()) then
            local items={}
            for _, weaponClass in ipairs(data.weapons or {}) do
                local weapon = weapons.GetStored(weaponClass)
                items[#items+1] = weapon and weapon.PrintName or weaponClass
            end
            classes[#classes+1]={key=key,name=data.name or key,description=data.role == "Guard" and "Protect the VIP and complete the route." or "Stop the VIP from completing the route.",items=table.concat(items,", ")}
        end
    end
    selectedClass=math.Clamp(selectedClass,1,math.max(#classes,1))
end
local function CloseClassMenu()
	if IsValid(ChudVIPClassMenu) then
		ChudVIPClassMenu:Remove()
	end
	ChudVIPClassMenu = nil
end

local function PickClass(index)
    if not CanChoose() then return end
    local class = classes[index]
    if not class then return end
    selectedClass = index
    surface.PlaySound("buttons/button14.wav")
    net.Start("chud_vip_loadout")
    net.WriteString(class.key)
    net.WriteUInt(#ChudVIPLoadoutSlots,4)
    for _, slot in ipairs(ChudVIPLoadoutSlots) do
        net.WriteString(slot.id)
        net.WriteString((ChudVIPClasses[class.key][slot.id] or {})[1] and ChudVIPClasses[class.key][slot.id][1].class or "")
    end
    net.SendToServer()
end

-- Picks the first font from the list whose text fits in maxW (so long lines never run off a row)
local function FitFont(text, maxW, fonts)
	for _, font in ipairs(fonts) do
		surface.SetFont(font)
		if surface.GetTextSize(text) <= maxW then
			return font
		end
	end

	return fonts[#fonts]
end

-- Planned: pick your weapon class. Same look as the vote screen. The character (gang and playermodel)
-- is random and only shown here; you choose the class. Keys 1-6 also pick.
-- Layout: a card on the left (your model + gang) and six evenly spaced rows on the right. Both span the
-- same height, and every size is relative to the screen so it fits any resolution.
local function OpenClassMenu()
    if not CanChoose() then return end
    BuildClasses()
    local isVIP = SelectionRole() == "VIP"
    if #classes == 0 and not isVIP then return end
    classEndTime=SelectionEnd()
    selectTeam=SelectionRole() == "Attacker" and 0 or 1
    selectModel=LocalPlayer():GetModel()
	CloseClassMenu()

	local teamColor = (selectTeam == 0) and Color(190, 0, 0) or Color(45,115,255)
	local teamText = isVIP and "YOU ARE THE VIP" or ((selectTeam == 0) and "You are an Angry Chud" or "You are a Guard")
	local count = #classes

	-- geometry
	local top = ScrH() * 0.17
	local gap = ScrH() * 0.012
	local rowH = math.min(ScrH()*0.1, (ScrH()*0.66 - math.max(count-1,0)*gap)/math.max(count,1))
	local totalH = count * rowH + (count - 1) * gap
	local cardX, cardY = ScrW() * 0.03, top
	local cardW, cardH = ScrW() * 0.26, math.max(totalH, ScrH()*0.60)
	if isVIP then cardX = ScrW() * 0.32 cardW = ScrW() * 0.36 cardH = ScrH() * 0.66 end
	local rowX = ScrW() * 0.32
	local rowW = ScrW() * 0.65

	-- fonts sized from the row height, so text never collides with the next line
	local function makeFont(name, factor, weight)
		surface.CreateFont(name, {
			font = "Courier Prime",
			size = math.max(math.floor(rowH * factor), 10),
			weight = weight or 500,
			extended = true,
			antialias = true,
		})
	end

	makeFont("ChudVIP_ClassName", 0.28, 600)
	makeFont("ChudVIP_ClassText", 0.15)
	makeFont("ChudVIP_ClassTextSmall", 0.12)
	makeFont("ChudVIP_ClassLabel", 0.26, 600)
	makeFont("ChudVIP_ClassLabelSmall", 0.2, 600)

	ChudVIPClassMenu = vgui.Create("DFrame")
	ChudVIPClassMenu:SetSize(ScrW(), ScrH())
	ChudVIPClassMenu:SetPos(0, 0)
	ChudVIPClassMenu:SetTitle("")
	ChudVIPClassMenu:ShowCloseButton(false)
	ChudVIPClassMenu:SetDraggable(false)
	ChudVIPClassMenu:MakePopup()
	ChudVIPClassMenu.OpenTime = CurTime()
	ChudVIPClassMenu.Paint = function(self, w, h)
		local elapsed = CurTime() - (self.OpenTime or CurTime())
		local titleFrac = math.Clamp(elapsed / 0.4, 0, 1)
		local pulse = 0.5 + math.sin(CurTime() * 4) * 0.5
		local timerLeft = math.max(math.ceil(classEndTime - CurTime()), 0)
		local timerColor = timerLeft <= 3 and Color(255, 120 + pulse * 80, 120 + pulse * 80) or Color(225, 225, 225)

		hg.DrawBlur(self, 5)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 19, 235))
		surface.SetDrawColor(18, 18, 18, 65)
		surface.SetMaterial(tex_gradient_r)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetMaterial(tex_gradient_l)
		surface.DrawTexturedRect(0, 0, w, h)
		surface.SetDrawColor(100, 100, 100, 35)
		surface.SetMaterial(tex_gradient_d)
		surface.DrawTexturedRect(0, 0, w, h)

		draw.SimpleText(isVIP and "YOU ARE THE VIP" or "CHOOSE YOUR CLASS", "ZCity_Menu_Small", w * 0.5, h * 0.075 - (1 - titleFrac) * 24, Color(225, 225, 225, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(isVIP and "P22 and blue armor. Stay with your guards and survive." or "Pick your loadout. No pick uses the first loadout.", "ZCity_Menu_Settings_Small", w * 0.5, h * 0.118 - (1 - titleFrac) * 18, Color(200, 200, 200, 255 * titleFrac), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- left card: same box style as the rows, spanning the same height
		draw.RoundedBox(0, cardX, cardY, cardW, cardH, Color(0, 0, 0, 190))
		surface.SetDrawColor(225, 225, 225, 110)
		surface.DrawOutlinedRect(cardX, cardY, cardW, cardH, 1)
		surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, 255)
		surface.DrawRect(cardX, cardY, cardW, math.max(3, h * 0.003))
		local labelFont = FitFont(teamText, cardW - 32, {"ChudVIP_ClassLabel", "ChudVIP_ClassLabelSmall", "ChudVIP_ClassText"})
		draw.SimpleText(teamText, labelFont, cardX + cardW * 0.5, cardY + cardH * 0.93, teamColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText("TIME LEFT: " .. timerLeft, "ZCity_Menu_Small", w * 0.5, h * 0.92, timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	ChudVIPClassMenu.Think = function()
		if not CanChoose() and IsValid(ChudVIPClassMenu) then
			CloseClassMenu()
		end
	end
	ChudVIPClassMenu.OnKeyCodePressed = function(self, key)
		local index = key - KEY_1 + 1
		if index >= 1 and index <= count then
			PickClass(index)
		end
	end

	-- the model you will spawn with (chosen by the server, you do not pick it), inside the card
	if selectModel ~= "" then
		local modelW = cardW - 16
		local modelH = cardH * 0.84 - 8

		local modelPanel = vgui.Create("DModelPanel", ChudVIPClassMenu)
		modelPanel:SetPos(cardX + 8, cardY + 8)
		modelPanel:SetSize(modelW, modelH)
		modelPanel:SetModel(selectModel)
        -- The server assigns the role appearance while players are spectators.
        -- Keep following it as model, clothing and class networking arrive.
        modelPanel.PreDrawModel = function(self, entity)
            local source = LocalPlayer()
            if not IsValid(source) then return end
            if entity:GetModel() ~= source:GetModel() then
                entity:SetModel(source:GetModel())
                entity:SetSequence(entity:LookupSequence("idle_all_01") or 0)
            end
            entity:SetSkin(source:GetSkin())
            entity:SetMaterial(source:GetMaterial())
            for _, group in ipairs(source:GetBodyGroups()) do
                entity:SetBodygroup(group.id, source:GetBodygroup(group.id))
            end
            for index = 0, #source:GetMaterials() - 1 do
                entity:SetSubMaterial(index, source:GetSubMaterial(index) or "")
            end
            entity.GetPlayerColor = function() return source:GetPlayerColor() end
            entity:SetNWVector("PlayerColor", source:GetPlayerColor())
            entity.CurAppearance = source.CurAppearance
            entity.shouldTransmit = true
        end
        modelPanel.PostDrawModel = function(self, entity)
            local source = LocalPlayer()
            if not IsValid(source) or not DrawAccesories then return end
            local accessories = source:GetNetVar("Accessories", {})
            if not istable(accessories) then accessories = {accessories} end
            for _, key in ipairs(accessories) do
                local data = hg.Accessories[key]
                if data then DrawAccesories(entity, entity, key, data, false, true) end
            end
        end
        local function RemovePreviewAccessories(entity)
            if not IsValid(entity) then return end
            for _, accessory in pairs(entity.modelAccess or {}) do
                if IsValid(accessory) then accessory:Remove() end
            end
        end
        modelPanel.OnRemove = function(self)
            RemovePreviewAccessories(self:GetEntity())
            if IsValid(self:GetEntity()) then self:GetEntity():Remove() end
        end


		local ent = modelPanel:GetEntity()
		if IsValid(ent) then
			local sequence = ent:LookupSequence("idle_all_01")
			if sequence and sequence > 0 then
				ent:SetSequence(sequence)
			end

			-- Put the camera straight in front of the model, far enough that the whole body fills
			-- about 85% of the panel's height. (The panel's FOV is horizontal, so a tall narrow panel
			-- shows more vertically: visible height = 2 * dist * tan(fov / 2) * (panel height / panel width).)
			local mins, maxs = ent:GetRenderBounds()
			local height = math.max(maxs.z - mins.z, 1)
			local fov = 30
			local dist = (height * 1.18) / (2 * math.tan(math.rad(fov * 0.5)) * (modelH / modelW))
			local center = (mins + maxs) * 0.5

			modelPanel:SetFOV(fov)
			modelPanel:SetCamPos(center + Vector(dist, 0, 0))
			modelPanel:SetLookAt(center)
		end

		modelPanel.LayoutEntity = function(self, entity)
			self:RunAnimation()
			entity:SetAngles(Angle(0, 25 + math.sin(CurTime() * 0.7) * 12, 0))
		end
	end

	for i, class in ipairs(classes) do
		local button = vgui.Create("DButton", ChudVIPClassMenu)
		button:SetSize(rowW, rowH)
		button:SetPos(rowX, top + (i - 1) * (rowH + gap))
		button:SetText("")
		button.HoverFrac = 0
		button.SelectFrac = 0
		button.Think = function(self)
			self.HoverFrac = Lerp(FrameTime() * 10, self.HoverFrac, self:IsHovered() and 1 or 0)
			self.SelectFrac = Lerp(FrameTime() * 10, self.SelectFrac, selectedClass == i and 1 or 0)
		end
		button.Paint = function(self, w, h)
			local picked = selectedClass == i
			local glow = math.max(self.HoverFrac, self.SelectFrac)
			local pad = h * 0.22
			local nameX = pad + h * 0.45
			local textMax = w - pad * 2

			draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 190 + glow * 35))

			if picked then
				surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
				surface.DrawRect(0, 0, math.max(4, h * 0.05), h)
			else
				surface.SetDrawColor(225, 225, 225, 110 + glow * 120)
				surface.DrawOutlinedRect(0, 0, w, h, 1)
			end

			draw.SimpleText(tostring(i), "ChudVIP_ClassName", pad, h * 0.29, picked and teamColor or Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(class.name, "ChudVIP_ClassName", nameX, h * 0.29, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if picked then
				draw.SimpleText("SELECTED", "ChudVIP_ClassText", w - pad, h * 0.29, teamColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			local fonts = {"ChudVIP_ClassText", "ChudVIP_ClassTextSmall"}
			local itemsLine = "You get: " .. class.items .. ", " .. "Hands"

			draw.SimpleText(class.description, FitFont(class.description, textMax, fonts), nameX, h * 0.6, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(itemsLine, FitFont(itemsLine, textMax - (nameX - pad), fonts), nameX, h * 0.83, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			PickClass(i)
		end
	end
end


local pending=false
net.Receive("chud_vip_selection", function()
    confirmedEnd, confirmedRole = net.ReadFloat(), net.ReadString()
    ChudVIPMusicEnd = confirmedEnd
    selectedClass = 1
    pending = true
    if CanChoose() then OpenClassMenu() end
end)

net.Receive("chud_vip_prepare",function()
    MODE.IntroAt=net.ReadFloat()
    selectedClass=1 pending=true
end)
net.Receive("chud_vip_menu",function() OpenClassMenu() end)
concommand.Add("chud_vip_loadout",function() OpenClassMenu() end)
hook.Add("Think","ChudVIPAutoLoadout",function()
    if pending then
        if zb.CROUND~="vip" or zb.ROUND_STATE~=0 or CurTime()>=GetGlobalFloat("ChudVIPLoadoutEnds",0) then pending=false
        elseif CanChoose() then pending=false OpenClassMenu() end
    end
    if CanChoose() and not IsValid(ChudVIPClassMenu) then OpenClassMenu() end
    if IsValid(ChudVIPClassMenu) and not CanChoose() then CloseClassMenu() end
end)
hook.Add("OnScreenSizeChanged","ChudVIPClassResize",function()
    if IsValid(ChudVIPClassMenu) then OpenClassMenu() end
end)
