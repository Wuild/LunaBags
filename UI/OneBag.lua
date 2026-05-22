local _, ns = ...

local OneBag = {
    frame = nil,
    buttons = {},
    readonlyButtons = {},
    keyringButtons = {},
    bagButtons = {},
    columns = 11,
    slotSize = 37,
    spacing = 4,
    searchText = "",
    searchVisible = false,
    showBagRail = true,
    splitByBagRows = false,
    sortingActive = false,
    lockSlotsMode = false,
    viewCharacterKey = nil,
    visibleBags = {},
    tooltipHooked = false,
    hoveredItemID = nil,
    hoveredButton = nil,
}

ns.OneBag = OneBag

local PLAYER_BAGS = { 0, 1, 2, 3, 4 }

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

local function IsViewingCurrentCharacter()
    return not OneBag.viewCharacterKey or OneBag.viewCharacterKey == GetCurrentCharacterKey()
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
        return ("|T%s:%d:%d:0:-1|t"):format(path, size, size)
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

local function EnsureTooltipPostHook()
    if OneBag.tooltipHooked then
        return
    end
    OneBag.tooltipHooked = true
    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        local itemID = OneBag.hoveredItemID
        local _, link = tt:GetItem()
        if not itemID and link then
            itemID = tonumber(link:match("item:(%d+)"))
        end
        if not itemID then
            return
        end
        AddCharacterItemCountTooltip(itemID, link)
    end)
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
    addon.db.profile.oneBag.perCharacter = addon.db.profile.oneBag.perCharacter or {}
    local key = GetCurrentCharacterKey()
    local perChar = addon.db.profile.oneBag.perCharacter[key] or {}
    addon.db.profile.oneBag.perCharacter[key] = perChar
    perChar.splitBags = perChar.splitBags or {}
    perChar.visibleBags = perChar.visibleBags or {}
    if addon.db.profile.oneBag._splitBagsMigrated ~= true then
        local old = addon.db.profile.oneBag.splitBags
        if type(old) == "table" then
            for bagID, enabled in pairs(old) do
                if perChar.splitBags[bagID] == nil then
                    perChar.splitBags[bagID] = enabled == true or nil
                end
            end
        end
        addon.db.profile.oneBag._splitBagsMigrated = true
    end
    if addon.db.profile.oneBag._viewOptionsPerCharMigrated ~= true then
        if perChar.splitByBagRows == nil and addon.db.profile.oneBag.splitByBagRows ~= nil then
            perChar.splitByBagRows = addon.db.profile.oneBag.splitByBagRows == true or nil
        end
        if perChar.showBagRail == nil and addon.db.profile.oneBag.showBagRail ~= nil then
            perChar.showBagRail = addon.db.profile.oneBag.showBagRail ~= false and true or nil
        end
        if type(addon.db.profile.oneBag.visibleBags) == "table" then
            for bagID, enabled in pairs(addon.db.profile.oneBag.visibleBags) do
                if perChar.visibleBags[bagID] == nil then
                    perChar.visibleBags[bagID] = enabled ~= false
                end
            end
        end
        addon.db.profile.oneBag._viewOptionsPerCharMigrated = true
    end
    addon.db.profile.oneBag._activeCharacter = key
    addon.db.profile.oneBag._activeCharacterData = perChar
    return addon.db.profile.oneBag
end

local function IsBagSplitEnabled(bagID)
    local cfg = GetConfig()
    if not cfg then
        return false
    end
    local perChar = cfg._activeCharacterData or {}
    perChar.splitBags = perChar.splitBags or {}
    return perChar.splitBags[bagID] == true
end

local function SetBagSplitEnabled(bagID, enabled)
    local cfg = GetConfig()
    if not cfg then
        return
    end
    local perChar = cfg._activeCharacterData or {}
    perChar.splitBags = perChar.splitBags or {}
    perChar.splitBags[bagID] = enabled == true or nil
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

local function GetSlotKey(bagID, slot)
    return tostring(bagID) .. ":" .. tostring(slot)
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

    local topInset = self.searchVisible and 34 or 12
    self.frame.content:ClearAllPoints()
    self.frame.content:SetPoint("TOPLEFT", self.frame.DarkInset, "TOPLEFT", 12, -topInset)
    self.frame.content:SetPoint("BOTTOMRIGHT", self.frame.DarkInset, "BOTTOMRIGHT", -12, 12)

    if self.frame.SearchPanel then
        self.frame.SearchPanel:SetShown(self.searchVisible)
    end
end

