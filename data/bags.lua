local _, ns = ...
local LunaBags = ns.LunaBags

local BagData = LunaBags and LunaBags:CreateModule("bags") or {}
ns.BagData = BagData

local CContainer = C_Container
local BAG_IDS = {
    0, 1, 2, 3, 4,
}

local BANK_BAG_IDS = {
    -1, 5, 6, 7, 8, 9, 10, 11,
}

local function NormalizeKey(text)
    return tostring(text or ""):lower():gsub("%s+", "")
end

local function GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return ("%s-%s"):format(name, realm)
end

local function EnsureGlobal()
    local addon = ns.LunaBags
    if not addon or not addon.db then
        return nil
    end
    addon.db.global = addon.db.global or {}
    addon.db.global.characters = addon.db.global.characters or {}
    return addon.db.global
end

local function EnsureCharacterRecord()
    local global = EnsureGlobal()
    if not global then
        return nil
    end
    local key = GetCharacterKey()
    local character = global.characters[key] or {}
    global.characters[key] = character
    character.name = UnitName("player")
    character.realm = GetRealmName()
    character.class = select(2, UnitClass("player"))
    character.faction = UnitFactionGroup("player")
    character.location = GetRealZoneText()
    local addon = ns.LunaBags
    if addon and addon.db and addon.db.keys and addon.db.keys.profile then
        character.profileKey = addon.db.keys.profile
    end
    return character
end

function BagData:GetAllCharacters()
    local global = EnsureGlobal()
    if not global then
        return {}
    end
    return global.characters or {}
end

local function GetQuestItemFlagFromContainer(bagID, slot, itemInfo)
    if itemInfo and itemInfo.isQuestItem == true then
        return true
    end

    if CContainer and CContainer.GetContainerItemQuestInfo then
        local questInfo = CContainer.GetContainerItemQuestInfo(bagID, slot)
        if type(questInfo) == "table" then
            return questInfo.isQuestItem == true
        end
        return questInfo == true
    end

    if GetContainerItemQuestInfo then
        local isQuestItem = GetContainerItemQuestInfo(bagID, slot)
        return isQuestItem == true
    end

    return false
end

local function BuildItemData(bagID, slot)
    if CContainer and CContainer.GetContainerItemInfo then
        local itemInfo = CContainer.GetContainerItemInfo(bagID, slot)
        if not itemInfo then
            return nil
        end
        local itemLink = CContainer.GetContainerItemLink and CContainer.GetContainerItemLink(bagID, slot)
        return {
            itemID = itemInfo.itemID,
            itemLink = itemLink,
            stackCount = itemInfo.stackCount or 1,
            quality = itemInfo.quality,
            isBound = itemInfo.isBound,
            isQuestItem = GetQuestItemFlagFromContainer(bagID, slot, itemInfo),
            iconFileID = itemInfo.iconFileID,
        }
    end

    local texture, count, locked, quality = GetContainerItemInfo(bagID, slot)
    if not texture then
        return nil
    end
    local itemLink = GetContainerItemLink and GetContainerItemLink(bagID, slot)
    local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil
    return {
        itemID = itemID,
        itemLink = itemLink,
        stackCount = count or 1,
        quality = quality,
        isBound = nil,
        isQuestItem = GetQuestItemFlagFromContainer(bagID, slot, nil),
        iconFileID = texture,
        isLocked = locked,
    }
end

local function ScanBagList(target, bagIDs)
    local capacity = 0
    for _, bagID in ipairs(bagIDs) do
        capacity = capacity + (BagData:ScanSingleBag(target, bagID) or 0)
    end
    return capacity
end

function BagData:ScanSingleBag(target, bagID)
    if type(target) ~= "table" then
        return 0
    end
    local slotCount
    if CContainer and CContainer.GetContainerNumSlots then
        slotCount = CContainer.GetContainerNumSlots(bagID)
    else
        slotCount = GetContainerNumSlots(bagID)
    end
    slotCount = slotCount or 0
    local bagData = { size = slotCount, slots = {} }
    for slot = 1, slotCount do
        bagData.slots[slot] = BuildItemData(bagID, slot)
    end
    target[bagID] = bagData
    return slotCount
end

local function GetCachedBagCapacity(bags)
    if type(bags) ~= "table" then
        return 0
    end
    local total = 0
    for _, bagData in pairs(bags) do
        if type(bagData) == "table" then
            total = total + (tonumber(bagData.size) or 0)
        end
    end
    return total
end

function BagData:ScanBags(includeBank)
    self._scanToken = (self._scanToken or 0) + 1
    local character = EnsureCharacterRecord()
    if not character then
        return
    end
    character.lastUpdate = time()
    character.bags = character.bags or {}
    character.bank = character.bank or {}

    local prevBags = character.bags
    local newBags = {}
    local bagCapacity = ScanBagList(newBags, BAG_IDS)
    local prevCapacity = GetCachedBagCapacity(prevBags)
    if bagCapacity > 0 or prevCapacity <= 0 then
        character.bags = newBags
    else
        character.bags = prevBags or {}
    end

    if includeBank then
        local prevBank = character.bank
        local newBank = {}
        local bankCapacity = ScanBagList(newBank, BANK_BAG_IDS)
        local prevBankCapacity = GetCachedBagCapacity(prevBank)
        if bankCapacity > 0 or prevBankCapacity <= 0 then
            character.bank = newBank
        else
            character.bank = prevBank or {}
        end
    end

    self._tooltipCountRevision = (self._tooltipCountRevision or 0) + 1
