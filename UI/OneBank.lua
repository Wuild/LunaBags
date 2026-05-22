local _, ns = ...

local OneBank = {
    frame = nil,
    buttons = {},
    bagButtons = {},
    columns = 11,
    slotSize = 36,
    spacing = 4,
    searchText = "",
    searchVisible = false,
    showBagRail = true,
    sortingActive = false,
}

ns.OneBank = OneBank

local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }
local BANK_BAG_SLOTS = { 5, 6, 7, 8, 9, 10, 11 }

local function GetConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.oneBank = addon.db.profile.oneBank or {}
    return addon.db.profile.oneBank
end

local function GetNumSlotsInBag(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end
    return GetContainerNumSlots(bagID) or 0
end

local function GetItemInfoFromBag(bagID, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bagID, slot)
    end
    local texture, count, locked, quality = GetContainerItemInfo(bagID, slot)
    if not texture then
        return nil
    end
    return { iconFileID = texture, stackCount = count or 1, quality = quality, isLocked = locked }
end

local function GetItemLinkFromBag(bagID, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slot)
    end
    return GetContainerItemLink and GetContainerItemLink(bagID, slot)
end

local function EnsureItemCooldown(button)
    local cd = button.cooldown or button.Cooldown or _G[button:GetName() .. "Cooldown"]
    if cd then
        button.cooldown = cd
        return cd
    end
    cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:SetAllPoints(button)
    button.cooldown = cd
    return cd
end

local function ClearItemCooldown(button)
    if not button or not button.cooldown then return end
    if CooldownFrame_Set then
        CooldownFrame_Set(button.cooldown, 0, 0, 0)
    else
        button.cooldown:SetCooldown(0, 0)
    end
end

local function UpdateItemCooldown(button, bagID, slot)
    if not button or not bagID or not slot then
        return
    end
    local cd = EnsureItemCooldown(button)
    if not cd then return end
    local start, duration, enable
    if C_Container and C_Container.GetContainerItemCooldown then
        start, duration, enable = C_Container.GetContainerItemCooldown(bagID, slot)
    else
        start, duration, enable = GetContainerItemCooldown(bagID, slot)
    end
    start = start or 0
    duration = duration or 0
    enable = enable or 0
    if CooldownFrame_Set then
        CooldownFrame_Set(cd, start, duration, enable)
    else
        cd:SetCooldown(start, duration)
    end
end

local function ItemMatchesSearch(item, searchText)
    if searchText == "" then
        return true
    end
    if not item then
        return false
    end
    local needle = searchText:lower()
    local name = item.name or (item.itemLink and GetItemInfo(item.itemLink))
    if name and name:lower():find(needle, 1, true) then
        return true
    end
    if item.itemLink and item.itemLink:lower():find(needle, 1, true) then
        return true
    end
    return item.itemID and tostring(item.itemID):find(needle, 1, true) or false
end

local function ContainerIDToInventoryIDCompat(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(bagID)
    end
    if ContainerIDToInventoryID then
        return ContainerIDToInventoryID(bagID)
    end
    return nil
end

local function BankBagToInventorySlotCompat(bagID)
    local inv = ContainerIDToInventoryIDCompat(bagID)
    if inv then
        return inv
    end
    if BankButtonIDToInvSlotID then
        return BankButtonIDToInvSlotID((bagID - 4), 1)
    end
    return nil
end

local function ApplyButtonStyle(button)
    if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
        ns.ItemButtonStyle.Apply(button)
        return
    end
    if not button.StyleBG then
        button.StyleBG = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBG:SetAllPoints(button)
        button.StyleBG:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        button.StyleBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        button.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
    end
    if not button.StyleBorder then
        button.StyleBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBorder:SetAllPoints(button)
        button.StyleBorder:SetFrameLevel(button:GetFrameLevel() + 2)
        button.StyleBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button.StyleBorder:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)
    end
    if not button.StyleGlow then
        button.StyleGlow = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.StyleGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.StyleGlow:SetFrameLevel(button:GetFrameLevel() + 3)
        button.StyleGlow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        button.StyleGlow:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.85)
        button.StyleGlow:Hide()
    end
    local icon = button.icon or button.Icon or _G[button:GetName() .. "IconTexture"] or _G[button:GetName() .. "Icon"]
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 4)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -2)
        icon:SetTexCoord(0, 1, 0, 1)
        if not button.IconMask then
            local mask = button:CreateMaskTexture(nil, "ARTWORK")
            mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            mask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            button.IconMask = mask
            if icon.AddMaskTexture then
                icon:AddMaskTexture(mask)
            end
        end
    end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetTexture(nil); normal:Hide() end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then pushed:SetTexture(nil); pushed:Hide() end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then highlight:SetTexture(nil); highlight:Hide() end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then checked:SetTexture(nil); checked:Hide() end
    if button.IconBorder then button.IconBorder:SetAlpha(0); button.IconBorder:Hide() end
    if button.Background then button.Background:SetTexture(nil); button.Background:Hide() end
    if button.IconOverlay then button.IconOverlay:SetTexture(nil); button.IconOverlay:Hide() end
    if button.searchOverlay then button.searchOverlay:Hide() end

    if not button.StyleStateHooks then
        local function Brighten(v, amount)
            return math.min(1, (v or 0) + amount)
        end
        local function SetIdle(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
            self.StyleBorder:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)
            if self.StyleGlow then self.StyleGlow:Hide() end
        end
        local function SetHover(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self.StyleBG:SetBackdropColor(0.17, 0.17, 0.17, 0.95)
            self.StyleBorder:SetBackdropBorderColor(0.44, 0.44, 0.44, 0.98)
            if self.StyleGlow then
                self.StyleGlow:SetBackdropBorderColor(
                    Brighten(0.34, 0.18),
                    Brighten(0.34, 0.18),
                    Brighten(0.34, 0.18),
                    0.9
                )
                self.StyleGlow:Show()
            end
        end
        local function SetDrag(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self.StyleBG:SetBackdropColor(0.20, 0.20, 0.20, 0.98)
            self.StyleBorder:SetBackdropBorderColor(0.54, 0.54, 0.54, 1)
            if self.StyleGlow then self.StyleGlow:Show() end
        end
        button:HookScript("OnEnter", SetHover)
        button:HookScript("OnLeave", SetIdle)
        button:HookScript("OnMouseDown", SetDrag)
        button:HookScript("OnMouseUp", function(self)
            if self:IsMouseOver() then SetHover(self) else SetIdle(self) end
        end)
        button:HookScript("OnDragStart", SetDrag)
        button:HookScript("OnReceiveDrag", function(self)
            if self:IsMouseOver() then SetHover(self) else SetIdle(self) end
        end)
        button:HookScript("OnHide", SetIdle)
        button.StyleStateHooks = true
        SetIdle(button)
    end
end

local function ResolveQualityBorderColor(quality)
    if not quality or quality <= 1 then
        return 0.34, 0.34, 0.34, 0.95
    end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r and g and b then
            return r, g, b, 1
        end
    end
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r and g and b then
            return r, g, b, 1
        end
    end
    return 0.34, 0.34, 0.34, 0.95
end

local function UpdateButtonStyleBorderForItem(button, item)
    if not button or not button.StyleBorder then
        return
    end
    if ns.ItemButtonStyle and ns.ItemButtonStyle.UpdateBorderForItem then
        ns.ItemButtonStyle.UpdateBorderForItem(button, item, true)
        return
    end
    local quality = item and item.quality or nil
    if quality == nil and item and item.itemLink and GetItemInfo then
        local _, _, q = GetItemInfo(item.itemLink)
        quality = q
    end
    local r, g, b, a = ResolveQualityBorderColor(quality)
    button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
    if button.IconBorder then button.IconBorder:SetAlpha(0); button.IconBorder:Hide() end
    if button.Background then button.Background:SetTexture(nil); button.Background:Hide() end
    if button.IconOverlay then button.IconOverlay:SetTexture(nil); button.IconOverlay:Hide() end
end

function OneBank:UpdateSearchLayout()
    if not self.frame or not self.frame.content then
        return
    end
    local topInset = self.searchVisible and 34 or 12
    self.frame.content:ClearAllPoints()
    self.frame.content:SetPoint("TOPLEFT", self.frame.DarkInset, "TOPLEFT", 12, -topInset)
    self.frame.content:SetPoint("BOTTOMRIGHT", self.frame.DarkInset, "BOTTOMRIGHT", -12, 12)
    if self.frame.SearchPanel then
        self.frame.SearchPanel:SetShown(self.searchVisible)
    end
end

function OneBank:CreateFrame()
    if self.frame then
        return
    end

    local frame = _G.LunaBagsOneBankFrame
    if not frame then
        frame = CreateFrame("Frame", "LunaBagsOneBankFrame", UIParent, "UIPanelDialogTemplate")
        frame:SetSize(520, 500)
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 34, 126)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("HIGH")
        frame:Hide()
        frame.content = CreateFrame("Frame", nil, frame)
        frame.content:SetPoint("TOPLEFT", 8, -48)
        frame.content:SetPoint("BOTTOMRIGHT", -8, 36)
    end

    if UISpecialFrames and frame.GetName then
        local frameName = frame:GetName()
        local exists = false
        for _, n in ipairs(UISpecialFrames) do
            if n == frameName then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(UISpecialFrames, frameName)
        end
    end

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        OneBank:SavePosition()
    end)
    frame.content = frame.Content or frame.content

    if frame.TitleText then frame.TitleText:Hide() end
    if frame.TitleBg then frame.TitleBg:Hide() end
    if frame.TopLeftCorner then frame.TopLeftCorner:Hide() end
    if frame.TopRightCorner then frame.TopRightCorner:Hide() end
    if frame.TopBorder then frame.TopBorder:Hide() end
    if frame.LeftBorder then frame.LeftBorder:Hide() end
    if frame.RightBorder then frame.RightBorder:Hide() end
    if frame.BottomBorder then frame.BottomBorder:Hide() end
    if frame.BottomLeftCorner then frame.BottomLeftCorner:Hide() end
    if frame.BottomRightCorner then frame.BottomRightCorner:Hide() end
    if frame.Bg then frame.Bg:Hide() end
    if frame.Header then
        frame.Header:Hide()
    end
    if frame.Header and frame.Header.SearchBox then
        frame.Header.SearchBox:Hide()
        frame.Header.SearchBox:EnableMouse(false)
    end
    if frame.Header and frame.Header.SearchToggle then
        frame.Header.SearchToggle:Hide()
        frame.Header.SearchToggle:EnableMouse(false)
    end
    if frame.Header and frame.Header.SortButton then
        frame.Header.SortButton:Hide()
        frame.Header.SortButton:EnableMouse(false)
    end

    if not frame.WindowBg then
        frame.WindowBg = frame:CreateTexture(nil, "BACKGROUND")
        frame.WindowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.WindowBg:SetAllPoints(frame)
        frame.WindowBg:SetVertexColor(0.12, 0.12, 0.12, 0.72)
    end
    if not frame.TitleBarBg then
        frame.TitleBarBg = frame:CreateTexture(nil, "ARTWORK")
        frame.TitleBarBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.TitleBarBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TitleBarBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TitleBarBg:SetHeight(28)
        frame.TitleBarBg:SetVertexColor(0.07, 0.07, 0.07, 0.78)
    end
    if not frame.DarkInset then
        frame.DarkInset = frame:CreateTexture(nil, "BORDER")
        frame.DarkInset:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.DarkInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
        frame.DarkInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 38)
        frame.DarkInset:SetVertexColor(0.02, 0.02, 0.02, 0.64)
    end
    if not frame.StatusBg then
        frame.StatusBg = frame:CreateTexture(nil, "ARTWORK")
        frame.StatusBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.StatusBg:SetPoint("TOPLEFT", frame.DarkInset, "BOTTOMLEFT", 0, 0)
        frame.StatusBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame.StatusBg:SetVertexColor(0.10, 0.10, 0.10, 0.70)
    end
    if not frame.OuterBorder then
        frame.OuterBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.OuterBorder:SetAllPoints(frame)
        frame.OuterBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        frame.OuterBorder:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
    end

    if not frame.CustomTitle then
        frame.CustomTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.CustomTitle:SetPoint("CENTER", frame.TitleBarBg, "CENTER", 0, 0)
    end
    frame.CustomTitle:SetText(BANK or "Bank")

    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end
    frame.CloseButton:ClearAllPoints()
    frame.CloseButton:SetPoint("TOPRIGHT", frame.TitleBarBg, "TOPRIGHT", -2, 2)
    frame.CloseButton:SetScript("OnClick", LunaBagsOneBank_Close)

    if not frame.SearchPanel then
        frame.SearchPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.SearchPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
        frame.SearchPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -29)
        frame.SearchPanel:SetHeight(28)
        frame.SearchPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame.SearchPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.82)
        frame.SearchPanel:SetBackdropBorderColor(0.26, 0.26, 0.26, 0.95)
    end

    if not frame.SearchEditBackdrop then
        frame.SearchEditBackdrop = CreateFrame("Frame", nil, frame.SearchPanel)
        frame.SearchEditBackdrop:SetPoint("TOPLEFT", frame.SearchPanel, "TOPLEFT", 6, -3)
        frame.SearchEditBackdrop:SetPoint("BOTTOMRIGHT", frame.SearchPanel, "BOTTOMRIGHT", -6, 3)
    end
    if not frame.SearchEditBox then
        frame.SearchEditBox = CreateFrame("EditBox", "LunaBagsOneBankSearchEditBox", frame.SearchEditBackdrop, "InputBoxTemplate")
        frame.SearchEditBox:SetAutoFocus(false)
        frame.SearchEditBox:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
        frame.SearchEditBox:SetScript("OnEnterPressed", function(editBox) editBox:ClearFocus() end)
        frame.SearchEditBox:SetScript("OnTextChanged", LunaBagsOneBank_SearchChanged)
    end
    frame.SearchEditBox:ClearAllPoints()
    frame.SearchEditBox:SetPoint("TOPLEFT", frame.SearchEditBackdrop, "TOPLEFT", 2, -1)
    frame.SearchEditBox:SetPoint("BOTTOMRIGHT", frame.SearchEditBackdrop, "BOTTOMRIGHT", -2, 1)
    frame.SearchEditBox:SetTextInsets(0, 0, 0, 0)
    frame.SearchEditBox:SetFontObject("GameFontHighlightSmall")
    frame.SearchEditBox:SetText(self.searchText or "")
    frame.SearchEditBox.Left:Hide()
    frame.SearchEditBox.Middle:Hide()
    frame.SearchEditBox.Right:Hide()
    frame.SearchPanel:SetShown(self.searchVisible == true)

    if not frame.SearchToggleButton then
        frame.SearchToggleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.SearchToggleButton:SetText("")
    frame.SearchToggleButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    frame.SearchToggleButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    frame.SearchToggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.SearchToggleButton:SetSize(18, 18)
    frame.SearchToggleButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 49, 0)
    frame.SearchToggleButton:SetScript("OnClick", LunaBagsOneBank_SearchToggleClicked)

    if not frame.SortButton then
        frame.SortButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.SortButton:SetText("")
    frame.SortButton:SetNormalTexture("Interface\\AddOns\\LunaBags\\external\\Bagnon\\art\\broom")
    frame.SortButton:SetPushedTexture("Interface\\AddOns\\LunaBags\\external\\Bagnon\\art\\broom")
    frame.SortButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.SortButton:SetSize(18, 18)
    frame.SortButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 71, 0)
    frame.SortButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.SortButton:SetScript("OnClick", LunaBagsOneBank_SortButtonClicked)

    if not frame.CharacterButton then
        frame.CharacterButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.CharacterButton.Icon = frame.CharacterButton:CreateTexture(nil, "ARTWORK")
        frame.CharacterButton.Icon:SetPoint("TOPLEFT", frame.CharacterButton, "TOPLEFT", 0, 0)
        frame.CharacterButton.Icon:SetPoint("BOTTOMRIGHT", frame.CharacterButton, "BOTTOMRIGHT", 0, 0)
    end
    frame.CharacterButton:SetText("")
    frame.CharacterButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.CharacterButton:SetSize(18, 18)
    frame.CharacterButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 5, 0)
    frame.CharacterButton.Icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    do
        local classToken = select(2, UnitClass("player"))
        local coords = CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken]
        if coords then
            frame.CharacterButton.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            frame.CharacterButton.Icon:SetTexCoord(0, 1, 0, 1)
        end
    end
    frame.CharacterButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bank - Current Character")
        GameTooltip:Show()
    end)
    frame.CharacterButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.CharacterButton:SetScript("OnClick", function() end)

    if not frame.RailToggleButton then
        frame.RailToggleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.RailToggleButton:SetText("")
    frame.RailToggleButton:SetNormalTexture("Interface\\Buttons\\Button-Backpack-Up")
    frame.RailToggleButton:SetPushedTexture("Interface\\Buttons\\Button-Backpack-Up")
    frame.RailToggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.RailToggleButton:SetSize(18, 18)
    frame.RailToggleButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 27, 0)
    frame.RailToggleButton:SetScript("OnClick", LunaBagsOneBank_RailToggleClicked)

    if not frame.SettingsButton then
        frame.SettingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.SettingsButton:SetText("")
    frame.SettingsButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    frame.SettingsButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    frame.SettingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.SettingsButton:SetSize(18, 18)
    frame.SettingsButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 93, 0)
    frame.SettingsButton:SetScript("OnClick", function()
        if ns.OpenConfig then ns.OpenConfig() end
    end)

    if frame.MoneyBar then
        frame.MoneyBar:ClearAllPoints()
        frame.MoneyBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
        frame.MoneyBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
        frame.MoneyBar:SetHeight(28)
        if frame.MoneyBar.SetStatusBarColor then
            frame.MoneyBar:SetMinMaxValues(0, 1)
            frame.MoneyBar:SetValue(0)
            frame.MoneyBar:SetStatusBarColor(0, 0, 0, 0)
        end
        if frame.MoneyBar.GetStatusBarTexture then
            local tex = frame.MoneyBar:GetStatusBarTexture()
            if tex then tex:SetAlpha(0) end
        end
        if frame.MoneyBar.Label then frame.MoneyBar.Label:SetText(BANK or "Bank") end
        if frame.MoneyBar.Text then
            frame.MoneyBar.Text:SetFontObject("GameFontNormal")
            frame.MoneyBar.Text:SetTextColor(1, 1, 1, 1)
        end
    end

    if not frame.BagSlots then
        frame.BagSlots = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    frame.BagSlots:ClearAllPoints()
    frame.BagSlots:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)

    self.frame = frame
    self:ApplySettings()
    self:UpdateSearchLayout()
