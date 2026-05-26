local ADDON_NAME, ns = ...

local OneGuildBank = ns.LunaBags and ns.LunaBags:NewModule("OneGuildBank") or {}
OneGuildBank.frame = nil
OneGuildBank.buttons = {}
OneGuildBank.tabButtons = {}
OneGuildBank.selectedTab = 1
OneGuildBank.searchText = ""
OneGuildBank.searchVisible = false
OneGuildBank.columns = 14
OneGuildBank.slotSize = 36
OneGuildBank.spacing = 4
OneGuildBank.mode = "bank"

ns.OneGuildBank = OneGuildBank

function OneGuildBank:OnDisable()
    self:Hide()
    if ns.LunaBags and ns.LunaBags.RestoreDefaultGuildBankFrame then
        ns.LunaBags:RestoreDefaultGuildBankFrame()
    end
end

local MAX_GUILD_BANK_SLOTS = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
local FRAME_STRATA = "DIALOG"
local FRAME_LEVEL = 40
local FIXED_COLUMNS = 14
local DEFAULT_GROUP_ROWS = 7
local DEFAULT_GROUP_COLUMNS = 2
local CONTENT_INSET_X = 8
local CONTENT_BOTTOM_INSET = 48
local FRAME_BORDER_PADDING_Y = 3
local FRAME_PADDING_X = CONTENT_INSET_X * 2
local MODE_BUTTONS = {
    { key = "bank", label = BANK or "Bank", icon = "Interface\\Buttons\\Button-Backpack-Up" },
    { key = "info", label = INFO or "Info", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "log", label = GUILD_BANK_LOG or "Log", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "moneylog", label = GUILD_BANK_MONEY_LOG or "Money Log", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
}
local LOG_TYPES = {
    deposit = GUILDBANK_DEPOSIT_MONEY_FORMAT,
    withdraw = GUILDBANK_WITHDRAW_MONEY_FORMAT,
    buyTab = GUILDBANK_BUYTAB_MONEY_FORMAT,
    repair = GUILDBANK_REPAIR_MONEY_FORMAT,
    withdrawForTab = GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT,
    unlockTab = GUILDBANK_UNLOCKTAB_FORMAT,
    depositSummary = GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT,
}
local GetCurrentTab

local function Clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function GetColorValue(color, r, g, b)
    if type(color) ~= "table" then
        return r, g, b
    end
    return tonumber(color.r or color[1]) or r,
        tonumber(color.g or color[2]) or g,
        tonumber(color.b or color[3]) or b
end

local function GetAppearanceConfig(cfg)
    local profile = ns.LunaBags and ns.LunaBags.db and ns.LunaBags.db.profile
    local shared = profile and profile.ui or nil
    if type(shared) == "table" then
        local merged = {}
        if type(cfg) == "table" then
            for k, v in pairs(cfg) do
                merged[k] = v
            end
        end
        for k, v in pairs(shared) do
            merged[k] = v
        end
        return merged
    end
    return cfg or {}
end

local function ApplyGuildBankFrameLayering(frame)
    if ns.WindowChrome and ns.WindowChrome.EnsureFrame then
        ns.WindowChrome.EnsureFrame(frame, OneGuildBank, { strata = FRAME_STRATA, level = FRAME_LEVEL })
    end
    if not frame then return end
    frame:SetFrameStrata(FRAME_STRATA)
    frame:SetFrameLevel(FRAME_LEVEL)
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end
    if frame.Content then frame.Content:SetFrameLevel(FRAME_LEVEL + 5) end
    if frame.TopRail then frame.TopRail:SetFrameLevel(FRAME_LEVEL + 6) end
    if frame.BottomRail then frame.BottomRail:SetFrameLevel(FRAME_LEVEL + 6) end
    if frame.SearchPanel then frame.SearchPanel:SetFrameLevel(FRAME_LEVEL + 10) end
    if frame.CloseButton then frame.CloseButton:SetFrameLevel(FRAME_LEVEL + 15) end
    if frame.SearchToggleButton then frame.SearchToggleButton:SetFrameLevel(FRAME_LEVEL + 15) end
    if frame.SettingsButton then frame.SettingsButton:SetFrameLevel(FRAME_LEVEL + 15) end
    if frame.GuildButton then frame.GuildButton:SetFrameLevel(FRAME_LEVEL + 15) end
end

local function ApplyWindowAppearance(frame, cfg)
    if ns.WindowChrome and ns.WindowChrome.ApplyAppearance then
        ns.WindowChrome.ApplyAppearance(frame, cfg)
        return
    end
    if not frame then
        return
    end
    cfg = GetAppearanceConfig(cfg)
    local wr, wg, wb = GetColorValue(cfg.windowColor, 0.12, 0.12, 0.12)
    local hr, hg, hb = GetColorValue(cfg.headerColor, 0.07, 0.07, 0.07)
    local windowOpacity = Clamp01(cfg.windowOpacity, 0.72)
    local headerOpacity = Clamp01(cfg.headerOpacity, 0.78)

    if frame.WindowBg then
        frame.WindowBg:SetVertexColor(wr, wg, wb, windowOpacity)
    end
    if frame.TitleBarBg then
        frame.TitleBarBg:SetVertexColor(hr, hg, hb, headerOpacity)
    end
    if frame.DarkInset then
        frame.DarkInset:SetVertexColor(wr * 0.18, wg * 0.18, wb * 0.18, math.min(1, windowOpacity * 0.9))
    end
    if frame.StatusBg then
        frame.StatusBg:SetVertexColor(wr * 0.85, wg * 0.85, wb * 0.85, math.min(1, windowOpacity * 0.95))
    end
    if frame.SearchPanel then
        frame.SearchPanel:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity * 0.95))
    end
    if frame.TopRail then
        frame.TopRail:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity))
    end
    if frame.BottomRail then
        frame.BottomRail:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity))
    end
end

function OneGuildBank:QueryCurrentTab()
    local tab = GetCurrentTab()
    if QueryGuildBankTab then
        QueryGuildBankTab(tab)
    end
    if QueryGuildBankText then
        QueryGuildBankText(tab)
    end
    if self._queryRefreshPending then
        return
    end
    self._queryRefreshPending = true
    local function refresh()
        OneGuildBank._queryRefreshPending = nil
        OneGuildBank:RefreshIfShown()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, refresh)
        C_Timer.After(0.5, function() OneGuildBank:RefreshIfShown() end)
    elseif self.frame then
        local elapsed = 0
        self.frame:SetScript("OnUpdate", function(frame, delta)
            elapsed = elapsed + (delta or 0)
            if elapsed >= 0.15 then
                frame:SetScript("OnUpdate", nil)
                refresh()
            end
        end)
    end
end

local function GetConfig()
    local addon = ns.LunaBags
    if not addon or not addon.db or not addon.db.profile then
        return {}
    end
    addon.db.profile.oneGuildBank = addon.db.profile.oneGuildBank or {}
    return addon.db.profile.oneGuildBank
end

local RefreshGuildBankActionButtons
local CreateEditorInput
local popupHooksInstalled = false

local function RegisterSpecialFrame(frame)
    if not UISpecialFrames or not frame or not frame.GetName then
        return
    end
    local frameName = frame:GetName()
    if not frameName then
        return
    end
    for _, name in ipairs(UISpecialFrames) do
        if name == frameName then
            return
        end
    end
    table.insert(UISpecialFrames, frameName)
end

local function RefreshGuildBankTabInfoSoon()
    local tab = GetCurrentTab and GetCurrentTab() or nil
    if tab and QueryGuildBankTab then
        QueryGuildBankTab(tab)
    end
    if tab and QueryGuildBankText then
        QueryGuildBankText(tab)
    end
    if OneGuildBank.RefreshTabs then
        OneGuildBank:RefreshTabs()
    end
    if OneGuildBank.InvalidateSlotCache then
        OneGuildBank:InvalidateSlotCache()
    end
    if OneGuildBank.RefreshIfShown then
        OneGuildBank:RefreshIfShown()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            if OneGuildBank.RefreshTabs then
                OneGuildBank:RefreshTabs()
            end
            if OneGuildBank.RefreshIfShown then
                OneGuildBank:RefreshIfShown()
            end
        end)
    end
end

local function EnsureGuildBankPopupHooks()
    if popupHooksInstalled then
        return
    end
    popupHooksInstalled = true
    if hooksecurefunc then
        if GuildBankPopupFrame and GuildBankPopupFrame.ConfirmEdit then
            hooksecurefunc(GuildBankPopupFrame, "ConfirmEdit", RefreshGuildBankTabInfoSoon)
        end
        if SetGuildBankTabInfo then
            hooksecurefunc("SetGuildBankTabInfo", RefreshGuildBankTabInfoSoon)
        end
        if SetGuildBankText then
            hooksecurefunc("SetGuildBankText", RefreshGuildBankTabInfoSoon)
        end
    end
end

local function MoneyToString(copper)
    if GetMoneyString then
        return GetMoneyString(copper or 0, true)
    end
    return tostring(copper or 0)
end

local function RefreshGuildBankMoneyDisplay()
    local frame = OneGuildBank.frame
    if not frame then
        return
    end
    if frame.MoneyBar and frame.MoneyBar.Text then
        local money = GetGuildBankMoney and GetGuildBankMoney() or 0
        frame.MoneyBar.Text:SetText(MoneyToString(money))
    end
    if RefreshGuildBankActionButtons then
        RefreshGuildBankActionButtons(frame)
    end
