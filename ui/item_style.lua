local _, ns = ...
local LunaBags = ns.LunaBags

local ItemButtonStyle = LunaBags and LunaBags:CreateModule("itemButtonStyle") or {}
ns.ItemButtonStyle = ItemButtonStyle

local ITEM_TEXT_FONTS = {
    expressway = "Interface\\AddOns\\LunaBags\\Art\\Expressway.ttf",
    arial_bold = "Fonts\\FRIZQT__.TTF",
    friz = "Fonts\\FRIZQT__.TTF",
}

local function ResolveTextFont(fontKey)
    if type(fontKey) ~= "string" or fontKey == "" then
        return ITEM_TEXT_FONTS.expressway
    end
    return ITEM_TEXT_FONTS[fontKey] or ITEM_TEXT_FONTS.expressway
end

local function ResolveQualityBorderColor(quality)
    if not quality or quality <= 1 then
        return 0.34, 0.34, 0.34, 0.95
    end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r and g and b then
            return r, g, b, 1
        end
    end
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r and g and b then
            return r, g, b, 1
        end
    end
    return 0.34, 0.34, 0.34, 0.95
end

local function Clamp(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
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

local function ResolveStackCountLayout(cfg)
    local align = (cfg and cfg.stackCountAlign) or "right"
    if align ~= "left" then
        align = "right"
    end
    local x = tonumber(cfg and cfg.stackCountOffsetX) or 3
    local y = tonumber(cfg and cfg.stackCountOffsetY) or 3
    return align, x, y
end

local function ApplyStackCountAnchor(count, button, cfg)
    if not count or not count.ClearAllPoints or not count.SetPoint then
        return
    end
    local align, x, y = ResolveStackCountLayout(cfg)
    count:ClearAllPoints()
    if align == "left" then
        count:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", x, y)
        if count.SetJustifyH then
            count:SetJustifyH("LEFT")
        end
    else
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -x, y)
        if count.SetJustifyH then
            count:SetJustifyH("RIGHT")
        end
    end
end


local function ResolveButtonIcon(button)
    if not button then
        return nil
    end
    local buttonName = button.GetName and button:GetName() or nil
    local icon = button.icon or button.Icon or button.IconTexture or (buttonName and (_G[buttonName .. "IconTexture"] or _G[buttonName .. "Icon"]))
    if icon then
        button.icon = icon
    end
    return icon
end

local function ReadContainerItemLocked(bag, slot)
    bag = tonumber(bag)
    slot = tonumber(slot)
    if not bag or not slot then
        return nil
    end

    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if type(info) == "table" then
            return info.isLocked or info.locked or false
        end
    end

    if GetContainerItemInfo then
        local _, _, locked = GetContainerItemInfo(bag, slot)
        return locked or false
    end

    return nil
end

local function GetItemBagSlot(button, item)
    item = item or (button and button._styleItem) or (button and button.item)

    local bag = item and (item.bag or item.bagID or item.bagId or item.container or item.containerID or item.containerId or item.containerIndex)
    local slot = item and (item.slot or item.slotID or item.slotId or item.containerSlotID or item.containerSlotId or item.slotIndex)

    bag = bag or (button and (button.bag or button.bagID or button.bagId or button.container or button.containerID or button.containerId or button.containerIndex))
    slot = slot or (button and (button.slot or button.slotID or button.slotId or button.containerSlotID or button.containerSlotId or button.slotIndex))

    return tonumber(bag), tonumber(slot)
end

function ItemButtonStyle.IsItemLocked(button, item)
    item = item or (button and button._styleItem) or (button and button.item)

    if button and (button._styleDragging or button.isLocked or button.locked) then
        return true
    end

    if item and (item.isLocked or item.locked) then
        return true
    end

    local bag, slot = GetItemBagSlot(button, item)
    local locked = ReadContainerItemLocked(bag, slot)
    if locked ~= nil then
        return locked == true
    end

    return false
end

function ItemButtonStyle.UpdateLockedState(button, item)
    if not button then
        return
    end

    if item then
        button._styleItem = item
    end

    local icon = ResolveButtonIcon(button)
    local locked = ItemButtonStyle.IsItemLocked(button, item)
    button._lunaBagsLocked = locked == true

    if icon then
        if icon.SetDesaturated then
            icon:SetDesaturated(locked or false)
        end
        if icon.SetVertexColor then
            if locked then
                icon:SetVertexColor(0.45, 0.45, 0.45, 1)
            else
                icon:SetVertexColor(1, 1, 1, 1)
            end
        end
    end

    if locked then
        button:SetAlpha(math.max(0.1, (button._baseAlpha or 1) * 0.72))
    elseif not button._styleDragging then
        button:SetAlpha(button._baseAlpha or 1)
    end
