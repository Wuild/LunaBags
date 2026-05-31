local _, ns = ...

local OneGuildBank = ns.LunaBags and ns.LunaBags:NewModule("OneGuildBank", "AceEvent-3.0") or {}
OneGuildBank.frame = nil
OneGuildBank.buttons = {}
OneGuildBank.searchText = ""
OneGuildBank.searchVisible = false
OneGuildBank.mode = "bank"
OneGuildBank.nextAvailableTab = nil
OneGuildBank.noViewableTabs = nil
OneGuildBank.currentTab = 1

ns.OneGuildBank = OneGuildBank

local MAX_GUILDBANK_TABS = _G.MAX_GUILDBANK_TABS or 8
local MAX_GUILDBANK_SLOTS_PER_TAB = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
local BLIZZARD_GUILDBANK_COLUMNS = 7
local BLIZZARD_GUILDBANK_ROWS = 14
local NUM_GUILDBANK_GROUPS = 7
local NUM_SLOTS_PER_GUILDBANK_GROUP = 14
local NUM_GUILDBANK_ROWS = 7
local NUM_GUILDBANK_COLUMNS = 14
local GRID_SPACING_X = 4
local GRID_SPACING_Y = 6
local GRID_INSET_X = 12
local GRID_INSET_Y = 8
local TAB_RAIL_WIDTH = 46
local MAX_BUY_GUILDBANK_TABS = _G.MAX_BUY_GUILDBANK_TABS or MAX_GUILDBANK_TABS

local function IsGuildBankAvailable()
    return type(GetNumGuildBankTabs) == "function"
        and type(GetCurrentGuildBankTab) == "function"
        and type(GetGuildBankTabInfo) == "function"
end

local function GetGuildBankWithdrawLimit()
    if not (CanWithdrawGuildBankMoney and CanWithdrawGuildBankMoney()) then
        return 0
    end
    local daily = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    local funds = GetGuildBankMoney and GetGuildBankMoney() or 0
    if daily < 0 then
        return funds
    end
    return math.min(daily, funds)
end

local function GetProfileConfig()
    local addon = ns.LunaBags
    local profile = addon and addon.db and addon.db.profile
    profile.oneGuildBank = profile and profile.oneGuildBank or {}
    return profile and profile.oneGuildBank or {}
end

local function SetBlizzardGuildBankSuppressed(suppressed)
    local frame = _G.GuildBankFrame
    if not frame then
        return
    end

    if suppressed then
        frame:SetAlpha(0)
        frame:EnableMouse(false)
    else
        frame:SetAlpha(1)
        frame:EnableMouse(true)
    end

    -- Some clients still allow child item buttons to capture mouse even when parent is hidden/alpha'd.
    for column = 1, BLIZZARD_GUILDBANK_COLUMNS do
        local columnFrame = frame.Columns and frame.Columns[column]
        if columnFrame and columnFrame.Buttons then
            for row = 1, BLIZZARD_GUILDBANK_ROWS do
                local button = columnFrame.Buttons[row]
                if button and button.EnableMouse then
                    button:EnableMouse(not suppressed)
                end
            end
        end
    end
end

local function NormalizeRailPosition(position, fallback)
    if position == "top" or position == "bottom" or position == "left" or position == "right" then
        return position
    end
    return fallback or "top"
end

local function CreateIconButton(parent, size, texturePath, tooltipText, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(size, size)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:SetText("")
    button:SetNormalTexture(texturePath)
    button:SetPushedTexture(texturePath)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

function OneGuildBank:OnEnable()
    self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED", "EventHandler")
    self:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED", "EventHandler")
    self:RegisterEvent("GUILDBANK_UPDATE_TABS", "EventHandler")
    self:RegisterEvent("GUILDBANK_UPDATE_MONEY", "EventHandler")
    self:RegisterEvent("GUILDBANK_UPDATE_WITHDRAWMONEY", "EventHandler")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "EventHandler")
    self:RegisterEvent("GUILDBANKLOG_UPDATE", "EventHandler")
    self:RegisterEvent("GUILDTABARD_UPDATE", "EventHandler")
    self:RegisterEvent("GUILDBANK_UPDATE_TEXT", "EventHandler")
    self:RegisterEvent("GUILDBANK_TEXT_CHANGED", "EventHandler")
    self:RegisterEvent("PLAYER_MONEY", "EventHandler")
    self:RegisterEvent("INVENTORY_SEARCH_UPDATE", "EventHandler")
end

function OneGuildBank:OnDisable()
    self:Hide()
    SetBlizzardGuildBankSuppressed(false)
end

function OneGuildBank:Create()
    if self.frame then
        return
    end

    local frame = _G.LunaBagsOneGuildBankFrame
    if not frame then
        return
    end

    frame:SetScript("OnHide", function()
        if _G.CloseGuildBankFrame and _G.GuildBankFrame and _G.GuildBankFrame:IsShown() then
            CloseGuildBankFrame()
        end
    end)

    frame:SetScript("OnShow", function()
        self:Refresh()
    end)

    self.frame = frame
    self:EnsureChrome()
    self:EnsureControls()
    self:EnsureItemGrid()
    self:ApplySettings()
    self:Refresh()
end

function OneGuildBank:EnsureChrome()
    if not self.frame then
        return
    end
    if ns.WindowChrome and ns.WindowChrome.EnsureFrame then
        ns.WindowChrome.EnsureFrame(self.frame, self, { strata = "DIALOG", level = 40 })
        ns.WindowChrome.EnsureStatusBar(self.frame, "MoneyBar")
    end

    if self.frame.Header then
        self.frame.Header:Hide()
        self.frame.Header:SetAlpha(0)
        self.frame.Header:EnableMouse(false)
    end
    if self.frame.SearchBox then
        self.frame.SearchBox:Hide()
        self.frame.SearchBox:SetAlpha(0)
        self.frame.SearchBox:EnableMouse(false)
    end
    if self.frame.SearchToggle then
        self.frame.SearchToggle:Hide()
        self.frame.SearchToggle:SetAlpha(0)
        self.frame.SearchToggle:EnableMouse(false)
    end

    if self.frame.Content then
        self.frame.Content:ClearAllPoints()
        self.frame.Content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 12, -34)
        self.frame.Content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -12, 40)
    end
end

