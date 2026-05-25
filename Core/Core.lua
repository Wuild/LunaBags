local ADDON_NAME, ns = ...

---@class LunaBagsAddon : AceAddon-3.0, AceConsole-3.0, AceEvent-3.0
local LunaBags = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.LunaBags = LunaBags

local frameWorkQueue = {}
local frameWorkFrame
local suppressedUIPanelParent

local function QueueFrameWork(callback)
    if type(callback) ~= "function" then
        return
    end
    if not CreateFrame then
        callback()
        return
    end
    frameWorkQueue[#frameWorkQueue + 1] = callback
    if not frameWorkFrame then
        frameWorkFrame = CreateFrame("Frame")
    end
    frameWorkFrame:SetScript("OnUpdate", function(frame)
        local nextWork = table.remove(frameWorkQueue, 1)
        if not nextWork then
            frame:SetScript("OnUpdate", nil)
            return
        end
        nextWork()
        if #frameWorkQueue == 0 then
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

local function GetSuppressedUIPanelParent()
    if suppressedUIPanelParent then
        return suppressedUIPanelParent
    end
    suppressedUIPanelParent = CreateFrame("Frame", nil, UIParent)
    suppressedUIPanelParent:SetAllPoints(UIParent)
    suppressedUIPanelParent:Hide()
    return suppressedUIPanelParent
end

local function IsGuildBankPanel(panel)
    return panel and panel.GetName and panel:GetName() == "GuildBankFrame"
end

local defaults = {
    profile = {
        enabled = true,
        debug = false,
        ui = {
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            itemFrameColor = { r = 0.13, g = 0.13, b = 0.13 },
            itemFrameOpacity = 0.92,
            itemBorderSize = 1,
            stackCountTextSize = 12,
            cooldownTextSize = 16,
        },
        oneBag = {
            columns = 11,
            windowWidth = 481,
            windowMaxHeight = 650,
            itemSize = 37,
            spacing = 4,
            splitByBagRows = false,
            splitBags = {},
            showBagRail = true,
            scale = 1,
            locked = false,
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            point = "BOTTOMRIGHT",
            x = -34,
            y = 126,
        },
        oneBank = {
            columns = 14,
            windowWidth = 590,
            windowMaxHeight = 650,
            itemSize = 36,
            spacing = 4,
            splitBags = {},
            visibleBags = {},
            scale = 1,
            locked = false,
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            point = "BOTTOMLEFT",
            x = 34,
            y = 126,
        },
        oneGuildBank = {
            columns = 14,
            itemSize = 36,
            spacing = 4,
            scale = 1,
            locked = false,
            windowColor = { r = 0.12, g = 0.12, b = 0.12 },
            windowOpacity = 0.72,
            headerColor = { r = 0.07, g = 0.07, b = 0.07 },
            headerOpacity = 0.78,
            point = "CENTER",
            x = 0,
            y = 0,
        },
        plugins = {
            qualityBorder = true,
            equipmentSetBorder = true,
            trashIcon = true,
        },
        modules = {
            oneBag = true,
            oneBank = true,
            oneGuildBank = true,
        },
        sorting = {
            priorityItemIDs = "6948",
            reverseSlotOrder = false,
            visualOnly = false,
            rules = {
                { key = "priority", direction = "asc", enabled = true },
                { key = "quality", direction = "desc", enabled = true },
                { key = "classID", direction = "asc", enabled = true },
                { key = "subClassID", direction = "asc", enabled = true },
                { key = "classOrder", direction = "asc", enabled = true },
                { key = "equipLoc", direction = "asc", enabled = true },
                { key = "itemLevel", direction = "desc", enabled = true },
                { key = "name", direction = "asc", enabled = true },
                { key = "itemID", direction = "asc", enabled = true },
                { key = "count", direction = "desc", enabled = true },
            },
        },
        categories = {
            bags = {
                enabled = false,
                columns = 1,
                layout = "masonry",
                nextID = 1,
                list = {},
            },
            bank = {
                enabled = false,
                columns = 1,
                layout = "masonry",
                nextID = 1,
                list = {},
            },
        },
    },
}

local OLD_DEFAULT_SORT_RULES = {
    { key = "priority", direction = "asc", enabled = true },
    { key = "quality", direction = "desc", enabled = true },
    { key = "itemLevel", direction = "desc", enabled = true },
    { key = "classOrder", direction = "asc", enabled = true },
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "equipLoc", direction = "asc", enabled = true },
    { key = "name", direction = "asc", enabled = true },
    { key = "itemID", direction = "asc", enabled = true },
    { key = "count", direction = "desc", enabled = true },
}

local SIMPLIFIED_DEFAULT_SORT_RULES = {
    { key = "priority", direction = "asc", enabled = true },
    { key = "quality", direction = "desc", enabled = true },
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "count", direction = "desc", enabled = true },
}