end

function OneBank:AcquireBagButton(index)
    local btn = self.bagButtons[index]
    if btn then return btn end

    btn = CreateFrame("Button", "LunaBagsBankBagSlotButton" .. index, self.frame.BagSlots, "BackdropTemplate")
    btn:SetSize(34, 34)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 3, -3)
    btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    btn.icon:SetTexCoord(0, 1, 0, 1)
    ApplyButtonStyle(btn)
    if not btn.UnpurchasedOverlay then
        btn.UnpurchasedOverlay = btn:CreateTexture(nil, "OVERLAY")
        btn.UnpurchasedOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.UnpurchasedOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        btn.UnpurchasedOverlay:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        btn.UnpurchasedOverlay:SetVertexColor(0.70, 0.10, 0.10, 0.38)
        btn.UnpurchasedOverlay:Hide()
    end
    btn:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if button.isPurchased == false then
            local nextIndex = (GetNumBankSlots and (GetNumBankSlots() or 0) or 0) + 1
            local cost = GetBankSlotCost and GetBankSlotCost(nextIndex) or nil
            GameTooltip:SetText(BANKSLOTPURCHASE or "Purchase Bank Slot")
            if cost and SetTooltipMoney then
                SetTooltipMoney(GameTooltip, cost)
            end
            GameTooltip:AddLine("Click to purchase this bank bag slot.", 0.85, 0.85, 0.85)
        elseif button.invSlot then
            GameTooltip:SetInventoryItem("player", button.invSlot)
        else
            GameTooltip:SetText(BANK or "Bank")
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(button)
        if button.isPurchased == false then
            if StaticPopup_Show and _G["CONFIRM_BUY_BANK_SLOT"] then
                StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
            elseif PurchaseSlot then
                PurchaseSlot()
            end
            return
        end
        if not button.invSlot then return end
        if CursorHasItem() then
            PutItemInBag(button.invSlot)
        else
            PickupBagFromSlot(button.invSlot)
        end
    end)
    btn:SetScript("OnDragStart", function(button)
        if button.invSlot then PickupBagFromSlot(button.invSlot) end
    end)
    btn:SetScript("OnReceiveDrag", function(button)
        if button.invSlot then PutItemInBag(button.invSlot) end
    end)
    self.bagButtons[index] = btn
    return btn
