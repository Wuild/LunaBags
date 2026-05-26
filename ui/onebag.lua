local _, ns = ...

local OneBag = ns.LunaBags and ns.LunaBags:NewModule("OneBag") or {}
OneBag.frame = nil
OneBag.buttons = {}
OneBag.readonlyButtons = {}
OneBag.keyringButtons = {}
OneBag.bagButtons = {}
OneBag.columns = 11
OneBag.slotSize = 37
OneBag.spacing = 4
OneBag.searchText = ""
OneBag.searchVisible = false
OneBag.showBagRail = true
OneBag.bagRailPosition = "top"
OneBag.splitByBagRows = false
OneBag.sortingActive = false
OneBag.lockSlotsMode = false
OneBag.viewCharacterKey = nil
OneBag.visibleBags = {}
OneBag.tooltipHooked = false
OneBag.hoveredItemID = nil
OneBag.hoveredButton = nil
OneBag.newItemSignatures = {}
OneBag.newItemGlowUntil = {}
OneBag.newItemTrackingReady = false
OneBag.draggedCategoryItem = nil

ns.OneBag = OneBag

function OneBag:OnEnable()
    if ns.BagHooks then
        ns.BagHooks:EnableHooks()
    end
end

function OneBag:OnDisable()
    if ns.BagHooks then
        ns.BagHooks:DisableHooks()
    end
    self:Hide()
end

local BAG_FRAME_STRATA = "DIALOG"
local BAG_FRAME_LEVEL = 40
local BAG_FRAME_PADDING_X = 26
local BAG_DEFAULT_MAX_HEIGHT = 650

local function CalculateWindowWidthFromColumns(columns, slotSize, spacing)
    columns = math.max(1, math.floor(tonumber(columns) or 1))
    slotSize = tonumber(slotSize) or 36
    spacing = tonumber(spacing) or 4
    local gridWidth = columns * slotSize + math.max(0, columns - 1) * spacing
    return gridWidth + (spacing * 2) + BAG_FRAME_PADDING_X
end

local function CalculateColumnsFromWindowWidth(windowWidth, slotSize, spacing)
    windowWidth = tonumber(windowWidth) or CalculateWindowWidthFromColumns(11, slotSize, spacing)
    slotSize = tonumber(slotSize) or 36
    spacing = tonumber(spacing) or 4
    local gridSpace = math.max(slotSize, windowWidth - BAG_FRAME_PADDING_X - (spacing * 2))
    return math.max(1, math.floor((gridSpace + spacing) / (slotSize + spacing)))
end

local function EnsureStackSplitFrameAboveBags()
    local splitFrame = _G.StackSplitFrame
    if not splitFrame then
        return
    end
    splitFrame:SetFrameStrata("TOOLTIP")
    splitFrame:SetFrameLevel(BAG_FRAME_LEVEL + 120)
end

local function ApplyBagFrameLayering(frame)
    if not frame then
        return
    end
    frame:SetFrameStrata(BAG_FRAME_STRATA)
    frame:SetFrameLevel(BAG_FRAME_LEVEL)
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end
    if frame.content then
        frame.content:SetFrameLevel(BAG_FRAME_LEVEL + 5)
    end
    if frame.Content then
        frame.Content:SetFrameLevel(BAG_FRAME_LEVEL + 5)
    end
    if frame.BagSlots then
        frame.BagSlots:SetFrameLevel(BAG_FRAME_LEVEL + 6)
    end
    if frame.SearchPanel then
        frame.SearchPanel:SetFrameLevel(BAG_FRAME_LEVEL + 10)
    end
    if frame.KeyringPanel then
        frame.KeyringPanel:SetFrameLevel(BAG_FRAME_LEVEL + 4)
    end
    if frame.CloseButton then
        frame.CloseButton:SetFrameLevel(BAG_FRAME_LEVEL + 15)
    end
    if frame.Header then
        frame.Header:SetFrameLevel(BAG_FRAME_LEVEL + 10)
    end
    if frame.RailToggleButton then
        frame.RailToggleButton:SetFrameLevel(BAG_FRAME_LEVEL + 15)
    end
    if frame.SettingsButton then
        frame.SettingsButton:SetFrameLevel(BAG_FRAME_LEVEL + 15)
    end
    if frame.CharacterButton then
        frame.CharacterButton:SetFrameLevel(BAG_FRAME_LEVEL + 15)
    end
    if frame.BankViewButton then
        frame.BankViewButton:SetFrameLevel(BAG_FRAME_LEVEL + 15)
    end
    if frame.ResizeGrip then
        frame.ResizeGrip:SetFrameLevel(BAG_FRAME_LEVEL + 18)
    end
    if frame.LeftResizeGrip then
        frame.LeftResizeGrip:SetFrameLevel(BAG_FRAME_LEVEL + 18)
    end
end

local function NotifyOptionsChanged()
    if not LibStub then
        return
    end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange("LunaBags")
    end
end

local function EnsureResizeGrip(owner, frame)
    if not frame.ResizeGrip then
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(16, 16)
        grip:SetNormalTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Down")
        grip:EnableMouse(true)
        grip:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then
                owner:StartResize("right")
            end
        end)
        grip:SetScript("OnMouseUp", function()
            owner:StopResize()
        end)
        grip:SetScript("OnHide", function()
            owner:StopResize()
        end)
        grip:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Resize")
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.ResizeGrip = grip
    end
    frame.ResizeGrip:ClearAllPoints()
    frame.ResizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.ResizeGrip:SetFrameLevel(BAG_FRAME_LEVEL + 18)

    if not frame.LeftResizeGrip then
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(16, 16)
        grip:SetNormalTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Down")
        grip:EnableMouse(true)
        grip:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then
                owner:StartResize("left")
            end
        end)
        grip:SetScript("OnMouseUp", function()
            owner:StopResize()
        end)
        grip:SetScript("OnHide", function()
            owner:StopResize()
        end)
        grip:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Resize")
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.LeftResizeGrip = grip
    end
    local normal = frame.LeftResizeGrip.GetNormalTexture and frame.LeftResizeGrip:GetNormalTexture()
    if normal then
        normal:SetTexCoord(1, 0, 0, 1)
    end
    local highlight = frame.LeftResizeGrip.GetHighlightTexture and frame.LeftResizeGrip:GetHighlightTexture()
    if highlight then
        highlight:SetTexCoord(1, 0, 0, 1)
    end
    local pushed = frame.LeftResizeGrip.GetPushedTexture and frame.LeftResizeGrip:GetPushedTexture()
    if pushed then
        pushed:SetTexCoord(1, 0, 0, 1)
    end
    frame.LeftResizeGrip:ClearAllPoints()
    frame.LeftResizeGrip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.LeftResizeGrip:SetFrameLevel(BAG_FRAME_LEVEL + 18)
end

local function GetScrollBar(scrollFrame)
    if not scrollFrame then
        return nil
    end
    return scrollFrame.ScrollBar or scrollFrame.scrollBar or (scrollFrame.GetName and _G[(scrollFrame:GetName() or "") .. "ScrollBar"])
end

local function SetScrollControlsShown(scrollFrame, shown)
    if not scrollFrame then
        return
    end
    local scrollBar = GetScrollBar(scrollFrame)
    if scrollBar then
        scrollBar:SetShown(shown)
        if shown then
            scrollBar:Show()
        else
            scrollBar:Hide()
        end
    end
    if scrollFrame.LunaBagsScrollTrack then
        scrollFrame.LunaBagsScrollTrack:SetShown(shown)
    end
    if scrollFrame.LunaBagsScrollUpButton then
        scrollFrame.LunaBagsScrollUpButton:SetShown(shown)
    end
    if scrollFrame.LunaBagsScrollDownButton then
        scrollFrame.LunaBagsScrollDownButton:SetShown(shown)
    end
end

local function StyleScrollButton(button, label)
    if not button then
        return
    end
    button:SetSize(12, 12)
    if button.SetNormalTexture then button:SetNormalTexture("Interface\\Buttons\\WHITE8X8") end
    if button.SetPushedTexture then button:SetPushedTexture("Interface\\Buttons\\WHITE8X8") end
    if button.SetHighlightTexture then button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8") end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetVertexColor(0.10, 0.10, 0.10, 0.95) end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then pushed:SetVertexColor(0.16, 0.16, 0.16, 1) end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(0.28, 0.28, 0.28, 0.55) end
    if not button.LunaBagsLabel then
        button.LunaBagsLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.LunaBagsLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
    button.LunaBagsLabel:SetText(label)
    button.LunaBagsLabel:SetTextColor(0.78, 0.78, 0.78, 1)
end

local function StyleScrollFrame(scrollFrame)
    if not scrollFrame then
        return
    end
    local scrollBar = GetScrollBar(scrollFrame)
    if not scrollBar then
        return
    end
    local scrollName = scrollBar.GetName and scrollBar:GetName() or nil
    local upButton = scrollBar.ScrollUpButton or scrollBar.ScrollUp or (scrollName and (_G[scrollName .. "ScrollUpButton"] or _G[scrollName .. "UpButton"]))
    local downButton = scrollBar.ScrollDownButton or scrollBar.ScrollDown or (scrollName and (_G[scrollName .. "ScrollDownButton"] or _G[scrollName .. "DownButton"]))

    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 7, -14)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 7, 14)
    scrollBar:SetWidth(10)
    scrollBar:SetFrameLevel((scrollFrame:GetFrameLevel() or BAG_FRAME_LEVEL) + 2)

    if not scrollFrame.LunaBagsScrollTrack then
        scrollFrame.LunaBagsScrollTrack = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
        scrollFrame.LunaBagsScrollTrack:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
    end
    scrollFrame.LunaBagsScrollTrack:ClearAllPoints()
    scrollFrame.LunaBagsScrollTrack:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", -1, 0)
    scrollFrame.LunaBagsScrollTrack:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", 1, 0)
    scrollFrame.LunaBagsScrollTrack:SetFrameLevel(scrollBar:GetFrameLevel() - 1)
    scrollFrame.LunaBagsScrollTrack:SetBackdropColor(0.035, 0.035, 0.035, 0.72)
    scrollFrame.LunaBagsScrollTrack:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.85)

    local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or scrollBar.ThumbTexture
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetVertexColor(0.42, 0.42, 0.42, 0.92)
        thumb:SetWidth(8)
    end

    if upButton then
        scrollFrame.LunaBagsScrollUpButton = upButton
        upButton:ClearAllPoints()
        upButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, 2)
        StyleScrollButton(upButton, "^")
    end
    if downButton then
        scrollFrame.LunaBagsScrollDownButton = downButton
        downButton:ClearAllPoints()
        downButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, -2)
        StyleScrollButton(downButton, "v")
    end
end

local function EnsureScrollFrame(frame)
    if not frame or not frame.content then
        return nil
    end
    if not frame.ScrollFrame then
        frame.ScrollFrame = CreateFrame("ScrollFrame", "LunaBagsOneBagScrollFrame", frame, "UIPanelScrollFrameTemplate")
        frame.ScrollFrame:SetFrameLevel(BAG_FRAME_LEVEL + 5)
        frame.ScrollFrame:EnableMouseWheel(true)
        frame.ScrollFrame:SetScript("OnMouseWheel", function(scrollFrame, delta)
            local maxScroll = math.max(0, scrollFrame:GetVerticalScrollRange() or 0)
            if maxScroll <= 0 then
                return
            end
            local step = 48
            local current = scrollFrame:GetVerticalScroll() or 0
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, current - (delta * step))))
        end)
    end
    if frame.content.SetParent and frame.content:GetParent() ~= frame.ScrollFrame then
        frame.content:SetParent(frame.ScrollFrame)
    end
    frame.content:SetFrameLevel(BAG_FRAME_LEVEL + 5)
    if frame.ScrollFrame:GetScrollChild() ~= frame.content then
        frame.ScrollFrame:SetScrollChild(frame.content)
    end
    StyleScrollFrame(frame.ScrollFrame)
    return frame.ScrollFrame
end

local function IsDebugEnabled()
    local addon = ns.LunaBags
    return addon and addon.db and addon.db.profile and addon.db.profile.debug == true
end

local function Clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function GetColorValue(color, r, g, b)
    if type(color) ~= "table" then
        return r, g, b
    end
    return tonumber(color.r or color[1]) or r,
        tonumber(color.g or color[2]) or g,
        tonumber(color.b or color[3]) or b
end

local function GetAppearanceConfig(cfg)
    local profile = ns.LunaBags and ns.LunaBags.db and ns.LunaBags.db.profile
    local shared = profile and profile.ui or nil
    if type(shared) == "table" then
        local merged = {}
        if type(cfg) == "table" then
            for k, v in pairs(cfg) do
                merged[k] = v
            end
        end
        for k, v in pairs(shared) do
            merged[k] = v
        end
        return merged
    end
    return cfg or {}
end

local function ApplyWindowAppearance(frame, cfg)
    if ns.WindowChrome and ns.WindowChrome.ApplyAppearance then
        ns.WindowChrome.ApplyAppearance(frame, cfg)
        return
    end
    if not frame then
        return
    end
    cfg = GetAppearanceConfig(cfg)
    local wr, wg, wb = GetColorValue(cfg.windowColor, 0.12, 0.12, 0.12)
    local hr, hg, hb = GetColorValue(cfg.headerColor, 0.07, 0.07, 0.07)
    local windowOpacity = Clamp01(cfg.windowOpacity, 0.72)
    local headerOpacity = Clamp01(cfg.headerOpacity, 0.78)

    if frame.WindowBg then
        frame.WindowBg:SetVertexColor(wr, wg, wb, windowOpacity)
    end
    if frame.TitleBarBg then
        frame.TitleBarBg:SetVertexColor(hr, hg, hb, headerOpacity)
    end
    if frame.DarkInset then
        frame.DarkInset:SetVertexColor(wr * 0.18, wg * 0.18, wb * 0.18, math.min(1, windowOpacity * 0.9))
    end
    if frame.StatusBg then
        frame.StatusBg:SetVertexColor(wr * 0.85, wg * 0.85, wb * 0.85, math.min(1, windowOpacity * 0.95))
    end
    if frame.SearchPanel then
        frame.SearchPanel:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity * 0.95))
    end
    if frame.BagSlots then
        frame.BagSlots:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity))
    end
    if frame.KeyringPanel then
        frame.KeyringPanel:SetBackdropColor(wr * 0.25, wg * 0.25, wb * 0.25, math.min(1, windowOpacity))
    end
end

local function EnsureVisibleBagDefaults(state)
    for bagID = 0, 4 do
        if state[bagID] == nil then
            state[bagID] = true
        end
    end
    if KEYRING_CONTAINER and state[KEYRING_CONTAINER] == nil then
        state[KEYRING_CONTAINER] = false
    end
end

local function CopyVisibleBagsState(state)
    local out = {}
    if type(state) == "table" then
        for k, v in pairs(state) do
            local n = tonumber(k)
            local key = n or k
            out[key] = v ~= false
        end
    end
    EnsureVisibleBagDefaults(out)
    return out
end

local function GetBackpackIcon()
    if MainMenuBarBackpackButtonIconTexture and MainMenuBarBackpackButtonIconTexture.GetTexture then
        return MainMenuBarBackpackButtonIconTexture:GetTexture()
    end
    return "Interface\\Buttons\\Button-Backpack-Up"
end

local function IsKeyringBag(bagID)
    return KEYRING_CONTAINER and bagID == KEYRING_CONTAINER
end

local function GetCurrentCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return ("%s-%s"):format(name, realm)
end

function OneBag:GetCurrentCharacterKey()
    return GetCurrentCharacterKey()
end

local function NormalizeCharacterKey(key)
    return tostring(key or ""):lower():gsub("%s+", "")
end

local function IsViewingCurrentCharacter()
    return not OneBag.viewCharacterKey or NormalizeCharacterKey(OneBag.viewCharacterKey) == NormalizeCharacterKey(GetCurrentCharacterKey())
end