local PRIORITY_QUALITY_DEFAULT_SORT_RULES = {
    { key = "priority", direction = "asc", enabled = true },
    { key = "quality", direction = "desc", enabled = true },
    { key = "classID", direction = "asc", enabled = true },
    { key = "subClassID", direction = "asc", enabled = true },
    { key = "classOrder", direction = "asc", enabled = true },
    { key = "equipLoc", direction = "asc", enabled = true },
    { key = "itemLevel", direction = "desc", enabled = true },
    { key = "name", direction = "asc", enabled = true },
    { key = "itemID", direction = "asc", enabled = true },
    { key = "count", direction = "desc", enabled = true },
}

local function CopySortRules(rules)
    local copy = {}
    for index, rule in ipairs(rules or {}) do
        copy[index] = {
            key = rule.key,
            direction = rule.direction,
            enabled = rule.enabled ~= false,
        }
    end
    return copy
end

local function SortRulesMatch(actual, expected)
    if type(actual) ~= "table" or #actual ~= #expected then
        return false
    end
    for index, expectedRule in ipairs(expected) do
        local actualRule = actual[index]
        if type(actualRule) ~= "table"
            or actualRule.key ~= expectedRule.key
            or (actualRule.direction == "desc" and "desc" or "asc") ~= expectedRule.direction
            or (actualRule.enabled ~= false) ~= (expectedRule.enabled ~= false)
        then
            return false
        end
    end
    return true
end

function LunaBags:MigrateDefaultSortRules()
    local sorting = self.db and self.db.profile and self.db.profile.sorting
    if not sorting then
        return
    end
    local hasSimplifiedRules = SortRulesMatch(sorting.rules, SIMPLIFIED_DEFAULT_SORT_RULES)
    if sorting._defaultRulesVersion == 5 and not hasSimplifiedRules then
        return
    end
    if SortRulesMatch(sorting.rules, OLD_DEFAULT_SORT_RULES)
        or SortRulesMatch(sorting.rules, PRIORITY_QUALITY_DEFAULT_SORT_RULES)
        or hasSimplifiedRules
    then
        sorting.rules = CopySortRules(defaults.profile.sorting.rules)
    end
    sorting._defaultRulesVersion = 5
end

function LunaBags:IsWindowModuleEnabled(key)
    local modules = self.db and self.db.profile and self.db.profile.modules
    if type(modules) ~= "table" then
        return true
    end
    return modules[key] ~= false
end

function LunaBags:ApplyWindowModuleStates()
    local moduleMap = {
        oneBag = ns.OneBag,
        oneBank = ns.OneBank,
        oneGuildBank = ns.OneGuildBank,
    }
    for key, module in pairs(moduleMap) do
        if module and module.SetEnabledState then
            local enabled = self:IsWindowModuleEnabled(key)
            module:SetEnabledState(enabled)
            if self.IsEnabled and self:IsEnabled() then
                if enabled and module.Enable then
                    module:Enable()
                elseif (not enabled) and module.Disable then
                    module:Disable()
                end
            end
        end
    end
end

