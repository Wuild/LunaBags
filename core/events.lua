local ADDON_NAME, addon = ...

local LunaBags = addon.LunaBags

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
    -- Intentionally avoid destructive BankFrame suppression hooks.
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
    self._sortLastLiveRefresh = nil
end

function LunaBags:EndSortSession()
    self._sortSessionActive = false
    self._sortLastLiveRefresh = nil
    if self._sortDeferredBagUpdate then
        self._sortDeferredBagUpdate = false
        self:BAG_UPDATE_DELAYED()
    end
end

function LunaBags:BAG_UPDATE_DELAYED()
    if addon.OneBag and addon.OneBag.InvalidateSlotCache then
        addon.OneBag:InvalidateSlotCache()
    end
    if addon.OneBank and addon.OneBank.InvalidateSlotCache then
        addon.OneBank:InvalidateSlotCache()
    end

    if self._sortSessionActive then
        self._sortDeferredBagUpdate = true
        local now = GetTime and GetTime() or 0
        if not self._sortLastLiveRefresh or now == 0 or (now - self._sortLastLiveRefresh) >= 0.08 then
            self._sortLastLiveRefresh = now
            if addon.OneBag and addon.OneBag.frame and addon.OneBag.frame:IsShown() then
                addon.OneBag:Refresh()
            end
            if addon.OneBank and addon.OneBank.frame and addon.OneBank.frame:IsShown() then
                addon.OneBank:Refresh()
            end
            if addon.OneGuildBank and addon.OneGuildBank.frame and addon.OneGuildBank.frame:IsShown() then
                addon.OneGuildBank:Refresh()
            end
        end
        return
    end

    -- Coalesce rapid bag updates (loot spam / auto-loot bursts).
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

    self:QueueOpenWindowRefresh()
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
