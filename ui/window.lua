local _, ns = ...
local LunaBags = ns.LunaBags

local WindowChrome = LunaBags and LunaBags:CreateModule("windowChrome") or {}
ns.WindowChrome = WindowChrome

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

function WindowChrome.GetAppearanceConfig(cfg)
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

function WindowChrome.ApplyAppearance(frame, cfg)
    if not frame then
        return
    end
    cfg = WindowChrome.GetAppearanceConfig(cfg)
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
    if frame.SearchPanel and frame.SearchPanel.SetBackdropColor then
        frame.SearchPanel:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity * 0.95))
    end
    if frame.TopRail and frame.TopRail.SetBackdropColor then
        frame.TopRail:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity))
    end
    if frame.BottomRail and frame.BottomRail.SetBackdropColor then
        frame.BottomRail:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity))
    end
    if frame.BagSlots and frame.BagSlots.SetBackdropColor then
        frame.BagSlots:SetBackdropColor(wr * 0.7, wg * 0.7, wb * 0.7, math.min(1, windowOpacity))
    end
    if frame.KeyringPanel and frame.KeyringPanel.SetBackdropColor then
        frame.KeyringPanel:SetBackdropColor(wr * 0.25, wg * 0.25, wb * 0.25, math.min(1, windowOpacity))
    end
end

function WindowChrome.EnsureFrame(frame, owner, opts)
    if not frame then
        return
    end
    opts = opts or {}
    local level = tonumber(opts.level) or 40
    frame:SetFrameStrata(opts.strata or "DIALOG")
    frame:SetFrameLevel(level)
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end

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
            if owner and owner.frame and owner.frame:IsMovable() then
                owner.frame:StartMoving()
            end
        end)
        frame.HeaderDrag:SetScript("OnDragStop", function()
            if owner and owner.frame then
                owner.frame:StopMovingOrSizing()
                if owner.SavePosition then
                    owner:SavePosition()
                end
            end
        end)
    end
    frame.HeaderDrag:ClearAllPoints()
    frame.HeaderDrag:SetPoint("TOPLEFT", frame.TitleBarBg, "TOPLEFT", 0, 0)
    frame.HeaderDrag:SetPoint("BOTTOMRIGHT", frame.TitleBarBg, "BOTTOMRIGHT", 0, 0)
    frame.HeaderDrag:SetFrameLevel(level + 8)

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
end

function WindowChrome.EnsureSearchPanel(frame)
    if not frame then
        return
    end
    if not frame.SearchPanel then
        frame.SearchPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.SearchPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame.SearchPanel:SetBackdropBorderColor(0.26, 0.26, 0.26, 0.95)
    end
    frame.SearchPanel:ClearAllPoints()
    frame.SearchPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -29)
    frame.SearchPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -29)
    frame.SearchPanel:SetHeight(28)
end

function WindowChrome.EnsureStatusBar(frame, key)
    if not frame then
        return nil
    end
    key = key or "MoneyBar"
    if not frame[key] then
        frame[key] = CreateFrame("StatusBar", nil, frame)
        frame[key]:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    local bar = frame[key]
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
    bar:SetHeight(28)
    if bar.SetStatusBarColor then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetStatusBarColor(0, 0, 0, 0)
    end
    if bar.GetStatusBarTexture then
        local tex = bar:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
    end
    if not bar.Label then
        bar.Label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bar.Label:SetPoint("LEFT", bar, "LEFT", 8, 0)
    end
    if not bar.Text then
        bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bar.Text:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    end
    bar.Label:SetFontObject("GameFontNormal")
    bar.Label:SetTextColor(1, 1, 1, 1)
    bar.Text:SetFontObject("GameFontNormal")
    bar.Text:SetTextColor(1, 1, 1, 1)
    return bar
end