function LunaBags:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("LunaBagsDB", defaults, true)
    self.db.profile.modules = self.db.profile.modules or {}
    self:ApplyWindowModuleStates()
    self.db.profile.plugins = self.db.profile.plugins or {}
    -- Migration: older builds wrote qualityBorder=false while plugin logic was incomplete.
    -- Enable it once unless the user has already been migrated.
    if not self.db.profile.plugins._qualityBorderMigrated then
        self.db.profile.plugins.qualityBorder = true
        self.db.profile.plugins._qualityBorderMigrated = true
    end
    self.db.profile.ui = self.db.profile.ui or {}
    if self.db.profile.ui._migratedSharedAppearance ~= true then
        local source = self.db.profile.oneBag or self.db.profile.oneBank or {}
        self.db.profile.ui.windowColor = self.db.profile.ui.windowColor or source.windowColor
        self.db.profile.ui.windowOpacity = self.db.profile.ui.windowOpacity or source.windowOpacity
        self.db.profile.ui.headerColor = self.db.profile.ui.headerColor or source.headerColor
        self.db.profile.ui.headerOpacity = self.db.profile.ui.headerOpacity or source.headerOpacity
        self.db.profile.ui._migratedSharedAppearance = true
    end
    self:MigrateDefaultSortRules()
    self:RegisterChatCommand("lunabags", "HandleSlashCommand")
    self:RegisterChatCommand("lb", "HandleSlashCommand")
end

function LunaBags:OnEnable()
    if not self.db.profile.enabled then
        return
    end

    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("CHAT_MSG_MONEY", "PLAYER_MONEY")
    self:RegisterEvent("CHAT_MSG_LOOT", "PLAYER_MONEY")
    self:RegisterEvent("TRADE_MONEY_CHANGED", "PLAYER_MONEY")
    self:RegisterEvent("PLAYER_TRADE_MONEY", "PLAYER_MONEY")
    self:RegisterEvent("SEND_MAIL_MONEY_CHANGED", "PLAYER_MONEY")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYERBANKSLOTS_CHANGED", "BAG_UPDATE_DELAYED")
    self:RegisterEvent("BANKFRAME_OPENED")
    self:RegisterEvent("BANKFRAME_CLOSED")
    self:RegisterEvent("GUILDBANKFRAME_OPENED")
    self:RegisterEvent("GUILDBANKFRAME_CLOSED")
    self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE")
    self:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED", "GUILDBANK_UPDATE")
    self:RegisterEvent("GUILDBANK_UPDATE_TABS", "GUILDBANK_UPDATE")
    self:RegisterEvent("GUILDBANK_UPDATE_MONEY")
    self:RegisterEvent("GUILDBANKLOG_UPDATE", "GUILDBANK_UPDATE")
    self:RegisterEvent("GUILDBANK_TEXT_CHANGED", "GUILDBANK_UPDATE")
    if C_PlayerInteractionManager and Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker then
        self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
        self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    end
    self:RegisterEvent("PLAYER_LOGOUT")

    if not self._bankCallHijacked then
        self._bankCallHijacked = true
        if hooksecurefunc then
            if type(_G.BankFrame_Show) == "function" then
                hooksecurefunc("BankFrame_Show", function()
                    if not ns.LunaBags:IsWindowModuleEnabled("oneBank") then
                        ns.LunaBags:RestoreDefaultBankFrame()
                        return
                    end
                    ns.LunaBags:SuppressDefaultBankFrame()
                    if ns.OneBank then
                        ns.OneBank:Show()
                    end
                end)
            end
            if type(_G.CloseBankFrame) == "function" then
                hooksecurefunc("CloseBankFrame", function()
                    if ns.LunaBags:IsWindowModuleEnabled("oneBank") and ns.OneBank then
                        ns.OneBank:Hide()
                    end
                    if BankFrame then
                        BankFrame:SetAlpha(1)
                        BankFrame:EnableMouse(true)
                    end
                end)
            end
            if type(_G.GuildBankFrame_Show) == "function" then
                hooksecurefunc("GuildBankFrame_Show", function()
                    if not ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                        ns.LunaBags:RestoreDefaultGuildBankFrame()
                        return
                    end
                    ns.LunaBags:SuppressDefaultGuildBankFrame()
                    if ns.OneGuildBank then
                        ns.OneGuildBank:Show()
                    end
                    if ns.BagHooks then
                        ns.BagHooks:OpenBags("GuildBankOpen")
                    end
                end)
            end
            if type(_G.CloseGuildBankFrame) == "function" then
                hooksecurefunc("CloseGuildBankFrame", function()
                    if ns.LunaBags and not ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                        ns.LunaBags:RestoreDefaultGuildBankFrame()
                        return
                    end
                    if ns.OneGuildBank then
                        ns.OneGuildBank:Hide()
                    end
                    if ns.BagHooks then
                        ns.BagHooks:CloseBags("GuildBankClose")
                    end
                    if GuildBankFrame then
                        GuildBankFrame:SetAlpha(1)
                        GuildBankFrame:EnableMouse(true)
                    end
                end)
            end
            if type(_G.ShowUIPanel) == "function" then
                hooksecurefunc("ShowUIPanel", function(panel)
                    if IsGuildBankPanel(panel) then
                        if not ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                            self:RestoreDefaultGuildBankFrame()
                            return
                        end
                        self:SuppressDefaultGuildBankFrame()
                        if ns.OneGuildBank then
                            ns.OneGuildBank:Show()
                        end
                        if ns.BagHooks then
                            ns.BagHooks:OpenBags("GuildBankOpen")
                        end
                    end
                end)
            end
            if type(_G.HideUIPanel) == "function" then
                hooksecurefunc("HideUIPanel", function(panel)
                    if IsGuildBankPanel(panel) then
                        if not ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                            self:RestoreDefaultGuildBankFrame()
                            return
                        end
                        if ns.OneGuildBank then
                            ns.OneGuildBank:Hide()
                        end
                        if ns.BagHooks then
                            ns.BagHooks:CloseBags("GuildBankClose")
                        end
                    end
                end)
            end
            if type(_G.GuildBankFrame_LoadUI) == "function" then
                hooksecurefunc("GuildBankFrame_LoadUI", function()
                    if not self:IsWindowModuleEnabled("oneGuildBank") then
                        self:RestoreDefaultGuildBankFrame()
                        return
                    end
                    self:EnsureGuildBankFrameSuppressionHooks()
                end)
            end
        end
    end

    self:UpdateCurrentCharacterCacheDeferred(false, false)

    self:Print("Loaded. Type /lunabags for options.")
