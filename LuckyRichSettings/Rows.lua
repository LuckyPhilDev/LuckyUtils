-- LuckyRichSettings/Rows.lua: the row builders attached to RichGroup (toggles,
-- sliders, selects, multi-selects, buttons, labels, notices, bottom rows, sections,
-- fill regions, and What's New cards), plus enabled-state propagation and the
-- live re-read of function-valued row state.

if LuckysUtilsSkipLoad then return end

local ns = select(2, ...)
local Rich = ns.Rich

local R                = Rich.R
local R_FONT           = Rich.Font
local S                = LuckyUtilsStrings.richSettings
local RichGroup        = Rich.RichGroup
local isVersionRecent  = Rich.isVersionRecent
local hideImagePreview = Rich.hideImagePreview

-- Keyed by row so a warning icon does not have to be stamped onto the frame,
-- and drops with the row it belongs to.
local rowWarnIcons = setmetatable({}, { __mode = "k" })

-- Row state (`checked` on Toggle, `value` on Slider) may be a plain value or a
-- zero-arg function. Function-valued state is re-read every time the panel is
-- shown, so changes made while it was closed (slash commands, minimap toggles)
-- can't leave stale controls. MultiSelect's isChecked already works this way.
local function resolveValue(v)
    if type(v) == "function" then return v() end
    return v
end

local STRING_FIELDS = { "label", "desc", "note", "warning", "suffix", "tooltip", "placeholder" }

-- Row sugar shared by the builders. `opts[1]` is a strings table whose fields
-- fill any the row did not name itself, so `g:Toggle{ S.autoRepair, ... }`
-- carries its label, desc and note. `parent` may be that same strings table.
-- `key` binds the row to its own `db`, else the group's, else the panel's: the value becomes
-- a live read of store[key], the change handler writes it, and a handler the
-- row named runs afterwards. Without a store, `key` keeps its old meaning as a
-- frame-name suffix, so older consumers are unaffected.
local function prepareRow(group, opts, valueField, changeField)
    local strings = opts[1]
    if strings ~= nil then
        assert(type(strings) == "table" and type(strings.label) == "string",
            "settings row: the strings table needs a string label")
        for _, field in ipairs(STRING_FIELDS) do
            if opts[field] == nil then opts[field] = strings[field] end
        end
    end
    assert(type(opts.label) == "string",
        "settings row: label is required" .. (opts.key and (" (key " .. tostring(opts.key) .. ")") or ""))
    if type(opts.parent) == "table" then opts.parent = opts.parent.label end

    local store = opts.db or group.db or group.panel.db
    if not store then return end

    if opts.key and valueField then
        local key, after = opts.key, opts[changeField]
        opts[valueField] = function() return store[key] end
        opts[changeField] = function(v)
            store[key] = v
            if after then after(v) end
        end
    end
    if opts.keys then
        local keys, after = opts.keys, opts.onToggle
        opts.isChecked = function(k) return store[keys[k]] end
        opts.onToggle = function(k, checked)
            store[keys[k]] = checked
            if after then after(k, checked) end
        end
    end
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

-- Walks the whole ancestry, not just the row above: a grandchild under a ticked
-- parent is still locked when that parent's own parent is cleared.
local function isEnabled(setting)
    if setting.disabled then return false end

    local p = setting.parentSetting
    if not p then return true end
    if not isEnabled(p) then return false end

    if p.type == "Toggle" and p.checkbox then
        return p.checkbox:GetChecked() and true or false
    end
    if p.type == "Slider" and p.slider then
        -- A slider parent is a feature switched off at zero, so its children
        -- lock there the same way a cleared checkbox locks them.
        return p.slider:GetValue() ~= 0
    end
    return true
end

local function applyEnabled(setting)
    local enabled = isEnabled(setting)
    setting.row:SetAlpha(enabled and 1 or 0.35)
    if setting.checkbox then setting.checkbox:SetEnabled(enabled) end
    if setting.slider   then setting.slider:SetEnabled(enabled) end
    if setting.button   then setting.button:SetEnabled(enabled) end
    if setting.dropdown then
        -- Select is on the modern dropdown, which is a button; MultiSelect is
        -- still on the legacy frame, which has its own enable calls.
        if setting.dropdown.SetEnabled then
            setting.dropdown:SetEnabled(enabled)
        elseif enabled then
            UIDropDownMenu_EnableDropDown(setting.dropdown)
        else
            UIDropDownMenu_DisableDropDown(setting.dropdown)
        end
    end
end

-- A parent changing re-locks its whole subtree, so every managed row in the
-- group is re-applied rather than the row below it.
local function refreshEnabled(group)
    for _, setting in ipairs(group.settings) do
        if setting.parentSetting or setting.disabled then applyEnabled(setting) end
    end
end

-- A warning whose level is function-valued follows the row it sits on, so it is
-- re-read wherever that row's value can have changed.
local function refreshWarnings(group)
    for _, setting in ipairs(group.settings) do
        local icon = setting.row and rowWarnIcons[setting.row]
        if icon then icon.Repaint() end
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
        refreshWarnings(g)
    end
end

-- The About rail keeps whatever was hovered last rather than snapping back to the
-- top of the group. A rail that resets on leave cannot be reached: its own
-- Enable and Reload button disappears the moment the cursor sets off towards it.
-- Switching group still resets it, which is where the default belongs. The
-- floating screenshot preview is the exception: nothing on it is clickable, so
-- it goes on leave rather than trailing the cursor around the panel.
local function attachHover(setting, group, extraFrames)
    local function onEnter()
        group.panel:UpdateAbout(setting)
        if setting.rowHover then setting.rowHover:Show() end
    end
    local function onLeave()
        if setting.rowHover then setting.rowHover:Hide() end
        hideImagePreview()
    end
    setting.row:SetScript("OnEnter", onEnter)
    setting.row:SetScript("OnLeave", onLeave)
    -- The icon sits inside the row and swallows its mouse events, so the About
    -- rail would go blank while the warning tooltip is up.
    local warnIcon = rowWarnIcons[setting.row]
    if warnIcon then
        warnIcon:HookScript("OnEnter", onEnter)
        warnIcon:HookScript("OnLeave", onLeave)
    end
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

local WARN_ICON_SIZE = 14
local WARN_ICON_GAP  = 6

local function baseIndent(opts)
    return opts.parent and 30 or 14
end

-- The art is white, so the colour is applied here. It is a button rather than a
-- texture because the warning has to be readable without hovering the control
-- the row belongs to.
--
-- `warningLevel` may be a function, so a row whose risk depends on the value it
-- holds can read amber on the safe choice and red on the one that cannot be
-- undone. Anything unrecognised stays red, the louder of the two.
local function makeWarningIcon(row, opts)
    local icon = CreateFrame("Button", nil, row)
    icon:SetSize(WARN_ICON_SIZE, WARN_ICON_SIZE)
    icon:SetPoint("LEFT", baseIndent(opts), 0)

    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(LuckyIcon("triangle-alert"))

    icon.Repaint = function()
        local color = resolveValue(opts.warningLevel) == "caution" and R.caution or R.warn
        tex:SetVertexColor(color[1], color[2], color[3])
    end
    icon.Repaint()

    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S.warningTitle, R.warn[1], R.warn[2], R.warn[3])
        GameTooltip:AddLine(opts.warning, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rowWarnIcons[row] = icon
    return icon
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

    if opts.warning then
        makeWarningIcon(row, opts)
    end

    return row, hl
end

-- A row carrying a warning gives up its leading space to the icon, so the
-- control it belongs to shifts right rather than sitting on top of it.
local function indentForOpts(opts)
    return baseIndent(opts) + (opts.warning and (WARN_ICON_SIZE + WARN_ICON_GAP) or 0)
end

function RichGroup:Toggle(opts)
    prepareRow(self, opts, "checked", "onToggle")
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
        warningLevel = opts.warningLevel,
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
        refreshEnabled(group)
        refreshWarnings(group)
        group.panel:UpdateAbout(setting)
    end)

    attachHover(setting, self, { cb })
    return self