end

function ItemButtonStyle.GetConfig()
    local profile = ns.LunaBags and ns.LunaBags.db and ns.LunaBags.db.profile
    local cfg = profile and profile.ui or {}
    local fr, fg, fb = GetColorValue(cfg.itemFrameColor, 0.13, 0.13, 0.13)
    return {
        frameR = fr,
        frameG = fg,
        frameB = fb,
        frameA = Clamp(cfg.itemFrameOpacity, 0, 1, 0.92),
        borderSize = Clamp(cfg.itemBorderSize, 0, 4, 1),
        stackCountTextSize = Clamp(cfg.stackCountTextSize, 8, 24, 10),
        cooldownTextSize = Clamp(cfg.cooldownTextSize, 8, 32, 10),
        itemTextFont = ITEM_TEXT_FONTS[cfg.itemTextFont] or ITEM_TEXT_FONTS.expressway,
        itemTextSize = Clamp(cfg.itemTextSize, 8, 24, 10),
        itemTextOutline = cfg.itemTextOutline ~= false,
        itemTextShadow = cfg.itemTextShadow ~= false,
        stackCountAlign = (cfg.stackCountAlign == "left") and "left" or "right",
        stackCountOffsetX = Clamp(cfg.stackCountOffsetX, 0, 20, 3),
        stackCountOffsetY = Clamp(cfg.stackCountOffsetY, 0, 20, 3),
    }
end

function ItemButtonStyle.GetSignature(cfg)
    cfg = cfg or ItemButtonStyle.GetConfig()
    return table.concat({
        tostring(cfg.frameR or ""),
        tostring(cfg.frameG or ""),
        tostring(cfg.frameB or ""),
        tostring(cfg.frameA or ""),
        tostring(cfg.borderSize or ""),
        tostring(cfg.stackCountTextSize or ""),
        tostring(cfg.cooldownTextSize or ""),
        tostring(cfg.itemTextFont or ""),
        tostring(cfg.itemTextSize or ""),
        tostring(cfg.itemTextOutline == true),
        tostring(cfg.itemTextShadow == true),
        tostring(cfg.stackCountAlign or ""),
        tostring(cfg.stackCountOffsetX or ""),
        tostring(cfg.stackCountOffsetY or ""),
    }, "|")
end

local function PixelSnap(texture)
    if not texture then
        return
    end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(true)
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
end

local function EnsureLineBorder(button)
    if not button or not button.StyleBorder then
        return
    end
    if button.StyleBorderLines then
        ItemButtonStyle.ApplyBorderSize(button)
        return
    end

    local parent = button.StyleBorder
    local lines = {}
    local function Line()
        local tex = parent:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        PixelSnap(tex)
        return tex
    end

    lines.top = Line()
    lines.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    lines.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    lines.top:SetHeight(1)

    lines.bottom = Line()
    lines.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    lines.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    lines.bottom:SetHeight(1)

    lines.left = Line()
    lines.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    lines.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    lines.left:SetWidth(1)

    lines.right = Line()
    lines.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    lines.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    lines.right:SetWidth(1)

    button.StyleBorderLines = lines

    if not parent._LunaBagsSetBackdropBorderColor and parent.SetBackdropBorderColor then
        parent._LunaBagsSetBackdropBorderColor = parent.SetBackdropBorderColor
        parent.SetBackdropBorderColor = function(frame, r, g, b, a)
            frame:_LunaBagsSetBackdropBorderColor(r or 0, g or 0, b or 0, 0)
            local owner = frame._LunaBagsOwnerButton
            local borderLines = owner and owner.StyleBorderLines
            if borderLines then
                local cfg = ItemButtonStyle.GetConfig()
                local visible = (cfg.borderSize or 1) > 0
                for _, line in pairs(borderLines) do
                    line:SetVertexColor(r or 0.34, g or 0.34, b or 0.34, a or 0.95)
                    line:SetShown(visible)
                end
            end
        end
    end
    parent._LunaBagsOwnerButton = button
    ItemButtonStyle.ApplyBorderSize(button)
end

local function EnsureInnerGlow(button)
    if not button then
        return nil
    end
    if button.StyleInnerGlow then
        return button.StyleInnerGlow
    end

    local parent = button.StyleBorder or button
    local glow = parent:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", parent, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 7, -7)
    glow:Hide()
    button.StyleInnerGlow = glow
    return glow