end

function LunaBags:SuppressDefaultBankFrame()
    if not BankFrame or not self:IsWindowModuleEnabled("oneBank") then
        return
    end
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
end

function LunaBags:RestoreDefaultBankFrame()
    if not BankFrame then
        return
    end
    BankFrame:SetAlpha(1)
    BankFrame:EnableMouse(true)
end

function LunaBags:DisableDefaultBankFrame()
    if self._bankFrameDisabled or not BankFrame or not self:IsWindowModuleEnabled("oneBank") then
        return
    end
    self._bankFrameDisabled = true

    BankFrame:SetScript("OnShow", nil)
    BankFrame:SetScript("OnHide", nil)
    if BankFrame.UnregisterAllEvents then
        BankFrame:UnregisterAllEvents()
    end
    if hooksecurefunc then
        hooksecurefunc(BankFrame, "Show", function()
            BankFrame:Hide()
        end)
    end
    BankFrame:Hide()
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
end

function LunaBags:EnsureBankFrameSuppressionHooks()
    if self._bankFrameSuppressionHooked or not BankFrame or not self:IsWindowModuleEnabled("oneBank") then
        return
    end
    self._bankFrameSuppressionHooked = true
    self:DisableDefaultBankFrame()

    BankFrame:HookScript("OnShow", function()
        BankFrame:Hide()
    end)

    if hooksecurefunc then
        hooksecurefunc(BankFrame, "Show", function()
            BankFrame:Hide()
        end)
    end
end

function LunaBags:UpdateCurrentCharacterCache(includeBank)
    if not ns.BagData then
        return
    end
    ns.BagData:ScanBags(includeBank == true and ns.BagData:IsBankAvailable() or false)
    ns.BagData:UpdateCurrentMoney()
end

