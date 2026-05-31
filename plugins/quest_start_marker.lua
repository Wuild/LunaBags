local name, addon = ...

local Plugin = {
    name = "Quest Start Marker",
    id = "questStartMarker",
    defaultEnabled = true,
}

local function EnsureQuestStartMarker(button)
    if not button then
        return nil
    end
    if button.LunaBagsQuestStartMarker then
        return button.LunaBagsQuestStartMarker
    end

    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    fs:SetJustifyH("RIGHT")
    if addon.ItemButtonStyle and addon.ItemButtonStyle.ApplyItemTextFont then
        addon.ItemButtonStyle.ApplyItemTextFont(fs)
    end
    fs:SetText("?")
    fs:SetTextColor(1.00, 0.92, 0.25, 1.00)
    fs:Hide()
    button.LunaBagsQuestStartMarker = fs
    return fs
end

local function IsQuestCompleted(questID)
    if not questID then
        return false
    end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID) == true
    end
    return false
end

local function GetQuestInfoForContainerSlot(bagID, slot)
    if C_Container and C_Container.GetContainerItemQuestInfo then
        local info = C_Container.GetContainerItemQuestInfo(bagID, slot)
        if type(info) == "table" then
            return info.questID, info.isActive
        end
    end
    if GetContainerItemQuestInfo then
        local _, questID, isActive = GetContainerItemQuestInfo(bagID, slot)
        return questID, isActive
    end
    return nil, nil
end

local function ShouldShowQuestStartMarker(button, entry)
    if not button or not entry or not entry.item then
        return false
    end

    local bagID = button.bagID or button.BagID
    local slot = button.slot or button.SlotID or button:GetID()
    if not bagID or not slot then
        return false
    end

    local questID, isActive = GetQuestInfoForContainerSlot(bagID, slot)
    if not questID or questID <= 0 then
        return false
    end
    if isActive then
        return false
    end
    if IsQuestCompleted(questID) then
        return false
    end
    return true
end

function Plugin:Apply(button, entry, context, enabled)
    local marker = EnsureQuestStartMarker(button)
    if not marker then
        return
    end

    if not enabled then
        marker:Hide()
        return
    end

    if context ~= "oneBag" and context ~= "oneBank" then
        marker:Hide()
        return
    end

    marker:SetShown(ShouldShowQuestStartMarker(button, entry))
end

addon.LunaBags:RegisterPlugin(Plugin)
