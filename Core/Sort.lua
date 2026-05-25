local _, ns = ...

local Sorter = {
    running = false,
    bags = { 0, 1, 2, 3, 4 },
    _onStart = nil,
    _onStop = nil,
    idleTicks = 0,
    lastRefresh = 0,
    lastMoveFrom = nil,
    lastMoveTo = nil,
}

ns.Sorter = Sorter

local ticker = CreateFrame("Frame")
local elapsed = 0
local STEP_INTERVAL = 0
local MAX_STEPS_PER_TICK = 3
local MAX_IDLE_TICKS = 120
local REFRESH_INTERVAL = 0.08
local MOVE_SETTLE_DELAY = 0.12
local HEARTHSTONE_ID = 6948
local CLASS_MISC = LE_ITEM_CLASS_MISCELLANEOUS or 15
local SUBCLASS_MISC_MOUNT = LE_ITEM_MISCELLANEOUS_MOUNT or 5
local CLASS_WEAPON = LE_ITEM_CLASS_WEAPON or 2
local CLASS_ARMOR = LE_ITEM_CLASS_ARMOR or 4
local CLASS_CONSUMABLE = LE_ITEM_CLASS_CONSUMABLE or 0
local CLASS_CONTAINER = LE_ITEM_CLASS_CONTAINER or 1
local CLASS_TRADEGOODS = LE_ITEM_CLASS_TRADEGOODS or 7
local CLASS_RECIPE = LE_ITEM_CLASS_RECIPE or 9
local CLASS_QUESTITEM = LE_ITEM_CLASS_QUESTITEM or 12
local CLASS_GLYPH = LE_ITEM_CLASS_GLYPH or 16
local SPECIALTY_ARROW = "arrow"
local SPECIALTY_BULLET = "bullet"

local SPECIALTY_BAGS = {
    [2101] = SPECIALTY_ARROW, [5439] = SPECIALTY_ARROW, [7278] = SPECIALTY_ARROW,
    [11362] = SPECIALTY_ARROW, [3573] = SPECIALTY_ARROW, [3605] = SPECIALTY_ARROW,
    [7371] = SPECIALTY_ARROW, [8217] = SPECIALTY_ARROW, [2662] = SPECIALTY_ARROW,
    [19319] = SPECIALTY_ARROW, [18714] = SPECIALTY_ARROW, [216514] = SPECIALTY_ARROW,

    [2102] = SPECIALTY_BULLET, [5441] = SPECIALTY_BULLET, [7279] = SPECIALTY_BULLET,
    [11363] = SPECIALTY_BULLET, [3574] = SPECIALTY_BULLET, [3604] = SPECIALTY_BULLET,
    [7372] = SPECIALTY_BULLET, [8218] = SPECIALTY_BULLET, [2663] = SPECIALTY_BULLET,
    [19320] = SPECIALTY_BULLET, [216515] = SPECIALTY_BULLET,
}

