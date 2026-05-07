-- LuckyRichSettings: 3-column high-fidelity settings panel layout.
-- Adds LuckySettings:NewRichPanel() — a richer alternative to NewPanel for
-- addons that want grouped navigation, hover descriptions, and a screenshot
-- About panel. Coexists with NewPanel/Builder (the simpler single-column API).
--
-- Usage:
--   local panel = LuckySettings:NewRichPanel("My Addon", {
--       addonFolder = "MyAddon_Folder",  -- for resolving image paths
--       imagesRoot  = "images",          -- subfolder under the addon
--   })
--   local g = panel:Group("General")
--   g:Toggle{ label = "...", desc = "...", checked = ..., onToggle = ... }
--   g:Slider{ label = "...", min = 1, max = 10, value = ..., onChanged = ... }
--   g:Button{ label = "Configure…", parent = "Some Toggle", onClick = ... }

local PREFIX = "|cffc9a84c[LuckyRichSettings]|r"
local devLog -- forward declaration; initialized lazily

local function Log(...)
    if not devLog then
        if LuckyLog and LuckyLog.New then
            devLog = LuckyLog:New(PREFIX, function()
                return LuckySettingsDB and LuckySettingsDB.debugMode
            end)
        else
            devLog = function() end
        end
    end
    devLog(...)
end

local R = {
    bg          = { 0.078, 0.071, 0.035 },
    bg2         = { 0.059, 0.051, 0.035 },
    bg3         = { 0.043, 0.039, 0.027 },
    accent      = { 0.784, 0.565, 0.165 },
    accentLight = { 0.910, 0.690, 0.251 },
    accentBg    = { 0.784, 0.565, 0.165, 0.10 },
    text        = { 0.831, 0.788, 0.690 },
    textDim     = { 0.478, 0.431, 0.345 },
    textFaint   = { 0.227, 0.204, 0.157 },
    warn        = { 0.816, 0.314, 0.314 },
    success     = { 0.353, 0.620, 0.290 },
    border      = { 1.0, 0.824, 0.392, 0.08 },
    border2     = { 1.0, 0.824, 0.392, 0.15 },
}

local R_FONT = "Fonts\\FRIZQT__.TTF"

local function rFillBg(parent, color, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end

local function rEdgeRule(parent, edge, color)
    local t = parent:CreateTexture(nil, "BORDER")
    if edge == "TOP" or edge == "BOTTOM" then
        t:SetHeight(1)
        t:SetPoint(edge .. "LEFT")
        t:SetPoint(edge .. "RIGHT")
    else
        t:SetWidth(1)
        t:SetPoint("TOP" .. edge)
        t:SetPoint("BOTTOM" .. edge)
    end
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end

local RichBuilder = {}; RichBuilder.__index = RichBuilder
local RichGroup   = {}; RichGroup.__index   = RichGroup

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function isVersionRecent(panel, since)
    if not since or not panel.recentVersions then return false end
    for _, v in ipairs(panel.recentVersions) do
        if v == since then return true end
    end
    return false
end

local function firstRealSetting(group)
    if not group then return nil end
    for _, s in ipairs(group.settings) do
        if not s.isSection then return s end
    end
    return nil
end

local function makeNewBadge(parent, anchor)
    local f = CreateFrame("Frame", nil, parent)
    local txt = f:CreateFontString(nil, "OVERLAY")
    txt:SetFont(R_FONT, 11, "")
    txt:SetText("NEW")
    txt:SetTextColor(0.08, 0.06, 0.02)
    txt:SetPoint("CENTER", 0, 0)
    local w = math.ceil(txt:GetStringWidth()) + 12
    f:SetSize(w, 16)
    f:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(R.accentLight[1], R.accentLight[2], R.accentLight[3], 1)
    return f
end

-- ─── Left nav ─────────────────────────────────────────────────────────────────

local function styleNav(btn, active)
    if active then
        btn.label:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
        btn.indicator:Show()
        btn.bg:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.10)
    else
        btn.label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
        btn.indicator:Hide()
        btn.bg:SetColorTexture(0, 0, 0, 0)
    end
end

