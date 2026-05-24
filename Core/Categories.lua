local _, ns = ...

local Categories = {
    customMatchers = {},
}

ns.Categories = Categories

local function SplitCSV(value)
    local out = {}
    if type(value) ~= "string" then
        return out
    end
    for token in value:gmatch("[^,%s]+") do
        out[#out + 1] = token
    end
    return out
end

local function MatchCSVNumber(value, csv)
    if not value then return false end
    local numeric = tonumber(value)
    for _, token in ipairs(SplitCSV(csv)) do
        if tonumber(token) == numeric then
            return true
        end
    end
    return false
end

local function MatchCSVText(value, csv)
    if not value or type(csv) ~= "string" or csv == "" then return false end
    local needle = tostring(value):lower()
    for _, token in ipairs(SplitCSV(csv)) do
        if needle == tostring(token):lower() then
            return true
        end
    end
    return false
end

local function MatchCSVPair(first, second, csv)
    if first == nil or second == nil or type(csv) ~= "string" or csv == "" then return false end
    local needle = tostring(first) .. ":" .. tostring(second)
    for _, token in ipairs(SplitCSV(csv)) do
        if token == needle then
            return true
        end
    end
    return false
end

local function CopyTableValue(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[CopyTableValue(k, seen)] = CopyTableValue(v, seen)
    end
    return out
end

local function ScopedConfigHasCategories(cfg)
    return type(cfg) == "table" and type(cfg.list) == "table" and #cfg.list > 0
end

local function HasCategoryData(categories)
    if type(categories) ~= "table" then
        return false
    end
    if type(categories.list) == "table" and #categories.list > 0 then
        return true
    end
    if ScopedConfigHasCategories(categories.bags) or ScopedConfigHasCategories(categories.bank) then
        return true
    end
    if type(categories.perCharacter) == "table" then
        for _, perChar in pairs(categories.perCharacter) do
            if type(perChar) == "table" then
                for _, scoped in pairs(perChar) do
                    if type(scoped) == "table" and type(scoped.list) == "table" and #scoped.list > 0 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function GetProfile()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.categories = addon.db.profile.categories or {}
    local profileCategories = addon.db.profile.categories

    if profileCategories._migratedFromGlobalCategories ~= true then
        local globalCategories = addon.db.global and addon.db.global.categories
        if HasCategoryData(globalCategories)
            and globalCategories._migratedToProfileCategories ~= true
            and not HasCategoryData(profileCategories)
        then
            addon.db.profile.categories = CopyTableValue(globalCategories)
            profileCategories = addon.db.profile.categories
            globalCategories._migratedToProfileCategories = true
        end
        profileCategories._migratedFromGlobalCategories = true
    end

    return profileCategories
end

local function GetCharacterKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    if (not name or name == "") and UnitName then
        name = UnitName("player")
    end
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or nil
    end

    local unknown = tostring(UNKNOWNOBJECT or "Unknown Entity")
    if not name or name == "" or tostring(name) == unknown then
        return nil
    end
    if not realm or realm == "" or tostring(realm) == unknown then
        return nil
    end
    return tostring(name) .. "-" .. tostring(realm)
end

local function NormalizeScope(scope)
    return (scope == "bank") and "bank" or "bags"
end

local function EnsureDefaultScopedFields(cfg)
    if type(cfg) ~= "table" then
        return nil
    end
    cfg.list = cfg.list or {}
    cfg.columns = tonumber(cfg.columns) or 1
    cfg.nextID = tonumber(cfg.nextID) or 1
    cfg.layout = (cfg.layout == "fixed") and "fixed" or "masonry"
    return cfg
end

local function CopyBestPerCharacterScope(profile, scope)
    if type(profile.perCharacter) ~= "table" then
        return nil
    end

    local currentKey = GetCharacterKey()
    local current = currentKey and profile.perCharacter[currentKey]
    if ScopedConfigHasCategories(current and current[scope]) then
        return CopyTableValue(current[scope])
    end

    for _, perChar in pairs(profile.perCharacter) do
        if ScopedConfigHasCategories(perChar and perChar[scope]) then
            return CopyTableValue(perChar[scope])
        end
    end

    return nil
end

local function MigrateSharedScopes(profile)
    if type(profile) ~= "table" or profile._migratedSharedCategoryScopes == true then
        return
    end

    -- Categories are profile data. Older builds stored them per character, which
    -- made copied/selected profiles look empty on alts.
    if type(profile.bags) ~= "table" then
        profile.bags = {}
    end
    if type(profile.bank) ~= "table" then
        profile.bank = {}
    end

    if not ScopedConfigHasCategories(profile.bags) then
        local migratedBags = nil
        if type(profile.list) == "table" and #profile.list > 0 then
            migratedBags = {
                enabled = profile.enabled == true,
                columns = tonumber(profile.columns) or 1,
                nextID = tonumber(profile.nextID) or 1,
                list = CopyTableValue(profile.list),
            }
        else
            migratedBags = CopyBestPerCharacterScope(profile, "bags")
        end
        if migratedBags then
            profile.bags = migratedBags
        end
    end

    if not ScopedConfigHasCategories(profile.bank) then
        local migratedBank = CopyBestPerCharacterScope(profile, "bank")
        if migratedBank then
            profile.bank = migratedBank
        end
    end

    profile._migratedSharedCategoryScopes = true
end

local function EnsureScopedConfig(scope)
    local profile = GetProfile()
    if not profile then
        return nil
    end

    scope = NormalizeScope(scope)
    MigrateSharedScopes(profile)

    -- Migration: early sessions could resolve character identity as unknown and
    -- write categories into a shared placeholder bucket.
    if profile._migratedUnknownCharacterKey ~= true then
        profile.perCharacter = profile.perCharacter or {}
        local key = GetCharacterKey()
        local perChar = key and profile.perCharacter[key] or nil
        local unknownBuckets = {
            "Unknown-UnknownRealm",
            "Unknown-",
            "-UnknownRealm",
            "Unknown Entity-Unknown Realm",
        }
        for _, oldKey in ipairs(unknownBuckets) do
            local oldChar = profile.perCharacter[oldKey]
            if type(oldChar) == "table" and oldChar ~= perChar then
                if perChar then
                    perChar.bags = perChar.bags or oldChar.bags
                    perChar.bank = perChar.bank or oldChar.bank
                end
                profile.perCharacter[oldKey] = nil
            end
        end
        profile._migratedUnknownCharacterKey = true
    end

    -- Migration: early category builds stored bag categories directly at
    -- profile.categories.list before categories were per character and scoped.
    if scope == "bags" and profile._migratedFlatListToPerCharacter ~= true then
        local cfg = profile.bags or {}
        if type(profile.list) == "table" and #profile.list > 0 and not ScopedConfigHasCategories(cfg) then
            cfg.list = CopyTableValue(profile.list)
            cfg.enabled = profile.enabled == true
            cfg.columns = tonumber(profile.columns) or cfg.columns or 1
            cfg.nextID = tonumber(profile.nextID) or cfg.nextID or 1
            profile.bags = cfg
        end
        profile._migratedFlatListToPerCharacter = true
    end

    profile[scope] = profile[scope] or {}
    return EnsureDefaultScopedFields(profile[scope])
end

function Categories:GetConfig(scope)
    return EnsureScopedConfig(scope)
end

function Categories:GetList(scope)
    local cfg = EnsureScopedConfig(scope)
    return cfg and cfg.list or {}
end

function Categories:AddCategory(scope)
    local cfg = EnsureScopedConfig(scope)
    if not cfg then return nil end
    local list = cfg.list
    local nextID = (cfg.nextID or 1)
    cfg.nextID = nextID + 1
    local category = {
        id = "cat" .. tostring(nextID),
        name = "Category " .. tostring(nextID),
        enabled = true,
        rules = {},
    }
    list[#list + 1] = category
    return category
end

function Categories:RemoveCategory(index, scope)
    local list = self:GetList(scope)
    index = tonumber(index)
    if index and list[index] then
        table.remove(list, index)
        return true
    end
    return false
end

function Categories:MoveCategory(index, direction, scope)
    local list = self:GetList(scope)
    index = tonumber(index)
    direction = tonumber(direction)
    if not index or not direction or direction == 0 then
        return false
    end
    local target = index + direction
    if not list[index] or not list[target] then
        return false
    end
    list[index], list[target] = list[target], list[index]
    return true
end

function Categories:RegisterMatcher(name, fn)
    if type(name) == "string" and type(fn) == "function" then
        self.customMatchers[name] = fn
    end
end

function Categories:AddItemIDRule(category, itemID)
    if type(category) ~= "table" then
        return false
    end
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    category.rules = category.rules or {}
    local existing = SplitCSV(category.rules.itemIDs)
    local itemIDText = tostring(itemID)
    for _, token in ipairs(existing) do
        if tonumber(token) == itemID then
            return false
        end
    end

    existing[#existing + 1] = itemIDText
    category.rules.itemIDs = table.concat(existing, ",")
    return true
end

function Categories:RemoveItemIDRule(category, itemID)
    if type(category) ~= "table" or type(category.rules) ~= "table" then
        return false
    end
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local changed = false
    local remaining = {}
    for _, token in ipairs(SplitCSV(category.rules.itemIDs)) do
        if tonumber(token) == itemID then
            changed = true
        else
            remaining[#remaining + 1] = token
        end
    end

    if changed then
        category.rules.itemIDs = (#remaining > 0) and table.concat(remaining, ",") or nil
    end
    return changed
end

function Categories:AddBlacklistItemID(category, itemID)
    if type(category) ~= "table" then
        return false
    end
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    category.rules = category.rules or {}
    local existing = SplitCSV(category.rules.blacklistItemIDs)
    for _, token in ipairs(existing) do
        if tonumber(token) == itemID then
            return false
        end
    end

    existing[#existing + 1] = tostring(itemID)
    category.rules.blacklistItemIDs = table.concat(existing, ",")
    return true
end

local function MatchEquipmentSet(item)
    if not item or not item.itemID then return false end

    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs then
        local setIDs = C_EquipmentSet.GetEquipmentSetIDs() or {}
        for _, setID in ipairs(setIDs) do
            local itemIDs = C_EquipmentSet.GetItemIDs(setID)
            if type(itemIDs) == "table" then
                for _, id in pairs(itemIDs) do
                    if tonumber(id) == tonumber(item.itemID) then
                        return true
                    end
                end
            end
        end
    end

    if ItemRackUser and type(ItemRackUser) == "table" and type(ItemRackUser.Sets) == "table" then
        for _, set in pairs(ItemRackUser.Sets) do
            if type(set) == "table" then
                for _, id in pairs(set) do
                    if tonumber(id) == tonumber(item.itemID) then
                        return true
                    end
                end
            end
        end
    end

    if Outfitter and type(Outfitter.ItemList_GetAllItems) == "function" then
        local ok, items = pcall(Outfitter.ItemList_GetAllItems, Outfitter)
        if ok and type(items) == "table" then
            for _, outfitterItem in pairs(items) do
                local id = type(outfitterItem) == "table" and outfitterItem.Code or outfitterItem
                if tonumber(id) == tonumber(item.itemID) then
                    return true
                end
            end
        end
    end

    return false
end

function Categories:IsEquipmentSetItem(item)
    return MatchEquipmentSet(item)
end

function Categories:ItemMatches(category, item)
    if not category or category.enabled == false or not item then return false end
    local rules = category.rules or {}
    local hasRule = false

    if rules.blacklistItemIDs and rules.blacklistItemIDs ~= "" and MatchCSVNumber(item.itemID, rules.blacklistItemIDs) then
        return false
    end

    if rules.itemIDs and rules.itemIDs ~= "" then
        hasRule = true
        if not MatchCSVNumber(item.itemID, rules.itemIDs) then return false end
    end
    if rules.qualityEnabled == true and rules.minQuality ~= nil then
        hasRule = true
        if (tonumber(item.quality) or -1) < tonumber(rules.minQuality) then return false end
    end
    if rules.qualityEnabled == true and rules.maxQuality ~= nil then
        hasRule = true
        if (tonumber(item.quality) or -1) > tonumber(rules.maxQuality) then return false end
    end
    if rules.classIDs and rules.classIDs ~= "" then
        hasRule = true
        if not MatchCSVNumber(item.classID, rules.classIDs) then return false end
    end
    if rules.subClassIDs and rules.subClassIDs ~= "" then
        hasRule = true
        if not MatchCSVNumber(item.subClassID, rules.subClassIDs) then return false end
    end
    if rules.subClassPairs and rules.subClassPairs ~= "" then
        hasRule = true
        if not MatchCSVPair(item.classID, item.subClassID, rules.subClassPairs) then return false end
    end
    if rules.equipLocs and rules.equipLocs ~= "" then
        hasRule = true
        if not MatchCSVText(item.equipLoc, rules.equipLocs) then return false end
    end
    if rules.equipmentSet == true then
        hasRule = true
        if not MatchEquipmentSet(item) then return false end
    end

    for name, fn in pairs(self.customMatchers) do
        if rules[name] == true then
            hasRule = true
            local ok, matched = pcall(fn, item, category)
            if not ok or not matched then return false end
        end
    end

    return hasRule
end

function Categories:MatchItem(item, scope)
    if not item then return nil end
    local cfg = EnsureScopedConfig(scope)
    if not cfg or cfg.enabled ~= true then return nil end
    for index, category in ipairs(cfg.list or {}) do
        if self:ItemMatches(category, item) then
            return category, index
        end
    end
    return nil
end