end

function OneBank:RefreshBagSlots()
    if not self.frame or not self.frame.BagSlots then return end
    if not self.showBagRail then
        self.frame.BagSlots:Hide()
        return
    end
    self.frame.BagSlots:Show()

    local size, spacing, pad = 34, 4, 6
    local purchasedSlots = GetNumBankSlots and (GetNumBankSlots() or 0) or 0
    for i, bagID in ipairs(BANK_BAG_SLOTS) do
        local button = self:AcquireBagButton(i)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad + (i - 1) * (size + spacing), -pad)
        button.bagID = bagID
        button.invSlot = BankBagToInventorySlotCompat(bagID)
        button.isPurchased = i <= purchasedSlots
        local icon
        if button.isPurchased then
            icon = button.invSlot and GetInventoryItemTexture("player", button.invSlot)
            button.icon:SetTexture(icon)
            button:SetAlpha(1)
            if button.UnpurchasedOverlay then
                button.UnpurchasedOverlay:Hide()
            end
            if button.StyleBorder then
                button.StyleBorder:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)
            end
        else
            button.icon:SetTexture(nil)
            button:SetAlpha(0.95)
            if button.UnpurchasedOverlay then
                button.UnpurchasedOverlay:Show()
            end
            if button.StyleBorder then
                button.StyleBorder:SetBackdropBorderColor(0.56, 0.44, 0.14, 0.95)
            end
        end
        button:Show()
    end
    self.frame.BagSlots:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    self.frame.BagSlots:SetBackdropColor(0.08, 0.08, 0.08, 0.84)
    self.frame.BagSlots:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)
    self.frame.BagSlots:SetWidth(pad * 2 + #BANK_BAG_SLOTS * size + (#BANK_BAG_SLOTS - 1) * spacing)
    self.frame.BagSlots:SetHeight(size + pad * 2)
end

function OneBank:AcquireButton(index)
    local btn = self.buttons[index]
    if btn then return btn end

    local name = "LunaBagsBankItemButton" .. index
    btn = CreateFrame("ItemButton", name, self.frame.content, "ContainerFrameItemButtonTemplate")
    btn:SetSize(self.slotSize, self.slotSize)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)
    btn:SetScript("OnEnter", LunaBagsOneBank_ItemButtonOnEnter)
    btn:SetScript("OnLeave", LunaBagsOneBank_ItemButtonOnLeave)
    btn:SetScript("OnClick", LunaBagsOneBank_ItemButtonOnClick)
    btn:SetScript("OnDragStart", LunaBagsOneBank_ItemButtonOnDragStart)
    btn:SetScript("OnReceiveDrag", LunaBagsOneBank_ItemButtonOnReceiveDrag)

    local icon = btn.icon or _G[name .. "IconTexture"] or _G[name .. "Icon"]
    if not icon then
        icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon
    local count = btn.Count or _G[name .. "Count"]
    if not count then
        count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    btn.count = count
    if not btn.DebugSlotText then
        btn.DebugSlotText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.DebugSlotText:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        btn.DebugSlotText:SetTextColor(0.95, 0.82, 0.10, 0.95)
        btn.DebugSlotText:SetJustifyH("LEFT")
    end
    ApplyButtonStyle(btn)
    self.buttons[index] = btn
    return btn
