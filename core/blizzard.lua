local name, addon = ...

local LunaBags = addon.LunaBags
local suppressedUIPanelParent

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

function LunaBags:HookBlizzardFrames()
    if self._bankCallHijacked then
        return
    end
    self._bankCallHijacked = true
    if not hooksecurefunc then
        return
    end

    if type(_G.BankFrame_Show) == "function" then
        hooksecurefunc("BankFrame_Show", function()
            if not LunaBags:IsWindowModuleEnabled("oneBank") then
                LunaBags:RestoreDefaultBankFrame()
                return
            end
            LunaBags:SuppressDefaultBankFrame()
            if addon.OneBank then
                addon.OneBank:Show()
            end
        end)
    end
    if type(_G.CloseBankFrame) == "function" then
        hooksecurefunc("CloseBankFrame", function()
            if LunaBags:IsWindowModuleEnabled("oneBank") and addon.OneBank then
                addon.OneBank:Hide()
            end
            if BankFrame then
                BankFrame:SetAlpha(1)
                BankFrame:EnableMouse(true)
            end
        end)
    end
    if type(_G.GuildBankFrame_Show) == "function" then
        hooksecurefunc("GuildBankFrame_Show", function()
            if not LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                LunaBags:RestoreDefaultGuildBankFrame()
                return
            end
            LunaBags:SuppressDefaultGuildBankFrame()
            if addon.OneGuildBank then
                addon.OneGuildBank:Show()
            end
            if addon.BagHooks then
                addon.BagHooks:OpenBags("GuildBankOpen")
            end
        end)
    end
    if type(_G.CloseGuildBankFrame) == "function" then
        hooksecurefunc("CloseGuildBankFrame", function()
            if LunaBags and not LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                LunaBags:RestoreDefaultGuildBankFrame()
                return
            end
            if addon.OneGuildBank then
                addon.OneGuildBank:Hide()
            end
            if addon.BagHooks then
                addon.BagHooks:CloseBags("GuildBankClose")
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
                if not LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                    LunaBags:RestoreDefaultGuildBankFrame()
                    return
                end
                LunaBags:SuppressDefaultGuildBankFrame()
                if addon.OneGuildBank then
                    addon.OneGuildBank:Show()
                end
                if addon.BagHooks then
                    addon.BagHooks:OpenBags("GuildBankOpen")
                end
            end
        end)
    end
    if type(_G.HideUIPanel) == "function" then
        hooksecurefunc("HideUIPanel", function(panel)
            if IsGuildBankPanel(panel) then
                if not LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                    LunaBags:RestoreDefaultGuildBankFrame()
                    return
                end
                if addon.OneGuildBank then
                    addon.OneGuildBank:Hide()
                end
                if addon.BagHooks then
                    addon.BagHooks:CloseBags("GuildBankClose")
                end
            end
        end)
    end
    if type(_G.GuildBankFrame_LoadUI) == "function" then
        hooksecurefunc("GuildBankFrame_LoadUI", function()
            if not LunaBags:IsWindowModuleEnabled("oneGuildBank") then
                LunaBags:RestoreDefaultGuildBankFrame()
                return
            end
            LunaBags:EnsureGuildBankFrameSuppressionHooks()
        end)
    end
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

function LunaBags:BANKFRAME_OPENED()
    if not self:IsWindowModuleEnabled("oneBank") then
        self:RestoreDefaultBankFrame()
        return
    end
    self:SuppressDefaultBankFrame()
    if addon.BagHooks then
        local now = GetTime and GetTime() or 0
        addon.BagHooks.bankOpenLatchUntil = now + 1.5
    end
    if self:IsWindowModuleEnabled("oneBank") and addon.OneBank then
        addon.OneBank:Show()
    end
    if addon.BagHooks then
        addon.BagHooks:OpenBags("BankOpen")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            if LunaBags and LunaBags:IsWindowModuleEnabled("oneBank") then
                LunaBags:UpdateCurrentCharacterCacheDeferred(true, false)
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
    if addon.BagHooks then
        addon.BagHooks:CloseBags("BankClose")
    end
    if addon.OneBank then
        addon.OneBank:Hide()
    end
end

function LunaBags:SuppressDefaultGuildBankFrame()
    if not GuildBankFrame or not self:IsWindowModuleEnabled("oneGuildBank") then
        return
    end
    if not GuildBankFrame._LunaBagsOriginalParent and GuildBankFrame.GetParent then
        GuildBankFrame._LunaBagsOriginalParent = GuildBankFrame:GetParent()
    end
    if GuildBankFrame.SetParent and GuildBankFrame._LunaBagsOriginalParent then
        GuildBankFrame:SetParent(GuildBankFrame._LunaBagsOriginalParent)
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
            if not (LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank")) then
                return
            end
            if LunaBags then
                LunaBags:SuppressDefaultGuildBankFrame()
            end
            if LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank then
                addon.OneGuildBank:Show()
            end
            if LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank") and addon.BagHooks then
                addon.BagHooks:OpenBags("GuildBankOpen")
            end
        end)
        GuildBankFrame:HookScript("OnHide", function()
            if not (LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank")) then
                return
            end
            if addon.OneGuildBank then
                addon.OneGuildBank:Hide()
            end
            if addon.BagHooks then
                addon.BagHooks:CloseBags("GuildBankClose")
            end
        end)
    end

    if hooksecurefunc and GuildBankFrame.Show then
        hooksecurefunc(GuildBankFrame, "Show", function()
            if not (LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank")) then
                return
            end
            if LunaBags then
                LunaBags:SuppressDefaultGuildBankFrame()
            end
            if LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank then
                addon.OneGuildBank:Show()
            end
            if LunaBags and LunaBags:IsWindowModuleEnabled("oneGuildBank") and addon.BagHooks then
                addon.BagHooks:OpenBags("GuildBankOpen")
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
    if self:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank then
        addon.OneGuildBank:Show()
    end
    if self:IsWindowModuleEnabled("oneGuildBank") and addon.BagHooks then
        addon.BagHooks:OpenBags("GuildBankOpen")
    end
end

function LunaBags:GUILDBANKFRAME_CLOSED()
    self:RestoreDefaultGuildBankFrame()
    if not self:IsWindowModuleEnabled("oneGuildBank") then
        return
    end
    if addon.BagHooks then
        addon.BagHooks:CloseBags("GuildBankClose")
    end
    if addon.OneGuildBank then
        addon.OneGuildBank:Hide()
    end
end

function LunaBags:GUILDBANK_UPDATE()
    if self:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank then
        if addon.OneGuildBank.InvalidateSlotCache then
            addon.OneGuildBank:InvalidateSlotCache()
        end
        addon.OneGuildBank:RefreshIfShown()
    end
end

function LunaBags:GUILDBANK_UPDATE_MONEY()
    if self:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank and addon.OneGuildBank.RefreshMoneyDisplay then
        addon.OneGuildBank:RefreshMoneyDisplay()
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
    if self:IsWindowModuleEnabled("oneGuildBank") and addon.OneGuildBank then
        addon.OneGuildBank:Show()
    end
    if self:IsWindowModuleEnabled("oneGuildBank") and addon.BagHooks then
        addon.BagHooks:OpenBags("GuildBankOpen")
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
    if addon.OneGuildBank then
        addon.OneGuildBank:Hide()
    end
    if addon.BagHooks then
        addon.BagHooks:CloseBags("GuildBankClose")
    end
    self:RestoreDefaultGuildBankFrame()
end