local SPECIALTY_ITEMS = {
    [2512] = SPECIALTY_ARROW, [2514] = SPECIALTY_ARROW, [2515] = SPECIALTY_ARROW,
    [3029] = SPECIALTY_ARROW, [3030] = SPECIALTY_ARROW, [3031] = SPECIALTY_ARROW,
    [3464] = SPECIALTY_ARROW, [9399] = SPECIALTY_ARROW, [10579] = SPECIALTY_ARROW,
    [11285] = SPECIALTY_ARROW, [12654] = SPECIALTY_ARROW, [18042] = SPECIALTY_ARROW,
    [19316] = SPECIALTY_ARROW, [24412] = SPECIALTY_ARROW, [24417] = SPECIALTY_ARROW,
    [28053] = SPECIALTY_ARROW, [28056] = SPECIALTY_ARROW, [30319] = SPECIALTY_ARROW,
    [30611] = SPECIALTY_ARROW, [31737] = SPECIALTY_ARROW, [31949] = SPECIALTY_ARROW,
    [32760] = SPECIALTY_ARROW, [33803] = SPECIALTY_ARROW, [34581] = SPECIALTY_ARROW,

    [2516] = SPECIALTY_BULLET, [2519] = SPECIALTY_BULLET, [3033] = SPECIALTY_BULLET,
    [3465] = SPECIALTY_BULLET, [4960] = SPECIALTY_BULLET, [5568] = SPECIALTY_BULLET,
    [8067] = SPECIALTY_BULLET, [8068] = SPECIALTY_BULLET, [8069] = SPECIALTY_BULLET,
    [10512] = SPECIALTY_BULLET, [10513] = SPECIALTY_BULLET, [11284] = SPECIALTY_BULLET,
    [11630] = SPECIALTY_BULLET, [13377] = SPECIALTY_BULLET, [15997] = SPECIALTY_BULLET,
    [19317] = SPECIALTY_BULLET, [23772] = SPECIALTY_BULLET, [23773] = SPECIALTY_BULLET,
    [28060] = SPECIALTY_BULLET, [28061] = SPECIALTY_BULLET, [30612] = SPECIALTY_BULLET,
    [31735] = SPECIALTY_BULLET, [32761] = SPECIALTY_BULLET, [32882] = SPECIALTY_BULLET,
    [32883] = SPECIALTY_BULLET, [34582] = SPECIALTY_BULLET,
}

local CLASS_ORDER = {
    [CLASS_WEAPON] = 10,
    [CLASS_ARMOR] = 20,
    [CLASS_CONSUMABLE] = 30,
    [CLASS_RECIPE] = 40,
    [CLASS_GLYPH] = 50,
    [CLASS_TRADEGOODS] = 60,
    [CLASS_CONTAINER] = 70,
    [CLASS_QUESTITEM] = 80,
    [CLASS_MISC] = 90,
}

local DEFAULT_SORT_RULES = {
    { key = "priority", direction = "asc", enabled = true },
    { key = "quality", direction = "desc", enabled = true },
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "classOrder", direction = "asc", enabled = true },
    { key = "equipLoc", direction = "asc", enabled = true },
    { key = "itemLevel", direction = "desc", enabled = true },
    { key = "name", direction = "asc", enabled = true },
    { key = "itemID", direction = "asc", enabled = true },
    { key = "count", direction = "desc", enabled = true },
}

local SORT_RULE_KEYS = {
    priority = true,
    quality = true,
    itemLevel = true,
    classOrder = true,
    classID = true,
    subClassID = true,
    equipLoc = true,
    name = true,
    itemID = true,
    count = true,
    sellPrice = true,
}

local function Band(a, b)
    if bit and bit.band then return bit.band(a or 0, b or 0) end
    if bit32 and bit32.band then return bit32.band(a or 0, b or 0) end
    return 0
end

local function GetSlotKey(bagID, slot)
    return tostring(bagID) .. ":" .. tostring(slot)
end

local function GetCurrentCharacterKey()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    if not name or name == "" then
        return nil
    end
    return name .. "-" .. (realm or "")
end

local function IsUserLockedSlot(bagID, slot)
    local addon = ns and ns.LunaBags
    local sorting = addon and addon.db and addon.db.profile and addon.db.profile.sorting
    if not sorting then return false end

    local key = GetSlotKey(bagID, slot)
    local charKey = sorting._activeCharacter or GetCurrentCharacterKey()
    local perChar = charKey and sorting.perCharacter and sorting.perCharacter[charKey] or sorting._activeCharacterData
    if perChar and perChar.lockedSlots and perChar.lockedSlots[key] == true then
        return true
    end

    if sorting._lockedSlotsMigrated ~= true and sorting.lockedSlots then
        return sorting.lockedSlots[key] == true
    end
    return false
end

local function GetPriorityItemIDs()
    local priorities = { [HEARTHSTONE_ID] = true }
    local addon = ns and ns.LunaBags
    local raw = addon and addon.db and addon.db.profile and addon.db.profile.sorting
        and addon.db.profile.sorting.priorityItemIDs
    if type(raw) == "string" then
        for id in raw:gmatch("%d+") do
            priorities[tonumber(id)] = true
        end
    elseif type(raw) == "table" then
        for id, enabled in pairs(raw) do
            if enabled then
                priorities[tonumber(id)] = true
            end
        end
    end
    return priorities