function OneGuildBank:UpdateSearchLayout()
    if not self.frame or not self.frame.Content then
        return
    end
    local topInset = self.searchVisible and 62 or 34
    self.frame.Content:ClearAllPoints()
    self.frame.Content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 12, -topInset)
    self.frame.Content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -12, 40)
    if self.frame.SearchPanel then
        self.frame.SearchPanel:SetShown(self.searchVisible == true)
    end
    self:UpdateWindowSize()
end

function OneGuildBank:EnsureControls()
    if not self.frame then
        return
    end

    local frame = self.frame

    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.CloseButton:SetScript("OnClick", function()
            self:Hide()
        end)
    end
    frame.CloseButton:ClearAllPoints()
    frame.CloseButton:SetPoint("TOPRIGHT", frame.TitleBarBg, "TOPRIGHT", -2, 2)
    frame.CloseButton:SetFrameLevel((frame:GetFrameLevel() or 40) + 15)

    if not frame.CustomTitle then
        frame.CustomTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.CustomTitle:SetPoint("CENTER", frame.TitleBarBg, "CENTER", 0, 0)
        frame.CustomTitle:SetJustifyH("CENTER")
    end
    frame.CustomTitle:SetDrawLayer("OVERLAY", 7)

    if not frame.CharacterButton then
        frame.CharacterButton = CreateIconButton(frame, 18, "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES", "Guild Tabs", function()
            if not LunaBagsGuildTabMenu then
                CreateFrame("Frame", "LunaBagsGuildTabMenu", UIParent, "UIDropDownMenuTemplate")
            end
            local items = {}
            local maxTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
            for i = 1, maxTabs do
                local tabName = GetGuildBankTabInfo and select(1, GetGuildBankTabInfo(i)) or nil
                if not tabName or tabName == "" then
                    tabName = ("Tab %d"):format(i)
                end
                items[#items + 1] = {
                    text = tabName,
                    checked = function()
                        return (GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1) == i
                    end,
                    func = function()
                        self:SelectTab(i)
                    end,
                    isNotRadio = true,
                    keepShownOnClick = false,
                }
            end

            if EasyMenu then
                EasyMenu(items, LunaBagsGuildTabMenu, "cursor", 0, 0, "MENU")
            else
                UIDropDownMenu_Initialize(LunaBagsGuildTabMenu, function(_, level)
                    if level ~= 1 then return end
                    for _, entry in ipairs(items) do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = entry.text
                        info.func = entry.func
                        info.checked = type(entry.checked) == "function" and entry.checked() or entry.checked
                        info.isNotRadio = entry.isNotRadio
                        info.keepShownOnClick = entry.keepShownOnClick
                        UIDropDownMenu_AddButton(info, level)
                    end
                end, "MENU")
                ToggleDropDownMenu(1, nil, LunaBagsGuildTabMenu, "cursor", 0, 0)
            end
        end)
    end
    frame.CharacterButton:ClearAllPoints()
    frame.CharacterButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 6, 0)
    frame.CharacterButton:SetFrameLevel((frame:GetFrameLevel() or 40) + 15)

    if not frame.SearchToggleButton then
        frame.SearchToggleButton = CreateIconButton(frame, 18, "Interface\\Icons\\INV_Misc_Spyglass_03", "Toggle Search", function()
            self.searchVisible = not self.searchVisible
            if frame.SearchEditBox then
                if not self.searchVisible then
                    frame.SearchEditBox:ClearFocus()
                    frame.SearchEditBox:SetText("")
                    self.searchText = ""
                end
            end
            self:UpdateSearchLayout()
            if self.searchVisible and frame.SearchEditBox then
                frame.SearchEditBox:SetFocus()
            end
            self:RefreshIfShown()
        end)
    end
    frame.SearchToggleButton:ClearAllPoints()
    frame.SearchToggleButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 28, 0)
    frame.SearchToggleButton:SetFrameLevel((frame:GetFrameLevel() or 40) + 15)

    if not frame.SettingsButton then
        frame.SettingsButton = CreateIconButton(frame, 18, "Interface\\Icons\\INV_Misc_Wrench_01", "Open Settings", function()
            if ns.OpenConfig then
                ns.OpenConfig()
            elseif InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory("LunaBags")
                InterfaceOptionsFrame_OpenToCategory("LunaBags")
            end
        end)
    end
    frame.SettingsButton:ClearAllPoints()
    frame.SettingsButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 50, 0)
    frame.SettingsButton:SetFrameLevel((frame:GetFrameLevel() or 40) + 15)

    if not frame.SearchPanel then
        frame.SearchPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.SearchPanel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame.SearchPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.82)
        frame.SearchPanel:SetBackdropBorderColor(0.26, 0.26, 0.26, 0.95)
    end
    frame.SearchPanel:ClearAllPoints()
    frame.SearchPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
    frame.SearchPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -29)
    frame.SearchPanel:SetHeight(28)
    frame.SearchPanel:SetFrameLevel((frame:GetFrameLevel() or 40) + 11)

    if not frame.SearchEditBackdrop then
        frame.SearchEditBackdrop = CreateFrame("Frame", nil, frame.SearchPanel)
        frame.SearchEditBackdrop:SetPoint("TOPLEFT", frame.SearchPanel, "TOPLEFT", 6, -3)
        frame.SearchEditBackdrop:SetPoint("BOTTOMRIGHT", frame.SearchPanel, "BOTTOMRIGHT", -6, 3)
    end

    if not frame.SearchEditBox then
        frame.SearchEditBox = CreateFrame("EditBox", "LunaBagsOneGuildBankSearchEditBox", frame.SearchEditBackdrop, "InputBoxTemplate")
        frame.SearchEditBox:SetAutoFocus(false)
        frame.SearchEditBox:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
        end)
        frame.SearchEditBox:SetScript("OnEnterPressed", function(editBox)
            editBox:ClearFocus()
        end)
        frame.SearchEditBox:SetScript("OnTextChanged", function(editBox)
            self.searchText = strtrim((editBox:GetText() or ""))
            self:RefreshIfShown()
        end)
    end
    frame.SearchEditBox:ClearAllPoints()
    frame.SearchEditBox:SetPoint("TOPLEFT", frame.SearchEditBackdrop, "TOPLEFT", 2, -1)
    frame.SearchEditBox:SetPoint("BOTTOMRIGHT", frame.SearchEditBackdrop, "BOTTOMRIGHT", -2, 1)
    frame.SearchEditBox:SetTextInsets(0, 0, 0, 0)
    frame.SearchEditBox:SetFontObject("GameFontHighlightSmall")
    if frame.SearchEditBox.Left then frame.SearchEditBox.Left:Hide() end
    if frame.SearchEditBox.Middle then frame.SearchEditBox.Middle:Hide() end
    if frame.SearchEditBox.Right then frame.SearchEditBox.Right:Hide() end
    frame.SearchEditBox:SetFrameLevel((frame:GetFrameLevel() or 40) + 12)
    frame.SearchEditBox:SetText(self.searchText or "")

    if frame.SearchBox then frame.SearchBox:Hide() end
    if frame.SearchToggle then frame.SearchToggle:Hide() end
    self:UpdateSearchLayout()

    if not frame.BottomRail then
        frame.BottomRail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.BottomRail:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame.BottomRail:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)
    end
    frame.BottomRail:ClearAllPoints()
    frame.BottomRail:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.BottomRail:SetHeight(46)
    frame.BottomRail:EnableMouse(true)
    frame.BottomRail:SetFrameLevel((frame:GetFrameLevel() or 40) + 12)
    frame.BottomRail:Show()
    frame.BottomRail:SetAlpha(1)

    if not frame.TabButtons then
        frame.TabButtons = {}
    end
    if not frame.ModeButtons then
        frame.ModeButtons = {}
    end

    if not frame.BagSlots then
        frame.BagSlots = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    frame.BagSlots:ClearAllPoints()
    frame.BagSlots:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    frame.BagSlots:SetWidth(TAB_RAIL_WIDTH)
    frame.BagSlots:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame.BagSlots:SetBackdropColor(0.08, 0.08, 0.08, 0.84)
    frame.BagSlots:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)
    frame.BagSlots:EnableMouse(true)
    frame.BagSlots:Show()
    frame.BagSlots:SetAlpha(1)

    frame.CharacterButton:Show()
    frame.CharacterButton:EnableMouse(true)
    frame.SearchToggleButton:Show()
    frame.SearchToggleButton:EnableMouse(true)
    frame.SettingsButton:Show()
    frame.SettingsButton:EnableMouse(true)

    if frame.MoneyBar then
        frame.MoneyBar:EnableMouse(true)
        if frame.MoneyBar.RegisterForClicks then
            frame.MoneyBar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        frame.MoneyBar:SetScript("OnEnter", function(bar)
            GameTooltip:SetOwner(bar, "ANCHOR_RIGHT")
            GameTooltip:SetText(GUILDBANK_FUNDS or "Guild Funds")
            GameTooltip:AddLine((LEFT_CLICK or "Left-click") .. ": " .. (DEPOSIT or "Deposit"), 0.85, 0.85, 0.85)
            local allowed = GetGuildBankWithdrawLimit()
            if allowed > 0 then
                local moneyText = (GetMoneyString and GetMoneyString(allowed, true)) or tostring(allowed)
                GameTooltip:AddLine((RIGHT_CLICK or "Right-click") .. ": " .. (WITHDRAW or "Withdraw") .. " " .. moneyText, 0.85, 0.85, 0.85)
            end
            GameTooltip:Show()
        end)
        frame.MoneyBar:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.MoneyBar:SetScript("OnMouseUp", function(_, mouseButton)
            local cursorType, cursorMoney = GetCursorInfo and GetCursorInfo() or nil, nil
            if cursorType == "money" then
                cursorMoney = GetCursorMoney and GetCursorMoney() or 0
            elseif cursorType == "guildbankmoney" then
                DropCursorMoney()
                if ClearCursor then ClearCursor() end
                return
            end
            if cursorMoney and cursorMoney > 0 and DepositGuildBankMoney then
                DepositGuildBankMoney(cursorMoney)
                if DropCursorMoney then DropCursorMoney() end
                if ClearCursor then ClearCursor() end
                return
            end

            if mouseButton == "RightButton" and GetGuildBankWithdrawLimit() > 0 then
                if StaticPopup_Show and _G["GUILDBANK_WITHDRAW"] then
                    StaticPopup_Show("GUILDBANK_WITHDRAW")
                end
            elseif mouseButton == "LeftButton" then
                if StaticPopup_Show and _G["GUILDBANK_DEPOSIT"] then
                    StaticPopup_Show("GUILDBANK_DEPOSIT")
                end
            end
        end)
    end
