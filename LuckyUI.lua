-- LuckyUI: Shared UI style library for Lucky Phil's addons.
-- Provides a dark/gold themed color palette, font constants, backdrop
-- definitions, and frame helper functions.

if LuckysUtilsSkipLoad then return end

LuckyUI = LuckyUI or {}

local SOLID = "Interface\\Buttons\\WHITE8x8"

-- ---------------------------------------------------------------------------
-- Color Palette
-- ---------------------------------------------------------------------------

LuckyUI.C = {
    bgDark      = { 0.102, 0.071, 0.035, 0.95 },
    bgPanel     = { 0.125, 0.102, 0.055, 0.95 },
    bgInput     = { 0.051, 0.039, 0.020, 0.95 },
    highlight   = { 0.788, 0.659, 0.298, 0.13 },

    goldPrimary = { 1.000, 0.820, 0.000 },
    goldAccent  = { 0.788, 0.659, 0.298 },
    goldMuted   = { 0.545, 0.451, 0.251 },
    goldIcon    = { 1.000, 0.824, 0.392 },

    textLight   = { 0.910, 0.863, 0.784 },
    textMuted   = { 0.541, 0.494, 0.416 },
    textGold    = { 1.000, 0.820, 0.000 },

    danger      = { 1.000, 0.420, 0.420 },
    info        = { 0.310, 0.765, 0.969 },
    success     = { 0.412, 0.859, 0.486 },
    purple      = { 0.702, 0.533, 1.000 },

    borderDark  = { 0.227, 0.180, 0.102 },
}

-- WoW color escape strings
LuckyUI.WC = {
    goldPrimary = "|cffffd100",
    goldAccent  = "|cffc9a84c",
    textMuted   = "|cff8a7e6a",
    info        = "|cff4fc3f7",
    success     = "|cff69db7c",
    danger      = "|cffff6b6b",
    purple      = "|cffb388ff",
    reset       = "|r",
}

-- Fonts. STANDARD_TEXT_FONT is whatever face the client's own locale uses,
-- so Cyrillic and CJK clients get glyphs instead of empty boxes.
LuckyUI.TITLE_FONT = STANDARD_TEXT_FONT
LuckyUI.BODY_FONT  = STANDARD_TEXT_FONT

-- Shared backdrop definition
LuckyUI.Backdrop = {
    bgFile   = SOLID,
    edgeFile = SOLID,
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- ---------------------------------------------------------------------------
-- Frame Helpers
-- ---------------------------------------------------------------------------

--- Create a styled panel frame (dark background, gold border, draggable).
function LuckyUI.CreatePanel(name, parent, w, h)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetBackdrop(LuckyUI.Backdrop)
    f:SetBackdropColor(LuckyUI.C.bgDark[1], LuckyUI.C.bgDark[2], LuckyUI.C.bgDark[3], LuckyUI.C.bgDark[4])
    f:SetBackdropBorderColor(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3])
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    return f
end

--- Create a header bar with gradient background, gold title, and close button.
function LuckyUI.CreateHeader(frame, title)
    local h = CreateFrame("Frame", nil, frame)
    h:SetHeight(32)
    h:SetPoint("TOPLEFT", 1, -1)
    h:SetPoint("TOPRIGHT", -1, -1)

    -- Gradient background
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1)
    bg:SetGradient("HORIZONTAL",
        CreateColor(LuckyUI.C.borderDark[1], LuckyUI.C.borderDark[2], LuckyUI.C.borderDark[3]),
        CreateColor(LuckyUI.C.bgPanel[1], LuckyUI.C.bgPanel[2], LuckyUI.C.bgPanel[3]))

    -- Gold bottom border
    local line = h:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3])

    -- Title text (Friz Quadrata)
    local t = h:CreateFontString(nil, "OVERLAY")
    t:SetFont(LuckyUI.TITLE_FONT, 16)
    t:SetTextColor(LuckyUI.C.goldPrimary[1], LuckyUI.C.goldPrimary[2], LuckyUI.C.goldPrimary[3])
    t:SetPoint("LEFT", 12, 0)
    t:SetText(title)
    frame.titleText = t

    -- Close button (red square with x)
    local cb = CreateFrame("Button", nil, h)
    cb:SetSize(20, 20)
    cb:SetPoint("RIGHT", -8, 0)

    local cbBg = cb:CreateTexture(nil, "BACKGROUND")
    cbBg:SetAllPoints()
    cbBg:SetColorTexture(LuckyUI.C.danger[1], LuckyUI.C.danger[2], LuckyUI.C.danger[3], 0.8)

    local cbX = cb:CreateFontString(nil, "OVERLAY")
    cbX:SetFont(LuckyUI.BODY_FONT, 12, "OUTLINE")
    cbX:SetTextColor(1, 1, 1)
    cbX:SetPoint("CENTER", 0, 1)
    cbX:SetText("x")

    cb:SetScript("OnClick", function() frame:Hide() end)
    cb:SetScript("OnEnter", function() cbBg:SetColorTexture(1, 0.3, 0.3, 1) end)
    cb:SetScript("OnLeave", function()
        cbBg:SetColorTexture(LuckyUI.C.danger[1], LuckyUI.C.danger[2], LuckyUI.C.danger[3], 0.8)
    end)

    frame.header = h
    return h
