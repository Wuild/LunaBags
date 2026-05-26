local _, ns = ...
local LunaBags = ns.LunaBags

local BagHooks = LunaBags and LunaBags:CreateModule("bagHooks") or {}
BagHooks.isOpen = false
BagHooks.isHooked = false
BagHooks.blizzardDisabled = false
BagHooks.toggleLocked = false

ns.BagHooks = BagHooks

local function SafeScan()
    if ns.LunaBags and ns.LunaBags.UpdateCurrentCharacterCacheDeferred then
        local includeBank = ns.BagData and ns.BagData.IsBankAvailable and ns.BagData:IsBankAvailable() or false
        ns.LunaBags:UpdateCurrentCharacterCacheDeferred(includeBank == true, false)
    elseif ns.BagData then
        ns.BagData:OnBagsUpdated()
    end
end

local function ForEachBlizzardBagFrame(callback)
    if type(callback) ~= "function" then
        return
    end
    local maxFrames = NUM_CONTAINER_FRAMES or 13
    for i = 1, maxFrames do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            callback(frame, i)
        end
    end
    if _G.ContainerFrameCombinedBags then
        callback(_G.ContainerFrameCombinedBags, 0)
    end
end

function BagHooks:HideBlizzardBags()
    ForEachBlizzardBagFrame(function(frame)
        if frame.Hide then
            frame:Hide()
        end
    end)
end

function BagHooks:DisableBlizzardBags()
    if self.blizzardDisabled then
        return
    end
    self.blizzardDisabled = true

    ForEachBlizzardBagFrame(function(frame)
        frame:SetScript("OnShow", nil)
        frame:SetScript("OnHide", nil)
        if frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
        end
        if frame.ClearAllPoints then
            frame:ClearAllPoints()
        end
        if frame.Hide then
            frame:Hide()
        end
        if hooksecurefunc and frame.SetPoint and frame.ClearAllPoints then
            hooksecurefunc(frame, "SetPoint", frame.ClearAllPoints)
        end
    end)
end

function BagHooks:OpenBags(source)
    if self.toggleLocked and source ~= "UI" then
        return
    end
    if ns.LunaBags and ns.LunaBags.IsWindowModuleEnabled and not ns.LunaBags:IsWindowModuleEnabled("oneBag") then
        return
    end
    if self.isOpen then
        return
    end
    self.isOpen = true
    self:HideBlizzardBags()
    if ns.OneBag then
        ns.OneBag:Show()
    end

    if LunaBags.db and LunaBags.db.profile.debug then
        LunaBags:Print(("Bags opened (%s)."):format(source or "unknown"))
    end
end

function BagHooks:CloseBags(source)
    if self.toggleLocked and source ~= "UI" then
        return
    end
    -- Opening bank can trigger CloseAllBags in Blizzard code paths.
    -- Keep inventory visible in that case.
    local now = GetTime and GetTime() or 0
    local bankOpenLatched = self.bankOpenLatchUntil and now <= self.bankOpenLatchUntil
    if source == "CloseAllBags" and (bankOpenLatched or (BankFrame and BankFrame:IsShown()) or (ns.OneBank and ns.OneBank.frame and ns.OneBank.frame:IsShown())) then
        return false
    end
    if not self.isOpen then
        return false
    end
    self.isOpen = false
    if ns.OneBag then
        ns.OneBag:Hide()
    end
    SafeScan()

    if LunaBags.db and LunaBags.db.profile.debug then
        LunaBags:Print(("Bags closed (%s)."):format(source or "unknown"))
    end
    return true
end

function BagHooks:ToggleBags(source)
    if self.toggleLocked then
        return
    end
    local now = GetTime and GetTime() or 0
    if source ~= "UI" and self.lastToggleAt and (now - self.lastToggleAt) < 0.08 then
        return
    end
    self.lastToggleAt = now

    self.toggleLocked = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            BagHooks.toggleLocked = false
        end)
    else
        self.toggleLocked = false
    end

    if ns.OneBag then
        ns.OneBag:Toggle()
        self.isOpen = ns.OneBag.frame and ns.OneBag.frame:IsShown() or false
        if not self.isOpen then
            SafeScan()
        end
        if LunaBags.db and LunaBags.db.profile.debug then
            LunaBags:Print(("Bags toggled (%s)."):format(source or "unknown"))
        end
        return
    end

    if self.isOpen then
        self:CloseBags(source)
    else
        self:OpenBags(source)
    end
end

function BagHooks:IsOpen()
    return self.isOpen
end

function BagHooks:EnableHooks()
    if self.isHooked then
        return
    end

    self.isHooked = true
    self:DisableBlizzardBags()
    if not self._originalOpenAllBags then self._originalOpenAllBags = _G.OpenAllBags end
    if not self._originalToggleAllBags then self._originalToggleAllBags = _G.ToggleAllBags end
    if not self._originalOpenBackpack then self._originalOpenBackpack = _G.OpenBackpack end
    if not self._originalToggleBackpack then self._originalToggleBackpack = _G.ToggleBackpack end
    if not self._originalToggleBag then self._originalToggleBag = _G.ToggleBag end

    _G.OpenAllBags = function(...)
        BagHooks:OpenBags("OpenAllBags")
    end

    _G.ToggleAllBags = function(...)
        BagHooks:ToggleBags("ToggleAllBags")
    end

    _G.OpenBackpack = function(...)
        BagHooks:OpenBags("OpenBackpack")
    end

    _G.ToggleBackpack = function(...)
        BagHooks:ToggleBags("ToggleBackpack")
    end

    _G.ToggleBag = function(bagID, ...)
        if bagID == 0 then
            BagHooks:ToggleBags("ToggleBag")
            return
        end
        -- Non-backpack bag toggles map to the same combined view in LunaBags.
        BagHooks:ToggleBags("ToggleBag")
    end

end

function BagHooks:DisableHooks()
    if not self.isHooked then
        return
    end

    if self._originalOpenAllBags then _G.OpenAllBags = self._originalOpenAllBags end
    if self._originalToggleAllBags then _G.ToggleAllBags = self._originalToggleAllBags end
    if self._originalOpenBackpack then _G.OpenBackpack = self._originalOpenBackpack end
    if self._originalToggleBackpack then _G.ToggleBackpack = self._originalToggleBackpack end
    if self._originalToggleBag then _G.ToggleBag = self._originalToggleBag end

    self.isHooked = false
    self.isOpen = false
    self.toggleLocked = false
    self.bankOpenLatchUntil = nil
    if ns.OneBag then
        ns.OneBag:Hide()
    end
end