end

function OneBank:BuildLiveSlots()
    local slots = {}
    for _, bagID in ipairs(BANK_BAGS) do
        local slotCount = GetNumSlotsInBag(bagID)
        for slot = 1, slotCount do
            local itemInfo = GetItemInfoFromBag(bagID, slot)
            local itemLink = itemInfo and GetItemLinkFromBag(bagID, slot) or nil
            local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil
            local itemName = itemLink and GetItemInfo(itemLink) or nil
            slots[#slots + 1] = {
                bagID = bagID,
                slot = slot,
                item = itemInfo and {
                    iconFileID = itemInfo.iconFileID,
                    stackCount = itemInfo.stackCount,
                    quality = itemInfo.quality,
                    itemLink = itemLink,
                    itemID = itemID,
                    name = itemName,
                } or nil,
            }
        end
    end
    return slots
end

function OneBank:Refresh()
    if not self.frame then return end
    self:RefreshBagSlots()

    local searching = self.searchText and self.searchText ~= ""
    local all = self:BuildLiveSlots()

    local used = #all
    local cols = self.columns
    local size = self.slotSize
    local spacing = self.spacing
    local gridWidth = cols * size + ((cols - 1) * spacing)
    local gridInsetX = spacing
    local gridInsetY = spacing
    local framePaddingX = 26
    local contentTopInset = self.searchVisible and 34 or 12
    local frameVerticalChrome = 79 + contentTopInset

    local desiredContentWidth = gridWidth + (gridInsetX * 2)
    local frameWidth = desiredContentWidth + framePaddingX
    self.frame:SetSize(frameWidth, self.frame:GetHeight())
    local actualContentWidth = self.frame.content and self.frame.content:GetWidth() or desiredContentWidth
    gridInsetX = math.max(spacing, math.floor((actualContentWidth - gridWidth) * 0.5))

    local maxBottom = 0
    for i = 1, used do
        local b = self:AcquireButton(i)
        b:SetSize(size, size)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + col * (size + spacing), -gridInsetY - row * (size + spacing))
        local info = all[i]
        local isMatch = ItemMatchesSearch(info.item, self.searchText)
        b.bagID = info.bagID
        b.slot = info.slot
        b.BagID = info.bagID
        b.SlotID = info.slot
        b:SetID(info.slot)
        b:SetAttribute("type", "item")
        b:SetAttribute("bag", info.bagID)
        b:SetAttribute("slot", info.slot)
        if b.DebugSlotText then
            b.DebugSlotText:SetText(("%d:%d"):format(tonumber(info.bagID) or -99, tonumber(info.slot) or -99))
            b.DebugSlotText:Show()
        end

        if info.item then
            if SetItemButtonTexture then SetItemButtonTexture(b, info.item.iconFileID) else b.icon:SetTexture(info.item.iconFileID) end
            if SetItemButtonCount then SetItemButtonCount(b, info.item.stackCount or 0) else b.count:SetText((info.item.stackCount or 0) > 1 and info.item.stackCount or "") end
            if SetItemButtonQuality then SetItemButtonQuality(b, info.item.quality, info.item.itemLink) end
            UpdateItemCooldown(b, info.bagID, info.slot)
            local alpha = (searching and not isMatch) and 0.22 or 1
            b:SetAlpha(alpha)
            b._baseAlpha = alpha
            UpdateButtonStyleBorderForItem(b, info.item)
        else
            if SetItemButtonTexture then SetItemButtonTexture(b, nil) else b.icon:SetTexture(nil) end
            if SetItemButtonCount then SetItemButtonCount(b, 0) else b.count:SetText("") end
            if SetItemButtonQuality then SetItemButtonQuality(b, nil) end
            ClearItemCooldown(b)
            local alpha = (searching and not isMatch) and 0.18 or 0.55
            b:SetAlpha(alpha)
            b._baseAlpha = alpha
            UpdateButtonStyleBorderForItem(b, nil)
        end
        if b.icon and b.icon.SetDesaturated then
            b.icon:SetDesaturated(self.sortingActive == true)
        end
        if ns.Plugins then ns.Plugins:Apply(b, info, "oneBank") end
        b:EnableMouse(not self.sortingActive)
        b:Show()
        local bottom = gridInsetY + row * (size + spacing) + size
        if bottom > maxBottom then maxBottom = bottom end
    end
    for i = used + 1, #self.buttons do
        if self.buttons[i].DebugSlotText then
            self.buttons[i].DebugSlotText:Hide()
        end
        self.buttons[i]:Hide()
    end

    if maxBottom <= 0 then maxBottom = gridInsetY + size end
    local contentHeight = maxBottom + gridInsetY
    local frameHeight = math.max(260, contentHeight + frameVerticalChrome)
    self.frame:SetSize(frameWidth, frameHeight)

    if self.frame.MoneyBar and self.frame.MoneyBar.Text and GetCoinTextureString then
        self.frame.MoneyBar.Text:SetText(GetCoinTextureString(GetMoney() or 0))
    end