end

local function RefreshGuildBankMoneySoon()
    RefreshGuildBankMoneyDisplay()
    local function refresh()
        RefreshGuildBankMoneyDisplay()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, refresh)
        C_Timer.After(0.6, refresh)
    end
end

local function ParseMoneyText(text)
    text = tostring(text or ""):lower():gsub(",", ""):gsub("%s+", "")
    if text == "" then
        return 0
    end
    local total = 0
    local matched = false
    for amount, unit in text:gmatch("([%d%.]+)([gsc])") do
        local value = tonumber(amount) or 0
        if unit == "g" then
            total = total + math.floor(value * (COPPER_PER_GOLD or 10000))
        elseif unit == "s" then
            total = total + math.floor(value * (COPPER_PER_SILVER or 100))
        elseif unit == "c" then
            total = total + math.floor(value)
        end
        matched = true
    end
    if matched then
        return math.max(0, math.floor(total))
    end
    return math.max(0, math.floor(tonumber(text) or 0))
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

local moneyHooksInstalled = false

local function EnsureGuildBankMoneyHooks()
    if moneyHooksInstalled or not hooksecurefunc then
        return
    end
    moneyHooksInstalled = true
    if DepositGuildBankMoney then
        hooksecurefunc("DepositGuildBankMoney", RefreshGuildBankMoneySoon)
    end
    if WithdrawGuildBankMoney then
        hooksecurefunc("WithdrawGuildBankMoney", RefreshGuildBankMoneySoon)
    end
end

local function GetMoneyDialogCopper(dialog)
    if dialog and dialog.MoneyInput and MoneyInputFrame_GetCopper then
        return tonumber(MoneyInputFrame_GetCopper(dialog.MoneyInput)) or 0
    end
    if dialog and dialog.FallbackEdit then
        return ParseMoneyText(dialog.FallbackEdit:GetText())
    end
    return 0
end

local function ResetMoneyDialog(dialog)
    if dialog.MoneyInput and MoneyInputFrame_ResetMoney then
        MoneyInputFrame_ResetMoney(dialog.MoneyInput)
    end
    if dialog.FallbackEdit then
        dialog.FallbackEdit:SetText("")
    end
end

local function CreateGuildBankMoneyDialog()
    local dialog = CreateFrame("Frame", "LunaBagsGuildBankMoneyDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(260, 126)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(90)
    if dialog.SetToplevel then
        dialog:SetToplevel(true)
    end
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:Hide()
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    dialog.Title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.Title:SetPoint("TOP", dialog, "TOP", 0, -18)

    local ok, moneyInput = pcall(CreateFrame, "Frame", "LunaBagsGuildBankMoneyInput", dialog, "MoneyInputFrameTemplate")
    if ok and moneyInput then
        dialog.MoneyInput = moneyInput
        moneyInput:SetPoint("TOP", dialog.Title, "BOTTOM", 0, -16)
        if MoneyInputFrame_SetCopper then
            MoneyInputFrame_SetCopper(moneyInput, 0)
        end
    else
        dialog.FallbackEdit = CreateEditorInput(dialog, "LunaBagsGuildBankMoneyFallbackEdit", false)
        dialog.FallbackEdit:SetPoint("TOPLEFT", dialog, "TOPLEFT", 28, -48)
        dialog.FallbackEdit:SetPoint("RIGHT", dialog, "RIGHT", -28, 0)
        dialog.FallbackEdit:SetHeight(22)
    end

    dialog.AcceptButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.AcceptButton:SetSize(82, 22)
    dialog.AcceptButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 18)
    dialog.AcceptButton:SetText(ACCEPT or OKAY or "OK")

    dialog.CancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.CancelButton:SetSize(82, 22)
    dialog.CancelButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 18)
    dialog.CancelButton:SetText(CANCEL or "Cancel")
    dialog.CancelButton:SetScript("OnClick", function(self)
        self:GetParent():Hide()
    end)

    dialog:SetScript("OnHide", function(self)
        ResetMoneyDialog(self)
    end)

    dialog.AcceptButton:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        local copper = GetMoneyDialogCopper(parent)
        if copper <= 0 then
            return
        end
        if parent.kind == "deposit" then
            copper = math.min(copper, GetMoney and GetMoney() or copper)
            if copper > 0 and DepositGuildBankMoney then
                DepositGuildBankMoney(copper)
            end
        else
            copper = math.min(copper, GetGuildBankWithdrawLimit())
            if copper > 0 and WithdrawGuildBankMoney then
                WithdrawGuildBankMoney(copper)
            end
        end
        parent:Hide()
        RefreshGuildBankMoneySoon()
    end)

    return dialog
end

local function ShowGuildBankMoneyPopup(kind)
    local isDeposit = kind == "deposit"
    EnsureGuildBankMoneyHooks()
    local dialog = OneGuildBank.moneyDialog or CreateGuildBankMoneyDialog()
    OneGuildBank.moneyDialog = dialog
    dialog.kind = isDeposit and "deposit" or "withdraw"
    dialog.Title:SetText(isDeposit and (GUILDBANK_DEPOSIT or DEPOSIT or "Deposit") or (GUILDBANK_WITHDRAW or WITHDRAW or "Withdraw"))
    ResetMoneyDialog(dialog)
    if OneGuildBank.frame then
        dialog:ClearAllPoints()
        dialog:SetPoint("CENTER", OneGuildBank.frame, "CENTER", 0, 0)
    else
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(100)
    if dialog.Raise then
        dialog:Raise()
    end
    dialog:Show()
    if dialog.MoneyInput then
        local goldBox = _G[dialog.MoneyInput:GetName() .. "Gold"]
        if goldBox then
            goldBox:SetFocus()
        end
    elseif dialog.FallbackEdit then
        dialog.FallbackEdit:SetFocus()
    end
end

local function ConfirmBuyGuildBankTab()
    if not BuyGuildBankTab then
        return
    end
    local shown
    if StaticPopup_Show then
        local popup = StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
        shown = popup ~= nil
        if popup and MoneyFrame_Update and GetGuildBankTabCost then
            MoneyFrame_Update(popup.moneyFrame, GetGuildBankTabCost())
        end
    end
    if not shown then
        BuyGuildBankTab()
    end
end

local function IsDebugEnabled()
    return ns.LunaBags and ns.LunaBags.db and ns.LunaBags.db.profile and ns.LunaBags.db.profile.debug == true
end

local function EnsureGuildBankUILoaded()
    if GuildBankFrame_LoadUI then
        GuildBankFrame_LoadUI()
    end
end

GetCurrentTab = function()
    local tab = OneGuildBank.selectedTab or (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
    local maxTabs = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
    if maxTabs > 0 then
        tab = math.max(1, math.min(tab, maxTabs))
    else
        tab = 1
    end
    return tab
end

local function SelectTab(tab)
    tab = tonumber(tab) or 1
    OneGuildBank.selectedTab = tab
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tab)
    end
    if OneGuildBank.mode == "log" and QueryGuildBankLog then
        if QueryGuildBankTab then
            QueryGuildBankTab(tab)
        end
        QueryGuildBankLog(tab)
    elseif OneGuildBank.mode == "moneylog" and QueryGuildBankLog then
        QueryGuildBankLog(MAX_GUILDBANK_TABS and (MAX_GUILDBANK_TABS + 1) or 9)
    elseif OneGuildBank.mode == "info" and QueryGuildBankText then
        QueryGuildBankText(tab)
    else
        OneGuildBank:QueryCurrentTab()
    end
    OneGuildBank:RefreshDeferred()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function() OneGuildBank:RefreshIfShown() end)
    end
end

local function GetItemDetails(itemLink, includeFullDetails)
    if not itemLink then
        return nil
    end
    local itemID = tonumber(itemLink:match("item:(%d+)")) or nil
    local itemName, _, itemQuality, itemLevel, _, itemTypeName, subTypeName, _, equipLoc, iconFileID, sellPrice, classID, subClassID
    if includeFullDetails and GetItemInfo then
        itemName, _, itemQuality, itemLevel, _, itemTypeName, subTypeName, _, equipLoc, iconFileID, sellPrice, classID, subClassID = GetItemInfo(itemLink)
    end
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInstant and (classID == nil or subClassID == nil or equipLoc == nil or itemTypeName == nil or subTypeName == nil) then
        local _, instantTypeName, instantSubTypeName, instantEquipLoc, instantIcon, instantClassID, instantSubClassID = getInstant(itemLink)
        itemTypeName = itemTypeName or instantTypeName
        subTypeName = subTypeName or instantSubTypeName
        equipLoc = equipLoc or instantEquipLoc
        iconFileID = iconFileID or instantIcon
        classID = classID or instantClassID
        subClassID = subClassID or instantSubClassID
    end
    return {
        name = itemName,
        quality = itemQuality,
        itemLevel = itemLevel,
        itemTypeName = itemTypeName,
        subTypeName = subTypeName,
        equipLoc = equipLoc,
        iconFileID = iconFileID,
        sellPrice = sellPrice,
        classID = classID,
        subClassID = subClassID,
        itemLink = itemLink,
        itemID = itemID,
    }
end