end

function OneGuildBank:EnsureModePanel()
    if not self.frame or not self.frame.Content then
        return
    end
    if self.frame.ModePanel then
        return
    end

    local panel = CreateFrame("Frame", nil, self.frame.Content, "BackdropTemplate")
    panel:SetAllPoints(self.frame.Content)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.04, 0.04, 0.04, 0.88)
    panel:SetBackdropBorderColor(0.20, 0.20, 0.20, 0.95)
    panel:Hide()

    panel.Title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.Title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    panel.Title:SetJustifyH("LEFT")

    panel.Body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.Body:SetPoint("TOPLEFT", panel.Title, "BOTTOMLEFT", 0, -8)
    panel.Body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
    panel.Body:SetJustifyH("LEFT")
    panel.Body:SetJustifyV("TOP")
    panel.Body:SetNonSpaceWrap(true)

    self.frame.ModePanel = panel
end

local function FormatGuildLogTime(year, month, day, hour)
    if RecentTimeDate and GUILD_BANK_LOG_TIME then
        return GUILD_BANK_LOG_TIME:format(RecentTimeDate(year, month, day, hour))
    end
    return (" (%02d/%02d %02d:00)"):format(tonumber(month) or 0, tonumber(day) or 0, tonumber(hour) or 0)
end

