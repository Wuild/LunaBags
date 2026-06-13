local _, ns = ...

local OneBank = ns.LunaBags and ns.LunaBags:NewModule("OneBank") or {}
OneBank.frame = nil
OneBank.buttons = {}
OneBank.bagButtons = {}
OneBank.columns = 14
OneBank.slotSize = 36
OneBank.spacing = 4
OneBank.searchText = ""
OneBank.searchVisible = false
OneBank.showBagRail = true
OneBank.bagRailPosition = "top"
OneBank.visibleBags = {}
OneBank.sortingActive = false
OneBank.viewMode = false
OneBank.viewCharacterKey = nil
OneBank._closingBankFrame = false
OneBank.draggedCategoryItem = nil

ns.OneBank = OneBank

function OneBank:OnDisable()
    self:Hide()
    if ns.LunaBags and ns.LunaBags.RestoreDefaultBankFrame then
        ns.LunaBags:RestoreDefaultBankFrame()
    end
end

local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }
local BANK_BAG_SLOTS = { 5, 6, 7, 8, 9, 10, 11 }
local BANK_FRAME_STRATA = "DIALOG"
local BANK_FRAME_LEVEL = 40
local BANK_FRAME_PADDING_X = 26
local BANK_DEFAULT_MAX_HEIGHT = 650

local function CalculateWindowWidthFromColumns(columns, slotSize, spacing)
    columns = math.max(1, math.floor(tonumber(columns) or 1))
    slotSize = tonumber(slotSize) or 36
    spacing = tonumber(spacing) or 4
    local gridWidth = columns * slotSize + math.max(0, columns - 1) * spacing
    return gridWidth + (spacing * 2) + BANK_FRAME_PADDING_X
end

local function CalculateColumnsFromWindowWidth(windowWidth, slotSize, spacing)
    windowWidth = tonumber(windowWidth) or CalculateWindowWidthFromColumns(14, slotSize, spacing)
    slotSize = tonumber(slotSize) or 36
    spacing = tonumber(spacing) or 4
    local gridSpace = math.max(slotSize, windowWidth - BANK_FRAME_PADDING_X - (spacing * 2))
    return math.max(1, math.floor((gridSpace + spacing) / (slotSize + spacing)))
end

local function NormalizeRailPosition(position, fallback)
    if position == "top" or position == "left" or position == "right" or position == "bottom" then
        return position
    end
    return fallback or "top"
end

local function PositionBankRail(frame, rail, position)
    rail:ClearAllPoints()
    if position == "left" then
        rail:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    elseif position == "right" then
        rail:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    elseif position == "bottom" then
        rail:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
    else
        rail:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    end
end

local function EnsureStackSplitFrameAboveBank()
    local splitFrame = _G.StackSplitFrame
    if not splitFrame then
        return
    end
    splitFrame:SetFrameStrata("TOOLTIP")
    splitFrame:SetFrameLevel(BANK_FRAME_LEVEL + 120)
end

local function ApplyBankFrameLayering(frame)
    if not frame then
        return
    end
    frame:SetFrameStrata(BANK_FRAME_STRATA)
    frame:SetFrameLevel(BANK_FRAME_LEVEL)
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end
    if frame.content then
        frame.content:SetFrameLevel(BANK_FRAME_LEVEL + 5)
    end
    if frame.Content then
        frame.Content:SetFrameLevel(BANK_FRAME_LEVEL + 5)
    end
    if frame.BagSlots then
        frame.BagSlots:SetFrameLevel(BANK_FRAME_LEVEL + 6)
    end
    if frame.SearchPanel then
        frame.SearchPanel:SetFrameLevel(BANK_FRAME_LEVEL + 10)
    end
    if frame.CloseButton then
        frame.CloseButton:SetFrameLevel(BANK_FRAME_LEVEL + 15)
    end
    if frame.RailToggleButton then
        frame.RailToggleButton:SetFrameLevel(BANK_FRAME_LEVEL + 15)
    end
    if frame.SettingsButton then
        frame.SettingsButton:SetFrameLevel(BANK_FRAME_LEVEL + 15)
    end
    if frame.CharacterButton then
        frame.CharacterButton:SetFrameLevel(BANK_FRAME_LEVEL + 15)
    end
    if frame.SearchToggleButton then
        frame.SearchToggleButton:SetFrameLevel(BANK_FRAME_LEVEL + 15)
    end
    if frame.SortButton then
        frame.SortButton:SetFrameLevel(BANK_FRAME_LEVEL + 15)
    end
    if frame.ResizeGrip then
        frame.ResizeGrip:SetFrameLevel(BANK_FRAME_LEVEL + 18)
    end
    if frame.LeftResizeGrip then
        frame.LeftResizeGrip:SetFrameLevel(BANK_FRAME_LEVEL + 18)
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

local function IsVisualSortEnabled()
    local addon = ns.LunaBags
    local sorting = addon and addon.db and addon.db.profile and addon.db.profile.sorting
    return sorting and sorting.visualOnly == true or false
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
    frame.ResizeGrip:SetFrameLevel(BANK_FRAME_LEVEL + 18)

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
    frame.LeftResizeGrip:SetFrameLevel(BANK_FRAME_LEVEL + 18)
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
    if button.SetNormalTexture then
        button:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    end
    if button.SetPushedTexture then
        button:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then
        normal:SetVertexColor(0.10, 0.10, 0.10, 0.95)
    end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then
        pushed:SetVertexColor(0.16, 0.16, 0.16, 1)
    end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(0.28, 0.28, 0.28, 0.55)
    end
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
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -14)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 14)
    scrollBar:SetWidth(10)
    scrollBar:SetFrameLevel((scrollFrame:GetFrameLevel() or BANK_FRAME_LEVEL) + 2)

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
        frame.ScrollFrame = CreateFrame("ScrollFrame", "LunaBagsOneBankScrollFrame", frame, "UIPanelScrollFrameTemplate")
        frame.ScrollFrame:SetFrameLevel(BANK_FRAME_LEVEL + 5)
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
    frame.content:SetFrameLevel(BANK_FRAME_LEVEL + 5)
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
    if value == nil then
        return fallback
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
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
end

local function GetCurrentCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return ("%s-%s"):format(name, realm)
end

local function NormalizeCharacterKey(key)
    return tostring(key or ""):lower():gsub("%s+", "")
end

local function GetViewedBankCharacterData()
    if not ns.BagData then
        return nil
    end
    return ns.BagData:GetCharacterData(OneBank.viewCharacterKey or GetCurrentCharacterKey())
end

local function IsBankViewMode()
    return OneBank.viewMode == true
end

local function GetCachedBankBagData(character, bagID)
    if not character or type(character.bank) ~= "table" then
        return nil
    end
    return character.bank[bagID] or character.bank[tostring(bagID)]
end

local function GetCachedBankSlot(bagData, slot)
    if type(bagData) ~= "table" then
        return nil
    end
    local slots = type(bagData.slots) == "table" and bagData.slots or bagData
    return slots[slot] or slots[tostring(slot)]
end

local function GetCachedBankSlotCount(bagData)
    if type(bagData) ~= "table" then
        return 0
    end
    local size = tonumber(bagData.size)
    if size and size > 0 then
        return size
    end
    local slots = type(bagData.slots) == "table" and bagData.slots or bagData
    local maxSlot = 0
    if type(slots) == "table" then
        for key in pairs(slots) do
            local slot = tonumber(key)
            if slot and slot > maxSlot then
                maxSlot = slot
            end
        end
    end
    return maxSlot
end

local function GetConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.oneBank = addon.db.profile.oneBank or {}
    local cfg = addon.db.profile.oneBank
    cfg.splitBags = cfg.splitBags or {}
    cfg.visibleBags = cfg.visibleBags or {}

    if addon.db.profile.oneBank._viewOptionsPerCharMigrated ~= true then
        local key = GetCurrentCharacterKey()
        local old = type(cfg.perCharacter) == "table" and key and cfg.perCharacter[key] or nil
        if type(old) == "table" and type(old.splitBags) == "table" then
            for bagID, enabled in pairs(old.splitBags) do
                if cfg.splitBags[bagID] == nil then
                    cfg.splitBags[bagID] = enabled == true or nil
                end
            end
        end
        if type(old) == "table" and type(old.visibleBags) == "table" then
            for bagID, enabled in pairs(old.visibleBags) do
                if cfg.visibleBags[bagID] == nil then
                    cfg.visibleBags[bagID] = enabled ~= false
                end
            end
        end
        addon.db.profile.oneBank._viewOptionsPerCharMigrated = true
    end

    return addon.db.profile.oneBank
end

local function GetViewedProfile()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    if not IsBankViewMode() or not addon.GetProfileKeyForCharacter then
        return addon.db.profile
    end
    local profileKey = addon:GetProfileKeyForCharacter(OneBank.viewCharacterKey)
    if profileKey and addon.db.profiles and addon.db.profiles[profileKey] then
        return addon.db.profiles[profileKey]
    end
    return addon.db.profile
end

local function GetBankCategoryConfig()
    local profile = GetViewedProfile()
    local categories = profile and profile.categories
    local cfg = categories and categories.bank
    if type(cfg) ~= "table" then
        return nil
    end
    cfg.list = cfg.list or {}
    cfg.columns = tonumber(cfg.columns) or 1
    cfg.layout = (cfg.layout == "fixed") and "fixed" or "masonry"
    return cfg
end