local function ItemMatchesSearch(item, searchText)
    if not searchText or searchText == "" then
        return true
    end
    if not item then
        return false
    end
    local needle = searchText:lower()
    local name = item.name or (item.itemLink and GetItemInfo and GetItemInfo(item.itemLink))
    if name and name:lower():find(needle, 1, true) then
        return true
    end
    if item.itemLink and item.itemLink:lower():find(needle, 1, true) then
        return true
    end
    return item.itemID and tostring(item.itemID):find(needle, 1, true) or false
end

local function ApplyButtonStyle(button)
    if ns.ItemButtonStyle and ns.ItemButtonStyle.Apply then
        ns.ItemButtonStyle.Apply(button)
    end
end

local function SetStyleBorder(button, r, g, b, a)
    if button and button.StyleBorder then
        button.StyleBorderBaseR = r
        button.StyleBorderBaseG = g
        button.StyleBorderBaseB = b
        button.StyleBorderBaseA = a
        button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
    end
end

local function ApplyRailBackdrop(rail)
    if not rail or not rail.SetBackdrop then
        return
    end
    rail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    rail:SetBackdropColor(0.08, 0.08, 0.08, 0.84)
    rail:SetBackdropBorderColor(0.24, 0.24, 0.24, 0.95)
end

local function ConfigureRailButton(button, label, icon, selected)
    button:SetText("")
    button:SetSize(34, 34)
    ApplyButtonStyle(button)
    if not button.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    end
    if not button.Count then
        button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    end
    button.icon:SetTexture(icon)
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.icon:SetVertexColor(1, 1, 1, 1)
    if button.icon.SetDesaturated then
        button.icon:SetDesaturated(false)
    end
    button.Count:SetText("")
    button.tooltipText = label
    button:SetAlpha(selected and 1 or 0.68)
    if selected then
        SetStyleBorder(button, 0.78, 0.66, 0.26, 1)
    else
        SetStyleBorder(button, 0.34, 0.34, 0.34, 0.95)
    end
end

local function SetRailButtonScripts(button, onClick)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        if btn.UpdateTooltip then
            btn:UpdateTooltip()
        else
            GameTooltip:SetText(btn.tooltipText or "")
            GameTooltip:Show()
        end
        if btn.StyleBorder then
            local r = btn.StyleBorderBaseR or 0.34
            local g = btn.StyleBorderBaseG or 0.34
            local b = btn.StyleBorderBaseB or 0.34
            btn.StyleBorder:SetBackdropBorderColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, b + 0.12), 1)
        end
    end)
    button:SetScript("OnLeave", function(btn)
        GameTooltip:Hide()
        SetStyleBorder(btn, btn.StyleBorderBaseR or 0.34, btn.StyleBorderBaseG or 0.34, btn.StyleBorderBaseB or 0.34, btn.StyleBorderBaseA or 0.95)
    end)
end

local function ConfigureActionButton(button, label, icon, onClick)
    button:SetText("")
    button:SetSize(22, 22)
    button:SetNormalTexture(icon)
    button:SetPushedTexture(icon)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.tooltipText = label
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(btn.tooltipText or "")
        if btn.UpdateTooltip then
            btn:UpdateTooltip()
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

CreateEditorInput = function(parent, name, multiLine)
    local editBox
    if multiLine then
        editBox = CreateFrame("EditBox", name, parent, "BackdropTemplate")
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        editBox:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
        editBox:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(6, 6, 6, 6)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    else
        editBox = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    return editBox
end

local function SaveCurrentGuildBankTabInfo()
    local frame = OneGuildBank.frame
    local editor = frame and frame.DetailPanel and frame.DetailPanel.InfoEditor
    if not editor then
        return
    end
    local tab = GetCurrentTab()
    local name = strtrim(editor.NameEdit:GetText() or "")
    local note = editor.NoteEdit:GetText() or ""
    local currentIcon = nil
    if GetGuildBankTabInfo then
        local _
        _, currentIcon = GetGuildBankTabInfo(tab)
    end

    if SetGuildBankTabInfo and name ~= "" then
        SetGuildBankTabInfo(tab, name, currentIcon)
    end
    if SetGuildBankText then
        SetGuildBankText(tab, note)
    end
    if QueryGuildBankText then
        QueryGuildBankText(tab)
    end
    RefreshGuildBankTabInfoSoon()
end

local function UpdateButtonStyleBorder(button, item)
    if ns.ItemButtonStyle and ns.ItemButtonStyle.UpdateBorderForItem then
        ns.ItemButtonStyle.UpdateBorderForItem(button, item, true)
    end
end

local function SetButtonItem(button, item, locked)
    if item then
        if SetItemButtonTexture then SetItemButtonTexture(button, item.iconFileID) elseif button.icon then button.icon:SetTexture(item.iconFileID) end
        if SetItemButtonCount then SetItemButtonCount(button, item.stackCount or 0) elseif button.count then button.count:SetText((item.stackCount or 0) > 1 and item.stackCount or "") end
        if SetItemButtonQuality then SetItemButtonQuality(button, item.quality, item.itemLink) end
    else
        if SetItemButtonTexture then SetItemButtonTexture(button, nil) elseif button.icon then button.icon:SetTexture(nil) end
        if SetItemButtonCount then SetItemButtonCount(button, 0) elseif button.count then button.count:SetText("") end
        if SetItemButtonQuality then SetItemButtonQuality(button, nil) end
    end
    if SetItemButtonDesaturated then
        SetItemButtonDesaturated(button, locked == true)
    elseif button.icon and button.icon.SetDesaturated then
        button.icon:SetDesaturated(locked == true)
    end
    if item then
        item.isLocked = locked == true
    end
    UpdateButtonStyleBorder(button, item)
end

local function ResetButtonVisualState(button, hasItem)
    if not button then
        return
    end
    button:SetButtonState("NORMAL")
    if button.SetChecked then
        button:SetChecked(false)
    end
    if button.PushedTexture then
        button.PushedTexture:Hide()
    end
    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetAlpha(hasItem and 1 or 0)
        pushed:Hide()
    end
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetAlpha(hasItem and 1 or 0)
    end
    if button.searchOverlay then
        button.searchOverlay:SetShown(false)
    end
end

local function ShowGuildBankTooltip(button)
    local tab = button.guildBankTab or GetCurrentTab()
    local slot = button.guildBankSlot or button:GetID()
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tab)
    end
    if GameTooltip and GameTooltip.SetGuildBankItem then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetGuildBankItem(tab, slot)
        GameTooltip:Show()
        return true
    end
    return false
end

local function GuildBankItemOnEnter(button)
    if not button.itemData then
        ResetButtonVisualState(button, false)
        return
    end
    ShowGuildBankTooltip(button)
end

local function InsertItemLink(link)
    if not link then
        return false
    end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
        return true
    end
    return false
end

local function DressUpItem(link)
    if not link then
        return false
    end
    if DressUpItemLink then
        DressUpItemLink(link)
        return true
    end
    return false
end

local function SplitGuildBankStack(button)
    local item = button.itemData
    local count = item and tonumber(item.stackCount) or 0
    if count <= 1 or item.isLocked or (CursorHasItem and CursorHasItem()) or not SplitGuildBankItem then
        return false
    end
    button.SplitStack = function(splitButton, amount)
        if amount and amount > 0 and SplitGuildBankItem then
            local tab = splitButton.guildBankTab or GetCurrentTab()
            if SetCurrentGuildBankTab then
                SetCurrentGuildBankTab(tab)
            end
            SplitGuildBankItem(tab, splitButton.guildBankSlot or splitButton:GetID(), amount)
        end
    end
    if OpenStackSplitFrame then
        OpenStackSplitFrame(count, button, "BOTTOMLEFT", "TOPLEFT")
    elseif StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
        StackSplitFrame:OpenStackSplitFrame(count, button, "BOTTOMLEFT", "TOPLEFT")
    else
        return false
    end
    return true
end

local function PickupGuildBankSlot(button)
    if not PickupGuildBankItem then
        return
    end
    local tab = button.guildBankTab or GetCurrentTab()
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tab)
    end
    PickupGuildBankItem(tab, button.guildBankSlot or button:GetID())
end