local function GetViewedCharacterData()
    if not ns.BagData or not OneBag.viewCharacterKey then
        return nil
    end
    local direct = ns.BagData:GetCharacterData(OneBag.viewCharacterKey)
    if direct then
        return direct
    end
    local target = tostring(OneBag.viewCharacterKey or ""):lower():gsub("%s+", "")
    for key, c in ns.BagData:IterCharacters() do
        if key == OneBag.viewCharacterKey then
            return c
        end
        if c and c.name and c.realm and (c.name .. "-" .. c.realm) == OneBag.viewCharacterKey then
            return c
        end
        local keyNorm = tostring(key or ""):lower():gsub("%s+", "")
        if keyNorm == target then
            return c
        end
        if c and c.name and c.realm then
            local charNorm = ((c.name or "") .. "-" .. (c.realm or "")):lower():gsub("%s+", "")
            if charNorm == target then
                return c
            end
        end
    end
    return nil
end

function OneBag:GetViewedCharacterData()
    return GetViewedCharacterData()
end

function OneBag:SetViewCharacterKey(characterKey)
    local currentKey = GetCurrentCharacterKey()
    if not characterKey or characterKey == "" or NormalizeCharacterKey(characterKey) == NormalizeCharacterKey(currentKey) then
        self.viewCharacterKey = nil
        if ns.LunaBags and ns.LunaBags.RestoreCurrentCharacterProfile then
            ns.LunaBags:RestoreCurrentCharacterProfile()
        end
    else
        local resolvedKey = characterKey
        if ns.BagData and ns.BagData.GetCharacterData then
            local data = ns.BagData:GetCharacterData(characterKey)
            if data and data.name and data.realm then
                resolvedKey = data.name .. "-" .. data.realm
            end
        end
        self.viewCharacterKey = resolvedKey
        if ns.LunaBags and ns.LunaBags.ActivateCharacterProfileView then
            ns.LunaBags:ActivateCharacterProfileView(resolvedKey)
        end
    end
    self:InvalidateSlotCache()
end

local function CountSlotsFromTable(slots)
    if type(slots) ~= "table" then
        return 0
    end
    local maxSlot = 0
    for k in pairs(slots) do
        local n = tonumber(k)
        if n and n > maxSlot then
            maxSlot = n
        end
    end
    return maxSlot
end

local function GetCharacterBagData(character, bagID, useBank)
    if not character then
        return nil
    end
    local container = useBank and character.bank or character.bags
    if type(container) ~= "table" then
        return nil
    end
    return container[bagID] or container[tostring(bagID)]
end

local function GetCharacterBagSlot(bagData, slot)
    if type(bagData) ~= "table" then
        return nil
    end
    local slots = type(bagData.slots) == "table" and bagData.slots or bagData
    return slots[slot] or slots[tostring(slot)]
end

local function GetCharacterBagSlotsTable(bagData)
    if type(bagData) ~= "table" then
        return nil
    end
    if type(bagData.slots) == "table" then
        return bagData.slots
    end
    return bagData
end

local function GetCharacterBagSlotCount(bagData)
    if type(bagData) ~= "table" then
        return 0
    end
    local size = tonumber(bagData.size)
    if size and size > 0 then
        return size
    end
    local slots = GetCharacterBagSlotsTable(bagData)
    return CountSlotsFromTable(slots)
end

local AddCharacterItemCountTooltip
local AddMoneyTooltipBreakdown

local function FormatMoneyText(money, iconSize)
    local amount = tonumber(money) or 0
    local size = tonumber(iconSize) or 14
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100

    local function Coin(path)
        return ("|T%s:%d:%d:0:2|t"):format(path, size, size)
    end

    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = ("%d %s"):format(gold, Coin("Interface\\MoneyFrame\\UI-GoldIcon"))
    end
    if silver > 0 or gold > 0 then
        parts[#parts + 1] = ("%d %s"):format(silver, Coin("Interface\\MoneyFrame\\UI-SilverIcon"))
    end
    parts[#parts + 1] = ("%d %s"):format(copper, Coin("Interface\\MoneyFrame\\UI-CopperIcon"))
    return table.concat(parts, "  ")
end

local function CountSlotUsage(slots)
    local used, total = 0, 0
    for _, entry in ipairs(slots or {}) do
        if not entry.virtualEmpty then
            total = total + 1
            if entry.item then
                used = used + 1
            end
        end
    end
    return used, total
end

local function FormatSlotUsageText(used, total)
    return ("%d/%d"):format(tonumber(used) or 0, tonumber(total) or 0)
end

local function GetCursorItemID()
    if not GetCursorInfo then
        return nil
    end
    local cursorType, value1, value2, value3 = GetCursorInfo()
    if cursorType ~= "item" then
        return nil
    end
    if tonumber(value1) then
        return tonumber(value1)
    end
    local function MatchItemID(value)
        if type(value) == "string" then
            local itemID = tonumber(value:match("item:(%d+)"))
            if itemID then
                return itemID
            end
        end
        return nil
    end
    return MatchItemID(value1) or MatchItemID(value2) or MatchItemID(value3)
end

local function CursorHasAssignableItem()
    if CursorHasItem and CursorHasItem() then
        return true
    end
    if GetCursorInfo then
        return GetCursorInfo() == "item"
    end
    return false
end

local function BuildCursorCategoryItem(itemID)
    local item = { itemID = itemID }
    local itemName, itemLink, itemQuality, itemLevel, _, itemTypeName, subTypeName, _, equipLoc, _, sellPrice, classID, subClassID
    if GetItemInfo then
        itemName, itemLink, itemQuality, itemLevel, _, itemTypeName, subTypeName, _, equipLoc, _, sellPrice, classID, subClassID = GetItemInfo(itemID)
    end
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInstant and (classID == nil or subClassID == nil or equipLoc == nil or itemTypeName == nil or subTypeName == nil) then
        local _, instantTypeName, instantSubTypeName, instantEquipLoc, _, instantClassID, instantSubClassID = getInstant(itemID)
        itemTypeName = itemTypeName or instantTypeName
        subTypeName = subTypeName or instantSubTypeName
        equipLoc = equipLoc or instantEquipLoc
        classID = classID or instantClassID
        subClassID = subClassID or instantSubClassID
    end
    item.name = itemName
    item.itemLink = itemLink
    item.quality = itemQuality
    item.itemLevel = itemLevel
    item.itemTypeName = itemTypeName
    item.subTypeName = subTypeName
    item.equipLoc = equipLoc
    item.sellPrice = sellPrice
    item.classID = classID
    item.subClassID = subClassID
    return item
end

local function AssignCursorItemToCategory(owner, category)
    local itemID = GetCursorItemID()
    if not itemID or not category or not ns.Categories or not ns.Categories.AddItemIDRule then
        return false
    end

    local item = BuildCursorCategoryItem(itemID)
    local matchedByRules = ns.Categories.ItemMatchesNonItemIDRules
        and ns.Categories:ItemMatchesNonItemIDRules(category, item)
    local added = matchedByRules and false or ns.Categories:AddItemIDRule(category, itemID)
    local unblacklisted = ns.Categories.RemoveBlacklistItemID and ns.Categories:RemoveBlacklistItemID(category, itemID)
    if ClearCursor then
        ClearCursor()
    end
    if added or unblacklisted then
        if owner then
            owner._layoutModel = nil
            if owner.Refresh then
                owner:Refresh()
            end
        end
        NotifyOptionsChanged()
        if ns.LunaBags and ns.LunaBags.Print then
            local action = added and "Added" or "Restored"
            ns.LunaBags:Print(("%s item ID %d to category %s."):format(action, itemID, category.name or "Category"))
        end
    elseif ns.LunaBags and ns.LunaBags.Print then
        ns.LunaBags:Print(("Item ID %d is already assigned to category %s."):format(itemID, category.name or "Category"))
    end
    return added or unblacklisted
end

local function RemoveDraggedItemFromCategory(owner)
    local drag = owner and owner.draggedCategoryItem
    if not drag or not drag.category or not drag.itemID or not ns.Categories then
        return false
    end

    local removed = ns.Categories.RemoveItemIDRule and ns.Categories:RemoveItemIDRule(drag.category, drag.itemID)
    local blacklisted = false
    if not removed and ns.Categories.AddBlacklistItemID then
        blacklisted = ns.Categories:AddBlacklistItemID(drag.category, drag.itemID)
    end
    owner.draggedCategoryItem = nil
    if ClearCursor then
        ClearCursor()
    end
    if owner.inventoryDropOverlay then
        owner.inventoryDropOverlay:Hide()
    end

    if removed or blacklisted then
        owner._layoutModel = nil
        if owner.Refresh then
            owner:Refresh()
        end
        NotifyOptionsChanged()
        if ns.LunaBags and ns.LunaBags.Print then
            local action = removed and "Removed" or "Blacklisted"
            ns.LunaBags:Print(("%s item ID %d from category %s."):format(action, drag.itemID, drag.category.name or "Category"))
        end
    end

    return removed or blacklisted
end

local function ShowInventoryDropOverlay(owner, shown)
    if not owner or not owner.frame or not owner.frame.content then
        return
    end
    if not owner.inventoryDropOverlay then
        local overlay = CreateFrame("Frame", nil, owner.frame.content, "BackdropTemplate")
        overlay:SetAllPoints(owner.frame.content)
        overlay:SetFrameLevel((owner.frame.content:GetFrameLevel() or BAG_FRAME_LEVEL) + 80)
        overlay:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        overlay:SetBackdropColor(0.05, 0.24, 0.36, 0.22)
        overlay:SetBackdropBorderColor(0.20, 0.72, 1.0, 0.85)
        overlay:EnableMouse(true)
        overlay:SetScript("OnReceiveDrag", function()
            RemoveDraggedItemFromCategory(owner)
        end)
        overlay:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and CursorHasAssignableItem() then
                RemoveDraggedItemFromCategory(owner)
            end
        end)
        overlay:SetScript("OnUpdate", function(self)
            if not owner.draggedCategoryItem or not CursorHasAssignableItem() then
                self:Hide()
            end
        end)
        overlay:Hide()
        owner.inventoryDropOverlay = overlay
    end
    owner.inventoryDropOverlay:SetShown(shown == true)
end

local function TrackCategoryDragFromButton(owner, button)
    if not owner or not button then
        return
    end
    local item = button.itemData
    local itemID = tonumber(item and item.itemID)
    if button.category and itemID then
        owner.draggedCategoryItem = {
            category = button.category,
            itemID = itemID,
        }
        ShowInventoryDropOverlay(owner, true)
    else
        owner.draggedCategoryItem = nil
        ShowInventoryDropOverlay(owner, false)
    end
end

local function ConfigureCategoryPlaceholder(frame, owner, category)
    if not frame then
        return
    end
    frame.category = category
    frame:EnableMouse(category ~= nil)
    frame:SetScript("OnReceiveDrag", nil)
    frame:SetScript("OnMouseUp", nil)
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    if not category then
        return
    end

    frame:SetScript("OnReceiveDrag", function(self)
        AssignCursorItemToCategory(owner, self.category)
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasAssignableItem() then
            AssignCursorItemToCategory(owner, self.category)
        end
    end)
    frame:SetScript("OnEnter", function(self)
        if GameTooltip and CursorHasAssignableItem() then
            self:SetBackdropColor(0.05, 0.24, 0.36, 0.45)
            self:SetBackdropBorderColor(0.20, 0.72, 1.0, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Assign item to category")
            GameTooltip:AddLine(category.name or "Category", 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.03, 0.03, 0.03, 0.35)
        self:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.5)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function ConfigureCategoryDropTarget(frame, owner, target)
    if not frame then
        return
    end
    frame.category = target and target.category or nil
    frame:SetScript("OnReceiveDrag", nil)
    frame:SetScript("OnMouseUp", nil)
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    frame:SetScript("OnUpdate", nil)
    frame:EnableMouse(false)
    frame:SetAlpha(0)
    if not target or not target.category then
        return
    end

    frame:SetScript("OnUpdate", function(self)
        local active = CursorHasAssignableItem()
        self:EnableMouse(active)
        self:SetAlpha(active and 1 or 0)
        if active then
            self:SetBackdropColor(0.05, 0.24, 0.36, 0.18)
            self:SetBackdropBorderColor(0.20, 0.72, 1.0, 0.75)
        end
    end)
    frame:SetScript("OnReceiveDrag", function(self)
        AssignCursorItemToCategory(owner, self.category)
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasAssignableItem() then
            AssignCursorItemToCategory(owner, self.category)
        end
    end)
    frame:SetScript("OnEnter", function(self)
        if CursorHasAssignableItem() then
            self:SetBackdropColor(0.05, 0.24, 0.36, 0.38)
            self:SetBackdropBorderColor(0.20, 0.72, 1.0, 0.95)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Assign item to category")
                GameTooltip:AddLine(self.category.name or "Category", 0.85, 0.85, 0.85)
                GameTooltip:Show()
            end
        end
    end)
    frame:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.05, 0.24, 0.36, 0.18)
        self:SetBackdropBorderColor(0.20, 0.72, 1.0, 0.75)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function EnsureTooltipPostHook()
    if ns.Tooltip and ns.Tooltip.EnsureHooks then
        ns.Tooltip:EnsureHooks()
    end
end

local function ApplyTestButtonStyle(button)
    if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
        ns.ItemButtonStyle.Apply(button)
        return
    end
    if not button.StyleBG then
        button.StyleBG = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBG:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.StyleBG:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.StyleBG:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        button.StyleBG:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
        })
        button.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
    end

    if not button.StyleBorder then
        button.StyleBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.StyleBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.StyleBorder:SetFrameLevel(button:GetFrameLevel() + 2)
        button.StyleBorder:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        button.StyleBorder:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)
    end
    if not button.StyleGlow then
        button.StyleGlow = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.StyleGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.StyleGlow:SetFrameLevel(button:GetFrameLevel() + 3)
        button.StyleGlow:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
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
    if normal then
        normal:SetTexture(nil)
        normal:Hide()
    end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then
        pushed:SetTexture(nil)
        pushed:Hide()
    end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        highlight:SetTexture(nil)
        highlight:Hide()
    end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then
        checked:SetTexture(nil)
        checked:Hide()
    end

    if button.IconBorder then
        button.IconBorder:SetAlpha(0)
        button.IconBorder:Hide()
    end
    if button.Background then
        button.Background:SetTexture(nil)
        button.Background:Hide()
    end
    if button.IconOverlay then
        button.IconOverlay:SetTexture(nil)
        button.IconOverlay:Hide()
    end
    if button.IconOverlay2 then
        button.IconOverlay2:SetTexture(nil)
        button.IconOverlay2:Hide()
    end
    if button.searchOverlay then
        button.searchOverlay:Hide()
    end
    if button.NewItemTexture then
        button.NewItemTexture:Hide()
    end
    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:Hide()
    end
    if button.flashAnim then
        button.flashAnim:Stop()
    end

    if not button.StyleStateHooks then
        local function Brighten(v, amount)
            return math.min(1, (v or 0) + amount)
        end
        local function SetIdle(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
            self.StyleBorder:SetBackdropBorderColor(
                self.StyleBorderBaseR or 0.34,
                self.StyleBorderBaseG or 0.34,
                self.StyleBorderBaseB or 0.34,
                self.StyleBorderBaseA or 0.95
            )
            if self.StyleGlow then
                self.StyleGlow:Hide()
            end
        end
        local function SetHover(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(0.17, 0.17, 0.17, 0.95)
            self.StyleBorder:SetBackdropBorderColor(
                Brighten(self.StyleBorderBaseR or 0.34, 0.10),
                Brighten(self.StyleBorderBaseG or 0.34, 0.10),
                Brighten(self.StyleBorderBaseB or 0.34, 0.10),
                self.StyleBorderBaseA or 0.98
            )
            if self.StyleGlow then
                self.StyleGlow:SetBackdropBorderColor(
                    Brighten(self.StyleBorderBaseR or 0.34, 0.18),
                    Brighten(self.StyleBorderBaseG or 0.34, 0.18),
                    Brighten(self.StyleBorderBaseB or 0.34, 0.18),
                    0.9
                )
                self.StyleGlow:Show()
            end
        end
        local function SetDrag(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self:SetAlpha(math.max(0.1, (self._baseAlpha or 1) * 0.72))
            self.StyleBG:SetBackdropColor(0.20, 0.20, 0.20, 0.98)
            self.StyleBorder:SetBackdropBorderColor(
                Brighten(self.StyleBorderBaseR or 0.34, 0.20),
                Brighten(self.StyleBorderBaseG or 0.34, 0.20),
                Brighten(self.StyleBorderBaseB or 0.34, 0.20),
                1
            )
            if self.StyleGlow then
                self.StyleGlow:SetBackdropBorderColor(
                    Brighten(self.StyleBorderBaseR or 0.34, 0.22),
                    Brighten(self.StyleBorderBaseG or 0.34, 0.22),
                    Brighten(self.StyleBorderBaseB or 0.34, 0.22),
                    0.95
                )
                self.StyleGlow:Show()
            end
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

local function StripBagButtonDefaultArt(button)
    if not button then
        return
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetTexture(nil); normal:Hide() end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then pushed:SetTexture(nil); pushed:Hide() end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then highlight:SetTexture(nil); highlight:Hide() end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then checked:SetTexture(nil); checked:Hide() end

    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region ~= button.icon then
            region:SetTexture(nil)
            region:Hide()
        end
    end
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

local function GetConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.oneBag = addon.db.profile.oneBag or {}
    local cfg = addon.db.profile.oneBag
    cfg.splitBags = cfg.splitBags or {}
    cfg.visibleBags = cfg.visibleBags or {}
    if addon.db.profile.oneBag._splitBagsMigrated ~= true then
        local key = GetCurrentCharacterKey()
        local old = type(cfg.perCharacter) == "table" and key and cfg.perCharacter[key] or nil
        old = type(old) == "table" and old.splitBags or cfg.splitBags
        if type(old) == "table" and old ~= cfg.splitBags then
            for bagID, enabled in pairs(old) do
                if cfg.splitBags[bagID] == nil then
                    cfg.splitBags[bagID] = enabled == true or nil
                end
            end
        end
        addon.db.profile.oneBag._splitBagsMigrated = true
    end
    if addon.db.profile.oneBag._viewOptionsPerCharMigrated ~= true then
        local key = GetCurrentCharacterKey()
        local old = type(cfg.perCharacter) == "table" and key and cfg.perCharacter[key] or nil
        if type(old) == "table" then
            if cfg.splitByBagRows == nil and old.splitByBagRows ~= nil then
                cfg.splitByBagRows = old.splitByBagRows == true or nil
            end
            if cfg.showBagRail == nil and old.showBagRail ~= nil then
                cfg.showBagRail = old.showBagRail ~= false
            end
            if type(old.visibleBags) == "table" then
                for bagID, enabled in pairs(old.visibleBags) do
                    if cfg.visibleBags[bagID] == nil then
                        cfg.visibleBags[bagID] = enabled ~= false
                    end
                end
            end
        end
        addon.db.profile.oneBag._viewOptionsPerCharMigrated = true
    end
    return addon.db.profile.oneBag
end

local function IsBagSplitEnabled(bagID)
    local cfg = GetConfig()
    if not cfg then
        return false
    end
    cfg.splitBags = cfg.splitBags or {}
    return cfg.splitBags[bagID] == true
end

local function SetBagSplitEnabled(bagID, enabled)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    cfg.splitBags = cfg.splitBags or {}
    cfg.splitBags[bagID] = enabled == true or nil
    OneBag:InvalidateSlotCache()
end

local function GetSortingConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.sorting = addon.db.profile.sorting or {}
    addon.db.profile.sorting.perCharacter = addon.db.profile.sorting.perCharacter or {}
    local key = GetCurrentCharacterKey()
    local perChar = addon.db.profile.sorting.perCharacter[key] or {}
    addon.db.profile.sorting.perCharacter[key] = perChar
    perChar.lockedSlots = perChar.lockedSlots or {}
    if addon.db.profile.sorting._lockedSlotsMigrated ~= true then
        local old = addon.db.profile.sorting.lockedSlots
        if type(old) == "table" then
            for slotKey, locked in pairs(old) do
                if perChar.lockedSlots[slotKey] == nil then
                    perChar.lockedSlots[slotKey] = locked == true or nil
                end
            end
        end
        addon.db.profile.sorting._lockedSlotsMigrated = true
    end
    addon.db.profile.sorting._activeCharacter = key
    addon.db.profile.sorting._activeCharacterData = perChar
    return addon.db.profile.sorting
end

local function IsVisualSortEnabled()
    local cfg = GetSortingConfig()
    return cfg and cfg.visualOnly == true or false
end

local function GetSlotKey(bagID, slot)
    return tostring(bagID) .. ":" .. tostring(slot)
end

local function GetNewItemSignature(item)
    if not item then
        return nil
    end
    return tostring(item.itemLink or item.itemID or "") .. ":" .. tostring(item.stackCount or 0)
end

local function IsSlotNewItem(bagID, slot, item)
    if not item or not IsViewingCurrentCharacter() then
        return false
    end

    if C_NewItems and C_NewItems.IsNewItem then
        local ok, isNew = pcall(C_NewItems.IsNewItem, bagID, slot)
        if ok and isNew == true then
            return true
        end
    end

    local key = GetSlotKey(bagID, slot)
    local signature = GetNewItemSignature(item)
    OneBag.newItemSignatures[key] = signature

    local now = GetTime and GetTime() or 0
    return (OneBag.newItemGlowUntil[key] or 0) > now
end

local function IsSlotUserLocked(bagID, slot)
    local cfg = GetSortingConfig()
    local perChar = cfg and cfg._activeCharacterData or nil
    if not perChar or not perChar.lockedSlots then
        return false
    end
    return perChar.lockedSlots[GetSlotKey(bagID, slot)] == true
end

local function SetSlotUserLocked(bagID, slot, locked)
    local cfg = GetSortingConfig()
    if not cfg then
        return
    end
    local perChar = cfg._activeCharacterData or {}
    perChar.lockedSlots = perChar.lockedSlots or {}
    perChar.lockedSlots[GetSlotKey(bagID, slot)] = locked == true or nil
end

local function ToggleSlotLockFromButton(button)
    if not button then
        return
    end
    local bagID = button.bagID or button.BagID
    local slot = button.slot or button.SlotID or button:GetID()
    if not bagID or not slot then
        return
    end
    local currentlyLocked = IsSlotUserLocked(bagID, slot)
    SetSlotUserLocked(bagID, slot, not currentlyLocked)
end

local function EnsureLockedCross(button)
    if button.LockedCross then
        return button.LockedCross
    end
    local cross = button:CreateTexture(nil, "OVERLAY")
    cross:SetTexture("Interface\\Buttons\\WHITE8X8")
    cross:SetVertexColor(0.95, 0.15, 0.15, 0.95)
    cross:SetSize(2, 2)
    cross:Hide()

    local d1 = button:CreateLine(nil, "OVERLAY")
    d1:SetColorTexture(0.95, 0.15, 0.15, 0.95)
    d1:SetThickness(2)
    d1:SetStartPoint("TOPLEFT", 3, -3)
    d1:SetEndPoint("BOTTOMRIGHT", -3, 3)

    local d2 = button:CreateLine(nil, "OVERLAY")
    d2:SetColorTexture(0.95, 0.15, 0.15, 0.95)
    d2:SetThickness(2)
    d2:SetStartPoint("TOPRIGHT", -3, -3)
    d2:SetEndPoint("BOTTOMLEFT", 3, 3)

    cross.d1 = d1
    cross.d2 = d2
    button.LockedCross = cross
    return cross
end

local function EnsureNewItemGlow(button)
    if button.NewItemGlow then
        return button.NewItemGlow
    end

    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1.0, 0.86, 0.18, 0.95)
    glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    glow:SetSize(68, 68)
    glow:Hide()

    local anim = glow:CreateAnimationGroup()
    anim:SetLooping("REPEAT")
    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.95)
    fadeOut:SetToAlpha(0.35)
    fadeOut:SetDuration(0.55)
    fadeOut:SetOrder(1)
    local fadeIn = anim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.35)
    fadeIn:SetToAlpha(0.95)
    fadeIn:SetDuration(0.55)
    fadeIn:SetOrder(2)
    glow.anim = anim

    button.NewItemGlow = glow
    return glow
