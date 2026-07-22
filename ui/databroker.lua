local _, ns = ...

local UPDATE_INTERVAL = 0.25
local SLOT_COUNT_OBJECT = "LunaBags: Slot Count"
local SLOT_COUNT_LABEL = "Slot Count"
local GOLD_OBJECT = "LunaBags: Gold"
local GOLD_LABEL = "Gold"
local SLOT_COUNT_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
local GOLD_ICON = "Interface\\MoneyFrame\\UI-GoldIcon"

local internalSlotObject = {
    type = "data source",
    label = SLOT_COUNT_LABEL,
    text = "Slots",
    icon = SLOT_COUNT_ICON,
    lunaBagsSlotCount = true,
}

local internalGoldObject = {
    type = "data source",
    label = GOLD_LABEL,
    text = "0",
    icon = GOLD_ICON,
    lunaBagsGold = true,
}

local function GetDataBroker()
    return LibStub and LibStub("LibDataBroker-1.1", true) or nil
end

local function EnsureSlotDataObject()
    local broker = GetDataBroker()
    if not broker then
        return internalSlotObject
    end

    local existing = type(broker.GetDataObjectByName) == "function" and broker:GetDataObjectByName(SLOT_COUNT_OBJECT) or nil
    if existing then
        existing.lunaBagsSlotCount = true
        existing.icon = existing.icon or SLOT_COUNT_ICON
        return existing
    end

    if type(broker.NewDataObject) == "function" then
        local ok, object = pcall(broker.NewDataObject, broker, SLOT_COUNT_OBJECT, {
            type = "data source",
            label = SLOT_COUNT_LABEL,
            text = "Slots",
            icon = SLOT_COUNT_ICON,
            lunaBagsSlotCount = true,
        })
        if ok and object then
            return object
        end
    end
    return internalSlotObject
end

local function EnsureGoldDataObject()
    local broker = GetDataBroker()
    if not broker then
        return internalGoldObject
    end

    local existing = type(broker.GetDataObjectByName) == "function" and broker:GetDataObjectByName(GOLD_OBJECT) or nil
    if existing then
        existing.lunaBagsGold = true
        existing.icon = existing.icon or GOLD_ICON
        return existing
    end

    if type(broker.NewDataObject) == "function" then
        local ok, object = pcall(broker.NewDataObject, broker, GOLD_OBJECT, {
            type = "data source",
            label = GOLD_LABEL,
            text = "0",
            icon = GOLD_ICON,
            lunaBagsGold = true,
        })
        if ok and object then
            return object
        end
    end
    return internalGoldObject
end

local function GetDataObject(name)
    if name == SLOT_COUNT_OBJECT then
        return EnsureSlotDataObject()
    elseif name == GOLD_OBJECT then
        return EnsureGoldDataObject()
    end
    local broker = GetDataBroker()
    if broker and type(broker.GetDataObjectByName) == "function" then
        return broker:GetDataObjectByName(name)
    end
end

local function NormalizeFooterKey(footerKey)
    return footerKey == "oneBank" and "oneBank" or "oneBag"
end

local function GetFooterConfig(footerKey)
    local addon = ns.LunaBags
    local profile = addon and addon.db and addon.db.profile
    if not profile then
        return nil, nil
    end
    footerKey = NormalizeFooterKey(footerKey)
    profile[footerKey] = profile[footerKey] or {}
    profile.ui = profile.ui or {}
    return profile[footerKey], profile.ui
end

