local _, ns = ...
local LunaBags = ns.LunaBags

local ExtraStyleWindow = LunaBags and LunaBags:CreateModule("extraStyleWindow") or {}
ExtraStyleWindow.frame = nil

ns.ExtraStyleWindow = ExtraStyleWindow

local BAG_SLOTS = {
    BACKPACK_CONTAINER,
    1,
    2,
    3,
    4,
}

local function GetBagIcon(containerID)
    if KEYRING_CONTAINER and containerID == KEYRING_CONTAINER then
        return "Interface\\ContainerFrame\\KeyRing-Bag-Icon"
    end

    if containerID == BACKPACK_CONTAINER then
        if MainMenuBarBackpackButtonIconTexture and MainMenuBarBackpackButtonIconTexture.GetTexture then
            return MainMenuBarBackpackButtonIconTexture:GetTexture()
        end
        return "Interface\\Buttons\\Button-Backpack-Up"
    end

    if ContainerIDToInventoryID then
        local invSlot = ContainerIDToInventoryID(containerID)
        if invSlot then
            return GetInventoryItemTexture("player", invSlot)
        end
    end

    return nil
end

local function RefreshBagRailIcons(rail)
    if not rail or not rail.buttons then
        return
    end

    for _, button in ipairs(rail.buttons) do
        local icon = GetBagIcon(button.containerID)
        if icon then
            button.icon:SetTexture(icon)
            button.icon:Show()
        else
            button.icon:SetTexture(nil)
            button.icon:Hide()
        end
    end
end

local function FormatMoneyText(copper)
    local gold = floor((copper or 0) / (COPPER_PER_SILVER * SILVER_PER_GOLD))
    local silver = floor(((copper or 0) % (COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
    local c = (copper or 0) % COPPER_PER_SILVER
    local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
    local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
    local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

    if gold > 0 then
        return string.format("%d%s %d%s %d%s", gold, goldIcon, silver, silverIcon, c, copperIcon)
    end
    if silver > 0 then
        return string.format("%d%s %d%s", silver, silverIcon, c, copperIcon)
    end
    return string.format("%d%s", c, copperIcon)
end

function ExtraStyleWindow:Create()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "LunaBagsExtraStyleWindow", UIParent)
    f:SetSize(640, 460)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")

    local windowBg = f:CreateTexture(nil, "BACKGROUND")
    windowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    windowBg:SetAllPoints()
    windowBg:SetVertexColor(0.12, 0.12, 0.12, 0.84)

    local titleBg = f:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    titleBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(28)
    titleBg:SetVertexColor(0.07, 0.07, 0.07, 0.90)

    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", titleBg, "TOPRIGHT", -2, 2)

    local insetBg = f:CreateTexture(nil, "BORDER")
    insetBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    insetBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -29)
    insetBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 38)
    insetBg:SetVertexColor(0.02, 0.02, 0.02, 0.78)

    local statusBg = f:CreateTexture(nil, "ARTWORK")
    statusBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    statusBg:SetPoint("TOPLEFT", insetBg, "BOTTOMLEFT", 0, 0)
    statusBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    statusBg:SetVertexColor(0.10, 0.10, 0.10, 0.84)

    local goldText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldText:SetPoint("RIGHT", f, "BOTTOMRIGHT", -12, 15)
    goldText:SetJustifyH("RIGHT")
    goldText:SetTextColor(1.0, 0.82, 0.0, 1.0)
    goldText:SetText(FormatMoneyText(GetMoney()))

    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    border:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBg, "LEFT", 10, 0)
    title:SetJustifyH("LEFT")
    title:SetText(string.format("%s - Bags", UnitName("player") or "Player"))

    local bagRail = CreateFrame("Frame", nil, f, "BackdropTemplate")
    local buttonSize = 34
    local buttonSpacing = 4
    local railPadding = 6
    local railSlots = #BAG_SLOTS + (KEYRING_CONTAINER and 1 or 0)
    local railHeight = (railSlots * buttonSize) + ((railSlots - 1) * buttonSpacing) + (railPadding * 2)
    bagRail:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, -28)
    bagRail:SetWidth(buttonSize + (railPadding * 2))
    bagRail:SetHeight(railHeight)
    bagRail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bagRail:SetBackdropColor(0.08, 0.08, 0.08, 0.84)
    bagRail:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)

    bagRail.buttons = {}
    local lastButton
    local railButtons = {}
    for _, containerID in ipairs(BAG_SLOTS) do
        table.insert(railButtons, containerID)
    end
    if KEYRING_CONTAINER then
        table.insert(railButtons, KEYRING_CONTAINER)
    end

    for _, containerID in ipairs(railButtons) do
        local button = CreateFrame("Button", nil, bagRail, "BackdropTemplate")
        button:SetSize(buttonSize, buttonSize)
        button.containerID = containerID
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
        })
        button:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
        button:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)

        if lastButton then
            button:SetPoint("TOP", lastButton, "BOTTOM", 0, -buttonSpacing)
        else
            button:SetPoint("TOP", bagRail, "TOP", 0, -railPadding)
        end

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetTexCoord(0, 1, 0, 1)

        button:SetScript("OnClick", function(self)
            if ToggleBag then
                ToggleBag(self.containerID)
            elseif OpenBag then
                OpenBag(self.containerID)
            end
        end)
        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.18, 0.18, 0.18, 0.95)
        end)
        button:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
        end)

        table.insert(bagRail.buttons, button)
        lastButton = button
    end

    local itemArea = CreateFrame("Frame", nil, f)
    itemArea:SetPoint("TOPLEFT", insetBg, "TOPLEFT", 12, -12)
    itemArea:SetPoint("BOTTOMRIGHT", insetBg, "BOTTOMRIGHT", -12, 12)

    local sampleItemButtons = {}
    local itemCols = 11
    local itemRows = 5
    local itemSize = 34
    local itemSpacing = 4
    for row = 1, itemRows do
        for col = 1, itemCols do
            local btn = CreateFrame("Button", nil, itemArea, "BackdropTemplate")
            btn:SetSize(itemSize, itemSize)
            btn:SetPoint(
                "TOPLEFT",
                itemArea,
                "TOPLEFT",
                (col - 1) * (itemSize + itemSpacing),
                -((row - 1) * (itemSize + itemSpacing))
            )
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
            })
            btn:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
            btn:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)
            sampleItemButtons[#sampleItemButtons + 1] = btn
        end
    end

    f:SetScript("OnShow", function()
        RefreshBagRailIcons(bagRail)
    end)
    f:SetScript("OnEvent", function(_, event)
        RefreshBagRailIcons(bagRail)
        if event == "PLAYER_MONEY" then
            goldText:SetText(FormatMoneyText(GetMoney()))
        end
    end)
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_MONEY")

    -- Body intentionally left empty as requested.

    f.bagRail = bagRail
    f.itemArea = itemArea
    f.sampleItemButtons = sampleItemButtons
    self.frame = f
end

function ExtraStyleWindow:Show()
    self:Create()
    self.frame:Show()
end

function ExtraStyleWindow:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