end

local function SetNewItemGlowShown(button, shown)
    local glow = EnsureNewItemGlow(button)
    if shown then
        glow:Show()
        if glow.anim and not glow.anim:IsPlaying() then
            glow.anim:Play()
        end
        return
    end

    if glow.anim and glow.anim:IsPlaying() then
        glow.anim:Stop()
    end
    glow:Hide()
end

local function ClearNewItemGlowForSlot(bagID, slot)
    local key = GetSlotKey(bagID, slot)
    OneBag.newItemGlowUntil[key] = nil

    if C_NewItems and C_NewItems.RemoveNewItem then
        pcall(C_NewItems.RemoveNewItem, bagID, slot)
    end
end

local function ClearAllNewItemGlows()
    OneBag.newItemGlowUntil = {}
    for _, collection in ipairs({ OneBag.buttons, OneBag.readonlyButtons, OneBag.keyringButtons }) do
        for _, button in ipairs(collection or {}) do
            if button and button.NewItemGlow then
                SetNewItemGlowShown(button, false)
            end
        end
    end
end

local function EnsureLockOverlay(button)
    if button.LockOverlay then
        return button.LockOverlay
    end
    local overlay = CreateFrame("Button", nil, button)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    overlay:SetFrameLevel(button:GetFrameLevel() + 10)
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:SetScript("OnClick", function()
        ToggleSlotLockFromButton(button)
        OneBag:Refresh()
    end)
    overlay:SetScript("OnEnter", function()
        if button:GetScript("OnEnter") then
            button:GetScript("OnEnter")(button)
        end
    end)
    overlay:SetScript("OnLeave", function()
        if button:GetScript("OnLeave") then
            button:GetScript("OnLeave")(button)
        end
    end)
    overlay:Hide()
    button.LockOverlay = overlay
    return overlay
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

local function UpdateButtonStyleBorderForItem(button, itemInfo)
    if not button or not button.StyleBorder then
        return
    end

    local addon = ns and ns.LunaBags
    local qualityEnabled = not addon
        or not addon.db
        or not addon.db.profile
        or not addon.db.profile.plugins
        or addon.db.profile.plugins.qualityBorder ~= false

    if ns.ItemButtonStyle and ns.ItemButtonStyle.UpdateBorderForItem then
        ns.ItemButtonStyle.UpdateBorderForItem(button, itemInfo, qualityEnabled)
        return
    end
    local quality = qualityEnabled and itemInfo and itemInfo.quality or nil
    if qualityEnabled and quality == nil and itemInfo and itemInfo.itemLink and GetItemInfo then
        local _, _, q = GetItemInfo(itemInfo.itemLink)
        quality = q
    end
    local r, g, b, a = ResolveQualityBorderColor(quality)
    button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = r, g, b, a
    button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
end

local function GetItemInfoFromBag(bagID, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bagID, slot)
    end
    local texture, count, locked, quality = GetContainerItemInfo(bagID, slot)
    if not texture then
        return nil
    end
    return {
        iconFileID = texture,
        stackCount = count or 1,
        isLocked = locked,
        quality = quality,
    }
end

local function GetItemLinkFromBag(bagID, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slot)
    end
    return GetContainerItemLink and GetContainerItemLink(bagID, slot)
end

