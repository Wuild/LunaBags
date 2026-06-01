local name, addon = ...

local Plugin = {
    name = "Item Level Text",
    id = "itemLevelText",
    defaultEnabled = true,
}

local function GetItemLevelTextLayout()
    local profile = addon and addon.LunaBags and addon.LunaBags.db and addon.LunaBags.db.profile
    local plugins = profile and profile.plugins or nil
    local options = plugins and plugins.itemLevelTextOptions or nil
    local align = (options and options.align) or "left"
    if align ~= "right" then
        align = "left"
    end
    local x = tonumber(options and options.offsetX) or 2
    local y = tonumber(options and options.offsetY) or 2
    return align, x, y
end

local function EnsureItemLevelText(button)
    if not button then
        return nil
    end
    if button.LunaBagsItemLevelText then
        return button.LunaBagsItemLevelText
    end

    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    if addon.ItemButtonStyle and addon.ItemButtonStyle.ApplyItemTextFont then
        addon.ItemButtonStyle.ApplyItemTextFont(fs)
    end
    fs:SetText("")
    fs:Hide()
    button.LunaBagsItemLevelText = fs
    return fs
end

local function ApplyItemLevelAnchor(fs, button)
    if not fs or not button then
        return
    end
    local align, x, y = GetItemLevelTextLayout()
    fs:ClearAllPoints()
    if align == "right" then
        fs:SetPoint("TOPRIGHT", button, "TOPRIGHT", -x, -y)
        fs:SetJustifyH("RIGHT")
    else
        fs:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
        fs:SetJustifyH("LEFT")
    end
end

local function ResolveItemLevel(item)
    if not item then
        return nil
    end

    local itemLevel = tonumber(item.itemLevel)
    if itemLevel and itemLevel > 0 then
        return itemLevel
    end

    if item.itemLink and GetDetailedItemLevelInfo then
        local detailedLevel = GetDetailedItemLevelInfo(item.itemLink)
        itemLevel = tonumber(detailedLevel)
        if itemLevel and itemLevel > 0 then
            return itemLevel
        end
    end

    if item.itemLink and GetItemInfo then
        local _, _, _, baseLevel = GetItemInfo(item.itemLink)
        itemLevel = tonumber(baseLevel)
        if itemLevel and itemLevel > 0 then
            return itemLevel
        end
    end

    return nil
end

local function ResolveItemQuality(item)
    if not item then
        return nil
    end

    local quality = tonumber(item.quality)
    if quality ~= nil then
        return quality
    end

    if item.itemLink and GetItemInfo then
        local _, _, q = GetItemInfo(item.itemLink)
        quality = tonumber(q)
        if quality ~= nil then
            return quality
        end
    end

    return nil
end

local function IsEquippableItem(item)
    if not item then
        return false
    end

    local equipLoc = item.equipLoc
    if (not equipLoc or equipLoc == "") and item.itemLink and GetItemInfo then
        local _, _, _, _, _, _, _, _, slot = GetItemInfo(item.itemLink)
        equipLoc = slot
    end

    if type(equipLoc) ~= "string" or equipLoc == "" then
        return false
    end

    if equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
        return false
    end

    return true
end

local function ResolveItemLevelColor(itemLevel)
    if not itemLevel then
        return 1.00, 1.00, 1.00
    end
    if itemLevel >= 400 then
        return 0.80, 0.62, 1.00
    elseif itemLevel >= 300 then
        return 0.22, 0.80, 1.00
    elseif itemLevel >= 200 then
        return 0.20, 1.00, 0.20
    end
    return 1.00, 1.00, 1.00
end

function Plugin:Apply(button, entry, _, enabled)
    local fs = EnsureItemLevelText(button)
    if not fs then
        return
    end
    ApplyItemLevelAnchor(fs, button)

    if not enabled then
        fs:SetText("")
        fs:Hide()
        return
    end

    local item = entry and entry.item
    if not IsEquippableItem(item) then
        fs:SetText("")
        fs:Hide()
        return
    end

    local quality = ResolveItemQuality(item)
    if not quality or quality < 2 then
        fs:SetText("")
        fs:Hide()
        return
    end

    local itemLevel = ResolveItemLevel(item)
    if not itemLevel then
        fs:SetText("")
        fs:Hide()
        return
    end

    local r, g, b = ResolveItemLevelColor(itemLevel)
    fs:SetTextColor(r, g, b, 1)
    fs:SetText(tostring(math.floor(itemLevel + 0.5)))
    fs:Show()
end

function Plugin:GetOptions(api)
    return {
        type = "group",
        name = "Item Level Text",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Item Level Text",
                order = 1,
                get = function()
                    return api.getEnabled(false)
                end,
                set = function(_, value)
                    api.setEnabled(value)
                end,
            },
            align = {
                type = "select",
                name = "Align",
                order = 2,
                values = {
                    left = "Left",
                    right = "Right",
                },
                get = function()
                    return api.get("align", "left")
                end,
                set = function(_, value)
                    api.set("align", value)
                end,
            },
            offsetX = {
                type = "range",
                name = "X Offset",
                order = 3,
                min = 0,
                max = 20,
                step = 1,
                get = function()
                    return api.get("offsetX", 2)
                end,
                set = function(_, value)
                    api.set("offsetX", value)
                end,
            },
            offsetY = {
                type = "range",
                name = "Y Offset",
                order = 4,
                min = 0,
                max = 20,
                step = 1,
                get = function()
                    return api.get("offsetY", 2)
                end,
                set = function(_, value)
                    api.set("offsetY", value)
                end,
            },
        },
    }
end

addon.LunaBags:RegisterPlugin(Plugin)