local function makeNavButton(panel, group, index)
    local btn = CreateFrame("Button", nil, panel.nav)
    btn:SetHeight(34)
    btn:SetPoint("LEFT")
    btn:SetPoint("RIGHT")
    if index == 1 then
        btn:SetPoint("TOP", 0, -4)
    else
        btn:SetPoint("TOP", panel.groups[index - 1].navButton, "BOTTOM", 0, 0)
    end

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0, 0, 0, 0)

    btn.indicator = btn:CreateTexture(nil, "ARTWORK")
    btn.indicator:SetWidth(2)
    btn.indicator:SetPoint("TOPLEFT")
    btn.indicator:SetPoint("BOTTOMLEFT")
    btn.indicator:SetColorTexture(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    btn.indicator:Hide()

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(R_FONT, 12, "")
    btn.label:SetPoint("LEFT", 12, 0)
    btn.label:SetPoint("RIGHT", -8, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(true)
    btn.label:SetText(group.name)

    btn:SetScript("OnEnter", function(self)
        if panel.activeGroup ~= group then
            self.label:SetTextColor(R.text[1], R.text[2], R.text[3])
        end
    end)
    btn:SetScript("OnLeave", function(self)
        styleNav(self, panel.activeGroup == group)
    end)
    btn:SetScript("OnClick", function() panel:SetActiveGroup(group) end)

    styleNav(btn, false)
    return btn
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

    -- Warning row (hidden by default)
    local warnHolder = CreateFrame("Frame", nil, A, "BackdropTemplate")
    warnHolder:SetBackdrop(LuckyUI.Backdrop)
    warnHolder:SetBackdropColor(R.warn[1], R.warn[2], R.warn[3], 0.07)
    warnHolder:SetBackdropBorderColor(R.warn[1], R.warn[2], R.warn[3], 0.18)
    local warn = warnHolder:CreateFontString(nil, "OVERLAY")
    warn:SetFont(R_FONT, 11, "")
    warn:SetPoint("TOPLEFT", 8, -6)
    warn:SetPoint("BOTTOMRIGHT", -8, 6)
    warn:SetTextColor(R.warn[1], R.warn[2], R.warn[3])
    warn:SetJustifyH("LEFT")
    warn:SetSpacing(3)
    warnHolder:Hide()
    A.warnHolder = warnHolder
    A.warn = warn

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

    if A.warnHolder:IsShown() then
        A.warnHolder:ClearAllPoints()
        A.warnHolder:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -8)
        A.warnHolder:SetPoint("RIGHT", A, "RIGHT", -10, 0)
        local h = A.warn:GetStringHeight()
        if h <= 0 then h = 14 end
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
    local A = panel.about
    if not s then
        A.name:SetText("")
        A.desc:SetText("")
        A.imageHolder:Hide()
        A.warnHolder:Hide()
        A.rangeHolder:Hide()
        A.status:Hide()
        relayoutAbout(panel)
        return
    end

    if s.image and panel.addonFolder then
        local path = "Interface\\AddOns\\" .. panel.addonFolder .. "\\"
            .. (panel.imagesRoot and (panel.imagesRoot .. "\\") or "") .. s.image
        A.image:SetTexture(path)
        if A.image:GetTexture() then
            local size = s.imageSize or A.imageDefaultSize
            local nw, nh = size[1], size[2]
            local scale = math.min(A.imageMaxW / nw, A.imageMaxH / nh, 1)
            local w = math.floor(nw * scale + 0.5)
            local h = math.floor(nh * scale + 0.5)
            local pad = A.imagePad
            A.image:ClearAllPoints()
            A.image:SetPoint("TOPLEFT", pad, -pad)
            A.image:SetSize(w, h)
            A.imageHolder:SetSize(w + pad * 2, h + pad * 2)
            A.imageHolder:Show()
        else
            A.imageHolder:Hide()
        end
    else
        A.imageHolder:Hide()
    end

    A.name:SetText(s.label or "")
    A.desc:SetText(s.desc or s.tooltip or "")

    -- Resolve dependency warnings live
    local warningText = s.warning
    if s.requires and LuckyDeps and LuckyDeps.Check then
        local ok, msg = LuckyDeps:Check(s.requires.addon, s.requires.minVersion)
        if not ok then warningText = msg end
    end
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
        local on = s.checkbox and s.checkbox:GetChecked()
        if on then
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

-- ─── Setting rows ─────────────────────────────────────────────────────────────

local function applyEnabled(setting)
    local enabled = true
    if setting.parentSetting then
        local p = setting.parentSetting
        if p.type == "Toggle" and p.checkbox then
            enabled = p.checkbox:GetChecked() and true or false
        end
    end
    setting.row:SetAlpha(enabled and 1 or 0.35)
    if setting.checkbox then setting.checkbox:SetEnabled(enabled) end
    if setting.slider   then setting.slider:SetEnabled(enabled) end
    if setting.button   then setting.button:SetEnabled(enabled) end
end

local function attachHover(setting, group, extraFrames)
    local function onEnter()
        group.panel:UpdateAbout(setting)
        if setting.rowHover then setting.rowHover:Show() end
    end
    local function onLeave()
        group.panel:UpdateAbout(nil)
        if setting.rowHover then setting.rowHover:Hide() end
    end
    setting.row:SetScript("OnEnter", onEnter)
    setting.row:SetScript("OnLeave", onLeave)
    if extraFrames then
        for _, f in ipairs(extraFrames) do
            f:HookScript("OnEnter", onEnter)
            f:HookScript("OnLeave", onLeave)
        end
    end
end

local function nextRowAnchor(group)
    local prev = group.settings[#group.settings]
    if prev then
        return prev.row, "BOTTOM"
    else
        return group.heading, "BOTTOM"
    end
end

local function makeRow(group, opts, height)
    local row = CreateFrame("Frame", nil, group.content)
    row:EnableMouse(true)
    row:SetHeight(height or 32)
    local anchor, anchorEdge = nextRowAnchor(group)
    row:SetPoint("TOPLEFT", anchor, anchorEdge .. "LEFT", 0, 0)
    row:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", 0, 0)

    -- Hover highlight
    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.06)
    hl:Hide()

    -- Child indent: left rule
    if opts.parent then
        local leftRule = row:CreateTexture(nil, "BORDER")
        leftRule:SetWidth(2)
        leftRule:SetPoint("TOPLEFT", 16, -4)
        leftRule:SetPoint("BOTTOMLEFT", 16, 4)
        leftRule:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.20)
    end

    return row, hl
