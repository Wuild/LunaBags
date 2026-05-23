local _, ns = ...

local OneBank = {
    frame = nil,
    buttons = {},
    bagButtons = {},
    columns = 14,
    slotSize = 36,
    spacing = 4,
    searchText = "",
    searchVisible = false,
    showBagRail = true,
    visibleBags = {},
    sortingActive = false,
    _closingBankFrame = false,
}

ns.OneBank = OneBank

local BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }
local BANK_BAG_SLOTS = { 5, 6, 7, 8, 9, 10, 11 }
local BANK_FRAME_STRATA = "DIALOG"
local BANK_FRAME_LEVEL = 40

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

local function GetConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.oneBank = addon.db.profile.oneBank or {}
    addon.db.profile.oneBank.perCharacter = addon.db.profile.oneBank.perCharacter or {}
    local key = GetCurrentCharacterKey()
    local perChar = addon.db.profile.oneBank.perCharacter[key] or {}
    addon.db.profile.oneBank.perCharacter[key] = perChar
    perChar.splitBags = perChar.splitBags or {}
    perChar.visibleBags = perChar.visibleBags or {}

    if addon.db.profile.oneBank._viewOptionsPerCharMigrated ~= true then
        if type(addon.db.profile.oneBank.splitBags) == "table" then
            for bagID, enabled in pairs(addon.db.profile.oneBank.splitBags) do
                if perChar.splitBags[bagID] == nil then
                    perChar.splitBags[bagID] = enabled == true or nil
                end
            end
        end
        if type(addon.db.profile.oneBank.visibleBags) == "table" then
            for bagID, enabled in pairs(addon.db.profile.oneBank.visibleBags) do
                if perChar.visibleBags[bagID] == nil then
                    perChar.visibleBags[bagID] = enabled ~= false
                end
            end
        end
        addon.db.profile.oneBank._viewOptionsPerCharMigrated = true
    end

    addon.db.profile.oneBank._activeCharacter = key
    addon.db.profile.oneBank._activeCharacterData = perChar
    return addon.db.profile.oneBank
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
    local perChar = cfg._activeCharacterData or {}
    perChar.splitBags = perChar.splitBags or {}
    return perChar.splitBags[bagID] == true
end

