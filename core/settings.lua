local _, ns = ...
local LunaBags = ns.LunaBags
local options
local BuildSortingOptions
local RefreshCategoryOptions
local RefreshProfileOptions
local profileCallbacksRegistered = false
local profileImportText = ""
local profileImportName = ""
local profileExportText = ""

local function RefreshOneBag(deferred)
    if ns.OneBag then
        if ns.OneBag.InvalidateSlotCache then
            ns.OneBag:InvalidateSlotCache()
        else
            ns.OneBag._layoutModel = nil
        end
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
        if ns.OneBank.InvalidateSlotCache then
            ns.OneBank:InvalidateSlotCache()
        else
            ns.OneBank._layoutModel = nil
        end
        ns.OneBank:ApplySettings()
        if ns.OneBank.frame and ns.OneBank.frame:IsShown() then
            ns.OneBank:Refresh()
        end
    end
end
local function RefreshOneGuildBank()
    if ns.OneGuildBank then
        ns.OneGuildBank:ApplySettings()
        if ns.OneGuildBank.frame and ns.OneGuildBank.frame:IsShown() then
            ns.OneGuildBank:Refresh()
        end
    end
end

local function CalculateWindowWidthFromColumns(columns, itemSize, spacing)
    columns = math.max(1, math.floor(tonumber(columns) or 1))
    itemSize = tonumber(itemSize) or 36
    spacing = tonumber(spacing) or 4
    return columns * itemSize + math.max(0, columns - 1) * spacing + (spacing * 2) + 26
end

local function GetOneBagSetting(key, fallback)
    LunaBags.db.profile.oneBag = LunaBags.db.profile.oneBag or {}
    local cfg = LunaBags.db.profile.oneBag
    if key == "windowWidth" and rawget(cfg, "windowWidth") == nil and cfg._windowWidthMigrated ~= true then
        return CalculateWindowWidthFromColumns(cfg.columns or 11, cfg.itemSize or 37, cfg.spacing or 4)
    end
    local value = cfg[key]
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
    local cfg = LunaBags.db.profile.oneBank
    if key == "windowWidth" and rawget(cfg, "windowWidth") == nil and cfg._windowWidthMigrated ~= true then
        return CalculateWindowWidthFromColumns(cfg.columns or 14, cfg.itemSize or 36, cfg.spacing or 4)
    end
    local value = cfg[key]
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

local function GetOneGuildBankSetting(key, fallback)
    LunaBags.db.profile.oneGuildBank = LunaBags.db.profile.oneGuildBank or {}
    local cfg = LunaBags.db.profile.oneGuildBank
    local value = cfg[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetOneGuildBankSetting(key, value)
    LunaBags.db.profile.oneGuildBank = LunaBags.db.profile.oneGuildBank or {}
    local cfg = LunaBags.db.profile.oneGuildBank
    cfg[key] = value
    RefreshOneGuildBank()
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
    RefreshOneGuildBank()
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
    RefreshOneGuildBank()
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
    local plugin = ns.Plugins and ns.Plugins.registry and ns.Plugins.registry[key]
    if type(plugin) == "table" then
        plugin._categoryCache = nil
    end
    RefreshOneBag()
    RefreshOneBank()
    RefreshOneGuildBank()
end

local function GetPluginOption(plugin, optionKey, fallback)
    LunaBags.db.profile.plugins = LunaBags.db.profile.plugins or {}
    local id = plugin and plugin.id
    if not id then
        return fallback
    end
    local optionsKey = id .. "Options"
    LunaBags.db.profile.plugins[optionsKey] = LunaBags.db.profile.plugins[optionsKey] or {}
    local value = LunaBags.db.profile.plugins[optionsKey][optionKey]
    if value == nil then
        return fallback
    end
    return value
end

local function SetPluginOption(plugin, optionKey, value)
    LunaBags.db.profile.plugins = LunaBags.db.profile.plugins or {}
    local id = plugin and plugin.id
    if not id then
        return
    end
    local optionsKey = id .. "Options"
    LunaBags.db.profile.plugins[optionsKey] = LunaBags.db.profile.plugins[optionsKey] or {}
    LunaBags.db.profile.plugins[optionsKey][optionKey] = value
    plugin._categoryCache = nil
    RefreshOneBag()
    RefreshOneBank()
    RefreshOneGuildBank()
end

local function GetModuleSetting(key)
    LunaBags.db.profile.modules = LunaBags.db.profile.modules or {}
    return LunaBags.db.profile.modules[key] ~= false
end

local function SetModuleSetting(key, value)
    LunaBags.db.profile.modules = LunaBags.db.profile.modules or {}
    LunaBags.db.profile.modules[key] = value ~= false
    LunaBags.db.profile.modules._reloadRequired = true
    if LunaBags.ApplyWindowModuleStates then
        LunaBags:ApplyWindowModuleStates()
    end
end

local function ReloadUIIfAvailable()
    if ReloadUI then
        ReloadUI()
    end
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
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "classOrder", direction = "asc", enabled = true },
    { key = "equipLoc", direction = "asc", enabled = true },
    { key = "itemLevel", direction = "desc", enabled = true },
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