end

local function indentForOpts(opts)
    return opts.parent and 30 or 14
end

function RichGroup:Toggle(opts)
    local row, hl = makeRow(self, opts, 32)
    local indent = indentForOpts(opts)

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("LEFT", indent, 0)
    cb:SetChecked(opts.checked)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetTextColor(R.text[1], R.text[2], R.text[3])
    label:SetText(opts.label)

    if isVersionRecent(self.panel, opts.since) then
        makeNewBadge(row, label)
    end

    local setting = {
        type      = "Toggle",
        label     = opts.label,
        desc      = opts.desc,
        tooltip   = opts.tooltip,
        image     = opts.image,
        imageSize = opts.imageSize,
        warning   = opts.warning,
        requires  = opts.requires,
        since     = opts.since,
        row      = row,
        rowHover = hl,
        checkbox = cb,
        parent   = opts.parent,
    }

    table.insert(self.settings, setting)
    self.byLabel[opts.label] = setting

    if opts.parent then
        setting.parentSetting = self.byLabel[opts.parent]
        applyEnabled(setting)
    end

    local group = self
    cb:SetScript("OnClick", function(c)
        local v = c:GetChecked() and true or false
        if opts.onToggle then opts.onToggle(v) end
        for _, s in ipairs(group.settings) do
            if s.parentSetting == setting then applyEnabled(s) end
        end
        group.panel:UpdateAbout(setting)
    end)

    attachHover(setting, self, { cb })
    return self
end