local function FormatRecentTime(year, month, day, hour)
    if RecentTimeDate then
        return RecentTimeDate(year, month, day, hour)
    end
    local parts = {}
    if year and year > 0 then parts[#parts + 1] = string.format("%dy", year) end
    if month and month > 0 then parts[#parts + 1] = string.format("%dmo", month) end
    if day and day > 0 then parts[#parts + 1] = string.format("%dd", day) end
    if hour and hour > 0 then parts[#parts + 1] = string.format("%dh", hour) end
    return #parts > 0 and table.concat(parts, " ") or ""
end

local function FormatLogSuffix(year, month, day, hour)
    local recent = FormatRecentTime(year, month, day, hour)
    if recent == "" then
        return ""
    end
    if GUILD_BANK_LOG_TIME then
        return "  |cff009999" .. string.format(GUILD_BANK_LOG_TIME, recent) .. "|r"
    end
    return "  |cff009999" .. recent .. "|r"
end

local function CopperText(amount)
    if GetDenominationsFromCopper then
        return GetDenominationsFromCopper(amount or 0)
    end
    return MoneyToString(amount or 0)
end

local function SetDetailContent(panel, mode, text)
    if not panel then
        return
    end
    local isLog = mode == "log" or mode == "moneylog"
    local isInfo = mode == "info"
    if panel.Text then
        panel.Text:SetShown((not isLog) and (not isInfo))
        if (not isLog) and (not isInfo) then
            panel.Text:SetText(text or "")
        end
    end
    if panel.Log then
        panel.Log:SetShown(isLog)
        panel.Log:Clear()
        if isLog and text and text ~= "" then
            for line in string.gmatch(text, "[^\n]+") do
                panel.Log:AddMessage(line)
            end
            panel.Log:ScrollToBottom()
        end
    end
    if panel.InfoEditor then
        panel.InfoEditor:SetShown(isInfo)
        if isInfo then
            local tab = GetCurrentTab()
            local name, icon = nil, nil
            if GetGuildBankTabInfo then
                name, icon = GetGuildBankTabInfo(tab)
            end
            local note = GetGuildBankText and GetGuildBankText(tab) or ""
            if note == "" and QueryGuildBankText then
                QueryGuildBankText(tab)
            end
            if not panel.InfoEditor.NameEdit:HasFocus() then
                panel.InfoEditor.NameEdit:SetText(name or "")
            end
            if not panel.InfoEditor.NoteEdit:HasFocus() then
                panel.InfoEditor.NoteEdit:SetText(note or "")
            end
        end
    end
end

local function GuildBankItemOnClick(button, mouseButton)
    local item = button.itemData
    if item and HandleModifiedItemClick and HandleModifiedItemClick(item.itemLink) then
        ResetButtonVisualState(button, true)
        return
    elseif item and IsModifiedClick then
        if IsModifiedClick("CHATLINK") and InsertItemLink(item.itemLink) then
            ResetButtonVisualState(button, true)
            return
        elseif IsModifiedClick("SPLITSTACK") and SplitGuildBankStack(button) then
            ResetButtonVisualState(button, true)
            return
        end
    end

    local cursorType, amount
    if GetCursorInfo then
        cursorType, amount = GetCursorInfo()
    end
    if cursorType == "money" and amount and DepositGuildBankMoney then
        DepositGuildBankMoney(amount)
        if ClearCursor then ClearCursor() end
    elseif cursorType == "guildbankmoney" then
        if DropCursorMoney then DropCursorMoney() end
        if ClearCursor then ClearCursor() end
    elseif mouseButton == "RightButton" and item and AutoStoreGuildBankItem then
        local tab = button.guildBankTab or GetCurrentTab()
        if SetCurrentGuildBankTab then
            SetCurrentGuildBankTab(tab)
        end
        AutoStoreGuildBankItem(tab, button.guildBankSlot or button:GetID())
    elseif item or cursorType then
        PickupGuildBankSlot(button)
    end
    ResetButtonVisualState(button, item ~= nil)
end

local function GuildBankItemOnUpdate(button, elapsed)
    if not button.itemData then
        ResetButtonVisualState(button, false)
    end
end

local function CreateGuildBankItemButton(name, parent)
    EnsureGuildBankUILoaded()
    local templates = {
        "GuildBankItemButtonTemplate",
        "LunaBagsGuildBankItemButtonTemplate",
        "ContainerFrameItemButtonTemplate",
    }
    for _, template in ipairs(templates) do
        local ok, button = pcall(CreateFrame, "ItemButton", name, parent, template)
        if ok and button then
            button.LunaBagsTemplate = template
            return button
        end
    end
    return CreateFrame("ItemButton", name, parent)
end

local function GetDefaultSlotPosition(slot)
    local zero = math.max(0, (tonumber(slot) or 1) - 1)
    local groupSize = DEFAULT_GROUP_ROWS * DEFAULT_GROUP_COLUMNS
    local group = math.floor(zero / groupSize)
    local offset = zero % groupSize
    local column = group * DEFAULT_GROUP_COLUMNS + math.floor(offset / DEFAULT_GROUP_ROWS)
    local row = offset % DEFAULT_GROUP_ROWS
    return column, row
end

local function GetDefaultSlotIDs(slot)
    local column, row = GetDefaultSlotPosition(slot)
    return column + 1, row + 1
end

local function PositionPopupNearFrame()
    if GuildBankPopupFrame and OneGuildBank.frame then
        GuildBankPopupFrame:ClearAllPoints()
        GuildBankPopupFrame:SetPoint("TOPLEFT", OneGuildBank.frame, "TOPRIGHT", -4, -30)
        GuildBankPopupFrame:SetFrameStrata("DIALOG")
        GuildBankPopupFrame:SetFrameLevel(FRAME_LEVEL + 80)
        if GuildBankPopupFrame.SetToplevel then
            GuildBankPopupFrame:SetToplevel(true)
        end
    end
end

local function ShowGuildBankTabPopup(tab)
    EnsureGuildBankUILoaded()
    EnsureGuildBankPopupHooks()
    if not GuildBankPopupFrame or not CanEditGuildBankTabInfo or not CanEditGuildBankTabInfo(tab) then
        return false
    end
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tab)
    end
    OneGuildBank.selectedTab = tab
    GuildBankPopupFrame:Show()
    if GuildBankPopupFrame.Update then
        GuildBankPopupFrame:Update()
    end
    PositionPopupNearFrame()
    return true
end

local function CanShowBuyGuildBankTab()
    if not BuyGuildBankTab then
        return false
    end
    local numTabs = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
    local maxTabs = MAX_GUILDBANK_TABS or MAX_BUY_GUILDBANK_TABS or numTabs
    local maxBuyTabs = MAX_BUY_GUILDBANK_TABS or maxTabs
    return (numTabs + 1) <= maxBuyTabs
end

RefreshGuildBankActionButtons = function(frame)
    if not frame then
        return
    end
    if frame.DepositButton then
        frame.DepositButton:Hide()
    end
    if frame.WithdrawButton then
        frame.WithdrawButton:Hide()
    end
    if frame.BuyTabButton then
        frame.BuyTabButton:Hide()
    end
end

function OneGuildBank:CreateFrame()
    if self.frame then
        return
    end

    EnsureGuildBankUILoaded()
    EnsureGuildBankMoneyHooks()
    EnsureGuildBankPopupHooks()

    local frame = _G.LunaBagsOneGuildBankFrame
    if not frame then
        frame = CreateFrame("Frame", "LunaBagsOneGuildBankFrame", UIParent, "BackdropTemplate")
        frame:SetSize(520, 500)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:Hide()
        frame.Content = CreateFrame("Frame", nil, frame)
        frame.Content:SetPoint("TOPLEFT", CONTENT_INSET_X, -62)
        frame.Content:SetPoint("BOTTOMRIGHT", -CONTENT_INSET_X, CONTENT_BOTTOM_INSET)
    end

    ApplyGuildBankFrameLayering(frame)
    RegisterSpecialFrame(frame)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not GetConfig().locked then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        OneGuildBank:SavePosition()
    end)
    frame:SetScript("OnHide", function()
        if frame.SearchBox then
            frame.SearchBox:ClearFocus()
        end
        if OneGuildBank.moneyDialog then
            OneGuildBank.moneyDialog:Hide()
        end
        if GuildBankPopupFrame then
            GuildBankPopupFrame:Hide()
        end
        if not OneGuildBank._closingGuildBankFrame and CloseGuildBankFrame then
            OneGuildBank._closingGuildBankFrame = true
            CloseGuildBankFrame()
            OneGuildBank._closingGuildBankFrame = nil
        end
    end)

    if not frame.WindowBg then
        frame.WindowBg = frame:CreateTexture(nil, "BACKGROUND")
        frame.WindowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.WindowBg:SetAllPoints(frame)
    end
    if not frame.TitleBarBg then
        frame.TitleBarBg = frame:CreateTexture(nil, "ARTWORK")
        frame.TitleBarBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.TitleBarBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TitleBarBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TitleBarBg:SetHeight(28)
    end
    if not frame.HeaderDrag then
        frame.HeaderDrag = CreateFrame("Frame", nil, frame)
        frame.HeaderDrag:EnableMouse(true)
        frame.HeaderDrag:RegisterForDrag("LeftButton")
        frame.HeaderDrag:SetScript("OnDragStart", function()
            if OneGuildBank.frame and OneGuildBank.frame:IsMovable() then
                OneGuildBank.frame:StartMoving()
            end
        end)
        frame.HeaderDrag:SetScript("OnDragStop", function()
            if OneGuildBank.frame then
                OneGuildBank.frame:StopMovingOrSizing()
                OneGuildBank:SavePosition()
            end
        end)
    end
    frame.HeaderDrag:ClearAllPoints()
    frame.HeaderDrag:SetPoint("TOPLEFT", frame.TitleBarBg, "TOPLEFT", 0, 0)
    frame.HeaderDrag:SetPoint("BOTTOMRIGHT", frame.TitleBarBg, "BOTTOMRIGHT", 0, 0)
    frame.HeaderDrag:SetFrameLevel(FRAME_LEVEL + 8)
    if not frame.DarkInset then
        frame.DarkInset = frame:CreateTexture(nil, "BORDER")
        frame.DarkInset:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.DarkInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
        frame.DarkInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 38)
    end
    if not frame.StatusBg then
        frame.StatusBg = frame:CreateTexture(nil, "ARTWORK")
        frame.StatusBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.StatusBg:SetPoint("TOPLEFT", frame.DarkInset, "BOTTOMLEFT", 0, 0)
        frame.StatusBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    if not frame.OuterBorder then
        frame.OuterBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.OuterBorder:SetAllPoints(frame)
        frame.OuterBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    end
    frame.OuterBorder:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)

    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 2)
    frame.CloseButton:SetScript("OnClick", LunaBagsOneGuildBank_Close)

    if not frame.TitleTextCustom then
        frame.TitleTextCustom = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.TitleTextCustom:SetPoint("CENTER", frame.TitleBarBg, "CENTER", 0, 0)
    end
    frame.TitleTextCustom:SetText(GUILD_BANK or "Guild Bank")

    if frame.Header then
        frame.Header:Hide()
    end
    frame.Content = frame.Content or frame.content or CreateFrame("Frame", nil, frame)
    frame.Content:ClearAllPoints()
    frame.Content:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_INSET_X, self.searchVisible and -63 or -48)
    frame.Content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTENT_INSET_X, CONTENT_BOTTOM_INSET)
    frame.Content:SetID(GetCurrentTab())

    if ns.WindowChrome and ns.WindowChrome.EnsureStatusBar then
        ns.WindowChrome.EnsureStatusBar(frame, "MoneyBar")
    end
    if frame.MoneyBar then
        frame.MoneyBar:ClearAllPoints()
        frame.MoneyBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
        frame.MoneyBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
        frame.MoneyBar:SetHeight(28)
        if frame.MoneyBar.SetStatusBarColor then
            frame.MoneyBar:SetMinMaxValues(0, 1)
            frame.MoneyBar:SetValue(0)
            frame.MoneyBar:SetStatusBarColor(0, 0, 0, 0)
        end
        if frame.MoneyBar.GetStatusBarTexture then
            local tex = frame.MoneyBar:GetStatusBarTexture()
            if tex then tex:SetAlpha(0) end
        end
        if frame.MoneyBar.Label then
            frame.MoneyBar.Label:SetFontObject("GameFontNormal")
            frame.MoneyBar.Label:SetTextColor(1, 1, 1, 1)
            frame.MoneyBar.Label:SetText(GUILDBANK_FUNDS or "Guild Funds")
        end
        if frame.MoneyBar.Text then
            frame.MoneyBar.Text:SetFontObject("GameFontNormal")
            frame.MoneyBar.Text:SetTextColor(1, 1, 1, 1)
        end
        frame.MoneyBar:EnableMouse(true)
        frame.MoneyBar:SetScript("OnEnter", function(bar)
            GameTooltip:SetOwner(bar, "ANCHOR_RIGHT")
            GameTooltip:SetText(GUILDBANK_FUNDS or "Guild Funds")
            if DepositGuildBankMoney then
                GameTooltip:AddLine((LEFT_CLICK or "Left-click") .. ": " .. (DEPOSIT or "Deposit"), 0.85, 0.85, 0.85)
            end
            local allowed = GetGuildBankWithdrawLimit()
            if allowed > 0 then
                GameTooltip:AddLine((RIGHT_CLICK or "Right-click") .. ": " .. (WITHDRAW or "Withdraw") .. " " .. MoneyToString(allowed), 0.85, 0.85, 0.85)
            end
            GameTooltip:Show()
        end)
        frame.MoneyBar:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.MoneyBar:SetScript("OnMouseUp", function(_, mouseButton)
            local cursorMoney = GetCursorMoney and GetCursorMoney() or 0
            if cursorMoney > 0 and DepositGuildBankMoney then
                DepositGuildBankMoney(cursorMoney)
                if DropCursorMoney then DropCursorMoney() end
                if ClearCursor then ClearCursor() end
                RefreshGuildBankMoneySoon()
                return
            end
            if mouseButton == "RightButton" and GetGuildBankWithdrawLimit() > 0 then
                ShowGuildBankMoneyPopup("withdraw")
            elseif mouseButton == "LeftButton" and DepositGuildBankMoney then
                ShowGuildBankMoneyPopup("deposit")
            end
        end)
    end

    RefreshGuildBankActionButtons(frame)

    if not frame.TopRail then
        frame.TopRail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    frame.TopRail:ClearAllPoints()
    frame.TopRail:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    ApplyRailBackdrop(frame.TopRail)

    if not frame.SearchBox then
        frame.SearchBox = CreateFrame("EditBox", "LunaBagsGuildBankSearchEditBox", frame, "InputBoxTemplate")
        frame.SearchBox:SetAutoFocus(false)
        frame.SearchBox:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
        frame.SearchBox:SetScript("OnEnterPressed", function(editBox) editBox:ClearFocus() end)
        frame.SearchBox:SetScript("OnTextChanged", LunaBagsOneGuildBank_SearchChanged)
    end
    if ns.WindowChrome and ns.WindowChrome.EnsureSearchPanel then
        ns.WindowChrome.EnsureSearchPanel(frame)
    elseif not frame.SearchPanel then
        frame.SearchPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.SearchPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame.SearchPanel:SetBackdropBorderColor(0.26, 0.26, 0.26, 0.95)
        frame.SearchPanel:ClearAllPoints()
        frame.SearchPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
        frame.SearchPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -29)
        frame.SearchPanel:SetHeight(28)
    end
    frame.SearchPanel:SetShown(self.searchVisible == true)
    frame.SearchBox:SetParent(frame.SearchPanel)
    frame.SearchBox:ClearAllPoints()
    frame.SearchBox:SetPoint("TOPLEFT", frame.SearchPanel, "TOPLEFT", 8, -4)
    frame.SearchBox:SetPoint("BOTTOMRIGHT", frame.SearchPanel, "BOTTOMRIGHT", -8, 4)
    frame.SearchBox:SetTextInsets(0, 0, 0, 0)
    frame.SearchBox:SetFontObject("GameFontHighlightSmall")
    frame.SearchBox:SetText(self.searchText or "")
    frame.SearchBox:Show()
    if frame.SearchBox.Left then frame.SearchBox.Left:Hide() end
    if frame.SearchBox.Middle then frame.SearchBox.Middle:Hide() end
    if frame.SearchBox.Right then frame.SearchBox.Right:Hide() end

    if not frame.GuildButton then
        frame.GuildButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.GuildButton.Icon = frame.GuildButton:CreateTexture(nil, "ARTWORK")
        frame.GuildButton.Icon:SetPoint("TOPLEFT", frame.GuildButton, "TOPLEFT", 0, 0)
        frame.GuildButton.Icon:SetPoint("BOTTOMRIGHT", frame.GuildButton, "BOTTOMRIGHT", 0, 0)
    end
    frame.GuildButton:SetText("")
    frame.GuildButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.GuildButton:SetSize(18, 18)
    frame.GuildButton:ClearAllPoints()
    frame.GuildButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 5, 0)
    frame.GuildButton.Icon:SetTexture("Interface\\Icons\\INV_Misc_TabardPVP_01")
    frame.GuildButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(GUILD_BANK or "Guild Bank")
        GameTooltip:Show()
    end)
    frame.GuildButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not frame.SearchToggleButton then
        frame.SearchToggleButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.SearchToggleButton:SetText("")
    frame.SearchToggleButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    frame.SearchToggleButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    frame.SearchToggleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.SearchToggleButton:SetSize(18, 18)
    frame.SearchToggleButton:ClearAllPoints()
    frame.SearchToggleButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 27, 0)
    frame.SearchToggleButton:SetScript("OnClick", LunaBagsOneGuildBank_SearchToggleClicked)
    frame.SearchToggleButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Search")
        GameTooltip:Show()
    end)
    frame.SearchToggleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not frame.SettingsButton then
        frame.SettingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    end
    frame.SettingsButton:SetText("")
    frame.SettingsButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    frame.SettingsButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    frame.SettingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    frame.SettingsButton:SetSize(18, 18)
    frame.SettingsButton:ClearAllPoints()
    frame.SettingsButton:SetPoint("LEFT", frame.TitleBarBg, "LEFT", 49, 0)
    frame.SettingsButton:SetScript("OnClick", function()
        if ns.OpenConfig then ns.OpenConfig() end
    end)
    frame.SettingsButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(SETTINGS or "Settings")
        GameTooltip:Show()
    end)
    frame.SettingsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not frame.BottomRail then
        frame.BottomRail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    frame.BottomRail:ClearAllPoints()
    frame.BottomRail:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
    ApplyRailBackdrop(frame.BottomRail)
    if not frame.DetailPanel then
        frame.DetailPanel = CreateFrame("Frame", nil, frame)
        frame.DetailPanel:SetPoint("TOPLEFT", frame.Content, "TOPLEFT", 0, 0)
        frame.DetailPanel:SetPoint("BOTTOMRIGHT", frame.Content, "BOTTOMRIGHT", 0, 0)
        frame.DetailPanel.Text = frame.DetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.DetailPanel.Text:SetPoint("TOPLEFT", frame.DetailPanel, "TOPLEFT", 4, -4)
        frame.DetailPanel.Text:SetPoint("BOTTOMRIGHT", frame.DetailPanel, "BOTTOMRIGHT", -4, 4)
        frame.DetailPanel.Text:SetJustifyH("LEFT")
        frame.DetailPanel.Text:SetJustifyV("TOP")
        frame.DetailPanel.Log = CreateFrame("ScrollingMessageFrame", nil, frame.DetailPanel)
        frame.DetailPanel.Log:SetPoint("TOPLEFT", frame.DetailPanel, "TOPLEFT", 4, -4)
        frame.DetailPanel.Log:SetPoint("BOTTOMRIGHT", frame.DetailPanel, "BOTTOMRIGHT", -4, 4)
        frame.DetailPanel.Log:SetFontObject(GameFontHighlight)
        frame.DetailPanel.Log:SetJustifyH("LEFT")
        frame.DetailPanel.Log:SetFading(false)
        frame.DetailPanel.Log:SetMaxLines(100)
        frame.DetailPanel.Log:EnableMouse(true)
        frame.DetailPanel.Log:SetScript("OnMouseWheel", function(log, delta)
            if delta > 0 then
                log:ScrollUp()
            else
                log:ScrollDown()
            end
        end)
        frame.DetailPanel.Log:SetScript("OnHyperlinkClick", function(_, ...)
            if SetItemRef then SetItemRef(...) end
        end)
        if frame.DetailPanel.Log.SetHyperlinksEnabled then
            frame.DetailPanel.Log:SetHyperlinksEnabled(true)
        end
        frame.DetailPanel.InfoEditor = CreateFrame("Frame", nil, frame.DetailPanel)
        frame.DetailPanel.InfoEditor:SetPoint("TOPLEFT", frame.DetailPanel, "TOPLEFT", 4, -4)
        frame.DetailPanel.InfoEditor:SetPoint("BOTTOMRIGHT", frame.DetailPanel, "BOTTOMRIGHT", -4, 4)

        frame.DetailPanel.InfoEditor.NameLabel = CreateLabel(frame.DetailPanel.InfoEditor, NAME or "Name")
        frame.DetailPanel.InfoEditor.NameLabel:SetPoint("TOPLEFT", frame.DetailPanel.InfoEditor, "TOPLEFT", 0, 0)
        frame.DetailPanel.InfoEditor.NameEdit = CreateEditorInput(frame.DetailPanel.InfoEditor, "LunaBagsGuildBankTabNameEdit", false)
        frame.DetailPanel.InfoEditor.NameEdit:SetPoint("TOPLEFT", frame.DetailPanel.InfoEditor.NameLabel, "BOTTOMLEFT", 0, -4)
        frame.DetailPanel.InfoEditor.NameEdit:SetPoint("RIGHT", frame.DetailPanel.InfoEditor, "RIGHT", 0, 0)
        frame.DetailPanel.InfoEditor.NameEdit:SetHeight(22)

        frame.DetailPanel.InfoEditor.IconLabel = CreateLabel(frame.DetailPanel.InfoEditor, EMBLEM_SYMBOL or "Icon")
        frame.DetailPanel.InfoEditor.IconLabel:SetPoint("LEFT", frame.DetailPanel.InfoEditor.NameEdit, "RIGHT", 10, 0)
        frame.DetailPanel.InfoEditor.IconLabel:SetPoint("TOP", frame.DetailPanel.InfoEditor.NameLabel, "TOP", 0, 0)
        frame.DetailPanel.InfoEditor.IconEdit = CreateEditorInput(frame.DetailPanel.InfoEditor, "LunaBagsGuildBankTabIconEdit", false)
        frame.DetailPanel.InfoEditor.IconEdit:SetPoint("TOPLEFT", frame.DetailPanel.InfoEditor.IconLabel, "BOTTOMLEFT", 0, -4)
        frame.DetailPanel.InfoEditor.IconEdit:SetPoint("RIGHT", frame.DetailPanel.InfoEditor, "RIGHT", 0, 0)
        frame.DetailPanel.InfoEditor.IconEdit:SetHeight(22)
        frame.DetailPanel.InfoEditor.IconLabel:Hide()
        frame.DetailPanel.InfoEditor.IconEdit:Hide()

        frame.DetailPanel.InfoEditor.NoteLabel = CreateLabel(frame.DetailPanel.InfoEditor, GUILD_BANK_TAB_INFO or INFO or "Info")
        frame.DetailPanel.InfoEditor.NoteLabel:SetPoint("TOPLEFT", frame.DetailPanel.InfoEditor.NameEdit, "BOTTOMLEFT", 0, -12)
        frame.DetailPanel.InfoEditor.NoteEdit = CreateEditorInput(frame.DetailPanel.InfoEditor, "LunaBagsGuildBankTabNoteEdit", true)
        frame.DetailPanel.InfoEditor.NoteEdit:SetPoint("TOPLEFT", frame.DetailPanel.InfoEditor.NoteLabel, "BOTTOMLEFT", 0, -4)
        frame.DetailPanel.InfoEditor.NoteEdit:SetPoint("RIGHT", frame.DetailPanel.InfoEditor, "RIGHT", 0, 0)
        frame.DetailPanel.InfoEditor.NoteEdit:SetHeight(118)

        frame.DetailPanel.InfoEditor.SaveButton = CreateFrame("Button", nil, frame.DetailPanel.InfoEditor, "UIPanelButtonTemplate")
        frame.DetailPanel.InfoEditor.SaveButton:SetText(SAVE or "Save")
        frame.DetailPanel.InfoEditor.SaveButton:SetSize(82, 22)
        frame.DetailPanel.InfoEditor.SaveButton:SetPoint("TOPRIGHT", frame.DetailPanel.InfoEditor.NoteEdit, "BOTTOMRIGHT", 0, -8)
        frame.DetailPanel.InfoEditor.SaveButton:SetScript("OnClick", SaveCurrentGuildBankTabInfo)
    end

    ApplyGuildBankFrameLayering(frame)
    ApplyWindowAppearance(frame, GetConfig())
    self.frame = frame
    self:ApplySettings()
