-- LuckyUI: Shared UI style library for Lucky Phil's addons.
-- Provides a dark/gold themed color palette, font constants, backdrop
-- definitions, and frame helper functions.

LuckyUI = {}

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

-- Fonts
LuckyUI.TITLE_FONT = "Fonts\\FRIZQT__.TTF"
LuckyUI.BODY_FONT  = "Fonts\\FRIZQT__.TTF"

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
