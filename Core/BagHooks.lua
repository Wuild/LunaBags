local _, ns = ...
local LunaBags = ns.LunaBags

local BagHooks = {
    isOpen = false,
    isHooked = false,
    blizzardDisabled = false,
    toggleLocked = false,
}

ns.BagHooks = BagHooks

local function SafeScan()
    if ns.BagData then
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
    if self.isOpen then
        return
    end
    self.isOpen = true
    self:HideBlizzardBags()
    if ns.OneBag then
        ns.OneBag:Show()
    end
    SafeScan()

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
        return
    end
    if not self.isOpen then
        return
    end
    self.isOpen = false
    if ns.OneBag then
        ns.OneBag:Hide()
    end
    SafeScan()

    if LunaBags.db and LunaBags.db.profile.debug then
        LunaBags:Print(("Bags closed (%s)."):format(source or "unknown"))
    end
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
        SafeScan()
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
    if not self._originalCloseAllBags then self._originalCloseAllBags = _G.CloseAllBags end
    if not self._originalToggleAllBags then self._originalToggleAllBags = _G.ToggleAllBags end
    if not self._originalOpenBackpack then self._originalOpenBackpack = _G.OpenBackpack end
    if not self._originalCloseBackpack then self._originalCloseBackpack = _G.CloseBackpack end
    if not self._originalToggleBackpack then self._originalToggleBackpack = _G.ToggleBackpack end
    if not self._originalToggleBag then self._originalToggleBag = _G.ToggleBag end

    _G.OpenAllBags = function(...)
        BagHooks:OpenBags("OpenAllBags")
    end

    _G.CloseAllBags = function(...)
        if BagHooks.isOpen then
            BagHooks:CloseBags("CloseAllBags")
            return true
        end
        if BagHooks._originalCloseAllBags then
            return BagHooks._originalCloseAllBags(...)
        end
        return false
    end

    _G.ToggleAllBags = function(...)
        BagHooks:ToggleBags("ToggleAllBags")
    end

    _G.OpenBackpack = function(...)
        BagHooks:OpenBags("OpenBackpack")
    end

    _G.CloseBackpack = function(...)
        if BagHooks.isOpen then
            BagHooks:CloseBags("CloseBackpack")
            return true
        end
        if BagHooks._originalCloseBackpack then
            return BagHooks._originalCloseBackpack(...)
        end
        return false
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
