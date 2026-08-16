-- LuckyRichSettings/About.lua: the About rail (hover descriptions, warnings,
-- status chips, screenshots) and the floating cursor preview for wide images.

local ns = select(2, ...)
local Rich = ns.Rich

local R                = Rich.R
local R_FONT           = Rich.Font
local rFillBg          = Rich.FillBg
local rEdgeRule        = Rich.EdgeRule
local RichBuilder      = Rich.RichBuilder
local firstRealSetting = Rich.firstRealSetting

-- ─── Floating image preview ───────────────────────────────────────────────────
-- Wide screenshots shrink to an unreadable strip inside the About rail, so those
-- are shown full size in a frame next to the cursor instead.

local PREVIEW_MAX_W, PREVIEW_MAX_H = 560, 420
local PREVIEW_PAD = 10
local PREVIEW_CURSOR_GAP = 18
local PREVIEW_SCREEN_MARGIN = 8

local imagePreview

local function getImagePreview()
    if imagePreview then return imagePreview end

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(false)
    f:SetBackdrop(LuckyUI.Backdrop)
    f:SetBackdropColor(R.bg3[1], R.bg3[2], R.bg3[3], 0.97)
    f:SetBackdropBorderColor(R.border2[1], R.border2[2], R.border2[3], 1)
    f:Hide()

    f.image = f:CreateTexture(nil, "ARTWORK")
    f.image:SetPoint("TOPLEFT", PREVIEW_PAD, -PREVIEW_PAD)

    imagePreview = f
    return f
end

local function hideImagePreview()
    if imagePreview then imagePreview:Hide() end
end

local function anchorPreviewToCursor(f)
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    -- Down and to the left, so the preview never covers the About rail.
    local w, h = f:GetSize()
    local x = cx - PREVIEW_CURSOR_GAP - w
    local y = cy - PREVIEW_CURSOR_GAP

    if x < PREVIEW_SCREEN_MARGIN then
        x = cx + PREVIEW_CURSOR_GAP
    end
    x = math.min(x, UIParent:GetWidth() - PREVIEW_SCREEN_MARGIN - w)
    x = math.max(PREVIEW_SCREEN_MARGIN, x)

    if y - h < PREVIEW_SCREEN_MARGIN then
        y = cy + PREVIEW_CURSOR_GAP + h
    end
    y = math.min(UIParent:GetHeight() - PREVIEW_SCREEN_MARGIN, y)

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function showImagePreview(path, nw, nh)
    local f = getImagePreview()
    local scale = math.min(PREVIEW_MAX_W / nw, PREVIEW_MAX_H / nh, 1)
    local w = math.floor(nw * scale + 0.5)
    local h = math.floor(nh * scale + 0.5)

    f.image:SetTexture(path)
    f.image:SetSize(w, h)
    f:SetSize(w + PREVIEW_PAD * 2, h + PREVIEW_PAD * 2)
    anchorPreviewToCursor(f)
    f:Show()
end

-- ─── About panel ──────────────────────────────────────────────────────────────

