local name, addon = ...

local LunaBags = addon.LunaBags

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
        local data = addon.BagData and addon.BagData:GetCharacterData()
        if data and self.db.profile.debug then
            self:Print(("Character cache updated at %s."):format(date("%H:%M:%S", data.lastUpdate or time())))
        else
            self:Print("Use /lb debug then /lb dump to inspect cache timestamps.")
        end
        return
    end

    if cmd == "version" or cmd == "ver" or cmd == "checkversion" then
        if self.StartVersionCheck then
            self:StartVersionCheck(rest)
        else
            local version = (self.GetVersionString and self:GetVersionString()) or "unknown"
            self:Print(("Local version: %s"):format(tostring(version)))
        end
        return
    end

    if cmd == "dumpchars" then
        if not addon.BagData then
            self:Print("BagData module missing.")
            return
        end
        local currentKey = addon.OneBag and addon.OneBag.GetCurrentCharacterKey and addon.OneBag:GetCurrentCharacterKey() or "unknown"
        local viewKey = addon.OneBag and addon.OneBag.viewCharacterKey or nil
        local effectiveKey = viewKey or currentKey
        local viewed = addon.OneBag and addon.OneBag.GetViewedCharacterData and addon.OneBag:GetViewedCharacterData() or nil
        self:Print(("Current key: %s"):format(tostring(currentKey)))
        self:Print(("View key: %s"):format(tostring(viewKey)))
        self:Print(("Effective view key: %s"):format(tostring(effectiveKey)))
        self:Print(("Viewed record resolved: %s"):format((viewKey == nil or viewed) and "yes" or "no"))

        local all = addon.BagData:GetAllCharacters() or {}
        local total = 0
        for _ in pairs(all) do
            total = total + 1
        end
        self:Print(("Characters discovered: %d"):format(total))

        for key, c in addon.BagData:IterCharacters() do
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
        if not addon.BagData then
            self:Print("BagData module missing.")
            return
        end
        addon.BagData:ScanBags(addon.BagData:IsBankAvailable())
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
        if not addon.OneBag then
            self:Print("OneBag module missing.")
            return
        end
        local key = rest and strtrim(rest) or ""
        if key == "" or key:lower() == "current" then
            if addon.OneBag.SetViewCharacterKey then
                addon.OneBag:SetViewCharacterKey(nil)
            else
                addon.OneBag.viewCharacterKey = nil
            end
            if addon.OneBag.frame then
                addon.OneBag:ApplySettings()
                addon.OneBag:Refresh()
            end
            self:Print("Character view set to current.")
            return
        end
        if addon.OneBag.SetViewCharacterKey then
            addon.OneBag:SetViewCharacterKey(key)
        else
            addon.OneBag.viewCharacterKey = key
        end
        if addon.OneBag.frame then
            addon.OneBag:ApplySettings()
            addon.OneBag:Refresh()
        end
        self:Print(("Character view set to: %s"):format(key))
        return
    end

    if cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        if addon.OneBag and addon.OneBag.frame and addon.OneBag.frame:IsShown() then
            addon.OneBag:Refresh()
        end
        if addon.OneBank and addon.OneBank.frame and addon.OneBank.frame:IsShown() then
            addon.OneBank:Refresh()
        end
        self:Print(("Debug is now %s."):format(self.db.profile.debug and "ON" or "OFF"))
        return
    end

    if cmd == "window" then
        if addon.ExtraStyleWindow then
            addon.ExtraStyleWindow:Show()
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

    if addon.OpenConfig then
        addon.OpenConfig()
        return
    end

    self:Print("Commands: /lunabags [open|close|toggle|view <Name-Realm|current>|scan|dbcheck|debug|enable|disable|dump|dumpchars|version|window]")
end
