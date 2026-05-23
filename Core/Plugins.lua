local _, ns = ...

local Plugins = {
    registry = {},
}
local POOR_QUALITY = _G.LE_ITEM_QUALITY_POOR or 0

ns.Plugins = Plugins

local function EnsurePluginConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return nil
    end
    addon.db.profile.plugins = addon.db.profile.plugins or {}
    return addon.db.profile.plugins
end

function Plugins:Register(id, def)
    if not id or type(def) ~= "table" then
        return
    end
    self.registry[id] = def
end

function Plugins:IsEnabled(id)
    local cfg = EnsurePluginConfig()
    local def = self.registry[id]
    if not def then
        return false
    end
    if not cfg then
        return def.defaultEnabled == true
    end
    local value = cfg[id]
    if value == nil then
        return def.defaultEnabled == true
    end
    return value
end

function Plugins:Apply(button, entry, context)
    for id, def in pairs(self.registry) do
        if def.apply then
            def.apply(button, entry, context, self:IsEnabled(id))
        end
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

local function IsQuestItem(item)
    -- Item class "Quest" includes repeatable turn-in items such as Mark of Sargeras.
    -- Only Blizzard's per-slot quest flag should trigger the quest border.
    return item and item.isQuestItem == true
end

local function EnsureTrashIcon(button)
    if button.trashIcon then
        return button.trashIcon
    end
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(13, 13)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    icon:Hide()
    button.trashIcon = icon
    return icon
end

Plugins:Register("qualityBorder", {
    defaultEnabled = true,
    apply = function(button, entry, _, enabled)
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
            -- Blizzard quest yellow
            r, g, b, a = 1, 0.82, 0, 1
            button.StyleBorderBaseR = r
            button.StyleBorderBaseG = g
            button.StyleBorderBaseB = b
            button.StyleBorderBaseA = a
            button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
        else
            button.StyleBorderBaseR = r
            button.StyleBorderBaseG = g
            button.StyleBorderBaseB = b
            button.StyleBorderBaseA = a
            button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
        end
    end,
})

Plugins:Register("trashIcon", {
    defaultEnabled = true,
    apply = function(button, entry, _, enabled)
        local icon = EnsureTrashIcon(button)
        if not enabled then
            icon:Hide()
            return
        end
        local item = entry and entry.item
        if not item then
            icon:Hide()
            return
        end
        local quality = item.quality
        if quality == nil and item.itemLink then
            local _, _, q = GetItemInfo(item.itemLink)
            quality = q
        end
        if quality == POOR_QUALITY then
            icon:Show()
        else
            icon:Hide()
        end
    end,
})