local function buildAbout(panel)
    local A = panel.about

    rFillBg(A, R.bg3)
    rEdgeRule(A, "LEFT", R.border)

    local heading = A:CreateFontString(nil, "OVERLAY")
    heading:SetFont(R_FONT, 10, "")
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetText("ABOUT")
    heading:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
    A.headingAnchor = heading

    -- Setting name
    local name = A:CreateFontString(nil, "OVERLAY")
    name:SetFont(R_FONT, 13, "")
    name:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    A.name = name

    -- Decorative rule
    local accent = A:CreateTexture(nil, "ARTWORK")
    accent:SetSize(20, 1)
    accent:SetColorTexture(R.accent[1], R.accent[2], R.accent[3])
    A.accentRule = accent

    -- Description (multiline)
    local desc = A:CreateFontString(nil, "OVERLAY")
    desc:SetFont(R_FONT, 12, "")
    desc:SetTextColor(R.text[1], R.text[2], R.text[3])
    desc:SetSpacing(4)
    desc:SetJustifyH("LEFT")
    A.desc = desc

    -- Note (subtle italic line under desc; hidden when unset)
    local note = A:CreateFontString(nil, "OVERLAY")
    note:SetFont(R_FONT, 11, "")
    note:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    note:SetSpacing(3)
    note:SetJustifyH("LEFT")
    note:Hide()
    A.note = note

    -- Warning row (hidden by default)
    local warnHolder = CreateFrame("Frame", nil, A, "BackdropTemplate")
    warnHolder:SetBackdrop(LuckyUI.Backdrop)
    warnHolder:SetBackdropColor(R.warn[1], R.warn[2], R.warn[3], 0.07)
    warnHolder:SetBackdropBorderColor(R.warn[1], R.warn[2], R.warn[3], 0.18)
    local warn = warnHolder:CreateFontString(nil, "OVERLAY")
    warn:SetFont(R_FONT, 11, "")
    warn:SetPoint("TOPLEFT", 8, -6)
    warn:SetPoint("TOPRIGHT", -8, -6)
    warn:SetTextColor(R.warn[1], R.warn[2], R.warn[3])
    warn:SetJustifyH("LEFT")
    warn:SetSpacing(3)
    warnHolder:Hide()
    A.warnHolder = warnHolder
    A.warn = warn

    -- Offered only when the dependency is installed and merely switched off,
    -- which is the one dependency failure the player can put right from here.
    local enableBtn = LuckyUI.CreateButton(warnHolder, "Enable and Reload", 140, 22, "primary")
    enableBtn:SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 0, -8)
    enableBtn:SetScript("OnClick", function(self)
        if not self.addonName then return end
        LuckyDeps:Enable(self.addonName)
        ReloadUI()
    end)
    enableBtn:Hide()
    A.enableBtn = enableBtn

    -- Slider range (hidden unless setting is a slider)
    local rangeHolder = CreateFrame("Frame", nil, A, "BackdropTemplate")
    rangeHolder:SetBackdrop(LuckyUI.Backdrop)
    rangeHolder:SetBackdropColor(0, 0, 0, 0.2)
    rangeHolder:SetBackdropBorderColor(R.border[1], R.border[2], R.border[3], R.border[4])
    rangeHolder:SetHeight(22)
    local range = rangeHolder:CreateFontString(nil, "OVERLAY")
    range:SetFont(R_FONT, 11, "")
    range:SetPoint("LEFT", 8, 0)
    range:SetPoint("RIGHT", -8, 0)
    range:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    range:SetJustifyH("LEFT")
    rangeHolder:Hide()
    A.rangeHolder = rangeHolder
    A.range = range

    -- Status chip (toggle only)
    local status = A:CreateFontString(nil, "OVERLAY")
    status:SetFont(R_FONT, 11, "")
    A.status = status
    status:Hide()

    -- Image holder wraps the image at its display size. Hidden when no image.
    local imgHolder = CreateFrame("Frame", nil, A)
    rFillBg(imgHolder, { 0, 0, 0, 0.4 })
    rEdgeRule(imgHolder, "TOP", R.border)
    local img = imgHolder:CreateTexture(nil, "ARTWORK")
    imgHolder:Hide()
    A.imageHolder = imgHolder
    A.image = img
    A.imagePad = 8
    A.imageDefaultSize = { 190, 190 }
    A.imageMaxW = 174
    A.imageMaxH = 280
    -- Below this rail scale the screenshot is too shrunken to read, so it moves
    -- to the cursor preview instead.
    A.imageMinRailScale = 0.6
end

local function relayoutAbout(panel)
    local A = panel.about

    A.name:ClearAllPoints()
    A.name:SetPoint("TOPLEFT", A.headingAnchor, "BOTTOMLEFT", 0, -10)
    A.name:SetPoint("TOPRIGHT", A, "TOPRIGHT", -10, 0)

    A.accentRule:ClearAllPoints()
    A.accentRule:SetPoint("TOPLEFT", A.name, "BOTTOMLEFT", 0, -8)

    A.desc:ClearAllPoints()
    A.desc:SetPoint("TOPLEFT", A.accentRule, "BOTTOMLEFT", 0, -8)
    A.desc:SetPoint("RIGHT", A, "RIGHT", -10, 0)

    local cursor = A.desc

    if A.note:IsShown() then
        A.note:ClearAllPoints()
        A.note:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -6)
        A.note:SetPoint("RIGHT", A, "RIGHT", -10, 0)
        cursor = A.note
    end

    if A.warnHolder:IsShown() then
        A.warnHolder:ClearAllPoints()
        A.warnHolder:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -8)
        A.warnHolder:SetPoint("RIGHT", A, "RIGHT", -10, 0)
        local h = A.warn:GetStringHeight()
        if h <= 0 then h = 14 end
        if A.enableBtn:IsShown() then h = h + A.enableBtn:GetHeight() + 8 end
        A.warnHolder:SetHeight(h + 12)
        cursor = A.warnHolder
    end

    if A.rangeHolder:IsShown() then
        A.rangeHolder:ClearAllPoints()
        A.rangeHolder:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -8)
        A.rangeHolder:SetPoint("RIGHT", A, "RIGHT", -10, 0)
        cursor = A.rangeHolder
    end

    if A.status:IsShown() then
        A.status:ClearAllPoints()
        A.status:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -10)
        cursor = A.status
    end

    if A.imageHolder:IsShown() then
        A.imageHolder:ClearAllPoints()
        A.imageHolder:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -12)
    end