local function GetNumSlotsInBag(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end
    return GetContainerNumSlots(bagID) or 0
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
    if ns.ItemButtonStyle and ns.ItemButtonStyle.ApplyTextStyle then
        ns.ItemButtonStyle.ApplyTextStyle(button)
    end
    return cd
end

local function ClearItemCooldown(button)
    if not button or not button.cooldown then
        return
    end
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
    if not cd then
        return
    end

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

local function KeyringHasItems()
    if not KEYRING_CONTAINER then
        return false
    end

    local slots = GetNumSlotsInBag(KEYRING_CONTAINER)
    for slot = 1, slots do
        local info = GetItemInfoFromBag(KEYRING_CONTAINER, slot)
        if info and info.iconFileID then
            return true
        end
    end
    return false
end

local function ItemMatchesSearch(item, searchText)
    if searchText == "" then
        return true
    end
    if not item then
        return false
    end

    local needle = searchText:lower()
    local name = item.name
    if not name and item.itemLink then
        name = GetItemInfo(item.itemLink)
    end

    if name and name:lower():find(needle, 1, true) then
        return true
    end
    if item.itemLink and item.itemLink:lower():find(needle, 1, true) then
        return true
    end
    if item.itemID and tostring(item.itemID):find(needle, 1, true) then
        return true
    end
    return false
end

function OneBag:UpdateSearchLayout()
    if not self.frame or not self.frame.content then
        return
    end

    local scrollFrame = EnsureScrollFrame(self.frame)
    local topInset = self.searchVisible and 34 or 12
    if scrollFrame then
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", self.frame.DarkInset, "TOPLEFT", 12, -topInset)
        scrollFrame:SetPoint("BOTTOMRIGHT", self.frame.DarkInset, "BOTTOMRIGHT", -12, 12)
        self.frame.content:ClearAllPoints()
        self.frame.content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    else
        self.frame.content:ClearAllPoints()
        self.frame.content:SetPoint("TOPLEFT", self.frame.DarkInset, "TOPLEFT", 12, -topInset)
        self.frame.content:SetPoint("BOTTOMRIGHT", self.frame.DarkInset, "BOTTOMRIGHT", -12, 12)
    end

    if self.frame.SearchPanel then
        self.frame.SearchPanel:SetShown(self.searchVisible)
    end
end

function OneBag:UpdateScrollFrame(contentHeight, viewportHeight)
    if not self.frame or not self.frame.content then
        return
    end
    local scrollFrame = EnsureScrollFrame(self.frame)
    if not scrollFrame then
        return
    end
    local contentWidth = math.max(1, scrollFrame:GetWidth() or self.frame.content:GetWidth() or 1)
    local childHeight = math.max(contentHeight or 1, viewportHeight or 1, 1)
    self._scrollContentHeight = contentHeight or 1
    self._scrollViewportHeight = viewportHeight or 1
    self.frame.content:SetSize(contentWidth, childHeight)
    local overflow = (contentHeight or 0) > ((viewportHeight or 0) + 1)
    scrollFrame:EnableMouseWheel(overflow)
    if not overflow then
        scrollFrame:SetVerticalScroll(0)
    else
        local maxScroll = math.max(0, childHeight - (viewportHeight or 0))
        local current = math.min(scrollFrame:GetVerticalScroll() or 0, maxScroll)
        scrollFrame:SetVerticalScroll(current)
    end
    SetScrollControlsShown(scrollFrame, overflow)
end

function OneBag:SetBagSlotPreview(bagID)
    if not self.buttons then
        return
    end

    for _, button in ipairs(self.buttons) do
        if button and button:IsShown() then
            if bagID == nil then
                button:SetAlpha(button._baseAlpha or 1)
                if button.StyleBorder then
                    button.StyleBorder:SetBackdropBorderColor(
                        button.StyleBorderBaseR or 0.34,
                        button.StyleBorderBaseG or 0.34,
                        button.StyleBorderBaseB or 0.34,
                        button.StyleBorderBaseA or 0.95
                    )
                end
            elseif button.bagID == bagID then
                button:SetAlpha(1)
                if button.StyleBorder then
                    button.StyleBorder:SetBackdropBorderColor(0.95, 0.78, 0.24, 1)
                end
            else
                button:SetAlpha(math.max(0.55, (button._baseAlpha or 1) * 0.65))
                if button.StyleBorder then
                    button.StyleBorder:SetBackdropBorderColor(
                        button.StyleBorderBaseR or 0.34,
                        button.StyleBorderBaseG or 0.34,
                        button.StyleBorderBaseB or 0.34,
                        math.min(button.StyleBorderBaseA or 0.95, 0.55)
                    )
                end
            end
        end
    end
end

function OneBag:CreateFrame()
    if self.frame then
        return
    end

    local frame = _G.LunaBagsOneBagFrame
    if not frame then
        frame = CreateFrame("Frame", "LunaBagsOneBagFrame", UIParent, "UIPanelDialogTemplate")
        frame:SetSize(520, 500)
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -34, 126)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata(BAG_FRAME_STRATA)
        frame:SetFrameLevel(BAG_FRAME_LEVEL)
        if frame.SetToplevel then
            frame:SetToplevel(true)
        end
        frame:Hide()
        frame.content = CreateFrame("Frame", nil, frame)
        frame.content:SetFrameLevel(BAG_FRAME_LEVEL + 5)
        frame.content:SetPoint("TOPLEFT", 8, -48)
        frame.content:SetPoint("BOTTOMRIGHT", -8, 36)
        frame.moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.moneyText:SetPoint("BOTTOMRIGHT", -16, 16)
    end
    ApplyBagFrameLayering(frame)
    EnsureStackSplitFrameAboveBags()
    EnsureVisibleBagDefaults(self.visibleBags)
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
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:EnableKeyboard(false)
    frame:SetScript("OnKeyDown", nil)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        OneBag:SavePosition()
    end)
    frame.content = frame.Content or frame.content
    EnsureScrollFrame(frame)
    frame.searchBox = frame.Header and frame.Header.SearchBox or nil
    frame.moneyText = (frame.MoneyBar and frame.MoneyBar.Text) or frame.moneyText
    frame.content:EnableMouse(true)
    frame.content:SetScript("OnReceiveDrag", function()
        RemoveDraggedItemFromCategory(OneBag)
    end)
    frame.content:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and CursorHasAssignableItem() then
            RemoveDraggedItemFromCategory(OneBag)
        end
    end)

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
    end
    if not frame.HeaderDrag then
        frame.HeaderDrag = CreateFrame("Frame", nil, frame)
        frame.HeaderDrag:EnableMouse(true)
        frame.HeaderDrag:RegisterForDrag("LeftButton")
        frame.HeaderDrag:SetScript("OnDragStart", function()
            if OneBag.frame and OneBag.frame:IsMovable() then
                OneBag.frame:StartMoving()
            end
        end)
        frame.HeaderDrag:SetScript("OnDragStop", function()
            if OneBag.frame then
                OneBag.frame:StopMovingOrSizing()
                OneBag:SavePosition()
            end
        end)
    end
    frame.HeaderDrag:ClearAllPoints()
    frame.HeaderDrag:SetPoint("TOPLEFT", frame.TitleBarBg, "TOPLEFT", 0, 0)
    frame.HeaderDrag:SetPoint("BOTTOMRIGHT", frame.TitleBarBg, "BOTTOMRIGHT", 0, 0)
    frame.HeaderDrag:SetFrameLevel(BAG_FRAME_LEVEL + 8)
    if not frame.DarkInset then
        frame.DarkInset = frame:CreateTexture(nil, "BORDER")
        frame.DarkInset:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.DarkInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
        frame.DarkInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 38)
    end
    if not frame.StatusBg then
        frame.StatusBg = frame:CreateTexture(nil, "ARTWORK")
        frame.StatusBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.StatusBg:SetPoint("TOPLEFT", frame.DarkInset, "BOTTOMLEFT", 0, 0)
        frame.StatusBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    if not frame.OuterBorder then
        frame.OuterBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.OuterBorder:SetAllPoints(frame)
        frame.OuterBorder:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        frame.OuterBorder:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
    end

    if not frame.CustomTitle then
        frame.CustomTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.CustomTitle:SetPoint("CENTER", frame.TitleBarBg, "CENTER", 0, 0)
        frame.CustomTitle:SetJustifyH("CENTER")
    end
    local viewedName = UnitName("player") or "Player"
    if OneBag.viewCharacterKey and ns.BagData then
        local data = GetViewedCharacterData()
        if data and data.name then
            viewedName = data.name
        end
    end
    frame.CustomTitle:SetText(string.format("%s - Bags", viewedName))

    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end
    if frame.CloseButton then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("TOPRIGHT", frame.TitleBarBg, "TOPRIGHT", -2, 2)
        frame.CloseButton:SetScript("OnClick", LunaBagsOneBag_Close)
    end

    if frame.Header then
        frame.Header:ClearAllPoints()
        frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame.Header:SetHeight(28)
        if frame.Header.Title then frame.Header.Title:Hide() end
    end

    if frame.Header and frame.Header.SearchBox then
        frame.Header.SearchBox:Hide()
    end
    if frame.Header and frame.Header.SearchToggle then
        local b = frame.Header.SearchToggle
        b:SetText("")
        b:SetNormalTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
        b:SetPushedTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:SetScript("OnClick", LunaBagsOneBag_SearchToggleClicked)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Search")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 49, 0)
    end
    if frame.Header and frame.Header.SortButton then
        local b = frame.Header.SortButton
        b:SetText("")
        b:SetNormalTexture("Interface\\AddOns\\LunaBags\\Art\\broom")
        b:SetPushedTexture("Interface\\AddOns\\LunaBags\\Art\\broom")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", LunaBagsOneBag_SortButtonClicked)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Sort")
            GameTooltip:AddLine("Right-click for lock mode.", 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 71, 0)
    end
    if not frame.CharacterButton then
        frame.CharacterButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.CharacterButton.Icon = frame.CharacterButton:CreateTexture(nil, "ARTWORK")
        frame.CharacterButton.Icon:SetPoint("TOPLEFT", frame.CharacterButton, "TOPLEFT", 0, 0)
        frame.CharacterButton.Icon:SetPoint("BOTTOMRIGHT", frame.CharacterButton, "BOTTOMRIGHT", 0, 0)
    end
    if frame.CharacterButton then
        local b = frame.CharacterButton
        b:SetText("")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 5, 0)
        b.Icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        local classToken = select(2, UnitClass("player"))
        local coords = CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken]
        if coords then
            b.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            b.Icon:SetTexCoord(0, 1, 0, 1)
        end
        b:SetScript("OnClick", function()
            if not LunaBagsCharacterMenu then
                CreateFrame("Frame", "LunaBagsCharacterMenu", UIParent, "UIDropDownMenuTemplate")
            end
            local items = {}
            local currentKey = GetCurrentCharacterKey()
            items[#items + 1] = {
                text = "Current Character",
                checked = function() return OneBag.viewCharacterKey == nil or NormalizeCharacterKey(OneBag.viewCharacterKey) == NormalizeCharacterKey(currentKey) end,
                func = function()
                    if OneBag.SetViewCharacterKey then
                        OneBag:SetViewCharacterKey(nil)
                    else
                        OneBag.viewCharacterKey = nil
                    end
                    OneBag:ApplySettings()
                    OneBag:Refresh()
                end,
                isNotRadio = true,
                keepShownOnClick = false,
            }
            if ns.BagData then
                for key, c in ns.BagData:IterCharacters() do
                    local selectedKey = key
                    local selectedChar = c
                    local label = (selectedChar and selectedChar.name and selectedChar.realm) and (selectedChar.name .. " - " .. selectedChar.realm) or selectedKey
                    items[#items + 1] = {
                        text = label,
                        checked = function() return NormalizeCharacterKey(OneBag.viewCharacterKey) == NormalizeCharacterKey(selectedKey) end,
                        func = function()
                            OneBag:SetViewCharacterKey(selectedKey)
                            OneBag:ApplySettings()
                            OneBag:Refresh()
                        end,
                        isNotRadio = true,
                        keepShownOnClick = false,
                    }
                end
            end
            if EasyMenu then
                EasyMenu(items, LunaBagsCharacterMenu, "cursor", 0, 0, "MENU")
            else
                UIDropDownMenu_Initialize(LunaBagsCharacterMenu, function(_, level)
                    if level ~= 1 then return end
                    for _, entry in ipairs(items) do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = entry.text
                        info.func = entry.func
                        info.checked = type(entry.checked) == "function" and entry.checked() or entry.checked
                        info.isNotRadio = entry.isNotRadio
                        info.keepShownOnClick = entry.keepShownOnClick
                        UIDropDownMenu_AddButton(info, level)
                    end
                end, "MENU")
                ToggleDropDownMenu(1, nil, LunaBagsCharacterMenu, "cursor", 0, 0)
            end
        end)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Character View")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    if not frame.SettingsButton then
        frame.SettingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    if frame.SettingsButton then
        local b = frame.SettingsButton
        b:SetText("")
        b:SetNormalTexture("Interface\\Icons\\INV_Misc_Wrench_01")
        b:SetPushedTexture("Interface\\Icons\\INV_Misc_Wrench_01")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:SetScript("OnClick", function()
            if ns.OpenConfig then
                ns.OpenConfig()
            end
        end)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(SETTINGS or "Settings")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 93, 0)
    end
    if not frame.BankViewButton then
        frame.BankViewButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    if frame.BankViewButton then
        local b = frame.BankViewButton
        b:SetText("")
        b:SetNormalTexture("Interface\\Icons\\INV_Box_02")
        b:SetPushedTexture("Interface\\Icons\\INV_Box_02")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:SetScript("OnClick", function()
            if ns.OneBank and ns.OneBank.OpenViewMode then
                ns.OneBank:OpenViewMode(OneBag.viewCharacterKey or GetCurrentCharacterKey())
            end
        end)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("View Cached Bank")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 115, 0)
    end
    if not frame.RailToggleButton then
        frame.RailToggleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    if frame.RailToggleButton then
        local b = frame.RailToggleButton
        b:SetText("")
        b:SetNormalTexture("Interface\\Buttons\\Button-Backpack-Up")
        b:SetPushedTexture("Interface\\Buttons\\Button-Backpack-Up")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:SetScript("OnClick", LunaBagsOneBag_RailToggleClicked)
        b:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("Toggle Bag Rail")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 27, 0)
    end

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
        if frame.MoneyBar.Label then
            frame.MoneyBar.Label:SetFontObject("GameFontNormal")
            frame.MoneyBar.Label:SetTextColor(1, 1, 1, 1)
            frame.MoneyBar.Label:SetText("")
        end
        if frame.MoneyBar.Text then
            frame.MoneyBar.Text:SetFontObject("GameFontNormal")
            frame.MoneyBar.Text:SetTextColor(1, 1, 1, 1)
        end
        frame.MoneyBar:EnableMouse(true)
        frame.MoneyBar:SetScript("OnEnter", function(bar)
            AddMoneyTooltipBreakdown(bar)
        end)
        frame.MoneyBar:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if not frame.BagSlots then
        frame.BagSlots = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    frame.BagSlots:ClearAllPoints()
    frame.BagSlots:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)

    if not frame.SearchPanel then
        frame.SearchPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.SearchPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
        frame.SearchPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -29)
        frame.SearchPanel:SetHeight(28)
        frame.SearchPanel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame.SearchPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.82)
        frame.SearchPanel:SetBackdropBorderColor(0.26, 0.26, 0.26, 0.95)
    end

    if not frame.SearchEditBackdrop then
        frame.SearchEditBackdrop = CreateFrame("Frame", nil, frame.SearchPanel)
        frame.SearchEditBackdrop:SetPoint("TOPLEFT", frame.SearchPanel, "TOPLEFT", 6, -3)
        frame.SearchEditBackdrop:SetPoint("BOTTOMRIGHT", frame.SearchPanel, "BOTTOMRIGHT", -6, 3)
    end

    if not frame.SearchEditBox then
        frame.SearchEditBox = CreateFrame("EditBox", "LunaBagsOneBagSearchEditBox", frame.SearchEditBackdrop, "InputBoxTemplate")
        frame.SearchEditBox:SetAutoFocus(false)
        frame.SearchEditBox:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
        end)
        frame.SearchEditBox:SetScript("OnEnterPressed", function(editBox)
            editBox:ClearFocus()
        end)
        frame.SearchEditBox:SetScript("OnTextChanged", LunaBagsOneBag_SearchChanged)
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

    if frame.content then
        self:UpdateSearchLayout()
    end

    if frame.BodyChrome then frame.BodyChrome:Hide() end
    if frame.title then frame.title:Hide() end

    if not frame.moneyText and frame.MoneyBar and frame.MoneyBar.Text then
        frame.moneyText = frame.MoneyBar.Text
    end
    if frame.moneyText then
        frame.moneyText:ClearAllPoints()
        frame.moneyText:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -12, 20)
        frame.moneyText:SetTextColor(1, 1, 1, 1)
    end

    if frame.Content then
        frame.Content:SetFrameLevel(BAG_FRAME_LEVEL + 5)
    end

    if not frame.KeyringPanel then
        frame.KeyringPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.KeyringPanel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame.KeyringPanel:SetBackdropBorderColor(0.22, 0.22, 0.22, 0.9)
    end
    frame.KeyringPanel:SetBackdropColor(0.00, 0.00, 0.00, 0.82)
    frame.KeyringPanel:ClearAllPoints()
    frame.KeyringPanel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.KeyringPanel:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    EnsureResizeGrip(self, frame)
    frame.BagSlotParents = frame.BagSlotParents or {}
    ApplyBagFrameLayering(frame)

    self.frame = frame
    self:ApplySettings()
end

function OneBag:SetSortingState(active)
    self.sortingActive = active == true
    if not self.frame then
        return
    end

    local disable = self.sortingActive
    if self.frame.Header and self.frame.Header.SortButton then
        self.frame.Header.SortButton:EnableMouse(not disable)
        self.frame.Header.SortButton:SetAlpha(disable and 0.5 or 1)
    end
    if self.frame.Header and self.frame.Header.SearchToggle then
        self.frame.Header.SearchToggle:EnableMouse(not disable)
        self.frame.Header.SearchToggle:SetAlpha(disable and 0.5 or 1)
    end
    if self.frame.RailToggleButton then
        self.frame.RailToggleButton:EnableMouse(not disable)
        self.frame.RailToggleButton:SetAlpha(disable and 0.5 or (self.showBagRail and 1 or 0.6))
    end
    if self.frame.SettingsButton then
        self.frame.SettingsButton:EnableMouse(not disable)
        self.frame.SettingsButton:SetAlpha(disable and 0.5 or 1)
    end
    if self.frame.SearchEditBox then
        self.frame.SearchEditBox:SetEnabled(not disable)
    end

    for _, button in ipairs(self.buttons or {}) do
        if button then
            button:EnableMouse(not disable)
            if button.icon and button.icon.SetDesaturated then
                button.icon:SetDesaturated(disable)
            end
        end
    end
    for _, button in ipairs(self.keyringButtons or {}) do
        if button then
            button:EnableMouse(not disable)
            if button.icon and button.icon.SetDesaturated then
                button.icon:SetDesaturated(disable)
            end
        end
    end
    for _, button in ipairs(self.bagButtons or {}) do
        if button then
            button:EnableMouse(not disable)
            if button.icon and button.icon.SetDesaturated then
                button.icon:SetDesaturated(disable)
            end
        end
    end
end

function OneBag:GetBagSlotParent(bagID, parentContainer)
    if not self.frame then
        return nil
    end
    parentContainer = parentContainer or self.frame.content
    local key = tostring(bagID) .. ":" .. tostring(parentContainer)
    local holder = self.frame.BagSlotParents[key]
    if holder then
        return holder
    end

    holder = CreateFrame("Frame", nil, parentContainer)
    holder:SetID(bagID)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", parentContainer, "TOPLEFT", 0, 0)
    holder:Show()
    self.frame.BagSlotParents[key] = holder
    return holder
end