local function CopySelectedNames(source)
    local output = {}
    for _, name in ipairs(source or {}) do
        output[#output + 1] = name
    end
    return output
end

local function GetSelectedNames(footerKey)
    local config, legacyUI = GetFooterConfig(footerKey)
    if not config then
        return { SLOT_COUNT_OBJECT, GOLD_OBJECT }
    end

    local selected
    if rawget(config, "_dataBrokerObjectsMigrated") ~= true then
        local sharedSelection = legacyUI and rawget(legacyUI, "dataBrokerObjects")
        if type(sharedSelection) == "table" then
            selected = CopySelectedNames(sharedSelection)
        else
            local legacyName = legacyUI and rawget(legacyUI, "dataBrokerObject")
            local legacyEnabled = legacyUI and rawget(legacyUI, "dataBrokerEnabled")
            if legacyEnabled ~= false and type(legacyName) == "string" and legacyName ~= "" and legacyName ~= SLOT_COUNT_OBJECT then
                selected = { SLOT_COUNT_OBJECT, legacyName }
            end
        end
        if type(selected) == "table" then
            config.dataBrokerObjects = selected
        end
        config._dataBrokerObjectsMigrated = true
    end

    selected = rawget(config, "dataBrokerObjects")
    if type(selected) ~= "table" then
        selected = { SLOT_COUNT_OBJECT, GOLD_OBJECT }
        config.dataBrokerObjects = selected
    end

    local names = {}
    local seen = {}
    for _, name in ipairs(selected) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if rawget(config, "_goldDataBrokerMigrated") ~= true then
        if not seen[GOLD_OBJECT] then
            names[#names + 1] = GOLD_OBJECT
        end
        config.dataBrokerObjects = CopySelectedNames(names)
        local alignments = rawget(config, "dataBrokerAlignments")
        if type(alignments) ~= "table" then
            alignments = {}
            config.dataBrokerAlignments = alignments
        end
        alignments[GOLD_OBJECT] = "right"
        config._goldDataBrokerMigrated = true
    end
    return names
end

function ns.GetDataBrokerObjectValues(footerKey)
    local values = {
        [SLOT_COUNT_OBJECT] = SLOT_COUNT_LABEL,
        [GOLD_OBJECT] = GOLD_LABEL,
    }
    local broker = GetDataBroker()
    if broker and type(broker.DataObjectIterator) == "function" then
        for name, object in broker:DataObjectIterator() do
            if type(name) == "string" and type(object) == "table" then
                values[name] = tostring(object.label or name)
            end
        end
    end
    for _, name in ipairs(GetSelectedNames(footerKey)) do
        if values[name] == nil then
            values[name] = name .. " (Unavailable)"
        end
    end
    return values
end

function ns.IsDataBrokerObjectSelected(footerKey, name)
    for _, selectedName in ipairs(GetSelectedNames(footerKey)) do
        if selectedName == name then
            return true
        end
    end
    return false
end

function ns.SetDataBrokerObjectSelected(footerKey, name, enabled)
    if type(name) ~= "string" or name == "" then
        return
    end
    local config = GetFooterConfig(footerKey)
    if not config then
        return
    end

    footerKey = NormalizeFooterKey(footerKey)
    local selected = GetSelectedNames(footerKey)
    local output = {}
    local found = false
    for _, selectedName in ipairs(selected) do
        if selectedName == name then
            found = true
            if enabled then
                output[#output + 1] = selectedName
            end
        else
            output[#output + 1] = selectedName
        end
    end
    if enabled and not found then
        output[#output + 1] = name
    end
    config.dataBrokerObjects = output
    if ns.RefreshDataBrokerDisplays then
        ns.RefreshDataBrokerDisplays()
    end
    local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if registry and type(registry.NotifyChange) == "function" then
        registry:NotifyChange("LunaBags")
    end
end

local function GetDataBrokerAlignments(footerKey)
    GetSelectedNames(footerKey)
    local config = GetFooterConfig(footerKey)
    if not config then
        return nil
    end
    local alignments = rawget(config, "dataBrokerAlignments")
    if type(alignments) ~= "table" then
        alignments = {}
        config.dataBrokerAlignments = alignments
    end
    if rawget(config, "_dataBrokerAlignmentsMigrated") ~= true then
        local legacyRightAligned = rawget(config, "dataBrokerRightAligned")
        if type(legacyRightAligned) == "table" then
            for name, enabled in pairs(legacyRightAligned) do
                if enabled == true and alignments[name] == nil then
                    alignments[name] = "right"
                end
            end
        end
        config._dataBrokerAlignmentsMigrated = true
    end
    return alignments
end

function ns.GetDataBrokerObjectAlignment(footerKey, name)
    local alignments = GetDataBrokerAlignments(footerKey)
    local alignment = alignments and alignments[name]
    if alignment == "center" or alignment == "right" then
        return alignment
    end
    return "left"
end

function ns.SetDataBrokerObjectAlignment(footerKey, name, alignment)
    if type(name) ~= "string" or name == "" then
        return
    end
    if alignment ~= "center" and alignment ~= "right" then
        alignment = "left"
    end
    local alignments = GetDataBrokerAlignments(footerKey)
    if not alignments then
        return
    end
    alignments[name] = alignment == "left" and nil or alignment
    if ns.RefreshDataBrokerDisplays then
        ns.RefreshDataBrokerDisplays()
    end
    local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if registry and type(registry.NotifyChange) == "function" then
        registry:NotifyChange("LunaBags")
    end
end

local function GetSortedObjectEntries(footerKey)
    local entries = {}
    for name, label in pairs(ns.GetDataBrokerObjectValues(footerKey)) do
        local object = GetDataObject(name)
        entries[#entries + 1] = {
            name = name,
            label = label,
            icon = object and object.icon,
            iconCoords = object and object.iconCoords,
            builtIn = name == SLOT_COUNT_OBJECT or name == GOLD_OBJECT,
        }
    end
    table.sort(entries, function(a, b)
        if a.name == SLOT_COUNT_OBJECT then
            return true
        elseif b.name == SLOT_COUNT_OBJECT then
            return false
        end
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    return entries
end

local function ShowDataBrokerMenu(anchor, footerKey)
    footerKey = NormalizeFooterKey(footerKey)
    local entries = GetSortedObjectEntries(footerKey)
    local groups = { builtIn = {}, external = {} }
    local entriesByValue = {}
    for index, entry in ipairs(entries) do
        entry.menuValue = "LunaBagsBrokerItem" .. index
        entriesByValue[entry.menuValue] = entry
        local group = entry.builtIn and groups.builtIn or groups.external
        group[#group + 1] = entry
    end

    local function ToggleShown(entry)
        ns.SetDataBrokerObjectSelected(
            footerKey,
            entry.name,
            not ns.IsDataBrokerObjectSelected(footerKey, entry.name)
        )
    end

    local function GetMenuLabel(entry)
        if entry.icon ~= nil and entry.icon ~= "" then
            return ("|T%s:16:16:0:0|t  %s"):format(tostring(entry.icon), tostring(entry.label))
        end
        return tostring(entry.label)
    end

    GameTooltip:Hide()
    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and ToggleDropDownMenu then
        local menu = _G.LunaBagsDataBrokerMenu
        if not menu then
            menu = CreateFrame("Frame", "LunaBagsDataBrokerMenu", UIParent, "UIDropDownMenuTemplate")
        end
        UIDropDownMenu_Initialize(menu, function(_, level)
            if level == 1 then
                local title = UIDropDownMenu_CreateInfo()
                title.text = footerKey == "oneBank" and "Bank Footer" or "Bags Footer"
                title.isTitle = true
                title.notCheckable = true
                UIDropDownMenu_AddButton(title, level)

                local builtIn = UIDropDownMenu_CreateInfo()
                builtIn.text = ("|T%s:16:16:0:0|t  LunaBags"):format(SLOT_COUNT_ICON)
                builtIn.hasArrow = true
                builtIn.notCheckable = true
                builtIn.padding = 24
                builtIn.value = "LunaBagsBuiltIn"
                UIDropDownMenu_AddButton(builtIn, level)

                if #groups.external > 0 then
                    local external = UIDropDownMenu_CreateInfo()
                    external.text = "DataBroker Feeds"
                    external.hasArrow = true
                    external.notCheckable = true
                    external.value = "LunaBagsExternal"
                    UIDropDownMenu_AddButton(external, level)
                end
                return
            end

            if level == 2 then
                local group = UIDROPDOWNMENU_MENU_VALUE == "LunaBagsBuiltIn" and groups.builtIn
                    or (UIDROPDOWNMENU_MENU_VALUE == "LunaBagsExternal" and groups.external or nil)
                for _, entry in ipairs(group or {}) do
                    local menuEntry = entry
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = GetMenuLabel(menuEntry)
                    info.checked = ns.IsDataBrokerObjectSelected(footerKey, menuEntry.name)
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.func = function()
                        ToggleShown(menuEntry)
                    end
                    info.hasArrow = true
                    info.padding = 24
                    info.value = menuEntry.menuValue
                    UIDropDownMenu_AddButton(info, level)
                end
                return
            end

            if level == 3 then
                local entry = entriesByValue[UIDROPDOWNMENU_MENU_VALUE]
                if not entry then
                    return
                end
                local alignmentTitle = UIDropDownMenu_CreateInfo()
                alignmentTitle.text = "Alignment"
                alignmentTitle.isTitle = true
                alignmentTitle.notCheckable = true
                UIDropDownMenu_AddButton(alignmentTitle, level)

                for _, alignment in ipairs({ "left", "center", "right" }) do
                    local selectedAlignment = alignment
                    local align = UIDropDownMenu_CreateInfo()
                    align.text = selectedAlignment:sub(1, 1):upper() .. selectedAlignment:sub(2)
                    align.checked = ns.GetDataBrokerObjectAlignment(footerKey, entry.name) == selectedAlignment
                    align.keepShownOnClick = true
                    align.func = function()
                        ns.SetDataBrokerObjectAlignment(footerKey, entry.name, selectedAlignment)
                    end
                    UIDropDownMenu_AddButton(align, level)
                end
            end
        end, "MENU")
        ToggleDropDownMenu(1, nil, menu, anchor or "cursor", 0, 0)
        return
    end

    if EasyMenu then
        local function BuildEasyGroup(group)
            local output = {}
            for _, entry in ipairs(group) do
                local menuEntry = entry
                output[#output + 1] = {
                    text = GetMenuLabel(menuEntry),
                    checked = ns.IsDataBrokerObjectSelected(footerKey, menuEntry.name),
                    isNotRadio = true,
                    keepShownOnClick = true,
                    func = function() ToggleShown(menuEntry) end,
                    hasArrow = true,
                    padding = 24,
                    menuList = {
                        { text = "Alignment", isTitle = true, notCheckable = true },
                        {
                            text = "Left",
                            checked = ns.GetDataBrokerObjectAlignment(footerKey, menuEntry.name) == "left",
                            keepShownOnClick = true,
                            func = function() ns.SetDataBrokerObjectAlignment(footerKey, menuEntry.name, "left") end,
                        },
                        {
                            text = "Center",
                            checked = ns.GetDataBrokerObjectAlignment(footerKey, menuEntry.name) == "center",
                            keepShownOnClick = true,
                            func = function() ns.SetDataBrokerObjectAlignment(footerKey, menuEntry.name, "center") end,
                        },
                        {
                            text = "Right",
                            checked = ns.GetDataBrokerObjectAlignment(footerKey, menuEntry.name) == "right",
                            keepShownOnClick = true,
                            func = function() ns.SetDataBrokerObjectAlignment(footerKey, menuEntry.name, "right") end,
                        },
                    },
                }
            end
            return output
        end

        local menu = {
            {
                text = footerKey == "oneBank" and "Bank Footer" or "Bags Footer",
                isTitle = true,
                notCheckable = true,
            },
            {
                text = ("|T%s:16:16:0:0|t  LunaBags"):format(SLOT_COUNT_ICON),
                hasArrow = true,
                notCheckable = true,
                padding = 24,
                menuList = BuildEasyGroup(groups.builtIn),
            },
        }
        if #groups.external > 0 then
            menu[#menu + 1] = {
                text = "DataBroker Feeds",
                hasArrow = true,
                notCheckable = true,
                menuList = BuildEasyGroup(groups.external),
            }
        end
        local menuFrame = _G.LunaBagsDataBrokerEasyMenu or CreateFrame("Frame", "LunaBagsDataBrokerEasyMenu", UIParent)
        EasyMenu(menu, menuFrame, anchor or "cursor", 0, 0, "MENU")
    end
end

local function SetButtonIcon(button, object)
    local icon = object and not object.lunaBagsGold and object.icon
    button.hasDisplayIcon = icon ~= nil and icon ~= ""
    button.Icon:SetShown(icon ~= nil and icon ~= "")
    button.Icon:SetTexture(icon)
    local coords = object and object.iconCoords
    if type(coords) == "table" and #coords >= 4 then
        button.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        button.Icon:SetTexCoord(0, 1, 0, 1)
    end

    button.Value:ClearAllPoints()
    if icon ~= nil and icon ~= "" then
        button.Value:SetPoint("LEFT", button.Icon, "RIGHT", 4, 0)
    else
        button.Value:SetPoint("LEFT", button, "LEFT", 0, 0)
    end
    button.Value:SetPoint("RIGHT", button, "RIGHT", 0, 0)
end

local function ShowButtonTooltip(button)
    local object = button.dataObject
    if type(object) ~= "table" then
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText(button.dataObjectName or "LibDataBroker")
        GameTooltip:AddLine("This broker feed is not currently available.", 1, 0.45, 0.35, true)
        GameTooltip:Show()
        return
    end
    if object.lunaBagsGold then
        local moneyBar = button:GetParent():GetParent()
        local showGoldTooltip = moneyBar and moneyBar.lunaBagsGoldTooltip
        if type(showGoldTooltip) == "function" then
            pcall(showGoldTooltip, button)
            return
        end
    end
    if type(object.OnEnter) == "function" then
        pcall(object.OnEnter, button)
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    if type(object.OnTooltipShow) == "function" then
        pcall(object.OnTooltipShow, GameTooltip)
    else
        GameTooltip:SetText(tostring(object.label or button.dataObjectName or ""))
        if object.lunaBagsSlotCount then
            GameTooltip:AddLine(tostring(button:GetParent():GetParent().lunaBagsSlotUsageText or "Slots"), 1, 1, 1)
        elseif object.lunaBagsGold then
            GameTooltip:AddLine(tostring(button:GetParent():GetParent().lunaBagsGoldText or "0"), 1, 1, 1)
        elseif object.text ~= nil then
            GameTooltip:AddLine(tostring(object.text), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function HideButtonTooltip(button)
    local object = button.dataObject
    if type(object) == "table" and type(object.OnLeave) == "function" then
        pcall(object.OnLeave, button)
    else
        GameTooltip:Hide()
    end
end

local function AcquireDisplayButton(container, index)
    container.Buttons = container.Buttons or {}
    local button = container.Buttons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, container)
    button:RegisterForClicks("AnyUp")
    button:SetHeight(20)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(16, 16)
    button.Icon:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.Value = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Value:SetJustifyH("LEFT")
    button.Value:SetWordWrap(false)
    button.Value:SetTextColor(1, 1, 1, 1)
    button:SetScript("OnClick", function(self, mouseButton)
        local object = self.dataObject
        if type(object) == "table" and type(object.OnClick) == "function" then
            pcall(object.OnClick, self, mouseButton)
        end
    end)
    button:SetScript("OnEnter", ShowButtonTooltip)
    button:SetScript("OnLeave", HideButtonTooltip)
    container.Buttons[index] = button
    return button
end

local function UpdateFooterDisplays(moneyBar)
    local container = moneyBar and moneyBar.DataBrokerContainer
    if not container then
        return
    end

    local footerKey = NormalizeFooterKey(moneyBar.lunaBagsFooterKey)
    local selected = GetSelectedNames(footerKey)
    local naturalWidths = {}
    local leftIndices = {}
    local centerIndices = {}
    local rightIndices = {}
    for index, name in ipairs(selected) do
        local button = AcquireDisplayButton(container, index)
        local object = GetDataObject(name)
        button.dataObject = object
        button.dataObjectName = name
        button.footerKey = footerKey
        SetButtonIcon(button, object)

        local value
        if object and object.lunaBagsSlotCount then
            value = moneyBar.lunaBagsSlotUsageText or "Slots"
        elseif object and object.lunaBagsGold then
            value = moneyBar.lunaBagsGoldText or "0"
        elseif object then
            value = object.text
            if value == nil or value == "" then
                value = object.label or name
            end
        else
            value = name
        end
        button.Value:SetText(tostring(value or ""))
        naturalWidths[index] = math.max(32, math.min(180,
            (button.Value:GetStringWidth() or 0) + (button.hasDisplayIcon and 20 or 0)))
        button:SetAlpha(object and 1 or 0.55)
        button:Show()
        local alignment = ns.GetDataBrokerObjectAlignment(footerKey, name)
        if alignment == "right" then
            rightIndices[#rightIndices + 1] = index
        elseif alignment == "center" then
            centerIndices[#centerIndices + 1] = index
        else
            leftIndices[#leftIndices + 1] = index
        end
    end

    for index = #selected + 1, #(container.Buttons or {}) do
        container.Buttons[index]:Hide()
    end

    local count = #selected
    if count == 0 then
        return
    end
    local spacing = 12
    local available = container:GetWidth()
    if not available or available <= 1 then
        available = math.max(80, (moneyBar:GetWidth() or 280) - 16)
    end
    local totalNatural = spacing * math.max(0, count - 1)
    for _, width in ipairs(naturalWidths) do
        totalNatural = totalNatural + width
    end
    local constrainedWidth = math.max(32, (available - spacing * math.max(0, count - 1)) / count)

    local previous
    for _, index in ipairs(leftIndices) do
        local button = container.Buttons[index]
        button:ClearAllPoints()
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
        else
            button:SetPoint("LEFT", container, "LEFT", 0, 0)
        end
        button:SetWidth(totalNatural <= available and naturalWidths[index] or constrainedWidth)
        previous = button
    end

    local centerWidth = spacing * math.max(0, #centerIndices - 1)
    for _, index in ipairs(centerIndices) do
        centerWidth = centerWidth + (totalNatural <= available and naturalWidths[index] or constrainedWidth)
    end
    previous = nil
    for _, index in ipairs(centerIndices) do
        local button = container.Buttons[index]
        button:ClearAllPoints()
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
        else
            button:SetPoint("LEFT", container, "CENTER", -centerWidth / 2, 0)
        end
        button:SetWidth(totalNatural <= available and naturalWidths[index] or constrainedWidth)
        previous = button
    end

    previous = nil
    for position = #rightIndices, 1, -1 do
        local index = rightIndices[position]
        local button = container.Buttons[index]
        button:ClearAllPoints()
        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -spacing, 0)
        else
            button:SetPoint("RIGHT", container, "RIGHT", 0, 0)
        end
        button:SetWidth(totalNatural <= available and naturalWidths[index] or constrainedWidth)
        previous = button
    end
end

function ns.SetFooterSlotUsage(moneyBar, text)
    if not moneyBar then
        return
    end
    moneyBar.lunaBagsSlotUsageText = text or "Slots"
    EnsureSlotDataObject().text = moneyBar.lunaBagsSlotUsageText
    UpdateFooterDisplays(moneyBar)
end

function ns.SetFooterGold(moneyBar, text)
    if not moneyBar then
        return
    end
    moneyBar.lunaBagsGoldText = text or "0"
    EnsureGoldDataObject().text = moneyBar.lunaBagsGoldText
    UpdateFooterDisplays(moneyBar)
end

function ns.AttachDataBrokerDisplay(moneyBar, footerKey)
    if not moneyBar or not moneyBar.Text then
        return nil
    end
    moneyBar.lunaBagsFooterKey = NormalizeFooterKey(footerKey or moneyBar.lunaBagsFooterKey)
    EnsureSlotDataObject()
    EnsureGoldDataObject()

    if moneyBar.Label then
        moneyBar.Label:Hide()
    end
    if moneyBar.Text then
        moneyBar.Text:Hide()
    end
    local container = moneyBar.DataBrokerContainer
    if not container then
        container = CreateFrame("Frame", nil, moneyBar)
        container:SetHeight(20)
        container:SetPoint("LEFT", moneyBar, "LEFT", 8, 0)
        container:SetPoint("RIGHT", moneyBar, "RIGHT", -8, 0)
        container:SetScript("OnUpdate", function(self, elapsed)
            self.updateElapsed = (self.updateElapsed or 0) + elapsed
            if self.updateElapsed >= UPDATE_INTERVAL then
                self.updateElapsed = 0
                UpdateFooterDisplays(moneyBar)
            end
        end)
        moneyBar.DataBrokerContainer = container
    end

    if moneyBar._lunaBagsDataBrokerMenuHook ~= true then
        moneyBar._lunaBagsDataBrokerMenuHook = true
        moneyBar:HookScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "RightButton" then
                local mouseFocus = GetMouseFocus and GetMouseFocus() or nil
                if mouseFocus and mouseFocus ~= moneyBar and mouseFocus ~= moneyBar.DataBrokerContainer then
                    return
                end
                ShowDataBrokerMenu("cursor", moneyBar.lunaBagsFooterKey)
            end
        end)
        moneyBar:HookScript("OnEnter", function(bar)
            GameTooltip:SetOwner(bar, "ANCHOR_TOP")
            GameTooltip:SetText("Footer DataBroker Items")
            GameTooltip:AddLine("Right-click the footer to manage its items.", 1, 1, 1, true)
            GameTooltip:AddLine("Click an item in the menu to show or hide it.", 0.75, 0.82, 0.9, true)
            GameTooltip:AddLine("Use an item's arrow submenu to choose Left, Center, or Right alignment.", 0.75, 0.82, 0.9, true)
            GameTooltip:Show()
        end)
    end

    UpdateFooterDisplays(moneyBar)
    return container
end

function ns.RefreshDataBrokerDisplays()
    local bagBar = ns.OneBag and ns.OneBag.frame and ns.OneBag.frame.MoneyBar
    local bankBar = ns.OneBank and ns.OneBank.frame and ns.OneBank.frame.MoneyBar
    if bagBar then
        ns.AttachDataBrokerDisplay(bagBar, "oneBag")
    end
    if bankBar then
        ns.AttachDataBrokerDisplay(bankBar, "oneBank")
    end
end