local function BuildTabLogText(tab)
    local numTransactions = GetNumGuildBankTransactions and (GetNumGuildBankTransactions(tab) or 0) or 0
    if numTransactions <= 0 then
        return NO_GUILDBANK_TRANSACTIONS or "No transactions."
    end

    local lines = {}
    for i = 1, numTransactions do
        local t, name, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i)
        name = name or UNKNOWN or "Unknown"
        local coloredName = (NORMAL_FONT_COLOR_CODE or "") .. name .. (FONT_COLOR_CODE_CLOSE or "")
        local msg
        if t == "deposit" then
            msg = format(GUILDBANK_DEPOSIT_FORMAT or "%s deposited %s", coloredName, itemLink or "")
            if (count or 0) > 1 then
                msg = msg .. format(GUILDBANK_LOG_QUANTITY or " x%d", count)
            end
        elseif t == "withdraw" then
            msg = format(GUILDBANK_WITHDRAW_FORMAT or "%s withdrew %s", coloredName, itemLink or "")
            if (count or 0) > 1 then
                msg = msg .. format(GUILDBANK_LOG_QUANTITY or " x%d", count)
            end
        elseif t == "move" then
            local tabName1 = GetGuildBankTabInfo and GetGuildBankTabInfo(tab1) or tostring(tab1 or "")
            local tabName2 = GetGuildBankTabInfo and GetGuildBankTabInfo(tab2) or tostring(tab2 or "")
            msg = format(GUILDBANK_MOVE_FORMAT or "%s moved %s x%d from %s to %s", coloredName, itemLink or "", count or 0, tabName1 or "", tabName2 or "")
        end
        if msg then
            lines[#lines + 1] = msg .. FormatGuildLogTime(year, month, day, hour)
        end
    end
    return table.concat(lines, "\n")
end

local function BuildMoneyLogText()
    local numTransactions = GetNumGuildBankMoneyTransactions and (GetNumGuildBankMoneyTransactions() or 0) or 0
    if numTransactions <= 0 then
        return NO_GUILDBANK_TRANSACTIONS or "No transactions."
    end

    local lines = {}
    for i = 1, numTransactions do
        local t, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i)
        name = name or UNKNOWN or "Unknown"
        local coloredName = (NORMAL_FONT_COLOR_CODE or "") .. name .. (FONT_COLOR_CODE_CLOSE or "")
        local money = GetDenominationsFromCopper and GetDenominationsFromCopper(amount or 0) or GetCoinTextureString(amount or 0)
        local msg
        if t == "deposit" then
            msg = format(GUILDBANK_DEPOSIT_MONEY_FORMAT or "%s deposited %s", coloredName, money or "")
        elseif t == "withdraw" then
            msg = format(GUILDBANK_WITHDRAW_MONEY_FORMAT or "%s withdrew %s", coloredName, money or "")
        elseif t == "repair" then
            msg = format(GUILDBANK_REPAIR_MONEY_FORMAT or "%s repaired for %s", coloredName, money or "")
        elseif t == "withdrawForTab" then
            msg = format(GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT or "%s withdrew for tab %s", coloredName, money or "")
        elseif t == "buyTab" then
            if (amount or 0) > 0 then
                msg = format(GUILDBANK_BUYTAB_MONEY_FORMAT or "%s bought tab for %s", coloredName, money or "")
            else
                msg = format(GUILDBANK_UNLOCKTAB_FORMAT or "%s unlocked tab", coloredName)
            end
        elseif t == "depositSummary" then
            msg = format(GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT or "Guild awarded %s", money or "")
        end
        if msg then
            lines[#lines + 1] = msg .. FormatGuildLogTime(year, month, day, hour)
        end
    end
    return table.concat(lines, "\n")
end

function OneGuildBank:UpdateModeView()
    if not self.frame then
        return
    end
    self:EnsureModePanel()

    local isBank = self.mode == "bank"
    for _, button in pairs(self.buttons) do
        if button then
            button:SetShown(isBank and not self.noViewableTabs)
        end
    end

    local panel = self.frame.ModePanel
    if not panel then
        return
    end
    if isBank then
        panel:Hide()
        return
    end

    panel:Show()
    if self.mode == "log" then
        panel.Title:SetText(GUILD_BANK_LOG or "Guild Bank Log")
        local tab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
        panel.Body:SetText(BuildTabLogText(tab))
    elseif self.mode == "moneylog" then
        panel.Title:SetText(GUILD_BANK_MONEY_LOG or "Guild Bank Money Log")
        panel.Body:SetText(BuildMoneyLogText())
    elseif self.mode == "tabinfo" then
        panel.Title:SetText(GUILD_BANK_TAB_INFO or "Guild Bank Tab Info")
        local tab = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
        local text = GetGuildBankText and GetGuildBankText(tab)
        panel.Body:SetText((text and text ~= "") and text or "No tab information.")
    else
        panel.Title:SetText(self.mode or "Mode")
        panel.Body:SetText("")
    end
end

function OneGuildBank:SavePosition()
    if not self.frame then
        return
    end
    local p, _, _, ox, oy = self.frame:GetPoint(1)
    local cfg = GetProfileConfig()
    cfg.point = p or "CENTER"
    cfg.x = ox or 0
    cfg.y = oy or 0
end

function OneGuildBank:EnsureItemGrid()
    if not self.frame or not self.frame.Content or (#self.buttons > 0) then
        return
    end

    local content = self.frame.Content
    local cfg = GetProfileConfig()
    local slotSize = tonumber(cfg.itemSize) or 36

    local function GetSlotVisualPosition(slot)
        local group = math.ceil(slot / NUM_SLOTS_PER_GUILDBANK_GROUP)
        local indexInGroup = ((slot - 1) % NUM_SLOTS_PER_GUILDBANK_GROUP) + 1
        local subColumn = (indexInGroup > NUM_GUILDBANK_ROWS) and 1 or 0
        local row = ((indexInGroup - 1) % NUM_GUILDBANK_ROWS) + 1
        local column = ((group - 1) * 2) + subColumn + 1
        return column, row
    end

    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
        local button = CreateFrame("Button", "LunaBagsGuildBankItemButton" .. slot, content, "ContainerFrameItemButtonTemplate")
        button:SetID(slot)
        button:SetSize(slotSize, slotSize)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
            ns.ItemButtonStyle.Apply(button)
        end

        local col, row = GetSlotVisualPosition(slot)
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            content,
            "TOPLEFT",
            GRID_INSET_X + ((col - 1) * (slotSize + GRID_SPACING_X)),
            -GRID_INSET_Y - ((row - 1) * (slotSize + GRID_SPACING_Y))
        )

        button:SetScript("OnClick", function(btn, mouseButton)
            self:HandleItemButtonClick(btn, mouseButton)
        end)
        button:SetScript("OnDragStart", function(btn)
            self:HandleItemButtonDragStart(btn)
        end)
        button:SetScript("OnEnter", function(btn)
            self:HandleItemButtonEnter(btn)
        end)
        button:SetScript("OnLeave", function()
            GameTooltip_Hide()
            ResetCursor()
        end)
        button:SetScript("OnHide", function(btn)
            if btn.hasStackSplit and btn.hasStackSplit == 1 and StackSplitFrame then
                StackSplitFrame:Hide()
            end
        end)
        button:SetScript("OnUpdate", function(btn)
            if GameTooltip and GameTooltip:IsOwned(btn) and btn.UpdateTooltip then
                btn:UpdateTooltip()
            end
        end)
        button.UpdateTooltip = function(btn)
            self:HandleItemButtonEnter(btn)
        end

        self.buttons[slot] = button
    end
end

function OneGuildBank:UpdateWindowSize()
    if not self.frame then
        return
    end

    local cfg = GetProfileConfig()
    local slotSize = tonumber(cfg.itemSize) or 36

    local gridWidth = (NUM_GUILDBANK_COLUMNS * slotSize) + ((NUM_GUILDBANK_COLUMNS - 1) * GRID_SPACING_X)
    local gridHeight = (NUM_GUILDBANK_ROWS * slotSize) + ((NUM_GUILDBANK_ROWS - 1) * GRID_SPACING_Y)

    local contentWidth = GRID_INSET_X + gridWidth + GRID_INSET_X
    local contentHeight = GRID_INSET_Y + gridHeight + GRID_INSET_Y

    local frameWidth = contentWidth + 24
    local topInset = self.searchVisible and 62 or 34
    local bottomInset = 40
    local frameHeight = contentHeight + topInset + bottomInset

    self.frame:SetSize(frameWidth, frameHeight)
end

function OneGuildBank:ApplySettings()
    self:Create()
    if not self.frame then
        return
    end

    local cfg = GetProfileConfig()
    local scale = tonumber(cfg.scale) or 1
    local locked = cfg.locked == true
    local point = cfg.point or "CENTER"
    local x = tonumber(cfg.x) or 0
    local y = tonumber(cfg.y) or 0
    local color = cfg.windowColor or { r = 0.12, g = 0.12, b = 0.12 }
    local opacity = tonumber(cfg.windowOpacity) or 0.72
    self.tabRailPosition = NormalizeRailPosition(cfg.tabRailPosition, "left")
    self.modeRailPosition = NormalizeRailPosition(cfg.modeRailPosition, "bottom")

    self.frame:SetScale(scale)
    self.frame:SetMovable(not locked)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(f)
        if not locked then
            f:StartMoving()
        end
    end)
    self.frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local p, _, rp, ox, oy = f:GetPoint(1)
        local active = GetProfileConfig()
        active.point = p or active.point or "CENTER"
        active.relativePoint = rp or active.relativePoint
        active.x = ox or active.x or 0
        active.y = oy or active.y or 0
    end)

    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, point, x, y)

    if ns.WindowChrome and ns.WindowChrome.ApplyAppearance then
        ns.WindowChrome.ApplyAppearance(self.frame, cfg)
    elseif self.frame.SetBackdrop then
        self.frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        self.frame:SetBackdropColor(color.r or 0.12, color.g or 0.12, color.b or 0.12, opacity)
        self.frame:SetBackdropBorderColor(0.22, 0.22, 0.22, 0.95)
    end

    if self.frame.BagSlots then
        self.frame.BagSlots:ClearAllPoints()
        if self.tabRailPosition == "right" then
            self.frame.BagSlots:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 0, 0)
        elseif self.tabRailPosition == "top" then
            self.frame.BagSlots:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 0)
        elseif self.tabRailPosition == "bottom" then
            self.frame.BagSlots:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, 0)
        else
            self.frame.BagSlots:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 0)
        end
        self.frame.BagSlots:SetWidth(TAB_RAIL_WIDTH)
        self.frame.BagSlots:Show()
    end

    if self.frame.BottomRail then
        self.frame.BottomRail:ClearAllPoints()
        if self.modeRailPosition == "left" then
            self.frame.BottomRail:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 0)
        elseif self.modeRailPosition == "right" then
            self.frame.BottomRail:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 0, 0)
        elseif self.modeRailPosition == "top" then
            self.frame.BottomRail:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 0)
        else
            self.frame.BottomRail:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, 0)
        end
        self.frame.BottomRail:SetWidth(160)
        self.frame.BottomRail:Show()
    end

    self:UpdateWindowSize()
