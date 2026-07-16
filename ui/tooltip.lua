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

local function GetCharacterItemCountCache()
    if not ns.BagData then
        return nil
    end

    local revision = tonumber(ns.BagData._tooltipCountRevision) or 0
    if ns.BagData._itemCountCacheRevision == revision and type(ns.BagData._itemCountCache) == "table" then
        return ns.BagData._itemCountCache
    end

    local cache = {}
    for key, character in ns.BagData:IterCharacters() do
        local entry = cache[key]
        if not entry then
            entry = {
                name = (character and character.name) or key,
                realm = character and character.realm or nil,
                bags = 0,
                bank = 0,
            }
            cache[key] = entry
        end

        local function Accumulate(container, isBank)
            if type(container) ~= "table" then
                return
            end
            for _, bagData in pairs(container) do
                local slots = bagData and bagData.slots
                if type(slots) == "table" then
                    for _, s in pairs(slots) do
                        local itemID = tonumber(s and s.itemID)
                        if itemID then
                            local count = tonumber(s.stackCount) or 1
                            local bucket = cache[itemID]
                            if not bucket then
                                bucket = {}
                                cache[itemID] = bucket
                            end
                            local itemEntry = bucket[key]
                            if not itemEntry then
                                itemEntry = {
                                    name = entry.name,
                                    realm = entry.realm,
                                    bags = 0,
                                    bank = 0,
                                }
                                bucket[key] = itemEntry
                            end
                            if isBank then
                                itemEntry.bank = itemEntry.bank + count
                            else
                                itemEntry.bags = itemEntry.bags + count
                            end
                        end
                    end
                end
            end
        end

        Accumulate(character and character.bags, false)
        Accumulate(character and character.bank, true)
    end

    ns.BagData._itemCountCache = cache
    ns.BagData._itemCountCacheRevision = revision
    return cache
end

local function AddCharacterItemCountTooltip(tt, itemID)
    if not itemID then
        return
    end
    if not ShouldShowCharacterItemCountTooltip() then
        return
    end

    local cache = GetCharacterItemCountCache()
    local counts = cache and cache[itemID]
    if type(counts) ~= "table" then
        return
    end

    tt:AddLine(" ")
    tt:AddLine("Item Across Characters", 0.9, 0.9, 0.9)
    for key, countsForCharacter in pairs(counts) do
        local bagsCount = tonumber(countsForCharacter and countsForCharacter.bags) or 0
        local bankCount = tonumber(countsForCharacter and countsForCharacter.bank) or 0
        local total = bagsCount + bankCount
        if total > 0 then
            local name = (countsForCharacter and countsForCharacter.name) or key or "Unknown"
            local realm = countsForCharacter and countsForCharacter.realm
            if realm and realm ~= "" then
                name = name .. " - " .. realm
            end
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
