local _, ns = ...

local ItemButtonStyle = {}
ns.ItemButtonStyle = ItemButtonStyle

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
        stackCountTextSize = Clamp(cfg.stackCountTextSize, 8, 24, 12),
        cooldownTextSize = Clamp(cfg.cooldownTextSize, 8, 32, 16),
    }
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
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local count = button.count or button.Count or (button.GetName and _G[button:GetName() .. "Count"])
    local countType = type(count)
    if (countType == "table" or countType == "userdata") and count.SetFont then
        count:SetFont(font, cfg.stackCountTextSize or 12, "OUTLINE")
    end
    if button.GetRegions then
        for _, region in ipairs({ button:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetFont then
                local name = region.GetName and region:GetName() or ""
                if region == button.Count or region == button.count or (type(name) == "string" and name:find("Count")) then
                    region:SetFont(font, cfg.stackCountTextSize or 12, "OUTLINE")
                end
            end
        end
    end
    local cooldown = button.cooldown or button.Cooldown or (button.GetName and _G[button:GetName() .. "Cooldown"])
    if cooldown and cooldown.GetRegions then
        for _, region in ipairs({ cooldown:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetFont then
                region:SetFont(font, cfg.cooldownTextSize or 16, "OUTLINE")
            end
        end
    end
end

function ItemButtonStyle.SetBorderColor(button, r, g, b, a)
    if not button or not button.StyleBorder then
        return
    end
    button.StyleBorderBaseR = r
    button.StyleBorderBaseG = g
    button.StyleBorderBaseB = b
    button.StyleBorderBaseA = a

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
end

function ItemButtonStyle.Apply(button)
    if not button then
        return
    end

    local cfg = ItemButtonStyle.GetConfig()

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

    local icon = button.icon or button.Icon or _G[button:GetName() .. "IconTexture"] or _G[button:GetName() .. "Icon"]
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
            if not self.StyleBG or not self.StyleBorder then return end
            local style = ItemButtonStyle.GetConfig()
            if self._styleDragging then return end
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(style.frameR, style.frameG, style.frameB, style.frameA)
            ItemButtonStyle.SetBorderColor(
                self,
                self.StyleBorderBaseR or 0.34,
                self.StyleBorderBaseG or 0.34,
                self.StyleBorderBaseB or 0.34,
                self.StyleBorderBaseA or 0.95
            )
            if self.StyleGlow then self.StyleGlow:Hide() end
            if self.icon and self.icon.SetDesaturated then
                self.icon:SetDesaturated(false)
            end
        end
        local function SetHover(self)
            if not self.StyleBG or not self.StyleBorder then return end
            local style = ItemButtonStyle.GetConfig()
            if self._styleDragging then return end
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(Brighten(style.frameR, 0.04), Brighten(style.frameG, 0.04), Brighten(style.frameB, 0.04), math.min(1, style.frameA + 0.03))
            ItemButtonStyle.SetBorderColor(
                self,
                Brighten(self.StyleBorderBaseR or 0.34, 0.10),
                Brighten(self.StyleBorderBaseG or 0.34, 0.10),
                Brighten(self.StyleBorderBaseB or 0.34, 0.10),
                self.StyleBorderBaseA or 0.98
            )
            if self.StyleGlow then self.StyleGlow:Hide() end
            if self.icon and self.icon.SetDesaturated then
                self.icon:SetDesaturated(false)
            end
        end
        local function SetDrag(self)
            if not self.StyleBG or not self.StyleBorder then return end
            local style = ItemButtonStyle.GetConfig()
            self._styleDragging = true
            self:SetAlpha(math.max(0.1, (self._baseAlpha or 1) * 0.72))
            self.StyleBG:SetBackdropColor(Brighten(style.frameR, 0.07), Brighten(style.frameG, 0.07), Brighten(style.frameB, 0.07), math.min(1, style.frameA + 0.06))
            ItemButtonStyle.SetBorderColor(
                self,
                Brighten(self.StyleBorderBaseR or 0.34, 0.20),
                Brighten(self.StyleBorderBaseG or 0.34, 0.20),
                Brighten(self.StyleBorderBaseB or 0.34, 0.20),
                1
            )
            if self.StyleGlow then self.StyleGlow:Hide() end
            if self.icon and self.icon.SetDesaturated then
                self.icon:SetDesaturated(true)
            end
        end

        button:HookScript("OnEnter", SetHover)
        button:HookScript("OnLeave", SetIdle)
        button:HookScript("OnMouseDown", SetDrag)
        button:HookScript("OnMouseUp", function(self)
            self._styleDragging = false
            if self:IsMouseOver() then SetHover(self) else SetIdle(self) end
        end)
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
        button.StyleStateHooks = true
        SetIdle(button)
    end
end

function ItemButtonStyle.UpdateBorderForItem(button, item, qualityEnabled)
    if not button or not button.StyleBorder then
        return
    end
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
end