end

--- Create a styled button. variant: "primary" | "secondary" (default) | "danger"
function LuckyUI.CreateButton(parent, text, w, h, variant)
    variant = variant or "secondary"
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 90, h or 28)
    btn:SetBackdrop(LuckyUI.Backdrop)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(LuckyUI.BODY_FONT, 12)
    lbl:SetPoint("CENTER")
    lbl:SetText(text)
    btn.label = lbl

    -- Override SetText/GetText to use our custom label
    function btn:SetText(t) self.label:SetText(t) end
    function btn:GetText() return self.label:GetText() end

    local c = LuckyUI.C
    if variant == "primary" then
        btn:SetBackdropColor(c.goldAccent[1], c.goldAccent[2], c.goldAccent[3])
        btn:SetBackdropBorderColor(c.goldPrimary[1], c.goldPrimary[2], c.goldPrimary[3])
        lbl:SetTextColor(c.bgDark[1], c.bgDark[2], c.bgDark[3])
        btn:SetScript("OnEnter", function()
            btn:SetBackdropColor(c.goldPrimary[1], c.goldPrimary[2], c.goldPrimary[3])
        end)
        btn:SetScript("OnLeave", function()
            btn:SetBackdropColor(c.goldAccent[1], c.goldAccent[2], c.goldAccent[3])
        end)
    elseif variant == "danger" then
        btn:SetBackdropColor(0, 0, 0, 0)
        btn:SetBackdropBorderColor(c.danger[1], c.danger[2], c.danger[3])
        lbl:SetTextColor(c.danger[1], c.danger[2], c.danger[3])
        btn:SetScript("OnEnter", function()
            btn:SetBackdropColor(c.danger[1], c.danger[2], c.danger[3], 0.15)
        end)
        btn:SetScript("OnLeave", function()
            btn:SetBackdropColor(0, 0, 0, 0)
        end)
    else -- secondary
        btn:SetBackdropColor(c.bgInput[1], c.bgInput[2], c.bgInput[3], c.bgInput[4])
        btn:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
        lbl:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
        btn:SetScript("OnEnter", function()
            btn:SetBackdropBorderColor(c.goldMuted[1], c.goldMuted[2], c.goldMuted[3])
        end)
        btn:SetScript("OnLeave", function()
            btn:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
        end)
    end

    return btn
end

--- Create a small icon button: gold tinted art, additive hover, dimmed when disabled.
--
-- opts fields:
--   icon     (string)  A shared icon's name (see Media\icons), or a full
--                      texture path for art of the consumer's own
--   size     (number)  Square size, default 20
--   tooltip  (string|function)  Text, or fn(GameTooltip, button) for a live one
--   anchor   (string)  Tooltip anchor, default "ANCHOR_RIGHT"
--   color    (table)   Icon tint, default LuckyUI.C.goldIcon
--   texCoord (table)   { left, right, top, bottom }, to crop the border baked
--                      into Interface\Icons art
--
-- The returned button gains SetIconColor(r, g, b, a) for callers that tint it
-- by state, and SetIconDesaturated(bool).
function LuckyUI.CreateIconButton(parent, opts)
    local size = opts.size or 20
    -- A bare name is one of the shared icons; anything with a path separator is
    -- the caller's own texture.
    local icon = opts.icon:find("\\", 1, true) and opts.icon or LuckyIcon(opts.icon)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:SetNormalTexture(icon)
    btn:SetHighlightTexture(icon, "ADD")
    btn:SetDisabledTexture(icon)

    local textures = { btn:GetNormalTexture(), btn:GetHighlightTexture(), btn:GetDisabledTexture() }
    if opts.texCoord then
        for _, t in ipairs(textures) do t:SetTexCoord(unpack(opts.texCoord)) end
    end

    function btn:SetIconColor(r, g, b, a)
        self:GetNormalTexture():SetVertexColor(r, g, b, a or 1)
    end

    function btn:SetIconDesaturated(desaturated)
        self:GetNormalTexture():SetDesaturated(desaturated)
    end

    local color = opts.color or LuckyUI.C.goldIcon
    btn:SetIconColor(color[1], color[2], color[3], color[4])
    btn:GetHighlightTexture():SetVertexColor(color[1], color[2], color[3])
    btn:GetHighlightTexture():SetAlpha(0.35)
    btn:GetDisabledTexture():SetVertexColor(0.35, 0.35, 0.35)

    if opts.tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, opts.anchor or "ANCHOR_RIGHT")
            if type(opts.tooltip) == "function" then
                opts.tooltip(GameTooltip, self)
            else
                GameTooltip:SetText(opts.tooltip)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end

    return btn