function OneBag:AcquireBagButton(index)
    local btn = self.bagButtons[index]
    if btn then
        return btn
    end

    btn = CreateFrame("Button", "LunaBagsBagSlotButton" .. index, self.frame.BagSlots, "BackdropTemplate")
    btn:SetSize(34, 34)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 3, -3)
    btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    btn.icon:SetTexCoord(0, 1, 0, 1)
    ApplyTestButtonStyle(btn)
    StripBagButtonDefaultArt(btn)

    btn:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if button.invSlot then
            GameTooltip:SetInventoryItem("player", button.invSlot)
        elseif button.bagID == KEYRING_CONTAINER then
            GameTooltip:SetText(KEYRING or "Keyring")
        else
            GameTooltip:SetText(BACKPACK_TOOLTIP or BAGSLOT)
        end
        local isVisible = OneBag.visibleBags[button.bagID] ~= false
        GameTooltip:AddLine(isVisible and "Shown in bag window" or "Hidden from bag window", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        if button.StyleBorder then
            local r = button.StyleBorderBaseR or 0.34
            local g = button.StyleBorderBaseG or 0.34
            local b = button.StyleBorderBaseB or 0.34
            button.StyleBorder:SetBackdropBorderColor(
                math.min(1, r + 0.12),
                math.min(1, g + 0.12),
                math.min(1, b + 0.12),
                1
            )
        end
        OneBag:SetBagSlotPreview(button.bagID)
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if btn.StyleBorder then
            btn.StyleBorder:SetBackdropBorderColor(
                btn.StyleBorderBaseR or 0.34,
                btn.StyleBorderBaseG or 0.34,
                btn.StyleBorderBaseB or 0.34,
                btn.StyleBorderBaseA or 0.95
            )
        end
        OneBag:SetBagSlotPreview(nil)
    end)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(button, mouseButton)
        if mouseButton == "RightButton" then
            if not LunaBagsBagRailMenu then
                CreateFrame("Frame", "LunaBagsBagRailMenu", UIParent, "UIDropDownMenuTemplate")
            end
            local bagID = button.bagID
            local canSplit = bagID and not IsKeyringBag(bagID)
            local menu = {
                {
                    text = "Split This Bag Section",
                    checked = function() return canSplit and IsBagSplitEnabled(bagID) end,
                    disabled = (not canSplit) or OneBag.splitByBagRows,
                    func = function()
                        if not canSplit then return end
                        SetBagSplitEnabled(bagID, not IsBagSplitEnabled(bagID))
                        OneBag:Refresh()
                    end,
                    isNotRadio = true,
                    keepShownOnClick = true,
                },
            }
            if EasyMenu then
                EasyMenu(menu, LunaBagsBagRailMenu, "cursor", 0, 0, "MENU")
            else
                UIDropDownMenu_Initialize(LunaBagsBagRailMenu, function(_, level)
                    if level ~= 1 then return end
                    for _, entry in ipairs(menu) do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = entry.text
                        info.func = entry.func
                        info.checked = type(entry.checked) == "function" and entry.checked() or entry.checked
                        info.disabled = entry.disabled
                        info.isNotRadio = entry.isNotRadio
                        info.keepShownOnClick = entry.keepShownOnClick
                        UIDropDownMenu_AddButton(info, level)
                    end
                end, "MENU")
                ToggleDropDownMenu(1, nil, LunaBagsBagRailMenu, "cursor", 0, 0)
            end
            return
        end
        if button.bagID == KEYRING_CONTAINER and not OneBag.keyringAvailable then
            return
        end
        if CursorHasAssignableItem() then
            if button.bagID == 0 then
                PutItemInBackpack()
            elseif button.invSlot then
                PutItemInBag(button.invSlot)
            end
            return
        end

        OneBag.visibleBags[button.bagID] = not (OneBag.visibleBags[button.bagID] ~= false)
        OneBag:SaveVisibleBagsState()
        OneBag:Refresh()
    end)
    btn:SetScript("OnDragStart", function(button)
        if button.bagID == 0 or not button.invSlot then
            return
        end
        PickupBagFromSlot(button.invSlot)
    end)
    btn:SetScript("OnReceiveDrag", function(button)
        if button.bagID == 0 then
            PutItemInBackpack()
            return
        end
        if not button.invSlot then
            return
        end
        PutItemInBag(button.invSlot)
    end)

    self.bagButtons[index] = btn
    return btn
end

function OneBag:RefreshBagSlots()
    if not self.frame or not self.frame.BagSlots then
        return
    end
    if not self.showBagRail then
        self.frame.BagSlots:Hide()
        return
    end
    self.frame.BagSlots:Show()
    local size, spacing = 34, 4
    local pad = 6
    self.keyringAvailable = KeyringHasItems()
    local railBags = {}
    for bagID = 0, 4 do
        railBags[#railBags + 1] = bagID
    end
    if KEYRING_CONTAINER then
        railBags[#railBags + 1] = KEYRING_CONTAINER
    end

    local candidateCount = #railBags
    if KEYRING_CONTAINER and not self.keyringAvailable then
        candidateCount = candidateCount - 1
    end
    local horizontalWidth = pad * 2 + candidateCount * size + math.max(0, candidateCount - 1) * spacing
    local horizontalHeight = size + pad * 2
    local verticalWidth = size + pad * 2
    local frameLeft = self.frame:GetLeft() or 0
    local frameRight = self.frame:GetRight() or (frameLeft + (self.frame:GetWidth() or 0))
    local frameCenter = (frameLeft + frameRight) * 0.5
    local chosenPosition = self.bagRailPosition or "top"
    local verticalSide = "LEFT"

    if chosenPosition ~= "left" and chosenPosition ~= "right" and chosenPosition ~= "bottom" then
        chosenPosition = "top"
    end

    local useVertical = chosenPosition == "left" or chosenPosition == "right"
    if useVertical then
        verticalSide = chosenPosition == "right" and "RIGHT" or "LEFT"
    end

    self.frame.BagSlots:ClearAllPoints()
    if useVertical and verticalSide == "RIGHT" then
        self.frame.BagSlots:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 0, 0)
    elseif useVertical then
        self.frame.BagSlots:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 0)
    elseif chosenPosition == "bottom" then
        self.frame.BagSlots:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    else
        self.frame.BagSlots:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 0)
    end

    local shownCount = 0
    for i, bagID in ipairs(railBags) do
        local button = self:AcquireBagButton(i)
        if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
            ns.ItemButtonStyle.Apply(button)
        end
        local showButton = not (bagID == KEYRING_CONTAINER and not self.keyringAvailable)
        if showButton then
            shownCount = shownCount + 1
            button:ClearAllPoints()
            if useVertical then
                button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad, -pad - (shownCount - 1) * (size + spacing))
            else
                button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad + (shownCount - 1) * (size + spacing), -pad)
            end
            button.bagID = bagID
            button.invSlot = ContainerIDToInventoryIDCompat(bagID)

            local icon
            if bagID == 0 then
                icon = GetBackpackIcon()
            elseif bagID == KEYRING_CONTAINER then
                icon = "Interface\\ContainerFrame\\KeyRing-Bag-Icon"
            elseif button.invSlot then
                icon = GetInventoryItemTexture("player", button.invSlot)
            end
            button.icon:SetTexture(icon)
            StripBagButtonDefaultArt(button)
            local isVisible = self.visibleBags[bagID] ~= false
            if button.StyleBorder then
                if isVisible then
                    button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.78, 0.66, 0.26, 1
                else
                    button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.34, 0.34, 0.34, 0.95
                end
                button.StyleBorder:SetBackdropBorderColor(
                    button.StyleBorderBaseR,
                    button.StyleBorderBaseG,
                    button.StyleBorderBaseB,
                    button.StyleBorderBaseA
                )
            end
            button:Show()
        else
            button:Hide()
        end
    end
    if type(self.frame.BagSlots.SetBackdrop) == "function" then
        self.frame.BagSlots:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        self.frame.BagSlots:SetBackdropColor(0.08, 0.08, 0.08, 0.84)
        self.frame.BagSlots:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)
    end
    local used = shownCount
    if useVertical then
        self.frame.BagSlots:SetWidth(verticalWidth)
        self.frame.BagSlots:SetHeight(pad * 2 + used * size + math.max(0, used - 1) * spacing)
    else
        self.frame.BagSlots:SetWidth(pad * 2 + used * size + math.max(0, used - 1) * spacing)
        self.frame.BagSlots:SetHeight(horizontalHeight)
    end
    ApplyWindowAppearance(self.frame, GetConfig())
end

function OneBag:AcquireButton(index)
    local btn = self.buttons[index]
    if btn then
        return btn
    end

    local buttonName = "LunaBagsItemButton" .. index
    btn = CreateFrame("ItemButton", buttonName, self.frame.content, "ContainerFrameItemButtonTemplate")
    btn:SetSize(self.slotSize, self.slotSize)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)
    btn:SetScript("OnEnter", LunaBagsOneBag_ItemButtonOnEnter)
    btn:SetScript("OnLeave", LunaBagsOneBag_ItemButtonOnLeave)
    btn:HookScript("OnDragStart", function(button)
        TrackCategoryDragFromButton(OneBag, button)
    end)
    -- Preserve Blizzard secure item-button behavior from template scripts.

    local icon = btn.icon or _G[btn:GetName() .. "IconTexture"] or _G[btn:GetName() .. "Icon"]
    if not icon then
        icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon
    ApplyTestButtonStyle(btn)

    local count = btn.Count or _G[btn:GetName() .. "Count"]
    if not count then
        count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    btn.count = count
    EnsureLockOverlay(btn)
    if not btn.DebugSlotText then
        btn.DebugSlotText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.DebugSlotText:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        btn.DebugSlotText:SetTextColor(0.95, 0.82, 0.10, 0.95)
        btn.DebugSlotText:SetJustifyH("LEFT")
    end

    self.buttons[index] = btn
    return btn
end

function OneBag:AcquireReadonlyButton(index)
    local btn = self.readonlyButtons[index]
    if btn then
        return btn
    end

    local buttonName = "LunaBagsReadonlyItemButton" .. index
    btn = CreateFrame("Button", buttonName, self.frame.content, "BackdropTemplate")
    btn:SetSize(self.slotSize, self.slotSize)
    btn:EnableMouse(true)
    btn:RegisterForClicks()
    btn:RegisterForDrag()
    btn:SetScript("OnEnter", LunaBagsOneBag_ItemButtonOnEnter)
    btn:SetScript("OnLeave", LunaBagsOneBag_ItemButtonOnLeave)
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnDragStart", nil)
    btn:SetScript("OnReceiveDrag", nil)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 4)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -2)
    btn.icon:SetTexCoord(0, 1, 0, 1)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", -3, 3)
    if not btn.DebugSlotText then
        btn.DebugSlotText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.DebugSlotText:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        btn.DebugSlotText:SetTextColor(0.95, 0.82, 0.10, 0.95)
        btn.DebugSlotText:SetJustifyH("LEFT")
    end

    ApplyTestButtonStyle(btn)
    self.readonlyButtons[index] = btn
    return btn
end

function OneBag:AcquireKeyringButton(index)
    local btn = self.keyringButtons[index]
    if btn then
        return btn
    end

    local buttonName = "LunaBagsKeyringItemButton" .. index
    btn = CreateFrame("ItemButton", buttonName, self.frame.KeyringPanel, "ContainerFrameItemButtonTemplate")
    btn:SetSize(self.slotSize, self.slotSize)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)
    btn:SetScript("OnEnter", LunaBagsOneBag_ItemButtonOnEnter)
    btn:SetScript("OnLeave", LunaBagsOneBag_ItemButtonOnLeave)

    local icon = btn.icon or _G[btn:GetName() .. "IconTexture"] or _G[btn:GetName() .. "Icon"]
    if not icon then
        icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon
    ApplyTestButtonStyle(btn)

    local count = btn.Count or _G[btn:GetName() .. "Count"]
    if not count then
        count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    btn.count = count
    EnsureLockOverlay(btn)

    self.keyringButtons[index] = btn
    return btn
end

function LunaBagsOneBag_Close()
    if ns.BagHooks then
        ns.BagHooks:CloseBags("UI")
    elseif OneBag.frame then
        ClearAllNewItemGlows()
        OneBag.frame:Hide()
    end
end

function LunaBagsOneBag_SearchChanged(editBox)
    OneBag.searchText = strtrim(editBox:GetText() or "")
    OneBag:Refresh()
end

function LunaBagsOneBag_SearchToggleClicked()
    OneBag.searchVisible = not OneBag.searchVisible
    if not OneBag.frame or not OneBag.frame.SearchEditBox then
        return
    end
    local searchBox = OneBag.frame.SearchEditBox
    OneBag:UpdateSearchLayout()
    if OneBag.searchVisible then
        searchBox:SetFocus()
    else
        searchBox:ClearFocus()
        OneBag.searchText = ""
        if searchBox:GetText() ~= "" then
            searchBox:SetText("")
        end
    end
    OneBag:Refresh()
end

function LunaBagsOneBag_SortClicked()
    if IsVisualSortEnabled() then
        OneBag._layoutModel = nil
        OneBag:Refresh()
        return
    end
    if ns.Sorter and ns.Sorter.SortBags then
        ns.Sorter:SortBags()
    elseif SortBags then
        SortBags()
    elseif C_Container and C_Container.SortBags then
        C_Container.SortBags()
    end
end

local function ClearAllLockedSlots()
    local cfg = GetSortingConfig()
    if not cfg then
        return
    end
    local perChar = cfg._activeCharacterData or {}
    perChar.lockedSlots = {}
    OneBag:Refresh()
end

local function ToggleLockSlotsMode()
    if OneBag.sortingActive then
        return
    end
    OneBag.lockSlotsMode = not OneBag.lockSlotsMode
    if OneBag.frame and OneBag.frame.Header and OneBag.frame.Header.SortButton then
        OneBag.frame.Header.SortButton:SetAlpha(OneBag.lockSlotsMode and 0.85 or 1)
    end
    OneBag:Refresh()
end

function LunaBagsOneBag_SortButtonClicked(_, mouseButton)
    if mouseButton == "RightButton" then
        local menu = {
            {
                text = "Sort Inventory",
                func = function() LunaBagsOneBag_SortClicked() end,
                notCheckable = true,
            },
            {
                text = "Lock Slots Mode",
                checked = function() return OneBag.lockSlotsMode end,
                func = function() ToggleLockSlotsMode() end,
                isNotRadio = true,
                keepShownOnClick = true,
            },
            {
                text = "Clear Locked Slots",
                func = function() ClearAllLockedSlots() end,
                notCheckable = true,
            },
        }
        if EasyMenu then
            if not LunaBagsOneBagSortMenu then
                CreateFrame("Frame", "LunaBagsOneBagSortMenu", UIParent, "UIDropDownMenuTemplate")
            end
            EasyMenu(menu, LunaBagsOneBagSortMenu, "cursor", 0, 0, "MENU")
        else
            if not LunaBagsOneBagSortMenu then
                CreateFrame("Frame", "LunaBagsOneBagSortMenu", UIParent, "UIDropDownMenuTemplate")
            end
            UIDropDownMenu_Initialize(LunaBagsOneBagSortMenu, function(_, level)
                if level ~= 1 then
                    return
                end
                for _, entry in ipairs(menu) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = entry.text
                    info.func = entry.func
                    info.checked = type(entry.checked) == "function" and entry.checked() or entry.checked
                    info.isNotRadio = entry.isNotRadio
                    info.keepShownOnClick = entry.keepShownOnClick
                    info.notCheckable = entry.notCheckable
                    UIDropDownMenu_AddButton(info, level)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, LunaBagsOneBagSortMenu, "cursor", 0, 0)
        end
        return
    end
    LunaBagsOneBag_SortClicked()
end

function LunaBagsOneBag_RailToggleClicked()
    local cfg = GetConfig()
    OneBag.showBagRail = not OneBag.showBagRail
    if cfg then
        cfg.showBagRail = OneBag.showBagRail == true
    end
    if OneBag.frame and OneBag.frame.RailToggleButton then
        OneBag.frame.RailToggleButton:SetAlpha(OneBag.showBagRail and 1 or 0.6)
    end
    OneBag:Refresh()
end