end

function OneGuildBank:IsTabViewable(tab)
    self.nextAvailableTab = nil
    if not IsGuildBankAvailable() then
        return false
    end

    local viewable = false
    for i = 1, MAX_GUILDBANK_TABS do
        local _, _, isViewable = GetGuildBankTabInfo(i)
        if isViewable then
            if not self.nextAvailableTab then
                self.nextAvailableTab = i
            end
            if i == tab then
                viewable = true
            end
        end
    end
    return viewable
end

function OneGuildBank:SelectAvailableTab()
    if not IsGuildBankAvailable() then
        return
    end

    local currentTab = GetCurrentGuildBankTab()
    if self:IsTabViewable(currentTab) then
        self.noViewableTabs = nil
        self:Refresh()
        return
    end

    if self.nextAvailableTab then
        self.noViewableTabs = nil
        SetCurrentGuildBankTab(self.nextAvailableTab)
        if QueryGuildBankTab then
            QueryGuildBankTab(self.nextAvailableTab)
        end
    else
        self.noViewableTabs = true
    end

    self:Refresh()
end

function OneGuildBank:RefreshMoneyDisplay()
    if not self.frame or not self.frame.MoneyBar or not self.frame.MoneyBar.Text then
        return
    end

    local money = (GetGuildBankMoney and GetGuildBankMoney()) or 0
    local label = _G.GUILD_BANK or "Guild Bank"
    if self.noViewableTabs then
        label = _G.NO_VIEWABLE_GUILDBANK_TABS or label
    end

    self.frame.MoneyBar.Label:SetText(label)
    self.frame.MoneyBar.Text:SetText(GetCoinTextureString and GetCoinTextureString(money) or tostring(money))
    if self.frame.MoneyBar.SetMinMaxValues then
        self.frame.MoneyBar:SetMinMaxValues(0, math.max(1, money))
        self.frame.MoneyBar:SetValue(money)
    end
end