local function SetBankBagSplitEnabled(bagID, enabled)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    local perChar = cfg._activeCharacterData or {}
    perChar.splitBags = perChar.splitBags or {}
    perChar.splitBags[bagID] = enabled == true or nil
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
    if not button or not button.bagID or not button.slot then
        return false
    end

    if IsBaseBankContainer(button.bagID) then
        if BankFrameItemButton_OnEnter then
            BankFrameItemButton_OnEnter(button)
            return true
        end

        local invSlot = BankItemToInventorySlotCompat(button.slot)
        if invSlot and GameTooltip:SetInventoryItem("player", invSlot) then
            return true
        end
    elseif ContainerFrameItemButton_OnEnter then
        ContainerFrameItemButton_OnEnter(button)
        return true
    end

    local ok = GameTooltip:SetBagItem(button.bagID, button.slot)
    if ok then
        return true
    end

    local link = (button.itemData and button.itemData.itemLink) or GetItemLinkFromBag(button.bagID, button.slot)
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
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
            self.StyleBorder:SetBackdropBorderColor(
                self.StyleBorderBaseR or 0.34,
                self.StyleBorderBaseG or 0.34,
                self.StyleBorderBaseB or 0.34,
                self.StyleBorderBaseA or 0.95
            )
            if self.StyleGlow then self.StyleGlow:Hide() end
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
    if button.IconBorder then button.IconBorder:SetAlpha(0); button.IconBorder:Hide() end
    if button.Background then button.Background:SetTexture(nil); button.Background:Hide() end
    if button.IconOverlay then button.IconOverlay:SetTexture(nil); button.IconOverlay:Hide() end
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

    -- Do not register as a generic special frame; bank open/close should be
    -- driven only by Blizzard bank flow (CloseBankFrame/BANKFRAME_* events).

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
    frame.RailToggleButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle Bank Bag Rail")
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
        if ns.OpenConfig then ns.OpenConfig() end
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
    ApplyBankFrameLayering(frame)

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
                    checked = function() return canSplit and IsBankBagSplitEnabled(bagID) end,
                    disabled = not canSplit,
                    func = function()
                        if not canSplit then return end
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
        if not button.invSlot then return end
        if CursorHasItem() then
            PutItemInBag(button.invSlot)
            return
        end
        OneBank.visibleBags[button.bagID] = not (OneBank.visibleBags[button.bagID] ~= false)
        OneBank:SaveVisibleBagsState()
        OneBank:Refresh()
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
        if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
            ns.ItemButtonStyle.Apply(button)
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad + (i - 1) * (size + spacing), -pad)
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
    self.frame.BagSlots:SetWidth(pad * 2 + #BANK_BAG_SLOTS * size + (#BANK_BAG_SLOTS - 1) * spacing)
    self.frame.BagSlots:SetHeight(size + pad * 2)
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
    if btn then return btn end

    local name = "LunaBagsBankItemButton" .. index
    btn = CreateFrame("ItemButton", name, self.frame.content, "ContainerFrameItemButtonTemplate")
    btn:SetSize(self.slotSize, self.slotSize)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:EnableMouse(true)
    btn:SetScript("OnEnter", LunaBagsOneBank_ItemButtonOnEnter)
    btn:SetScript("OnLeave", LunaBagsOneBank_ItemButtonOnLeave)
    btn:SetScript("OnUpdate", nil)
    btn.GetInventorySlot = function(self)
        if IsBaseBankContainer(self.bagID) then
            return BankItemToInventorySlotCompat(self:GetID())
        end
        return nil
    end
    btn.UpdateTooltip = function(self)
        if not GameTooltip or not self or not self.bagID or not self.slot then
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
    local slots = {}
    local includeFullDetails = self.searchText and self.searchText ~= ""
    for _, bagID in ipairs(BANK_BAGS) do
        if bagID == -1 or self.visibleBags[bagID] ~= false then
            local slotCount = GetNumSlotsInBag(bagID)
            for slot = 1, slotCount do
                local itemInfo = GetItemInfoFromBag(bagID, slot)
                local itemLink = itemInfo and GetItemLinkFromBag(bagID, slot) or nil
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
    return slots
end

function OneBank:Refresh()
    if not self.frame then return end
    EnsureVisibleBankBagDefaults(self.visibleBags)
    self:UpdateSearchLayout()
    self:RefreshBagSlots()

    local searching = self.searchText and self.searchText ~= ""
    local all = self:BuildLiveSlots()
    local occupiedSlots, totalSlots = CountSlotUsage(all)
    local positioned = {}
    local sectionHeaders = {}
    local sectionEmptyLabels = {}
    local sectionPlaceholders = {}

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

    local categoryConfig = ns.Categories and ns.Categories:GetConfig("bank") or nil
    local categoriesEnabled = categoryConfig and categoryConfig.enabled == true
    local categoryColumnCount = math.max(1, math.min(tonumber(categoryConfig and categoryConfig.columns) or 1, cols))
    local sectionHeaderHeight = 14
    local sectionGapY = 8
    local uncategorized = {}
    local splitByBag = {}
    local splitSections = {}
    local categorySections = {}
    local categoryByID = {}

    if categoriesEnabled and ns.Categories then
        for index, category in ipairs(ns.Categories:GetList("bank") or {}) do
            if category.enabled ~= false then
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

    for _, entry in ipairs(all) do
        local category = categoriesEnabled and ns.Categories and ns.Categories:MatchItem(entry.item, "bank") or nil
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

        local gridGapCols = (categoryColumnCount > 1 and ((categoryColumnCount * 2 - 1) <= cols)) and 1 or 0
        local sectionCols = math.max(1, math.floor((cols - ((categoryColumnCount - 1) * gridGapCols)) / categoryColumnCount))
        local rowHeights = {}
        local layouts = {}

        for index, section in ipairs(sections) do
            local gridCol = (index - 1) % categoryColumnCount
            local gridRow = math.floor((index - 1) / categoryColumnCount)
            local startCol = gridCol * (sectionCols + gridGapCols)
            local entries = section.entries or {}
            local minSlots = math.max(0, tonumber(section.minSlots) or 0)
            local visibleSlots = (#entries == 0) and math.max(1, minSlots) or math.max(#entries, minSlots)
            local slotRows = math.max(1, math.ceil(visibleSlots / sectionCols))
            local sectionHeight = sectionHeaderHeight + slotRows * size + math.max(0, slotRows - 1) * spacing
            rowHeights[gridRow] = math.max(rowHeights[gridRow] or 0, sectionHeight)
            layouts[#layouts + 1] = {
                section = section,
                gridRow = gridRow,
                startCol = startCol,
                entries = entries,
                visibleSlots = visibleSlots,
            }
        end

        for _, layout in ipairs(layouts) do
            local priorOffset = 0
            for row = 0, layout.gridRow - 1 do
                priorOffset = priorOffset + (rowHeights[row] or 0) + sectionGapY
            end

            local section = layout.section
            local entries = layout.entries
            local startCol = layout.startCol
            local visibleSlots = layout.visibleSlots
            local startRow = currentRow
            local headerOffset = extraYOffset + priorOffset

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

            for idx, entry in ipairs(entries) do
                local zero = idx - 1
                positioned[#positioned + 1] = {
                    entry = entry,
                    col = startCol + (zero % sectionCols),
                    row = startRow + math.floor(zero / sectionCols),
                    yOffset = headerOffset,
                }
            end
            for idx = #entries + 1, visibleSlots do
                local zero = idx - 1
                sectionPlaceholders[#sectionPlaceholders + 1] = {
                    col = startCol + (zero % sectionCols),
                    row = startRow + math.floor(zero / sectionCols),
                    yOffset = headerOffset,
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
        local rowIndex = 0
        while rowHeights[rowIndex] do
            if rowIndex > 0 then
                totalHeight = totalHeight + sectionGapY
            end
            totalHeight = totalHeight + rowHeights[rowIndex]
            rowIndex = rowIndex + 1
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
    for i = 1, used do
        local b = self:AcquireButton(i)
        b:SetSize(size, size)
        if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
            ns.ItemButtonStyle.Apply(b)
        end
        local pos = positioned[i]
        local col = pos.col
        local row = pos.row
        local info = pos.entry
        local slotParent = self:GetBagSlotParent(info.bagID, self.frame.content)
        if slotParent and b:GetParent() ~= slotParent then
            b:SetParent(slotParent)
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + col * (size + spacing), -gridInsetY - row * (size + spacing) - (pos.yOffset or 0))
        local isMatch = ItemMatchesSearch(info.item, self.searchText)
        b.bagID = info.bagID
        b.slot = info.slot
        b.BagID = info.bagID
        b.SlotID = info.slot
        b.itemData = info.item
        b:SetID(info.slot)
        b:SetAttribute("type", "item")
        b:SetAttribute("bag", info.bagID)
        b:SetAttribute("slot", info.slot)
        if b.DebugSlotText and IsDebugEnabled() then
            b.DebugSlotText:SetText(("%d:%d"):format(tonumber(info.bagID) or -99, tonumber(info.slot) or -99))
            b.DebugSlotText:Show()
        elseif b.DebugSlotText then
            b.DebugSlotText:Hide()
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
        local bottom = gridInsetY + row * (size + spacing) + (pos.yOffset or 0) + size
        if bottom > maxBottom then maxBottom = bottom end
    end
    for i = used + 1, #self.buttons do
        if self.buttons[i].DebugSlotText then
            self.buttons[i].DebugSlotText:Hide()
        end
        self.buttons[i]:Hide()
    end

    local placeholders = self.frame.content and self.frame.content.BankCategoryPlaceholders or {}
    for i, placeholder in ipairs(sectionPlaceholders) do
        local frame = EnsureBankPlaceholder(self.frame.content, i)
        frame:SetSize(size, size)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + (placeholder.col or 0) * (size + spacing), -gridInsetY - (placeholder.row or 0) * (size + spacing) - (placeholder.yOffset or 0))
        frame:Show()
        local bottom = gridInsetY + (placeholder.row or 0) * (size + spacing) + (placeholder.yOffset or 0) + size
        if bottom > maxBottom then maxBottom = bottom end
    end
    for i = #sectionPlaceholders + 1, #placeholders do
        placeholders[i]:Hide()
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
        if bottom > maxBottom then maxBottom = bottom end
    end
    for i = #sectionEmptyLabels + 1, #(self.sectionEmptyLabels or {}) do
        self.sectionEmptyLabels[i]:Hide()
    end

    if maxBottom <= 0 then maxBottom = gridInsetY + size end
    local contentHeight = maxBottom + gridInsetY
    local frameHeight = math.max(260, contentHeight + frameVerticalChrome)
    self.frame:SetSize(frameWidth, frameHeight)

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

function OneBank:SavePosition()
    local cfg = GetConfig()
    if not cfg or not self.frame then return end
    local point, _, _, x, y = self.frame:GetPoint(1)
    cfg.point = point or "BOTTOMLEFT"
    cfg.x = x or 34
    cfg.y = y or 126
end

function OneBank:SaveVisibleBagsState()
    local cfg = GetConfig()
    if not cfg then return end
    local perChar = cfg._activeCharacterData or {}
    perChar.visibleBags = CopyVisibleBankBagsState(self.visibleBags)
end

function OneBank:ApplySettings()
    local cfg = GetConfig()
    if not cfg or not self.frame then return end
    self.columns = math.max(6, math.min(16, tonumber(cfg.columns) or 14))
    self.slotSize = math.max(24, math.min(48, tonumber(cfg.itemSize) or 36))
    self.spacing = math.max(0, math.min(12, tonumber(cfg.spacing) or 4))
    self.showBagRail = cfg.showBagRail ~= false
    local perChar = cfg._activeCharacterData or {}
    self.visibleBags = CopyVisibleBankBagsState(perChar.visibleBags or cfg.visibleBags)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(cfg.point or "BOTTOMLEFT", UIParent, cfg.point or "BOTTOMLEFT", cfg.x or 34, cfg.y or 126)
    self.frame:SetScale(math.max(0.7, math.min(1.5, tonumber(cfg.scale) or 1)))
    self.frame:SetMovable(not cfg.locked)
    self.frame:RegisterForDrag()
    if self.frame.HeaderDrag then
        self.frame.HeaderDrag:EnableMouse(not cfg.locked)
        self.frame.HeaderDrag:SetShown(not cfg.locked)
    end
    ApplyWindowAppearance(self.frame, cfg)
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
    EnsureStackSplitFrameAboveBank()
    self.frame:Show()
    if ns.LunaBags and ns.LunaBags.QueueOpenWindowRefresh then
        ns.LunaBags:QueueOpenWindowRefresh()
    else
        self:Refresh()
    end
end

function OneBank:Hide()
    if self.frame then self.frame:Hide() end
end

function LunaBagsOneBank_Close()
    if CloseBankFrame then
        CloseBankFrame()
        return
    end
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
        OneBank.searchText = ""
        if OneBank.frame.SearchEditBox:GetText() ~= "" then
            OneBank.frame.SearchEditBox:SetText("")
        end
    end
    OneBank:Refresh()
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
    if button.bagID and button.slot then
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