end

function OneBank:SetSortingState(active)
    self.sortingActive = (active == true)
    if self.frame and self.frame.SortButton then
        self.frame.SortButton:EnableMouse(not self.sortingActive)
        self.frame.SortButton:SetAlpha(self.sortingActive and 0.5 or 1)
    end
end

function OneBank:SavePosition()
    local cfg = GetConfig()
    if not cfg or not self.frame then return end
    local point, _, _, x, y = self.frame:GetPoint(1)
    cfg.point = point or "BOTTOMLEFT"
    cfg.x = x or 34
    cfg.y = y or 126
end

function OneBank:ApplySettings()
    local cfg = GetConfig()
    if not cfg or not self.frame then return end
    self.columns = math.max(6, math.min(16, tonumber(cfg.columns) or 11))
    self.slotSize = math.max(24, math.min(48, tonumber(cfg.itemSize) or 36))
    self.spacing = math.max(0, math.min(12, tonumber(cfg.spacing) or 4))
    self.showBagRail = cfg.showBagRail ~= false
    self.frame:ClearAllPoints()
    self.frame:SetPoint(cfg.point or "BOTTOMLEFT", UIParent, cfg.point or "BOTTOMLEFT", cfg.x or 34, cfg.y or 126)
    self.frame:SetScale(math.max(0.7, math.min(1.5, tonumber(cfg.scale) or 1)))
    self.frame:SetMovable(not cfg.locked)
    if cfg.locked then self.frame:RegisterForDrag() else self.frame:RegisterForDrag("LeftButton") end
    if self.frame.RailToggleButton then
        self.frame.RailToggleButton:SetAlpha(self.showBagRail and 1 or 0.6)
    end
    self:UpdateSearchLayout()