end

local function SetInnerGlowColor(button, r, g, b, a)
    local glow = EnsureInnerGlow(button)
    if not glow then
        return
    end
    local alpha = math.min(0.42, math.max(0.18, (a or 0.95) * 0.32))
    glow:SetVertexColor(r or 0.34, g or 0.34, b or 0.34, alpha)
    glow:SetShown(button._lunaBagsInnerGlowVisible == true)
end

local function SetInnerGlowShown(button, shown)
    if not button or not button.StyleInnerGlow then
        return
    end
    button._lunaBagsInnerGlowVisible = shown == true
    button.StyleInnerGlow:SetShown(shown == true)
end

function ItemButtonStyle.ApplyBorderSize(button)
    local lines = button and button.StyleBorderLines
    if not lines then
        return
    end
    local cfg = ItemButtonStyle.GetConfig()
    local size = cfg.borderSize or 1
    for _, line in pairs(lines) do
        line:SetShown(size > 0)
    end
    lines.top:SetHeight(size)
    lines.bottom:SetHeight(size)
    lines.left:SetWidth(size)
    lines.right:SetWidth(size)
end

function ItemButtonStyle.ApplyTextStyle(button)
    if not button then
        return
    end
    local cfg = ItemButtonStyle.GetConfig()
    local sharedSize = cfg.itemTextSize or 10
    local font = ResolveTextFont(cfg.itemTextFont)
    local styleFlags = cfg.itemTextOutline and "OUTLINE" or ""
    local function ApplySmoothSmallFont(region, size)
        if not region then
            return
        end
        if region.SetFont then
            region:SetFont(font, size or sharedSize, styleFlags)
        end
        if region.SetFontObject then
            region:SetFontObject(nil)
        end
        if cfg.itemTextShadow then
            if region.SetShadowOffset then
                region:SetShadowOffset(1, -1)
            end
            if region.SetShadowColor then
                region:SetShadowColor(0, 0, 0, 0.9)
            end
        else
            if region.SetShadowOffset then
                region:SetShadowOffset(0, 0)
            end
            if region.SetShadowColor then
                region:SetShadowColor(0, 0, 0, 0)
            end
        end
    end
    local buttonName = button.GetName and button:GetName() or nil
    local count = button.count or button.Count or (buttonName and _G[buttonName .. "Count"])
    local countType = type(count)
    if (countType == "table" or countType == "userdata") and count.SetFont then
        ApplyStackCountAnchor(count, button, cfg)
        ApplySmoothSmallFont(count, sharedSize)
    end
    if button.GetRegions then
        for _, region in ipairs({ button:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetFont then
                local name = region.GetName and region:GetName() or ""
                if region == button.Count or region == button.count or (type(name) == "string" and name:find("Count")) then
                    ApplyStackCountAnchor(region, button, cfg)
                    ApplySmoothSmallFont(region, sharedSize)
                end
            end
        end
    end
    local cooldown = button.cooldown or button.Cooldown or (buttonName and _G[buttonName .. "Cooldown"])
    if cooldown and cooldown.GetRegions then
        for _, region in ipairs({ cooldown:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetFont then
                ApplySmoothSmallFont(region, sharedSize)
            end
        end
    end

    ApplySmoothSmallFont(button.LunaBagsItemLevelText, sharedSize)
    ApplySmoothSmallFont(button.LunaBagsQuestStartMarker, sharedSize)
    ApplySmoothSmallFont(button.DebugSlotText, sharedSize)
end

function ItemButtonStyle.ApplyItemTextFont(fontString, size)
    if not fontString then
        return
    end
    local cfg = ItemButtonStyle.GetConfig()
    local sharedSize = cfg.itemTextSize or 10
    local font = ResolveTextFont(cfg.itemTextFont)
    local styleFlags = cfg.itemTextOutline and "OUTLINE" or ""
    if fontString.SetFont then
        fontString:SetFont(font, size or sharedSize, styleFlags)
    end
    if fontString.SetFontObject then
        fontString:SetFontObject(nil)
    end
    if cfg.itemTextShadow then
        if fontString.SetShadowOffset then
            fontString:SetShadowOffset(1, -1)
        end
        if fontString.SetShadowColor then
            fontString:SetShadowColor(0, 0, 0, 0.9)
        end
    else
        if fontString.SetShadowOffset then
            fontString:SetShadowOffset(0, 0)
        end
        if fontString.SetShadowColor then
            fontString:SetShadowColor(0, 0, 0, 0)
        end
    end
end

function ItemButtonStyle.SetBorderVisualColor(button, r, g, b, a)
    if not button or not button.StyleBorder then
        return
    end

    EnsureLineBorder(button)
    ItemButtonStyle.ApplyBorderSize(button)
    if button.StyleBorder.SetBackdropBorderColor then
        button.StyleBorder:SetBackdropBorderColor(r or 0, g or 0, b or 0, 0)
    end
    local lines = button.StyleBorderLines
    if lines then
        local cfg = ItemButtonStyle.GetConfig()
        local visible = (cfg.borderSize or 1) > 0
        for _, line in pairs(lines) do
            line:SetVertexColor(r or 0.34, g or 0.34, b or 0.34, a or 0.95)
            line:SetShown(visible)
        end
    end
    SetInnerGlowColor(button, r, g, b, a)
end

function ItemButtonStyle.SetBorderColor(button, r, g, b, a)
    if not button or not button.StyleBorder then
        return
    end
    button.StyleBorderBaseR = r
    button.StyleBorderBaseG = g
    button.StyleBorderBaseB = b
    button.StyleBorderBaseA = a
    ItemButtonStyle.SetBorderVisualColor(button, r, g, b, a)
end

function ItemButtonStyle.ResetState(button)
    if not button or not button.StyleBG or not button.StyleBorder then
        return
    end
    button._lunaBagsStyleDirty = true
    local cfg = ItemButtonStyle.GetConfig()
    button._styleDragging = false
    button:SetAlpha(button._baseAlpha or 1)
    button.StyleBG:SetBackdropColor(cfg.frameR, cfg.frameG, cfg.frameB, cfg.frameA)
    SetInnerGlowShown(button, false)
    ItemButtonStyle.SetBorderVisualColor(
            button,
            button.StyleBorderBaseR or 0.34,
            button.StyleBorderBaseG or 0.34,
            button.StyleBorderBaseB or 0.34,
            button.StyleBorderBaseA or 0.95
    )
    if button.StyleGlow then
        button.StyleGlow:Hide()
    end
end

function ItemButtonStyle.Apply(button)
    if not button then
        return false
    end

    local cfg = ItemButtonStyle.GetConfig()
    local signature = ItemButtonStyle.GetSignature(cfg)
    local needsApply = button._lunaBagsStyleSignature ~= signature
        or not button.StyleBG
        or not button.StyleBorder
        or not button.StyleStateHooks
        or not button.IconMask

    if not needsApply then
        return false
    end

    if not button.StyleBG then
        button.StyleBG = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBG:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.StyleBG:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.StyleBG:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        button.StyleBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    end
    button.StyleBG:SetBackdropColor(cfg.frameR, cfg.frameG, cfg.frameB, cfg.frameA)

    if not button.StyleBorder then
        button.StyleBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.StyleBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.StyleBorder:SetFrameLevel(button:GetFrameLevel() + 2)
    end
    if button.StyleBorder.SetBackdrop then
        button.StyleBorder:SetBackdrop({})
    end
    EnsureLineBorder(button)
    ItemButtonStyle.ApplyBorderSize(button)
    ItemButtonStyle.SetBorderColor(button, 0.34, 0.34, 0.34, 0.95)
    ItemButtonStyle.ApplyTextStyle(button)

    if not button.StyleGlow then
        button.StyleGlow = CreateFrame("Frame", nil, button)
        button.StyleGlow:Hide()
    end

    local buttonName = button.GetName and button:GetName() or nil
    local icon = ResolveButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 4)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -2)
        icon:SetTexCoord(0, 1, 0, 1)

        if not button.IconMask then
            local mask = button:CreateMaskTexture(nil, "ARTWORK")
            mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            mask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            button.IconMask = mask
            if icon.AddMaskTexture then
                icon:AddMaskTexture(mask)
            end
        end
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetTexture(nil); normal:Hide() end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then pushed:SetTexture(nil); pushed:Hide() end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then highlight:SetTexture(nil); highlight:Hide() end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then checked:SetTexture(nil); checked:Hide() end

    if button.IconBorder then button.IconBorder:SetAlpha(0); button.IconBorder:Hide() end
    if button.Background then button.Background:SetTexture(nil); button.Background:Hide() end
    if button.IconOverlay then button.IconOverlay:SetTexture(nil); button.IconOverlay:Hide() end
    if button.IconOverlay2 then button.IconOverlay2:SetTexture(nil); button.IconOverlay2:Hide() end
    if button.searchOverlay then button.searchOverlay:Hide() end
    if button.NewItemTexture then button.NewItemTexture:Hide() end
    if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
    if button.flashAnim then button.flashAnim:Stop() end

    if not button.StyleStateHooks then
        local function Brighten(v, amount)
            return math.min(1, (v or 0) + amount)
        end
        local function SetIdle(self)
            if self._styleDragging then return end
            self._lunaBagsStyleDirty = true
            ItemButtonStyle.ResetState(self)
            ItemButtonStyle.UpdateLockedState(self)
        end
        local function SetHover(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self._lunaBagsStyleDirty = true
            local style = ItemButtonStyle.GetConfig()
            if self._styleDragging then return end
            self.StyleBG:SetBackdropColor(Brighten(style.frameR, 0.04), Brighten(style.frameG, 0.04), Brighten(style.frameB, 0.04), math.min(1, style.frameA + 0.03))
            ItemButtonStyle.SetBorderVisualColor(
                    self,
                    Brighten(self.StyleBorderBaseR or 0.34, 0.10),
                    Brighten(self.StyleBorderBaseG or 0.34, 0.10),
                    Brighten(self.StyleBorderBaseB or 0.34, 0.10),
                    self.StyleBorderBaseA or 0.98
            )
            SetInnerGlowShown(self, true)
            if self.StyleGlow then self.StyleGlow:Hide() end
            ItemButtonStyle.UpdateLockedState(self)
        end
        local function SetDrag(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self._lunaBagsStyleDirty = true
            local style = ItemButtonStyle.GetConfig()
            self._styleDragging = true
            self:SetAlpha(math.max(0.1, (self._baseAlpha or 1) * 0.72))
            self.StyleBG:SetBackdropColor(Brighten(style.frameR, 0.07), Brighten(style.frameG, 0.07), Brighten(style.frameB, 0.07), math.min(1, style.frameA + 0.06))
            ItemButtonStyle.SetBorderVisualColor(
                    self,
                    Brighten(self.StyleBorderBaseR or 0.34, 0.20),
                    Brighten(self.StyleBorderBaseG or 0.34, 0.20),
                    Brighten(self.StyleBorderBaseB or 0.34, 0.20),
                    1
            )
            SetInnerGlowShown(self, true)
            if self.StyleGlow then self.StyleGlow:Hide() end
            ItemButtonStyle.UpdateLockedState(self)
        end

        button:HookScript("OnEnter", SetHover)
        button:HookScript("OnLeave", SetIdle)
        button:HookScript("OnDragStart", SetDrag)
        button:HookScript("OnDragStop", function(self)
            self._styleDragging = false
            if self:IsMouseOver() then
                SetHover(self)
            else
                SetIdle(self)
            end
        end)
        button:HookScript("OnReceiveDrag", function(self)
            self._styleDragging = false
            if self:IsMouseOver() then SetHover(self) else SetIdle(self) end
        end)
        button:HookScript("OnHide", SetIdle)

        if button.RegisterEvent then
            button:RegisterEvent("ITEM_LOCK_CHANGED")
            button:HookScript("OnEvent", function(self, event, bagID, slot)
                if event == "ITEM_LOCK_CHANGED" and (tonumber(bagID) ~= tonumber(self.bagID) or tonumber(slot) ~= tonumber(self.slot)) then
                    return
                end
                ItemButtonStyle.UpdateLockedState(self)
            end)
        end

        button.StyleStateHooks = true
        SetIdle(button)
    end
    button._lunaBagsStyleSignature = signature
    return true
end

function ItemButtonStyle.UpdateBorderForItem(button, item, qualityEnabled)
    if not button or not button.StyleBorder then
        return
    end
    button._styleItem = item
    local useQuality = qualityEnabled ~= false
    local quality = useQuality and item and item.quality or nil
    if useQuality and quality == nil and item and item.itemLink and GetItemInfo then
        local _, _, q = GetItemInfo(item.itemLink)
        quality = q
    end
    local r, g, b, a = ResolveQualityBorderColor(quality)
    ItemButtonStyle.SetBorderColor(button, r, g, b, a)
    if button.IconBorder then button.IconBorder:SetAlpha(0); button.IconBorder:Hide() end
    if button.Background then button.Background:SetTexture(nil); button.Background:Hide() end
    if button.IconOverlay then button.IconOverlay:SetTexture(nil); button.IconOverlay:Hide() end
    ItemButtonStyle.UpdateLockedState(button, item)
end