local function MatchBankCategory(item, categoryConfig)
    if not item or not ns.Categories or not ns.Categories.ItemMatches then
        return nil
    end
    if categoryConfig and categoryConfig.enabled == true then
        for _, category in ipairs(categoryConfig.list or {}) do
            if ns.Categories:ItemMatches(category, item) then
                return category
            end
        end
    end
    if ns.Categories.GetDynamicList then
        for _, category in ipairs(ns.Categories:GetDynamicList("bank") or {}) do
            if ns.Categories:ItemMatches(category, item) then
                return category
            end
        end
    end
    return nil
end

local function GetBankActiveCategories(categoryConfig)
    local out = {}
    if categoryConfig and categoryConfig.enabled == true then
        for _, category in ipairs(categoryConfig.list or {}) do
            if type(category) == "table" and category.enabled ~= false then
                out[#out + 1] = category
            end
        end
    end
    if ns.Categories and ns.Categories.GetDynamicList then
        for _, category in ipairs(ns.Categories:GetDynamicList("bank") or {}) do
            out[#out + 1] = category
        end
    end
    return out
end

local function EnsureVisibleBankBagDefaults(state)
    for _, bagID in ipairs(BANK_BAG_SLOTS) do
        if state[bagID] == nil then
            state[bagID] = true
        end
    end
end

local function CopyVisibleBankBagsState(state)
    local out = {}
    if type(state) == "table" then
        for k, v in pairs(state) do
            local n = tonumber(k)
            out[n or k] = v ~= false
        end
    end
    EnsureVisibleBankBagDefaults(out)
    return out
end

local function IsBankBagSplitEnabled(bagID)
    local cfg = GetConfig()
    if not cfg then
        return false
    end
    cfg.splitBags = cfg.splitBags or {}
    return cfg.splitBags[bagID] == true or cfg.splitBags[tostring(bagID)] == true
end

local function SetBankBagSplitEnabled(bagID, enabled)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    cfg.splitBags = cfg.splitBags or {}
    cfg.splitBags[bagID] = enabled == true or nil
    cfg.splitBags[tostring(bagID)] = nil
    OneBank:InvalidateSlotCache()
end

local function GetBankSplitLayoutKey()
    local parts = {}
    for _, bagID in ipairs(BANK_BAG_SLOTS) do
        parts[#parts + 1] = tostring(bagID) .. "=" .. tostring(IsBankBagSplitEnabled(bagID))
    end
    return table.concat(parts, ";")
end

local function GetBankCategoryLayoutKey(categoryConfig)
    if type(categoryConfig) ~= "table" then
        return "categories=none"
    end

    local parts = {
        "enabled=" .. tostring(categoryConfig.enabled == true),
        "columns=" .. tostring(tonumber(categoryConfig.columns) or 1),
        "layout=" .. tostring(categoryConfig.layout or "masonry"),
    }
    for index, category in ipairs(categoryConfig.list or {}) do
        parts[#parts + 1] = table.concat({
            tostring(index),
            tostring(category.id or category.name or ""),
            tostring(category.enabled ~= false),
            tostring(category.hidden == true),
            tostring(tonumber(category.columns) or 0),
            tostring(tonumber(category.minSlots) or 0),
        }, ",")
    end
    return table.concat(parts, ";")
end

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
    if owner and owner.viewMode then
        return false
    end
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
            if owner.InvalidateSlotCache then
                owner:InvalidateSlotCache()
            else
                owner._layoutModel = nil
                owner._layoutModelKey = nil
            end
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
    if owner and owner.viewMode then
        return false
    end
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
        if owner.InvalidateSlotCache then
            owner:InvalidateSlotCache()
        else
            owner._layoutModel = nil
            owner._layoutModelKey = nil
        end
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
        overlay:SetFrameLevel((owner.frame.content:GetFrameLevel() or BANK_FRAME_LEVEL) + 80)
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
    if owner.viewMode then
        owner.draggedCategoryItem = nil
        ShowInventoryDropOverlay(owner, false)
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
    frame:EnableMouse(category ~= nil and not owner.viewMode)
    frame:SetScript("OnReceiveDrag", nil)
    frame:SetScript("OnMouseUp", nil)
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    if not category or owner.viewMode then
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
        self:SetBackdropColor(0.08, 0.08, 0.08, 0.42)
        self:SetBackdropBorderColor(0.28, 0.28, 0.28, 0.55)
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
    if not target or not target.category or owner.viewMode then
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

local function AddBankMoneyTooltipBreakdown(owner)
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

local function GetItemCooldownSignature(bagID, slot)
    if not bagID or not slot then
        return ""
    end
    local start, duration, enable
    if C_Container and C_Container.GetContainerItemCooldown then
        start, duration, enable = C_Container.GetContainerItemCooldown(bagID, slot)
    else
        start, duration, enable = GetContainerItemCooldown(bagID, slot)
    end
    return tostring(start or 0) .. "," .. tostring(duration or 0) .. "," .. tostring(enable or 0)
end

local function GetPluginRenderSignature()
    local addon = ns.LunaBags
    local cfg = addon and addon.db and addon.db.profile and addon.db.profile.plugins
    local parts = {}
    if type(cfg) == "table" then
        for key, value in pairs(cfg) do
            if type(value) == "table" then
                local nested = {}
                for optionKey, optionValue in pairs(value) do
                    nested[#nested + 1] = tostring(optionKey) .. "=" .. tostring(optionValue)
                end
                table.sort(nested)
                parts[#parts + 1] = tostring(key) .. "={" .. table.concat(nested, ",") .. "}"
            else
                parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
            end
        end
    end
    if ns.Plugins and type(ns.Plugins.registry) == "table" then
        for id, plugin in pairs(ns.Plugins.registry) do
            if type(plugin) == "table" and type(plugin.GetRenderSignature) == "function" then
                parts[#parts + 1] = tostring(id) .. ":" .. tostring(plugin:GetRenderSignature())
            end
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function GetButtonRenderSignature(info, context, readOnly, alpha, sortingActive, pluginSignature)
    local item = info and info.item
    local cooldownSignature = item and not readOnly and GetItemCooldownSignature(info.bagID, info.slot) or ""
    return table.concat({
        tostring(context or ""),
        tostring(info and info.bagID or ""),
        tostring(info and info.slot or ""),
        tostring(readOnly == true),
        tostring(alpha or ""),
        tostring(sortingActive == true),
        tostring(item and item.iconFileID or ""),
        tostring(item and item.stackCount or ""),
        tostring(item and item.quality or ""),
        tostring(item and item.itemLink or item and item.itemID or ""),
        cooldownSignature,
        tostring(pluginSignature or ""),
    }, "|")
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

local function IsBaseBankContainer(bagID)
    return bagID == BANK_CONTAINER or bagID == -1
end

local function BankItemToInventorySlotCompat(slot)
    if BankButtonIDToInvSlotID then
        return BankButtonIDToInvSlotID(slot)
    end
    return nil
end

local function ShowLiveBankItemTooltip(button)
    local bagID = button and (button.bagID or button.viewBagID)
    local slot = button and (button.slot or button.viewSlot)
    if not button or not bagID or not slot then
        return false
    end

    if button.readOnly then
        local link = button.itemData and button.itemData.itemLink
        if link and GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink(link)
            return true
        end
        return false
    end

    if IsBaseBankContainer(bagID) then
        if BankFrameItemButton_OnEnter then
            BankFrameItemButton_OnEnter(button)
            return true
        end

        local invSlot = BankItemToInventorySlotCompat(slot)
        if invSlot and GameTooltip:SetInventoryItem("player", invSlot) then
            return true
        end
    elseif ContainerFrameItemButton_OnEnter then
        ContainerFrameItemButton_OnEnter(button)
        return true
    end

    local ok = GameTooltip:SetBagItem(bagID, slot)
    if ok then
        return true
    end

    local link = (button.itemData and button.itemData.itemLink) or GetItemLinkFromBag(bagID, slot)
    if link and GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink(link)
        return true
    end

    return false
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
    if normal then
        normal:SetTexture(nil);
        normal:Hide()
    end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then
        pushed:SetTexture(nil);
        pushed:Hide()
    end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        highlight:SetTexture(nil);
        highlight:Hide()
    end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then
        checked:SetTexture(nil);
        checked:Hide()
    end
    if button.IconBorder then
        button.IconBorder:SetAlpha(0);
        button.IconBorder:Hide()
    end
    if button.Background then
        button.Background:SetTexture(nil);
        button.Background:Hide()
    end
    if button.IconOverlay then
        button.IconOverlay:SetTexture(nil);
        button.IconOverlay:Hide()
    end
    if button.searchOverlay then
        button.searchOverlay:Hide()
    end

    if not button.StyleStateHooks then
        local function Brighten(v, amount)
            return math.min(1, (v or 0) + amount)
        end
        local function SetIdle(self)
            if not self.StyleBG or not self.StyleBorder then
                return
            end
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
            if not self.StyleBG or not self.StyleBorder then
                return
            end
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
            if not self.StyleBG or not self.StyleBorder then
                return
            end
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
        button:HookScript("OnDragStart", SetDrag)
        button:HookScript("OnReceiveDrag", function(self)
            if self:IsMouseOver() then
                SetHover(self)
            else
                SetIdle(self)
            end
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
    button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = r, g, b, a
    button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
    if button.IconBorder then
        button.IconBorder:SetAlpha(0);
        button.IconBorder:Hide()
    end
    if button.Background then
        button.Background:SetTexture(nil);
        button.Background:Hide()
    end
    if button.IconOverlay then
        button.IconOverlay:SetTexture(nil);
        button.IconOverlay:Hide()
    end
end

local function EnsureBankPlaceholder(parent, index)
    parent.BankCategoryPlaceholders = parent.BankCategoryPlaceholders or {}
    local frame = parent.BankCategoryPlaceholders[index]
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.42)
    frame:SetBackdropBorderColor(0.28, 0.28, 0.28, 0.55)
    parent.BankCategoryPlaceholders[index] = frame
    return frame
end

function OneBank:UpdateSearchLayout()
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

function OneBank:UpdateScrollFrame(contentHeight, viewportHeight)
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
        frame:SetFrameStrata(BANK_FRAME_STRATA)
        frame:SetFrameLevel(BANK_FRAME_LEVEL)
        if frame.SetToplevel then
            frame:SetToplevel(true)
        end
        frame:Hide()
        frame.content = CreateFrame("Frame", nil, frame)
        frame.content:SetFrameLevel(BANK_FRAME_LEVEL + 5)
        frame.content:SetPoint("TOPLEFT", 8, -48)
        frame.content:SetPoint("BOTTOMRIGHT", -8, 36)
    end
    ApplyBankFrameLayering(frame)
    EnsureStackSplitFrameAboveBank()

    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        OneBank:SavePosition()
    end)
    frame:SetScript("OnHide", function()
        if OneBank.frame and OneBank.frame.SearchEditBox then
            OneBank.frame.SearchEditBox:ClearFocus()
        end
        if OneBank.viewMode then
            return
        end
        if OneBank._closingBankFrame then
            return
        end
        if CloseBankFrame and BankFrame and BankFrame:IsShown() then
            OneBank._closingBankFrame = true
            CloseBankFrame()
            OneBank._closingBankFrame = false
        end
    end)
    frame.content = frame.Content or frame.content
    EnsureScrollFrame(frame)
    frame.content:EnableMouse(true)
    frame.content:SetScript("OnReceiveDrag", function()
        RemoveDraggedItemFromCategory(OneBank)
    end)
    frame.content:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and CursorHasAssignableItem() then
            RemoveDraggedItemFromCategory(OneBank)
        end
    end)

    if frame.TitleText then
        frame.TitleText:Hide()
    end
    if frame.TitleBg then
        frame.TitleBg:Hide()
    end
    if frame.TopLeftCorner then
        frame.TopLeftCorner:Hide()
    end
    if frame.TopRightCorner then
        frame.TopRightCorner:Hide()
    end
    if frame.TopBorder then
        frame.TopBorder:Hide()
    end
    if frame.LeftBorder then
        frame.LeftBorder:Hide()
    end
    if frame.RightBorder then
        frame.RightBorder:Hide()
    end
    if frame.BottomBorder then
        frame.BottomBorder:Hide()
    end
    if frame.BottomLeftCorner then
        frame.BottomLeftCorner:Hide()
    end
    if frame.BottomRightCorner then
        frame.BottomRightCorner:Hide()
    end
    if frame.Bg then
        frame.Bg:Hide()
    end
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
    end
    if not frame.HeaderDrag then
        frame.HeaderDrag = CreateFrame("Frame", nil, frame)
        frame.HeaderDrag:EnableMouse(true)
        frame.HeaderDrag:RegisterForDrag("LeftButton")
        frame.HeaderDrag:SetScript("OnDragStart", function()
            if OneBank.frame and OneBank.frame:IsMovable() then
                OneBank.frame:StartMoving()
            end
        end)
        frame.HeaderDrag:SetScript("OnDragStop", function()
            if OneBank.frame then
                OneBank.frame:StopMovingOrSizing()
                OneBank:SavePosition()
            end
        end)
    end
    frame.HeaderDrag:ClearAllPoints()
    frame.HeaderDrag:SetPoint("TOPLEFT", frame.TitleBarBg, "TOPLEFT", 0, 0)
    frame.HeaderDrag:SetPoint("BOTTOMRIGHT", frame.TitleBarBg, "BOTTOMRIGHT", 0, 0)
    frame.HeaderDrag:SetFrameLevel(BANK_FRAME_LEVEL + 8)
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
        frame.OuterBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        frame.OuterBorder:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
    end

    if not frame.CustomTitle then
        frame.CustomTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.CustomTitle:SetPoint("CENTER", frame.TitleBarBg, "CENTER", 0, 0)
    end
    local bankTitle = BANK or "Bank"
    if IsBankViewMode() then
        local character = GetViewedBankCharacterData()
        local name = character and character.name or UnitName("player") or "Player"
        bankTitle = ("%s - %s"):format(name, bankTitle)
    end
    frame.CustomTitle:SetText(bankTitle)

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
        frame.SearchEditBox:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
        end)
        frame.SearchEditBox:SetScript("OnEnterPressed", function(editBox)
            editBox:ClearFocus()
        end)
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
    frame.SearchToggleButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Search")
        GameTooltip:Show()
    end)
    frame.SearchToggleButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    if not frame.SortButton then
        frame.SortButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.SortButton:SetText("")
    frame.SortButton:SetNormalTexture("Interface\\AddOns\\LunaBags\\Art\\broom")
    frame.SortButton:SetPushedTexture("Interface\\AddOns\\LunaBags\\Art\\broom")
    frame.SortButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.SortButton:SetSize(18, 18)
    frame.SortButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 71, 0)
    frame.SortButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.SortButton:SetScript("OnClick", LunaBagsOneBank_SortButtonClicked)
    frame.SortButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort Bank")
        GameTooltip:Show()
    end)
    frame.SortButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
        if OneBank.viewMode and OneBank.viewCharacterKey and ns.BagData then
            local viewed = GetViewedBankCharacterData()
            if viewed and viewed.class then
                classToken = viewed.class
            end
        end
        local coords = CLASS_ICON_TCOORDS and classToken and CLASS_ICON_TCOORDS[classToken]
        if coords then
            frame.CharacterButton.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            frame.CharacterButton.Icon:SetTexCoord(0, 1, 0, 1)
        end
    end
    frame.CharacterButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Character Bank View")
        GameTooltip:Show()
    end)
    frame.CharacterButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.CharacterButton:SetScript("OnClick", function()
        if not LunaBagsBankCharacterMenu then
            CreateFrame("Frame", "LunaBagsBankCharacterMenu", UIParent, "UIDropDownMenuTemplate")
        end

        local items = {}
        local currentKey = GetCurrentCharacterKey()
        items[#items + 1] = {
            text = "Current Character",
            checked = function()
                return OneBank.viewMode == true and NormalizeCharacterKey(OneBank.viewCharacterKey) == NormalizeCharacterKey(currentKey)
            end,
            func = function()
                OneBank:OpenViewMode(currentKey)
            end,
            isNotRadio = true,
            keepShownOnClick = false,
        }

        if ns.BagData then
            for key, c in ns.BagData:IterCharacters() do
                local selectedKey = key
                local selectedChar = c
                local label = (selectedChar and selectedChar.name and selectedChar.realm)
                    and (selectedChar.name .. " - " .. selectedChar.realm)
                    or selectedKey
                items[#items + 1] = {
                    text = label,
                    checked = function()
                        return OneBank.viewMode == true and NormalizeCharacterKey(OneBank.viewCharacterKey) == NormalizeCharacterKey(selectedKey)
                    end,
                    func = function()
                        OneBank:OpenViewMode(selectedKey)
                    end,
                    isNotRadio = true,
                    keepShownOnClick = false,
                }
            end
        end

        if EasyMenu then
            EasyMenu(items, LunaBagsBankCharacterMenu, "cursor", 0, 0, "MENU")
        else
            UIDropDownMenu_Initialize(LunaBagsBankCharacterMenu, function(_, level)
                if level ~= 1 then
                    return
                end
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
            ToggleDropDownMenu(1, nil, LunaBagsBankCharacterMenu, "cursor", 0, 0)
        end
    end)

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
    frame.RailToggleButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(IsBankViewMode() and "Bank bag rail is hidden in view mode." or "Toggle Bank Bag Rail")
        GameTooltip:Show()
    end)
    frame.RailToggleButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
        if ns.OpenConfig then
            ns.OpenConfig()
        end
    end)
    frame.SettingsButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(SETTINGS or "Settings")
        GameTooltip:Show()
    end)
    frame.SettingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
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
            if tex then
                tex:SetAlpha(0)
            end
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
            AddBankMoneyTooltipBreakdown(bar)
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
    EnsureResizeGrip(self, frame)
    ApplyBankFrameLayering(frame)

    self.frame = frame
    self:ApplySettings()
    self:UpdateSearchLayout()
