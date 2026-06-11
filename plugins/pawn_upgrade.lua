local name, addon = ...

local Plugin = {
    name = "Pawn Upgrade Arrows",
    id = "pawnUpgrade",
    defaultEnabled = true,
}

local retryQueued = {}
local retryScheduled = false
local refreshCounter = 1
local pawnRegistered = false

local function IsPawnReady()
    return type(PawnShouldItemLinkHaveUpgradeArrow) == "function"
end

local function IsBagContext(context)
    return context == "oneBag" or context == "oneBank"
end

local function EnsureUpgradeIcon(button)
    if not button then
        return nil
    end

    if button.UpgradeIcon then
        return button.UpgradeIcon
    end

    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetTexture("Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow")
    icon:Hide()
    button.UpgradeIcon = icon
    return icon
end

local function GetArrowLayout()
    local profile = addon and addon.LunaBags and addon.LunaBags.db and addon.LunaBags.db.profile
    local plugins = profile and profile.plugins or nil
    local options = plugins and plugins.pawnUpgradeOptions or nil
    local anchor = (options and options.anchor) or "top_right"
    if anchor ~= "top_left" and anchor ~= "top_right" and anchor ~= "bottom_left" and anchor ~= "bottom_right" then
        anchor = "top_right"
    end
    local x = tonumber(options and options.offsetX) or 2
    local y = tonumber(options and options.offsetY) or 2
    return anchor, x, y
end

local function ApplyArrowAnchor(icon, button)
    if not icon or not button then
        return
    end
    local anchor, x, y = GetArrowLayout()
    icon:ClearAllPoints()
    if anchor == "top_left" then
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
    elseif anchor == "bottom_left" then
        icon:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", x, y)
    elseif anchor == "bottom_right" then
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -x, y)
    else
        icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -x, -y)
    end
end

local function SetUpgradeIconShown(button, shown)
    local icon = EnsureUpgradeIcon(button)
    if not icon then
        return
    end
    ApplyArrowAnchor(icon, button)
    icon:SetShown(shown == true)
end

local function RefreshOpenWindows()
    if addon.OneBag and addon.OneBag.frame and addon.OneBag.frame:IsShown() then
        addon.OneBag:Refresh()
    end
    if addon.OneBank and addon.OneBank.frame and addon.OneBank.frame:IsShown() then
        addon.OneBank:Refresh()
    end
end

local function QueueRetry(button)
    if not button then
        return
    end
    retryQueued[button] = true
    if retryScheduled then
        return
    end
    retryScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            retryScheduled = false
            local queued = retryQueued
            retryQueued = {}
            for b in pairs(queued) do
                if b and b:IsShown() and b.itemData and b.itemData.itemLink and Plugin.lastEnabled ~= false then
                    Plugin:Apply(b, { item = b.itemData }, b._lunaBagsContext or "oneBag", true)
                end
            end
        end)
    else
        retryScheduled = false
        retryQueued = {}
    end
end

local function RegisterWithPawn()
    if pawnRegistered or type(PawnRegisterThirdPartyBag) ~= "function" then
        return
    end
    PawnRegisterThirdPartyBag("LunaBags", {
        RefreshAll = function()
            refreshCounter = refreshCounter + 1
            RefreshOpenWindows()
        end,
    })
    pawnRegistered = true
end

function Plugin:Apply(button, entry, context, enabled)
    self.lastEnabled = enabled
    if not button then
        return
    end

    button._lunaBagsContext = context

    if not enabled or not IsBagContext(context) or not IsPawnReady() then
        SetUpgradeIconShown(button, false)
        button._lunaPawnLastCheckedRefresh = nil
        button._lunaPawnLastCheckedLink = nil
        return
    end

    RegisterWithPawn()

    local item = entry and entry.item
    local itemLink = item and item.itemLink
    if not itemLink then
        SetUpgradeIconShown(button, false)
        button._lunaPawnLastCheckedRefresh = nil
        button._lunaPawnLastCheckedLink = nil
        return
    end

    if button._lunaPawnLastCheckedRefresh == refreshCounter and button._lunaPawnLastCheckedLink == itemLink then
        return
    end

    local isUpgrade = PawnShouldItemLinkHaveUpgradeArrow(itemLink, true)
    if isUpgrade == nil then
        SetUpgradeIconShown(button, false)
        button._lunaPawnLastCheckedRefresh = nil
        button._lunaPawnLastCheckedLink = nil
        QueueRetry(button)
        return
    end

    button._lunaPawnLastCheckedRefresh = refreshCounter
    button._lunaPawnLastCheckedLink = itemLink
    SetUpgradeIconShown(button, isUpgrade)
end

function Plugin:GetRenderSignature()
    return refreshCounter
end

function Plugin:GetOptions(api)
    return {
        type = "group",
        name = "Pawn Upgrade Arrows",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Pawn Upgrade Arrows",
                order = 1,
                get = function()
                    return api.getEnabled(true)
                end,
                set = function(_, value)
                    api.setEnabled(value)
                    refreshCounter = refreshCounter + 1
                    RefreshOpenWindows()
                end,
            },
            hint = {
                type = "description",
                order = 2,
                name = "Shows a green upgrade arrow on bag and bank items using Pawn's upgrade evaluation.",
            },
            anchor = {
                type = "select",
                name = "Arrow Align",
                order = 3,
                values = {
                    top_right = "Top Right",
                    top_left = "Top Left",
                    bottom_right = "Bottom Right",
                    bottom_left = "Bottom Left",
                },
                get = function()
                    return api.get("anchor", "top_right")
                end,
                set = function(_, value)
                    api.set("anchor", value)
                    refreshCounter = refreshCounter + 1
                    RefreshOpenWindows()
                end,
            },
            offsetX = {
                type = "range",
                name = "X Offset",
                order = 4,
                min = 0,
                max = 20,
                step = 1,
                get = function()
                    return api.get("offsetX", 2)
                end,
                set = function(_, value)
                    api.set("offsetX", value)
                    refreshCounter = refreshCounter + 1
                    RefreshOpenWindows()
                end,
            },
            offsetY = {
                type = "range",
                name = "Y Offset",
                order = 5,
                min = 0,
                max = 20,
                step = 1,
                get = function()
                    return api.get("offsetY", 2)
                end,
                set = function(_, value)
                    api.set("offsetY", value)
                    refreshCounter = refreshCounter + 1
                    RefreshOpenWindows()
                end,
            },
        },
    }
end

addon.LunaBags:RegisterPlugin(Plugin)