function LunaBags:QueueOpenWindowRefresh()
    self._refreshQueueToken = (self._refreshQueueToken or 0) + 1
    local token = self._refreshQueueToken

    if ns.OneBag and ns.OneBag.frame and ns.OneBag.frame:IsShown() then
        QueueFrameWork(function()
            if token == self._refreshQueueToken and self:IsWindowModuleEnabled("oneBag") and ns.OneBag and ns.OneBag.frame and ns.OneBag.frame:IsShown() then
                if ns.OneBag.RefreshDeferred then ns.OneBag:RefreshDeferred() else ns.OneBag:Refresh() end
            end
        end)
    end
    if ns.OneBank and ns.OneBank.frame and ns.OneBank.frame:IsShown() then
        QueueFrameWork(function()
            if token == self._refreshQueueToken and self:IsWindowModuleEnabled("oneBank") and ns.OneBank and ns.OneBank.frame and ns.OneBank.frame:IsShown() then
                if ns.OneBank.RefreshDeferred then ns.OneBank:RefreshDeferred() else ns.OneBank:Refresh() end
            end
        end)
    end
    if ns.OneGuildBank and ns.OneGuildBank.frame and ns.OneGuildBank.frame:IsShown() then
        QueueFrameWork(function()
            if token == self._refreshQueueToken and self:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank and ns.OneGuildBank.frame and ns.OneGuildBank.frame:IsShown() then
                if ns.OneGuildBank.RefreshDeferred then ns.OneGuildBank:RefreshDeferred() else ns.OneGuildBank:Refresh() end
            end
        end)
    end
end

function LunaBags:UpdateCurrentCharacterCacheDeferred(includeBank, refreshOpenWindows)
    if not ns.BagData then
        return
    end

    self._cacheQueueToken = (self._cacheQueueToken or 0) + 1
    local token = self._cacheQueueToken
    local shouldIncludeBank = includeBank == true and ns.BagData:IsBankAvailable()

    local function finish()
        if token ~= self._cacheQueueToken or not ns.BagData then
            return
        end
        ns.BagData:UpdateCurrentMoney()
        if refreshOpenWindows then
            self:QueueOpenWindowRefresh()
        end
        if self.db and self.db.profile and self.db.profile.debug then
            self:Print("Bags cache updated.")
        end
    end

    if ns.BagData.ScanBagsDeferred then
        ns.BagData:ScanBagsDeferred(shouldIncludeBank, finish)
    else
        QueueFrameWork(function()
            if token ~= self._cacheQueueToken or not ns.BagData then
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
    if not ns.BagData or not C_Timer or not C_Timer.After then
        return
    end
    local delays = { 0.5, 1.5, 3.0, 6.0, 10.0 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if not ns.BagData then
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

function LunaBags:OnDisable()
    self:UnregisterAllEvents()
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
    if ns.OneBag and ns.OneBag.InvalidateSlotCache then
        ns.OneBag:InvalidateSlotCache()
    end
    if ns.OneBank and ns.OneBank.InvalidateSlotCache then
        ns.OneBank:InvalidateSlotCache()
    end

    if self._sortSessionActive then
        self._sortDeferredBagUpdate = true
        local now = GetTime and GetTime() or 0
        if not self._sortLastLiveRefresh or now == 0 or (now - self._sortLastLiveRefresh) >= 0.08 then
            self._sortLastLiveRefresh = now
            if ns.OneBag and ns.OneBag.frame and ns.OneBag.frame:IsShown() then
                ns.OneBag:Refresh()
            end
            if ns.OneBank and ns.OneBank.frame and ns.OneBank.frame:IsShown() then
                ns.OneBank:Refresh()
            end
            if ns.OneGuildBank and ns.OneGuildBank.frame and ns.OneGuildBank.frame:IsShown() then
                ns.OneGuildBank:Refresh()
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
                if not ns or not ns.LunaBags then
                    return
                end
                ns.LunaBags._bagUpdateFlushQueued = false
                ns.LunaBags:BAG_UPDATE_DELAYED()
            end)
        end
        return
    end
    self._lastBagUpdateAt = now

    self:QueueOpenWindowRefresh()
    local includeBank = ns.BagData and ns.BagData.IsBankAvailable and ns.BagData:IsBankAvailable() or false
    self:UpdateCurrentCharacterCacheDeferred(includeBank == true, false)
end

function LunaBags:PLAYER_MONEY()
    if ns.BagData then
        ns.BagData:UpdateCurrentMoney()
    end
    self:QueueOpenWindowRefresh()
end

function LunaBags:PLAYER_LOGOUT()
    self:UpdateCurrentCharacterCache(true)
end

function LunaBags:BANKFRAME_OPENED()
    if not self:IsWindowModuleEnabled("oneBank") then
        self:RestoreDefaultBankFrame()
        return
    end
    self:SuppressDefaultBankFrame()
    if ns.BagHooks then
        local now = GetTime and GetTime() or 0
        ns.BagHooks.bankOpenLatchUntil = now + 1.5
    end
    if self:IsWindowModuleEnabled("oneBank") and ns.OneBank then
        ns.OneBank:Show()
    end
    if ns.BagHooks then
        ns.BagHooks:OpenBags("BankOpen")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            if ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneBank") then
                ns.LunaBags:UpdateCurrentCharacterCacheDeferred(true, false)
            end
        end)
    else
        self:UpdateCurrentCharacterCacheDeferred(true, false)
    end