end

function RichGroup:Slider(opts)
    prepareRow(self, opts, "value", "onChanged")
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
        warningLevel = opts.warningLevel,
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

    local group = self
    slider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val + 0.5)
        valueText:SetText(tostring(val) .. (opts.suffix or ""))
        if opts.onChanged then opts.onChanged(val) end
        refreshEnabled(group)
        refreshWarnings(group)
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
--   keys      table?          { optionKey = storeField }, binds each option to the store
--
function RichGroup:MultiSelect(opts)
    prepareRow(self, opts)
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
        if #labels == 0 then return S.selectNone end
        if #labels == #opts.options then return S.selectAll end
        if #labels <= 2 then return table.concat(labels, ", ") end
        return S.selectSome:format(#labels, #opts.options)
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
        warningLevel = opts.warningLevel,
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
-- MultiSelect's sibling for a setting that holds one value: radio buttons
-- instead of check boxes, on the modern dropdown rather than MultiSelect's
-- legacy one. `value` may be a plain key or a zero-arg function, re-read every
-- time the panel opens.
--
-- The dropdown sits beside the label, as MultiSelect's does. Pass
-- `newLine = true` for the two-line shape Slider uses, label above the control,
-- which option text long enough to be worth reading needs once the About rail
-- has taken its share of the width.

function RichGroup:Select(opts)
    prepareRow(self, opts, "value", "onSelect")
    local row, hl = makeRow(self, opts, opts.newLine and 48 or 32)
    local indent = indentForOpts(opts)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetTextColor(R.text[1], R.text[2], R.text[3])
    label:SetText(opts.label)

    local dd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dd:SetWidth(opts.width or 220)

    if opts.newLine then
        -- Right-aligned on the line below the label, sharing an edge with the
        -- values on Label rows. The 22 clears the row's top pad and the label line.
        label:SetPoint("TOPLEFT", indent, -4)
        dd:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, -22)
    else
        label:SetPoint("LEFT", indent, 0)
        dd:SetPoint("RIGHT", -14, 0)
    end

    if isVersionRecent(self.panel, opts.since) then
        makeNewBadge(row, label)
    end

    local function labelFor(key)
        for _, o in ipairs(opts.options) do
            if o.key == key then return o.label end
        end
    end

    local group = self
    local function refresh()
        dd:SetDefaultText(labelFor(resolveValue(opts.value)) or opts.placeholder or "")
        refreshWarnings(group)
    end

    dd:SetupMenu(function(_, root)
        for _, o in ipairs(opts.options) do
            root:CreateRadio(o.label,
                function() return resolveValue(opts.value) == o.key end,
                function()
                    if opts.onSelect then opts.onSelect(o.key) end
                    refresh()
                end)
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
        warningLevel = opts.warningLevel,
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
    prepareRow(self, opts)
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
        warningLevel = opts.warningLevel,
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

-- ─── ButtonRow (sibling actions side by side on one row) ─────────────────
-- Actions on the same subject, new/rename/duplicate/delete for a profile say,
-- read as one toolbar rather than as a stack of full-width buttons. Each button
-- keeps its own About entry, so hovering one explains that action alone.
--
--     group:ButtonRow({ buttons = {
--         { label = "New", icon = "plus", desc = "...", onClick = fn },
--     } })
--
-- `icon` is the bare name of one of the shared icons; leave it out for a plain
-- text button. The buttons are borderless, the same look the icon buttons across
-- the addons have: gold art and label with no plate behind them, lighting up on
-- hover with the icon added over itself. Each is only as wide as it reads, since
-- with no edges to line up an even width would just make the gaps look uneven.

local ICON_SIZE  = 14
local ICON_GAP   = 6   -- icon to its own label
local BUTTON_H   = 20
local GLOW_ALPHA = 0.35

function RichGroup:ButtonRow(opts)
    local rowHeight = 32
    local row, hl = makeRow(self, opts, rowHeight)
    local gap = opts.gap or 20  -- between buttons, which is all that separates them

    local x, firstSetting = indentForOpts(opts), nil

    for _, spec in ipairs(opts.buttons) do
        local btn = CreateFrame("Button", nil, row)
        btn:SetHeight(BUTTON_H)
        btn:SetScript("OnClick", function() if spec.onClick then spec.onClick() end end)

        local text = btn:CreateFontString(nil, "OVERLAY")
        text:SetFont(R_FONT, 12, "")
        text:SetText(spec.label)
        text:SetPoint("RIGHT")

        local width = math.ceil(text:GetStringWidth())
        local icon, glow
        if spec.icon then
            local art = LuckyIcon(spec.icon)
            icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:SetTexture(art)
            icon:SetPoint("LEFT")

            -- Hover is the icon added over itself rather than anything drawn
            -- behind it, which is what keeps the button borderless.
            glow = btn:CreateTexture(nil, "OVERLAY")
            glow:SetAllPoints(icon)
            glow:SetTexture(art)
            glow:SetBlendMode("ADD")
            glow:SetAlpha(GLOW_ALPHA)
            glow:Hide()

            width = width + ICON_SIZE + ICON_GAP
        end

        btn:SetWidth(width)
        btn:SetPoint("LEFT", x, 0)
        -- The gaps are dead space that would otherwise hand the mouse back to the
        -- row, so each button claims its half and the full height of the row.
        btn:SetHitRectInsets(-gap / 2, -gap / 2, -(rowHeight - BUTTON_H) / 2, -(rowHeight - BUTTON_H) / 2)
        x = x + width + gap

        local function paint(lit)
            local c = lit and R.accentLight or R.accent
            text:SetTextColor(c[1], c[2], c[3])
            if icon then
                icon:SetVertexColor(c[1], c[2], c[3])
                glow:SetVertexColor(c[1], c[2], c[3])
                glow:SetShown(lit)
            end
        end
        paint(false)
        btn:SetScript("OnEnter", function() paint(true) end)
        btn:SetScript("OnLeave", function() paint(false) end)

        local setting = {
            type     = "Button",
            label    = spec.label,
            desc     = spec.desc,
            tooltip  = spec.tooltip,
            warning  = spec.warning,
            since    = spec.since,
            row      = row,
            rowHover = hl,
            button   = btn,
            icon     = icon,
        }
        table.insert(self.settings, setting)
        self.byLabel[spec.label] = setting
        attachHover(setting, self, { btn })
        firstSetting = firstSetting or setting
    end

    -- Every button just re-pointed the row's own hover at itself, so the last one
    -- would otherwise own whatever is left of the row.
    attachHover(firstSetting, self)
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

--- An empty row of the given height in the normal top-down flow, for callers
--- that draw their own contents. Returns the frame rather than the group.
---@param height number
---@return Frame
function RichGroup:Frame(height)
    local frame = CreateFrame("Frame", nil, rowParent(self))
    frame:SetHeight(height)
    placeRow(self, frame)
    table.insert(self.settings, { row = frame, isSection = true })
    return frame
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

local SCROLLBAR_WIDTH = 22

-- Content that fits needs no scrollbar, and gives its width back to the rows.
-- Measured from the child rather than the scroll range because a region that
-- fits from the moment it is built has a range of zero that never changes, so
-- OnScrollRangeChanged alone would leave the bar showing over a short group.
local function updateScrollbar(scroll, inner)
    local bar = scroll.ScrollBar
    if not bar then return end

    local scrollable = (inner:GetHeight() or 0) > (scroll:GetHeight() or 0) + 0.5
    if scroll.luckyScrollable == scrollable then return end
    scroll.luckyScrollable = scrollable

    bar:SetShown(scrollable)
    scroll:SetPoint("BOTTOMRIGHT", scrollable and -SCROLLBAR_WIDTH or 0, 0)
end

local function makeScrollRegion(holder)
    local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_WIDTH, 0)

    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetSize(scroll:GetWidth() or 400, 1)
    scroll:SetScrollChild(inner)

    -- Both fire: the size once the anchors resolve, the range once the child is
    -- filled. Whichever lands first with real numbers settles the bar, and the
    -- stored state keeps the other from re-anchoring for the same answer.
    scroll:HookScript("OnSizeChanged", function(self, w)
        inner:SetWidth(w)
        updateScrollbar(self, inner)
    end)
    scroll:HookScript("OnScrollRangeChanged", function(self)
        updateScrollbar(self, inner)
    end)

    -- The template starts with the bar showing. Settling it now on an empty
    -- child means a region nothing ever fires for is left without a bar rather
    -- than stuck behind one, and the wheel still scrolls either way.
    updateScrollbar(scroll, inner)

    return inner