function OneGuildBank:SlotMatchesSearch(tab, slot)
    local text = self.searchText
    if not text or text == "" then
        return true
    end
    text = string.lower(text)
    local itemLink = GetGuildBankItemLink and GetGuildBankItemLink(tab, slot)
    if not itemLink then
        return false
    end
    local itemName = GetItemInfo and GetItemInfo(itemLink)
    if not itemName then
        return true
    end
    return string.find(string.lower(itemName), text, 1, true) ~= nil
end

function OneGuildBank:RefreshItemButtons()
    if not self.frame then
        return
    end
    self:EnsureItemGrid()
    if not IsGuildBankAvailable() then
        for _, button in pairs(self.buttons) do
            button:Hide()
        end
        return
    end

    local tab = GetCurrentGuildBankTab()
    local _, _, _, canDeposit, numWithdrawals = GetGuildBankTabInfo and GetGuildBankTabInfo(tab) or nil, nil, nil, true, -1
    local canWithdrawItems = (numWithdrawals == nil) or (numWithdrawals ~= 0)
    local hasItemInteraction = (canDeposit == true) or canWithdrawItems
    local searching = self.searchText and self.searchText ~= ""
    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
        local button = self.buttons[slot]
        if button then
            local texture, count, locked, isFiltered, quality = GetGuildBankItemInfo(tab, slot)
            button.guildBankTab = tab
            button.guildBankSlot = slot
            button:SetID(slot)
            button.itemData = texture and {
                stackCount = count or 0,
                isLocked = locked == true,
                itemLink = GetGuildBankItemLink and GetGuildBankItemLink(tab, slot) or nil,
            } or nil
            SetItemButtonTexture(button, texture)
            SetItemButtonCount(button, count)
            if ns.ItemButtonStyle and ns.ItemButtonStyle.ApplyTextStyle then
                ns.ItemButtonStyle.ApplyTextStyle(button)
            end
            SetItemButtonDesaturated(button, locked)

            if ns.ItemButtonStyle and ns.ItemButtonStyle.UpdateBorderForItem then
                ns.ItemButtonStyle.UpdateBorderForItem(button, { quality = quality }, true)
            end

            local matchesSearch = self:SlotMatchesSearch(tab, slot)
            local isEmpty = not texture
            local alpha
            if searching and not matchesSearch then
                alpha = isEmpty and 0.18 or 0.22
            else
                alpha = isEmpty and 0.55 or 1
            end
            if locked then
                alpha = math.max(0.1, alpha * 0.72)
            end
            if not hasItemInteraction and texture then
                alpha = math.min(alpha, 0.45)
            end
            button:SetAlpha(alpha)
            button._baseAlpha = alpha

            if button.searchOverlay then
                button.searchOverlay:Hide()
            end

            button:EnableMouse(hasItemInteraction == true)
            button:SetShown(not self.noViewableTabs)
            if GameTooltip and GameTooltip:IsOwned(button) then
                self:HandleItemButtonEnter(button)
            end
        end
    end
end

function OneGuildBank:Refresh()
    self:Create()
    if not self.frame then
        return
    end

    local titleTarget = self.frame.CustomTitle
    if titleTarget then
        local guildName = GetGuildInfo and select(1, GetGuildInfo("player"))
        local tab = IsGuildBankAvailable() and GetCurrentGuildBankTab() or 1
        local tabName = IsGuildBankAvailable() and select(1, GetGuildBankTabInfo(tab)) or nil
        if not tabName or tabName == "" then
            tabName = format(GUILDBANK_TAB_NUMBER or "Tab %d", tab or 1)
        end
        if guildName and guildName ~= "" then
            titleTarget:SetText(("%s - %s"):format(guildName, tabName))
        else
            titleTarget:SetText(tabName)
        end
    end

    self:RefreshRails()
    self:RefreshItemButtons()
    self:UpdateModeView()
    self:RefreshMoneyDisplay()
end

function OneGuildBank:SetMode(mode)
    if mode ~= "bank" and mode ~= "log" and mode ~= "moneylog" and mode ~= "tabinfo" then
        return
    end
    self.mode = mode
    if mode == "log" and QueryGuildBankLog then
        QueryGuildBankLog(GetCurrentGuildBankTab())
    elseif mode == "moneylog" and QueryGuildBankLog then
        QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)
    elseif mode == "tabinfo" and QueryGuildBankText then
        QueryGuildBankText(GetCurrentGuildBankTab())
    elseif mode == "bank" and QueryGuildBankTab then
        QueryGuildBankTab(GetCurrentGuildBankTab())
    end
    self:RefreshIfShown()
end

function OneGuildBank:SelectTab(tab)
    if not tab or tab < 1 then
        return
    end
    self.currentTab = tab
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tab)
    end

    if self.mode == "log" and QueryGuildBankLog then
        QueryGuildBankTab(tab)
        QueryGuildBankLog(tab)
    elseif self.mode == "moneylog" and QueryGuildBankLog then
        QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)
    elseif self.mode == "tabinfo" and QueryGuildBankText then
        QueryGuildBankText(tab)
    elseif QueryGuildBankTab then
        QueryGuildBankTab(tab)
    end

    self:SelectAvailableTab()
    self:RefreshIfShown()
end

