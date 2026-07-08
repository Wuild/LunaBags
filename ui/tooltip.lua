local _, ns = ...
local LunaBags = ns.LunaBags

local Tooltip = LunaBags and LunaBags:CreateModule("tooltip") or {}
ns.Tooltip = Tooltip

local function ShouldShowCharacterItemCountTooltip()
    local profile = LunaBags and LunaBags.db and LunaBags.db.profile
    local tooltips = profile and profile.tooltips
    if type(tooltips) ~= "table" then
        return true
    end
    return tooltips.showAcrossCharacters ~= false
end

local function AddCharacterItemCountTooltip(tt, itemID)
    if not ns.BagData or not itemID then
        return
    end
    if not ShouldShowCharacterItemCountTooltip() then
        return
    end

    local hasAny = false
    for _, _ in ns.BagData:IterCharacters() do
        hasAny = true
        break
    end
    if not hasAny then
        return
    end

    tt:AddLine(" ")
    tt:AddLine("Item Across Characters", 0.9, 0.9, 0.9)
    for _, c in ns.BagData:IterCharacters() do
        local bagsCount, bankCount = 0, 0
        if c and c.bags then
            for _, bagData in pairs(c.bags) do
                if bagData and bagData.slots then
                    for _, s in pairs(bagData.slots) do
                        if s and tonumber(s.itemID) == itemID then
                            bagsCount = bagsCount + (s.stackCount or 1)
                        end
                    end
                end
            end
        end
        if c and c.bank then
            for _, bagData in pairs(c.bank) do
                if bagData and bagData.slots then
                    for _, s in pairs(bagData.slots) do
                        if s and tonumber(s.itemID) == itemID then
                            bankCount = bankCount + (s.stackCount or 1)
                        end
                    end
                end
            end
        end
        local total = bagsCount + bankCount
        if total > 0 then
            local name = (c and c.name) or "Unknown"
            tt:AddDoubleLine(name, string.format("%d (bags %d / bank %d)", total, bagsCount, bankCount), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
end

function Tooltip:EnsureHooks()
    if self._hooked or not GameTooltip then
        return
    end
    self._hooked = true

    GameTooltip:HookScript("OnTooltipCleared", function(tt)
        tt.LunaBagsAugmentedItemID = nil
    end)

    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        local _, link = tt:GetItem()
        if not link then
            return
        end
        local itemID = tonumber(link:match("item:(%d+)"))
        if not itemID then
            return
        end
        if tt.LunaBagsAugmentedItemID == itemID then
            return
        end
        tt.LunaBagsAugmentedItemID = itemID
        AddCharacterItemCountTooltip(tt, itemID)
    end)
end

Tooltip:EnsureHooks()