function RichGroup:Slider(opts)
    local row, hl = makeRow(self, opts, 44)
    local indent = indentForOpts(opts)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetPoint("TOPLEFT", indent, -4)
    label:SetTextColor(R.text[1], R.text[2], R.text[3])
    label:SetText(opts.label)

    if isVersionRecent(self.panel, opts.since) then
        makeNewBadge(row, label)
    end

    local slider = CreateFrame("Slider", "LuckySettings_RichSlider_" .. (opts.key or opts.label),
        row, "OptionsSliderTemplate")
    slider:SetWidth(160)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    slider:SetMinMaxValues(opts.min, opts.max)
    slider:SetValueStep(opts.step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(opts.value)
    slider.Low:SetText(opts.min)
    slider.High:SetText(opts.max)

    local valueText = row:CreateFontString(nil, "OVERLAY")
    valueText:SetFont(R_FONT, 12, "")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    valueText:SetText(tostring(opts.value) .. (opts.suffix or ""))

    local setting = {
        type      = "Slider",
        label     = opts.label,
        desc      = opts.desc,
        tooltip   = opts.tooltip,
        image     = opts.image,
        imageSize = opts.imageSize,
        warning   = opts.warning,
        since     = opts.since,
        min       = opts.min,
        max       = opts.max,
        suffix    = opts.suffix,
        row      = row,
        rowHover = hl,
        slider   = slider,
        parent   = opts.parent,
    }

    slider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val + 0.5)
        valueText:SetText(tostring(val) .. (opts.suffix or ""))
        if opts.onChanged then opts.onChanged(val) end
    end)

    table.insert(self.settings, setting)
    self.byLabel[opts.label] = setting

    if opts.parent then
        setting.parentSetting = self.byLabel[opts.parent]
        applyEnabled(setting)
    end

    attachHover(setting, self, { slider })
    return self
end