end

local function IsReverseSlotOrder()
    local addon = ns and ns.LunaBags
    local sorting = addon and addon.db and addon.db.profile and addon.db.profile.sorting
    return sorting and sorting.reverseSlotOrder == true or false
end

local function GetSortRules()
    local addon = ns and ns.LunaBags
    local sorting = addon and addon.db and addon.db.profile and addon.db.profile.sorting
    local configured = sorting and sorting.rules
    local rules = {}

    if type(configured) == "table" then
        for _, rule in ipairs(configured) do
            if type(rule) == "table" and rule.enabled ~= false and SORT_RULE_KEYS[rule.key] then
                rules[#rules + 1] = {
                    key = rule.key,
                    direction = rule.direction == "desc" and "desc" or "asc",
                }
            end
        end
    end

    if #rules == 0 then
        for _, rule in ipairs(DEFAULT_SORT_RULES) do
            rules[#rules + 1] = {
                key = rule.key,
                direction = rule.direction,
            }
        end
    end

    return rules
end

local function GetNumSlotsInBag(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end
    return GetContainerNumSlots and GetContainerNumSlots(bagID) or 0
end

local function GetContainerInfo(bagID, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info, count, locked, quality = C_Container.GetContainerItemInfo(bagID, slot)
        if type(info) == "table" then
            return info
        end
        if not info then return nil end
        local itemLink = C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bagID, slot)
        return {
            iconFileID = info,
            stackCount = count or 1,
            isLocked = locked,
            quality = quality,
            itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil,
        }
    end

    if not GetContainerItemInfo then return nil end
    local texture, count, locked, quality = GetContainerItemInfo(bagID, slot)
    if not texture then return nil end
    local itemLink = GetContainerItemLink and GetContainerItemLink(bagID, slot)
    return {
        iconFileID = texture,
        stackCount = count or 1,
        isLocked = locked,
        quality = quality,
        itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil,
    }
end

local function GetContainerLink(bagID, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slot)
    end
    return GetContainerItemLink and GetContainerItemLink(bagID, slot)
end

local QUALITY_BY_LINK_COLOR = {
    ["ff9d9d9d"] = 0,
    ["ffffffff"] = 1,
    ["ff1eff00"] = 2,
    ["ff0070dd"] = 3,
    ["ffa335ee"] = 4,
    ["ffff8000"] = 5,
    ["ffe6cc80"] = 6,
    ["ff00ccff"] = 7,
}

local function GetQualityFromLink(link)
    if type(link) ~= "string" then return nil end
    local color = link:match("|c(%x%x%x%x%x%x%x%x)")
    return color and QUALITY_BY_LINK_COLOR[string.lower(color)] or nil
end

local function GetBagFamilyMask(bagID)
    local _, bagType
    if C_Container and C_Container.GetContainerNumFreeSlots then
        _, bagType = C_Container.GetContainerNumFreeSlots(bagID)
    elseif GetContainerNumFreeSlots then
        _, bagType = GetContainerNumFreeSlots(bagID)
    end
    if bagType and bagType > 0 then return bagType end
    if bagID == 0 then return 0 end

    local invSlot
    if C_Container and C_Container.ContainerIDToInventoryID then
        invSlot = C_Container.ContainerIDToInventoryID(bagID)
    elseif ContainerIDToInventoryID then
        invSlot = ContainerIDToInventoryID(bagID)
    end
    if not invSlot then return 0 end

    local bagLink = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
    return bagLink and (GetItemFamily(bagLink) or 0) or 0
end

local function GetSpecialtyBagClass(bagID)
    if bagID == 0 then return nil end

    local invSlot
    if C_Container and C_Container.ContainerIDToInventoryID then
        invSlot = C_Container.ContainerIDToInventoryID(bagID)
    elseif ContainerIDToInventoryID then
        invSlot = ContainerIDToInventoryID(bagID)
    end
    if not invSlot then return nil end

    local bagLink = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
    local bagItemID = bagLink and tonumber(bagLink:match("item:(%d+)")) or nil
    return bagItemID and SPECIALTY_BAGS[bagItemID] or nil
end

local function CanItemFitBag(itemFamilyMask, bagFamilyMask)
    if not bagFamilyMask or bagFamilyMask == 0 then return true end
    if not itemFamilyMask or itemFamilyMask == 0 then return false end
    return Band(itemFamilyMask, bagFamilyMask) ~= 0
end

local function CanItemFitSpace(item, spaceOrBagFamily, bagSpecialtyClass)
    local bagFamilyMask = type(spaceOrBagFamily) == "table" and spaceOrBagFamily.bagFamilyMask or spaceOrBagFamily
    local specialtyClass = type(spaceOrBagFamily) == "table" and spaceOrBagFamily.bagSpecialtyClass or bagSpecialtyClass

    if specialtyClass then
        return item and item.itemSpecialtyClass == specialtyClass
    end
    return CanItemFitBag(item and item.itemFamilyMask or 0, bagFamilyMask)
end

local function IsMountItem(item)
    if not item or item.empty then return false end
    if C_MountJournal and C_MountJournal.GetMountFromItem and item.itemID and item.itemID > 0 then
        local mountID = C_MountJournal.GetMountFromItem(item.itemID)
        if mountID and mountID > 0 then return true end
    end
    if item.classID == CLASS_MISC and item.subClassID == SUBCLASS_MISC_MOUNT then return true end
    return tostring(item.subTypeName or ""):lower():find("mount", 1, true) ~= nil
end

local function BuildSlotData(bagID, slot, bagFamilyMask, bagSpecialtyClass, priorities)
    local info = GetContainerInfo(bagID, slot)
    local link = info and GetContainerLink(bagID, slot) or nil
    local itemID = (info and info.itemID) or (link and tonumber(link:match("item:(%d+)"))) or 0
    local itemKey = link or (itemID > 0 and itemID) or ""
    local name, _, quality, itemLevel, _, itemTypeName, subTypeName, maxStack, equipLoc, _, sellPrice, classID, subClassID
    if itemID > 0 or link then
        name, _, quality, itemLevel, _, itemTypeName, subTypeName, maxStack, equipLoc, _, sellPrice, classID, subClassID = GetItemInfo(itemKey)
    end
    quality = GetQualityFromLink(link) or quality or (info and info.quality)

    local itemFamily = 0
    if itemID > 0 and GetItemFamily then
        itemFamily = GetItemFamily(itemKey) or 0
    end

    local data = {
        bag = bagID,
        slot = slot,
        key = GetSlotKey(bagID, slot),
        empty = info == nil,
        userLocked = IsUserLockedSlot(bagID, slot),
        runtimeLocked = info and info.isLocked == true or false,
        bagFamilyMask = bagFamilyMask ~= nil and bagFamilyMask or GetBagFamilyMask(bagID),
        bagSpecialtyClass = bagSpecialtyClass,
        itemFamilyMask = itemFamily or 0,
        itemSpecialtyClass = SPECIALTY_ITEMS[itemID or 0],
        itemID = itemID or 0,
        link = link or "",
        itemKey = link ~= "" and link or tostring(itemID or 0),
        count = (info and info.stackCount) or 0,
        maxStack = maxStack or 1,
        quality = quality or -1,
        itemLevel = itemLevel or 0,
        classID = classID or 999,
        subClassID = subClassID or 999,
        classOrder = CLASS_ORDER[classID or 999] or 500,
        name = string.lower(name or ""),
        itemTypeName = itemTypeName or "",
        subTypeName = subTypeName or "",
        equipLoc = equipLoc or "",
        sellPrice = sellPrice or 0,
    }

    if not data.empty then
        if priorities and priorities[data.itemID] then
            data.priority = 0
        elseif IsMountItem(data) then
            data.priority = 5
        else
            data.priority = 10
        end
    else
        data.priority = 999
    end
    return data
end

local function ItemSortWithRules(a, b, rules)
    for _, rule in ipairs(rules) do
        local av = a[rule.key]
        local bv = b[rule.key]
        if av ~= bv then
            if rule.direction == "desc" then
                return av > bv
            end
            return av < bv
        end
    end
    return a.key < b.key
end

local function SpaceSort(a, b)
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

local function ReverseSpaceSort(a, b)
    if a.bag ~= b.bag then return a.bag > b.bag end
    return a.slot > b.slot
end

local function BuildSpaces(bags)
    local spaces = {}
    local priorities = GetPriorityItemIDs()
    for _, bagID in ipairs(bags) do
        local bagFamilyMask = GetBagFamilyMask(bagID)
        local bagSpecialtyClass = GetSpecialtyBagClass(bagID)
        local slots = GetNumSlotsInBag(bagID)
        for slot = 1, slots do
            local item = BuildSlotData(bagID, slot, bagFamilyMask, bagSpecialtyClass, priorities)
            local space = {
                index = #spaces + 1,
                bag = bagID,
                slot = slot,
                key = item.key,
                bagFamilyMask = bagFamilyMask,
                bagSpecialtyClass = bagSpecialtyClass,
                item = item,
                locked = item.userLocked and not item.empty,
            }
            item.space = space
            spaces[#spaces + 1] = space
        end
    end
    table.sort(spaces, IsReverseSlotOrder() and ReverseSpaceSort or SpaceSort)
    for i, space in ipairs(spaces) do
        space.index = i
    end
    return spaces
end

local function AssignDesiredLayout(spaces)
    local items, used = {}, {}

    for _, space in ipairs(spaces) do
        space.targetItem = nil
        space.targetCount = nil
        space.targetData = nil
        if space.locked then
            if not space.item.empty then
                space.targetItem = space.item.itemKey
                space.targetCount = space.item.count
                space.targetData = space.item
            end
        elseif not space.item.empty then
            items[#items + 1] = space.item
        end
    end

    local sortRules = GetSortRules()
    table.sort(items, function(a, b)
        return ItemSortWithRules(a, b, sortRules)
    end)

    for _, space in ipairs(spaces) do
        if not space.locked and space.bagFamilyMask and space.bagFamilyMask > 0 then
            for _, item in ipairs(items) do
                if not used[item] and CanItemFitSpace(item, space) then
                    space.targetItem = item.itemKey
                    space.targetCount = item.count
                    space.targetData = item
                    used[item] = true
                    break
                end
            end
        end
    end

    for _, space in ipairs(spaces) do
        if not space.locked and not space.targetItem and (not space.bagFamilyMask or space.bagFamilyMask == 0) then
            for _, item in ipairs(items) do
                if not used[item] then
                    space.targetItem = item.itemKey
                    space.targetCount = item.count
                    space.targetData = item
                    used[item] = true
                    break
                end
            end
        end
    end

    return true
end

local function BuildDisplaySortData(entry)
    local item = entry and entry.item
    local itemID = tonumber(item and item.itemID) or 0
    local data = {
        bag = entry and entry.bagID or 0,
        slot = entry and entry.slot or 0,
        key = GetSlotKey(entry and entry.bagID or 0, entry and entry.slot or 0),
        empty = item == nil,
        itemID = itemID,
        count = tonumber(item and item.stackCount) or 0,
        quality = tonumber(item and item.quality) or -1,
        itemLevel = tonumber(item and item.itemLevel) or 0,
        classID = tonumber(item and item.classID) or 999,
        subClassID = tonumber(item and item.subClassID) or 999,
        name = string.lower(tostring(item and item.name or "")),
        itemTypeName = item and item.itemTypeName or "",
        subTypeName = item and item.subTypeName or "",
        equipLoc = item and item.equipLoc or "",
        sellPrice = tonumber(item and item.sellPrice) or 0,
    }
    data.classOrder = CLASS_ORDER[data.classID] or 500

    if not data.empty then
        local priorities = GetPriorityItemIDs()
        if priorities[data.itemID] then
            data.priority = 0
        elseif IsMountItem(data) then
            data.priority = 5
        else
            data.priority = 10
        end
    else
        data.priority = 999
    end

    return data
end

function Sorter:SortDisplayEntries(entries)
    if type(entries) ~= "table" or #entries <= 1 then
        return entries
    end

    local result = {}
    local sortable = {}
    local empty = {}
    local fillIndexes = {}

    for index, entry in ipairs(entries) do
        local locked = entry and entry.item and IsUserLockedSlot(entry.bagID, entry.slot)
        if locked then
            result[index] = entry
        else
            fillIndexes[#fillIndexes + 1] = index
            if entry and entry.item then
                entry._displaySortData = BuildDisplaySortData(entry)
                sortable[#sortable + 1] = entry
            else
                empty[#empty + 1] = entry
            end
        end
    end

    local sortRules = GetSortRules()
    table.sort(sortable, function(a, b)
        return ItemSortWithRules(a._displaySortData, b._displaySortData, sortRules)
    end)

    local outputIndex = IsReverseSlotOrder() and #fillIndexes or 1
    local outputStep = IsReverseSlotOrder() and -1 or 1
    local function NextFillIndex()
        local fillIndex = fillIndexes[outputIndex]
        outputIndex = outputIndex + outputStep
        return fillIndex
    end

    for _, entry in ipairs(sortable) do
        result[NextFillIndex()] = entry
        entry._displaySortData = nil
    end
    for _, entry in ipairs(empty) do
        result[NextFillIndex()] = entry
    end

    return result
end

local function IsCorrect(space)
    if not space.targetItem then
        return space.item.empty
    end
    return not space.item.empty
        and space.item.itemKey == space.targetItem
        and space.item.count == space.targetCount
end

local function IsSatisfied(space)
    return IsCorrect(space)
end

local function SourceHasSpareForTarget(space)
    return not space.item.empty and not IsCorrect(space)
end

local function CanSwapSpaces(a, b)
    if not a or not b or a.item.empty or b.item.empty then return false end
    if a.locked or b.locked then return false end
    if a.item.runtimeLocked or b.item.runtimeLocked then return false end
    if a.item.itemKey == b.item.itemKey and ((a.item.maxStack or 1) > 1 or (b.item.maxStack or 1) > 1) then
        return false
    end
    return CanItemFitSpace(a.item, b)
        and CanItemFitSpace(b.item, a)
end

local function FindSourceForTarget(spaces, target)
    local best, bestRank
    for _, source in ipairs(spaces) do
        if source ~= target
            and not source.locked
            and not target.locked
            and not source.item.empty
            and not source.item.runtimeLocked
            and not target.item.runtimeLocked
            and source.item.itemKey == target.targetItem
            and source.item.count == target.targetCount
            and SourceHasSpareForTarget(source)
            and CanItemFitSpace(source.item, target)
            and (target.item.empty or CanItemFitSpace(target.item, source))
        then
            local rank = math.abs((source.item.count or 0) - (target.targetCount or 0)
                + (target.item.itemKey == target.targetItem and (target.item.count or 0) or 0))
            if not bestRank or rank < bestRank then
                best = source
                bestRank = rank
            end
        end
    end
    return best
end

local function FindBufferSpace(spaces, item)
    for i = #spaces, 1, -1 do
        local space = spaces[i]
        if space.item.empty
            and not space.locked
            and not space.targetItem
            and CanItemFitSpace(item, space)
        then
            return space
        end
    end
    for i = #spaces, 1, -1 do
        local space = spaces[i]
        if space.item.empty and not space.locked and CanItemFitSpace(item, space) then
            return space
        end
    end
    return nil
end

local function FindCompatibleIncorrectSwap(spaces)
    for _, target in ipairs(spaces) do
        if target.targetItem and not target.item.runtimeLocked and not IsCorrect(target) then
            for _, source in ipairs(spaces) do
                if source ~= target
                    and not source.locked
                    and not target.locked
                    and not source.item.empty
                    and not source.item.runtimeLocked
                    and not IsCorrect(source)
                    and source.item.itemKey == target.targetItem
                    and source.item.count == target.targetCount
                    and CanSwapSpaces(source, target)
                then
                    return source, target
                end
            end
        end
    end
    for _, source in ipairs(spaces) do
        if not source.item.empty and not source.item.runtimeLocked and not IsCorrect(source) then
            for _, target in ipairs(spaces) do
                if target ~= source
                    and not source.locked
                    and not target.locked
                    and not target.item.empty
                    and not target.item.runtimeLocked
                    and target.targetItem == source.item.itemKey
                    and target.targetCount == source.item.count
                    and not IsCorrect(target)
                    and CanSwapSpaces(source, target)
                then
                    return source, target
                end
            end
        end
    end
    return nil, nil
end

local function PickupSlot(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    else
        PickupContainerItem(bag, slot)
    end
end

local function RefreshVisibleViews()
    local now = GetTime and GetTime() or 0
    if now > 0 and Sorter.lastRefresh and (now - Sorter.lastRefresh) < REFRESH_INTERVAL then
        return
    end
    Sorter.lastRefresh = now
    if ns.OneBag and ns.OneBag.frame and ns.OneBag.frame:IsShown() then
        ns.OneBag:Refresh()
    end
    if ns.OneBank and ns.OneBank.frame and ns.OneBank.frame:IsShown() then
        ns.OneBank:Refresh()
    end
end

function Sorter:MoveItem(fromSpace, toSpace)
    if not fromSpace or not toSpace then return false end
    if fromSpace.locked or toSpace.locked then return false end
    if fromSpace.item.empty then return false end
    if fromSpace.item.runtimeLocked or toSpace.item.runtimeLocked then return false end
    if fromSpace.bag == toSpace.bag and fromSpace.slot == toSpace.slot then return false end
    local fromKey = GetSlotKey(fromSpace.bag, fromSpace.slot)
    local toKey = GetSlotKey(toSpace.bag, toSpace.slot)
    if self.lastMoveFrom == toKey and self.lastMoveTo == fromKey then
        return false
    end
    if not CanItemFitSpace(fromSpace.item, toSpace) then return false end
    if not toSpace.item.empty and not CanItemFitSpace(toSpace.item, fromSpace) then return false end

    PickupSlot(fromSpace.bag, fromSpace.slot)
    if CursorHasItem and not CursorHasItem() then
        return false
    end
    PickupSlot(toSpace.bag, toSpace.slot)
    if CursorHasItem and CursorHasItem() then
        PickupSlot(fromSpace.bag, fromSpace.slot)
    end
    if CursorHasItem and CursorHasItem() then
        if ClearCursor then ClearCursor() end
        return false
    end
    self.lastMoveFrom = fromKey
    self.lastMoveTo = toKey
    if GetTime then
        self.waitUntil = GetTime() + MOVE_SETTLE_DELAY
    end
    return true
end

function Sorter:StepOnce()
    local spaces = BuildSpaces(self.bags)
    if #spaces < 2 then return "done" end
    if not AssignDesiredLayout(spaces) then return "pending" end

    for _, target in ipairs(spaces) do
        if not target.locked and target.targetItem and not target.item.runtimeLocked and not IsSatisfied(target) then
            local source = FindSourceForTarget(spaces, target)
            if source and self:MoveItem(source, target) then
                return "moved"
            end
        end
    end

    for _, target in ipairs(spaces) do
        if not target.locked and target.targetItem and not target.item.runtimeLocked and not IsCorrect(target) and not target.item.empty then
            local buffer = FindBufferSpace(spaces, target.item)
            if buffer and buffer.index < target.index and self:MoveItem(target, buffer) then
                return "moved"
            end
        end
    end

    for _, source in ipairs(spaces) do
        if not source.locked and not source.item.runtimeLocked and not IsCorrect(source) and not source.item.empty then
            local buffer = FindBufferSpace(spaces, source.item)
            if buffer and buffer.index < source.index and self:MoveItem(source, buffer) then
                return "moved"
            end
        end
    end

    for _, target in ipairs(spaces) do
        if not target.locked and target.targetItem and not target.item.runtimeLocked and not IsCorrect(target) then
            local source = FindSourceForTarget(spaces, target)
            if source and CanSwapSpaces(source, target) and self:MoveItem(source, target) then
                return "moved"
            end
        end
    end

    local source, target = FindCompatibleIncorrectSwap(spaces)
    if source and target and self:MoveItem(source, target) then
        return "moved"
    end

    local waitingOnLocked = false
    for _, space in ipairs(spaces) do
        if not IsCorrect(space) then
            if space.item.runtimeLocked then
                waitingOnLocked = true
            else
                return "blocked"
            end
        end
    end
    if waitingOnLocked then
        return "pending"
    end
    return "done"
end

local function HandleIdleState(self, state)
    self.idleTicks = self.idleTicks + 1
    if self.idleTicks > MAX_IDLE_TICKS then
        if ns and ns.LunaBags and ns.LunaBags.Print then
            ns.LunaBags:Print(("Sort stopped while %s."):format(state == "pending" and "waiting for item locks" or "blocked"))
        end
        self:Stop()
    end
end

function Sorter:Step()
    if not self.running then return end
    if InCombatLockdown and InCombatLockdown() then self:Stop(); return end
    if self.waitUntil and GetTime and GetTime() < self.waitUntil then
        return "wait"
    end
    self.waitUntil = nil
    if CursorHasItem and CursorHasItem() then
        if ClearCursor then ClearCursor() end
        return "wait"
    end

    local state = self:StepOnce()
    if state == "moved" then
        self.idleTicks = 0
        return state
    end
    if state == "pending" then
        HandleIdleState(self, state)
        return state
    end
    if state == "wait" then
        return state
    end
    if state == "done" then
        self:Stop()
        return state
    end

    HandleIdleState(self, state)
    return state
end

function Sorter:Start()
    if self.running then return end
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
    self.running = true
    self.idleTicks = 0
    self.lastRefresh = 0
    self.lastMoveFrom = nil
    self.lastMoveTo = nil
    self.waitUntil = nil
    if ns and ns.LunaBags and ns.LunaBags.BeginSortSession then ns.LunaBags:BeginSortSession() end
    if self._onStart then self._onStart() elseif ns.OneBag and ns.OneBag.SetSortingState then ns.OneBag:SetSortingState(true) end
end

function Sorter:Stop()
    self.running = false
    if ns and ns.LunaBags and ns.LunaBags.EndSortSession then ns.LunaBags:EndSortSession() end
    if self._onStop then self._onStop() elseif ns.OneBag and ns.OneBag.SetSortingState then ns.OneBag:SetSortingState(false) end
    self._onStart = nil
    self._onStop = nil
    self.waitUntil = nil
end

function Sorter:SortBags()
    if self.running then self:Stop() end
    self.bags = { 0, 1, 2, 3, 4 }
    self._onStart = nil
    self._onStop = nil
    self:Start()
end

function Sorter:SortSpecificBags(bagList, callbacks)
    if type(bagList) ~= "table" or #bagList == 0 then return end
    if self.running then self:Stop() end
    self.bags = {}
    for i = 1, #bagList do
        local bagID = tonumber(bagList[i])
        if bagID then self.bags[#self.bags + 1] = bagID end
    end
    if #self.bags == 0 then return end

    callbacks = callbacks or {}
    self._onStart = callbacks.onStart
    self._onStop = callbacks.onStop
    self:Start()
end

ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + (dt or 0)
    if elapsed < STEP_INTERVAL then return end
    elapsed = 0
    if not Sorter.running then return end

    local moved = false
    for _ = 1, MAX_STEPS_PER_TICK do
        if not Sorter.running then break end
        local ok, stateOrErr = xpcall(function() return Sorter:Step() end, function(e) return tostring(e) end)
        if not ok then
            Sorter:Stop()
            if ns and ns.LunaBags and ns.LunaBags.Print then
                ns.LunaBags:Print(("Sort error: %s"):format(tostring(stateOrErr)))
            end
            break
        end
        if stateOrErr == "moved" then
            moved = true
        elseif stateOrErr ~= "moved" then
            break
        end
    end
    if moved then
        RefreshVisibleViews()
    end
end)
