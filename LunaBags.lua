local ADDON_NAME, ns = ...

---@class LunaBagsAddon : AceAddon-3.0, AceConsole-3.0, AceEvent-3.0
local LunaBags = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
_G.LunaBags = LunaBags
ns.LunaBags = LunaBags

local defaults = ns.configsDefaults
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    if type(data) ~= "string" or data == "" then
        return ""
    end
    local bits = data:gsub(".", function(char)
        local byte = char:byte()
        local out = {}
        for i = 8, 1, -1 do
            out[#out + 1] = (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0) and "1" or "0"
        end
        return table.concat(out)
    end)
    local encoded = (bits .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(chunk)
        if #chunk < 6 then
            return ""
        end
        local value = 0
        for i = 1, 6 do
            value = value + (chunk:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
        end
        return BASE64_ALPHABET:sub(value + 1, value + 1)
    end)
    return encoded .. ({ "", "==", "=" })[#data % 3 + 1]
end

local function Base64Decode(data)
    if type(data) ~= "string" or data == "" then
        return nil
    end
    data = data:gsub("%s+", "")
    if data:match("[^A-Za-z0-9%+/%=]") then
        return nil
    end
    local bits = data:gsub(".", function(char)
        if char == "=" then
            return ""
        end
        local index = BASE64_ALPHABET:find(char, 1, true)
        if not index then
            return ""
        end
        local value = index - 1
        local out = {}
        for i = 6, 1, -1 do
            out[#out + 1] = (value % 2 ^ i - value % 2 ^ (i - 1) > 0) and "1" or "0"
        end
        return table.concat(out)
    end)
    local decoded = bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(chunk)
        if #chunk ~= 8 then
            return ""
        end
        local value = 0
        for i = 1, 8 do
            value = value + (chunk:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
        end
        return string.char(value)
    end)
    return decoded ~= "" and decoded or nil
end

local function CopyTableValue(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[CopyTableValue(k, seen)] = CopyTableValue(v, seen)
    end
    return out
end

local function GetCurrentCharacterKey()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    if not name or name == "" then
        return nil
    end
    return tostring(name) .. "-" .. tostring(realm or "")
end

local function ToAceCharacterKey(characterKey, character)
    local name = character and character.name
    local realm = character and character.realm
    if (not name or name == "" or not realm or realm == "") and type(characterKey) == "string" then
        local parsedName, parsedRealm = characterKey:match("^(.+)%-(.+)$")
        name = name or parsedName
        realm = realm or parsedRealm
    end
    if not name or name == "" then
        return nil
    end
    return tostring(name) .. " - " .. tostring(realm or "")
end

local function ClearProfileRuntimeKeys(profile)
    if type(profile) ~= "table" then
        return
    end
    if type(profile.oneBag) == "table" then
        profile.oneBag._activeCharacter = nil
        profile.oneBag._activeCharacterData = nil
    end
    if type(profile.oneBank) == "table" then
        profile.oneBank._activeCharacter = nil
        profile.oneBank._activeCharacterData = nil
    end
    if type(profile.sorting) == "table" then
        profile.sorting._activeCharacter = nil
        profile.sorting._activeCharacterData = nil
    end
end

local function IsGeneratedProfileKey(db, profileKey)
    if not db or not db.keys or type(profileKey) ~= "string" then
        return false
    end
    return profileKey == db.keys.realm
        or profileKey == db.keys.class
        or profileKey == db.keys.race
        or profileKey == db.keys.faction
        or profileKey == db.keys.factionrealm
        or profileKey == db.keys.factionrealmregion
        or profileKey == db.keys.locale
end

function LunaBags:MigrateDefaultSortRules()
    local sorting = self.db and self.db.profile and self.db.profile.sorting
    if not sorting then
        return
    end
    local hasSimplifiedRules = ns:SortRulesMatch(sorting.rules, ns.simplifiedDefaultSortRules)
    if sorting._defaultRulesVersion == 5 and not hasSimplifiedRules then
        return
    end
    if ns:SortRulesMatch(sorting.rules, ns.oldDefaultSortRules)
        or ns:SortRulesMatch(sorting.rules, ns.priorityQualityDefaultSortRules)
        or hasSimplifiedRules
    then
        sorting.rules = ns:CopySortRules(defaults.profile.sorting.rules)
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

function LunaBags:RefreshOpenWindowsForProfileChange()
    if ns.OneBag then
        if ns.OneBag.InvalidateSlotCache then
            ns.OneBag:InvalidateSlotCache()
        end
        ns.OneBag._layoutModel = nil
        if ns.OneBag.frame and ns.OneBag.frame:IsShown() then
            ns.OneBag:ApplySettings()
            ns.OneBag:Refresh()
        end
    end
    if ns.OneBank then
        if ns.OneBank.InvalidateSlotCache then
            ns.OneBank:InvalidateSlotCache()
        end
        ns.OneBank._layoutModel = nil
        if ns.OneBank.frame and ns.OneBank.frame:IsShown() then
            ns.OneBank:ApplySettings()
            ns.OneBank:Refresh()
        end
    end
    if ns.OneGuildBank and ns.OneGuildBank.frame and ns.OneGuildBank.frame:IsShown() then
        ns.OneGuildBank:ApplySettings()
        ns.OneGuildBank:Refresh()
    end
end

function LunaBags:EnsureProfileShape(profile)
    profile = profile or (self.db and self.db.profile)
    if not profile then
        return
    end
    profile.modules = profile.modules or {}
    profile.plugins = profile.plugins or {}
    if not profile.plugins._qualityBorderMigrated then
        profile.plugins.qualityBorder = true
        profile.plugins._qualityBorderMigrated = true
    end
    profile.ui = profile.ui or {}
    if profile.ui._migratedSharedAppearance ~= true then
        local source = profile.oneBag or profile.oneBank or {}
        profile.ui.windowColor = profile.ui.windowColor or source.windowColor
        profile.ui.windowOpacity = profile.ui.windowOpacity or source.windowOpacity
        profile.ui.headerColor = profile.ui.headerColor or source.headerColor
        profile.ui.headerOpacity = profile.ui.headerOpacity or source.headerOpacity
        profile.ui._migratedSharedAppearance = true
    end
end

function LunaBags:EnsureCharacterProfile()
    if not self.db or not self.db.SetProfile then
        return
    end
    local characterProfile = ToAceCharacterKey(GetCurrentCharacterKey())
    if not characterProfile or characterProfile == "" then
        return
    end

    local current = self.db.keys and self.db.keys.profile
    local shouldSwitch = current == nil
        or current == "Default"
        or IsGeneratedProfileKey(self.db, current)

    if not shouldSwitch then
        return
    end

    if self.db.profiles and not self.db.profiles[characterProfile] then
        self.db.profiles[characterProfile] = {}
    end
    self.db:SetProfile(characterProfile)
end

function LunaBags:GetProfileKeyForCharacter(characterKey)
    if not self.db then
        return nil
    end
    local currentKey = GetCurrentCharacterKey()
    if not characterKey or characterKey == "" or characterKey == currentKey then
        return self.db.keys and self.db.keys.profile
    end

    local character = ns.BagData and ns.BagData.GetCharacterData and ns.BagData:GetCharacterData(characterKey) or nil
    local aceKey = ToAceCharacterKey(characterKey, character)
    local profileKeys = self.db.sv and self.db.sv.profileKeys
    if character and character.profileKey
        and not IsGeneratedProfileKey(self.db, character.profileKey)
        and self.db.profiles
        and self.db.profiles[character.profileKey]
    then
        return character.profileKey
    end
    local profileKey = aceKey and profileKeys and profileKeys[aceKey]
    if profileKey and not IsGeneratedProfileKey(self.db, profileKey) then
        return profileKey
    end
    if aceKey and self.db.profiles and self.db.profiles[aceKey] then
        return aceKey
    end
    if self.db.profiles and self.db.profiles[characterKey] then
        return characterKey
    end
    return nil
end

function LunaBags:ActivateCharacterProfileView(characterKey)
    if not self.db or not self.db.SetProfile then
        return
    end
    local currentKey = GetCurrentCharacterKey()
    if not characterKey or characterKey == "" or characterKey == currentKey then
        self:RestoreCurrentCharacterProfile()
        return
    end

    if not self._realProfileKey then
        self._realProfileKey = self.db.keys and self.db.keys.profile
    end
    local currentAceKey = ToAceCharacterKey(currentKey)
    if currentAceKey and self.db.sv and self.db.sv.profileKeys then
        self._realProfileMapValue = self.db.sv.profileKeys[currentAceKey]
    end

    local profileKey = self:GetProfileKeyForCharacter(characterKey)
    if profileKey and profileKey ~= self.db.keys.profile then
        self.db:SetProfile(profileKey)
        if currentAceKey and self.db.sv and self.db.sv.profileKeys then
            self.db.sv.profileKeys[currentAceKey] = self._realProfileMapValue or self._realProfileKey
        end
    end
    self._viewProfileKey = profileKey
    self:EnsureProfileShape()
    self:MigrateDefaultSortRules()
    self:RefreshOpenWindowsForProfileChange()
end

function LunaBags:RestoreCurrentCharacterProfile()
    if not self.db or not self.db.SetProfile or not self._realProfileKey then
        return
    end
    local currentAceKey = ToAceCharacterKey(GetCurrentCharacterKey())
    if currentAceKey and self.db.sv and self.db.sv.profileKeys then
        self.db.sv.profileKeys[currentAceKey] = self._realProfileMapValue or self._realProfileKey
    end
    if self.db.keys.profile ~= self._realProfileKey then
        self.db:SetProfile(self._realProfileKey)
    end
    self._realProfileKey = nil
    self._realProfileMapValue = nil
    self._viewProfileKey = nil
    self:EnsureProfileShape()
    self:MigrateDefaultSortRules()
    self:RefreshOpenWindowsForProfileChange()
end

function LunaBags:OnDatabaseProfileChanged()
    self:EnsureProfileShape()
    self:MigrateDefaultSortRules()
    self:ApplyWindowModuleStates()
    self:RefreshOpenWindowsForProfileChange()
end

function LunaBags:ExportCurrentProfile()
    local serializer = LibStub("AceSerializer-3.0", true)
    if not serializer or not self.db or not self.db.profile then
        return nil
    end
    local export = CopyTableValue(self.db.profile)
    ClearProfileRuntimeKeys(export)
    export._exportVersion = 1
    export._exportedProfileName = self.db.keys and self.db.keys.profile or nil
    local serialized = serializer:Serialize(export)
    return "LunaBagsProfile:" .. Base64Encode(serialized)
end

function LunaBags:ImportProfile(serialized, profileName)
    local serializer = LibStub("AceSerializer-3.0", true)
    if not serializer or not self.db or type(serialized) ~= "string" or serialized == "" then
        return false, "Profile import data is empty or AceSerializer-3.0 is unavailable."
    end
    serialized = strtrim(serialized)
    local payload = serialized:match("^LunaBagsProfile:(.+)$") or serialized
    local decoded = Base64Decode(payload)
    if decoded then
        payload = decoded
    end

    local ok, imported = serializer:Deserialize(payload)
    if not ok or type(imported) ~= "table" then
        return false, "Profile import data could not be decoded."
    end
    local importedName = imported._exportedProfileName
    ClearProfileRuntimeKeys(imported)
    imported._exportVersion = nil
    imported._exportedProfileName = nil
    local target = (type(profileName) == "string" and strtrim(profileName) ~= "" and strtrim(profileName))
        or importedName
        or (self.db.keys and self.db.keys.profile)
        or "Imported"
    self.db.profiles[target] = CopyTableValue(imported)
    self.db:SetProfile(target)
    self:EnsureProfileShape()
    self:MigrateDefaultSortRules()
    return true, target
end

function LunaBags:OnInitialize()
    local characterProfile = ToAceCharacterKey(GetCurrentCharacterKey())
    self.db = LibStub("AceDB-3.0"):New("LunaBagsDB", defaults, characterProfile)
    if self.db.RegisterCallback then
        self.db.RegisterCallback(self, "OnProfileChanged", "OnDatabaseProfileChanged")
        self.db.RegisterCallback(self, "OnProfileCopied", "OnDatabaseProfileChanged")
        self.db.RegisterCallback(self, "OnProfileReset", "OnDatabaseProfileChanged")
    end
    self:EnsureCharacterProfile()
    self:EnsureProfileShape()
    self:ApplyWindowModuleStates()
    self:MigrateDefaultSortRules()
    self:RegisterChatCommand("lunabags", "HandleSlashCommand")
    self:RegisterChatCommand("lb", "HandleSlashCommand")
end

function LunaBags:OnEnable()
    if not self.db.profile.enabled then
        return
    end

    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN")
    self:RegisterEvent("ITEM_LOCK_CHANGED")
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

    self:HookBlizzardFrames()

    self:UpdateCurrentCharacterCacheDeferred(false, false)

    self:Print("Loaded. Type /lunabags for options.")
end

function LunaBags:OnDisable()
    self:UnregisterAllEvents()
end