-- ─── MultiSelect (checkbox dropdown for picking N of M options) ─────────────
--
-- opts:
--   label     string         row label
--   desc      string         hover description
--   parent    string?        parent toggle label (enables/disables this row)
--   options   table[]        { { key, label }, ... }
--   isChecked function(key)  returns boolean for current state
--   onToggle  function(key, checked)
--   summarize function(checkedLabels[])?  returns the dropdown summary text
--
function RichGroup:MultiSelect(opts)
    local row, hl = makeRow(self, opts, 32)
    local indent = indentForOpts(opts)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetPoint("LEFT", indent, 0)
    label:SetTextColor(R.text[1], R.text[2], R.text[3])
    label:SetText(opts.label)

    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    dd:SetPoint("RIGHT", -8, 0)
    UIDropDownMenu_SetWidth(dd, 150)

    local function checkedLabels()
        local out = {}
        for _, o in ipairs(opts.options) do
            if opts.isChecked(o.key) then table.insert(out, o.label) end
        end
        return out
    end

    local function defaultSummary(labels)
        if #labels == 0 then return "None" end
        if #labels == #opts.options then return "All" end
        if #labels <= 2 then return table.concat(labels, ", ") end
        return string.format("%d of %d", #labels, #opts.options)
    end

    local function refreshSummary()
        local labels = checkedLabels()
        local fn = opts.summarize or defaultSummary
        UIDropDownMenu_SetText(dd, fn(labels))
    end

    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, o in ipairs(opts.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text             = o.label
            info.checked          = opts.isChecked(o.key)
            info.keepShownOnClick = true
            info.isNotRadio       = true
            info.func             = function(_, _, _, checked)
                opts.onToggle(o.key, checked)
                refreshSummary()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    refreshSummary()

    local setting = {
        type     = "MultiSelect",
        label    = opts.label,
        desc     = opts.desc,
        tooltip  = opts.tooltip,
        warning  = opts.warning,
        since    = opts.since,
        row      = row,
        rowHover = hl,
        dropdown = dd,
        parent   = opts.parent,
    }
    table.insert(self.settings, setting)
    self.byLabel[opts.label] = setting

    if opts.parent then
        setting.parentSetting = self.byLabel[opts.parent]
        applyEnabled(setting)
    end

    attachHover(setting, self, { dd })
    return self
end

function RichGroup:Button(opts)
    local row, hl = makeRow(self, opts, 32)
    local indent = indentForOpts(opts)

    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(opts.width or 140, 22)
    btn:SetPoint("LEFT", indent, 0)
    btn:SetText(opts.label)
    btn:SetScript("OnClick", function() if opts.onClick then opts.onClick() end end)

    if isVersionRecent(self.panel, opts.since) then
        makeNewBadge(row, btn)
    end

    local setting = {
        type      = "Button",
        label     = opts.label,
        desc      = opts.desc,
        tooltip   = opts.tooltip,
        image     = opts.image,
        imageSize = opts.imageSize,
        warning   = opts.warning,
        since     = opts.since,
        row      = row,
        rowHover = hl,
        button   = btn,
        parent   = opts.parent,
    }

    table.insert(self.settings, setting)
    self.byLabel[opts.label] = setting

    if opts.parent then
        setting.parentSetting = self.byLabel[opts.parent]
        applyEnabled(setting)
    end

    attachHover(setting, self, { btn })
    return self
end

-- ─── Label (read-only key-value info row) ─────────────────────────────────────

function RichGroup:Label(opts)
    local frame = CreateFrame("Frame", nil, self.content)
    frame:SetHeight(22)
    local anchor, anchorEdge = nextRowAnchor(self)
    frame:SetPoint("TOPLEFT", anchor, anchorEdge .. "LEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", 0, 0)

    local key = frame:CreateFontString(nil, "OVERLAY")
    key:SetFont(R_FONT, 11, "")
    key:SetPoint("LEFT", 14, 0)
    key:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    key:SetText(opts.label)

    local val = frame:CreateFontString(nil, "OVERLAY")
    val:SetFont(R_FONT, 11, "")
    val:SetPoint("RIGHT", -14, 0)
    val:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    val:SetText(opts.value)

    table.insert(self.settings, { row = frame, isSection = true })
    return self
end

-- ─── Bottom-anchored rows (pinned to bottom of group content) ────────────────
-- Rows added via BottomLabel/BottomSection stack from bottom upward in the
-- order they're added. They live outside the normal top-down flow used by
-- toggles/sliders/sections, so adding more standard rows above doesn't push
-- them around.

local function relayoutBottom(group)
    local items = group.bottomSettings
    if not items or #items == 0 then return end
    local totalH = 0
    for _, it in ipairs(items) do totalH = totalH + it.row:GetHeight() end
    local first = items[1].row
    first:ClearAllPoints()
    first:SetPoint("TOPLEFT",  group.content, "BOTTOMLEFT",  0, totalH + 12)
    first:SetPoint("TOPRIGHT", group.content, "BOTTOMRIGHT", 0, totalH + 12)
end

function RichGroup:BottomLabel(opts)
    self.bottomSettings = self.bottomSettings or {}
    local frame = CreateFrame("Frame", nil, self.content)
    frame:SetHeight(22)

    local prev = self.bottomSettings[#self.bottomSettings]
    if prev then
        frame:SetPoint("TOPLEFT",  prev.row, "BOTTOMLEFT",  0, 0)
        frame:SetPoint("TOPRIGHT", prev.row, "BOTTOMRIGHT", 0, 0)
    end

    local key = frame:CreateFontString(nil, "OVERLAY")
    key:SetFont(R_FONT, 11, "")
    key:SetPoint("LEFT", 14, 0)
    key:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    key:SetText(opts.label)

    local val = frame:CreateFontString(nil, "OVERLAY")
    val:SetFont(R_FONT, 11, "")
    val:SetPoint("RIGHT", -14, 0)
    val:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    val:SetText(opts.value)

    table.insert(self.bottomSettings, { row = frame })
    relayoutBottom(self)
    return self
end

function RichGroup:BottomSection(name)
    self.bottomSettings = self.bottomSettings or {}
    local frame = CreateFrame("Frame", nil, self.content)
    frame:SetHeight(28)

    local prev = self.bottomSettings[#self.bottomSettings]
    if prev then
        frame:SetPoint("TOPLEFT",  prev.row, "BOTTOMLEFT",  0, 0)
        frame:SetPoint("TOPRIGHT", prev.row, "BOTTOMRIGHT", 0, 0)
    end

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 10, "")
    label:SetPoint("BOTTOMLEFT", 14, 4)
    label:SetText(string.upper(name))
    label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 1)
    rule:SetPoint("RIGHT", -14, 1)
    rule:SetColorTexture(R.border[1], R.border[2], R.border[3], R.border[4])

    table.insert(self.bottomSettings, { row = frame })
    relayoutBottom(self)
    return self
end

-- ─── Section heading (sub-group within a group) ──────────────────────────────

function RichGroup:Section(name)
    local frame = CreateFrame("Frame", nil, self.content)
    frame:SetHeight(28)
    local anchor, anchorEdge = nextRowAnchor(self)
    frame:SetPoint("TOPLEFT", anchor, anchorEdge .. "LEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", 0, 0)

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 10, "")
    label:SetPoint("BOTTOMLEFT", 14, 4)
    label:SetText(string.upper(name))
    label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 1)
    rule:SetPoint("RIGHT", -14, 1)
    rule:SetColorTexture(R.border[1], R.border[2], R.border[3], R.border[4])

    table.insert(self.settings, { row = frame, isSection = true, name = name })
    return self
