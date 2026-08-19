-- LuckyRichSettings/Rows.lua: the row builders attached to RichGroup (toggles,
-- sliders, selects, multi-selects, buttons, labels, notices, bottom rows, sections,
-- fill regions, and What's New cards), plus enabled-state propagation and the
-- live re-read of function-valued row state.

if LuckysUtilsSkipLoad then return end

local ns = select(2, ...)
local Rich = ns.Rich

local R               = Rich.R
local R_FONT          = Rich.Font
local RichGroup       = Rich.RichGroup
local isVersionRecent = Rich.isVersionRecent

-- Row state (`checked` on Toggle, `value` on Slider) may be a plain value or a
-- zero-arg function. Function-valued state is re-read every time the panel is
-- shown, so changes made while it was closed (slash commands, minimap toggles)
-- can't leave stale controls. MultiSelect's isChecked already works this way.
local function resolveValue(v)
    if type(v) == "function" then return v() end
    return v
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

-- ─── Setting rows ─────────────────────────────────────────────────────────────

-- A feature whose dependency is absent cannot be switched on, so its row locks
-- the same way an explicitly disabled one does. The About pane still explains
-- why, and offers the fix when the dependency is merely switched off.
local function requiresUnmet(requires)
    return requires ~= nil and not LuckyDeps:Check(requires.addon, requires.minVersion)
end

local function applyEnabled(setting)
    local enabled = true
    if setting.disabled then
        enabled = false
    elseif setting.parentSetting then
        local p = setting.parentSetting
        if p.disabled then
            enabled = false
        elseif p.type == "Toggle" and p.checkbox then
            enabled = p.checkbox:GetChecked() and true or false
        end
    end
    setting.row:SetAlpha(enabled and 1 or 0.35)
    if setting.checkbox then setting.checkbox:SetEnabled(enabled) end
    if setting.slider   then setting.slider:SetEnabled(enabled) end
    if setting.button   then setting.button:SetEnabled(enabled) end
    if setting.dropdown then
        if enabled then
            UIDropDownMenu_EnableDropDown(setting.dropdown)
        else
            UIDropDownMenu_DisableDropDown(setting.dropdown)
        end
    end
end

-- Re-read function-valued row state across all built groups. SetChecked and
-- SetValue don't fire OnClick/onToggle, and a slider's OnValueChanged only
-- fires when the value actually differs, so this never causes spurious writes.
local function refreshLiveValues(builder)
    for _, g in ipairs(builder.groups) do
        for _, s in ipairs(g.settings) do
            if s.getChecked and s.checkbox then
                s.checkbox:SetChecked(s.getChecked() and true or false)
            end
            if s.getValue and s.slider then
                s.slider:SetValue(s.getValue())
            end
            if s.refreshSelect then s.refreshSelect() end
        end
        -- Second pass: parents are fresh now, so dependent rows re-lock.
        for _, s in ipairs(g.settings) do
            if s.parentSetting then applyEnabled(s) end
        end
    end
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

-- Rows normally flow down the group's content frame. Between BeginScroll and
-- EndScroll they flow down a scroll child instead, which is what folds the
-- What's New list into a group that already has rows of its own.
local function rowParent(group)
    return group.rowParent or group.content
end

local function nextRowAnchor(group)
    if group.lastRow then return group.lastRow, "BOTTOM" end
    if group.rowParent then return group.rowParent, "TOP" end
    return group.heading, "BOTTOM"
end

local function placeRow(group, frame)
    local anchor, anchorEdge = nextRowAnchor(group)
    frame:SetPoint("TOPLEFT", anchor, anchorEdge .. "LEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", 0, 0)
    group.lastRow = frame
    if group.rowParent then
        group.rowParentHeight = (group.rowParentHeight or 0) + frame:GetHeight()
        group.rowParent:SetHeight(group.rowParentHeight)
    end
end

local function makeRow(group, opts, height)
    local row = CreateFrame("Frame", nil, rowParent(group))
    row:EnableMouse(true)
    row:SetHeight(height or 32)
    placeRow(group, row)

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
    cb:SetChecked(resolveValue(opts.checked))

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
        note      = opts.note,
        image     = opts.image,
        imageSize = opts.imageSize,
        warning   = opts.warning,
        requires  = opts.requires,
        since     = opts.since,
        row      = row,
        rowHover = hl,
        checkbox = cb,
        parent   = opts.parent,
        disabled = opts.disabled or requiresUnmet(opts.requires),
        getChecked = type(opts.checked) == "function" and opts.checked or nil,
    }

    table.insert(self.settings, setting)
    self.byLabel[opts.label] = setting

    if opts.parent then
        setting.parentSetting = self.byLabel[opts.parent]
        -- A disabled parent locks its whole subtree, so children inherit it.
        if setting.parentSetting and setting.parentSetting.disabled then
            setting.disabled = true
        end
    end

    if setting.disabled or opts.parent then
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

    local initialValue = resolveValue(opts.value)

    local slider = CreateFrame("Slider", "LuckySettings_RichSlider_" .. (opts.key or opts.label),
        row, "OptionsSliderTemplate")
    slider:SetWidth(160)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    slider:SetMinMaxValues(opts.min, opts.max)
    slider:SetValueStep(opts.step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initialValue)
    slider.Low:SetText(opts.min)
    slider.High:SetText(opts.max)

    local valueText = row:CreateFontString(nil, "OVERLAY")
    valueText:SetFont(R_FONT, 12, "")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    valueText:SetText(tostring(initialValue) .. (opts.suffix or ""))

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
        getValue = type(opts.value) == "function" and opts.value or nil,
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