function LunaBagsOneBag_ItemButtonOnEnter(button)
    EnsureTooltipPostHook()
    OneBag.hoveredItemID = button.itemData and button.itemData.itemID or nil
    OneBag.hoveredButton = button
    if button.bagID and button.slot then
        ClearNewItemGlowForSlot(button.bagID, button.slot)
        SetNewItemGlowShown(button, false)
    end
    GameTooltip:ClearAllPoints()
    if button:GetRight() and button:GetRight() > (GetScreenWidth() * 0.5) then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    end
    if not IsViewingCurrentCharacter() then
        if button.itemData and button.itemData.itemLink then
            GameTooltip:SetHyperlink(button.itemData.itemLink)
            GameTooltip:Show()
        end
        return
    end
    if button.bagID and button.slot then
        GameTooltip:SetBagItem(button.bagID, button.slot)
        if IsKeyringBag(button.bagID) and not GameTooltip:GetItem() then
            local invSlot = KeyRingButtonIDToInvSlotID and KeyRingButtonIDToInvSlotID(button.slot)
            if invSlot then
                GameTooltip:SetInventoryItem("player", invSlot)
            end
            if not GameTooltip:GetItem() and button.itemData and button.itemData.itemLink then
                GameTooltip:SetHyperlink(button.itemData.itemLink)
            end
        end
        if not OneBag.hoveredItemID then
            local _, link = GameTooltip:GetItem()
            if link then
                OneBag.hoveredItemID = tonumber(link:match("item:(%d+)"))
            end
        end
        if OneBag.lockSlotsMode then
            GameTooltip:AddLine("Lock Slots Mode: click to lock/unlock slot", 0.95, 0.82, 0.30)
        end
        if IsSlotUserLocked(button.bagID, button.slot) then
            GameTooltip:AddLine("Slot is locked for sorting", 0.95, 0.82, 0.30)
        end
        GameTooltip:Show()
    end
end

function LunaBagsOneBag_ItemButtonOnLeave()
    OneBag.hoveredItemID = nil
    OneBag.hoveredButton = nil
    GameTooltip:Hide()
end

local function GetItemDetails(itemLink, itemID, includeFullDetails)
    local itemKey = itemLink or itemID
    local itemName, _, itemQuality, itemLevel, _, itemTypeName, subTypeName, _, equipLoc, _, sellPrice, classID, subClassID
    if includeFullDetails and itemKey and GetItemInfo then
        itemName, _, itemQuality, itemLevel, _, itemTypeName, subTypeName, _, equipLoc, _, sellPrice, classID, subClassID = GetItemInfo(itemKey)
    end

    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInstant and itemKey and (classID == nil or subClassID == nil or equipLoc == nil or itemTypeName == nil or subTypeName == nil) then
        local _, instantTypeName, instantSubTypeName, instantEquipLoc, _, instantClassID, instantSubClassID = getInstant(itemKey)
        itemTypeName = itemTypeName or instantTypeName
        subTypeName = subTypeName or instantSubTypeName
        equipLoc = equipLoc or instantEquipLoc
        classID = classID or instantClassID
        subClassID = subClassID or instantSubClassID
    end

    return itemName, itemQuality, itemLevel, itemTypeName, subTypeName, equipLoc, sellPrice, classID, subClassID
end

local function GetQuestItemFlag(bagID, slot, itemInfo)
    if itemInfo and itemInfo.isQuestItem == true then
        return true
    end

    if C_Container and C_Container.GetContainerItemQuestInfo then
        local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
        if type(questInfo) == "table" then
            return questInfo.isQuestItem == true
        end
        return questInfo == true
    end

    if GetContainerItemQuestInfo then
        local isQuestItem = GetContainerItemQuestInfo(bagID, slot)
        return isQuestItem == true
    end

    return false
end