end

function RichGroup:Fill(inset)
    inset = inset or 14
    local holder = CreateFrame("Frame", nil, self.content)
    local anchor, anchorEdge = nextRowAnchor(self)
    holder:SetPoint("TOPLEFT",  anchor, anchorEdge .. "LEFT",  inset, -8)
    holder:SetPoint("TOPRIGHT", anchor, anchorEdge .. "RIGHT", -inset, -8)
    self.fillHolder = holder
    self.lastRow = holder
    relayoutFill(self)

    local inner = makeScrollRegion(holder)
    table.insert(self.settings, { row = holder, isSection = true })
    return inner
end

-- Rows are laid out flush in the group's content frame, which silently clips
-- them once a group outgrows the panel. A group that has not built a scrolling
-- region of its own gets one here, after its rows are placed, so the chain they
-- were anchored in survives and only the first row is re-anchored. Groups that
-- fit look no different: the scrollbar hides itself and gives the width back.
function RichGroup:AutoScroll()
    if self.fillHolder or self.rowParent then return false end

    local rows = {}
    for _, setting in ipairs(self.settings) do
        if setting.row then table.insert(rows, setting.row) end
    end
    if #rows == 0 then return false end

    -- Anchored to the heading rather than the last row, because every row is
    -- about to move inside it.
    local holder = CreateFrame("Frame", nil, self.content)
    holder:SetPoint("TOPLEFT",  self.heading, "BOTTOMLEFT",  0, 0)
    holder:SetPoint("TOPRIGHT", self.heading, "BOTTOMRIGHT", 0, 0)
    self.fillHolder = holder
    relayoutFill(self)

    local inner = makeScrollRegion(holder)

    local height = 0
    for _, row in ipairs(rows) do
        row:SetParent(inner)
        height = height + row:GetHeight()
    end

    -- Left anchored outside the scroll frame, the first row would hold every
    -- other one still while the region scrolled underneath it.
    rows[1]:ClearAllPoints()
    rows[1]:SetPoint("TOPLEFT",  inner, "TOPLEFT",  0, 0)
    rows[1]:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, 0)
    inner:SetHeight(height)

    self.rowParent, self.rowParentHeight, self.lastRow = inner, height, rows[#rows]
    return true
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
        hideImagePreview()
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
