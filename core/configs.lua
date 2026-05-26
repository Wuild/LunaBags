local name, addon = ...

addon.configsDefaults = {
    profile = {
        enabled = true,
        debug = false,
        ui = {
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            itemFrameColor = { r = 0.13, g = 0.13, b = 0.13 },
            itemFrameOpacity = 0.92,
            itemBorderSize = 1,
            stackCountTextSize = 12,
            cooldownTextSize = 16,
        },
        oneBag = {
            columns = 11,
            windowWidth = 481,
            windowMaxHeight = 650,
            itemSize = 37,
            spacing = 4,
            splitByBagRows = false,
            splitBags = {},
            showBagRail = true,
            scale = 1,
            locked = false,
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            point = "BOTTOMRIGHT",
            x = -34,
            y = 126,
        },
        oneBank = {
            columns = 14,
            windowWidth = 590,
            windowMaxHeight = 650,
            itemSize = 36,
            spacing = 4,
            splitBags = {},
            visibleBags = {},
            scale = 1,
            locked = false,
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            point = "BOTTOMLEFT",
            x = 34,
            y = 126,
        },
        oneGuildBank = {
            columns = 14,
            itemSize = 36,
            spacing = 4,
            scale = 1,
            locked = false,
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            point = "CENTER",
            x = 0,
            y = 0,
        },
        plugins = {
            qualityBorder = true,
            equipmentSetBorder = true,
            trashIcon = true,
        },
        modules = {
            oneBag = true,
            oneBank = true,
            oneGuildBank = true,
        },
        sorting = {
            priorityItemIDs = "6948",
            reverseSlotOrder = false,
            visualOnly = false,
            rules = {
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
            },
        },
        categories = {
            bags = {
                enabled = false,
                columns = 1,
                layout = "masonry",
                nextID = 1,
                list = {},
            },
            bank = {
                enabled = false,
                columns = 1,
                layout = "masonry",
                nextID = 1,
                list = {},
            },
        },
    },
}

addon.oldDefaultSortRules = {
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

addon.simplifiedDefaultSortRules = {
    { key = "priority", direction = "asc", enabled = true },
    { key = "quality", direction = "desc", enabled = true },
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "count", direction = "desc", enabled = true },
}

addon.priorityQualityDefaultSortRules = {
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

function addon:CopySortRules(rules)
    local copy = {}
    for index, rule in ipairs(rules or {}) do
        copy[index] = {
            key = rule.key,
            direction = rule.direction,
            enabled = rule.enabled ~= false,
        }
    end
    return copy
end

function addon:SortRulesMatch(actual, expected)
    if type(actual) ~= "table" or #actual ~= #expected then
        return false
    end
    for index, expectedRule in ipairs(expected) do
        local actualRule = actual[index]
        if type(actualRule) ~= "table"
            or actualRule.key ~= expectedRule.key
            or (actualRule.direction == "desc" and "desc" or "asc") ~= expectedRule.direction
            or (actualRule.enabled ~= false) ~= (expectedRule.enabled ~= false)
        then
            return false
        end
    end
    return true
end