-- ─── Select (single choice from a fixed list) ────────────────────────────────
-- MultiSelect's sibling for a setting that holds one value: the same row shape
-- and dropdown template, radio buttons instead of check boxes. `value` may be a
-- plain key or a zero-arg function, which is re-read every time the panel opens.

function RichGroup:Select(opts)
    local row, hl = makeRow(self, opts, 32)
    local indent = indentForOpts(opts)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetPoint("LEFT", indent, 0)
    label:SetTextColor(R.text[1], R.text[2], R.text[3])
    label:SetText(opts.label)

    if isVersionRecent(self.panel, opts.since) then
        makeNewBadge(row, label)
    end

    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    dd:SetPoint("RIGHT", -8, 0)
    UIDropDownMenu_SetWidth(dd, opts.width or 150)

    local function labelFor(key)
        for _, o in ipairs(opts.options) do
            if o.key == key then return o.label end
        end
    end

    local function refresh()
        UIDropDownMenu_SetText(dd, labelFor(resolveValue(opts.value)) or opts.placeholder or "")
    end

    UIDropDownMenu_Initialize(dd, function(_, level)
        local selected = resolveValue(opts.value)
        for _, o in ipairs(opts.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = o.label
            info.checked = o.key == selected
            info.func    = function()
                if opts.onSelect then opts.onSelect(o.key) end
                refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    refresh()

    local setting = {
        type     = "Select",
        label    = opts.label,
        desc     = opts.desc,
        tooltip  = opts.tooltip,
        note     = opts.note,
        image    = opts.image,
        imageSize = opts.imageSize,
        warning  = opts.warning,
        since    = opts.since,
        row      = row,
        rowHover = hl,
        dropdown = dd,
        parent   = opts.parent,
        refreshSelect = refresh,
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
    local frame = CreateFrame("Frame", nil, rowParent(self))
    frame:SetHeight(22)
    placeRow(self, frame)

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

-- ─── Notice (inline informational / warning banner) ──────────────────────────
-- A full-width, warn-styled message box that sits in the normal row flow.
-- Use it to surface state that isn't tied to a single control, e.g. a feature
-- that's temporarily disabled. Wraps and re-measures its height when the panel
-- is first sized, so following rows reflow automatically.

function RichGroup:Notice(opts)
    local frame = CreateFrame("Frame", nil, rowParent(self))
    placeRow(self, frame)

    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -8)
    box:SetPoint("TOPRIGHT", -14, -8)
    box:SetBackdrop(LuckyUI.Backdrop)
    box:SetBackdropColor(R.warn[1], R.warn[2], R.warn[3], 0.07)
    box:SetBackdropBorderColor(R.warn[1], R.warn[2], R.warn[3], 0.18)

    local text = box:CreateFontString(nil, "OVERLAY")
    text:SetFont(R_FONT, 11, "")
    text:SetPoint("TOPLEFT", 8, -6)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    text:SetTextColor(R.warn[1], R.warn[2], R.warn[3])
    text:SetText(opts.text or "")

    local function resize()
        local h = text:GetStringHeight()
        if h <= 0 then h = 14 end
        box:SetHeight(h + 12)
        frame:SetHeight(h + 12 + 16)
    end
    resize()
    box:SetScript("OnSizeChanged", resize)

    table.insert(self.settings, { row = frame, isSection = true })
    return self
end

-- ─── Bottom-anchored rows (pinned to bottom of group content) ────────────────
-- Rows added via BottomLabel/BottomSection stack from bottom upward in the
-- order they're added. They live outside the normal top-down flow used by
-- toggles/sliders/sections, so adding more standard rows above doesn't push
-- them around.

-- A Fill region takes whatever height is left above the bottom rows, so it has
-- to be re-anchored whenever those rows change (they may be added after it).
local function relayoutFill(group)
    local holder = group.fillHolder
    if not holder then return end
    local first = group.bottomSettings and group.bottomSettings[1]
    if first then
        holder:SetPoint("BOTTOM", first.row, "TOP", 0, 4)
    else
        holder:SetPoint("BOTTOM", group.content, "BOTTOM", 0, 12)
    end
end

local function relayoutBottom(group)
    local items = group.bottomSettings
    if not items or #items == 0 then return end
    local totalH = 0
    for _, it in ipairs(items) do totalH = totalH + it.row:GetHeight() end
    local first = items[1].row
    first:ClearAllPoints()
    first:SetPoint("TOPLEFT",  group.content, "BOTTOMLEFT",  0, totalH + 12)
    first:SetPoint("TOPRIGHT", group.content, "BOTTOMRIGHT", 0, totalH + 12)
    relayoutFill(group)
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

function RichGroup:BottomLink(opts)
    self.bottomSettings = self.bottomSettings or {}
    local frame = CreateFrame("Button", nil, self.content)
    frame:SetHeight(22)

    local prev = self.bottomSettings[#self.bottomSettings]
    if prev then
        frame:SetPoint("TOPLEFT",  prev.row, "BOTTOMLEFT",  0, 0)
        frame:SetPoint("TOPRIGHT", prev.row, "BOTTOMRIGHT", 0, 0)
    end

    local hl = frame:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.06)
    hl:Hide()

    local key = frame:CreateFontString(nil, "OVERLAY")
    key:SetFont(R_FONT, 11, "")
    key:SetPoint("LEFT", 14, 0)
    key:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    key:SetText(opts.label)

    local val = frame:CreateFontString(nil, "OVERLAY")
    val:SetFont(R_FONT, 11, "")
    val:SetPoint("RIGHT", -14, 0)
    val:SetTextColor(R.accent[1], R.accent[2], R.accent[3])
    val:SetText(opts.value)

    frame:SetScript("OnEnter", function()
        val:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
        hl:Show()
    end)
    frame:SetScript("OnLeave", function()
        val:SetTextColor(R.accent[1], R.accent[2], R.accent[3])
        hl:Hide()
    end)
    frame:SetScript("OnClick", function()
        if opts.onClick then opts.onClick() end
    end)

    table.insert(self.bottomSettings, { row = frame })
    relayoutBottom(self)
    return self
end

--- An empty bottom row of the given height, for callers that draw their own
--- contents. Returns the frame rather than the group.
---@param height number
---@return Frame
function RichGroup:BottomFrame(height)
    self.bottomSettings = self.bottomSettings or {}
    local frame = CreateFrame("Frame", nil, self.content)
    frame:SetHeight(height)

    local prev = self.bottomSettings[#self.bottomSettings]
    if prev then
        frame:SetPoint("TOPLEFT",  prev.row, "BOTTOMLEFT",  0, 0)
        frame:SetPoint("TOPRIGHT", prev.row, "BOTTOMRIGHT", 0, 0)
    end

    table.insert(self.bottomSettings, { row = frame })
    relayoutBottom(self)
    return frame
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
    local frame = CreateFrame("Frame", nil, rowParent(self))
    frame:SetHeight(28)
    placeRow(self, frame)

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

-- ─── Fill (scrollable custom-content region) ─────────────────────────────────
-- Claims the remaining vertical space in the group below the last row and
-- returns a scroll-child frame the caller builds custom widgets in. The caller
-- must keep the returned frame's height in sync with its content so the scroll
-- range is correct. Must be the last row added to the group.

function RichGroup:Fill(inset)
    inset = inset or 14
    local holder = CreateFrame("Frame", nil, self.content)
    local anchor, anchorEdge = nextRowAnchor(self)
    holder:SetPoint("TOPLEFT",  anchor, anchorEdge .. "LEFT",  inset, -8)
    holder:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", -inset, -8)
    self.fillHolder = holder
    self.lastRow = holder
    relayoutFill(self)

    local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)

    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetSize(scroll:GetWidth() or 400, 1)
    scroll:SetScrollChild(inner)
    scroll:HookScript("OnSizeChanged", function(_, w) inner:SetWidth(w) end)

    -- Content that fits needs no scrollbar, and gives its 22px back to the rows.
    scroll:HookScript("OnScrollRangeChanged", function(self, _, yRange)
        local bar = self.ScrollBar
        if not bar then return end
        local scrollable = (yRange or self:GetVerticalScrollRange()) > 0
        bar:SetShown(scrollable)
        self:SetPoint("BOTTOMRIGHT", scrollable and -22 or 0, 0)
    end)

    table.insert(self.settings, { row = holder, isSection = true })
    return inner
end

--- Send the rows added from here on into a scrolling region that fills the
--- space left between the rows above it and the group's bottom rows. Ends at
--- EndScroll. Only one scroll region per group.
function RichGroup:BeginScroll(inset)
    local inner = self:Fill(inset)
    self.rowParent, self.lastRow, self.rowParentHeight = inner, nil, 0
    return inner
end

function RichGroup:EndScroll()
    self.rowParent, self.lastRow = nil, self.fillHolder
end

-- ─── Card (read-only navigation row, used in What's New) ──────────────────────

function RichGroup:Card(opts)
    local row = CreateFrame("Button", nil, rowParent(self))
    row:EnableMouse(true)
    row:SetHeight(32)
    placeRow(self, row)

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
    -- Includes the live checkbox/slider references and slider range so the
    -- About panel renders the correct toggle state and range, not a default.
    local entry = {
        type      = source.type,
        label     = source.label,
        desc      = source.desc,
        tooltip   = source.tooltip,
        note      = source.note,
        image     = source.image,
        imageSize = source.imageSize,
        warning   = source.warning,
        requires  = source.requires,
        since     = source.since,
        checkbox  = source.checkbox,
        slider    = source.slider,
        min       = source.min,
        max       = source.max,
        suffix    = source.suffix,
        row       = row,
        rowHover  = hl,
        isCard    = true,
    }
    table.insert(self.settings, entry)
    return self
end

Rich.refreshLiveValues = refreshLiveValues
Rich.resolveValue      = resolveValue
