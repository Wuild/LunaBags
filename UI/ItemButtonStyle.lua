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

function ItemButtonStyle.Apply(button)
    if not button then
        return
    end

    if not button.StyleBG then
        button.StyleBG = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBG:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.StyleBG:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.StyleBG:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        button.StyleBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        button.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
    end

    if not button.StyleBorder then
        button.StyleBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.StyleBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.StyleBorder:SetFrameLevel(button:GetFrameLevel() + 2)
        button.StyleBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button.StyleBorder:SetBackdropBorderColor(0.34, 0.34, 0.34, 0.95)
    end

    if not button.StyleGlow then
        button.StyleGlow = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.StyleGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.StyleGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.StyleGlow:SetFrameLevel(button:GetFrameLevel() + 3)
        button.StyleGlow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        button.StyleGlow:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.85)
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
            if self._styleDragging then return end
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(0.13, 0.13, 0.13, 0.92)
            self.StyleBorder:SetBackdropBorderColor(
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
            if self._styleDragging then return end
            self:SetAlpha(self._baseAlpha or 1)
            self.StyleBG:SetBackdropColor(0.17, 0.17, 0.17, 0.95)
            self.StyleBorder:SetBackdropBorderColor(
                Brighten(self.StyleBorderBaseR or 0.34, 0.10),
                Brighten(self.StyleBorderBaseG or 0.34, 0.10),
                Brighten(self.StyleBorderBaseB or 0.34, 0.10),
                self.StyleBorderBaseA or 0.98
            )
            if self.StyleGlow then
                self.StyleGlow:SetBackdropBorderColor(
                    Brighten(self.StyleBorderBaseR or 0.34, 0.18),
                    Brighten(self.StyleBorderBaseG or 0.34, 0.18),
                    Brighten(self.StyleBorderBaseB or 0.34, 0.18),
                    0.9
                )
                self.StyleGlow:Show()
            end
            if self.icon and self.icon.SetDesaturated then
                self.icon:SetDesaturated(false)
            end
        end
        local function SetDrag(self)
            if not self.StyleBG or not self.StyleBorder then return end
            self._styleDragging = true
            self:SetAlpha(math.max(0.1, (self._baseAlpha or 1) * 0.72))
            self.StyleBG:SetBackdropColor(0.20, 0.20, 0.20, 0.98)
            self.StyleBorder:SetBackdropBorderColor(
                Brighten(self.StyleBorderBaseR or 0.34, 0.20),
                Brighten(self.StyleBorderBaseG or 0.34, 0.20),
                Brighten(self.StyleBorderBaseB or 0.34, 0.20),
                1
            )
            if self.StyleGlow then
                self.StyleGlow:SetBackdropBorderColor(
                    Brighten(self.StyleBorderBaseR or 0.34, 0.22),
                    Brighten(self.StyleBorderBaseG or 0.34, 0.22),
                    Brighten(self.StyleBorderBaseB or 0.34, 0.22),
                    0.95
                )
                self.StyleGlow:Show()
            end
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
    button.StyleBorderBaseR, button.StyleBorderBaseG, button.StyleBorderBaseB, button.StyleBorderBaseA = r, g, b, a
    button.StyleBorder:SetBackdropBorderColor(r, g, b, a)
    if button.IconBorder then button.IconBorder:SetAlpha(0); button.IconBorder:Hide() end
    if button.Background then button.Background:SetTexture(nil); button.Background:Hide() end
    if button.IconOverlay then button.IconOverlay:SetTexture(nil); button.IconOverlay:Hide() end
end