end

function OneGuildBank:AcquireTabButton(index)
    local button = self.tabButtons[index]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, self.frame.TopRail, "BackdropTemplate")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    SetRailButtonScripts(button, function(btn, mouseButton)
        if btn.canPurchase then
            ConfirmBuyGuildBankTab()
            return
        end
        if mouseButton == "RightButton" and btn.tab and ShowGuildBankTabPopup(btn.tab) then
            OneGuildBank:RefreshTabs()
            return
        end
        if btn.viewable ~= false then
            SelectTab(btn.tab)
        end
    end)
    button.UpdateTooltip = function(btn)
        if btn.canPurchase then
            GameTooltip:SetText(BUY_GUILDBANK_TAB or "Buy Guild Bank Tab", 1, 1, 1)
            if GetGuildBankTabCost and GetMoneyString then
                GameTooltip:AddLine(GetMoneyString(GetGuildBankTabCost(), true))
            end
            GameTooltip:Show()
            return
        end

        GameTooltip:SetText(btn.tooltipText or tostring(btn.tab), 1, 1, 1)
        if btn.tab and GetGuildBankText then
            local text = strtrim(GetGuildBankText(btn.tab) or "")
            if text ~= "" then
                GameTooltip:AddLine("\"" .. text .. "\"", nil, nil, nil, true)
            elseif QueryGuildBankText then
                QueryGuildBankText(btn.tab)
            end
        end
        if btn.permissionText then
            if btn.remainingText then
                GameTooltip:AddDoubleLine(btn.permissionText, btn.remainingText, 1, 1, 1, 1, 1, 1)
            else
                GameTooltip:AddLine(btn.permissionText)
            end
        end
        GameTooltip:Show()
    end
    self.tabButtons[index] = button
    return button