end

function OneBank:AcquireBagButton(index)
    local btn = self.bagButtons[index]
    if btn then
        return btn
    end

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
        local isVisible = OneBank.visibleBags[button.bagID] ~= false
        GameTooltip:AddLine(isVisible and "Shown in bank window" or "Hidden from bank window", 0.8, 0.8, 0.8)
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
        OneBank:SetBagSlotPreview(button.bagID)
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
        OneBank:SetBagSlotPreview(nil)
    end)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(button, mouseButton)
        if mouseButton == "RightButton" then
            if not LunaBagsBankBagRailMenu then
                CreateFrame("Frame", "LunaBagsBankBagRailMenu", UIParent, "UIDropDownMenuTemplate")
            end
            local bagID = button.bagID
            local canSplit = button.isPurchased ~= false and bagID ~= nil
            local menu = {
                {
                    text = "Split This Bank Bag Section",
                    checked = function()
                        return canSplit and IsBankBagSplitEnabled(bagID)
                    end,
                    disabled = not canSplit,
                    func = function()
                        if not canSplit then
                            return
                        end
                        SetBankBagSplitEnabled(bagID, not IsBankBagSplitEnabled(bagID))
                        OneBank:Refresh()
                    end,
                    isNotRadio = true,
                    keepShownOnClick = true,
                },
            }
            if EasyMenu then
                EasyMenu(menu, LunaBagsBankBagRailMenu, "cursor", 0, 0, "MENU")
            else
                UIDropDownMenu_Initialize(LunaBagsBankBagRailMenu, function(_, level)
                    if level ~= 1 then
                        return
                    end
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
                ToggleDropDownMenu(1, nil, LunaBagsBankBagRailMenu, "cursor", 0, 0)
            end
            return
        end
        if button.isPurchased == false then
            if StaticPopup_Show and _G["CONFIRM_BUY_BANK_SLOT"] then
                StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
            elseif PurchaseSlot then
                PurchaseSlot()
            end
            return
        end
        if not button.invSlot then
            return
        end
        if CursorHasAssignableItem() then
            PutItemInBag(button.invSlot)
            return
        end
        OneBank.visibleBags[button.bagID] = not (OneBank.visibleBags[button.bagID] ~= false)
        OneBank:SaveVisibleBagsState()
        OneBank:Refresh()
    end)
    btn:SetScript("OnDragStart", function(button)
        if button.invSlot then
            PickupBagFromSlot(button.invSlot)
        end
    end)
    btn:SetScript("OnReceiveDrag", function(button)
        if button.invSlot then
            PutItemInBag(button.invSlot)
        end
    end)
    self.bagButtons[index] = btn
    return btn