end

--- Create a styled checkbox (gold accent when checked).
function LuckyUI.CreateCheckbox(parent, size)
    size = size or 16
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(size, size)
    cb:SetBackdrop(LuckyUI.Backdrop)
    cb:SetBackdropColor(LuckyUI.C.bgInput[1], LuckyUI.C.bgInput[2], LuckyUI.C.bgInput[3], LuckyUI.C.bgInput[4])
    cb:SetBackdropBorderColor(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3])

    -- Checked fill: solid gold-accent square
    local ck = cb:CreateTexture()
    ck:SetSize(size - 4, size - 4)
    ck:SetPoint("CENTER")
    ck:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3])
    cb:SetCheckedTexture(ck)

    -- Hover highlight
    local hl = cb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3], 0.15)

    return cb
end

--- Attach drag-to-move behaviour to a frame with SavedVariables persistence.
-- Enables RegisterForDrag, OnDragStart/Stop, and immediately restores the
-- saved position (or the supplied default if none exists yet).
-- Also adds frame:RestorePosition() for callers that need to re-apply later.
--
-- opts fields:
--   db        (table)   SavedVariables table to read/write position from
--   key       (string)  Key within db where {point, relPoint, x, y} is stored
--   button    (string)  Drag mouse button — default "LeftButton"
--   default   (table)   Fallback {point, relPoint, x, y} when db[key] is nil
--                       e.g. { "CENTER", "CENTER", 0, 200 }
--
-- Usage:
--   LuckyUI.EnableDrag(myFrame, {
--       db      = MyAddonDB,
--       key     = "windowPos",
--       default = { "TOP", "TOP", 0, -200 },
--   })
function LuckyUI.EnableDrag(frame, opts)
    local db  = opts.db
    local key = opts.key
    local btn = opts.button or "LeftButton"
    local def = opts.default or { "CENTER", "CENTER", 0, 0 }

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag(btn)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db[key] = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    function frame:RestorePosition()
        local pos = db[key]
        self:ClearAllPoints()
        if pos then
            self:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        else
            self:SetPoint(def[1], UIParent, def[2], def[3], def[4])
        end
    end

    frame:RestorePosition()
end

--- Create a horizontal divider with optional label text.
function LuckyUI.CreateDivider(parent, labelText)
    local d = CreateFrame("Frame", nil, parent)
    d:SetHeight(16)

    local line = d:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(LuckyUI.C.borderDark[1], LuckyUI.C.borderDark[2], LuckyUI.C.borderDark[3])
    line:SetPoint("BOTTOMLEFT", 0, 4)
    line:SetPoint("BOTTOMRIGHT", 0, 4)

    if labelText then
        local t = d:CreateFontString(nil, "OVERLAY")
        t:SetFont(LuckyUI.BODY_FONT, 11)
        t:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
        t:SetPoint("BOTTOMLEFT", 0, 6)
        t:SetText(labelText)
    end

    return d
end