end

function OneBank:ResetPosition()
    local cfg = GetConfig()
    if not cfg then return end
    cfg.point = "BOTTOMLEFT"
    cfg.x = 34
    cfg.y = 126
    self:ApplySettings()
end

function OneBank:Show()
    self:CreateFrame()
    self:ApplySettings()
    self:Refresh()
    self.frame:Show()
end

function OneBank:Hide()
    if self.frame then self.frame:Hide() end
end

function LunaBagsOneBank_Close()
    if ns.OneBank then ns.OneBank:Hide() end
end

function LunaBagsOneBank_SearchChanged(editBox)
    OneBank.searchText = strtrim(editBox:GetText() or "")
    OneBank:Refresh()
end

function LunaBagsOneBank_SearchToggleClicked()
    OneBank.searchVisible = not OneBank.searchVisible
    if not OneBank.frame or not OneBank.frame.SearchEditBox then
        return
    end
    OneBank:UpdateSearchLayout()
    if OneBank.searchVisible then
        OneBank.frame.SearchEditBox:SetFocus()
    else
        OneBank.frame.SearchEditBox:ClearFocus()
        OneBank.frame.SearchEditBox:SetText("")
        OneBank.searchText = ""
        OneBank:Refresh()
    end
end

function LunaBagsOneBank_SortClicked()
    if SortBankBags then
        SortBankBags()
    elseif C_Container and C_Container.SortBankBags then
        C_Container.SortBankBags()
    elseif ns.Sorter and ns.Sorter.SortSpecificBags then
        ns.Sorter:SortSpecificBags(BANK_BAGS, {
            onStart = function()
                OneBank:SetSortingState(true)
            end,
            onStop = function()
                OneBank:SetSortingState(false)
                OneBank:Refresh()
            end,
        })
    end