end

local function aboutShow(panel, s)
    if not panel.about or not panel.about:IsShown() then
        hideImagePreview()
        return
    end
    local A = panel.about
    if not s then
        A.name:SetText("")
        A.desc:SetText("")
        A.note:Hide()
        A.imageHolder:Hide()
        hideImagePreview()
        A.warnHolder:Hide()
        A.rangeHolder:Hide()
        A.status:Hide()
        relayoutAbout(panel)
        return
    end

    A.imageHolder:Hide()
    hideImagePreview()

    if s.image and panel.addonFolder then
        local path = "Interface\\AddOns\\" .. panel.addonFolder .. "\\"
            .. (panel.imagesRoot and (panel.imagesRoot .. "\\") or "") .. s.image
        A.image:SetTexture(path)
        if A.image:GetTexture() then
            local size = s.imageSize or A.imageDefaultSize
            local nw, nh = size[1], size[2]
            local scale = math.min(A.imageMaxW / nw, A.imageMaxH / nh, 1)
            if scale < A.imageMinRailScale then
                -- Only while genuinely hovering; the group's default setting
                -- fills the rail without the cursor being over anything.
                if panel.hoveredSetting == s then
                    showImagePreview(path, nw, nh)
                end
            else
                local w = math.floor(nw * scale + 0.5)
                local h = math.floor(nh * scale + 0.5)
                local pad = A.imagePad
                A.image:ClearAllPoints()
                A.image:SetPoint("TOPLEFT", pad, -pad)
                A.image:SetSize(w, h)
                A.imageHolder:SetSize(w + pad * 2, h + pad * 2)
                A.imageHolder:Show()
            end
        end
    end

    A.name:SetText(s.label or "")
    A.desc:SetText(s.desc or s.tooltip or "")

    if s.note and s.note ~= "" then
        A.note:SetText(s.note)
        A.note:Show()
    else
        A.note:Hide()
    end

    -- Resolve dependency warnings live
    local warningText, offerEnable = s.warning, false
    if s.requires and LuckyDeps and LuckyDeps.Check then
        local ok, msg, status = LuckyDeps:Check(s.requires.addon, s.requires.minVersion)
        if not ok then
            warningText = msg
            offerEnable = status == LuckyDeps.Status.DISABLED
        end
    end
    A.enableBtn.addonName = offerEnable and s.requires.addon or nil
    A.enableBtn:SetShown(offerEnable)
    if warningText then
        A.warn:SetText(warningText)
        A.warnHolder:Show()
    else
        A.warnHolder:Hide()
    end

    if s.type == "Slider" then
        A.range:SetText(string.format("Range: %s – %s%s",
            tostring(s.min), tostring(s.max), s.suffix and (" " .. s.suffix) or ""))
        A.rangeHolder:Show()
    else
        A.rangeHolder:Hide()
    end

    if s.type == "Toggle" then
        if s.disabled then
            A.status:SetText("|A:common-icon-redx:12:12|a UNAVAILABLE")
            A.status:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
        elseif s.checkbox and s.checkbox:GetChecked() then
            A.status:SetText("|A:common-icon-checkmark:12:12|a ENABLED")
            A.status:SetTextColor(R.success[1], R.success[2], R.success[3])
        else
            A.status:SetText("|A:common-icon-redx:12:12|a DISABLED")
            A.status:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
        end
        A.status:Show()
    else
        A.status:Hide()
    end

    relayoutAbout(panel)
end

function RichBuilder:UpdateAbout(setting)
    self.hoveredSetting = setting
    aboutShow(self, setting or firstRealSetting(self.activeGroup))
end

Rich.buildAbout       = buildAbout
Rich.aboutShow        = aboutShow
Rich.hideImagePreview = hideImagePreview