end

function OneBank:RefreshBagSlots()
    if not self.frame or not self.frame.BagSlots then
        return
    end
    if IsBankViewMode() or not self.showBagRail then
        self.frame.BagSlots:Hide()
        return
    end
    self.frame.BagSlots:Show()

    local size, spacing, pad = 34, 4, 6
    local position = NormalizeRailPosition(self.bagRailPosition, "top")
    local useVertical = position == "left" or position == "right"
    local purchasedSlots = GetNumBankSlots and (GetNumBankSlots() or 0) or 0
    PositionBankRail(self.frame, self.frame.BagSlots, position)
    for i, bagID in ipairs(BANK_BAG_SLOTS) do
        local button = self:AcquireBagButton(i)
        if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
            ns.ItemButtonStyle.Apply(button)
        end
        button:ClearAllPoints()
        if useVertical then
            button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad, -pad - (i - 1) * (size + spacing))
        else
            button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad + (i - 1) * (size + spacing), -pad)
        end
        button.bagID = bagID
        button.invSlot = BankBagToInventorySlotCompat(bagID)
        button.isPurchased = i <= purchasedSlots
        local isVisible = self.visibleBags[bagID] ~= false
        local icon
        if button.isPurchased then
            icon = button.invSlot and GetInventoryItemTexture("player", button.invSlot)
            button.icon:SetTexture(icon)
            button:SetAlpha(isVisible and 1 or 0.62)
            button._baseAlpha = isVisible and 1 or 0.62
            if button.UnpurchasedOverlay then
                button.UnpurchasedOverlay:Hide()
            end
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
        else
            button.icon:SetTexture(nil)
            button:SetAlpha(0.95)
            button._baseAlpha = 0.95
            if button.UnpurchasedOverlay then
                button.UnpurchasedOverlay:Show()
            end
            if button.StyleBorder then
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.56, 0.44, 0.14, 0.95
                button.StyleBorder:SetBackdropBorderColor(
                        button.StyleBorderBaseR,
                        button.StyleBorderBaseG,
                        button.StyleBorderBaseB,
                        button.StyleBorderBaseA
                )
            end
        end
        button:Show()
    end
    self.frame.BagSlots:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    self.frame.BagSlots:SetBackdropColor(0.08, 0.08, 0.08, 0.84)
    self.frame.BagSlots:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)
    if useVertical then
        self.frame.BagSlots:SetWidth(size + pad * 2)
        self.frame.BagSlots:SetHeight(pad * 2 + #BANK_BAG_SLOTS * size + (#BANK_BAG_SLOTS - 1) * spacing)
    else
        self.frame.BagSlots:SetWidth(pad * 2 + #BANK_BAG_SLOTS * size + (#BANK_BAG_SLOTS - 1) * spacing)
        self.frame.BagSlots:SetHeight(size + pad * 2)
    end
    ApplyWindowAppearance(self.frame, GetConfig())
end

function OneBank:SetBagSlotPreview(bagID)
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

function OneBank:GetBagSlotParent(bagID, parentContainer)
    if not self.frame then
        return parentContainer
    end
    parentContainer = parentContainer or self.frame.content
    self.frame.BagSlotParents = self.frame.BagSlotParents or {}
    local key = tostring(bagID) .. ":" .. tostring(parentContainer)
    local holder = self.frame.BagSlotParents[key]
    if holder then
        return holder
    end
    holder = CreateFrame("Frame", nil, parentContainer)
    holder:SetAllPoints(parentContainer)
    holder:SetID(bagID)
    holder.bagID = bagID
    holder.BagID = bagID
    holder:SetFrameLevel(parentContainer:GetFrameLevel())
    self.frame.BagSlotParents[key] = holder
    return holder
end

function OneBank:GetCategoryOverlay()
    if not self.frame or not self.frame.content then
        return nil
    end
    local overlay = self.frame.CategoryOverlay
    if not overlay then
        overlay = CreateFrame("Frame", nil, self.frame.content)
        overlay:EnableMouse(false)
        self.frame.CategoryOverlay = overlay
    end
    overlay:ClearAllPoints()
    overlay:SetAllPoints(self.frame.content)
    overlay:SetFrameLevel((self.frame.content:GetFrameLevel() or BANK_FRAME_LEVEL) + 60)
    return overlay
end

function OneBank:AcquireButton(index)
    local btn = self.buttons[index]
    if btn then
        return btn
    end

    local name = "LunaBagsBankItemButton" .. index
    btn = CreateFrame("ItemButton", name, self.frame.content, "ContainerFrameItemButtonTemplate")
    btn:SetSize(self.slotSize, self.slotSize)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)
    btn:SetScript("OnEnter", LunaBagsOneBank_ItemButtonOnEnter)
    btn:SetScript("OnLeave", LunaBagsOneBank_ItemButtonOnLeave)
    btn:HookScript("OnDragStart", function(button)
        TrackCategoryDragFromButton(OneBank, button)
    end)
    btn:SetScript("OnUpdate", nil)
    btn.GetInventorySlot = function(self)
        if IsBaseBankContainer(self.bagID) then
            return BankItemToInventorySlotCompat(self:GetID())
        end
        return nil
    end
    btn.UpdateTooltip = function(self)
        if not GameTooltip or not self or not ((self.bagID and self.slot) or (self.viewBagID and self.viewSlot)) then
            return
        end
        if not GameTooltip:IsOwned(self) then
            return
        end
        GameTooltip:ClearLines()
        if ShowLiveBankItemTooltip(self) then
            GameTooltip:Show()
        end
    end

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
    local includeFullDetails = (self.searchText and self.searchText ~= "") or IsVisualSortEnabled()
    local visibleKey = {}
    for _, bagID in ipairs(BANK_BAGS) do
        visibleKey[#visibleKey + 1] = tostring(bagID) .. "=" .. tostring(bagID == -1 or self.visibleBags[bagID] ~= false)
    end
    local cacheKey = table.concat(visibleKey, ";") .. "|view=" .. tostring(IsBankViewMode() and (self.viewCharacterKey or "cached") or "current")
    if self._slotCache
        and self._slotCacheDirty ~= true
        and self._slotCacheKey == cacheKey
        and (not includeFullDetails or self._slotCacheFullDetails == true)
    then
        return self._slotCache
    end

    local slots = {}
    if IsBankViewMode() then
        local character = GetViewedBankCharacterData()
        for _, bagID in ipairs(BANK_BAGS) do
            if bagID == -1 or self.visibleBags[bagID] ~= false then
                local bagData = GetCachedBankBagData(character, bagID)
                local slotCount = GetCachedBankSlotCount(bagData)
                for slot = 1, slotCount do
                    local item = GetCachedBankSlot(bagData, slot)
                    local itemLink = item and item.itemLink or nil
                    local itemID = item and (item.itemID or (itemLink and tonumber(itemLink:match("item:(%d+)")))) or nil
                    local itemName, itemQuality, itemLevel, itemTypeName, subTypeName, equipLoc, sellPrice, classID, subClassID = GetItemDetails(itemLink, itemID, includeFullDetails)
                    slots[#slots + 1] = {
                        bagID = bagID,
                        slot = slot,
                        item = item and {
                            iconFileID = item.iconFileID,
                            stackCount = item.stackCount,
                            quality = item.quality or itemQuality,
                            isQuestItem = item.isQuestItem,
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
        if IsVisualSortEnabled() and ns.Sorter and ns.Sorter.SortDisplayEntries then
            slots = ns.Sorter:SortDisplayEntries(slots)
        end
        self._slotCache = slots
        self._slotCacheKey = cacheKey
        self._slotCacheFullDetails = includeFullDetails == true
        self._slotCacheDirty = nil
        return slots
    end
    for _, bagID in ipairs(BANK_BAGS) do
        if bagID == -1 or self.visibleBags[bagID] ~= false then
            local slotCount = GetNumSlotsInBag(bagID)
            for slot = 1, slotCount do
                local itemInfo = GetItemInfoFromBag(bagID, slot)
                local itemLink = itemInfo and GetItemLinkFromBag(bagID, slot) or nil
                local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or (itemInfo and itemInfo.itemID) or nil
                local itemName, itemQuality, itemLevel, itemTypeName, subTypeName, equipLoc, sellPrice, classID, subClassID = GetItemDetails(itemLink, itemID, includeFullDetails)
                slots[#slots + 1] = {
                    bagID = bagID,
                    slot = slot,
                    item = itemInfo and {
                        iconFileID = itemInfo.iconFileID,
                        stackCount = itemInfo.stackCount,
                        quality = itemInfo.quality or itemQuality,
                        isQuestItem = GetQuestItemFlag(bagID, slot, itemInfo),
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
    if IsVisualSortEnabled() and ns.Sorter and ns.Sorter.SortDisplayEntries then
        slots = ns.Sorter:SortDisplayEntries(slots)
    end
    self._slotCache = slots
    self._slotCacheKey = cacheKey
    self._slotCacheFullDetails = includeFullDetails == true
    self._slotCacheDirty = nil
    return slots
end

function OneBank:InvalidateSlotCache()
    self._slotCacheDirty = true
    self._layoutModel = nil
    self._layoutModelKey = nil
end

local function GetBankSlotKey(bagID, slot)
    return tostring(bagID) .. ":" .. tostring(slot)
end

local function BuildCurrentOneBankSlotEntry(bagID, slot)
    local itemInfo = GetItemInfoFromBag(bagID, slot)
    local itemLink = itemInfo and GetItemLinkFromBag(bagID, slot) or nil
    local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or (itemInfo and itemInfo.itemID) or nil
    local includeFullDetails = OneBank.searchText and OneBank.searchText ~= ""
    local itemName, itemQuality, itemLevel, itemTypeName, subTypeName, equipLoc, sellPrice, classID, subClassID =
        GetItemDetails(itemLink, itemID, includeFullDetails)
    return {
        bagID = bagID,
        slot = slot,
        item = itemInfo and {
            iconFileID = itemInfo.iconFileID,
            stackCount = itemInfo.stackCount,
            quality = itemInfo.quality or itemQuality,
            isQuestItem = GetQuestItemFlag(bagID, slot, itemInfo),
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

local ONEBANK_BUTTONS_PER_FRAME = 18

local function StopOneBankButtonRenderJob(self)
    self._buttonRenderToken = (self._buttonRenderToken or 0) + 1
    self._buttonRenderJob = nil
    if self._buttonRenderFrame then
        self._buttonRenderFrame:SetScript("OnUpdate", nil)
    end
end

local function RenderOneBankPositionedButton(self, job, i)
    local pos = job.positioned[i]
    if not pos then
        return
    end

    local b = self:AcquireButton(i)
    b:SetSize(job.size, job.size)
    if (not job.layoutOnly) and ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
        ns.ItemButtonStyle.Apply(b)
         b._lunaBagsStyleDirty = true
    end
    local col = pos.col
    local row = pos.row
    local info = pos.entry
    local slotParent = self:GetBagSlotParent(info.bagID, self.frame.content)
    if slotParent and b:GetParent() ~= slotParent then
        b:SetParent(slotParent)
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", job.gridInsetX + col * (job.size + job.spacing), -job.gridInsetY - row * (job.size + job.spacing) - (pos.yOffset or 0))
    if job.layoutOnly then
        if ns.ItemButtonStyle and ns.ItemButtonStyle.ResetState then
            ns.ItemButtonStyle.ResetState(b)
        end
        b:Show()
        return
    end

    local isMatch = ItemMatchesSearch(info.item, self.searchText)
    local readOnly = job.readOnly
    b.viewBagID = info.bagID
    b.viewSlot = info.slot
    b.bagID = readOnly and nil or info.bagID
    b.slot = readOnly and nil or info.slot
    b.BagID = readOnly and nil or info.bagID
    b.SlotID = readOnly and nil or info.slot
    b.itemData = info.item
    b.category = pos.category
    b.readOnly = readOnly
    b:SetID(readOnly and 0 or info.slot)
    if readOnly then
        b:SetAttribute("type", nil)
        b:SetAttribute("bag", nil)
        b:SetAttribute("slot", nil)
    else
        b:SetAttribute("type", "item")
        b:SetAttribute("bag", info.bagID)
        b:SetAttribute("slot", info.slot)
    end
    if b.DebugSlotText and IsDebugEnabled() then
        b.DebugSlotText:SetText(("%d:%d"):format(tonumber(info.bagID) or -99, tonumber(info.slot) or -99))
        b.DebugSlotText:Show()
    elseif b.DebugSlotText then
        b.DebugSlotText:Hide()
    end

    local alpha = info.item and ((job.searching and not isMatch) and 0.22 or 1) or ((job.searching and not isMatch) and 0.18 or 0.55)
    local renderSignature = GetButtonRenderSignature(info, "oneBank", readOnly, alpha, self.sortingActive, job.pluginSignature)
    local visualDirty = b._lunaBagsRenderSignature ~= renderSignature

    if visualDirty then
        if info.item then
            if SetItemButtonTexture then
                SetItemButtonTexture(b, info.item.iconFileID)
            else
                b.icon:SetTexture(info.item.iconFileID)
            end
            if SetItemButtonCount then
                SetItemButtonCount(b, info.item.stackCount or 0)
                if ns.ItemButtonStyle and ns.ItemButtonStyle.ApplyTextStyle then
                    ns.ItemButtonStyle.ApplyTextStyle(b)
                end
            else
                b.count:SetText((info.item.stackCount or 0) > 1 and info.item.stackCount or "")
            end
            if SetItemButtonQuality then
                SetItemButtonQuality(b, info.item.quality, info.item.itemLink)
            end
            if readOnly then
                ClearItemCooldown(b)
            else
                UpdateItemCooldown(b, info.bagID, info.slot)
            end
        else
            if SetItemButtonTexture then
                SetItemButtonTexture(b, nil)
            else
                b.icon:SetTexture(nil)
            end
            if SetItemButtonCount then
                SetItemButtonCount(b, 0)
                if ns.ItemButtonStyle and ns.ItemButtonStyle.ApplyTextStyle then
                    ns.ItemButtonStyle.ApplyTextStyle(b)
                end
            else
                b.count:SetText("")
            end
            if SetItemButtonQuality then
                SetItemButtonQuality(b, nil)
            end
            ClearItemCooldown(b)
        end
        b._lunaBagsSortingDesaturated = self.sortingActive == true
        if b.icon and b.icon.SetDesaturated then
            b.icon:SetDesaturated(self.sortingActive == true)
        end
        b._lunaBagsRenderSignature = renderSignature
    end
    local pluginRenderSignature = renderSignature .. ":" .. tostring(job.pluginSignature or "")
    local pluginDirty = visualDirty or b._lunaBagsStyleDirty == true or b._lunaBagsPluginSignature ~= pluginRenderSignature
    if pluginDirty then
        UpdateButtonStyleBorderForItem(b, info.item)
        if ns.Plugins then
            ns.Plugins:Apply(b, info, "oneBank")
        end
        b._lunaBagsPluginSignature = pluginRenderSignature
        b._lunaBagsStyleDirty = nil
    end
    b:SetAlpha(alpha)
    b._baseAlpha = alpha
    b:EnableMouse(readOnly or not self.sortingActive)
    b:Show()
end

local function CleanupOneBankButtons(self, used)
    for i = used + 1, #self.buttons do
        self.buttons[i]._lunaBagsRenderSignature = nil
        self.buttons[i]._lunaBagsPluginSignature = nil
        self.buttons[i]._lunaBagsStyleDirty = nil
        self.buttons[i].readOnly = nil
        self.buttons[i].viewBagID = nil
        self.buttons[i].viewSlot = nil
        if self.buttons[i].DebugSlotText then
            self.buttons[i].DebugSlotText:Hide()
        end
        self.buttons[i]:Hide()
    end
end

local function StartOneBankButtonRenderJob(self, job)
    StopOneBankButtonRenderJob(self)
    self._buttonRenderToken = (self._buttonRenderToken or 0) + 1
    job.token = self._buttonRenderToken
    job.index = 1
    self._buttonRenderJob = job

    local function process(limit)
        local processed = 0
        while job.index <= job.used and processed < limit do
            RenderOneBankPositionedButton(self, job, job.index)
            job.index = job.index + 1
            processed = processed + 1
        end
        if job.index > job.used then
            self._buttonRenderJob = nil
            if self._buttonRenderFrame then
                self._buttonRenderFrame:SetScript("OnUpdate", nil)
            end
        end
    end

    if job.layoutOnly or not CreateFrame then
        process(job.used)
        return
    end

    if not self._buttonRenderFrame then
        self._buttonRenderFrame = CreateFrame("Frame")
    end
    process(math.min(job.used, ONEBANK_BUTTONS_PER_FRAME))
    if job.index <= job.used then
        self._buttonRenderFrame:SetScript("OnUpdate", function(frame)
            if not self._buttonRenderJob or self._buttonRenderJob.token ~= job.token or not self.frame or not self.frame:IsShown() then
                self._buttonRenderJob = nil
                frame:SetScript("OnUpdate", nil)
                return
            end
            process(ONEBANK_BUTTONS_PER_FRAME)
        end)
    end
end

local function BuildBankPositionedSlotIndex(positioned)
    local index = {}
    for i, p in ipairs(positioned or {}) do
        local entry = p and p.entry
        if entry and entry.bagID ~= nil and entry.slot ~= nil then
            index[GetBankSlotKey(entry.bagID, entry.slot)] = i
        end
    end
    return index
end

local function HasBankDirtySlot(dirtySlots)
    if type(dirtySlots) ~= "table" then
        return false
    end
    for _, slots in pairs(dirtySlots) do
        if slots == true then
            return true
        end
        if type(slots) == "table" then
            for _ in pairs(slots) do
                return true
            end
        end
    end
    return false
end

function OneBank:CanRefreshItemsOnly()
    if not self.frame or not self.frame:IsShown() or IsBankViewMode() then
        return false
    end
    if IsVisualSortEnabled() then
        return false
    end
    if ns.Categories and ns.Categories.HasActiveCategories and ns.Categories:HasActiveCategories("bank") then
        return false
    end
    return self._lastButtonRenderTemplate and self._lastButtonRenderTemplate.positioned and self._lastButtonRenderTemplate.slotIndex
end

function OneBank:RefreshItemsOnly(dirtySlots)
    if not self:CanRefreshItemsOnly() or not HasBankDirtySlot(dirtySlots) then
        return false
    end

    local previous = self._lastButtonRenderTemplate
    local positioned = previous.positioned
    local slotIndex = previous.slotIndex
    local changedIndexes = {}

    for rawBagID, slots in pairs(dirtySlots) do
        local bagID = tonumber(rawBagID) or rawBagID
        if (bagID == -1 or (type(bagID) == "number" and bagID >= 5 and bagID <= 11)) and (bagID == -1 or self.visibleBags[bagID] ~= false) then
            if slots == true then
                local slotCount = GetNumSlotsInBag(bagID)
                local mappedSlots = 0
                for slot = 1, slotCount do
                    if slotIndex[GetBankSlotKey(bagID, slot)] then
                        mappedSlots = mappedSlots + 1
                    end
                end
                if mappedSlots ~= slotCount then
                    return false
                end
                for slot = 1, slotCount do
                    local index = slotIndex[GetBankSlotKey(bagID, slot)]
                    if index and positioned[index] then
                        positioned[index].entry = BuildCurrentOneBankSlotEntry(bagID, slot)
                        changedIndexes[#changedIndexes + 1] = index
                    end
                end
            elseif type(slots) == "table" then
                for rawSlot in pairs(slots) do
                    local slot = tonumber(rawSlot) or rawSlot
                    local index = slotIndex[GetBankSlotKey(bagID, slot)]
                    if index and positioned[index] then
                        positioned[index].entry = BuildCurrentOneBankSlotEntry(bagID, slot)
                        changedIndexes[#changedIndexes + 1] = index
                    end
                end
            end
        end
    end

    if #changedIndexes == 0 then
        return false
    end

    table.sort(changedIndexes)
    local currentSlots = {}
    for _, p in ipairs(positioned) do
        currentSlots[#currentSlots + 1] = p.entry
    end
    local occupiedSlots, totalSlots = CountSlotUsage(currentSlots)
    if self.frame.MoneyBar and self.frame.MoneyBar.Label then
        self.frame.MoneyBar.Label:SetText(FormatSlotUsageText(occupiedSlots, totalSlots))
    end
    if self.frame.MoneyBar and self.frame.MoneyBar.Text then
        self.frame.MoneyBar.Text:SetText(FormatMoneyText(GetMoney and GetMoney() or 0, 14))
    end

    local job = {
        positioned = positioned,
        used = #positioned,
        size = previous.size,
        spacing = previous.spacing,
        gridInsetX = previous.gridInsetX,
        gridInsetY = previous.gridInsetY,
        layoutOnly = false,
        readOnly = false,
        searching = self.searchText and self.searchText ~= "",
        pluginSignature = GetPluginRenderSignature(),
        indexes = changedIndexes,
    }

    StopOneBankButtonRenderJob(self)
    self._buttonRenderToken = (self._buttonRenderToken or 0) + 1
    job.token = self._buttonRenderToken
    job.index = 1
    self._buttonRenderJob = job

    local function process(limit)
        local processed = 0
        while job.index <= #job.indexes and processed < limit do
            RenderOneBankPositionedButton(self, job, job.indexes[job.index])
            job.index = job.index + 1
            processed = processed + 1
        end
        if job.index > #job.indexes then
            self._buttonRenderJob = nil
            if self._buttonRenderFrame then
                self._buttonRenderFrame:SetScript("OnUpdate", nil)
            end
        end
    end

    if not self._buttonRenderFrame then
        self._buttonRenderFrame = CreateFrame("Frame")
    end
    process(math.min(#job.indexes, ONEBANK_BUTTONS_PER_FRAME))
    if job.index <= #job.indexes then
        self._buttonRenderFrame:SetScript("OnUpdate", function(frame)
            if not self._buttonRenderJob or self._buttonRenderJob.token ~= job.token or not self.frame or not self.frame:IsShown() then
                self._buttonRenderJob = nil
                frame:SetScript("OnUpdate", nil)
                return
            end
            process(ONEBANK_BUTTONS_PER_FRAME)
        end)
    end

    self._slotCacheDirty = true
    return true
end

function OneBank:RefreshCooldowns()
    if not self.frame or not self.frame:IsShown() or IsBankViewMode() then
        return false
    end

    local refreshed = false
    for i = 1, #self.buttons do
        local button = self.buttons[i]
        if button and button:IsShown() then
            if button.readOnly or not button.bagID or not button.slot then
                ClearItemCooldown(button)
            else
                UpdateItemCooldown(button, button.bagID, button.slot)
                button._lunaBagsRenderSignature = nil
                refreshed = true
            end
        end
    end
    return refreshed
end

function OneBank:Refresh(layoutOnly)
    if not self.frame then
        return
    end
    layoutOnly = layoutOnly == true
    EnsureVisibleBankBagDefaults(self.visibleBags)
    self:UpdateSearchLayout()
    if not layoutOnly then
        self:RefreshBagSlots()
    end

    local cols = self.columns
    local size = self.slotSize
    local spacing = self.spacing
    local gridWidth = cols * size + ((cols - 1) * spacing)
    local gridInsetX = spacing
    local gridInsetY = spacing
    local framePaddingX = BANK_FRAME_PADDING_X
    local contentTopInset = self.searchVisible and 34 or 12
    local frameVerticalChrome = 79 + contentTopInset

    local desiredContentWidth = gridWidth + (gridInsetX * 2)
    local frameWidth = math.max(desiredContentWidth + framePaddingX, tonumber(self.windowWidth) or 0)
    self.frame:SetSize(frameWidth, self.frame:GetHeight())
    local actualContentWidth = self.frame.ScrollFrame and self.frame.ScrollFrame:GetWidth() or (self.frame.content and self.frame.content:GetWidth()) or desiredContentWidth
    gridInsetX = math.max(spacing, math.floor((actualContentWidth - gridWidth) * 0.5))

    local categoryConfig = GetBankCategoryConfig()
    local layoutKey = table.concat({
        GetBankSplitLayoutKey(),
        GetBankCategoryLayoutKey(categoryConfig),
        tostring(self.columns or ""),
        tostring(self.slotSize or ""),
        tostring(self.spacing or ""),
        tostring(IsVisualSortEnabled() == true),
    }, ":")
    local searching = self.searchText and self.searchText ~= ""
    local cachedLayout = (layoutOnly and not IsVisualSortEnabled() and self._layoutModelKey == layoutKey) and self._layoutModel or nil
    local all = cachedLayout and cachedLayout.all or self:BuildLiveSlots()
    local occupiedSlots = cachedLayout and cachedLayout.occupiedSlots or nil
    local totalSlots = cachedLayout and cachedLayout.totalSlots or nil
    if not occupiedSlots or not totalSlots then
        occupiedSlots, totalSlots = CountSlotUsage(all)
    end
    local positioned = {}
    local sectionHeaders = {}
    local sectionEmptyLabels = {}
    local sectionPlaceholders = {}
    local sectionDropTargets = {}

    local activeCategories = GetBankActiveCategories(categoryConfig)
    local categoriesEnabled = #activeCategories > 0
    local categoryColumnCount = math.max(1, math.min(tonumber(categoryConfig and categoryConfig.columns) or 1, cols))
    local categoryLayoutMode = (categoryConfig and categoryConfig.layout == "fixed") and "fixed" or "masonry"
    local visualSortEnabled = IsVisualSortEnabled()
    local sectionHeaderHeight = 14
    local sectionGapY = math.max(spacing * 2, spacing + 6)
    local uncategorized = cachedLayout and cachedLayout.uncategorized or {}
    local splitSections = cachedLayout and cachedLayout.splitSections or {}
    local categorySections = cachedLayout and cachedLayout.categorySections or {}
    local categoryByID = {}

    if (not cachedLayout) and categoriesEnabled then
        for index, category in ipairs(activeCategories) do
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
        local splitByBag = {}
        for _, entry in ipairs(all) do
            local category = categoriesEnabled and MatchBankCategory(entry.item, categoryConfig) or nil
            if category then
                local key = category.id or category.name
                local section = key and categoryByID[key] or nil
                if section then
                    section.entries[#section.entries + 1] = entry
                else
                    uncategorized[#uncategorized + 1] = entry
                end
            elseif IsBankBagSplitEnabled(entry.bagID) then
                splitByBag[entry.bagID] = splitByBag[entry.bagID] or {}
                splitByBag[entry.bagID][#splitByBag[entry.bagID] + 1] = entry
            else
                uncategorized[#uncategorized + 1] = entry
            end
        end
        for index, bagID in ipairs(BANK_BAG_SLOTS) do
            local entries = splitByBag[bagID]
            if entries and #entries > 0 then
                splitSections[#splitSections + 1] = {
                    title = string.format("%s %d", BANK_BAG or "Bank Bag", index),
                    entries = entries,
                }
            end
        end

        self._layoutModel = {
            all = all,
            occupiedSlots = occupiedSlots,
            totalSlots = totalSlots,
            uncategorized = uncategorized,
            splitSections = splitSections,
            categorySections = categorySections,
        }
        self._layoutModelKey = layoutKey
    elseif not cachedLayout then
        local splitByBag = {}
        for _, entry in ipairs(all) do
            local category = categoriesEnabled and MatchBankCategory(entry.item, categoryConfig) or nil
            if category then
                local key = category.id or category.name
                local section = key and categoryByID[key] or nil
                if section then
                    section.entries[#section.entries + 1] = entry
                else
                    uncategorized[#uncategorized + 1] = entry
                end
            elseif IsBankBagSplitEnabled(entry.bagID) then
                splitByBag[entry.bagID] = splitByBag[entry.bagID] or {}
                splitByBag[entry.bagID][#splitByBag[entry.bagID] + 1] = entry
            else
                uncategorized[#uncategorized + 1] = entry
            end
        end
        for index, bagID in ipairs(BANK_BAG_SLOTS) do
            local entries = splitByBag[bagID]
            if entries and #entries > 0 then
                splitSections[#splitSections + 1] = {
                    title = string.format("%s %d", BANK_BAG or "Bank Bag", index),
                    entries = entries,
                }
            end
        end

        self._layoutModel = {
            all = all,
            occupiedSlots = occupiedSlots,
            totalSlots = totalSlots,
            uncategorized = uncategorized,
            splitSections = splitSections,
            categorySections = categorySections,
        }
        self._layoutModelKey = layoutKey
    end

local currentRow = 0
local extraYOffset = 0
local hasContent = false
local function AddSection(title, entries)
    if not entries or #entries == 0 then
        return
    end
    if hasContent then
        extraYOffset = extraYOffset + sectionGapY
    end
    if title and title ~= "" then
        sectionHeaders[#sectionHeaders + 1] = {
            title = title,
            row = currentRow,
            yOffset = extraYOffset,
        }
        extraYOffset = extraYOffset + sectionHeaderHeight
    end
    for idx, entry in ipairs(entries) do
        local zero = idx - 1
        positioned[#positioned + 1] = {
            entry = entry,
            col = zero % cols,
            row = currentRow + math.floor(zero / cols),
            yOffset = extraYOffset,
        }
    end
    local rowsUsed = math.max(1, math.ceil(#entries / cols))
    currentRow = currentRow + rowsUsed
    hasContent = true
end

local function AddCategoryGrid(sections)
    if #sections == 0 then
        return
    end
    if hasContent then
        extraYOffset = extraYOffset + sectionGapY
    end

    local desiredGridGapCols = 2
    local gridGapCols = 0
    if categoryColumnCount > 1 then
        local minColsWithDesiredGap = categoryColumnCount + ((categoryColumnCount - 1) * desiredGridGapCols)
        if minColsWithDesiredGap <= cols then
            gridGapCols = desiredGridGapCols
        elseif (categoryColumnCount * 2 - 1) <= cols then
            gridGapCols = 1
        end
    end
    local defaultSectionCols = math.max(1, math.floor((cols - ((categoryColumnCount - 1) * gridGapCols)) / categoryColumnCount))
    local columnHeights = {}
    local layouts = {}
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
                fixedTopOffset = fixedTopOffset + fixedRowHeight + sectionGapY
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
                topOffset = topOffset + sectionGapY
            end
            for col = startCol, startCol + sectionCols - 1 do
                columnHeights[col] = topOffset + sectionHeight
            end
        end
        layouts[#layouts + 1] = {
            section = section,
            startCol = startCol,
            topOffset = topOffset,
            sectionCols = sectionCols,
            entries = entries,
            visibleSlots = visibleSlots,
        }
    end

    for _, layout in ipairs(layouts) do
        local section = layout.section
        local entries = layout.entries
        local startCol = layout.startCol
        local visibleSlots = layout.visibleSlots
        local sectionCols = layout.sectionCols
        local startRow = currentRow
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
            local zero = idx - 1
            positioned[#positioned + 1] = {
                entry = entry,
                col = startCol + (zero % sectionCols),
                row = startRow + math.floor(zero / sectionCols),
                yOffset = headerOffset,
                category = section.category,
            }
        end
        for idx = #entries + 1, visibleSlots do
            local zero = idx - 1
            sectionPlaceholders[#sectionPlaceholders + 1] = {
                col = startCol + (zero % sectionCols),
                row = startRow + math.floor(zero / sectionCols),
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
    hasContent = true
end

    if categoriesEnabled then
        AddSection("Uncategorized", uncategorized)
        for _, section in ipairs(splitSections) do
            AddSection(section.title, section.entries)
        end
        AddCategoryGrid(categorySections)
    else
        AddSection(nil, uncategorized)
        for _, section in ipairs(splitSections) do
            AddSection(section.title, section.entries)
        end
    end

    local used = #positioned
    local maxBottom = 0
    local pluginSignature = GetPluginRenderSignature()
    for i = 1, used do
        local pos = positioned[i]
        local row = pos.row or 0
        local bottom = gridInsetY + row * (size + spacing) + (pos.yOffset or 0) + size
        if bottom > maxBottom then
            maxBottom = bottom
        end
    end
    CleanupOneBankButtons(self, used)
    local renderJob = {
        positioned = positioned,
        used = used,
        size = size,
        spacing = spacing,
        gridInsetX = gridInsetX,
        gridInsetY = gridInsetY,
        layoutOnly = layoutOnly,
        readOnly = IsBankViewMode(),
        searching = searching,
        pluginSignature = pluginSignature,
        allSlots = all,
        slotIndex = BuildBankPositionedSlotIndex(positioned),
    }
    self._lastButtonRenderTemplate = renderJob
    StartOneBankButtonRenderJob(self, renderJob)

    local placeholders = self.frame.content and self.frame.content.BankCategoryPlaceholders or {}
    for i, placeholder in ipairs(sectionPlaceholders) do
        local frame = EnsureBankPlaceholder(self.frame.content, i)
        frame:SetSize(size, size)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + (placeholder.col or 0) * (size + spacing), -gridInsetY - (placeholder.row or 0) * (size + spacing) - (placeholder.yOffset or 0))
        ConfigureCategoryPlaceholder(frame, self, placeholder.category)
        frame:Show()
        local bottom = gridInsetY + (placeholder.row or 0) * (size + spacing) + (placeholder.yOffset or 0) + size
        if bottom > maxBottom then
            maxBottom = bottom
        end
    end
    for i = #sectionPlaceholders + 1, #placeholders do
        ConfigureCategoryPlaceholder(placeholders[i], self, nil)
        placeholders[i]:Hide()
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
        frame:SetFrameLevel((self.frame.content and self.frame.content:GetFrameLevel() or BANK_FRAME_LEVEL) + 90)
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

    local categoryOverlay = self:GetCategoryOverlay() or self.frame.content
    self.sectionHeaders = self.sectionHeaders or {}
    for i, header in ipairs(sectionHeaders) do
        local fs = self.sectionHeaders[i]
        if not fs then
            fs = categoryOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetJustifyH("LEFT")
            self.sectionHeaders[i] = fs
        end
        if fs.GetParent and fs.SetParent and fs:GetParent() ~= categoryOverlay then
            fs:SetParent(categoryOverlay)
        end
        fs:SetText(header.title)
        fs:SetWidth(((header.cols or cols) * size) + math.max(0, (header.cols or cols) - 1) * spacing)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", categoryOverlay, "TOPLEFT", gridInsetX + (header.col or 0) * (size + spacing), -gridInsetY - (header.row or 0) * (size + spacing) - (header.yOffset or 0))
        fs:Show()
    end
    for i = #sectionHeaders + 1, #(self.sectionHeaders or {}) do
        self.sectionHeaders[i]:Hide()
    end

    self.sectionEmptyLabels = self.sectionEmptyLabels or {}
    for i, label in ipairs(sectionEmptyLabels) do
        local fs = self.sectionEmptyLabels[i]
        if not fs then
            fs = categoryOverlay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            self.sectionEmptyLabels[i] = fs
        end
        if fs.GetParent and fs.SetParent and fs:GetParent() ~= categoryOverlay then
            fs:SetParent(categoryOverlay)
        end
        fs:SetText(label.text or "")
        fs:SetWidth(((label.cols or cols) * size) + math.max(0, (label.cols or cols) - 1) * spacing)
        fs:SetHeight(size)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", categoryOverlay, "TOPLEFT", gridInsetX + (label.col or 0) * (size + spacing), -gridInsetY - (label.row or 0) * (size + spacing) - (label.yOffset or 0))
        fs:Show()
        local bottom = gridInsetY + (label.row or 0) * (size + spacing) + (label.yOffset or 0) + size
        if bottom > maxBottom then
            maxBottom = bottom
        end
    end
    for i = #sectionEmptyLabels + 1, #(self.sectionEmptyLabels or {}) do
        self.sectionEmptyLabels[i]:Hide()
    end

    if maxBottom <= 0 then
        maxBottom = gridInsetY + size
    end
    local contentHeight = maxBottom + gridInsetY
    local naturalFrameHeight = contentHeight + frameVerticalChrome
    local frameHeight = math.max(260, math.min(tonumber(self.maxHeight) or BANK_DEFAULT_MAX_HEIGHT, naturalFrameHeight))
    self.frame:SetSize(frameWidth, frameHeight)
    self:UpdateScrollFrame(contentHeight, math.max(1, frameHeight - frameVerticalChrome))

    if self.frame.MoneyBar and self.frame.MoneyBar.Text then
        if self.frame.MoneyBar.Label then
            self.frame.MoneyBar.Label:SetText(FormatSlotUsageText(occupiedSlots, totalSlots))
        end
        self.frame.MoneyBar.Text:SetText(FormatMoneyText(GetMoney and GetMoney() or 0, 14))
    end
end

function OneBank:SetSortingState(active)
    self.sortingActive = (active == true)
    if self.frame and self.frame.SortButton then
        self.frame.SortButton:EnableMouse(not self.sortingActive)
        self.frame.SortButton:SetAlpha(self.sortingActive and 0.5 or 1)
    end
end

function OneBank:RefreshDeferred(layoutOnly)
    if not self.frame then
        return
    end
    self._refreshDeferredToken = (self._refreshDeferredToken or 0) + 1
    local token = self._refreshDeferredToken
    if layoutOnly ~= true then
        self._refreshDeferredNeedsFull = true
    end
    local function run()
        if token ~= OneBank._refreshDeferredToken or not OneBank.frame or not OneBank.frame:IsShown() then
            return
        end
        local full = OneBank._refreshDeferredNeedsFull == true
        OneBank._refreshDeferredNeedsFull = nil
        OneBank:Refresh(not full)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

function OneBank:SavePosition()
    local cfg = GetConfig()
    if not cfg or not self.frame then
        return
    end
    local point, _, _, x, y = self.frame:GetPoint(1)
    cfg.point = point or "BOTTOMLEFT"
    cfg.x = x or 34
    cfg.y = y or 126
end

function OneBank:SaveWindowWidth(width)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    width = math.max(320, math.min(1100, math.floor((tonumber(width) or self.windowWidth or 590) + 0.5)))
    cfg.windowWidth = width
    cfg._windowWidthMigrated = true
    self.windowWidth = width
end

function OneBank:StartResize(side)
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
                OneBank:StopResize()
                return
            end
            local cursorX = GetCursorPosition()
            local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            local scaledCursorX = cursorX / scale
            local rawWidth
            if OneBank._resizeSide == "left" then
                rawWidth = (OneBank._resizeRight or scaledCursorX) - scaledCursorX
            else
                rawWidth = scaledCursorX - (OneBank._resizeLeft or 0)
            end
            local width = math.max(320, math.min(1100, math.floor(rawWidth + 0.5)))
            if width ~= OneBank.windowWidth then
                OneBank.windowWidth = width
                if OneBank.frame.SetWidth then
                    OneBank.frame:SetWidth(width)
                else
                    OneBank.frame:SetSize(width, OneBank.frame:GetHeight())
                end
                local newColumns = CalculateColumnsFromWindowWidth(OneBank.windowWidth, OneBank.slotSize, OneBank.spacing)
                if newColumns ~= OneBank.columns then
                    OneBank.columns = newColumns
                    OneBank:Refresh(true)
                else
                    OneBank:UpdateScrollFrame(OneBank._scrollContentHeight or 1, OneBank._scrollViewportHeight or 1)
                end
            end
        end)
    end
end

function OneBank:StopResize()
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

function OneBank:SaveVisibleBagsState()
    local cfg = GetConfig()
    if not cfg then
        return
    end
    cfg.visibleBags = CopyVisibleBankBagsState(self.visibleBags)
end

function OneBank:ApplySettings()
    local cfg = GetConfig()
    if not cfg or not self.frame then
        return
    end
    self.slotSize = math.max(24, math.min(48, tonumber(cfg.itemSize) or 36))
    self.spacing = math.max(0, math.min(12, tonumber(cfg.spacing) or 4))
    if cfg._windowWidthMigrated ~= true then
        cfg.windowWidth = CalculateWindowWidthFromColumns(tonumber(cfg.columns) or 14, self.slotSize, self.spacing)
        cfg._windowWidthMigrated = true
    end
    local fallbackWidth = CalculateWindowWidthFromColumns(tonumber(cfg.columns) or 14, self.slotSize, self.spacing)
    self.windowWidth = math.max(260, math.min(1400, tonumber(cfg.windowWidth) or fallbackWidth))
    self.maxHeight = math.max(260, math.min(1200, tonumber(cfg.windowMaxHeight) or BANK_DEFAULT_MAX_HEIGHT))
    self.columns = CalculateColumnsFromWindowWidth(self.windowWidth, self.slotSize, self.spacing)
    self.showBagRail = cfg.showBagRail ~= false
    self.bagRailPosition = NormalizeRailPosition(cfg.bagRailPosition, "top")
    self.visibleBags = CopyVisibleBankBagsState(cfg.visibleBags)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(cfg.point or "BOTTOMLEFT", UIParent, cfg.point or "BOTTOMLEFT", cfg.x or 34, cfg.y or 126)
    self.frame:SetScale(math.max(0.7, math.min(1.5, tonumber(cfg.scale) or 1)))
    self.frame:SetMovable(not cfg.locked)
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
        if self.frame.CustomTitle then
            local bankTitle = BANK or "Bank"
            if IsBankViewMode() then
                local character = GetViewedBankCharacterData()
                local name = character and character.name or UnitName("player") or "Player"
                bankTitle = ("%s - %s"):format(name, bankTitle)
            end
            self.frame.CustomTitle:SetText(bankTitle)
        end
        if self.frame.RailToggleButton then
            self.frame.RailToggleButton:SetShown(not IsBankViewMode())
            self.frame.RailToggleButton:SetAlpha(self.showBagRail and 1 or 0.6)
        end
        if self.frame.CharacterButton and self.frame.CharacterButton.Icon then
            local classToken = select(2, UnitClass("player"))
            if self.viewMode and self.viewCharacterKey and ns.BagData then
                local viewed = GetViewedBankCharacterData()
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
    self:UpdateSearchLayout()
end

function OneBank:ResetPosition()
    local cfg = GetConfig()
    if not cfg then
        return
    end
    cfg.point = "BOTTOMLEFT"
    cfg.x = 34
    cfg.y = 126
    self:ApplySettings()
end

function OneBank:Show()
    if ns.LunaBags and ns.LunaBags.IsWindowModuleEnabled and not ns.LunaBags:IsWindowModuleEnabled("oneBank") then
        return
    end
    self.viewMode = false
    self.viewCharacterKey = nil
    if ns.LunaBags and ns.LunaBags.RestoreCurrentCharacterProfile then
        ns.LunaBags:RestoreCurrentCharacterProfile()
    end
    self:CreateFrame()
    self:ApplySettings()
    EnsureStackSplitFrameAboveBank()
    self.frame:Show()
    if ns.LunaBags and ns.LunaBags.QueueOpenWindowRefresh then
        ns.LunaBags:QueueOpenWindowRefresh()
    elseif self.RefreshDeferred then
        self:RefreshDeferred()
    else
        self:Refresh()
    end
end

function OneBank:OpenViewMode(characterKey)
    if ns.LunaBags and ns.LunaBags.IsWindowModuleEnabled and not ns.LunaBags:IsWindowModuleEnabled("oneBank") then
        return
    end
    local currentKey = GetCurrentCharacterKey()
    if not characterKey or characterKey == "" then
        characterKey = currentKey
    end

    if NormalizeCharacterKey(characterKey) == NormalizeCharacterKey(currentKey) then
        self.viewMode = true
        self.viewCharacterKey = currentKey
    else
        local resolvedKey = characterKey
        if ns.BagData and ns.BagData.GetCharacterData then
            local data = ns.BagData:GetCharacterData(characterKey)
            if data and data.name and data.realm then
                resolvedKey = data.name .. "-" .. data.realm
            end
        end
        self.viewMode = true
        self.viewCharacterKey = resolvedKey
    end
    self:InvalidateSlotCache()
    self:CreateFrame()
    self:ApplySettings()
    EnsureStackSplitFrameAboveBank()
    self.frame:Show()
    self:RefreshDeferred()
end

function OneBank:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function LunaBagsOneBank_Close()
    if ns.OneBank and ns.OneBank.viewMode then
        ns.OneBank:Hide()
        return
    end
    if CloseBankFrame then
        CloseBankFrame()
        return
    end
    if ns.OneBank then
        ns.OneBank:Hide()
    end
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
        OneBank.searchText = ""
        if OneBank.frame.SearchEditBox:GetText() ~= "" then
            OneBank.frame.SearchEditBox:SetText("")
        end
    end
    OneBank:Refresh()
end

function LunaBagsOneBank_SortClicked()
    if IsBankViewMode() then
        OneBank:InvalidateSlotCache()
        OneBank:Refresh()
        return
    end
    if IsVisualSortEnabled() then
        if ns.Sorter and ns.Sorter.RestackSpecificBags then
            ns.Sorter:RestackSpecificBags(BANK_BAGS, {
                onStart = function()
                    OneBank:SetSortingState(true)
                end,
                onStop = function()
                    OneBank:SetSortingState(false)
                    OneBank:InvalidateSlotCache()
                    OneBank:Refresh()
                end,
            })
        else
            OneBank:InvalidateSlotCache()
            OneBank:Refresh()
        end
        return
    end
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
                func = function()
                    LunaBagsOneBank_SortClicked()
                end,
                notCheckable = true,
            },
            {
                text = SETTINGS or "Settings",
                func = function()
                    if ns.OpenConfig then
                        ns.OpenConfig()
                    end
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
                if level ~= 1 then
                    return
                end
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
    if ns.OneBag then
        ns.OneBag.hoveredItemID = nil
        ns.OneBag.hoveredButton = button
    end
    GameTooltip:ClearAllPoints()
    if button:GetRight() and button:GetRight() > (GetScreenWidth() * 0.5) then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    end
    if (button.bagID and button.slot) or (button.viewBagID and button.viewSlot) then
        if button.UpdateTooltip then
            button:UpdateTooltip()
        end
        if ns.OneBag and not ns.OneBag.hoveredItemID then
            local _, link = GameTooltip:GetItem()
            if link then
                ns.OneBag.hoveredItemID = tonumber(link:match("item:(%d+)"))
            end
        end
        GameTooltip:Show()
    end
end

function LunaBagsOneBank_ItemButtonOnLeave()
    if ns.OneBag then
        ns.OneBag.hoveredItemID = nil
        ns.OneBag.hoveredButton = nil
    end
    GameTooltip:Hide()
end