end

function BagData:ScanBagsDeferred(includeBank, onDone)
    if not CreateFrame then
        self:ScanBags(includeBank)
        if type(onDone) == "function" then
            onDone()
        end
        return
    end

    self._scanToken = (self._scanToken or 0) + 1
    local token = self._scanToken
    local character = EnsureCharacterRecord()
    if not character then
        if type(onDone) == "function" then
            onDone()
        end
        return
    end

    character.lastUpdate = time()
    character.bags = character.bags or {}
    character.bank = character.bank or {}

    local job = {
        token = token,
        includeBank = includeBank == true,
        character = character,
        prevBags = character.bags,
        prevBank = character.bank,
        newBags = {},
        newBank = {},
        bagIndex = 1,
        bankIndex = 1,
        bagCapacity = 0,
        bankCapacity = 0,
        onDone = onDone,
    }
    self._scanJob = job

    if not self._scanFrame then
        self._scanFrame = CreateFrame("Frame")
    end

    self._scanFrame:SetScript("OnUpdate", function(frame)
        local current = BagData._scanJob
        if not current or current.token ~= BagData._scanToken then
            frame:SetScript("OnUpdate", nil)
            return
        end

        if current.bagIndex <= #BAG_IDS then
            local bagID = BAG_IDS[current.bagIndex]
            current.bagCapacity = current.bagCapacity + (BagData:ScanSingleBag(current.newBags, bagID) or 0)
            current.bagIndex = current.bagIndex + 1
            return
        end

        if current.includeBank and current.bankIndex <= #BANK_BAG_IDS then
            local bagID = BANK_BAG_IDS[current.bankIndex]
            current.bankCapacity = current.bankCapacity + (BagData:ScanSingleBag(current.newBank, bagID) or 0)
            current.bankIndex = current.bankIndex + 1
            return
        end

        local prevCapacity = GetCachedBagCapacity(current.prevBags)
        if current.bagCapacity > 0 or prevCapacity <= 0 then
            current.character.bags = current.newBags
        else
            current.character.bags = current.prevBags or {}
        end

        if current.includeBank then
            local prevBankCapacity = GetCachedBagCapacity(current.prevBank)
            if current.bankCapacity > 0 or prevBankCapacity <= 0 then
                current.character.bank = current.newBank
            else
                current.character.bank = current.prevBank or {}
            end
        end

        current.character.lastUpdate = time()
        BagData._tooltipCountRevision = (BagData._tooltipCountRevision or 0) + 1
        BagData._scanJob = nil
        frame:SetScript("OnUpdate", nil)
        if type(current.onDone) == "function" then
            current.onDone()
        end
    end)
end

function BagData:UpdateCurrentMoney()
    local character = EnsureCharacterRecord()
    if not character then
        return
    end
    local value = tonumber(GetMoney and GetMoney())
    if value ~= nil then
        if value > 0 or character.money == nil then
            character.money = value
        end
    elseif character.money == nil then
        character.money = 0
    end
    character.lastUpdate = time()
end

function BagData:GetCharacterData(characterKey)
    local all = self:GetAllCharacters()
    if not characterKey then
        return all[GetCharacterKey()]
    end

    local direct = all[characterKey]
    if direct then
        return direct
    end

    local target = NormalizeKey(characterKey)
    for key, c in pairs(all) do
        if NormalizeKey(key) == target then
            return c
        end
        if type(c) == "table" and c.name and c.realm then
            if NormalizeKey((c.name or "") .. "-" .. (c.realm or "")) == target then
                return c
            end
        end
    end
    return nil
end

function BagData:GetLiveBagSlots(bagID)
    local slotCount
    if CContainer and CContainer.GetContainerNumSlots then
        slotCount = CContainer.GetContainerNumSlots(bagID)
    else
        slotCount = GetContainerNumSlots(bagID)
    end
    slotCount = slotCount or 0

    local slots = {}
    for slot = 1, slotCount do
        slots[slot] = BuildItemData(bagID, slot)
    end
    return slots, slotCount
end

function BagData:GetBagSlots(characterKey, bagID, useBank)
    local character = self:GetCharacterData(characterKey)
    if not character then
        return nil
    end
    local container = useBank and character.bank or character.bags
    if type(container) ~= "table" then
        return nil
    end
    local bagData = container[bagID] or container[tostring(bagID)]
    if type(bagData) ~= "table" then
        return nil
    end
    return bagData.slots or bagData
end

function BagData:IterCharacters()
    local all = self:GetAllCharacters()
    return pairs(all)
end

function BagData:IsBankAvailable()
    return BankFrame and BankFrame:IsShown() or false
end

function BagData:OnBagsUpdated()
    self:ScanBags(self:IsBankAvailable())
end

function BagData:OnPlayerMoney()
    self:UpdateCurrentMoney()
end

function BagData:OnPlayerLogout()
    self:ScanBags(self:IsBankAvailable())
end