function OneGuildBank:RefreshRails()
    if not self.frame or not self.frame.BagSlots or not self.frame.BottomRail then
        return
    end

    local rail = self.frame.BagSlots
    local numTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
    local maxTabsToShow = math.max(1, math.min(MAX_GUILDBANK_TABS, numTabs > 0 and numTabs or 1))
    local currentTab = IsGuildBankAvailable() and GetCurrentGuildBankTab() or 1
    local size, spacing, pad = 34, 4, 6
    local tabPos = self.tabRailPosition or "left"
    local tabVertical = (tabPos == "left" or tabPos == "right")
    local canBuyNewTab = (IsGuildLeader and IsGuildLeader()) and (numTabs < MAX_BUY_GUILDBANK_TABS)
    local buySlotIndex = canBuyNewTab and (numTabs + 1) or nil

    for i = 1, MAX_GUILDBANK_TABS do
        local button = self.frame.TabButtons[i]
        if not button then
            button = CreateFrame("Button", nil, rail, "BackdropTemplate")
            button:SetSize(size, size)
            button.Icon = button:CreateTexture(nil, "ARTWORK")
            button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
            button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
            button.Icon:SetTexCoord(0, 1, 0, 1)
            if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
                ns.ItemButtonStyle.Apply(button)
            end
            button:SetScript("OnClick", function(btn)
                if btn.isBuyTab then
                    if StaticPopup_Show and _G["CONFIRM_BUY_GUILDBANK_TAB"] then
                        StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
                    elseif BuyGuildBankTab then
                        BuyGuildBankTab()
                    end
                    return
                end
                self:SelectTab(btn.tabID or 1)
            end)
            self.frame.TabButtons[i] = button
        end
        button:ClearAllPoints()
        if tabVertical then
            button:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -pad - ((i - 1) * (size + spacing)))
        else
            button:SetPoint("TOPLEFT", rail, "TOPLEFT", pad + ((i - 1) * (size + spacing)), -pad)
        end
        button.tabID = i

        local name, icon, isViewable = GetGuildBankTabInfo and GetGuildBankTabInfo(i) or nil, nil, nil
        local canDeposit, numWithdrawals, remainingWithdrawals
        if GetGuildBankTabInfo then
            name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(i)
        end
        if not name or name == "" then
            name = ("Tab %d"):format(i)
        end
        button:SetText("")
        button.isBuyTab = (buySlotIndex ~= nil and i == buySlotIndex)
        if button.isBuyTab then
            if button.Icon then
                button.Icon:SetTexture("Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab")
            end
            button.tooltip = BUY_GUILDBANK_TAB or "Buy Guild Bank Tab"
        else
            if button.Icon then
                button.Icon:SetTexture(icon or "Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab")
            end
            button.tooltip = name
        end
        button:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:SetText(btn.tooltip or "")
            if btn.isBuyTab then
                local cost = GetGuildBankTabCost and GetGuildBankTabCost()
                if cost and SetTooltipMoney then
                    SetTooltipMoney(GameTooltip, cost)
                end
            else
                if btn.permissionText and btn.permissionText ~= "" then
                    GameTooltip:AddLine(btn.permissionText, 0.85, 0.85, 0.85)
                end
                if btn.remainingText and btn.remainingText ~= "" then
                    GameTooltip:AddLine(btn.remainingText, 0.75, 0.82, 0.95)
                end
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local shown = (i <= maxTabsToShow) or (buySlotIndex ~= nil and i == buySlotIndex)
        button:SetShown(shown)
        button:EnableMouse(shown and (button.isBuyTab or isViewable ~= false))
        if not button.WithdrawText then
            button.WithdrawText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            button.WithdrawText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
            button.WithdrawText:SetJustifyH("RIGHT")
        end

        local permissionText
        if not button.isBuyTab then
            if isViewable == false or ((canDeposit ~= true) and (numWithdrawals == 0)) then
                permissionText = GUILDBANK_TAB_LOCKED or "Locked"
            elseif canDeposit ~= true and (numWithdrawals and numWithdrawals > 0) then
                permissionText = GUILDBANK_TAB_WITHDRAW_ONLY or "Withdraw only"
            elseif canDeposit == true and numWithdrawals == 0 then
                permissionText = GUILDBANK_TAB_DEPOSIT_ONLY or "Deposit only"
            else
                permissionText = GUILDBANK_TAB_FULL_ACCESS or "Full access"
            end
        end
        button.permissionText = permissionText

        if button.isBuyTab then
            button.remainingText = nil
            button.WithdrawText:SetText("+")
            button.WithdrawText:SetTextColor(0.94, 0.82, 0.34, 1)
            button.WithdrawText:Show()
        else
            local remainingText
            if remainingWithdrawals ~= nil then
                if remainingWithdrawals > 0 then
                    remainingText = tostring(remainingWithdrawals)
                elseif remainingWithdrawals == 0 then
                    remainingText = "0"
                else
                    remainingText = "*"
                end
            end
            local remainingLabel = GUILDBANK_REMAINING or "Remaining"
            button.remainingText = (remainingText and ((remainingLabel .. ": ") .. remainingText)) or nil
            if remainingText then
                button.WithdrawText:SetText(remainingText)
                if remainingText == "0" then
                    button.WithdrawText:SetTextColor(0.95, 0.35, 0.35, 1)
                else
                    button.WithdrawText:SetTextColor(0.82, 0.82, 0.82, 1)
                end
                button.WithdrawText:Show()
            else
                button.WithdrawText:Hide()
            end
        end

        if button.isBuyTab then
            button:SetAlpha(0.95)
        else
            local baseAlpha = (i == currentTab and 1 or 0.85)
            if isViewable == false then
                baseAlpha = 0.35
            elseif canDeposit ~= true and (numWithdrawals == 0) then
                baseAlpha = math.min(baseAlpha, 0.50)
            elseif canDeposit ~= true or numWithdrawals == 0 then
                baseAlpha = math.min(baseAlpha, 0.72)
            end
            button:SetAlpha(baseAlpha)
        end
        if button.StyleBorder then
            if button.isBuyTab then
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.56, 0.44, 0.14, 0.95
            elseif i == currentTab then
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.78, 0.66, 0.26, 1
            else
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.34, 0.34, 0.34, 0.95
            end
            button.StyleBorder:SetBackdropBorderColor(
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA
            )
        end
    end

    local visibleTabButtons = maxTabsToShow + (buySlotIndex and 1 or 0)
    if tabVertical then
        rail:SetWidth(size + pad * 2)
        rail:SetHeight(pad * 2 + visibleTabButtons * size + math.max(0, visibleTabButtons - 1) * spacing)
    else
        rail:SetWidth(pad * 2 + visibleTabButtons * size + math.max(0, visibleTabButtons - 1) * spacing)
        rail:SetHeight(size + pad * 2)
    end

    local modes = {
        { id = "bank", tooltip = GUILD_BANK or "Bank", icon = "Interface\\Buttons\\Button-Backpack-Up" },
        { id = "log", tooltip = GUILD_BANK_LOG or "Log", icon = "Interface\\Icons\\INV_Misc_Note_01" },
        { id = "moneylog", tooltip = GUILD_BANK_MONEY_LOG or "Money Log", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { id = "tabinfo", tooltip = GUILD_BANK_TAB_INFO or "Tab Info", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    }
    for index, entry in ipairs(modes) do
        local button = self.frame.ModeButtons[index]
        if not button then
            button = CreateFrame("Button", nil, self.frame.BottomRail, "BackdropTemplate")
            button:SetSize(34, 34)
            button:EnableMouse(true)
            button:RegisterForClicks("LeftButtonUp")
            button.Icon = button:CreateTexture(nil, "ARTWORK")
            button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
            button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
            button.Icon:SetTexCoord(0, 1, 0, 1)
            if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
                ns.ItemButtonStyle.Apply(button)
            end
            button:SetScript("OnClick", function(btn)
                self:SetMode(btn.modeID)
            end)
            self.frame.ModeButtons[index] = button
        end
        button:SetFrameLevel((self.frame.BottomRail:GetFrameLevel() or 50) + 1)
        button:ClearAllPoints()
        local modePos = self.modeRailPosition or "bottom"
        local modeVertical = (modePos == "left" or modePos == "right")
        if modeVertical then
            button:SetPoint("TOPLEFT", self.frame.BottomRail, "TOPLEFT", 6, -6 - ((index - 1) * 38))
        else
            button:SetPoint("TOPLEFT", self.frame.BottomRail, "TOPLEFT", 6 + ((index - 1) * 38), -6)
        end
        button.modeID = entry.id
        button:SetText("")
        if button.Icon then
            button.Icon:SetTexture(entry.icon)
        end
        button:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:SetText(entry.tooltip)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetAlpha(self.mode == entry.id and 1 or 0.85)
        if button.StyleBorder then
            if self.mode == entry.id then
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.78, 0.66, 0.26, 1
            else
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = 0.34, 0.34, 0.34, 0.95
            end
            button.StyleBorder:SetBackdropBorderColor(
                button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA
            )
        end
    end
    local modePos = self.modeRailPosition or "bottom"
    local modeVertical = (modePos == "left" or modePos == "right")
    if modeVertical then
        self.frame.BottomRail:SetWidth(46)
        self.frame.BottomRail:SetHeight(6 + (#modes * 38) + 2)
    else
        self.frame.BottomRail:SetWidth(6 + (#modes * 38) + 2)
        self.frame.BottomRail:SetHeight(46)
    end
end

function OneGuildBank:RefreshIfShown()
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

function OneGuildBank:InvalidateSlotCache()
    -- Guild bank refresh is API-driven; keep this for parity with other modules.
end

function OneGuildBank:Show()
    self:Create()
    if not self.frame then
        return
    end
    SetBlizzardGuildBankSuppressed(true)
    self:ApplySettings()
    if IsGuildBankAvailable() and QueryGuildBankTab then
        QueryGuildBankTab(GetCurrentGuildBankTab())
    end
    self:SelectAvailableTab()
    self.frame:Show()
end

function OneGuildBank:Hide()
    if self.frame then
        self.frame:Hide()
    end
    SetBlizzardGuildBankSuppressed(false)
end

function OneGuildBank:EventHandler(event, ...)
    if event == "GUILDBANK_UPDATE_TABS" or event == "GUILD_ROSTER_UPDATE" then
        local tab = IsGuildBankAvailable() and GetCurrentGuildBankTab() or nil
        if event == "GUILD_ROSTER_UPDATE"
            and tab
            and not select(1, ...)
            and self.noViewableTabs
            and self.mode == "bank"
            and QueryGuildBankTab
        then
            QueryGuildBankTab(tab)
        end
        self:SelectAvailableTab()
        return
    end

    if event == "GUILDBANK_TEXT_CHANGED" and GetCurrentGuildBankTab and QueryGuildBankText then
        local changedTab = tonumber(...)
        if changedTab and GetCurrentGuildBankTab() == changedTab then
            QueryGuildBankText(changedTab)
        end
    end

    self:RefreshIfShown()
end

function OneGuildBank:HandleItemButtonDragStart(button)
    if not button or not IsGuildBankAvailable() then
        return
    end
    local tab = button.guildBankTab or (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
    local slot = button.guildBankSlot or button:GetID()
    if SetCurrentGuildBankTab and GetCurrentGuildBankTab and GetCurrentGuildBankTab() ~= tab then
        SetCurrentGuildBankTab(tab)
    end
    PickupGuildBankItem(tab, slot)
end

function OneGuildBank:HandleItemButtonClick(button, mouseButton)
    if not button or not IsGuildBankAvailable() then
        return
    end

    local tab = button.guildBankTab or (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
    local slot = button.guildBankSlot or button:GetID()
    if SetCurrentGuildBankTab and GetCurrentGuildBankTab and GetCurrentGuildBankTab() ~= tab then
        SetCurrentGuildBankTab(tab)
    end
    local itemLink = GetGuildBankItemLink and GetGuildBankItemLink(tab, slot)
    if itemLink and HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
        return
    end

    if IsModifiedClick and IsModifiedClick("SPLITSTACK") then
        if not CursorHasItem() then
            local _, count, locked = GetGuildBankItemInfo(tab, slot)
            if not locked and count and count > 1 then
                OpenStackSplitFrame(count, button, "BOTTOMLEFT", "TOPLEFT")
            end
        end
        return
    end

    local cursorType, money = GetCursorInfo()
    if cursorType == "money" then
        DepositGuildBankMoney(money)
        ClearCursor()
        return
    end
    if cursorType == "guildbankmoney" then
        DropCursorMoney()
        ClearCursor()
        return
    end

    if mouseButton == "RightButton" then
        AutoStoreGuildBankItem(tab, slot)
        GameTooltip_Hide()
    else
        PickupGuildBankItem(tab, slot)
    end
end

function OneGuildBank:HandleItemButtonEnter(button)
    if not button or not IsGuildBankAvailable() then
        return
    end
    local tab = button.guildBankTab or (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
    local slot = button.guildBankSlot or button:GetID()
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tab)
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetGuildBankItem(tab, slot)
    if speciesID and speciesID > 0 and BattlePetToolTip_Show then
        BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name)
    end
end

function OneGuildBank:ResetPosition()
    local cfg = GetProfileConfig()
    cfg.point = "CENTER"
    cfg.x = 0
    cfg.y = 0
    self:ApplySettings()
end

function _G.LunaBagsOneGuildBank_SearchChanged(editBox)
    local module = ns.OneGuildBank
    if not module then
        return
    end
    module.searchText = (editBox and editBox.GetText and editBox:GetText()) or ""
    module:RefreshIfShown()
end