end

-- ─── Card (read-only navigation row, used in What's New) ──────────────────────

function RichGroup:Card(opts)
    local row = CreateFrame("Button", nil, self.content)
    row:EnableMouse(true)
    row:SetHeight(32)
    local anchor, anchorEdge = nextRowAnchor(self)
    row:SetPoint("TOPLEFT", anchor, anchorEdge .. "LEFT", 0, 0)
    row:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", 0, 0)

    local hl = row:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.06)
    hl:Hide()

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetPoint("LEFT", 14, 0)
    label:SetTextColor(R.text[1], R.text[2], R.text[3])
    label:SetText(opts.label)

    local versionTag = row:CreateFontString(nil, "OVERLAY")
    versionTag:SetFont(R_FONT, 10, "")
    versionTag:SetPoint("RIGHT", -14, 0)
    versionTag:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
    versionTag:SetText(opts.since and ("v" .. opts.since) or "")

    local source = opts.source
    local sourceGroup = opts.sourceGroup
    local panel = self.panel
    row:SetScript("OnEnter", function()
        hl:Show()
        panel:UpdateAbout(source)
    end)
    row:SetScript("OnLeave", function()
        hl:Hide()
        panel:UpdateAbout(nil)
    end)
    row:SetScript("OnClick", function()
        panel:SetActiveGroup(sourceGroup)
    end)

    -- Mirror source fields so default-show (non-hover) on this group works.
    local entry = {
        type      = source.type,
        label     = source.label,
        desc      = source.desc,
        tooltip   = source.tooltip,
        image     = source.image,
        imageSize = source.imageSize,
        warning   = source.warning,
        requires  = source.requires,
        since     = source.since,
        row       = row,
        rowHover  = hl,
        isCard    = true,
    }
    table.insert(self.settings, entry)
    return self
end

-- ─── Group / Panel ────────────────────────────────────────────────────────────