end

function OneGuildBank:AcquireModeButton(index)
    self.modeButtons = self.modeButtons or {}
    local button = self.modeButtons[index]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, self.frame.BottomRail, "BackdropTemplate")
    SetRailButtonScripts(button, function(btn)
        OneGuildBank.mode = btn.modeKey or "bank"
        if OneGuildBank.mode == "log" and QueryGuildBankLog then
            QueryGuildBankLog(GetCurrentTab())
        elseif OneGuildBank.mode == "moneylog" and QueryGuildBankLog then
            QueryGuildBankLog(MAX_GUILDBANK_TABS and (MAX_GUILDBANK_TABS + 1) or 9)
        elseif OneGuildBank.mode == "info" and QueryGuildBankText then
            QueryGuildBankText(GetCurrentTab())
        end
        OneGuildBank:RefreshDeferred()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function() OneGuildBank:RefreshIfShown() end)
        end
    end)
    self.modeButtons[index] = button
    return button
end

function OneGuildBank:RefreshModeRail()
    if not self.frame or not self.frame.BottomRail then
        return
    end
    local size, spacing, pad = 34, 4, 6
    for index, mode in ipairs(MODE_BUTTONS) do
        local button = self:AcquireModeButton(index)
        button.modeKey = mode.key
        ConfigureRailButton(button, mode.label, mode.icon, self.mode == mode.key)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.BottomRail, "TOPLEFT", pad + (index - 1) * (size + spacing), -pad)
        button:Show()
    end
    self.frame.BottomRail:SetWidth(pad * 2 + #MODE_BUTTONS * size + (#MODE_BUTTONS - 1) * spacing)
    self.frame.BottomRail:SetHeight(size + pad * 2)
    ApplyRailBackdrop(self.frame.BottomRail)
end

function OneGuildBank:BuildDetailText()
    local tab = GetCurrentTab()
    if self.mode == "info" then
        local name = GetGuildBankTabInfo and GetGuildBankTabInfo(tab) or nil
        local text = GetGuildBankText and GetGuildBankText(tab) or ""
        if text == "" and QueryGuildBankText then
            QueryGuildBankText(tab)
        end
        return string.format("%s\n\n%s", name or (BANK_TAB or "Bank Tab"), text ~= "" and text or (NONE or "None"))
    elseif self.mode == "log" then
        if QueryGuildBankLog then
            QueryGuildBankLog(tab)
        end
        local lines = {}
        local count = GetNumGuildBankTransactions and GetNumGuildBankTransactions(tab) or 0
        for index = 1, math.min(count, 25) do
            if GetGuildBankTransaction then
                local transactionType, name, itemLink, itemCount, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, index)
                local displayName = NORMAL_FONT_COLOR_CODE .. (name or UNKNOWN or "") .. FONT_COLOR_CODE_CLOSE
                local msg
                if transactionType == "deposit" and GUILDBANK_DEPOSIT_FORMAT then
                    msg = string.format(GUILDBANK_DEPOSIT_FORMAT, displayName, itemLink or "")
                    if tonumber(itemCount) and itemCount > 1 and GUILDBANK_LOG_QUANTITY then
                        msg = msg .. string.format(GUILDBANK_LOG_QUANTITY, itemCount)
                    end
                elseif transactionType == "withdraw" and GUILDBANK_WITHDRAW_FORMAT then
                    msg = string.format(GUILDBANK_WITHDRAW_FORMAT, displayName, itemLink or "")
                    if tonumber(itemCount) and itemCount > 1 and GUILDBANK_LOG_QUANTITY then
                        msg = msg .. string.format(GUILDBANK_LOG_QUANTITY, itemCount)
                    end
                elseif transactionType == "move" and GUILDBANK_MOVE_FORMAT then
                    msg = string.format(GUILDBANK_MOVE_FORMAT, displayName, itemLink or "", itemCount or 0, GetGuildBankTabInfo(tab1), GetGuildBankTabInfo(tab2))
                else
                    msg = string.format("%s  %s  %s x%s", tostring(transactionType or ""), tostring(displayName or ""), tostring(itemLink or ""), tostring(itemCount or ""))
                end
                lines[#lines + 1] = msg .. FormatLogSuffix(year, month, day, hour)
            end
        end
        return #lines > 0 and table.concat(lines, "\n") or (GUILD_BANK_LOG or "No log entries.")
    elseif self.mode == "moneylog" then
        if QueryGuildBankLog then
            QueryGuildBankLog(MAX_GUILDBANK_TABS and (MAX_GUILDBANK_TABS + 1) or 9)
        end
        local lines = {}
        local count = GetNumGuildBankMoneyTransactions and GetNumGuildBankMoneyTransactions() or 0
        for index = 1, math.min(count, 25) do
            if GetGuildBankMoneyTransaction then
                local transactionType, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(index)
                local displayName = NORMAL_FONT_COLOR_CODE .. (name or UNKNOWN or "") .. FONT_COLOR_CODE_CLOSE
                local money = CopperText(amount or 0)
                local formatString = LOG_TYPES[transactionType]
                local msg
                if transactionType == "buyTab" and amount and amount > 0 and GUILDBANK_BUYTAB_MONEY_FORMAT then
                    msg = string.format(GUILDBANK_BUYTAB_MONEY_FORMAT, displayName, money)
                elseif transactionType == "buyTab" and GUILDBANK_UNLOCKTAB_FORMAT then
                    msg = string.format(GUILDBANK_UNLOCKTAB_FORMAT, displayName)
                elseif transactionType == "depositSummary" and GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT then
                    msg = string.format(GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT, money)
                elseif formatString then
                    msg = string.format(formatString, displayName, money)
                else
                    msg = string.format("%s  %s  %s", tostring(transactionType or ""), displayName, MoneyToString(amount or 0))
                end
                lines[#lines + 1] = msg .. FormatLogSuffix(year, month, day, hour)
            end
        end
        return #lines > 0 and table.concat(lines, "\n") or (GUILD_BANK_MONEY_LOG or "No money log entries.")
    end
    return ""
end

function OneGuildBank:RefreshTabs()
    if not self.frame or not self.frame.TopRail then
        return
    end
    local numTabs = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
    local maxTabs = MAX_GUILDBANK_TABS or numTabs
    local maxBuyTabs = MAX_BUY_GUILDBANK_TABS or maxTabs
    local showPurchase = BuyGuildBankTab and (numTabs + 1) <= maxBuyTabs
    local displayTabs = math.min(maxTabs, numTabs + (showPurchase and 1 or 0))
    local size, spacing, pad = 34, 4, 6
    for tab = 1, displayTabs do
        local isPurchase = tab == numTabs + 1 and showPurchase
        local name, icon, isViewable, canDeposit, withdraw = nil, nil, true, nil, nil
        if isPurchase then
            name = BUY_GUILDBANK_TAB or "Buy Guild Bank Tab"
            icon = 132071
        else
            name, icon, isViewable, canDeposit, withdraw = GetGuildBankTabInfo(tab)
        end
        local button = self:AcquireTabButton(tab)
        button.tab = tab
        button.canPurchase = isPurchase == true
        button.viewable = isViewable
        ConfigureRailButton(button, name or tostring(tab), icon or "Interface\\Icons\\INV_Misc_Bag_08", tab == GetCurrentTab() and not isPurchase)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.TopRail, "TOPLEFT", pad + (tab - 1) * (size + spacing), -pad)
        if not isPurchase and isViewable == false then
            button.icon:SetVertexColor(1, 0.1, 0.1, 1)
            if button.icon.SetDesaturated then
                button.icon:SetDesaturated(true)
            end
            button:SetAlpha(0.8)
        end
        local remaining = nil
        if tab == GetCurrentTab() and not isPurchase and GetGuildBankTabInfo then
            remaining = select(6, GetGuildBankTabInfo(tab))
        end
        if button.Count then
            if not isPurchase and isViewable and remaining ~= nil then
                if remaining < 0 then
                    button.Count:SetText("∞")
                elseif AbbreviateNumbers then
                    button.Count:SetText(AbbreviateNumbers(remaining))
                else
                    button.Count:SetText(tostring(remaining))
                end
            else
                button.Count:SetText("")
            end
        end
        local permission
        if not isPurchase then
            if not isViewable or (not canDeposit and withdraw == 0) then
                permission = GUILDBANK_TAB_LOCKED
            elseif not canDeposit and withdraw and withdraw > 0 then
                permission = GUILDBANK_TAB_WITHDRAW_ONLY
            elseif withdraw == 0 then
                permission = GUILDBANK_TAB_DEPOSIT_ONLY
            elseif withdraw then
                permission = GUILDBANK_TAB_FULL_ACCESS
            end
        end
        button.permissionText = permission and permission:gsub("[%(%)%[%]]", "") or nil
        button.remainingText = remaining and remaining >= 0 and (ITEMS or "Items") .. ": " .. tostring(remaining) or nil
        button:EnableMouse(isPurchase or icon ~= nil)
        button:Show()
    end
    for tab = displayTabs + 1, #self.tabButtons do
        self.tabButtons[tab]:Hide()
    end
    local used = math.max(displayTabs, 1)
    self.frame.TopRail:SetWidth(pad * 2 + used * size + math.max(0, used - 1) * spacing)
    self.frame.TopRail:SetHeight(size + pad * 2)
    self.frame.TopRail:SetShown(displayTabs > 0)
    ApplyRailBackdrop(self.frame.TopRail)
end

function OneGuildBank:AcquireButton(index)
    local button = self.buttons[index]
    if button then
        return button
    end

    local name = "LunaBagsGuildBankItemButton" .. index
    button = CreateGuildBankItemButton(name, self.frame.Content)
    button:SetSize(self.slotSize, self.slotSize)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:EnableMouse(true)
    button:SetScript("OnEnter", GuildBankItemOnEnter)
    button:SetScript("OnLeave", function()
        ResetButtonVisualState(button, button.itemData ~= nil)
        if GameTooltip then GameTooltip:Hide() end
        if ResetCursor then ResetCursor() end
    end)
    button:SetScript("OnClick", GuildBankItemOnClick)
    button:SetScript("OnDragStart", PickupGuildBankSlot)
    button:SetScript("OnReceiveDrag", PickupGuildBankSlot)
    button:SetScript("OnMouseUp", function(btn) ResetButtonVisualState(btn, btn.itemData ~= nil) end)
    button:SetScript("OnUpdate", GuildBankItemOnUpdate)
    button.UpdateTooltip = ShowGuildBankTooltip

    local icon = button.icon or button.Icon or _G[name .. "IconTexture"] or _G[name .. "Icon"]
    if not icon then
        icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    button.icon = icon
    button.Icon = button.Icon or icon

    local count = button.Count or button.count or _G[name .. "Count"]
    if not count then
        count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    button.Count = button.Count or count
    button.count = count

    if not button.DebugSlotText then
        button.DebugSlotText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.DebugSlotText:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.DebugSlotText:SetTextColor(0.95, 0.82, 0.10, 0.95)
    end

    ApplyButtonStyle(button)
    self.buttons[index] = button
    return button
end

function OneGuildBank:BuildSlots()
    local tab = GetCurrentTab()
    local includeFullDetails = self.searchText and self.searchText ~= ""
    local cacheKey = tostring(tab)
    if self._slotCache
        and self._slotCacheDirty ~= true
        and self._slotCacheKey == cacheKey
        and (not includeFullDetails or self._slotCacheFullDetails == true)
    then
        return self._slotCache
    end

    local slots = {}
    if self.frame and self.frame.Content then
        self.frame.Content:SetID(tab)
    end
    for slot = 1, MAX_GUILD_BANK_SLOTS do
        local texture, count, locked, isFiltered, quality = GetGuildBankItemInfo and GetGuildBankItemInfo(tab, slot)
        local itemLink = GetGuildBankItemLink and GetGuildBankItemLink(tab, slot) or nil
        local item = GetItemDetails(itemLink, includeFullDetails)
        if item then
            item.iconFileID = texture or item.iconFileID
            item.stackCount = count or 0
            item.quality = quality or item.quality
            item.isLocked = locked == true or locked == 1
        elseif texture then
            item = {
                iconFileID = texture,
                stackCount = count or 0,
                quality = quality,
                itemLink = itemLink,
                isLocked = locked == true or locked == 1,
            }
        end
        slots[#slots + 1] = {
            tab = tab,
            slot = slot,
            locked = locked == true or locked == 1,
            filtered = isFiltered == true,
            item = item,
        }
    end
    self._slotCache = slots
    self._slotCacheKey = cacheKey
    self._slotCacheFullDetails = includeFullDetails == true
    self._slotCacheDirty = nil
    return slots
end

function OneGuildBank:InvalidateSlotCache()
    self._slotCacheDirty = true
end

function OneGuildBank:RefreshMoneyDisplay()
    RefreshGuildBankMoneyDisplay()
end

function OneGuildBank:Refresh()
    if not self.frame then
        return
    end

    EnsureGuildBankUILoaded()
    PositionPopupNearFrame()
    self:RefreshTabs()
    self:RefreshModeRail()
    if self.frame.SearchPanel then
        self.frame.SearchPanel:SetShown(self.searchVisible == true)
    end
    if self.frame.Content then
        self.frame.Content:ClearAllPoints()
        self.frame.Content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", CONTENT_INSET_X, self.searchVisible and -63 or -48)
        self.frame.Content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -CONTENT_INSET_X, CONTENT_BOTTOM_INSET)
    end

    local cfg = GetConfig()
    local size = self.slotSize
    local spacing = self.spacing
    local cols = FIXED_COLUMNS
    self.columns = cols
    local gridWidth = cols * size + (cols - 1) * spacing
    local frameWidth = gridWidth + FRAME_PADDING_X
    local contentWidth = math.max(gridWidth, frameWidth - FRAME_PADDING_X)
    local gridInsetX = math.max(0, math.floor((contentWidth - gridWidth) * 0.5))
    local slots = self:BuildSlots()
    local searching = self.searchText and self.searchText ~= ""
    local visibleSlots = {}

    for _, info in ipairs(slots) do
        local matches = ItemMatchesSearch(info.item, self.searchText)
        visibleSlots[#visibleSlots + 1] = info
        info.matchesSearch = matches
    end

    self.frame:SetScale(tonumber(cfg.scale) or 1)
    self.frame:SetWidth(frameWidth)
    ApplyWindowAppearance(self.frame, cfg)
    RefreshGuildBankActionButtons(self.frame)

    local bankMode = self.mode == "bank"
    self.frame.Content:SetShown(bankMode)
    if self.frame.DetailPanel then
        self.frame.DetailPanel:SetShown(not bankMode)
        if not bankMode then
            SetDetailContent(self.frame.DetailPanel, self.mode, self:BuildDetailText())
        end
    end

    if not bankMode then
        for index = 1, #self.buttons do
            self.buttons[index]:Hide()
        end
        self.frame:SetHeight(360)
        ApplyWindowAppearance(self.frame, cfg)
        if self.frame.MoneyBar and self.frame.MoneyBar.Text then
            local money = GetGuildBankMoney and GetGuildBankMoney() or 0
            self.frame.MoneyBar.Text:SetText(MoneyToString(money))
        end
        RefreshGuildBankActionButtons(self.frame)
        return
    end

    local used = #visibleSlots
    local maxRow = 0
    for index, info in ipairs(visibleSlots) do
        local button = self:AcquireButton(index)
        local col, row = GetDefaultSlotPosition(info.slot)
        maxRow = math.max(maxRow, row)
        if button:GetParent() ~= self.frame.Content then
            button:SetParent(self.frame.Content)
        end
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame.Content, "TOPLEFT", gridInsetX + col * (size + spacing), -row * (size + spacing))
        local defaultColumn, defaultRow = GetDefaultSlotIDs(info.slot)
        button:SetID(info.slot)
        button.defaultGuildBankColumn = defaultColumn
        button.defaultGuildBankRow = defaultRow
        button.guildBankTab = info.tab
        button.guildBankSlot = info.slot
        button.tab = info.tab
        button.slot = info.slot
        button.itemData = info.item
        local alpha
        if info.item then
            alpha = (searching and not info.matchesSearch) and 0.22 or 1
        else
            alpha = searching and 0.18 or 0.55
        end
        button:SetAlpha(alpha)
        button._baseAlpha = alpha
        SetButtonItem(button, info.item, info.locked)
        ResetButtonVisualState(button, info.item ~= nil)
        if button.DebugSlotText and IsDebugEnabled() then
            button.DebugSlotText:SetText(("%d:%d"):format(info.tab, info.slot))
            button.DebugSlotText:Show()
        elseif button.DebugSlotText then
            button.DebugSlotText:Hide()
        end
        if ns.Plugins then
            ns.Plugins:Apply(button, info, "oneGuildBank")
        end
        button:Show()
    end

    for index = used + 1, #self.buttons do
        self.buttons[index]:Hide()
    end

    local rows = math.max(1, maxRow + 1)
    local contentHeight = rows * size + math.max(0, rows - 1) * spacing
    local contentTopInset = self.searchVisible and 63 or 48
    self.frame:SetHeight(contentHeight + contentTopInset + CONTENT_BOTTOM_INSET + FRAME_BORDER_PADDING_Y)
    ApplyWindowAppearance(self.frame, cfg)

    if self.frame.MoneyBar and self.frame.MoneyBar.Text then
        local money = GetGuildBankMoney and GetGuildBankMoney() or 0
        self.frame.MoneyBar.Text:SetText(MoneyToString(money))
    end
    RefreshGuildBankActionButtons(self.frame)
