local _, addon = ...

local Plugin = {
    name = "EquipmentSetCategories",
    id = "equipmentSetCategories",
    defaultEnabled = true,
}

local SLOT_IDS = {}
local SLOT_NAME_BY_ID = {}

local function AddSlot(id, name)
    if id and name then
        SLOT_IDS[#SLOT_IDS + 1] = id
        SLOT_NAME_BY_ID[id] = name
    end
end

AddSlot(INVSLOT_HEAD, "HeadSlot")
AddSlot(INVSLOT_NECK, "NeckSlot")
AddSlot(INVSLOT_SHOULDER, "ShoulderSlot")
AddSlot(INVSLOT_BACK, "BackSlot")
AddSlot(INVSLOT_CHEST, "ChestSlot")
AddSlot(INVSLOT_BODY, "ShirtSlot")
AddSlot(INVSLOT_TABARD, "TabardSlot")
AddSlot(INVSLOT_WRIST, "WristSlot")
AddSlot(INVSLOT_HAND, "HandsSlot")
AddSlot(INVSLOT_WAIST, "WaistSlot")
AddSlot(INVSLOT_LEGS, "LegsSlot")
AddSlot(INVSLOT_FEET, "FeetSlot")
AddSlot(INVSLOT_FINGER1, "Finger0Slot")
AddSlot(INVSLOT_FINGER2, "Finger1Slot")
AddSlot(INVSLOT_TRINKET1, "Trinket0Slot")
AddSlot(INVSLOT_TRINKET2, "Trinket1Slot")
AddSlot(INVSLOT_MAINHAND, "MainHandSlot")
AddSlot(INVSLOT_OFFHAND, "SecondaryHandSlot")
AddSlot(INVSLOT_RANGED, "RangedSlot")
AddSlot(INVSLOT_AMMO, "AmmoSlot")

local SLOT_ID_BY_NAME = {}
for id, name in pairs(SLOT_NAME_BY_ID) do
    SLOT_ID_BY_NAME[name] = id
end

local ITEMRACK_SLOT_BY_INDEX = {
    [0] = INVSLOT_AMMO,
    [1] = INVSLOT_HEAD,
    [2] = INVSLOT_NECK,
    [3] = INVSLOT_SHOULDER,
    [4] = INVSLOT_BODY,
    [5] = INVSLOT_CHEST,
    [6] = INVSLOT_WAIST,
    [7] = INVSLOT_LEGS,
    [8] = INVSLOT_FEET,
    [9] = INVSLOT_WRIST,
    [10] = INVSLOT_HAND,
    [11] = INVSLOT_FINGER1,
    [12] = INVSLOT_FINGER2,
    [13] = INVSLOT_TRINKET1,
    [14] = INVSLOT_TRINKET2,
    [15] = INVSLOT_BACK,
    [16] = INVSLOT_MAINHAND,
    [17] = INVSLOT_OFFHAND,
    [18] = INVSLOT_RANGED,
    [19] = INVSLOT_TABARD,
}

local function NormalizeItemLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end
    return link:match("|H(item:[^|]+)|h") or link:match("(item:[^|]+)") or nil
end

local function ExtractItemID(value)
    if type(value) == "number" then
        return value > 0 and value or nil
    end
    if type(value) ~= "string" or value == "" or value == "0" then
        return nil
    end
    local fromLink = value:match("item:(%d+)")
    if fromLink then
        return tonumber(fromLink)
    end
    local fromItemRackID = value:match("^(%-?%d+)")
    if fromItemRackID then
        local itemID = tonumber(fromItemRackID)
        return itemID and itemID > 0 and itemID or nil
    end
    return tonumber(value)
end

local function GetItemRackID(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if value:match("^%-?%d+:") then
        return value
    end
    local itemRack = _G.ItemRack
    if itemRack and type(itemRack.GetIRString) == "function" then
        local ok, id = pcall(itemRack.GetIRString, value)
        if ok and id and id ~= 0 and id ~= "0" then
            return id
        end
    end
    return nil
end

local function AddItem(target, value)
    local itemID = ExtractItemID(value)
    local itemLink = NormalizeItemLink(value)
    local itemRackID = GetItemRackID(value)
    if itemID then
        target.itemIDs[itemID] = true
    end
    if itemLink then
        target.itemLinks[itemLink] = true
    end
    if itemRackID then
        target.itemRackIDs[itemRackID] = true
    end
end

local function GetEquippedItemID(slotID)
    if not slotID or not GetInventoryItemID then
        return nil
    end
    local itemID = GetInventoryItemID("player", slotID)
    return itemID ~= 0 and itemID or nil
end

local function GetEquippedItemLink(slotID)
    if not slotID or not GetInventoryItemLink then
        return nil
    end
    return NormalizeItemLink(GetInventoryItemLink("player", slotID))
end

local function SlotMatches(slotID, desired)
    slotID = tonumber(slotID) or slotID
    if not slotID or desired == nil or desired == false or desired == 0 or desired == "0" or desired == "" then
        return true
    end
    local desiredLink = NormalizeItemLink(desired)
    if desiredLink then
        return GetEquippedItemLink(slotID) == desiredLink
    end
    local itemID = ExtractItemID(desired)
    if itemID then
        return GetEquippedItemID(slotID) == itemID
    end
    return true
end

local function BuildSetPayload(source, key, name, isEquipped)
    return {
        source = source,
        key = tostring(key or name or source),
        name = name,
        itemIDs = {},
        itemLinks = {},
        itemRackIDs = {},
        isEquipped = isEquipped == true,
    }
end

local function PayloadHasItems(payload)
    for _ in pairs(payload.itemIDs) do
        return true
    end
    for _ in pairs(payload.itemLinks) do
        return true
    end
    for _ in pairs(payload.itemRackIDs) do
        return true
    end
    return false
end

local function AddCategory(out, seen, payload)
    if not payload or not payload.name or payload.name == "" or not PayloadHasItems(payload) then
        return
    end

    local signatureParts = {}
    for itemID in pairs(payload.itemIDs) do
        signatureParts[#signatureParts + 1] = "i" .. tostring(itemID)
    end
    if #signatureParts == 0 then
        for itemLink in pairs(payload.itemLinks) do
            signatureParts[#signatureParts + 1] = "l" .. itemLink
        end
        for itemRackID in pairs(payload.itemRackIDs) do
            signatureParts[#signatureParts + 1] = "r" .. itemRackID
        end
    end
    table.sort(signatureParts)
    local signature = tostring(payload.name):lower() .. ":" .. table.concat(signatureParts, ",")
    local existing = seen[signature]
    if existing then
        for itemID in pairs(payload.itemIDs) do
            existing._equipmentSetItemIDs[itemID] = true
        end
        for itemLink in pairs(payload.itemLinks) do
            existing._equipmentSetItemLinks[itemLink] = true
        end
        for itemRackID in pairs(payload.itemRackIDs) do
            existing._equipmentSetItemRackIDs[itemRackID] = true
        end
        if payload.isEquipped ~= true then
            existing.hidden = false
        end
        return
    end

    local category = {
        id = "equipmentSet:" .. payload.source .. ":" .. payload.key,
        name = payload.name,
        enabled = true,
        hidden = payload.isEquipped == true,
        rules = {
            equipmentSetCategory = true,
        },
        _equipmentSetItemIDs = payload.itemIDs,
        _equipmentSetItemLinks = payload.itemLinks,
        _equipmentSetItemRackIDs = payload.itemRackIDs,
        _equipmentSetSource = payload.source,
    }
    seen[signature] = category
    out[#out + 1] = category
end

local function GetOptionsConfig()
    local lunaBags = addon.LunaBags
    local plugins = lunaBags and lunaBags.db and lunaBags.db.profile and lunaBags.db.profile.plugins
    if type(plugins) ~= "table" then
        return {}
    end
    plugins.equipmentSetCategoriesOptions = plugins.equipmentSetCategoriesOptions or {}
    return plugins.equipmentSetCategoriesOptions
end

local function IsSourceEnabled(sourceKey)
    local options = GetOptionsConfig()
    local value = options[sourceKey]
    return value ~= false
end

local GetExtraStatsEquipmentModule

local function IsExtraStatsAvailable()
    return GetExtraStatsEquipmentModule() ~= nil
end

local function IsItemRackAvailable()
    return type(_G.ItemRackUser) == "table" and type(_G.ItemRackUser.Sets) == "table"
end

local function IsSupportedIntegrationAvailable()
    return IsExtraStatsAvailable() or IsItemRackAvailable()
end

local function IsIgnored(ignoredSlots, slotID)
    if type(ignoredSlots) ~= "table" or not slotID then
        return false
    end
    slotID = tonumber(slotID) or slotID
    return ignoredSlots[slotID] == true or ignoredSlots[tostring(slotID)] == true
end

local function CollectBlizzardSets(out, seen)
    if not IsSourceEnabled("blizzard") then
        return
    end

    local manager = C_EquipmentSet
    local getIDs = manager and manager.GetEquipmentSetIDs or _G.GetEquipmentSetIDs
    local getInfo = manager and manager.GetEquipmentSetInfo or _G.GetEquipmentSetInfo
    local getItemIDs = manager and manager.GetItemIDs or _G.GetEquipmentSetItemIDs
    local getIgnoredSlots = manager and manager.GetIgnoredSlots or _G.GetEquipmentSetIgnoreSlots

    if type(getIDs) ~= "function" or type(getInfo) ~= "function" or type(getItemIDs) ~= "function" then
        return
    end

    local okIDs, setIDs = pcall(getIDs)
    if not okIDs or type(setIDs) ~= "table" then
        return
    end

    for _, setID in ipairs(setIDs) do
        local okInfo, name, _, realID, isEquipped = pcall(getInfo, setID)
        if okInfo and name then
            local payload = BuildSetPayload("blizzard", realID or setID, name, isEquipped)
            local okItems, itemIDs = pcall(getItemIDs, setID)
            local ignoredSlots = {}
            local canInferEquipped = isEquipped == nil
            local hasComparableSlot = false
            local allComparableSlotsEquipped = true
            if type(getIgnoredSlots) == "function" then
                local okIgnored, ignored = pcall(getIgnoredSlots, setID)
                if okIgnored and type(ignored) == "table" then
                    ignoredSlots = ignored
                end
            end
            if okItems and type(itemIDs) == "table" then
                for slotID, itemID in pairs(itemIDs) do
                    if not IsIgnored(ignoredSlots, slotID) then
                        AddItem(payload, itemID)
                        if canInferEquipped and ExtractItemID(itemID) then
                            hasComparableSlot = true
                            if not SlotMatches(slotID, itemID) then
                                allComparableSlotsEquipped = false
                            end
                        end
                    end
                end
            end
            if canInferEquipped and hasComparableSlot then
                payload.isEquipped = allComparableSlotsEquipped
            end
            AddCategory(out, seen, payload)
        end
    end
end

function GetExtraStatsEquipmentModule()
    local extraStats = _G.ExtraStats
    if not extraStats or type(extraStats.GetModule) ~= "function" then
        return nil
    end
    local ok, module = pcall(extraStats.GetModule, extraStats, "EquipmentSet", true)
    if ok then
        return module
    end
    return nil
end

local function CollectExtraStatsSets(out, seen)
    if not IsSourceEnabled("extraStats") then
        return
    end

    local equipment = GetExtraStatsEquipmentModule()
    if not equipment then
        return
    end

    local sets = equipment.db and equipment.db.char and equipment.db.char.sets
    if type(sets) ~= "table" then
        return
    end

    for setID, set in ipairs(sets) do
        if type(set) == "table" and set.name then
            local isEquipped = false
            if type(equipment.GetEquipmentSetInfo) == "function" then
                local ok, _, _, _, equipped = pcall(equipment.GetEquipmentSetInfo, equipment, setID)
                isEquipped = ok and equipped == true
            end
            local payload = BuildSetPayload("extrastats", setID, set.name, isEquipped)
            for slotName, itemID in pairs(set.items or {}) do
                local slotID = SLOT_ID_BY_NAME[slotName]
                if not IsIgnored(set.ignoredSlots, slotID) then
                    AddItem(payload, itemID)
                end
            end
            for slotName, itemLink in pairs(set.itemLinks or {}) do
                local slotID = SLOT_ID_BY_NAME[slotName]
                if not IsIgnored(set.ignoredSlots, slotID) then
                    AddItem(payload, itemLink)
                end
            end
            AddCategory(out, seen, payload)
        end
    end
end

local function GetItemRackSetItems(set)
    if type(set) ~= "table" then
        return nil
    end
    if type(set.equip) == "table" then
        return set.equip
    end
    if type(set.items) == "table" then
        return set.items
    end
    return set
end

local function ResolveItemRackSlot(key)
    if type(key) == "number" then
        return ITEMRACK_SLOT_BY_INDEX[key] or SLOT_IDS[key]
    end
    if type(key) == "string" then
        return SLOT_ID_BY_NAME[key] or ITEMRACK_SLOT_BY_INDEX[tonumber(key)]
    end
    return nil
end

local function CollectItemRackSets(out, seen)
    if not IsSourceEnabled("itemRack") then
        return
    end

    local itemRack = _G.ItemRackUser
    local itemRackAddon = _G.ItemRack
    local sets = itemRack and itemRack.Sets
    if type(sets) ~= "table" then
        return
    end

    for setName, set in pairs(sets) do
        local includeHidden = GetOptionsConfig().includeHiddenItemRackSets == true
        local isInternalSet = type(setName) == "string" and setName:sub(1, 1) == "~"
        local isHidden = itemRackAddon and itemRackAddon.IsHidden and itemRackAddon.IsHidden(setName)
        if type(set) == "table" and not isInternalSet and (includeHidden or not isHidden) then
            local equipped = true
            if itemRackAddon and type(itemRackAddon.IsSetEquipped) == "function" then
                local ok, isEquipped = pcall(itemRackAddon.IsSetEquipped, setName)
                if ok and isEquipped ~= nil then
                    equipped = isEquipped == true
                end
            end
            local payload = BuildSetPayload("itemrack", setName, set.name or setName, equipped)
            local items = GetItemRackSetItems(set)
            for key, value in pairs(items or {}) do
                local slotID = ResolveItemRackSlot(key)
                if slotID then
                    AddItem(payload, value)
                    if not SlotMatches(slotID, value) then
                        payload.isEquipped = false
                    end
                end
            end
            AddCategory(out, seen, payload)
        end
    end
end

local function PluginEnabled()
    return addon.Plugins and addon.Plugins.IsEnabled and addon.Plugins:IsEnabled("equipmentSetCategories")
end

local function GetCurrentCharacterKey()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    if not name or name == "" then
        return nil
    end
    return tostring(name) .. "-" .. tostring(realm or "")
end

local function NormalizeCharacterKey(key)
    return key and tostring(key):lower():gsub("%s+", "") or nil
end

local function IsViewingCurrentScope(scope)
    local current = NormalizeCharacterKey(GetCurrentCharacterKey())
    if scope == "bags" and addon.OneBag and addon.OneBag.viewCharacterKey then
        return NormalizeCharacterKey(addon.OneBag.viewCharacterKey) == current
    end
    if scope == "bank" and addon.OneBank and addon.OneBank.viewMode and addon.OneBank.viewCharacterKey then
        return NormalizeCharacterKey(addon.OneBank.viewCharacterKey) == current
    end
    return true
end

function Plugin:GetCategories(scope)
    if scope ~= "bags" and scope ~= "bank" then
        return {}
    end
    if not PluginEnabled() then
        return {}
    end
    if not IsViewingCurrentScope(scope) then
        return {}
    end

    local now = GetTime and GetTime() or 0
    local fingerprint = self:GetFingerprint()
    self._categoryCache = self._categoryCache or {}
    local cached = self._categoryCache[scope]
    if cached and cached.fingerprint == fingerprint and now > 0 and (now - cached.at) < 0.5 then
        return cached.list
    end

    local out = {}
    local seen = {}
    CollectBlizzardSets(out, seen)
    CollectExtraStatsSets(out, seen)
    CollectItemRackSets(out, seen)
    self._categoryCache[scope] = {
        at = now,
        fingerprint = fingerprint,
        list = out,
    }
    return out
end

function Plugin:GetFingerprint()
    local parts = {}

    local manager = C_EquipmentSet
    local getIDs = manager and manager.GetEquipmentSetIDs or _G.GetEquipmentSetIDs
    local getInfo = manager and manager.GetEquipmentSetInfo or _G.GetEquipmentSetInfo
    local getItemIDs = manager and manager.GetItemIDs or _G.GetEquipmentSetItemIDs
    if IsSourceEnabled("blizzard") and type(getIDs) == "function" and type(getInfo) == "function" then
        local okIDs, setIDs = pcall(getIDs)
        if okIDs and type(setIDs) == "table" then
            for _, setID in ipairs(setIDs) do
                local okInfo, name, _, realID, isEquipped = pcall(getInfo, setID)
                if okInfo and name then
                    local itemParts = {}
                    if type(getItemIDs) == "function" then
                        local okItems, itemIDs = pcall(getItemIDs, setID)
                        if okItems and type(itemIDs) == "table" then
                            for slotID, itemID in pairs(itemIDs) do
                                itemParts[#itemParts + 1] = tostring(slotID) .. "=" .. tostring(itemID)
                            end
                        end
                    end
                    table.sort(itemParts)
                    parts[#parts + 1] = "b:" .. tostring(realID or setID) .. ":" .. tostring(name) .. ":" .. tostring(isEquipped == true) .. ":" .. table.concat(itemParts, ",")
                end
            end
        end
    end

    local equipment = IsSourceEnabled("extraStats") and GetExtraStatsEquipmentModule() or nil
    local sets = equipment and equipment.db and equipment.db.char and equipment.db.char.sets
    if type(sets) == "table" then
        for setID, set in ipairs(sets) do
            if type(set) == "table" and set.name then
                local itemParts = {}
                for slotName, itemID in pairs(set.items or {}) do
                    itemParts[#itemParts + 1] = tostring(slotName) .. "=" .. tostring(itemID)
                end
                for slotName, itemLink in pairs(set.itemLinks or {}) do
                    itemParts[#itemParts + 1] = tostring(slotName) .. "=" .. tostring(itemLink)
                end
                table.sort(itemParts)
                parts[#parts + 1] = "e:" .. tostring(setID) .. ":" .. tostring(set.name) .. ":" .. table.concat(itemParts, ",")
            end
        end
    end

    local itemRackSets = IsSourceEnabled("itemRack") and _G.ItemRackUser and _G.ItemRackUser.Sets or nil
    if type(itemRackSets) == "table" then
        for setName, set in pairs(itemRackSets) do
            if type(set) == "table" and type(setName) == "string" and setName:sub(1, 1) ~= "~" then
                local itemParts = {}
                local items = GetItemRackSetItems(set)
                for slotID, itemID in pairs(items or {}) do
                    itemParts[#itemParts + 1] = tostring(slotID) .. "=" .. tostring(itemID)
                end
                table.sort(itemParts)
                parts[#parts + 1] = "i:" .. tostring(setName) .. ":" .. table.concat(itemParts, ",")
            end
        end
    end

    table.sort(parts)
    return table.concat(parts, "|")
end

function Plugin:Matches(item, category)
    if not item or not category then
        return false
    end
    local itemKey = item.itemLink or item.itemID
    local categoryKey = category.id or category.name
    if itemKey and categoryKey then
        local fingerprint = self:GetFingerprint()
        self._matchCache = self._matchCache or {}
        local cacheKey = table.concat({ tostring(fingerprint), tostring(categoryKey), tostring(itemKey) }, "|")
        local cached = self._matchCache[cacheKey]
        if cached ~= nil then
            return cached == true
        end
        local itemLink = NormalizeItemLink(item.itemLink)
        local itemID = tonumber(item.itemID)
        local itemRackID = item and item.itemLink and GetItemRackID(item.itemLink)
        local matched = (itemRackID and category._equipmentSetItemRackIDs and category._equipmentSetItemRackIDs[itemRackID])
            or (itemLink and category._equipmentSetItemLinks and category._equipmentSetItemLinks[itemLink])
            or (itemID and category._equipmentSetItemIDs and category._equipmentSetItemIDs[itemID] == true)
        self._matchCache[cacheKey] = matched == true
        return matched == true
    end

    local itemLink = NormalizeItemLink(item.itemLink)
    local itemID = tonumber(item.itemID)
    local itemRackID = item and item.itemLink and GetItemRackID(item.itemLink)
    if itemRackID and category._equipmentSetItemRackIDs and category._equipmentSetItemRackIDs[itemRackID] then
        return true
    end
    if itemLink and category._equipmentSetItemLinks and category._equipmentSetItemLinks[itemLink] then
        return true
    end
    return itemID and category._equipmentSetItemIDs and category._equipmentSetItemIDs[itemID] == true
end

function Plugin:GetOptions(ctx)
    return {
        type = "group",
        name = "Equipment Sets",
        order = 10,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable equipment set categories",
                order = 0,
                get = function() return ctx.getEnabled(true) end,
                set = function(_, value) ctx.setEnabled(value) end,
            },
            availability = {
                type = "description",
                name = function()
                    if IsSupportedIntegrationAvailable() then
                        return "ExtraStats or ItemRack detected. Optional equipment set integrations are available."
                    end
                    return "ExtraStats and ItemRack are not loaded. Blizzard equipment sets can still be used if available."
                end,
                order = 0.5,
                fontSize = "medium",
            },
            sources = {
                type = "group",
                name = "Sources",
                inline = true,
                order = 1,
                args = {
                    blizzard = {
                        type = "toggle",
                        name = "Blizzard",
                        order = 1,
                        get = function() return ctx.get("blizzard", true) end,
                        set = function(_, value) ctx.set("blizzard", value) end,
                    },
                    extraStats = {
                        type = "toggle",
                        name = "ExtraStats",
                        order = 2,
                        get = function() return ctx.get("extraStats", true) end,
                        set = function(_, value) ctx.set("extraStats", value) end,
                    },
                    itemRack = {
                        type = "toggle",
                        name = "ItemRack",
                        order = 3,
                        get = function() return ctx.get("itemRack", true) end,
                        set = function(_, value) ctx.set("itemRack", value) end,
                    },
                },
            },
            itemRackOptions = {
                type = "group",
                name = "ItemRack",
                inline = true,
                order = 2,
                args = {
                    includeHiddenItemRackSets = {
                        type = "toggle",
                        name = "Include hidden sets",
                        desc = "Show ItemRack sets that are hidden from ItemRack menus.",
                        order = 1,
                        get = function() return ctx.get("includeHiddenItemRackSets", false) end,
                        set = function(_, value) ctx.set("includeHiddenItemRackSets", value) end,
                    },
                },
            },
        },
    }
end

local function RefreshOpenWindows()
    Plugin._categoryCache = nil
    Plugin._matchCache = nil
    if addon.Categories and addon.Categories.InvalidateMatchCache then
        addon.Categories:InvalidateMatchCache()
    end
    if addon.OneBag then
        addon.OneBag._layoutModel = nil
        if addon.OneBag.InvalidateSlotCache then
            addon.OneBag:InvalidateSlotCache()
        end
    end
    if addon.OneBank then
        addon.OneBank._layoutModel = nil
        if addon.OneBank.InvalidateSlotCache then
            addon.OneBank:InvalidateSlotCache()
        end
    end
    if addon.LunaBags and addon.LunaBags.QueueOpenWindowRefresh then
        addon.LunaBags:QueueOpenWindowRefresh()
    end
end

local eventFrame
local itemRackListenersRegistered = false
local itemRackHooks = {}
local extraStatsListenerRegistered = false
local blizzardHooksRegistered = false

local function RegisterBlizzardSetHooks()
    if blizzardHooksRegistered or type(hooksecurefunc) ~= "function" then
        return
    end

    local hooked = false
    local manager = _G.C_EquipmentSet
    if type(manager) == "table" then
        local methods = {
            "CreateEquipmentSet",
            "DeleteEquipmentSet",
            "ModifyEquipmentSet",
            "SaveEquipmentSet",
        }
        for _, method in ipairs(methods) do
            if type(manager[method]) == "function" then
                local ok = pcall(hooksecurefunc, manager, method, RefreshOpenWindows)
                hooked = hooked or ok
            end
        end
    end

    local globals = {
        "CreateEquipmentSet",
        "DeleteEquipmentSet",
        "ModifyEquipmentSet",
        "SaveEquipmentSet",
    }
    for _, name in ipairs(globals) do
        if type(_G[name]) == "function" then
            local ok = pcall(hooksecurefunc, name, RefreshOpenWindows)
            hooked = hooked or ok
        end
    end

    blizzardHooksRegistered = hooked
end

local function RegisterExtraStatsListener()
    if extraStatsListenerRegistered then
        return
    end
    local extraStats = _G.ExtraStats
    if extraStats and type(extraStats.On) == "function" then
        pcall(extraStats.On, extraStats, "gear.update", RefreshOpenWindows)
        extraStatsListenerRegistered = true
    end
end

local function RegisterItemRackListeners()
    local itemRack = _G.ItemRack
    if (not itemRackListenersRegistered) and itemRack and type(itemRack.RegisterExternalEventListener) == "function" then
        pcall(itemRack.RegisterExternalEventListener, itemRack, "ITEMRACK_SET_SAVED", RefreshOpenWindows)
        pcall(itemRack.RegisterExternalEventListener, itemRack, "ITEMRACK_SET_DELETED", RefreshOpenWindows)
        itemRackListenersRegistered = true
    end

    if type(hooksecurefunc) ~= "function" then
        return
    end

    if itemRack then
        local methods = {
            "AddHidden",
            "RemoveHidden",
            "ToggleHidden",
        }
        for _, method in ipairs(methods) do
            local key = "ItemRack." .. method
            if not itemRackHooks[key] and type(itemRack[method]) == "function" then
                local ok = pcall(hooksecurefunc, itemRack, method, RefreshOpenWindows)
                if ok then
                    itemRackHooks[key] = true
                end
            end
        end
    end

    local itemRackOpt = _G.ItemRackOpt
    if itemRackOpt then
        local methods = {
            "SaveSet",
            "DeleteSet",
            "HideSet",
            "LoadSet",
        }
        for _, method in ipairs(methods) do
            local key = "ItemRackOpt." .. method
            if not itemRackHooks[key] and type(itemRackOpt[method]) == "function" then
                local ok = pcall(hooksecurefunc, itemRackOpt, method, RefreshOpenWindows)
                if ok then
                    itemRackHooks[key] = true
                end
            end
        end
    end
end

local function EnsureEventFrame()
    if eventFrame or not CreateFrame then
        return
    end
    eventFrame = CreateFrame("Frame")
    local events = {
        "ADDON_LOADED",
        "PLAYER_EQUIPMENT_CHANGED",
        "EQUIPMENT_SETS_CHANGED",
        "PLAYER_ENTERING_WORLD",
    }
    for _, event in ipairs(events) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    eventFrame:SetScript("OnEvent", function()
        RegisterBlizzardSetHooks()
        RegisterExtraStatsListener()
        RegisterItemRackListeners()
        RefreshOpenWindows()
    end)

    RegisterBlizzardSetHooks()
    RegisterExtraStatsListener()
    RegisterItemRackListeners()
end

if addon.Categories then
    addon.Categories:RegisterMatcher("equipmentSetCategory", function(item, category)
        return Plugin:Matches(item, category)
    end)
    addon.Categories:RegisterProvider("equipmentSetCategories", Plugin)
end

EnsureEventFrame()
addon.LunaBags:RegisterPlugin(Plugin)
