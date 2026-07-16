local ADDON_NAME, addon = ...

local LunaBags = addon.LunaBags

local function NormalizeVersionParts(version)
    local parts = {}
    for chunk in tostring(version or ""):gmatch("%d+") do
        parts[#parts + 1] = tonumber(chunk) or 0
    end
    return parts
end

local function CompareVersions(a, b)
    local pa = NormalizeVersionParts(a)
    local pb = NormalizeVersionParts(b)
    local length = math.max(#pa, #pb)
    for i = 1, length do
        local va = pa[i] or 0
        local vb = pb[i] or 0
        if va ~= vb then
            return va < vb and -1 or 1
        end
    end
    return 0
end

local function GetVersionPrefix()
    if LunaBags and LunaBags.GetVersionPrefix then
        return LunaBags:GetVersionPrefix()
    end
    return "LunaBagsVer"
end

local function GetVersionString()
    if LunaBags and LunaBags.GetVersionString then
        return LunaBags:GetVersionString()
    end
    return "unknown"
end

function LunaBags:UpdateCurrentCharacterCache(includeBank)
    if not addon.BagData then
        return
    end
    addon.BagData:ScanBags(includeBank == true and addon.BagData:IsBankAvailable() or false)
    addon.BagData:UpdateCurrentMoney()
end

function LunaBags:QueueOpenWindowRefresh()
    self._refreshQueueToken = (self._refreshQueueToken or 0) + 1
    local token = self._refreshQueueToken

    if addon.OneBag and addon.OneBag.frame and addon.OneBag.frame:IsShown() then
        self:QueueFrameWork(function()
            if token == self._refreshQueueToken and self:IsWindowModuleEnabled("oneBag") and addon.OneBag and addon.OneBag.frame and addon.OneBag.frame:IsShown() then
                if addon.OneBag.RefreshDeferred then addon.OneBag:RefreshDeferred() else addon.OneBag:Refresh() end
            end
        end)
    end
    if addon.OneBank and addon.OneBank.frame and addon.OneBank.frame:IsShown() then
        self:QueueFrameWork(function()
            if token == self._refreshQueueToken and self:IsWindowModuleEnabled("oneBank") and addon.OneBank and addon.OneBank.frame and addon.OneBank.frame:IsShown() then
                if addon.OneBank.RefreshDeferred then addon.OneBank:RefreshDeferred() else addon.OneBank:Refresh() end
            end
        end)
    end
    if addon.OneGuildBank and addon.OneGuildBank.frame and addon.OneGuildBank.frame:IsShown() then
        self:QueueFrameWork(function()
            if token == self._refreshQueueToken and self:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank and addon.OneGuildBank.frame and addon.OneGuildBank.frame:IsShown() then
                if addon.OneGuildBank.RefreshDeferred then addon.OneGuildBank:RefreshDeferred() else addon.OneGuildBank:Refresh() end
            end
        end)
    end
end

local function CopyDirtySlots(dirtySlots)
    if type(dirtySlots) ~= "table" then
        return nil
    end
    local copy = {}
    for bagID, slots in pairs(dirtySlots) do
        if slots == true then
            copy[bagID] = true
        elseif type(slots) == "table" then
            copy[bagID] = {}
            for slot in pairs(slots) do
                copy[bagID][slot] = true
            end
        end
    end
    return copy
end

function LunaBags:MarkDirtyBagSlot(bagID, slot)
    if bagID == nil then
        return
    end
    self._dirtyBagSlots = self._dirtyBagSlots or {}
    if slot == nil then
        self._dirtyBagSlots[bagID] = true
        return
    end
    if self._dirtyBagSlots[bagID] == true then
        return
    end
    self._dirtyBagSlots[bagID] = self._dirtyBagSlots[bagID] or {}
    self._dirtyBagSlots[bagID][slot] = true
end

function LunaBags:BAG_UPDATE(_, bagID)
    self:MarkDirtyBagSlot(bagID)
end

function LunaBags:ITEM_LOCK_CHANGED(_, bagID, slot)
    self:MarkDirtyBagSlot(bagID, slot)
    if bagID ~= nil and slot ~= nil then
        self:RefreshDirtyOpenWindows({ [bagID] = { [slot] = true } })
    end
end

function LunaBags:RefreshOpenWindowCooldowns()
    if addon.OneBag and addon.OneBag.RefreshCooldowns then
        addon.OneBag:RefreshCooldowns()
    end
    if addon.OneBank and addon.OneBank.RefreshCooldowns then
        addon.OneBank:RefreshCooldowns()
    end
end

function LunaBags:BAG_UPDATE_COOLDOWN()
    if self._cooldownRefreshQueued then
        return
    end
    self._cooldownRefreshQueued = true

    local function refresh()
        if not addon or not addon.LunaBags then
            return
        end
        addon.LunaBags._cooldownRefreshQueued = false
        addon.LunaBags:RefreshOpenWindowCooldowns()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, refresh)
    else
        refresh()
    end
end

function LunaBags:RefreshDirtyOpenWindows(dirtySlots)
    local anyVisible = false

    if addon.OneBag and addon.OneBag.frame and addon.OneBag.frame:IsShown() then
        anyVisible = true
        if addon.OneBag.RefreshItemsOnly and addon.OneBag:RefreshItemsOnly(dirtySlots) then
        else
            if addon.OneBag.InvalidateSlotCache then
                addon.OneBag:InvalidateSlotCache()
            end
            if addon.OneBag.RefreshDeferred then addon.OneBag:RefreshDeferred() else addon.OneBag:Refresh() end
        end
    elseif addon.OneBag then
        addon.OneBag._slotCacheDirty = true
    end

    if addon.OneBank and addon.OneBank.frame and addon.OneBank.frame:IsShown() then
        anyVisible = true
        if addon.OneBank.RefreshItemsOnly and addon.OneBank:RefreshItemsOnly(dirtySlots) then
        else
            if addon.OneBank.InvalidateSlotCache then
                addon.OneBank:InvalidateSlotCache()
            end
            if addon.OneBank.RefreshDeferred then addon.OneBank:RefreshDeferred() else addon.OneBank:Refresh() end
        end
    elseif addon.OneBank then
        addon.OneBank._slotCacheDirty = true
    end

    if addon.OneGuildBank and addon.OneGuildBank.frame and addon.OneGuildBank.frame:IsShown() then
        anyVisible = true
        if addon.OneGuildBank.RefreshDeferred then addon.OneGuildBank:RefreshDeferred() else addon.OneGuildBank:Refresh() end
    end

    return anyVisible
end

function LunaBags:UpdateCurrentCharacterCacheDeferred(includeBank, refreshOpenWindows)
    if not addon.BagData then
        return
    end

    self._cacheQueueToken = (self._cacheQueueToken or 0) + 1
    local token = self._cacheQueueToken
    local shouldIncludeBank = includeBank == true and addon.BagData:IsBankAvailable()

    local function finish()
        if token ~= self._cacheQueueToken or not addon.BagData then
            return
        end
        addon.BagData:UpdateCurrentMoney()
        if refreshOpenWindows then
            self:QueueOpenWindowRefresh()
        end
        if self.db and self.db.profile and self.db.profile.debug then
            self:Print("Bags cache updated.")
        end
    end

    if addon.BagData.ScanBagsDeferred then
        addon.BagData:ScanBagsDeferred(shouldIncludeBank, finish)
    else
        self:QueueFrameWork(function()
            if token ~= self._cacheQueueToken or not addon.BagData then
                return
            end
            self:UpdateCurrentCharacterCache(shouldIncludeBank)
            if refreshOpenWindows then
                self:QueueOpenWindowRefresh()
            end
        end)
    end
end

function LunaBags:ADDON_LOADED(addonName)
    if addonName and addonName ~= ADDON_NAME then
        return
    end
    self:UpdateCurrentCharacterCacheDeferred(false, false)
end

local function GetPlayerBagCapacity()
    local total = 0
    for bagID = 0, 4 do
        local slots = 0
        if C_Container and C_Container.GetContainerNumSlots then
            slots = C_Container.GetContainerNumSlots(bagID) or 0
        else
            slots = GetContainerNumSlots(bagID) or 0
        end
        total = total + slots
    end
    return total
end

function LunaBags:ScheduleStartupScans()
    if not addon.BagData or not C_Timer or not C_Timer.After then
        return
    end
    local delays = { 0.5, 1.5, 3.0, 6.0, 10.0 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if not addon.BagData then
                return
            end
            self:UpdateCurrentCharacterCacheDeferred(false, false)
            if self.db and self.db.profile and self.db.profile.debug then
                self:Print(("Startup scan @ %.1fs (bag capacity=%d, money=%s)"):format(
                    delay,
                    GetPlayerBagCapacity(),
                    tostring(GetMoney and GetMoney() or 0)
                ))
            end
        end)
    end
end

function LunaBags:PLAYER_ENTERING_WORLD()
    self:UpdateCurrentCharacterCacheDeferred(false, false)
    self:ScheduleStartupScans()
end

function LunaBags:BeginSortSession()
    self._sortSessionActive = true
    self._sortDeferredBagUpdate = false
end

function LunaBags:EndSortSession()
    self._sortSessionActive = false
    if self._sortDeferredBagUpdate then
        self._sortDeferredBagUpdate = false
        self:BAG_UPDATE_DELAYED()
    end
end

function LunaBags:BAG_UPDATE_DELAYED()
    if self._sortSessionActive then
        self._sortDeferredBagUpdate = true
        return
    end

    local now = GetTime and GetTime() or 0
    if not self._lastBagUpdateAt then
        self._lastBagUpdateAt = 0
    end
    if now > 0 and (now - self._lastBagUpdateAt) < 0.10 then
        if (not self._bagUpdateFlushQueued) and C_Timer and C_Timer.After then
            self._bagUpdateFlushQueued = true
            C_Timer.After(0.10, function()
                if not addon or not addon.LunaBags then
                    return
                end
                addon.LunaBags._bagUpdateFlushQueued = false
                addon.LunaBags:BAG_UPDATE_DELAYED()
            end)
        end
        return
    end
    self._lastBagUpdateAt = now

    local dirtySlots = CopyDirtySlots(self._dirtyBagSlots)
    self._dirtyBagSlots = nil
    if not self:RefreshDirtyOpenWindows(dirtySlots) then
        if addon.OneBag and addon.OneBag.InvalidateSlotCache then
            addon.OneBag:InvalidateSlotCache()
        end
        if addon.OneBank and addon.OneBank.InvalidateSlotCache then
            addon.OneBank:InvalidateSlotCache()
        end
        self:QueueOpenWindowRefresh()
    end
    local includeBank = addon.BagData and addon.BagData.IsBankAvailable and addon.BagData:IsBankAvailable() or false
    self:UpdateCurrentCharacterCacheDeferred(includeBank == true, false)
end

function LunaBags:PLAYER_MONEY()
    if addon.BagData then
        addon.BagData:UpdateCurrentMoney()
    end
    self:QueueOpenWindowRefresh()
end

function LunaBags:PLAYER_LOGOUT()
    self:UpdateCurrentCharacterCache(true)
end

function LunaBags:CHAT_MSG_ADDON(prefix, message, channel, sender)
    if prefix ~= GetVersionPrefix() then
        return
    end
    if type(message) ~= "string" or message == "" then
        return
    end

    sender = sender and Ambiguate and Ambiguate(sender, "short") or sender
    local kind, checkID, payload = strsplit("|", message, 3)
    if kind == "REQ" then
        if sender and sender ~= (UnitName and UnitName("player")) then
            self:SendVersionAddonMessage(("RES|%s|%s"):format(checkID or "", GetVersionString()), "WHISPER", sender)
        end
        return
    end

    if kind ~= "RES" then
        return
    end

    local state = self._versionCheck
    if not state or state.id ~= checkID then
        return
    end

    if CompareVersions(payload, state.highestVersion or state.localVersion) > 0 then
        state.highestVersion = payload
        state.highestSender = sender
    end
    state.responses = (state.responses or 0) + 1
end