end

function LunaBags:BANKFRAME_CLOSED()
    self:RestoreDefaultBankFrame()
    if not self:IsWindowModuleEnabled("oneBank") then
        return
    end
    if ns.BagHooks then
        ns.BagHooks:CloseBags("BankClose")
    end
    if ns.OneBank then
        ns.OneBank:Hide()
    end
end

function LunaBags:SuppressDefaultGuildBankFrame()
    if not GuildBankFrame or not self:IsWindowModuleEnabled("oneGuildBank") then
        return
    end
    if not GuildBankFrame._LunaBagsOriginalParent and GuildBankFrame.GetParent then
        GuildBankFrame._LunaBagsOriginalParent = GuildBankFrame:GetParent()
    end
    if GuildBankFrame.SetParent then
        GuildBankFrame:SetParent(GetSuppressedUIPanelParent())
    end
    GuildBankFrame:SetAlpha(0)
    GuildBankFrame:EnableMouse(false)
end

function LunaBags:RestoreDefaultGuildBankFrame()
    if not GuildBankFrame then
        return
    end
    if GuildBankFrame.SetParent then
        GuildBankFrame:SetParent(GuildBankFrame._LunaBagsOriginalParent or UIParent)
    end
    GuildBankFrame:SetAlpha(1)
    GuildBankFrame:EnableMouse(true)
end