end

function OneGuildBank:RefreshIfShown()
    if self.frame and self.frame:IsShown() then
        self:RefreshDeferred()
    end
end

function OneGuildBank:RefreshDeferred()
    if not self.frame then
        return
    end
    self._refreshDeferredToken = (self._refreshDeferredToken or 0) + 1
    local token = self._refreshDeferredToken
    local function run()
        if token ~= OneGuildBank._refreshDeferredToken or not OneGuildBank.frame or not OneGuildBank.frame:IsShown() then
            return
        end
        OneGuildBank:Refresh()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

function OneGuildBank:ApplySettings()
    local cfg = GetConfig()
    self.slotSize = math.max(24, tonumber(cfg.itemSize) or 36)
    self.spacing = math.max(0, tonumber(cfg.spacing) or 4)
    self.columns = FIXED_COLUMNS
    if not self.frame then
        return
    end
    self.frame:SetMovable(cfg.locked ~= true)
    self.frame:SetScale(tonumber(cfg.scale) or 1)
    ApplyWindowAppearance(self.frame, cfg)
    ApplyGuildBankFrameLayering(self.frame)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.point or "CENTER", cfg.x or 0, cfg.y or 0)
end

function OneGuildBank:SavePosition()
    if not self.frame then
        return
    end
    local cfg = GetConfig()
    local point, _, _, x, y = self.frame:GetPoint(1)
    cfg.point = point or "CENTER"
    cfg.x = x or 0
    cfg.y = y or 0