function OneBag:BuildLiveSlots()
    local viewingCurrent = IsViewingCurrentCharacter()
    local includeFullDetails = (self.searchText and self.searchText ~= "") or IsVisualSortEnabled()
    local visibleKey = {}
    for bagID = 0, 4 do
        visibleKey[#visibleKey + 1] = tostring(bagID) .. "=" .. tostring(self.visibleBags[bagID] ~= false)
    end
    local cacheKey = table.concat(visibleKey, ";") .. "|view=" .. tostring(viewingCurrent and "current" or (self.viewCharacterKey or "cached"))
    if self._slotCache
        and self._slotCacheDirty ~= true
        and self._slotCacheKey == cacheKey
        and (not includeFullDetails or self._slotCacheFullDetails == true)
    then
        return self._slotCache
    end

    local slots = {}
    local viewedCharacter
    if not viewingCurrent then
        viewedCharacter = GetViewedCharacterData()
    end

    for bagID = 0, 4 do
        if self.visibleBags[bagID] ~= false and not IsKeyringBag(bagID) then
            local slotCount = 0
            local cachedSlots
            local cachedBagData
            if viewingCurrent then
                slotCount = GetNumSlotsInBag(bagID)
            else
                cachedBagData = GetCharacterBagData(viewedCharacter, bagID, false)
                slotCount = GetCharacterBagSlotCount(cachedBagData)
                cachedSlots = GetCharacterBagSlotsTable(cachedBagData)
            end
            for slot = 1, slotCount do
                local itemInfo
                local itemLink
                if viewingCurrent then
                    itemInfo = GetItemInfoFromBag(bagID, slot)
                    itemLink = itemInfo and GetItemLinkFromBag(bagID, slot) or nil
                else
                    itemInfo = GetCharacterBagSlot(cachedBagData or cachedSlots, slot)
                    itemLink = itemInfo and itemInfo.itemLink or nil
                end
                local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or (itemInfo and itemInfo.itemID) or nil
                local itemName, itemQuality, itemLevel, itemTypeName, subTypeName, equipLoc, sellPrice, classID, subClassID =
                    GetItemDetails(itemLink, itemID, includeFullDetails)
                slots[#slots + 1] = {
                    bagID = bagID,
                    slot = slot,
                    item = itemInfo and {
                        iconFileID = itemInfo.iconFileID,
                        stackCount = itemInfo.stackCount,
                        quality = itemInfo.quality or itemQuality,
                        isQuestItem = viewingCurrent and GetQuestItemFlag(bagID, slot, itemInfo) or itemInfo.isQuestItem == true,
                        itemLink = itemLink,
                        itemID = itemID,
                        name = itemName,
                        itemLevel = itemLevel,
                        itemTypeName = itemTypeName,
                        subTypeName = subTypeName,
                        equipLoc = equipLoc,
                        sellPrice = sellPrice,
                        classID = classID,
                        subClassID = subClassID,
                    } or nil,
                }
            end
        end
    end

    table.sort(slots, function(a, b)
        if a.bagID == b.bagID then
            return a.slot < b.slot
        end
        return a.bagID < b.bagID
    end)

    if IsVisualSortEnabled() and ns.Sorter and ns.Sorter.SortDisplayEntries then
        slots = ns.Sorter:SortDisplayEntries(slots)
    end

    self._slotCache = slots
    self._slotCacheKey = cacheKey
    self._slotCacheFullDetails = includeFullDetails == true
    self._slotCacheDirty = nil
    return slots
end

function OneBag:InvalidateSlotCache()
    self._slotCacheDirty = true
    self._layoutModel = nil
end

function OneBag:BuildKeyringSlots()
    local slots = {}
    if not KEYRING_CONTAINER or self.visibleBags[KEYRING_CONTAINER] == false or not IsViewingCurrentCharacter() then
        return slots
    end

    local includeFullDetails = self.searchText and self.searchText ~= ""
    local slotCount = GetNumSlotsInBag(KEYRING_CONTAINER)
    for slot = 1, slotCount do
        local itemInfo = GetItemInfoFromBag(KEYRING_CONTAINER, slot)
        if itemInfo then
            local itemLink = GetItemLinkFromBag(KEYRING_CONTAINER, slot)
            local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil
            local itemName, itemQuality, itemLevel, itemTypeName, subTypeName, equipLoc, sellPrice, classID, subClassID =
                GetItemDetails(itemLink, itemID, includeFullDetails)
            slots[#slots + 1] = {
                bagID = KEYRING_CONTAINER,
                slot = slot,
                item = {
                    iconFileID = itemInfo.iconFileID,
                    stackCount = itemInfo.stackCount,
                    quality = itemInfo.quality or itemQuality,
                    isQuestItem = GetQuestItemFlag(KEYRING_CONTAINER, slot, itemInfo),
                    itemLink = itemLink,
                    itemID = itemID,
                    name = itemName,
                    itemLevel = itemLevel,
                    itemTypeName = itemTypeName,
                    subTypeName = subTypeName,
                    equipLoc = equipLoc,
                    sellPrice = sellPrice,
                    classID = classID,
                    subClassID = subClassID,
                },
            }
        end
    end
    slots[#slots + 1] = {
        bagID = KEYRING_CONTAINER,
        slot = slotCount + 1,
        item = nil,
        virtualEmpty = true,
    }

    return slots
end

AddCharacterItemCountTooltip = function(itemID, itemLink)
    if not ns.BagData then
        return
    end
    local targetID = tonumber(itemID) or (itemLink and tonumber(itemLink:match("item:(%d+)"))) or nil
    if not targetID then
        return
    end
    local hasAny = false
    for _, _ in ns.BagData:IterCharacters() do
        hasAny = true
        break
    end
    if not hasAny then
        return
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Item Across Characters", 0.9, 0.9, 0.9)
    for _, c in ns.BagData:IterCharacters() do
        local bagsCount, bankCount = 0, 0
        if c and c.bags then
            for _, bagData in pairs(c.bags) do
                if bagData and bagData.slots then
                    for _, s in pairs(bagData.slots) do
                        if s and tonumber(s.itemID) == targetID then
                            bagsCount = bagsCount + (s.stackCount or 1)
                        end
                    end
                end
            end
        end
        if c and c.bank then
            for _, bagData in pairs(c.bank) do
                if bagData and bagData.slots then
                    for _, s in pairs(bagData.slots) do
                        if s and tonumber(s.itemID) == targetID then
                            bankCount = bankCount + (s.stackCount or 1)
                        end
                    end
                end
            end
        end
        local total = bagsCount + bankCount
        if total > 0 then
            local name = (c and c.name) or "Unknown"
            GameTooltip:AddDoubleLine(name, string.format("%d (bags %d / bank %d)", total, bagsCount, bankCount), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
end

AddMoneyTooltipBreakdown = function(owner)
    if not ns.BagData then
        return
    end

    local rows = {}
    local total = 0
    for key, c in ns.BagData:IterCharacters() do
        local money = tonumber(c and c.money) or 0
        total = total + money
        rows[#rows + 1] = {
            key = key,
            name = (c and c.name) or key,
            realm = (c and c.realm) or "",
            money = money,
        }
    end

    table.sort(rows, function(a, b)
        if a.money ~= b.money then
            return a.money > b.money
        end
        return a.name < b.name
    end)

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Gold")
    if GetCoinTextureString then
        GameTooltip:AddDoubleLine("Total", GetCoinTextureString(total), 1, 0.82, 0.2, 1, 1, 1)
    else
        GameTooltip:AddDoubleLine("Total", tostring(total), 1, 0.82, 0.2, 1, 1, 1)
    end

    if #rows > 0 then
        GameTooltip:AddLine(" ")
        local currentKey = GetCurrentCharacterKey()
        for _, row in ipairs(rows) do
            local left = row.name
            if row.realm and row.realm ~= "" then
                left = left .. " - " .. row.realm
            end
            if row.key == currentKey then
                left = left .. " (You)"
            end
            local right = GetCoinTextureString and GetCoinTextureString(row.money) or tostring(row.money)
            GameTooltip:AddDoubleLine(left, right, 0.85, 0.85, 0.85, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

function OneBag:Refresh(layoutOnly)
    if not self.frame then
        return
    end
    layoutOnly = layoutOnly == true
    EnsureVisibleBagDefaults(self.visibleBags)
    self:UpdateSearchLayout()

    local cachedLayout = (layoutOnly and not IsVisualSortEnabled()) and self._layoutModel or nil
    local allSlots = cachedLayout and cachedLayout.allSlots or self:BuildLiveSlots()
    local keySlots = cachedLayout and cachedLayout.keySlots or self:BuildKeyringSlots()
    local occupiedSlots = cachedLayout and cachedLayout.occupiedSlots or nil
    local totalSlots = cachedLayout and cachedLayout.totalSlots or nil
    if not occupiedSlots or not totalSlots then
        occupiedSlots, totalSlots = CountSlotUsage(allSlots)
    end
    local searching = self.searchText and self.searchText ~= ""
    local readOnly = not IsViewingCurrentCharacter()
    local used = #allSlots
    local cols = self.columns
    local size = self.slotSize
    local spacing = self.spacing
    local gridWidth = cols * size + ((cols - 1) * spacing)
    local gridInsetX = spacing
    local gridInsetY = spacing
    local framePaddingX = BAG_FRAME_PADDING_X
    local contentTopInset = self.searchVisible and 34 or 12
    local frameVerticalChrome = 79 + contentTopInset

    local rows = math.max(1, math.ceil(math.max(used, 1) / cols))
    local desiredContentWidth = gridWidth + (gridInsetX * 2)
    local contentHeight = gridInsetY + rows * size + (rows - 1) * spacing + gridInsetY

    -- Desired frame size from configured columns.
    local frameWidth = math.max(desiredContentWidth + framePaddingX, tonumber(self.windowWidth) or 0)
    local frameHeight = math.max(200, math.min(tonumber(self.maxHeight) or BAG_DEFAULT_MAX_HEIGHT, contentHeight + frameVerticalChrome))
    self.frame:SetSize(frameWidth, frameHeight)

    -- Recenter against actual available content width (template/min-width can exceed desired width).
    local actualContentWidth = self.frame.ScrollFrame and self.frame.ScrollFrame:GetWidth() or (self.frame.content and self.frame.content:GetWidth()) or desiredContentWidth
    gridInsetX = math.max(spacing, math.floor((actualContentWidth - gridWidth) * 0.5))

    local positioned = {}
    local bagSectionGapY = math.max(spacing * 2, spacing + 6)
    local nonSplit = cachedLayout and cachedLayout.nonSplit or {}
    local splitSections = cachedLayout and cachedLayout.splitSections or {}
    local categorySections = cachedLayout and cachedLayout.categorySections or {}
    local categoryByID = {}
    local categoryConfig = ns.Categories and ns.Categories:GetConfig("bags") or nil
    local categoriesEnabled = ns.Categories and ns.Categories.HasActiveCategories and ns.Categories:HasActiveCategories("bags") or false
    local categoryColumnCount = math.max(1, math.min(tonumber(categoryConfig and categoryConfig.columns) or 1, cols))
    local categoryLayoutMode = (categoryConfig and categoryConfig.layout == "fixed") and "fixed" or "masonry"
    local visualSortEnabled = IsVisualSortEnabled()

    if (not cachedLayout) and categoriesEnabled and ns.Categories then
        for index, category in ipairs(ns.Categories:GetActiveList("bags") or {}) do
            if category.enabled ~= false and category.hidden ~= true then
                local key = category.id or category.name or tostring(index)
                local section = {
                    title = category.name or ("Category " .. tostring(index)),
                    entries = {},
                    category = category,
                    minSlots = tonumber(category.minSlots) or 0,
                }
                categoryByID[key] = section
                categorySections[#categorySections + 1] = section
            end
        end
    end

    if not cachedLayout and visualSortEnabled then
        for _, entry in ipairs(allSlots) do
            local category = categoriesEnabled and ns.Categories and ns.Categories:MatchItem(entry.item, "bags") or nil
            if category then
                local key = category.id or category.name or tostring(#categorySections + 1)
                local section = categoryByID[key]
                if not section then
                    section = { title = category.name or "Category", entries = {}, category = category, minSlots = tonumber(category.minSlots) or 0 }
                    categoryByID[key] = section
                    categorySections[#categorySections + 1] = section
                end
                section.entries[#section.entries + 1] = entry
            else
                nonSplit[#nonSplit + 1] = entry
            end
        end

        self._layoutModel = {
            allSlots = allSlots,
            keySlots = keySlots,
            occupiedSlots = occupiedSlots,
            totalSlots = totalSlots,
            nonSplit = nonSplit,
            splitSections = splitSections,
            categorySections = categorySections,
        }
    elseif not cachedLayout then
        local bagBuckets = {}
        for _, entry in ipairs(allSlots) do
            bagBuckets[entry.bagID] = bagBuckets[entry.bagID] or {}
            bagBuckets[entry.bagID][#bagBuckets[entry.bagID] + 1] = entry
        end

        for bagID = 0, 4 do
            if self.visibleBags[bagID] ~= false and not IsKeyringBag(bagID) then
                local bucket = bagBuckets[bagID] or {}
                local remaining = {}
                for _, entry in ipairs(bucket) do
                    local category = categoriesEnabled and ns.Categories and ns.Categories:MatchItem(entry.item, "bags") or nil
                    if category then
                        local key = category.id or category.name or tostring(#categorySections + 1)
                        local section = categoryByID[key]
                        if not section then
                            section = { title = category.name or "Category", entries = {}, category = category, minSlots = tonumber(category.minSlots) or 0 }
                            categoryByID[key] = section
                            categorySections[#categorySections + 1] = section
                        end
                        section.entries[#section.entries + 1] = entry
                    else
                        remaining[#remaining + 1] = entry
                    end
                end
                bucket = remaining
                if self.splitByBagRows or IsBagSplitEnabled(bagID) then
                    table.sort(bucket, function(a, b)
                        local aHasItem = a and a.item ~= nil
                        local bHasItem = b and b.item ~= nil
                        if aHasItem ~= bHasItem then
                            return aHasItem
                        end
                        return (a.slot or 0) < (b.slot or 0)
                    end)
                    splitSections[#splitSections + 1] = { bagID = bagID, entries = bucket }
                else
                    for _, entry in ipairs(bucket) do
                        nonSplit[#nonSplit + 1] = entry
                    end
                end
            end
        end

        self._layoutModel = {
            allSlots = allSlots,
            keySlots = keySlots,
            occupiedSlots = occupiedSlots,
            totalSlots = totalSlots,
            nonSplit = nonSplit,
            splitSections = splitSections,
            categorySections = categorySections,
        }
    end

    local usedRows = 0
    local extraYOffset = 0
    local hasBaseContent = false
    local sectionHeaders = {}
    local sectionEmptyLabels = {}
    local sectionPlaceholders = {}
    local sectionDropTargets = {}
    local sectionHeaderHeight = 14

    local function AddSection(section)
        local entries = section.entries or {}
        local minSlots = math.max(0, tonumber(section.minSlots) or 0)
        local visibleSlots = math.max(#entries, minSlots)
        if visibleSlots == 0 then
            return
        end
        if hasBaseContent then
            extraYOffset = extraYOffset + bagSectionGapY
        end
        if section.title and section.title ~= "" then
            sectionHeaders[#sectionHeaders + 1] = {
                title = section.title,
                row = usedRows,
                yOffset = extraYOffset,
            }
            extraYOffset = extraYOffset + sectionHeaderHeight
        end
        for idx, entry in ipairs(entries) do
            local localIndex = idx - 1
            positioned[#positioned + 1] = {
                entry = entry,
                col = localIndex % cols,
                row = usedRows + math.floor(localIndex / cols),
                yOffset = extraYOffset,
            }
        end
        for idx = #entries + 1, visibleSlots do
            local localIndex = idx - 1
            sectionPlaceholders[#sectionPlaceholders + 1] = {
                col = localIndex % cols,
                row = usedRows + math.floor(localIndex / cols),
                yOffset = extraYOffset,
                category = section.category,
            }
        end
        if #entries == 0 then
            sectionEmptyLabels[#sectionEmptyLabels + 1] = {
                text = "No items found",
                row = usedRows,
                yOffset = extraYOffset,
                cols = math.min(cols, math.max(1, visibleSlots)),
            }
        end
        usedRows = usedRows + math.max(1, math.ceil(visibleSlots / cols))
        hasBaseContent = true
    end

    local function AddCategoryGrid(sections)
        if #sections == 0 then
            return
        end
        if hasBaseContent then
            extraYOffset = extraYOffset + bagSectionGapY
        end

        local gridGapCols = (categoryColumnCount > 1 and ((categoryColumnCount * 2 - 1) <= cols)) and 1 or 0
        local defaultSectionCols = math.max(1, math.floor((cols - ((categoryColumnCount - 1) * gridGapCols)) / categoryColumnCount))
        local columnHeights = {}
        local sectionLayouts = {}
        for col = 0, cols - 1 do
            columnHeights[col] = 0
        end

        local function GetSectionCols(section)
            local category = section and section.category
            local requested = tonumber(category and category.columns)
            if requested and requested > 0 then
                return math.max(1, math.min(cols, math.floor(requested)))
            end
            return defaultSectionCols
        end

        local function FindMasonrySlot(sectionCols)
            local bestCol = 0
            local bestHeight
            for startCol = 0, cols - sectionCols do
                local height = 0
                for col = startCol, startCol + sectionCols - 1 do
                    height = math.max(height, columnHeights[col] or 0)
                end
                if bestHeight == nil or height < bestHeight then
                    bestHeight = height
                    bestCol = startCol
                end
            end
            return bestCol, bestHeight or 0
        end

        local fixedTopOffset = 0
        local fixedRowHeight = 0
        local fixedTotalHeight = nil
        local fixedCurrentCol = 0
        for index, section in ipairs(sections) do
            local sectionCols = GetSectionCols(section)
            local startCol, topOffset
            if categoryLayoutMode == "fixed" then
                sectionCols = math.min(sectionCols, cols)
                if fixedCurrentCol > 0 and (fixedCurrentCol + sectionCols) > cols then
                    fixedTopOffset = fixedTopOffset + fixedRowHeight + bagSectionGapY
                    fixedRowHeight = 0
                    fixedCurrentCol = 0
                end
                startCol = fixedCurrentCol
                topOffset = fixedTopOffset
                fixedCurrentCol = fixedCurrentCol + sectionCols + gridGapCols
            else
                startCol, topOffset = FindMasonrySlot(sectionCols)
            end
            local entries = section.entries or {}
            local minSlots = math.max(0, tonumber(section.minSlots) or 0)
            local visibleSlots = (#entries == 0) and math.max(1, minSlots) or math.max(#entries, minSlots)
            local slotRows = math.max(1, math.ceil(visibleSlots / sectionCols))
            local headerHeight = (section.title and section.title ~= "") and sectionHeaderHeight or 0
            local sectionHeight = headerHeight + slotRows * size + math.max(0, slotRows - 1) * spacing
            if categoryLayoutMode == "fixed" then
                fixedRowHeight = math.max(fixedRowHeight, sectionHeight)
                fixedTotalHeight = fixedTopOffset + fixedRowHeight
            else
                if topOffset > 0 then
                    topOffset = topOffset + bagSectionGapY
                end
                for col = startCol, startCol + sectionCols - 1 do
                    columnHeights[col] = topOffset + sectionHeight
                end
            end
            sectionLayouts[#sectionLayouts + 1] = {
                section = section,
                startCol = startCol,
                topOffset = topOffset,
                sectionCols = sectionCols,
                entries = entries,
                visibleSlots = visibleSlots,
            }
        end

        for _, layout in ipairs(sectionLayouts) do
            local section = layout.section
            local entries = layout.entries
            local startCol = layout.startCol
            local visibleSlots = layout.visibleSlots
            local sectionCols = layout.sectionCols
            local startRow = usedRows
            local headerOffset = extraYOffset + (layout.topOffset or 0)
            local sectionTopOffset = headerOffset

            if section.title and section.title ~= "" then
                sectionHeaders[#sectionHeaders + 1] = {
                    title = section.title,
                    row = startRow,
                    yOffset = headerOffset,
                    col = startCol,
                    cols = sectionCols,
                }
                headerOffset = headerOffset + sectionHeaderHeight
            end

            if section.category then
                local slotRows = math.max(1, math.ceil(visibleSlots / sectionCols))
                local targetHeight = (headerOffset - sectionTopOffset) + slotRows * size + math.max(0, slotRows - 1) * spacing
                sectionDropTargets[#sectionDropTargets + 1] = {
                    category = section.category,
                    col = startCol,
                    row = startRow,
                    yOffset = sectionTopOffset,
                    width = sectionCols * size + math.max(0, sectionCols - 1) * spacing,
                    height = targetHeight,
                }
            end

            for idx, entry in ipairs(entries) do
                local localIndex = idx - 1
                positioned[#positioned + 1] = {
                    entry = entry,
                    col = startCol + (localIndex % sectionCols),
                    row = startRow + math.floor(localIndex / sectionCols),
                    yOffset = headerOffset,
                    category = section.category,
                }
            end
            for idx = #entries + 1, visibleSlots do
                local localIndex = idx - 1
                sectionPlaceholders[#sectionPlaceholders + 1] = {
                    col = startCol + (localIndex % sectionCols),
                    row = startRow + math.floor(localIndex / sectionCols),
                    yOffset = headerOffset,
                    category = section.category,
                }
            end
            if #entries == 0 then
                sectionEmptyLabels[#sectionEmptyLabels + 1] = {
                    text = "No items found",
                    row = startRow,
                    yOffset = headerOffset,
                    col = startCol,
                    cols = sectionCols,
                }
            end
        end

        local totalHeight = 0
        if categoryLayoutMode == "fixed" then
            totalHeight = fixedTotalHeight or 0
        else
            for col = 0, cols - 1 do
                totalHeight = math.max(totalHeight, columnHeights[col] or 0)
            end
        end
        extraYOffset = extraYOffset + math.max(sectionHeaderHeight + size, totalHeight)
        hasBaseContent = true
    end

    AddSection({ entries = nonSplit })

    for _, section in ipairs(splitSections) do
        AddSection(section)
    end

    AddCategoryGrid(categorySections)

    -- Keyring is always split and always placed after non-split, split-bag, and category sections.
    if #keySlots > 0 then
        AddSection({ title = KEYRING or "Keyring", entries = keySlots })
    end

    rows = math.max(1, usedRows)

    -- Derive content height from final positioned geometry so split-section gaps
    -- are always accounted for exactly.
    local maxBottom = 0
    for _, p in ipairs(positioned) do
        local row = p.row or 0
        local yOff = p.yOffset or 0
        local bottom = gridInsetY + row * (size + spacing) + yOff + size
        if bottom > maxBottom then
            maxBottom = bottom
        end
    end
    for _, p in ipairs(sectionPlaceholders) do
        local row = p.row or 0
        local yOff = p.yOffset or 0
        local bottom = gridInsetY + row * (size + spacing) + yOff + size
        if bottom > maxBottom then
            maxBottom = bottom
        end
    end
    for _, label in ipairs(sectionEmptyLabels) do
        local row = label.row or 0
        local yOff = label.yOffset or 0
        local bottom = gridInsetY + row * (size + spacing) + yOff + size
        if bottom > maxBottom then
            maxBottom = bottom
        end
    end
    if maxBottom <= 0 then
        maxBottom = gridInsetY + size
    end
    contentHeight = maxBottom + gridInsetY
    local naturalFrameHeight = contentHeight + frameVerticalChrome
    frameHeight = math.max(200, math.min(tonumber(self.maxHeight) or BAG_DEFAULT_MAX_HEIGHT, naturalFrameHeight))
    self.frame:SetSize(frameWidth, frameHeight)
    if not layoutOnly then
        self:RefreshBagSlots()
    end
    self:UpdateScrollFrame(contentHeight, math.max(1, frameHeight - frameVerticalChrome))

    self.sectionHeaders = self.sectionHeaders or {}
    for i, header in ipairs(sectionHeaders) do
        local fs = self.sectionHeaders[i]
        if not fs then
            fs = self.frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetJustifyH("LEFT")
            self.sectionHeaders[i] = fs
        end
        fs:SetText(header.title)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + (header.col or 0) * (size + spacing), -gridInsetY - (header.row or 0) * (size + spacing) - (header.yOffset or 0))
        if header.cols then
            fs:SetWidth(header.cols * size + math.max(0, header.cols - 1) * spacing)
        else
            fs:SetWidth(gridWidth)
        end
        fs:Show()
    end
    for i = #sectionHeaders + 1, #(self.sectionHeaders or {}) do
        self.sectionHeaders[i]:Hide()
    end

    self.sectionPlaceholders = self.sectionPlaceholders or {}
    for i, placeholder in ipairs(sectionPlaceholders) do
        local frame = self.sectionPlaceholders[i]
        if not frame then
            frame = CreateFrame("Frame", nil, self.frame.content, "BackdropTemplate")
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            frame:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.5)
            self.sectionPlaceholders[i] = frame
        end
        frame:SetFrameLevel((self.frame.content and self.frame.content:GetFrameLevel() or 45) + 1)
        frame:SetSize(size, size)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + (placeholder.col or 0) * (size + spacing), -gridInsetY - (placeholder.row or 0) * (size + spacing) - (placeholder.yOffset or 0))
        frame:SetBackdropColor(0.03, 0.03, 0.03, 0.35)
        ConfigureCategoryPlaceholder(frame, self, placeholder.category)
        frame:Show()
    end
    for i = #sectionPlaceholders + 1, #(self.sectionPlaceholders or {}) do
        ConfigureCategoryPlaceholder(self.sectionPlaceholders[i], self, nil)
        self.sectionPlaceholders[i]:Hide()
    end

    self.sectionDropTargets = self.sectionDropTargets or {}
    for i, target in ipairs(sectionDropTargets) do
        local frame = self.sectionDropTargets[i]
        if not frame then
            frame = CreateFrame("Frame", nil, self.frame.content, "BackdropTemplate")
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 2,
            })
            self.sectionDropTargets[i] = frame
        end
        frame:SetFrameLevel((self.frame.content and self.frame.content:GetFrameLevel() or BAG_FRAME_LEVEL) + 90)
        frame:SetSize(target.width or size, target.height or size)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + (target.col or 0) * (size + spacing), -gridInsetY - (target.row or 0) * (size + spacing) - (target.yOffset or 0))
        ConfigureCategoryDropTarget(frame, self, target)
        frame:Show()
    end
    for i = #sectionDropTargets + 1, #(self.sectionDropTargets or {}) do
        ConfigureCategoryDropTarget(self.sectionDropTargets[i], self, nil)
        self.sectionDropTargets[i]:Hide()
    end

    self.sectionEmptyLabels = self.sectionEmptyLabels or {}
    for i, label in ipairs(sectionEmptyLabels) do
        local fs = self.sectionEmptyLabels[i]
        if not fs then
            fs = self.frame.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            self.sectionEmptyLabels[i] = fs
        end
        local labelCols = math.max(1, tonumber(label.cols) or 1)
        fs:SetText(label.text or "No items found")
        fs:SetWidth(labelCols * size + math.max(0, labelCols - 1) * spacing)
        fs:SetHeight(size)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + (label.col or 0) * (size + spacing), -gridInsetY - (label.row or 0) * (size + spacing) - (label.yOffset or 0))
        fs:Show()
    end
    for i = #sectionEmptyLabels + 1, #(self.sectionEmptyLabels or {}) do
        self.sectionEmptyLabels[i]:Hide()
    end

    used = #positioned
    local usingReadonlyButtons = readOnly
    for i = 1, used do
        local button = usingReadonlyButtons and self:AcquireReadonlyButton(i) or self:AcquireButton(i)
        button:SetSize(size, size)
        if (not layoutOnly) and ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
            ns.ItemButtonStyle.Apply(button)
        end
        local p = positioned[i]
        local col = p.col
        local row = p.row
        local extraY = p.yOffset or 0
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + col * (size + spacing), -gridInsetY - row * (size + spacing) - extraY)
        if layoutOnly then
            if ns.ItemButtonStyle and ns.ItemButtonStyle.ResetState then
                ns.ItemButtonStyle.ResetState(button)
            end
            button:Show()
        else

        local info = p.entry
        local isMatch = ItemMatchesSearch(info.item, self.searchText)
        local slotParent = self:GetBagSlotParent(info.bagID, self.frame.content)
        if slotParent and button:GetParent() ~= slotParent then
            button:SetParent(slotParent)
        end
        button.bagID = info.bagID
        button.slot = info.slot
        button.BagID = info.bagID
        button.SlotID = info.slot
        button:SetID(info.slot)
        button.itemData = info.item
        button.category = p.category
        button.virtualEmpty = info.virtualEmpty == true
        if button.DebugSlotText and IsDebugEnabled() then
            button.DebugSlotText:SetText(("%d:%d"):format(tonumber(info.bagID) or -99, tonumber(info.slot) or -99))
            button.DebugSlotText:Show()
        elseif button.DebugSlotText then
            button.DebugSlotText:Hide()
        end

        if info.item then
            if (not usingReadonlyButtons) and SetItemButtonTexture then
                SetItemButtonTexture(button, info.item.iconFileID)
            else
                button.icon:SetTexture(info.item.iconFileID)
            end
            button.icon:Show()
            local count = info.item.stackCount or 0
            if (not usingReadonlyButtons) and SetItemButtonCount then
                SetItemButtonCount(button, count)
            else
                button.count:SetText(count > 1 and count or "")
            end
            if (not usingReadonlyButtons) and SetItemButtonQuality then
                SetItemButtonQuality(button, info.item.quality, info.item.itemLink)
            end
            if (not usingReadonlyButtons) and IsViewingCurrentCharacter() then
                UpdateItemCooldown(button, info.bagID, info.slot)
            else
                ClearItemCooldown(button)
            end
            local alpha = (searching and not isMatch) and 0.22 or 1
            if self.lockSlotsMode then alpha = 1 end
            button:SetAlpha(alpha)
            button._baseAlpha = alpha
        else
            if (not usingReadonlyButtons) and SetItemButtonTexture then
                SetItemButtonTexture(button, nil)
            else
                button.icon:SetTexture(nil)
            end
            button.icon:Hide()
            if (not usingReadonlyButtons) and SetItemButtonCount then
                SetItemButtonCount(button, 0)
            else
                button.count:SetText("")
            end
            if (not usingReadonlyButtons) and SetItemButtonQuality then
                SetItemButtonQuality(button, nil)
            end
            ClearItemCooldown(button)
            local alpha = (searching and not isMatch) and 0.18 or 0.55
            if self.lockSlotsMode then alpha = 1 end
            button:SetAlpha(alpha)
            button._baseAlpha = alpha
        end
        local lockCross = EnsureLockedCross(button)
        if (not button.virtualEmpty) and self.lockSlotsMode and IsSlotUserLocked(info.bagID, info.slot) then
            lockCross:Show()
            lockCross.d1:Show()
            lockCross.d2:Show()
        else
            lockCross:Hide()
            lockCross.d1:Hide()
            lockCross.d2:Hide()
        end
        SetNewItemGlowShown(button, (not button.virtualEmpty) and IsSlotNewItem(info.bagID, info.slot, info.item))
        UpdateButtonStyleBorderForItem(button, info.item)
        button._lunaBagsSortingDesaturated = self.sortingActive == true
        if button.icon and button.icon.SetDesaturated then
            button.icon:SetDesaturated(self.sortingActive == true)
        end
        if ns.Plugins and not button.virtualEmpty then
            ns.Plugins:Apply(button, info, "oneBag")
        end
        button:EnableMouse((not button.virtualEmpty) and (self.sortingActive ~= true) and ((not readOnly) or usingReadonlyButtons))
        if button.LockOverlay then
            if (not button.virtualEmpty) and self.lockSlotsMode and not self.sortingActive and not readOnly then
                button.LockOverlay:Show()
            else
                button.LockOverlay:Hide()
            end
        end
        button:Show()
        end
    end

    for i = used + 1, #self.buttons do
        local b = self.buttons[i]
        if b and b.LockedCross then
            b.LockedCross:Hide()
            if b.LockedCross.d1 then b.LockedCross.d1:Hide() end
            if b.LockedCross.d2 then b.LockedCross.d2:Hide() end
        end
        if b and b.LockOverlay then
            b.LockOverlay:Hide()
        end
        if b and b.NewItemGlow then
            SetNewItemGlowShown(b, false)
        end
        if b and b.DebugSlotText then
            b.DebugSlotText:Hide()
        end
        self.buttons[i]:Hide()
    end
    for i = used + 1, #self.readonlyButtons do
        if self.readonlyButtons[i] and self.readonlyButtons[i].DebugSlotText then
            self.readonlyButtons[i].DebugSlotText:Hide()
        end
        if self.readonlyButtons[i] and self.readonlyButtons[i].NewItemGlow then
            SetNewItemGlowShown(self.readonlyButtons[i], false)
        end
        self.readonlyButtons[i]:Hide()
    end
    if usingReadonlyButtons then
        for i = 1, #self.buttons do
            local b = self.buttons[i]
            if b then
                if b.LockOverlay then b.LockOverlay:Hide() end
                if b.LockedCross then
                    b.LockedCross:Hide()
                    if b.LockedCross.d1 then b.LockedCross.d1:Hide() end
                    if b.LockedCross.d2 then b.LockedCross.d2:Hide() end
                end
                if b.DebugSlotText then b.DebugSlotText:Hide() end
                b:Hide()
            end
        end
    else
        for i = 1, #self.readonlyButtons do
            if self.readonlyButtons[i] then
                if self.readonlyButtons[i].NewItemGlow then SetNewItemGlowShown(self.readonlyButtons[i], false) end
                if self.readonlyButtons[i].DebugSlotText then self.readonlyButtons[i].DebugSlotText:Hide() end
                self.readonlyButtons[i]:Hide()
            end
        end
    end

    if self.frame.KeyringPanel then
        self.frame.KeyringPanel:Hide()
    end
    for i = 1, #self.keyringButtons do
        local b = self.keyringButtons[i]
        if b and b.LockedCross then
            b.LockedCross:Hide()
            if b.LockedCross.d1 then b.LockedCross.d1:Hide() end
            if b.LockedCross.d2 then b.LockedCross.d2:Hide() end
        end
        if b and b.LockOverlay then
            b.LockOverlay:Hide()
        end
        if b and b.NewItemGlow then
            SetNewItemGlowShown(b, false)
        end
        self.keyringButtons[i]:Hide()
    end

    local money = GetMoney and GetMoney() or 0
    if self.frame.moneyText then
        self.frame.moneyText:SetText(FormatMoneyText(money, 14))
    end
    if self.frame.MoneyBar and self.frame.MoneyBar.Text then
        if self.frame.MoneyBar.Label then
            self.frame.MoneyBar.Label:SetText(FormatSlotUsageText(occupiedSlots, totalSlots))
        end
        if readOnly and OneBag.viewCharacterKey and ns.BagData then
            local viewed = GetViewedCharacterData()
            local vMoney = tonumber(viewed and viewed.money) or 0
            self.frame.MoneyBar.Text:SetText(FormatMoneyText(vMoney or 0, 14))
        else
            self.frame.MoneyBar.Text:SetText(FormatMoneyText(money, 14))
        end
    end
    if self.frame.CustomTitle then
        local titleName = UnitName("player") or "Player"
        if readOnly and OneBag.viewCharacterKey and ns.BagData then
            local viewed = GetViewedCharacterData()
            if viewed and viewed.name then
                titleName = viewed.name
            end
        end
        self.frame.CustomTitle:SetText(string.format("%s - Bags", titleName))
    end
    self.newItemTrackingReady = true
    self:SetSortingState(self.sortingActive == true)
end

function OneBag:RefreshDeferred(layoutOnly)
    if not self.frame then
        return
    end
    self._refreshDeferredToken = (self._refreshDeferredToken or 0) + 1
    local token = self._refreshDeferredToken
    if layoutOnly ~= true then
        self._refreshDeferredNeedsFull = true
    end
    local function run()
        if token ~= OneBag._refreshDeferredToken or not OneBag.frame or not OneBag.frame:IsShown() then
            return
        end
        local full = OneBag._refreshDeferredNeedsFull == true
        OneBag._refreshDeferredNeedsFull = nil
        OneBag:Refresh(not full)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

function OneBag:SavePosition()
    if not self.frame then
        return
    end
    local cfg = GetConfig()
    if not cfg then
        return
    end
    local point, _, _, x, y = self.frame:GetPoint(1)
    cfg.point = point or "BOTTOMRIGHT"
    cfg.x = x or -34
    cfg.y = y or 126
end

function OneBag:SaveWindowWidth(width)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    width = math.max(280, math.min(900, math.floor((tonumber(width) or self.windowWidth or 481) + 0.5)))
    cfg.windowWidth = width
    cfg._windowWidthMigrated = true
    self.windowWidth = width
end

function OneBag:StartResize(side)
    if not self.frame or self._resizing then
        return
    end
    self._resizing = true
    self._resizeSide = (side == "left") and "left" or "right"
    self._resizeLeft = self.frame:GetLeft() or 0
    self._resizeRight = self.frame:GetRight() or (self._resizeLeft + (self.frame:GetWidth() or self.windowWidth or 0))
    self._resizeBottom = self.frame:GetBottom() or 0
    self.frame:ClearAllPoints()
    if self._resizeSide == "left" then
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", self._resizeRight, self._resizeBottom)
    else
        self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", self._resizeLeft, self._resizeBottom)
    end
    self:SavePosition()

    local grip = (self._resizeSide == "left") and self.frame.LeftResizeGrip or self.frame.ResizeGrip
    if grip then
        grip:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                OneBag:StopResize()
                return
            end
            local cursorX = GetCursorPosition()
            local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            local scaledCursorX = cursorX / scale
            local rawWidth
            if OneBag._resizeSide == "left" then
                rawWidth = (OneBag._resizeRight or scaledCursorX) - scaledCursorX
            else
                rawWidth = scaledCursorX - (OneBag._resizeLeft or 0)
            end
            local width = math.max(280, math.min(900, math.floor(rawWidth + 0.5)))
            if width ~= OneBag.windowWidth then
                OneBag.windowWidth = width
                if OneBag.frame.SetWidth then
                    OneBag.frame:SetWidth(width)
                else
                    OneBag.frame:SetSize(width, OneBag.frame:GetHeight())
                end
                local newColumns = CalculateColumnsFromWindowWidth(OneBag.windowWidth, OneBag.slotSize, OneBag.spacing)
                if newColumns ~= OneBag.columns then
                    OneBag.columns = newColumns
                    OneBag:Refresh(true)
                else
                    OneBag:UpdateScrollFrame(OneBag._scrollContentHeight or 1, OneBag._scrollViewportHeight or 1)
                end
            end
        end)
    end
end

function OneBag:StopResize()
    if not self._resizing then
        return
    end
    self._resizing = false
    if self.frame and self.frame.ResizeGrip then
        self.frame.ResizeGrip:SetScript("OnUpdate", nil)
    end
    if self.frame and self.frame.LeftResizeGrip then
        self.frame.LeftResizeGrip:SetScript("OnUpdate", nil)
    end
    self._resizeSide = nil
    self:SaveWindowWidth(self.windowWidth)
    self.columns = CalculateColumnsFromWindowWidth(self.windowWidth, self.slotSize, self.spacing)
    self:Refresh()
    self:SavePosition()
    NotifyOptionsChanged()
end

function OneBag:SaveVisibleBagsState()
    local cfg = GetConfig()
    if not cfg then
        return
    end
    cfg.visibleBags = CopyVisibleBagsState(self.visibleBags)
end

function OneBag:ApplySettings()
    local cfg = GetConfig()
    if not cfg then
        return
    end

    self.slotSize = math.max(24, math.min(48, tonumber(cfg.itemSize) or 36))
    self.spacing = math.max(0, math.min(12, tonumber(cfg.spacing) or 4))
    if cfg._windowWidthMigrated ~= true then
        cfg.windowWidth = CalculateWindowWidthFromColumns(tonumber(cfg.columns) or 11, self.slotSize, self.spacing)
        cfg._windowWidthMigrated = true
    end
    local fallbackWidth = CalculateWindowWidthFromColumns(tonumber(cfg.columns) or 11, self.slotSize, self.spacing)
    self.windowWidth = math.max(240, math.min(1200, tonumber(cfg.windowWidth) or fallbackWidth))
    self.maxHeight = math.max(220, math.min(1200, tonumber(cfg.windowMaxHeight) or BAG_DEFAULT_MAX_HEIGHT))
    self.columns = CalculateColumnsFromWindowWidth(self.windowWidth, self.slotSize, self.spacing)
    self.splitByBagRows = cfg.splitByBagRows == true
    self.showBagRail = cfg.showBagRail ~= false
    self.bagRailPosition = (cfg.bagRailPosition == "top" or cfg.bagRailPosition == "left" or cfg.bagRailPosition == "right" or cfg.bagRailPosition == "bottom")
        and cfg.bagRailPosition
        or "top"
    self.visibleBags = CopyVisibleBagsState(cfg.visibleBags)

    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point or "BOTTOMRIGHT", UIParent, cfg.point or "BOTTOMRIGHT", cfg.x or -34, cfg.y or 126)
        self.frame:SetScale(math.max(0.7, math.min(1.5, tonumber(cfg.scale) or 1)))
        self.frame:SetMovable(not cfg.locked)
        self.frame:EnableMouse(true)
        self.frame:RegisterForDrag()
        if self.frame.HeaderDrag then
            self.frame.HeaderDrag:EnableMouse(not cfg.locked)
            self.frame.HeaderDrag:SetShown(not cfg.locked)
        end
        if self.frame.ResizeGrip then
            self.frame.ResizeGrip:EnableMouse(not cfg.locked)
            self.frame.ResizeGrip:SetAlpha(cfg.locked and 0.25 or 1)
        end
        if self.frame.LeftResizeGrip then
            self.frame.LeftResizeGrip:EnableMouse(not cfg.locked)
            self.frame.LeftResizeGrip:SetAlpha(cfg.locked and 0.25 or 1)
        end
        ApplyWindowAppearance(self.frame, cfg)
        if self.frame.RailToggleButton then
            self.frame.RailToggleButton:SetAlpha(self.showBagRail and 1 or 0.6)
        end
        if self.frame.CharacterButton and self.frame.CharacterButton.Icon then
            local classToken = select(2, UnitClass("player"))
            if self.viewCharacterKey and ns.BagData then
                local viewed = GetViewedCharacterData()
                if viewed and viewed.class then
                    classToken = viewed.class
                end
            end
            local coords = CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken]
            self.frame.CharacterButton.Icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            if coords then
                self.frame.CharacterButton.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            else
                self.frame.CharacterButton.Icon:SetTexCoord(0, 1, 0, 1)
            end
        end
    end
end

function OneBag:ResetPosition()
    local cfg = GetConfig()
    if not cfg then
        return
    end
    cfg.point = "BOTTOMRIGHT"
    cfg.x = -34
    cfg.y = 126
    self:ApplySettings()
end

function OneBag:Show()
    if ns.LunaBags and ns.LunaBags.IsWindowModuleEnabled and not ns.LunaBags:IsWindowModuleEnabled("oneBag") then
        return
    end
    self:CreateFrame()
    self:SetViewCharacterKey(nil)
    self:ApplySettings()
    EnsureStackSplitFrameAboveBags()
    self.frame:Show()
    if ns.LunaBags and ns.LunaBags.QueueOpenWindowRefresh then
        ns.LunaBags:QueueOpenWindowRefresh()
    elseif self.RefreshDeferred then
        self:RefreshDeferred()
    else
        self:Refresh()
    end
end

function OneBag:Hide()
    if self.frame then
        ClearAllNewItemGlows()
        self.frame:Hide()
    end
end

function OneBag:Toggle()
    self:CreateFrame()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