end

function LunaBagsOneBank_SortButtonClicked(_, mouseButton)
    if mouseButton == "RightButton" then
        local menu = {
            {
                text = "Sort Bank",
                func = function() LunaBagsOneBank_SortClicked() end,
                notCheckable = true,
            },
            {
                text = SETTINGS or "Settings",
                func = function()
                    if ns.OpenConfig then ns.OpenConfig() end
                end,
                notCheckable = true,
            },
        }
        if EasyMenu then
            if not LunaBagsOneBankSortMenu then
                CreateFrame("Frame", "LunaBagsOneBankSortMenu", UIParent, "UIDropDownMenuTemplate")
            end
            EasyMenu(menu, LunaBagsOneBankSortMenu, "cursor", 0, 0, "MENU")
        else
            if not LunaBagsOneBankSortMenu then
                CreateFrame("Frame", "LunaBagsOneBankSortMenu", UIParent, "UIDropDownMenuTemplate")
            end
            UIDropDownMenu_Initialize(LunaBagsOneBankSortMenu, function(_, level)
                if level ~= 1 then return end
                for _, entry in ipairs(menu) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = entry.text
                    info.func = entry.func
                    info.notCheckable = entry.notCheckable
                    UIDropDownMenu_AddButton(info, level)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, LunaBagsOneBankSortMenu, "cursor", 0, 0)
        end
        return
    end
    LunaBagsOneBank_SortClicked()