--- Create a styled single-line search input.
-- Dark input background, a gold border that brightens on focus, a greyed-out
-- placeholder shown while the box is empty, and a clear (x) button that appears
-- once there is text. Fires opts.onChange with the trimmed query on every edit.
--
-- opts fields:
--   width       (number)   box width in px (default 200)
--   height      (number)   box height in px (default 24)
--   placeholder (string)   hint text shown while empty (default "Search...")
--   onChange    (function) called with the current trimmed query string
--
-- Returns the EditBox, with two convenience methods added:
--   box:SetQuery(text)  set the text (fires onChange)
--   box:Clear()         empty the box (fires onChange)
function LuckyUI.CreateSearchBox(parent, opts)
    opts = opts or {}
    local placeholderText = opts.placeholder or "Search..."
    local onChange = opts.onChange
    local c = LuckyUI.C

    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(opts.width or 200, opts.height or 24)
    box:SetBackdrop(LuckyUI.Backdrop)
    box:SetBackdropColor(c.bgInput[1], c.bgInput[2], c.bgInput[3], c.bgInput[4])
    box:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
    box:SetAutoFocus(false)
    box:SetFont(LuckyUI.BODY_FONT, 12, "")
    box:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
    box:SetTextInsets(8, 22, 0, 0)
    box:SetMaxLetters(60)

    -- Placeholder, visible only while the box is empty.
    local placeholder = box:CreateFontString(nil, "ARTWORK")
    placeholder:SetFont(LuckyUI.BODY_FONT, 12)
    placeholder:SetTextColor(c.textMuted[1], c.textMuted[2], c.textMuted[3])
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetText(placeholderText)

    -- Clear button, hidden until there is text to clear.
    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(16, 16)
    clear:SetPoint("RIGHT", -4, 0)
    local clearX = clear:CreateFontString(nil, "OVERLAY")
    clearX:SetFont(LuckyUI.BODY_FONT, 13)
    clearX:SetTextColor(c.textMuted[1], c.textMuted[2], c.textMuted[3])
    clearX:SetPoint("CENTER")
    clearX:SetText("x")
    clear:Hide()
    clear:SetScript("OnEnter", function() clearX:SetTextColor(c.danger[1], c.danger[2], c.danger[3]) end)
    clear:SetScript("OnLeave", function() clearX:SetTextColor(c.textMuted[1], c.textMuted[2], c.textMuted[3]) end)
    clear:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)

    box:SetScript("OnTextChanged", function(self)
        local query = strtrim(self:GetText() or "")
        if query == "" then
            placeholder:Show()
            clear:Hide()
        else
            placeholder:Hide()
            clear:Show()
        end
        if onChange then onChange(query) end
    end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(c.goldMuted[1], c.goldMuted[2], c.goldMuted[3])
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
    end)

    function box:SetQuery(text) self:SetText(text or "") end
    function box:Clear() self:SetText("") end

    return box
end