function RichBuilder:Group(name)
    local content = CreateFrame("Frame", nil, self.center)
    content:SetAllPoints()
    content:Hide()

    local heading = content:CreateFontString(nil, "OVERLAY")
    heading:SetFont(R_FONT, 11, "")
    heading:SetPoint("TOPLEFT", 14, -10)
    heading:SetPoint("RIGHT", -14, 0)
    heading:SetJustifyH("LEFT")
    heading:SetText(string.upper(name))
    heading:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])

    local rule = content:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    rule:SetPoint("RIGHT", -14, 0)
    rule:SetColorTexture(R.border[1], R.border[2], R.border[3], R.border[4])

    local group = setmetatable({
        name       = name,
        panel      = self,
        content    = content,
        heading    = rule, -- rows anchor below the rule
        settings   = {},
        byLabel    = {},
    }, RichGroup)

    table.insert(self.groups, group)
    group.navButton = makeNavButton(self, group, #self.groups)

    if #self.groups == 1 then self:SetActiveGroup(group) end

    return group
end

function RichBuilder:SetActiveGroup(group)
    if self.activeGroup == group then return end
    if self.activeGroup then
        self.activeGroup.content:Hide()
        styleNav(self.activeGroup.navButton, false)
    end
    self.activeGroup = group
    group.content:Show()
    styleNav(group.navButton, true)
    self:UpdateAbout(nil) -- falls back to first setting in active group
end

function RichBuilder:OnOpen(fn)
    self._onOpen = fn
end

-- Re-anchor every nav button from scratch (used after re-ordering self.groups).
function RichBuilder:_relayoutNav()
    for i, g in ipairs(self.groups) do
        local btn = g.navButton
        btn:ClearAllPoints()
        btn:SetPoint("LEFT")
        btn:SetPoint("RIGHT")
        if i == 1 then
            btn:SetPoint("TOP", 0, -4)
        else
            btn:SetPoint("TOP", self.groups[i - 1].navButton, "BOTTOM", 0, 0)
        end
    end
end

-- Call after all groups/settings are added. Scans for settings flagged with a
-- `since` version in `recentVersions` and prepends a "What's New" group that
-- mirrors them as clickable cards. Cards activate the source group on click.
function RichBuilder:Finalize()
    if not self.recentVersions then return end

    local grouped = {}
    for _, g in ipairs(self.groups) do
        local items = {}
        for _, s in ipairs(g.settings) do
            if not s.isSection and not s.isCard
               and s.since and isVersionRecent(self, s.since) then
                table.insert(items, s)
            end
        end
        if #items > 0 then
            table.insert(grouped, { group = g, items = items })
        end
    end

    if #grouped == 0 then return end

    local whatsNew = self:Group("What's New")
    -- Move What's New to position 1
    table.remove(self.groups) -- pop from end
    table.insert(self.groups, 1, whatsNew)

    for _, gn in ipairs(grouped) do
        whatsNew:Section(gn.group.name)
        for _, s in ipairs(gn.items) do
            whatsNew:Card({
                label       = s.label,
                since       = s.since,
                source      = s,
                sourceGroup = gn.group,
            })
        end
    end

    self:_relayoutNav()
    self:SetActiveGroup(whatsNew)
end

function RichBuilder:Open()
    LuckySettings:Open(self.category)
end

-- ─── Factory ──────────────────────────────────────────────────────────────────

-- Public theme handles for popups/dialogs that want to match the rich panel.
LuckySettings.Rich = {
    Theme    = R,
    Font     = R_FONT,
    FillBg   = rFillBg,
    EdgeRule = rEdgeRule,
}

--- Create a 3-column rich settings panel.
---@param displayName string
---@param opts table?  { addonFolder?: string, imagesRoot?: string }
---@return table builder
function LuckySettings:NewRichPanel(displayName, opts)
    Log("NewRichPanel called for:", displayName)
    opts = opts or {}

    local canvas = CreateFrame("Frame")
    canvas.name = displayName
    canvas:Hide()

    -- Content wrapper. The Settings canvas adds ~10px inset on all sides;
    -- negative offsets reclaim that space so backgrounds extend flush to the
    -- visible Settings frame edges (matches Plumber's pattern).
    local content = CreateFrame("Frame", nil, canvas)
    content:SetPoint("TOPLEFT", -14, 10)
    content:SetPoint("BOTTOMRIGHT", 0,0)

    -- Background + columns
    rFillBg(content, R.bg)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, content)
    titleBar:SetHeight(40)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    rFillBg(titleBar, R.bg2)
    rEdgeRule(titleBar, "BOTTOM", R.border)

    local titleL = titleBar:CreateFontString(nil, "OVERLAY")
    titleL:SetFont(R_FONT, 16, "")
    titleL:SetPoint("LEFT", 14, 0)
    titleL:SetText(displayName)
    titleL:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])

    local titleR = titleBar:CreateFontString(nil, "OVERLAY")
    titleR:SetFont(R_FONT, 11, "")
    titleR:SetPoint("RIGHT", -14, 0)
    titleR:SetText("ADDON SETTINGS")
    titleR:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])

    -- Three columns under title bar
    local nav = CreateFrame("Frame", nil, content)
    nav:SetWidth(112)
    nav:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT")
    rFillBg(nav, R.bg3)
    rEdgeRule(nav, "RIGHT", R.border)

    local about = CreateFrame("Frame", nil, content)
    about:SetWidth(210)
    about:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    about:SetPoint("BOTTOMRIGHT")

    local center = CreateFrame("Frame", nil, content)
    center:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
    center:SetPoint("BOTTOMRIGHT", about, "BOTTOMLEFT", 0, 0)
    rFillBg(center, R.bg)

    local builder = setmetatable({
        addonFolder    = opts.addonFolder,
        imagesRoot     = opts.imagesRoot,
        recentVersions = opts.recentVersions, -- list of versions whose settings get a NEW badge
        canvas         = canvas,
        titleBar       = titleBar,
        nav            = nav,
        center         = center,
        about          = about,
        groups         = {},
    }, RichBuilder)

    buildAbout(builder)

    builder.category = self:Register(canvas, displayName)

    canvas:HookScript("OnShow", function()
        if builder._onOpen then builder._onOpen() end
        if builder.activeGroup then
            aboutShow(builder, builder.hoveredSetting or firstRealSetting(builder.activeGroup))
        end
    end)

    return builder
end