end

function LunaBagsOneBank_RailToggleClicked()
    OneBank.showBagRail = not OneBank.showBagRail
    local cfg = GetConfig()
    if cfg then
        cfg.showBagRail = OneBank.showBagRail
    end
    if OneBank.frame and OneBank.frame.RailToggleButton then
        OneBank.frame.RailToggleButton:SetAlpha(OneBank.showBagRail and 1 or 0.6)
    end
    OneBank:Refresh()
end

function LunaBagsOneBank_ItemButtonOnEnter(button)
    if button.bagID and button.slot then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(button.bagID, button.slot)
        GameTooltip:Show()
    end
end

function LunaBagsOneBank_ItemButtonOnLeave()
    GameTooltip:Hide()
end

function LunaBagsOneBank_ItemButtonOnClick(button, mouseButton)
    if not button.bagID or not button.slot then return end
    if mouseButton == "RightButton" then
        if C_Container and C_Container.UseContainerItem then
            C_Container.UseContainerItem(button.bagID, button.slot)
        else
            UseContainerItem(button.bagID, button.slot)
        end
    else
        if C_Container and C_Container.PickupContainerItem then
            C_Container.PickupContainerItem(button.bagID, button.slot)
        else
            PickupContainerItem(button.bagID, button.slot)
        end
    end
end

function LunaBagsOneBank_ItemButtonOnDragStart(button)
    if not button.bagID or not button.slot then return end
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(button.bagID, button.slot)
    else
        PickupContainerItem(button.bagID, button.slot)
    end
end

function LunaBagsOneBank_ItemButtonOnReceiveDrag(button)
    if not button.bagID or not button.slot then return end
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(button.bagID, button.slot)
    else
        PickupContainerItem(button.bagID, button.slot)
    end
end
