local _, ns = ...
local LunaBags = ns.LunaBags

local function RefreshOneBag()
    if ns.OneBag then
        ns.OneBag:ApplySettings()
        if ns.OneBag.frame and ns.OneBag.frame:IsShown() then
            ns.OneBag:Refresh()
        end
    end
end
local function RefreshOneBank()
    if ns.OneBank then
        ns.OneBank:ApplySettings()
        if ns.OneBank.frame and ns.OneBank.frame:IsShown() then
            ns.OneBank:Refresh()
        end
    end
end

local function GetOneBagSetting(key, fallback)
    LunaBags.db.profile.oneBag = LunaBags.db.profile.oneBag or {}
    local value = LunaBags.db.profile.oneBag[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetOneBagSetting(key, value)
    LunaBags.db.profile.oneBag = LunaBags.db.profile.oneBag or {}
    LunaBags.db.profile.oneBag[key] = value
    RefreshOneBag()
end
local function GetOneBankSetting(key, fallback)
    LunaBags.db.profile.oneBank = LunaBags.db.profile.oneBank or {}
    local value = LunaBags.db.profile.oneBank[key]
    if value == nil then
        return fallback
    end
    return value
end
local function SetOneBankSetting(key, value)
    LunaBags.db.profile.oneBank = LunaBags.db.profile.oneBank or {}
    LunaBags.db.profile.oneBank[key] = value
    RefreshOneBank()
end

local function GetPluginSetting(key, fallback)
    LunaBags.db.profile.plugins = LunaBags.db.profile.plugins or {}
    local value = LunaBags.db.profile.plugins[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetPluginSetting(key, value)
    LunaBags.db.profile.plugins = LunaBags.db.profile.plugins or {}
    LunaBags.db.profile.plugins[key] = value
    RefreshOneBag()
    RefreshOneBank()
end

local function GetSortingSetting(key, fallback)
    LunaBags.db.profile.sorting = LunaBags.db.profile.sorting or {}
    local value = LunaBags.db.profile.sorting[key]
    if value == nil then
        return fallback
    end
    return value
end

local function SetSortingSetting(key, value)
    LunaBags.db.profile.sorting = LunaBags.db.profile.sorting or {}
    LunaBags.db.profile.sorting[key] = value
end

local options = {
    name = "LunaBags",
    type = "group",
    args = {
        enabled = {
            type = "toggle",
            name = "Enabled",
            order = 1,
            get = function()
                return LunaBags.db.profile.enabled
            end,
            set = function(_, value)
                LunaBags.db.profile.enabled = value
            end,
        },
        debug = {
            type = "toggle",
            name = "Debug",
            order = 2,
            get = function()
                return LunaBags.db.profile.debug
            end,
            set = function(_, value)
                LunaBags.db.profile.debug = value
            end,
        },
        oneBagHeader = {
            type = "header",
            name = "One Bag",
            order = 10,
        },
        columns = {
            type = "range",
            name = "Columns",
            order = 11,
            min = 6,
            max = 16,
            step = 1,
            get = function()
                return GetOneBagSetting("columns", 11)
            end,
            set = function(_, value)
                SetOneBagSetting("columns", value)
            end,
        },
        itemSize = {
            type = "range",
            name = "Item Size",
            order = 12,
            min = 24,
            max = 48,
            step = 1,
            get = function()
                return GetOneBagSetting("itemSize", 36)
            end,
            set = function(_, value)
                SetOneBagSetting("itemSize", value)
            end,
        },
        spacing = {
            type = "range",
            name = "Item Spacing",
            order = 13,
            min = 0,
            max = 12,
            step = 1,
            get = function()
                return GetOneBagSetting("spacing", 4)
            end,
            set = function(_, value)
                SetOneBagSetting("spacing", value)
            end,
        },
        splitByBagRows = {
            type = "toggle",
            name = "Split Rows By Bag",
            order = 13.5,
            get = function()
                return GetOneBagSetting("splitByBagRows", false)
            end,
            set = function(_, value)
                SetOneBagSetting("splitByBagRows", value)
            end,
        },
        scale = {
            type = "range",
            name = "Frame Scale",
            order = 14,
            min = 0.7,
            max = 1.5,
            step = 0.01,
            bigStep = 0.05,
            isPercent = true,
            get = function()
                return GetOneBagSetting("scale", 1)
            end,
            set = function(_, value)
                SetOneBagSetting("scale", value)
            end,
        },
        locked = {
            type = "toggle",
            name = "Lock Frame Position",
            order = 15,
            get = function()
                return GetOneBagSetting("locked", false)
            end,
            set = function(_, value)
                SetOneBagSetting("locked", value)
            end,
        },
        resetPosition = {
            type = "execute",
            name = "Reset Position",
            order = 16,
            func = function()
                if ns.OneBag then
                    ns.OneBag:ResetPosition()
                end
            end,
        },
        oneBankHeader = {
            type = "header",
            name = "One Bank",
            order = 20,
        },
        bankColumns = {
            type = "range", name = "Bank Columns", order = 21, min = 6, max = 16, step = 1,
            get = function() return GetOneBankSetting("columns", 11) end,
            set = function(_, value) SetOneBankSetting("columns", value) end,
        },
        bankItemSize = {
            type = "range", name = "Bank Item Size", order = 22, min = 24, max = 48, step = 1,
            get = function() return GetOneBankSetting("itemSize", 36) end,
            set = function(_, value) SetOneBankSetting("itemSize", value) end,
        },
        bankSpacing = {
            type = "range", name = "Bank Item Spacing", order = 23, min = 0, max = 12, step = 1,
            get = function() return GetOneBankSetting("spacing", 4) end,
            set = function(_, value) SetOneBankSetting("spacing", value) end,
        },
        bankScale = {
            type = "range", name = "Bank Frame Scale", order = 24, min = 0.7, max = 1.5, step = 0.01, bigStep = 0.05, isPercent = true,
            get = function() return GetOneBankSetting("scale", 1) end,
            set = function(_, value) SetOneBankSetting("scale", value) end,
        },
        bankLocked = {
            type = "toggle", name = "Lock Bank Frame Position", order = 25,
            get = function() return GetOneBankSetting("locked", false) end,
            set = function(_, value) SetOneBankSetting("locked", value) end,
        },
        bankResetPosition = {
            type = "execute", name = "Reset Bank Position", order = 26,
            func = function() if ns.OneBank then ns.OneBank:ResetPosition() end end,
        },
        sortingHeader = {
            type = "header",
            name = "Sorting",
            order = 27,
        },
        reverseSlotOrder = {
            type = "toggle",
            name = "Reverse Slot Order",
            desc = "Place the first sorted items at the bottom-right end of the bag order.",
            order = 28,
            get = function()
                return GetSortingSetting("reverseSlotOrder", false)
            end,
            set = function(_, value)
                SetSortingSetting("reverseSlotOrder", value == true or nil)
            end,
        },
        pluginsHeader = {
            type = "header",
            name = "Plugins",
            order = 30,
        },
        pluginQualityBorder = {
            type = "toggle",
            name = "Item Quality Border",
            order = 31,
            get = function()
                return GetPluginSetting("qualityBorder", true)
            end,
            set = function(_, value)
                SetPluginSetting("qualityBorder", value)
            end,
        },
        pluginTrashIcon = {
            type = "toggle",
            name = "Trash Item Icon",
            order = 32,
            get = function()
                return GetPluginSetting("trashIcon", true)
            end,
            set = function(_, value)
                SetPluginSetting("trashIcon", value)
            end,
        },
    },
}

function ns.OpenConfig()
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:Open("LunaBags")
    local openFrame = dialog.OpenFrames and dialog.OpenFrames["LunaBags"]
    if openFrame and openFrame.frame then
        openFrame.frame:SetFrameStrata("DIALOG")
        openFrame.frame:SetClampedToScreen(true)
        openFrame.frame:SetMovable(true)
        if openFrame.frame.obj and openFrame.frame.obj.SetStatusText then
            openFrame.frame.obj:SetStatusText("LunaBags Settings")
        end
    end
end

local function RegisterOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("LunaBags", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LunaBags", "LunaBags")
end

RegisterOptions()
