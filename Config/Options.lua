local _, ns = ...
local LunaBags = ns.LunaBags
local options
local BuildSortingOptions
local RefreshCategoryOptions
local RefreshProfileOptions
local profileCallbacksRegistered = false

local function RefreshOneBag(deferred)
    if ns.OneBag then
        ns.OneBag:ApplySettings()
        if ns.OneBag.frame and ns.OneBag.frame:IsShown() then
            ns.OneBag:Refresh()
            if deferred and C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if ns.OneBag and ns.OneBag.frame and ns.OneBag.frame:IsShown() then
                        ns.OneBag:ApplySettings()
                        ns.OneBag:Refresh()
                    end
                end)
            end
        end
    end
end
local function RefreshOneBank()
    if ns.OneBank then
        ns.OneBank:ApplySettings()
        if ns.OneBank.frame and ns.OneBank.frame:IsShown() then
            ns.OneBank:Refresh()
        end
    end
end

local function GetOneBagSetting(key, fallback)
    LunaBags.db.profile.oneBag = LunaBags.db.profile.oneBag or {}
    local value = LunaBags.db.profile.oneBag[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetOneBagSetting(key, value)
    LunaBags.db.profile.oneBag = LunaBags.db.profile.oneBag or {}
    LunaBags.db.profile.oneBag[key] = value
    RefreshOneBag()
end

local function GetOneBankSetting(key, fallback)
    LunaBags.db.profile.oneBank = LunaBags.db.profile.oneBank or {}
    local value = LunaBags.db.profile.oneBank[key]
    if value == nil then
        return fallback
    end
    return value
end
local function SetOneBankSetting(key, value)
    LunaBags.db.profile.oneBank = LunaBags.db.profile.oneBank or {}
    LunaBags.db.profile.oneBank[key] = value
    RefreshOneBank()
end

local function GetUISetting(key, fallback)
    LunaBags.db.profile.ui = LunaBags.db.profile.ui or {}
    local value = LunaBags.db.profile.ui[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetUISetting(key, value)
    LunaBags.db.profile.ui = LunaBags.db.profile.ui or {}
    LunaBags.db.profile.ui[key] = value
    RefreshOneBag(true)
    RefreshOneBank()
end

local function GetUIColorSetting(key, r, g, b)
    local color = GetUISetting(key, nil)
    if type(color) ~= "table" then
        return r, g, b
    end
    return tonumber(color.r or color[1]) or r,
        tonumber(color.g or color[2]) or g,
        tonumber(color.b or color[3]) or b
end

local function SetUIColorSetting(key, r, g, b)
    SetUISetting(key, { r = r, g = g, b = b })
end

local function ResetUIColorAndOpacitySettings()
    LunaBags.db.profile.ui = LunaBags.db.profile.ui or {}
    LunaBags.db.profile.ui.windowColor = { r = 0.12, g = 0.12, b = 0.12 }
    LunaBags.db.profile.ui.windowOpacity = 0.72
    LunaBags.db.profile.ui.headerColor = { r = 0.07, g = 0.07, b = 0.07 }
    LunaBags.db.profile.ui.headerOpacity = 0.78
    LunaBags.db.profile.ui.itemFrameColor = { r = 0.13, g = 0.13, b = 0.13 }
    LunaBags.db.profile.ui.itemFrameOpacity = 0.92
    RefreshOneBag(true)
    RefreshOneBank()
end

local function GetPluginSetting(key, fallback)
    LunaBags.db.profile.plugins = LunaBags.db.profile.plugins or {}
    local value = LunaBags.db.profile.plugins[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetPluginSetting(key, value)
    LunaBags.db.profile.plugins = LunaBags.db.profile.plugins or {}
    LunaBags.db.profile.plugins[key] = value
    RefreshOneBag()
    RefreshOneBank()
end

local function GetSortingSetting(key, fallback)
    LunaBags.db.profile.sorting = LunaBags.db.profile.sorting or {}
    local value = LunaBags.db.profile.sorting[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetSortingSetting(key, value)
    LunaBags.db.profile.sorting = LunaBags.db.profile.sorting or {}
    LunaBags.db.profile.sorting[key] = value
end

local DEFAULT_SORT_RULES = {
    { key = "priority", direction = "asc", enabled = true },
    { key = "quality", direction = "desc", enabled = true },
    { key = "itemLevel", direction = "desc", enabled = true },
    { key = "classOrder", direction = "asc", enabled = true },
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "equipLoc", direction = "asc", enabled = true },
    { key = "name", direction = "asc", enabled = true },
    { key = "itemID", direction = "asc", enabled = true },
    { key = "count", direction = "desc", enabled = true },
}

local SORT_RULE_VALUES = {
    priority = "Priority Items / Mounts",
    quality = "Quality",
    itemLevel = "Item Level",
    classOrder = "Default Class Group",
    classID = "Item Class",
    subClassID = "Item Subclass",
    equipLoc = "Equip Slot",
    name = "Name",
    itemID = "Item ID",
    count = "Stack Count",
    sellPrice = "Sell Price",
}

local SORT_DIRECTION_VALUES = {
    asc = "Ascending",
    desc = "Descending",
}

local function CopyDefaultSortRules()
    local rules = {}
    for index, rule in ipairs(DEFAULT_SORT_RULES) do
        rules[index] = {
            key = rule.key,
            direction = rule.direction,
            enabled = rule.enabled ~= false,
        }
    end
    return rules
end

local function GetSortRulesConfig()
    if not LunaBags.db or not LunaBags.db.profile then
        return CopyDefaultSortRules()
    end
    LunaBags.db.profile.sorting = LunaBags.db.profile.sorting or {}
    if type(LunaBags.db.profile.sorting.rules) ~= "table" or #LunaBags.db.profile.sorting.rules == 0 then
        LunaBags.db.profile.sorting.rules = CopyDefaultSortRules()
    end
    return LunaBags.db.profile.sorting.rules
end

local function RefreshSortingOptions()
    if options and options.args and options.args.sorting then
        options.args.sorting.args = BuildSortingOptions()
    end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange("LunaBags")
    end
end

local function AddSortRule()
    local rules = GetSortRulesConfig()
    rules[#rules + 1] = { key = "name", direction = "asc", enabled = true }
    RefreshSortingOptions()
end

local function MoveSortRule(index, direction)
    local rules = GetSortRulesConfig()
    local target = index + direction
    if rules[index] and rules[target] then
        rules[index], rules[target] = rules[target], rules[index]
        RefreshSortingOptions()
    end
end

local function RemoveSortRule(index)
    local rules = GetSortRulesConfig()
    if rules[index] then
        table.remove(rules, index)
        RefreshSortingOptions()
    end
end

local ITEM_CLASS_OPTIONS = {
    [0] = "Consumable",
    [1] = "Container",
    [2] = "Weapon",
    [3] = "Gem",
    [4] = "Armor",
    [5] = "Reagent",
    [6] = "Projectile",
    [7] = "Trade Goods",
    [9] = "Recipe",
    [11] = "Quiver",
    [12] = "Quest",
    [13] = "Key",
    [15] = "Miscellaneous",
}

local ITEM_SUBCLASS_OPTIONS = {
    [0] = {
        [0] = "Consumable",
        [1] = "Potion",
        [2] = "Elixir",
        [3] = "Flask",
        [4] = "Scroll",
        [5] = "Food & Drink",
        [6] = "Item Enhancement",
        [7] = "Bandage",
        [8] = "Other",
    },
    [1] = {
        [0] = "Bag",
        [1] = "Soul Bag",
        [2] = "Herb Bag",
        [3] = "Enchanting Bag",
        [4] = "Engineering Bag",
        [5] = "Gem Bag",
        [6] = "Mining Bag",
        [7] = "Leatherworking Bag",
        [8] = "Inscription Bag",
        [9] = "Tackle Box",
    },
    [2] = {
        [0] = "Axe",
        [1] = "Axe",
        [2] = "Bow",
        [3] = "Gun",
        [4] = "Mace",
        [5] = "Mace",
        [6] = "Polearm",
        [7] = "Sword",
        [8] = "Sword",
        [10] = "Staff",
        [13] = "Fist Weapon",
        [14] = "Miscellaneous",
        [15] = "Dagger",
        [16] = "Thrown",
        [18] = "Crossbow",
        [19] = "Wand",
        [20] = "Fishing Pole",
    },
    [3] = {
        [0] = "Red",
        [1] = "Blue",
        [2] = "Yellow",
        [3] = "Purple",
        [4] = "Green",
        [5] = "Orange",
        [6] = "Meta",
        [7] = "Simple",
        [8] = "Prismatic",
    },
    [4] = {
        [0] = "Miscellaneous",
        [1] = "Cloth",
        [2] = "Leather",
        [3] = "Mail",
        [4] = "Plate",
        [6] = "Shield",
        [7] = "Libram",
        [8] = "Idol",
        [9] = "Totem",
    },
    [5] = {
        [0] = "Reagent",
    },
    [6] = {
        [2] = "Arrow",
        [3] = "Bullet",
    },
    [7] = {
        [0] = "Trade Goods",
        [1] = "Parts",
        [2] = "Explosives",
        [3] = "Devices",
        [4] = "Jewelcrafting",
        [5] = "Cloth",
        [6] = "Leather",
        [7] = "Metal & Stone",
        [8] = "Meat",
        [9] = "Herb",
        [10] = "Elemental",
        [11] = "Other",
        [12] = "Enchanting",
        [13] = "Materials",
    },
    [9] = {
        [0] = "Book",
        [1] = "Leatherworking",
        [2] = "Tailoring",
        [3] = "Engineering",
        [4] = "Blacksmithing",
        [5] = "Cooking",
        [6] = "Alchemy",
        [7] = "First Aid",
        [8] = "Enchanting",
        [9] = "Fishing",
        [10] = "Jewelcrafting",
    },
    [11] = {
        [2] = "Quiver",
        [3] = "Ammo Pouch",
    },
    [12] = {
        [0] = "Quest",
    },
    [13] = {
        [0] = "Key",
        [1] = "Lockpick",
    },
    [15] = {
        [0] = "Junk",
        [1] = "Reagent",
        [2] = "Companion Pet",
        [3] = "Holiday",
        [4] = "Other",
        [5] = "Mount",
    },
}

local function GetItemClassName(classID)
    if type(GetItemClassInfo) == "function" then
        local name = GetItemClassInfo(classID)
        if name then return name end
    end
    return ITEM_CLASS_OPTIONS[classID] or tostring(classID)
end

local function GetItemSubClassName(classID, subClassID)
    if type(GetItemSubClassInfo) == "function" then
        local name = GetItemSubClassInfo(classID, subClassID)
        if name then return name end
    end
    local classOptions = ITEM_SUBCLASS_OPTIONS[classID]
    return (classOptions and classOptions[subClassID]) or tostring(subClassID)
end

local function CSVHas(csv, value)
    if type(csv) ~= "string" then return false end
    local needle = tostring(value)
    for token in csv:gmatch("[^,%s]+") do
        if token == needle then
            return true
        end
    end
    return false
end

local function CSVSet(csv, value, enabled)
    local needle = tostring(value)
    local seen = {}
    local out = {}
    if type(csv) == "string" then
        for token in csv:gmatch("[^,%s]+") do
            if token ~= needle and not seen[token] then
                seen[token] = true
                out[#out + 1] = token
            end
        end
    end
    if enabled and not seen[needle] then
        out[#out + 1] = needle
    end
    return #out > 0 and table.concat(out, ",") or nil
end

local function CSVAny(csv)
    return type(csv) == "string" and csv:match("[^,%s]+") ~= nil
end

local function BuildClassValues()
    local values = {}
    for classID in pairs(ITEM_CLASS_OPTIONS) do
        values[tostring(classID)] = GetItemClassName(classID)
    end
    return values
end

local function BuildSubclassValues(classCSV)
    local values = {}
    for classID in pairs(ITEM_CLASS_OPTIONS) do
        if CSVHas(classCSV, classID) then
            local subclasses = ITEM_SUBCLASS_OPTIONS[classID]
            if subclasses then
                local className = GetItemClassName(classID)
                for subClassID in pairs(subclasses) do
                    local key = tostring(classID) .. ":" .. tostring(subClassID)
                    values[key] = className .. " - " .. GetItemSubClassName(classID, subClassID)
                end
            end
        end
    end
    return values
end

local function RemoveSubclassSelectionsForClass(subClassPairs, classID)
    if type(subClassPairs) ~= "string" then return nil end
    local prefix = tostring(classID) .. ":"
    local out = {}
    for token in subClassPairs:gmatch("[^,%s]+") do
        if token:sub(1, #prefix) ~= prefix then
            out[#out + 1] = token
        end
    end
    return #out > 0 and table.concat(out, ",") or nil
end

local selectedCategoryScope = "bags"

local function GetCategoryConfig()
    if not ns.Categories or not ns.Categories.GetConfig then
        return { enabled = false, list = {}, columns = 1 }
    end
    return ns.Categories:GetConfig(selectedCategoryScope) or { enabled = false, list = {}, columns = 1 }
end

local function RefreshCategories()
    if RefreshCategoryOptions then
        RefreshCategoryOptions()
    end
    RefreshOneBag(true)
    RefreshOneBank()
end

local function RefreshAllOpenWindows()
    RefreshOneBag(true)
    RefreshOneBank()
end

local function HandleProfileChanged()
    RefreshSortingOptions()
    if RefreshCategoryOptions then
        RefreshCategoryOptions()
    end
    if RefreshProfileOptions then
        RefreshProfileOptions()
    end
    RefreshAllOpenWindows()
end

local function EnsureProfileCallbacks()
    if profileCallbacksRegistered or not LunaBags.db or not LunaBags.db.RegisterCallback then
        return
    end
    profileCallbacksRegistered = true
    LunaBags.db:RegisterCallback("OnProfileChanged", HandleProfileChanged)
    LunaBags.db:RegisterCallback("OnProfileCopied", HandleProfileChanged)
    LunaBags.db:RegisterCallback("OnProfileReset", HandleProfileChanged)
    LunaBags.db:RegisterCallback("OnProfileDeleted", HandleProfileChanged)
end

local function BuildCategoryOptions()
    local cfg = GetCategoryConfig()
    local args = {
        categoriesEnabled = {
            type = "toggle",
            name = "Enable Category Sections",
            order = 1,
            get = function() return cfg.enabled == true end,
            set = function(_, value)
                cfg.enabled = value == true
                RefreshCategories()
            end,
        },
        categoryScope = {
            type = "select",
            name = "Category Scope",
            order = 2,
            values = {
                bags = "Bags",
                bank = "Bank",
            },
            get = function() return selectedCategoryScope end,
            set = function(_, value)
                selectedCategoryScope = (value == "bank") and "bank" or "bags"
                RefreshCategories()
            end,
        },
        addCategory = {
            type = "execute",
            name = "Add Category",
            order = 3,
            func = function()
                if ns.Categories then
                    ns.Categories:AddCategory(selectedCategoryScope)
                end
                cfg.enabled = true
                RefreshCategories()
            end,
        },
        categoryColumns = {
            type = "range",
            name = "Category Columns",
            desc = "How many category sections to place side by side in the bag window.",
            order = 4,
            min = 1,
            max = 4,
            step = 1,
            get = function() return cfg.columns or 1 end,
            set = function(_, value)
                cfg.columns = tonumber(value) or 1
                RefreshCategories()
            end,
        },
    }

    for index, category in ipairs(cfg.list or {}) do
        category.rules = category.rules or {}
        local key = "category" .. tostring(index)
        args[key] = {
            type = "group",
            name = category.name or ("Category " .. tostring(index)),
            order = 10 + index,
            childGroups = "tab",
            args = {
                general = {
                    type = "group",
                    name = "General",
                    order = 1,
                    args = {
                        enabled = {
                            type = "toggle",
                            name = "Enabled",
                            order = 1,
                            get = function() return category.enabled ~= false end,
                            set = function(_, value)
                                category.enabled = value ~= false
                                RefreshCategories()
                            end,
                        },
                        name = {
                            type = "input",
                            name = "Name",
                            order = 2,
                            get = function() return category.name or "" end,
                            set = function(_, value)
                                category.name = value ~= "" and value or ("Category " .. tostring(index))
                                RefreshCategories()
                            end,
                        },
                        minSlots = {
                            type = "range",
                            name = "Minimum Slots",
                            desc = "Reserve at least this many visible slots for this category.",
                            order = 3,
                            min = 0,
                            max = 48,
                            step = 1,
                            get = function() return category.minSlots or 0 end,
                            set = function(_, value)
                                category.minSlots = (tonumber(value) and tonumber(value) > 0) and tonumber(value) or nil
                                RefreshCategories()
                            end,
                        },
                        moveUp = {
                            type = "execute",
                            name = "Move Up",
                            order = 4,
                            disabled = function() return index <= 1 end,
                            func = function()
                                if ns.Categories and ns.Categories:MoveCategory(index, -1, selectedCategoryScope) then
                                    RefreshCategories()
                                end
                            end,
                        },
                        moveDown = {
                            type = "execute",
                            name = "Move Down",
                            order = 5,
                            disabled = function() return index >= #(cfg.list or {}) end,
                            func = function()
                                if ns.Categories and ns.Categories:MoveCategory(index, 1, selectedCategoryScope) then
                                    RefreshCategories()
                                end
                            end,
                        },
                        remove = {
                            type = "execute",
                            name = "Remove Category",
                            order = 99,
                            confirm = true,
                            func = function()
                                if ns.Categories then
                                    ns.Categories:RemoveCategory(index, selectedCategoryScope)
                                end
                                RefreshCategories()
                            end,
                        },
                    },
                },
                rules = {
                    type = "group",
                    name = "Rules",
                    order = 2,
                    args = {
                        itemIDs = {
                            type = "input",
                            name = "Item IDs",
                            desc = "Comma-separated item IDs.",
                            order = 1,
                            get = function() return category.rules.itemIDs or "" end,
                            set = function(_, value)
                                category.rules.itemIDs = value ~= "" and value or nil
                                RefreshCategories()
                            end,
                        },
                        qualityEnabled = {
                            type = "toggle",
                            name = "Use Quality Rule",
                            order = 2,
                            get = function() return category.rules.qualityEnabled == true end,
                            set = function(_, value)
                                category.rules.qualityEnabled = value == true or nil
                                if value == true then
                                    category.rules.minQuality = category.rules.minQuality or 0
                                    category.rules.maxQuality = category.rules.maxQuality or 7
                                end
                                RefreshCategories()
                            end,
                        },
                        minQuality = {
                            disabled = function() return category.rules.qualityEnabled ~= true end,
                            type = "range",
                            name = "Minimum Quality",
                            order = 3,
                            min = 0,
                            max = 7,
                            step = 1,
                            get = function() return category.rules.minQuality or 0 end,
                            set = function(_, value)
                                category.rules.minQuality = tonumber(value)
                                RefreshCategories()
                            end,
                        },
                        maxQuality = {
                            disabled = function() return category.rules.qualityEnabled ~= true end,
                            type = "range",
                            name = "Maximum Quality",
                            order = 4,
                            min = 0,
                            max = 7,
                            step = 1,
                            get = function() return category.rules.maxQuality or 7 end,
                            set = function(_, value)
                                category.rules.maxQuality = tonumber(value)
                                RefreshCategories()
                            end,
                        },
                        classIDs = {
                            type = "multiselect",
                            name = "Item Classes",
                            desc = "Select item classes this category should match.",
                            order = 5,
                            values = BuildClassValues(),
                            get = function(_, _key)
                                return CSVHas(category.rules.classIDs, _key)
                            end,
                            set = function(_, _key, value)
                                category.rules.classIDs = CSVSet(category.rules.classIDs, _key, value)
                                if not value then
                                    category.rules.subClassPairs = RemoveSubclassSelectionsForClass(category.rules.subClassPairs, key)
                                end
                                RefreshCategories()
                            end,
                        },
                        subClassPairs = {
                            type = "multiselect",
                            name = "Item Subclasses",
                            desc = "Select item subclasses from the chosen item classes.",
                            order = 6,
                            disabled = function() return not CSVAny(category.rules.classIDs) end,
                            values = BuildSubclassValues(category.rules.classIDs),
                            get = function(_, _key)
                                return CSVHas(category.rules.subClassPairs, _key)
                            end,
                            set = function(_, _key, value)
                                category.rules.subClassPairs = CSVSet(category.rules.subClassPairs, _key, value)
                                RefreshCategories()
                            end,
                        },
                        equipLocs = {
                            type = "input",
                            name = "Equip Locations",
                            desc = "Comma-separated equip locations like INVTYPE_HEAD or INVTYPE_TRINKET.",
                            order = 7,
                            get = function() return category.rules.equipLocs or "" end,
                            set = function(_, value)
                                category.rules.equipLocs = value ~= "" and value or nil
                                RefreshCategories()
                            end,
                        },
                        equipmentSet = {
                            type = "toggle",
                            name = "Equipment Set Items",
                            desc = "Match items used by Blizzard Equipment Manager, ItemRack, or Outfitter when available.",
                            order = 8,
                            get = function() return category.rules.equipmentSet == true end,
                            set = function(_, value)
                                category.rules.equipmentSet = value == true or nil
                                RefreshCategories()
                            end,
                        },
                    },
                },
            },
        }
    end

    return args
end
local function BuildGeneralOptions()
    return {
        enabled = {
            type = "toggle",
            name = "Enabled",
            order = 1,
            get = function() return LunaBags.db.profile.enabled end,
            set = function(_, value) LunaBags.db.profile.enabled = value end,
        },
        debug = {
            type = "toggle",
            name = "Debug",
            order = 2,
            get = function() return LunaBags.db.profile.debug end,
            set = function(_, value)
                LunaBags.db.profile.debug = value
                RefreshOneBag()
                RefreshOneBank()
            end,
        },
    }
end

local function BuildAppearanceOptions()
    return {
        resetColors = {
            type = "execute",
            name = "Reset Colors",
            desc = "Restore default shared colors and opacity. Border size and text sizes are not changed.",
            order = 0,
            confirm = true,
            func = ResetUIColorAndOpacitySettings,
        },
        windowColor = {
            type = "color",
            name = "Window Color",
            order = 1,
            get = function() return GetUIColorSetting("windowColor", 0.12, 0.12, 0.12) end,
            set = function(_, r, g, b) SetUIColorSetting("windowColor", r, g, b) end,
        },
        windowOpacity = {
            type = "range",
            name = "Window Opacity",
            order = 2,
            min = 0.1,
            max = 1,
            step = 0.01,
            isPercent = true,
            get = function() return GetUISetting("windowOpacity", 0.72) end,
            set = function(_, value) SetUISetting("windowOpacity", value) end,
        },
        headerColor = {
            type = "color",
            name = "Header Color",
            order = 3,
            get = function() return GetUIColorSetting("headerColor", 0.07, 0.07, 0.07) end,
            set = function(_, r, g, b) SetUIColorSetting("headerColor", r, g, b) end,
        },
        headerOpacity = {
            type = "range",
            name = "Header Opacity",
            order = 4,
            min = 0.1,
            max = 1,
            step = 0.01,
            isPercent = true,
            get = function() return GetUISetting("headerOpacity", 0.78) end,
            set = function(_, value) SetUISetting("headerOpacity", value) end,
        },
        itemFrameColor = {
            type = "color",
            name = "Item Frame Color",
            order = 5,
            get = function() return GetUIColorSetting("itemFrameColor", 0.13, 0.13, 0.13) end,
            set = function(_, r, g, b) SetUIColorSetting("itemFrameColor", r, g, b) end,
        },
        itemFrameOpacity = {
            type = "range",
            name = "Item Frame Opacity",
            order = 6,
            min = 0,
            max = 1,
            step = 0.01,
            isPercent = true,
            get = function() return GetUISetting("itemFrameOpacity", 0.92) end,
            set = function(_, value) SetUISetting("itemFrameOpacity", value) end,
        },
        itemBorderSize = {
            type = "range",
            name = "Item Border Size",
            order = 7,
            min = 0,
            max = 4,
            step = 1,
            get = function() return GetUISetting("itemBorderSize", 1) end,
            set = function(_, value) SetUISetting("itemBorderSize", value) end,
        },
        stackCountTextSize = {
            type = "range",
            name = "Stack Count Text Size",
            order = 8,
            min = 8,
            max = 24,
            step = 1,
            get = function() return GetUISetting("stackCountTextSize", 12) end,
            set = function(_, value) SetUISetting("stackCountTextSize", value) end,
        },
        cooldownTextSize = {
            type = "range",
            name = "Cooldown Text Size",
            order = 9,
            min = 8,
            max = 32,
            step = 1,
            get = function() return GetUISetting("cooldownTextSize", 16) end,
            set = function(_, value) SetUISetting("cooldownTextSize", value) end,
        },
    }
end

local function BuildBagOptions()
    return {
        columns = {
            type = "range",
            name = "Columns",
            order = 1,
            min = 6,
            max = 16,
            step = 1,
            get = function() return GetOneBagSetting("columns", 11) end,
            set = function(_, value) SetOneBagSetting("columns", value) end,
        },
        itemSize = {
            type = "range",
            name = "Item Size",
            order = 2,
            min = 24,
            max = 48,
            step = 1,
            get = function() return GetOneBagSetting("itemSize", 36) end,
            set = function(_, value) SetOneBagSetting("itemSize", value) end,
        },
        spacing = {
            type = "range",
            name = "Item Spacing",
            order = 3,
            min = 0,
            max = 12,
            step = 1,
            get = function() return GetOneBagSetting("spacing", 4) end,
            set = function(_, value) SetOneBagSetting("spacing", value) end,
        },
        splitByBagRows = {
            type = "toggle",
            name = "Split Rows By Bag",
            order = 4,
            get = function() return GetOneBagSetting("splitByBagRows", false) end,
            set = function(_, value) SetOneBagSetting("splitByBagRows", value) end,
        },
        scale = {
            type = "range",
            name = "Frame Scale",
            order = 5,
            min = 0.7,
            max = 1.5,
            step = 0.01,
            bigStep = 0.05,
            isPercent = true,
            get = function() return GetOneBagSetting("scale", 1) end,
            set = function(_, value) SetOneBagSetting("scale", value) end,
        },
        locked = {
            type = "toggle",
            name = "Lock Frame Position",
            order = 6,
            get = function() return GetOneBagSetting("locked", false) end,
            set = function(_, value) SetOneBagSetting("locked", value) end,
        },
        resetPosition = {
            type = "execute",
            name = "Reset Position",
            order = 7,
            func = function()
                if ns.OneBag then
                    ns.OneBag:ResetPosition()
                end
            end,
        },
    }
end

local function BuildBankOptions()
    return {
        bankColumns = {
            type = "range",
            name = "Columns",
            order = 1,
            min = 6,
            max = 16,
            step = 1,
            get = function() return GetOneBankSetting("columns", 14) end,
            set = function(_, value) SetOneBankSetting("columns", value) end,
        },
        bankItemSize = {
            type = "range",
            name = "Item Size",
            order = 2,
            min = 24,
            max = 48,
            step = 1,
            get = function() return GetOneBankSetting("itemSize", 36) end,
            set = function(_, value) SetOneBankSetting("itemSize", value) end,
        },
        bankSpacing = {
            type = "range",
            name = "Item Spacing",
            order = 3,
            min = 0,
            max = 12,
            step = 1,
            get = function() return GetOneBankSetting("spacing", 4) end,
            set = function(_, value) SetOneBankSetting("spacing", value) end,
        },
        bankScale = {
            type = "range",
            name = "Frame Scale",
            order = 4,
            min = 0.7,
            max = 1.5,
            step = 0.01,
            bigStep = 0.05,
            isPercent = true,
            get = function() return GetOneBankSetting("scale", 1) end,
            set = function(_, value) SetOneBankSetting("scale", value) end,
        },
        bankLocked = {
            type = "toggle",
            name = "Lock Frame Position",
            order = 5,
            get = function() return GetOneBankSetting("locked", false) end,
            set = function(_, value) SetOneBankSetting("locked", value) end,
        },
        bankResetPosition = {
            type = "execute",
            name = "Reset Position",
            order = 6,
            func = function()
                if ns.OneBank then
                    ns.OneBank:ResetPosition()
                end
            end,
        },
    }
end

function BuildSortingOptions()
    local args = {
        reverseSlotOrder = {
            type = "toggle",
            name = "Reverse Slot Order",
            desc = "Place the first sorted items at the bottom-right end of the bag order.",
            order = 1,
            get = function() return GetSortingSetting("reverseSlotOrder", false) end,
            set = function(_, value) SetSortingSetting("reverseSlotOrder", value == true or nil) end,
        },
        priorityItemIDs = {
            type = "input",
            name = "Priority Item IDs",
            desc = "Comma-separated item IDs handled by the Priority Items sort rule.",
            order = 1.5,
            get = function() return GetSortingSetting("priorityItemIDs", "6948") end,
            set = function(_, value) SetSortingSetting("priorityItemIDs", value ~= "" and value or "6948") end,
        },
        resetRules = {
            type = "execute",
            name = "Reset Sort Rules",
            desc = "Restore the default sorting rules.",
            order = 2,
            confirm = true,
            func = function()
                SetSortingSetting("rules", CopyDefaultSortRules())
                RefreshSortingOptions()
            end,
        },
        addRule = {
            type = "execute",
            name = "Add Sort Rule",
            order = 3,
            func = AddSortRule,
        },
    }

    local rules = GetSortRulesConfig()
    for index, rule in ipairs(rules) do
        local ruleName = SORT_RULE_VALUES[rule.key] or tostring(rule.key or "Rule")
        args["rule" .. tostring(index)] = {
            type = "group",
            name = ("%02d. %s"):format(index, ruleName),
            order = 10 + index,
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enabled",
                    order = 1,
                    get = function() return rule.enabled ~= false end,
                    set = function(_, value)
                        rule.enabled = value ~= false
                    end,
                },
                key = {
                    type = "select",
                    name = "Rule",
                    order = 2,
                    values = SORT_RULE_VALUES,
                    get = function() return rule.key or "name" end,
                    set = function(_, value)
                        rule.key = value
                        RefreshSortingOptions()
                    end,
                },
                direction = {
                    type = "select",
                    name = "Direction",
                    order = 3,
                    values = SORT_DIRECTION_VALUES,
                    get = function() return rule.direction == "desc" and "desc" or "asc" end,
                    set = function(_, value)
                        rule.direction = value == "desc" and "desc" or "asc"
                        RefreshSortingOptions()
                    end,
                },
                moveUp = {
                    type = "execute",
                    name = "Move Up",
                    order = 4,
                    disabled = function() return index <= 1 end,
                    func = function() MoveSortRule(index, -1) end,
                },
                moveDown = {
                    type = "execute",
                    name = "Move Down",
                    order = 5,
                    disabled = function() return index >= #rules end,
                    func = function() MoveSortRule(index, 1) end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 6,
                    confirm = true,
                    func = function() RemoveSortRule(index) end,
                },
            },
        }
    end

    return args
end

local function BuildPluginOptions()
    return {
        pluginQualityBorder = {
            type = "toggle",
            name = "Item Quality Border",
            order = 1,
            get = function() return GetPluginSetting("qualityBorder", true) end,
            set = function(_, value) SetPluginSetting("qualityBorder", value) end,
        },
        pluginTrashIcon = {
            type = "toggle",
            name = "Trash Item Icon",
            order = 2,
            get = function() return GetPluginSetting("trashIcon", true) end,
            set = function(_, value) SetPluginSetting("trashIcon", value) end,
        },
    }
end

local function BuildProfileOptions()
    if not LunaBags.db then
        return {
            type = "group",
            name = "Profiles",
            order = 5,
            args = {
                unavailable = {
                    type = "description",
                    name = "Profiles will be available after the addon initializes.",
                    order = 1,
                },
            },
        }
    end
    local aceDBOptions = LibStub("AceDBOptions-3.0", true)
    if not aceDBOptions then
        return {
            type = "group",
            name = "Profiles",
            order = 5,
            args = {
                unavailable = {
                    type = "description",
                    name = "AceDBOptions-3.0 is not available.",
                    order = 1,
                },
            },
        }
    end
    local profileOptions = aceDBOptions:GetOptionsTable(LunaBags.db)
    profileOptions.name = "Profiles"
    profileOptions.order = 5
    return profileOptions
end

options = {
    name = "LunaBags",
    type = "group",
    childGroups = "tree",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = BuildGeneralOptions(),
        },
        ui = {
            type = "group",
            name = "UI",
            order = 2,
            childGroups = "tab",
            args = {
                appearance = {
                    type = "group",
                    name = "Appearance",
                    order = 1,
                    args = BuildAppearanceOptions(),
                },
                bags = {
                    type = "group",
                    name = "Bags",
                    order = 2,
                    args = BuildBagOptions(),
                },
                bank = {
                    type = "group",
                    name = "Bank",
                    order = 3,
                    args = BuildBankOptions(),
                },
            },
        },
        sorting = {
            type = "group",
            name = "Sorting",
            order = 3,
            args = BuildSortingOptions(),
        },
        plugins = {
            type = "group",
            name = "Plugins",
            order = 4,
            args = BuildPluginOptions(),
        },
        profiles = BuildProfileOptions(),
        categories = {
            type = "group",
            name = "Categories",
            order = 6,
            childGroups = "tree",
            args = BuildCategoryOptions(),
        },
    },
}

RefreshCategoryOptions = function()
    options.args.categories.args = BuildCategoryOptions()
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange("LunaBags")
    end
end

RefreshProfileOptions = function()
    EnsureProfileCallbacks()
    options.args.profiles = BuildProfileOptions()
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange("LunaBags")
    end
end

function ns.OpenConfig()
    local dialog = LibStub("AceConfigDialog-3.0")
    RefreshSortingOptions()
    if RefreshCategoryOptions then
        RefreshCategoryOptions()
    end
    if RefreshProfileOptions then
        RefreshProfileOptions()
    end
    dialog:Open("LunaBags")
    local openFrame = dialog.OpenFrames and dialog.OpenFrames["LunaBags"]
    if openFrame and openFrame.frame then
        openFrame.frame:SetFrameStrata("DIALOG")
        openFrame.frame:SetClampedToScreen(true)
        openFrame.frame:SetMovable(true)
        if openFrame.frame.obj and openFrame.frame.obj.SetStatusText then
            openFrame.frame.obj:SetStatusText("LunaBags Settings")
        end
    end
end

local function RegisterOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("LunaBags", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LunaBags", "LunaBags")
end

RegisterOptions()