function OneBag:SetBagSlotPreview(bagID)
    if not self.buttons then
        return
    end

    for _, button in ipairs(self.buttons) do
        if button and button:IsShown() then
            if bagID == nil then
                button:SetAlpha(button._baseAlpha or 1)
            elseif button.bagID == bagID then
                button:SetAlpha(1)
            else
                button:SetAlpha(0.22)
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
        frame:SetFrameStrata("HIGH")
        frame:Hide()
        frame.content = CreateFrame("Frame", nil, frame)
        frame.content:SetPoint("TOPLEFT", 8, -48)
        frame.content:SetPoint("BOTTOMRIGHT", -8, 36)
        frame.moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.moneyText:SetPoint("BOTTOMRIGHT", -16, 16)
    end
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
    frame:RegisterForDrag("LeftButton")
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            if f.SetPropagateKeyboardInput then
                f:SetPropagateKeyboardInput(false)
            end
            LunaBagsOneBag_Close()
            return
        end
        if f.SetPropagateKeyboardInput then
            f:SetPropagateKeyboardInput(true)
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        OneBag:SavePosition()
    end)
    frame.content = frame.Content or frame.content
    frame.searchBox = frame.Header and frame.Header.SearchBox or nil
    frame.moneyText = (frame.MoneyBar and frame.MoneyBar.Text) or frame.moneyText

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
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 49, 0)
    end
    if frame.Header and frame.Header.SortButton then
        local b = frame.Header.SortButton
        b:SetText("")
        b:SetNormalTexture("Interface\\AddOns\\LunaBags\\external\\Bagnon\\art\\broom")
        b:SetPushedTexture("Interface\\AddOns\\LunaBags\\external\\Bagnon\\art\\broom")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        b:SetSize(18, 18)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", LunaBagsOneBag_SortButtonClicked)
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
        b:SetScript("OnClick", function(btn)
            if not LunaBagsCharacterMenu then
                CreateFrame("Frame", "LunaBagsCharacterMenu", UIParent, "UIDropDownMenuTemplate")
            end
            local items = {}
            local currentKey = GetCurrentCharacterKey()
            items[#items + 1] = {
                text = "Current Character",
                checked = function() return OneBag.viewCharacterKey == nil or OneBag.viewCharacterKey == currentKey end,
                func = function()
                    OneBag.viewCharacterKey = nil
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
                        checked = function() return OneBag.viewCharacterKey == selectedKey end,
                        func = function()
                            OneBag.viewCharacterKey = selectedKey
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
        if frame.MoneyBar.Label then frame.MoneyBar.Label:SetText("") end
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
        frame.Content:SetFrameLevel(frame:GetFrameLevel() + 3)
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

    frame.BagSlotParents = frame.BagSlotParents or {}

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
        if CursorHasItem() then
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

    local shownCount = 0
    for i, bagID in ipairs(railBags) do
        local button = self:AcquireBagButton(i)
        local showButton = not (bagID == KEYRING_CONTAINER and not self.keyringAvailable)
        if showButton then
            shownCount = shownCount + 1
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.frame.BagSlots, "TOPLEFT", pad + (shownCount - 1) * (size + spacing), -pad)
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
    self.frame.BagSlots:SetWidth(pad * 2 + used * size + (used - 1) * spacing)
    self.frame.BagSlots:SetHeight(size + pad * 2)
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
    if ContainerFrameItemButton_OnClick then
        btn:SetScript("OnClick", function(self, mouseButton)
            if not IsViewingCurrentCharacter() then
                return
            end
            ContainerFrameItemButton_OnClick(self, mouseButton)
        end)
    end
    if ContainerFrameItemButton_OnDrag then
        btn:SetScript("OnDragStart", function(self)
            if not IsViewingCurrentCharacter() then
                return
            end
            ContainerFrameItemButton_OnDrag(self)
        end)
    end
    if ContainerFrameItemButton_OnReceiveDrag then
        btn:SetScript("OnReceiveDrag", function(self)
            if not IsViewingCurrentCharacter() then
                return
            end
            ContainerFrameItemButton_OnReceiveDrag(self)
        end)
    end

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
        searchBox:SetText("")
        OneBag.searchText = ""
        OneBag:Refresh()
    end
end

function LunaBagsOneBag_SortClicked()
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
        local perChar = cfg._activeCharacterData or {}
        perChar.showBagRail = OneBag.showBagRail == true or nil
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

function OneBag:BuildLiveSlots()
    local slots = {}
    local viewingCurrent = IsViewingCurrentCharacter()
    local viewedCharacter = nil
    if not viewingCurrent then
        viewedCharacter = GetViewedCharacterData()
    end

    for bagID = 0, 4 do
        if self.visibleBags[bagID] ~= false and not IsKeyringBag(bagID) then
            local slotCount = 0
            local cachedSlots = nil
            local cachedBagData = nil
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
    end

    table.sort(slots, function(a, b)
        if a.bagID == b.bagID then
            return a.slot < b.slot
        end
        return a.bagID < b.bagID
    end)

    return slots
end

function OneBag:BuildKeyringSlots()
    local slots = {}
    if not KEYRING_CONTAINER or self.visibleBags[KEYRING_CONTAINER] == false or not IsViewingCurrentCharacter() then
        return slots
    end

    local slotCount = math.min(2, GetNumSlotsInBag(KEYRING_CONTAINER))
    for slot = 1, slotCount do
        local itemInfo = GetItemInfoFromBag(KEYRING_CONTAINER, slot)
        local itemLink = itemInfo and GetItemLinkFromBag(KEYRING_CONTAINER, slot) or nil
        local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil
        local itemName = itemLink and GetItemInfo(itemLink) or nil
        slots[#slots + 1] = {
            bagID = KEYRING_CONTAINER,
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

function OneBag:Refresh()
    if not self.frame then
        return
    end
    EnsureVisibleBagDefaults(self.visibleBags)

    local allSlots = self:BuildLiveSlots()
    local keySlots = self:BuildKeyringSlots()
    self:RefreshBagSlots()
    local searching = self.searchText and self.searchText ~= ""
    local readOnly = not IsViewingCurrentCharacter()
    local used = #allSlots
    local cols = self.columns
    local size = self.slotSize
    local spacing = self.spacing
    local gridWidth = cols * size + ((cols - 1) * spacing)
    local gridInsetX = spacing
    local gridInsetY = spacing
    local framePaddingX = 26
    local contentTopInset = self.searchVisible and 34 or 12
    local frameVerticalChrome = 79 + contentTopInset

    local rows = math.max(1, math.ceil(math.max(used, 1) / cols))
    local desiredContentWidth = gridWidth + (gridInsetX * 2)
    local contentHeight = gridInsetY + rows * size + (rows - 1) * spacing + gridInsetY

    -- Desired frame size from configured columns.
    local frameWidth = desiredContentWidth + framePaddingX
    local frameHeight = math.max(200, contentHeight + frameVerticalChrome)
    self.frame:SetSize(frameWidth, frameHeight)

    -- Recenter against actual available content width (template/min-width can exceed desired width).
    local actualContentWidth = self.frame.content and self.frame.content:GetWidth() or desiredContentWidth
    gridInsetX = math.max(spacing, math.floor((actualContentWidth - gridWidth) * 0.5))

    local positioned = {}
    local bagSectionGapY = spacing
    local bagBuckets = {}
    for _, entry in ipairs(allSlots) do
        bagBuckets[entry.bagID] = bagBuckets[entry.bagID] or {}
        bagBuckets[entry.bagID][#bagBuckets[entry.bagID] + 1] = entry
    end

    local nonSplit = {}
    local splitSections = {}

    for bagID = 0, 4 do
        if self.visibleBags[bagID] ~= false and not IsKeyringBag(bagID) then
            local bucket = bagBuckets[bagID] or {}
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

    for idx, entry in ipairs(nonSplit) do
        local localIndex = idx - 1
        positioned[#positioned + 1] = {
            entry = entry,
            col = localIndex % cols,
            row = math.floor(localIndex / cols),
        }
    end

    local usedRows = (#nonSplit > 0) and math.ceil(#nonSplit / cols) or 0
    local extraYOffset = 0
    local hasBaseContent = #positioned > 0

    for _, section in ipairs(splitSections) do
        local entries = section.entries or {}
        if #entries > 0 then
            if hasBaseContent then
                extraYOffset = extraYOffset + bagSectionGapY
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
            usedRows = usedRows + math.max(1, math.ceil(#entries / cols))
            hasBaseContent = true
        end
    end

    -- Keyring is always split and always placed after non-split and split-bag sections.
    if #keySlots > 0 then
        if hasBaseContent then
            extraYOffset = extraYOffset + bagSectionGapY
        end
        for idx, entry in ipairs(keySlots) do
            local localIndex = idx - 1
            positioned[#positioned + 1] = {
                entry = entry,
                col = localIndex % cols,
                row = usedRows + math.floor(localIndex / cols),
                yOffset = extraYOffset,
            }
        end
        usedRows = usedRows + math.max(1, math.ceil(#keySlots / cols))
        hasBaseContent = true
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
    if maxBottom <= 0 then
        maxBottom = gridInsetY + size
    end
    contentHeight = maxBottom + gridInsetY
    frameHeight = math.max(200, contentHeight + frameVerticalChrome)
    self.frame:SetSize(frameWidth, frameHeight)

    used = #positioned
    local usingReadonlyButtons = readOnly
    for i = 1, used do
        local button = usingReadonlyButtons and self:AcquireReadonlyButton(i) or self:AcquireButton(i)
        button:SetSize(size, size)
        local p = positioned[i]
        local col = p.col
        local row = p.row
        local extraY = p.yOffset or 0
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", gridInsetX + col * (size + spacing), -gridInsetY - row * (size + spacing) - extraY)

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
        if button.DebugSlotText then
            button.DebugSlotText:SetText(("%d:%d"):format(tonumber(info.bagID) or -99, tonumber(info.slot) or -99))
            button.DebugSlotText:Show()
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
        UpdateButtonStyleBorderForItem(button, info.item)
        if ns.Plugins then
            ns.Plugins:Apply(button, info, "oneBag")
        end
        local lockCross = EnsureLockedCross(button)
        if self.lockSlotsMode and IsSlotUserLocked(info.bagID, info.slot) then
            lockCross:Show()
            lockCross.d1:Show()
            lockCross.d2:Show()
        else
            lockCross:Hide()
            lockCross.d1:Hide()
            lockCross.d2:Hide()
        end
        if button.icon and button.icon.SetDesaturated then
            button.icon:SetDesaturated(self.sortingActive == true)
        end
        button:EnableMouse((self.sortingActive ~= true) and ((not readOnly) or usingReadonlyButtons))
        if button.LockOverlay then
            if self.lockSlotsMode and not self.sortingActive and not readOnly then
                button.LockOverlay:Show()
            else
                button.LockOverlay:Hide()
            end
        end
        button:Show()
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
        if b and b.DebugSlotText then
            b.DebugSlotText:Hide()
        end
        self.buttons[i]:Hide()
    end
    for i = used + 1, #self.readonlyButtons do
        if self.readonlyButtons[i] and self.readonlyButtons[i].DebugSlotText then
            self.readonlyButtons[i].DebugSlotText:Hide()
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
        self.keyringButtons[i]:Hide()
    end

    local money = GetMoney and GetMoney() or 0
    if self.frame.moneyText then
        self.frame.moneyText:SetText(FormatMoneyText(money, 14))
    end
    if self.frame.MoneyBar and self.frame.MoneyBar.Text then
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
    self:SetSortingState(self.sortingActive == true)
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

function OneBag:SaveVisibleBagsState()
    local cfg = GetConfig()
    if not cfg then
        return
    end
    local perChar = cfg._activeCharacterData or {}
    perChar.visibleBags = CopyVisibleBagsState(self.visibleBags)
end

function OneBag:ApplySettings()
    local cfg = GetConfig()
    if not cfg then
        return
    end

    self.columns = math.max(6, math.min(16, tonumber(cfg.columns) or 11))
    self.slotSize = math.max(24, math.min(48, tonumber(cfg.itemSize) or 36))
    self.spacing = math.max(0, math.min(12, tonumber(cfg.spacing) or 4))
    local perChar = cfg._activeCharacterData or {}
    self.splitByBagRows = (perChar.splitByBagRows ~= nil) and (perChar.splitByBagRows == true) or (cfg.splitByBagRows == true)
    self.showBagRail = (perChar.showBagRail ~= nil) and (perChar.showBagRail == true) or (cfg.showBagRail ~= false)
    self.visibleBags = CopyVisibleBagsState(perChar.visibleBags or cfg.visibleBags)

    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(cfg.point or "BOTTOMRIGHT", UIParent, cfg.point or "BOTTOMRIGHT", cfg.x or -34, cfg.y or 126)
        self.frame:SetScale(math.max(0.7, math.min(1.5, tonumber(cfg.scale) or 1)))
        self.frame:SetMovable(not cfg.locked)
        self.frame:EnableMouse(true)
        if cfg.locked then
            self.frame:RegisterForDrag()
        else
            self.frame:RegisterForDrag("LeftButton")
        end
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
    self:CreateFrame()
    self.viewCharacterKey = nil
    self:ApplySettings()
    self:Refresh()
    self.frame:Show()
end

function OneBag:Hide()
    if self.frame then
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
