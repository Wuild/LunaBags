local name, addon = ...

local Plugin = {
    name = "TrashIcon",
    id = "trashIcon",
    defaultEnabled = true,
}

local POOR_QUALITY = _G.LE_ITEM_QUALITY_POOR or 0
local TRASH_ICON_GRAYSCALE = 0.82
local ICON_INSET = 2

local function ResolveButtonIcon(button)
    if not button then
        return nil
    end
    local buttonName = button.GetName and button:GetName() or nil
    local itemIcon = button.icon
        or button.Icon
        or button.IconTexture
        or (buttonName and (_G[buttonName .. "IconTexture"] or _G[buttonName .. "Icon"]))
    if itemIcon then
        button.icon = itemIcon
    end
    return itemIcon
end

local function SetItemIconVisual(button, desaturated, r, g, b)
    if SetItemButtonDesaturated then
        SetItemButtonDesaturated(button, desaturated == true, r, g, b)
    end

    local itemIcon = ResolveButtonIcon(button)
    if itemIcon then
        if itemIcon.SetDesaturated then
            itemIcon:SetDesaturated(desaturated == true)
        end
        if itemIcon.SetVertexColor then
            itemIcon:SetVertexColor(r or 1, g or 1, b or 1, 1)
        end
    end

    if SetItemButtonTextureVertexColor then
        SetItemButtonTextureVertexColor(button, r or 1, g or 1, b or 1)
    end
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

local function EnsureGrayscaleOverlay(button)
    if button.trashGrayscaleOverlay then
        return button.trashGrayscaleOverlay
    end

    local itemIcon = ResolveButtonIcon(button)
    local overlay = button:CreateTexture(nil, "ARTWORK")
    if overlay.SetDrawLayer then
        overlay:SetDrawLayer("ARTWORK", 7)
    end
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
    overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    overlay:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if overlay.SetDesaturated then
        overlay:SetDesaturated(true)
    end
    overlay:SetVertexColor(TRASH_ICON_GRAYSCALE, TRASH_ICON_GRAYSCALE, TRASH_ICON_GRAYSCALE, 1)
    overlay:Hide()
    button.trashGrayscaleOverlay = overlay
    return overlay
end

local function SyncGrayscaleOverlay(button, itemIcon)
    local overlay = EnsureGrayscaleOverlay(button)
    itemIcon = itemIcon or ResolveButtonIcon(button)
    if itemIcon then
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
        overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
        if itemIcon.GetTexture and overlay.SetTexture then
            overlay:SetTexture(itemIcon:GetTexture())
        end
    end
    overlay:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if overlay.SetDesaturated then
        overlay:SetDesaturated(true)
    end
    overlay:SetVertexColor(TRASH_ICON_GRAYSCALE, TRASH_ICON_GRAYSCALE, TRASH_ICON_GRAYSCALE, 1)
    overlay:Show()
end

local function HideGrayscaleOverlay(button)
    if button and button.trashGrayscaleOverlay then
        button.trashGrayscaleOverlay:Hide()
    end
end

local function RestoreItemIcon(button)
    HideGrayscaleOverlay(button)
    if not button or not button._lunaTrashGrayscaleApplied then
        return
    end
    button._lunaTrashGrayscaleApplied = nil

    local desaturated = button._lunaBagsLocked == true or button._lunaBagsSortingDesaturated == true
    if button._lunaBagsLocked == true then
        SetItemIconVisual(button, desaturated, 0.45, 0.45, 0.45)
    else
        SetItemIconVisual(button, desaturated, 1, 1, 1)
    end
end

function Plugin:Apply(button, entry, _, enabled)
    local icon = EnsureTrashIcon(button)
    if not enabled then
        icon:Hide()
        RestoreItemIcon(button)
        return
    end
    local item = entry and entry.item
    if not item then
        icon:Hide()
        RestoreItemIcon(button)
        return
    end
    local quality = item.quality
    if quality == nil and item.itemLink then
        local _, _, q = GetItemInfo(item.itemLink)
        quality = q
    end
    if quality == POOR_QUALITY then
        icon:Show()
        SyncGrayscaleOverlay(button)
        button._lunaTrashGrayscaleApplied = true
    else
        icon:Hide()
        RestoreItemIcon(button)
    end
end

addon.LunaBags:RegisterPlugin(Plugin)