function LunaBags:EnsureGuildBankFrameSuppressionHooks()
    if self._guildBankFrameSuppressionHooked or not GuildBankFrame or not self:IsWindowModuleEnabled("oneGuildBank") then
        return
    end
    self._guildBankFrameSuppressionHooked = true
    self:SuppressDefaultGuildBankFrame()

    if GuildBankFrame.HookScript then
        GuildBankFrame:HookScript("OnShow", function()
            if not (ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank")) then
                return
            end
            if ns.LunaBags then
                ns.LunaBags:SuppressDefaultGuildBankFrame()
            end
            if ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank then
                ns.OneGuildBank:Show()
            end
            if ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") and ns.BagHooks then
                ns.BagHooks:OpenBags("GuildBankOpen")
            end
        end)
        GuildBankFrame:HookScript("OnHide", function()
            if not (ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank")) then
                return
            end
            if ns.OneGuildBank then
                ns.OneGuildBank:Hide()
            end
            if ns.BagHooks then
                ns.BagHooks:CloseBags("GuildBankClose")
            end
        end)
    end

    if hooksecurefunc and GuildBankFrame.Show then
        hooksecurefunc(GuildBankFrame, "Show", function()
            if not (ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank")) then
                return
            end
            if ns.LunaBags then
                ns.LunaBags:SuppressDefaultGuildBankFrame()
            end
            if ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank then
                ns.OneGuildBank:Show()
            end
            if ns.LunaBags and ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") and ns.BagHooks then
                ns.BagHooks:OpenBags("GuildBankOpen")
            end
        end)
    end
end

function LunaBags:GUILDBANKFRAME_OPENED()
    if not self:IsWindowModuleEnabled("oneGuildBank") then
        self:RestoreDefaultGuildBankFrame()
        return
    end
    self:EnsureGuildBankFrameSuppressionHooks()
    self:SuppressDefaultGuildBankFrame()
    if self:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank then
        ns.OneGuildBank:Show()
    end
    if self:IsWindowModuleEnabled("oneGuildBank") and ns.BagHooks then
        ns.BagHooks:OpenBags("GuildBankOpen")
    end
end

function LunaBags:GUILDBANKFRAME_CLOSED()
    self:RestoreDefaultGuildBankFrame()
    if not self:IsWindowModuleEnabled("oneGuildBank") then
        return
    end
    if ns.BagHooks then
        ns.BagHooks:CloseBags("GuildBankClose")
    end
    if ns.OneGuildBank then
        ns.OneGuildBank:Hide()
    end
end

function LunaBags:GUILDBANK_UPDATE()
    if self:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank then
        if ns.OneGuildBank.InvalidateSlotCache then
            ns.OneGuildBank:InvalidateSlotCache()
        end
        ns.OneGuildBank:RefreshIfShown()
    end
end

function LunaBags:GUILDBANK_UPDATE_MONEY()
    if self:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank and ns.OneGuildBank.RefreshMoneyDisplay then
        ns.OneGuildBank:RefreshMoneyDisplay()
    end
end

function LunaBags:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(frameType)
    if not Enum or not Enum.PlayerInteractionType or frameType ~= Enum.PlayerInteractionType.GuildBanker then
        return
    end
    if GuildBankFrame_LoadUI then
        GuildBankFrame_LoadUI()
    end
    if not self:IsWindowModuleEnabled("oneGuildBank") then
        self:RestoreDefaultGuildBankFrame()
        return
    end
    self:EnsureGuildBankFrameSuppressionHooks()
    self:SuppressDefaultGuildBankFrame()
    if self:IsWindowModuleEnabled("oneGuildBank") and ns.OneGuildBank then
        ns.OneGuildBank:Show()
    end
    if self:IsWindowModuleEnabled("oneGuildBank") and ns.BagHooks then
        ns.BagHooks:OpenBags("GuildBankOpen")
    end
end

function LunaBags:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(frameType)
    if not Enum or not Enum.PlayerInteractionType or frameType ~= Enum.PlayerInteractionType.GuildBanker then
        return
    end
    if not self:IsWindowModuleEnabled("oneGuildBank") then
        self:RestoreDefaultGuildBankFrame()
        return
    end
    if ns.OneGuildBank then
        ns.OneGuildBank:Hide()
    end
    if ns.BagHooks then
        ns.BagHooks:CloseBags("GuildBankClose")
    end
    self:RestoreDefaultGuildBankFrame()
end

function LunaBags:HandleSlashCommand(input)
    local raw = input and strtrim(input) or ""
    local cmd, rest = raw:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "open" then
        OpenAllBags()
        return
    end

    if cmd == "close" then
        CloseAllBags()
        return
    end

    if cmd == "toggle" then
        ToggleAllBags()
        return
    end

    if cmd == "dump" then
        local data = ns.BagData and ns.BagData:GetCharacterData()
        if data and self.db.profile.debug then
            self:Print(("Character cache updated at %s."):format(date("%H:%M:%S", data.lastUpdate or time())))
        else
            self:Print("Use /lb debug then /lb dump to inspect cache timestamps.")
        end
        return
    end

    if cmd == "dumpchars" then
        if not ns.BagData then
            self:Print("BagData module missing.")
            return
        end
        local currentKey = ns.OneBag and ns.OneBag.GetCurrentCharacterKey and ns.OneBag:GetCurrentCharacterKey() or "unknown"
        local viewKey = ns.OneBag and ns.OneBag.viewCharacterKey or nil
        local effectiveKey = viewKey or currentKey
        local viewed = ns.OneBag and ns.OneBag.GetViewedCharacterData and ns.OneBag:GetViewedCharacterData() or nil
        self:Print(("Current key: %s"):format(tostring(currentKey)))
        self:Print(("View key: %s"):format(tostring(viewKey)))
        self:Print(("Effective view key: %s"):format(tostring(effectiveKey)))
        self:Print(("Viewed record resolved: %s"):format((viewKey == nil or viewed) and "yes" or "no"))

        local all = ns.BagData:GetAllCharacters() or {}
        local total = 0
        for _ in pairs(all) do
            total = total + 1
        end
        self:Print(("Characters discovered: %d"):format(total))

        for key, c in ns.BagData:IterCharacters() do
            local bags = 0
            local bagSlots = 0
            local bagSizeTotal = 0
            local bagBreakdown = {}
            if c and type(c.bags) == "table" then
                for bagID, bagData in pairs(c.bags) do
                    if type(bagData) == "table" then
                        bags = bags + 1
                        local bagSize = tonumber(bagData.size) or 0
                        bagSizeTotal = bagSizeTotal + bagSize
                        local perBagFilled = 0
                        local slots = bagData.slots or bagData
                        if type(slots) == "table" then
                            for _, item in pairs(slots) do
                                if item then
                                    bagSlots = bagSlots + 1
                                    perBagFilled = perBagFilled + 1
                                end
                            end
                        end
                        bagBreakdown[#bagBreakdown + 1] = string.format("%s:%d/%d", tostring(bagID), perBagFilled, bagSize)
                    end
                end
            end
            local money = (c and c.money) or 0
            local nameRealm = (c and c.name and c.realm) and (c.name .. "-" .. c.realm) or "n/a"
            self:Print(("[%s] nameRealm=%s money=%s bags=%d slots=%d size=%d"):format(
                tostring(key),
                tostring(nameRealm),
                tostring(money),
                bags,
                bagSlots,
                bagSizeTotal
            ))
            if #bagBreakdown > 0 then
                self:Print(("  bag fill: %s"):format(table.concat(bagBreakdown, ", ")))
            end
        end
        return
    end

    if cmd == "scan" then
        if not ns.BagData then
            self:Print("BagData module missing.")
            return
        end
        ns.BagData:ScanBags(ns.BagData:IsBankAvailable())
        self:Print("Forced character scan completed.")
        return
    end

    if cmd == "dbcheck" then
        local sv = _G.LunaBagsDB
        local hasSV = sv ~= nil
        local hasDB = self.db ~= nil
        local hasGlobal = hasDB and self.db.global ~= nil
        local hasChars = hasGlobal and self.db.global.characters ~= nil
        self:Print(("SV exists: %s | AceDB exists: %s"):format(tostring(hasSV), tostring(hasDB)))
        self:Print(("AceDB global exists: %s | characters table exists: %s"):format(tostring(hasGlobal), tostring(hasChars)))

        local aceChars = hasChars and self.db.global.characters or nil
        local svChars = sv and sv.global and sv.global.characters or nil
        self:Print(("AceDB chars table == SV chars table: %s"):format(tostring(aceChars ~= nil and aceChars == svChars)))

        local aceCount = 0
        if type(aceChars) == "table" then
            for _ in pairs(aceChars) do
                aceCount = aceCount + 1
            end
        end
        local svCount = 0
        if type(svChars) == "table" then
            for _ in pairs(svChars) do
                svCount = svCount + 1
            end
        end
        self:Print(("AceDB character records: %d | SV character records: %d"):format(aceCount, svCount))
        return
    end

    if cmd == "view" then
        if not ns.OneBag then
            self:Print("OneBag module missing.")
            return
        end
        local key = rest and strtrim(rest) or ""
        if key == "" or key:lower() == "current" then
            ns.OneBag.viewCharacterKey = nil
            if ns.OneBag.frame then
                ns.OneBag:ApplySettings()
                ns.OneBag:Refresh()
            end
            self:Print("Character view set to current.")
            return
        end
        ns.OneBag.viewCharacterKey = key
        if ns.OneBag.frame then
            ns.OneBag:ApplySettings()
            ns.OneBag:Refresh()
        end
        self:Print(("Character view set to: %s"):format(key))
        return
    end

    if cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        if ns.OneBag and ns.OneBag.frame and ns.OneBag.frame:IsShown() then
            ns.OneBag:Refresh()
        end
        if ns.OneBank and ns.OneBank.frame and ns.OneBank.frame:IsShown() then
            ns.OneBank:Refresh()
        end
        self:Print(("Debug is now %s."):format(self.db.profile.debug and "ON" or "OFF"))
        return
    end

    if cmd == "window" then
        if ns.ExtraStyleWindow then
            ns.ExtraStyleWindow:Show()
        end
        return
    end

    if cmd == "enable" then
        self.db.profile.enabled = true
        self:Print("Addon enabled.")
        return
    end

    if cmd == "disable" then
        self.db.profile.enabled = false
        self:Print("Addon disabled.")
        return
    end

    if ns.OpenConfig then
        ns.OpenConfig()
        return
    end

    self:Print("Commands: /lunabags [open|close|toggle|view <Name-Realm|current>|scan|dbcheck|debug|enable|disable|dump|dumpchars|window]")
end