local RAIL_POSITION_OPTIONS = {
    top = "Top",
    left = "Left",
    right = "Right",
    bottom = "Bottom",
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

local function GetCategoryScopeLabel()
    return selectedCategoryScope == "bank" and "Bank" or "Bags"
end

local function GetCategoryOverview()
    local cfg = GetCategoryConfig()
    local count = #(cfg.list or {})
    local state = cfg.enabled == true and "enabled" or "disabled"
    local layout = cfg.layout == "fixed" and "fixed columns" or "masonry"
    return ("%s categories: %d configured, %s, %s layout. Drag items onto a category in the bag or bank window to add them; drag categorized items back to the inventory area to remove or blacklist them."):format(
        GetCategoryScopeLabel(),
        count,
        state,
        layout
    )
end

local function RefreshOpenWindows()
    RefreshOneBag(true)
    RefreshOneBank()
    RefreshOneGuildBank()
end

local function RefreshCategories()
    if RefreshCategoryOptions then
        RefreshCategoryOptions()
    end
    RefreshOneBag(true)
    RefreshOneBank()
end

local function RefreshAllOpenWindows()
    if LunaBags.RefreshOpenWindowsForProfileChange then
        LunaBags:RefreshOpenWindowsForProfileChange()
    else
        RefreshOneBag(true)
        RefreshOneBank()
    end
end

local function HandleProfileChanged()
    if LunaBags.EnsureProfileShape then
        LunaBags:EnsureProfileShape()
    end
    if LunaBags.MigrateDefaultSortRules then
        LunaBags:MigrateDefaultSortRules()
    end
    if LunaBags.ApplyWindowModuleStates then
        LunaBags:ApplyWindowModuleStates()
    end
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
        overview = {
            type = "description",
            name = GetCategoryOverview,
            order = 0,
            fontSize = "medium",
        },
        scopeHeader = {
            type = "header",
            name = "Scope",
            order = 0.5,
        },
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
        layoutHeader = {
            type = "header",
            name = "Layout",
            order = 3.5,
        },
        categoryColumns = {
            type = "range",
            name = "Category Columns",
            desc = "Default number of category sections to fit side by side. Individual categories can override their item column width.",
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
        categoryLayout = {
            type = "select",
            name = "Category Layout",
            desc = "Masonry fills the shortest column first. Fixed keeps categories aligned in stable column lanes.",
            order = 5,
            values = {
                masonry = "Masonry",
                fixed = "Fixed",
            },
            get = function() return cfg.layout == "fixed" and "fixed" or "masonry" end,
            set = function(_, value)
                cfg.layout = (value == "fixed") and "fixed" or "masonry"
                RefreshCategories()
            end,
        },
        categoriesHeader = {
            type = "header",
            name = GetCategoryScopeLabel() .. " Categories",
            order = 9,
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
                        columns = {
                            type = "range",
                            name = "Section Columns",
                            desc = "How many item columns this category should use. Set to 0 to use the default category width.",
                            order = 4,
                            min = 0,
                            max = 32,
                            step = 1,
                            get = function() return category.columns or 0 end,
                            set = function(_, value)
                                local columns = tonumber(value) or 0
                                category.columns = columns > 0 and columns or nil
                                RefreshCategories()
                            end,
                        },
                        moveUp = {
                            type = "execute",
                            name = "Move Up",
                            order = 5,
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
                            order = 6,
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
                        blacklistItemIDs = {
                            type = "input",
                            name = "Blacklist Item IDs",
                            desc = "Comma-separated item IDs excluded from this category, useful with broad class rules.",
                            order = 1.5,
                            get = function() return category.rules.blacklistItemIDs or "" end,
                            set = function(_, value)
                                category.rules.blacklistItemIDs = value ~= "" and value or nil
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
        overview = {
            type = "description",
            name = "Enable the addon, refresh open windows, and jump straight into the live inventory UI while tuning settings.",
            order = 0,
            fontSize = "medium",
        },
        coreHeader = {
            type = "header",
            name = "Core",
            order = 0.5,
        },
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
        modulesHeader = {
            type = "header",
            name = "Window Modules",
            order = 3,
        },
        modulesNote = {
            type = "description",
            name = "Window modules are Ace modules. Changing these settings requires a UI reload to fully load or unload module code.",
            order = 4,
        },
        moduleOneBag = {
            type = "toggle",
            name = "Bags Module",
            order = 5,
            get = function() return GetModuleSetting("oneBag") end,
            set = function(_, value) SetModuleSetting("oneBag", value) end,
        },
        moduleOneBank = {
            type = "toggle",
            name = "Bank Module",
            order = 6,
            get = function() return GetModuleSetting("oneBank") end,
            set = function(_, value) SetModuleSetting("oneBank", value) end,
        },
        moduleOneGuildBank = {
            type = "toggle",
            name = "Guild Bank Module",
            order = 7,
            get = function() return GetModuleSetting("oneGuildBank") end,
            set = function(_, value) SetModuleSetting("oneGuildBank", value) end,
        },
        reloadRequired = {
            type = "description",
            name = function()
                return (LunaBags.db.profile.modules and LunaBags.db.profile.modules._reloadRequired)
                    and "|cffffd200Reload UI required for module load changes to fully apply.|r"
                    or ""
            end,
            order = 8,
        },
        reloadUI = {
            type = "execute",
            name = "Reload UI",
            order = 9,
            hidden = function()
                return not (LunaBags.db.profile.modules and LunaBags.db.profile.modules._reloadRequired)
            end,
            func = ReloadUIIfAvailable,
        },
        actionsHeader = {
            type = "header",
            name = "Actions",
            order = 10,
        },
        openBags = {
            type = "execute",
            name = "Open Bags",
            desc = "Open the combined bag window.",
            order = 11,
            func = function()
                if GetModuleSetting("oneBag") and ns.OneBag then
                    ns.OneBag:Show()
                end
            end,
        },
        refreshWindows = {
            type = "execute",
            name = "Refresh Open Windows",
            desc = "Reapply current profile settings to open LunaBags windows.",
            order = 12,
            func = RefreshOpenWindows,
        },
    }
end

local function BuildAppearanceOptions()
    return {
        overview = {
            type = "description",
            name = "Shared color, opacity, border, and text settings used by the bag, bank, and guild bank windows.",
            order = -1,
            fontSize = "medium",
        },
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
        itemTextFont = {
            type = "select",
            name = "Item Text Font",
            order = 8,
            values = {
                expressway = "Expressway",
                arial_bold = "Arial Bold",
                friz = "Friz Quadrata",
            },
            get = function() return GetUISetting("itemTextFont", "expressway") end,
            set = function(_, value) SetUISetting("itemTextFont", value) end,
        },
        itemTextSize = {
            type = "range",
            name = "Item Text Size",
            order = 9,
            min = 8,
            max = 24,
            step = 1,
            get = function() return GetUISetting("itemTextSize", 10) end,
            set = function(_, value) SetUISetting("itemTextSize", value) end,
        },
        itemTextOutline = {
            type = "toggle",
            name = "Item Text Outline",
            order = 10,
            get = function() return GetUISetting("itemTextOutline", true) end,
            set = function(_, value) SetUISetting("itemTextOutline", value) end,
        },
        itemTextShadow = {
            type = "toggle",
            name = "Item Text Shadow",
            order = 11,
            get = function() return GetUISetting("itemTextShadow", true) end,
            set = function(_, value) SetUISetting("itemTextShadow", value) end,
        },
        stackCountAlign = {
            type = "select",
            name = "Stack Count Align",
            order = 12,
            values = {
                left = "Left",
                right = "Right",
            },
            get = function() return GetUISetting("stackCountAlign", "right") end,
            set = function(_, value) SetUISetting("stackCountAlign", value) end,
        },
        stackCountOffsetX = {
            type = "range",
            name = "Stack Count X Offset",
            order = 13,
            min = 0,
            max = 20,
            step = 1,
            get = function() return GetUISetting("stackCountOffsetX", 3) end,
            set = function(_, value) SetUISetting("stackCountOffsetX", value) end,
        },
        stackCountOffsetY = {
            type = "range",
            name = "Stack Count Y Offset",
            order = 14,
            min = 0,
            max = 20,
            step = 1,
            get = function() return GetUISetting("stackCountOffsetY", 3) end,
            set = function(_, value) SetUISetting("stackCountOffsetY", value) end,
        },
    }
end

local function BuildBagOptions()
    return {
        overview = {
            type = "description",
            name = "Inventory window size, spacing, scale, position lock, and row splitting.",
            order = 0,
            fontSize = "medium",
        },
        layoutHeader = {
            type = "header",
            name = "Layout",
            order = 0.5,
        },
        windowWidth = {
            type = "range",
            name = "Window Width",
            order = 1,
            min = 280,
            max = 900,
            step = 1,
            get = function() return GetOneBagSetting("windowWidth", 481) end,
            set = function(_, value) SetOneBagSetting("windowWidth", value) end,
        },
        itemSize = {
            type = "range",
            name = "Item Size",
            order = 2,
            min = 24,
            max = 48,
            step = 1,
            get = function() return GetOneBagSetting("itemSize", 37) end,
            set = function(_, value) SetOneBagSetting("itemSize", value) end,
        },
        windowMaxHeight = {
            type = "range",
            name = "Max Height",
            order = 3,
            min = 260,
            max = 1000,
            step = 1,
            get = function() return GetOneBagSetting("windowMaxHeight", 650) end,
            set = function(_, value) SetOneBagSetting("windowMaxHeight", value) end,
        },
        spacing = {
            type = "range",
            name = "Item Spacing",
            order = 4,
            min = 0,
            max = 12,
            step = 1,
            get = function() return GetOneBagSetting("spacing", 4) end,
            set = function(_, value) SetOneBagSetting("spacing", value) end,
        },
        splitByBagRows = {
            type = "toggle",
            name = "Split Rows By Bag",
            order = 5,
            get = function() return GetOneBagSetting("splitByBagRows", false) end,
            set = function(_, value) SetOneBagSetting("splitByBagRows", value) end,
        },
        bagRailPosition = {
            type = "select",
            name = "Bag Rail Position",
            order = 5.5,
            values = {
                top = "Top",
                left = "Left",
                right = "Right",
                bottom = "Bottom",
            },
            get = function() return GetOneBagSetting("bagRailPosition", "top") end,
            set = function(_, value) SetOneBagSetting("bagRailPosition", value) end,
        },
        scale = {
            type = "range",
            name = "Frame Scale",
            order = 6,
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
            order = 7,
            get = function() return GetOneBagSetting("locked", false) end,
            set = function(_, value) SetOneBagSetting("locked", value) end,
        },
        resetPosition = {
            type = "execute",
            name = "Reset Position",
            order = 8,
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
        overview = {
            type = "description",
            name = "Bank window size, spacing, scale, and position lock.",
            order = 0,
            fontSize = "medium",
        },
        layoutHeader = {
            type = "header",
            name = "Layout",
            order = 0.5,
        },
        bankWindowWidth = {
            type = "range",
            name = "Window Width",
            order = 1,
            min = 320,
            max = 1100,
            step = 1,
            get = function() return GetOneBankSetting("windowWidth", 590) end,
            set = function(_, value) SetOneBankSetting("windowWidth", value) end,
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
        bankWindowMaxHeight = {
            type = "range",
            name = "Max Height",
            order = 3,
            min = 300,
            max = 1000,
            step = 1,
            get = function() return GetOneBankSetting("windowMaxHeight", 650) end,
            set = function(_, value) SetOneBankSetting("windowMaxHeight", value) end,
        },
        bankSpacing = {
            type = "range",
            name = "Item Spacing",
            order = 4,
            min = 0,
            max = 12,
            step = 1,
            get = function() return GetOneBankSetting("spacing", 4) end,
            set = function(_, value) SetOneBankSetting("spacing", value) end,
        },
        bankBagRailPosition = {
            type = "select",
            name = "Bag Rail Position",
            order = 4.5,
            values = RAIL_POSITION_OPTIONS,
            get = function() return GetOneBankSetting("bagRailPosition", "top") end,
            set = function(_, value) SetOneBankSetting("bagRailPosition", value) end,
        },
        bankScale = {
            type = "range",
            name = "Frame Scale",
            order = 5,
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
            order = 6,
            get = function() return GetOneBankSetting("locked", false) end,
            set = function(_, value) SetOneBankSetting("locked", value) end,
        },
        bankResetPosition = {
            type = "execute",
            name = "Reset Position",
            order = 7,
            func = function()
                if ns.OneBank then
                    ns.OneBank:ResetPosition()
                end
            end,
        },
    }
end

local function BuildGuildBankOptions()
    return {
        overview = {
            type = "description",
            name = "Guild bank grid density, spacing, scale, and position lock.",
            order = 0,
            fontSize = "medium",
        },
        guildBankItemSize = {
            type = "range",
            name = "Item Size",
            order = 2,
            min = 24,
            max = 48,
            step = 1,
            get = function() return GetOneGuildBankSetting("itemSize", 36) end,
            set = function(_, value) SetOneGuildBankSetting("itemSize", value) end,
        },
        guildBankSpacing = {
            type = "range",
            name = "Item Spacing",
            order = 3,
            min = 0,
            max = 12,
            step = 1,
            get = function() return GetOneGuildBankSetting("spacing", 4) end,
            set = function(_, value) SetOneGuildBankSetting("spacing", value) end,
        },
        guildBankTabRailPosition = {
            type = "select",
            name = "Tab Rail Position",
            order = 3.5,
            values = RAIL_POSITION_OPTIONS,
            get = function() return GetOneGuildBankSetting("tabRailPosition", "top") end,
            set = function(_, value) SetOneGuildBankSetting("tabRailPosition", value) end,
        },
        guildBankModeRailPosition = {
            type = "select",
            name = "Mode Rail Position",
            order = 3.6,
            values = RAIL_POSITION_OPTIONS,
            get = function() return GetOneGuildBankSetting("modeRailPosition", "bottom") end,
            set = function(_, value) SetOneGuildBankSetting("modeRailPosition", value) end,
        },
        guildBankScale = {
            type = "range",
            name = "Frame Scale",
            order = 4,
            min = 0.7,
            max = 1.5,
            step = 0.01,
            bigStep = 0.05,
            isPercent = true,
            get = function() return GetOneGuildBankSetting("scale", 1) end,
            set = function(_, value) SetOneGuildBankSetting("scale", value) end,
        },
        guildBankLocked = {
            type = "toggle",
            name = "Lock Frame Position",
            order = 5,
            get = function() return GetOneGuildBankSetting("locked", false) end,
            set = function(_, value) SetOneGuildBankSetting("locked", value) end,
        },
        guildBankResetPosition = {
            type = "execute",
            name = "Reset Position",
            order = 6,
            func = function()
                if ns.OneGuildBank then
                    ns.OneGuildBank:ResetPosition()
                end
            end,
        },
    }
end

function BuildSortingOptions()
    local args = {
        overview = {
            type = "description",
            name = "Sorting behavior is shared by real sorting and visual sorting. Rule order is evaluated from top to bottom.",
            order = 0,
            fontSize = "medium",
        },
        behaviorHeader = {
            type = "header",
            name = "Behavior",
            order = 0.5,
        },
        reverseSlotOrder = {
            type = "toggle",
            name = "Reverse Slot Order",
            desc = "Place the first sorted items at the bottom-right end of the bag order.",
            order = 1,
            get = function() return GetSortingSetting("reverseSlotOrder", false) end,
            set = function(_, value) SetSortingSetting("reverseSlotOrder", value == true or nil) end,
        },
        visualOnly = {
            type = "toggle",
            name = "Visual Sort Only",
            desc = "Display inventory items in sorted order without moving them between bag slots.",
            order = 1.25,
            get = function() return GetSortingSetting("visualOnly", false) end,
            set = function(_, value)
                SetSortingSetting("visualOnly", value == true or nil)
                if ns.OneBag then
                    ns.OneBag._layoutModel = nil
                end
                if ns.OneBank then
                    ns.OneBank._layoutModel = nil
                end
                RefreshOneBag()
                RefreshOneBank()
            end,
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
        rulesHeader = {
            type = "header",
            name = "Rules",
            order = 9,
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
    local args = {
        overview = {
            type = "description",
            name = "Small item-slot overlays and borders. These update open windows immediately.",
            order = 0,
            fontSize = "medium",
        },
        pluginQualityBorder = {
            type = "toggle",
            name = "Item Quality Border",
            order = 1,
            get = function() return GetPluginSetting("qualityBorder", true) end,
            set = function(_, value) SetPluginSetting("qualityBorder", value) end,
        },
        pluginEquipmentSetBorder = {
            type = "toggle",
            name = "Equipment Set Border",
            desc = "Use a blue border for items that belong to an equipment set.",
            order = 1.5,
            get = function() return GetPluginSetting("equipmentSetBorder", true) end,
            set = function(_, value) SetPluginSetting("equipmentSetBorder", value) end,
        },
        pluginEquipmentSetCategories = {
            type = "toggle",
            name = "Equipment Set Categories",
            desc = "Create dynamic bag and bank categories for Blizzard, ExtraStats, and ItemRack equipment sets. Fully equipped sets are hidden.",
            order = 1.6,
            get = function() return GetPluginSetting("equipmentSetCategories", true) end,
            set = function(_, value) SetPluginSetting("equipmentSetCategories", value) end,
        },
        pluginTrashIcon = {
            type = "toggle",
            name = "Trash Item Icon",
            order = 2,
            get = function() return GetPluginSetting("trashIcon", true) end,
            set = function(_, value) SetPluginSetting("trashIcon", value) end,
        },
        pluginItemLevelText = {
            type = "toggle",
            name = "Item Level Text",
            desc = "Show item level directly on item buttons.",
            order = 2.05,
            get = function() return GetPluginSetting("itemLevelText", true) end,
            set = function(_, value) SetPluginSetting("itemLevelText", value) end,
        },
        pluginQuestStartMarker = {
            type = "toggle",
            name = "Quest Start Marker",
            desc = "Show a ? on items that start an available quest.",
            order = 2.06,
            get = function() return GetPluginSetting("questStartMarker", true) end,
            set = function(_, value) SetPluginSetting("questStartMarker", value) end,
        },
        pluginPawnUpgrade = {
            type = "toggle",
            name = "Pawn Upgrade Arrows",
            desc = "Show Pawn's upgrade arrows on LunaBags item buttons.",
            order = 2.1,
            get = function() return GetPluginSetting("pawnUpgrade", true) end,
            set = function(_, value) SetPluginSetting("pawnUpgrade", value) end,
        },
    }

    local registry = ns.Plugins and ns.Plugins.registry
    if type(registry) == "table" then
        local ordered = {}
        for id, plugin in pairs(registry) do
            if type(plugin) == "table" then
                ordered[#ordered + 1] = plugin
            end
        end
        table.sort(ordered, function(a, b)
            return tostring(a.name or a.id or "") < tostring(b.name or b.id or "")
        end)
        for index, plugin in ipairs(ordered) do
            local fn = plugin.GetOptions or plugin.BuildOptions or plugin.getOptions
            local pluginOptions
            if type(fn) == "function" then
                local ok, result = pcall(fn, plugin, {
                    get = function(optionKey, fallback) return GetPluginOption(plugin, optionKey, fallback) end,
                    set = function(optionKey, value) SetPluginOption(plugin, optionKey, value) end,
                    getEnabled = function(fallback) return GetPluginSetting(plugin.id, fallback) end,
                    setEnabled = function(value) SetPluginSetting(plugin.id, value) end,
                })
                if ok then
                    pluginOptions = result
                end
            elseif type(plugin.options) == "table" then
                pluginOptions = plugin.options
            end

            if type(pluginOptions) == "table" then
                local key = "pluginPage_" .. tostring(plugin.id or plugin.name or index):gsub("[^%w_]", "_")
                if pluginOptions.type == "group" then
                    args[key] = pluginOptions
                    args[key].name = args[key].name or plugin.name or plugin.id
                    args[key].order = args[key].order or (20 + index)
                else
                    args[key] = {
                        type = "group",
                        name = plugin.name or plugin.id or ("Plugin " .. tostring(index)),
                        order = 20 + index,
                        args = pluginOptions,
                    }
                end
            end
        end
    end

    return args
end

local function BuildProfileOptions()
    if not LunaBags.db then
        return {
            type = "group",
            name = "Profiles",
            order = 6,
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
            order = 6,
            args = {
                unavailable = {
                    type = "description",
                    name = "AceDBOptions-3.0 is not available.",
                    order = 1,
                },
            },
        }
    end
    local profileOptions = aceDBOptions:GetOptionsTable(LunaBags.db, true)
    profileOptions.name = "Profiles"
    profileOptions.order = 6
    profileOptions.args = profileOptions.args or {}
    profileOptions.args.export = {
        type = "group",
        name = "Export",
        order = 900,
        args = {
            overview = {
                type = "description",
                name = "Export the current profile as a base64 encoded LunaBags profile string.",
                order = 0,
                fontSize = "medium",
            },
            exportProfile = {
                type = "execute",
                name = "Export Current Profile",
                order = 1,
                func = function()
                    profileExportText = (LunaBags.ExportCurrentProfile and LunaBags:ExportCurrentProfile()) or ""
                    if profileExportText == "" and LunaBags.Print then
                        LunaBags:Print("Profile export failed.")
                    end
                end,
            },
            exportData = {
                type = "input",
                name = "Export Data",
                order = 2,
                multiline = 8,
                width = "full",
                get = function() return profileExportText end,
                set = function(_, value) profileExportText = value or "" end,
            },
        },
    }
    profileOptions.args.import = {
        type = "group",
        name = "Import",
        order = 901,
        args = {
            overview = {
                type = "description",
                name = "Import a base64 encoded LunaBags profile string.",
                order = 0,
                fontSize = "medium",
            },
            importName = {
                type = "input",
                name = "Import As",
                desc = "Leave blank to use the exported profile name or replace the current profile.",
                order = 1,
                get = function() return profileImportName end,
                set = function(_, value) profileImportName = value or "" end,
            },
            importData = {
                type = "input",
                name = "Import Data",
                order = 2,
                multiline = 8,
                width = "full",
                get = function() return profileImportText end,
                set = function(_, value) profileImportText = value or "" end,
            },
            importProfile = {
                type = "execute",
                name = "Import Profile",
                order = 3,
                confirm = true,
                disabled = function() return profileImportText == "" end,
                func = function()
                    local ok, result = LunaBags.ImportProfile and LunaBags:ImportProfile(profileImportText, profileImportName)
                    if ok then
                        profileImportText = ""
                        profileImportName = ""
                        HandleProfileChanged()
                        if LunaBags.Print then
                            LunaBags:Print(("Imported profile: %s"):format(tostring(result)))
                        end
                    elseif LunaBags.Print then
                        LunaBags:Print(tostring(result or "Profile import failed."))
                    end
                end,
            },
        },
    }
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
            name = "Windows",
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
                guildBank = {
                    type = "group",
                    name = "Guild Bank",
                    order = 4,
                    args = BuildGuildBankOptions(),
                },
            },
        },
        categories = {
            type = "group",
            name = "Categories",
            order = 3,
            childGroups = "tree",
            args = BuildCategoryOptions(),
        },
        sorting = {
            type = "group",
            name = "Sorting",
            order = 4,
            args = BuildSortingOptions(),
        },
        plugins = {
            type = "group",
            name = "Plugins",
            order = 5,
            childGroups = "tree",
            args = BuildPluginOptions(),
        },
        profiles = BuildProfileOptions(),
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