end

function OneGuildBank:ResetPosition()
    local cfg = GetConfig()
    cfg.point = "CENTER"
    cfg.x = 0
    cfg.y = 0
    if self.frame then
        self:ApplySettings()
    end
end

function OneGuildBank:Show()
    if ns.LunaBags and ns.LunaBags.IsWindowModuleEnabled and not ns.LunaBags:IsWindowModuleEnabled("oneGuildBank") then
        return
    end
    self:CreateFrame()
    self.selectedTab = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or self.selectedTab or 1
    self.frame:Show()
    PositionPopupNearFrame()
    self:QueryCurrentTab()
    self:RefreshDeferred()
end

function OneGuildBank:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function LunaBagsOneGuildBank_Close()
    if CloseGuildBankFrame then
        OneGuildBank._closingGuildBankFrame = true
        CloseGuildBankFrame()
        OneGuildBank._closingGuildBankFrame = nil
    end
    if ns.OneGuildBank then
        ns.OneGuildBank:Hide()
    end
end

function LunaBagsOneGuildBank_SearchChanged(editBox)
    OneGuildBank.searchText = strtrim(editBox:GetText() or "")
    OneGuildBank:RefreshIfShown()
end

function LunaBagsOneGuildBank_SearchToggleClicked()
    OneGuildBank.searchVisible = not OneGuildBank.searchVisible
    if not OneGuildBank.frame or not OneGuildBank.frame.SearchBox then
        return
    end
    if OneGuildBank.searchVisible then
        OneGuildBank.frame.SearchBox:SetFocus()
    else
        OneGuildBank.frame.SearchBox:ClearFocus()
        OneGuildBank.searchText = ""
        if OneGuildBank.frame.SearchBox:GetText() ~= "" then
            OneGuildBank.frame.SearchBox:SetText("")
        end
    end
    OneGuildBank:RefreshDeferred()
end
