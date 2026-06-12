local name, addon = ...

local Plugin = {
    name = "QualityBorder",
    id = "qualityBorder",
    defaultEnabled = true,
}

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

local function IsQuestItem(item)
    return item and item.isQuestItem == true
end

local function IsEquipmentSetItem(item)
    return addon.Categories
        and addon.Categories.IsEquipmentSetItem
        and addon.Categories:IsEquipmentSetItem(item)
        or false
end

function Plugin:Apply(button, entry, _, enabled)
    if not button or not button.StyleBorder then
        return
    end

    local item = entry and entry.item
    local quality = enabled and item and item.quality or nil
    local isQuestItem = false

    if enabled and quality == nil and item and item.itemLink and GetItemInfo then
        local _, _, q = GetItemInfo(item.itemLink)
        quality = q
    end

    isQuestItem = enabled and IsQuestItem(item) or false

    local r, g, b, a = ResolveQualityBorderColor(quality)

    if isQuestItem then
        r, g, b, a = 1, 0.82, 0, 1
    elseif enabled and addon.Plugins and addon.Plugins:IsEnabled("equipmentSetBorder") and IsEquipmentSetItem(item) then
        r, g, b, a = 0.20, 0.72, 1.0, 1
    end

    if addon.ItemButtonStyle and addon.ItemButtonStyle.SetBorderColor then
        addon.ItemButtonStyle.SetBorderColor(button, r, g, b, a)
    else
        button.StyleBorderBaseR = r
        button.StyleBorderBaseG = g
        button.StyleBorderBaseB = b
        button.StyleBorderBaseA = a
        button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
    end
end

addon.LunaBags:RegisterPlugin(Plugin)