--- Create a virtualised, pooled scrolling list.
-- Only enough row frames to fill the visible area are ever built; they are
-- recycled as the user scrolls, so a list of hundreds of items costs the same
-- as a list of ten. The caller owns the look of a row (createRow builds it,
-- updateRow fills it from a data entry); the list owns scrolling and pooling.
--
-- opts fields:
--   rowHeight (number)    height of one row in px (default 20)
--   createRow (function)  createRow(parent) -> rowFrame. Build a row's visuals
--                         parented to `parent` and RETURN the frame. Called
--                         once per pooled slot, never per data item.
--   updateRow (function)  updateRow(rowFrame, item, index). Fill the row from
--                         the data entry. Called whenever a slot is reused.
--   onClick   (function)  onClick(item, index, rowFrame, mouseButton). Optional;
--                         when set, rows gain a hover highlight and respond to
--                         clicks.
--
-- The returned frame is positioned and sized by the caller (SetPoint/SetSize),
-- and gains:
--   list:SetData(array)   replace the backing data and redraw from the top
--   list:Refresh()        redraw visible rows from the current data and scroll
--   list:GetData()        the current backing array
--   list:ScrollTo(index)  scroll so a 1-based data index is at the top
--
-- Usage:
--   local list = LuckyUI.CreateScrollList(panel, {
--       rowHeight = 24,
--       createRow = function(parent)
--           local row = CreateFrame("Frame", nil, parent)
--           row.text = row:CreateFontString(nil, "OVERLAY")
--           row.text:SetFont(LuckyUI.BODY_FONT, 12)
--           row.text:SetPoint("LEFT", 6, 0)
--           return row
--       end,
--       updateRow = function(row, item) row.text:SetText(item.name) end,
--       onClick   = function(item) print("clicked", item.name) end,
--   })
--   list:SetPoint("TOPLEFT", 12, -48)
--   list:SetSize(280, 360)
--   list:SetData(myArray)
function LuckyUI.CreateScrollList(parent, opts)
    opts = opts or {}
    local rowHeight = opts.rowHeight or 20
    local createRow = opts.createRow
    local updateRow = opts.updateRow
    local onClick   = opts.onClick
    local c = LuckyUI.C

    local GUTTER = 14  -- reserved width for the scrollbar

    local list = CreateFrame("Frame", nil, parent)
    list.data = {}
    list.rows = {}

    -- Row area. Clips so a partially-scrolled row is cut off cleanly rather
    -- than spilling past the list bounds.
    local area = CreateFrame("Frame", nil, list)
    area:SetClipsChildren(true)
    area:SetPoint("TOPLEFT", 0, 0)
    area:SetPoint("BOTTOMRIGHT", -GUTTER, 0)
    list.rowArea = area

    -- Scrollbar (a plain vertical slider; no template needed).
    local bar = CreateFrame("Slider", nil, list)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(GUTTER - 4)
    bar:SetPoint("TOPRIGHT", 0, -2)
    bar:SetPoint("BOTTOMRIGHT", 0, 2)
    bar:SetThumbTexture(SOLID)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetValue(0)
    list.scrollBar = bar

    local trough = bar:CreateTexture(nil, "BACKGROUND")
    trough:SetAllPoints()
    trough:SetColorTexture(c.bgInput[1], c.bgInput[2], c.bgInput[3], 0.6)

    local thumb = bar:GetThumbTexture()
    thumb:SetColorTexture(c.goldMuted[1], c.goldMuted[2], c.goldMuted[3], 0.9)
    thumb:SetWidth(GUTTER - 4)

    -- How many rows are needed to cover the visible area, plus one for the
    -- partial row that appears at the top or bottom mid-scroll.
    local function visibleRowCount()
        local h = area:GetHeight()
        if h <= 0 then return 0 end
        return math.ceil(h / rowHeight) + 1
    end

    -- Grow the pool to at least n rows. Rows are built once and reused.
    local function acquireRows(n)
        for i = #list.rows + 1, n do
            local row = createRow and createRow(area) or CreateFrame("Frame", nil, area)
            row:SetParent(area)
            row:SetHeight(rowHeight)
            if onClick then
                row:EnableMouse(true)
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(c.goldAccent[1], c.goldAccent[2], c.goldAccent[3], 0.12)
                row:SetScript("OnMouseUp", function(self, mouseButton)
                    if self._item ~= nil then
                        onClick(self._item, self._index, self, mouseButton)
                    end
                end)
            end
            list.rows[i] = row
        end
    end

    function list:UpdateView()
        local data     = self.data
        local total    = #data
        local areaH    = area:GetHeight()
        local maxScroll = math.max(0, total * rowHeight - areaH)

        bar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            bar:Hide()
            bar:SetValue(0)
        else
            bar:Show()
            -- Thumb height tracks the visible fraction of the whole list.
            local frac = areaH / (total * rowHeight)
            thumb:SetHeight(math.max(20, areaH * frac))
        end

        local value = bar:GetValue()
        if value > maxScroll then
            value = maxScroll
            bar:SetValue(value)
        end

        local first     = math.floor(value / rowHeight)  -- rows fully scrolled past
        local topOffset = value - first * rowHeight       -- 0..rowHeight pixel shift
        local need      = visibleRowCount()
        acquireRows(need)

        local areaW = area:GetWidth()
        for r = 1, #self.rows do
            local row = self.rows[r]
            local dataIndex = first + r
            if r <= need and dataIndex >= 1 and dataIndex <= total then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", area, "TOPLEFT", 0, topOffset - (r - 1) * rowHeight)
                row:SetWidth(areaW)
                row._item  = data[dataIndex]
                row._index = dataIndex
                if updateRow then updateRow(row, data[dataIndex], dataIndex) end
                row:Show()
            else
                row._item = nil
                row:Hide()
            end
        end
    end

    function list:Refresh() self:UpdateView() end

    function list:SetData(arr)
        self.data = arr or {}
        bar:SetValue(0)
        self:UpdateView()
    end

    function list:GetData() return self.data end

    function list:ScrollTo(index)
        bar:SetValue((math.max(1, index or 1) - 1) * rowHeight)
    end

    bar:SetScript("OnValueChanged", function() list:UpdateView() end)

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(bar:GetValue() - delta * rowHeight * 3)
    end)
    list:SetScript("OnSizeChanged", function(self) self:UpdateView() end)

    return list
end
