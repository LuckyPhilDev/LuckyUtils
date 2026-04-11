-- LuckySettings: Shared settings registration and panel builder for Lucky Phil's addons.

LuckySettings = {}

-- ── Registration ──────────────────────────────────────────────────────────────

--- Register a canvas settings panel with the game's Interface Options.
---@param canvas Frame  The settings panel frame to register
---@param displayName string  The name shown in the settings list
---@return table|nil  category
function LuckySettings:Register(canvas, displayName)
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end
    local category = Settings.RegisterCanvasLayoutCategory(canvas, displayName)
    if category then
        Settings.RegisterAddOnCategory(category)
    end
    return category
end

--- Open the settings panel for a previously registered category.
---@param category table  The category object returned by Register()
function LuckySettings:Open(category)
    if not category then
        print("Settings panel not registered.")
        return
    end
    if not Settings or not Settings.OpenToCategory then return end
    local id = (type(category.GetID) == "function" and category:GetID()) or category.ID
    if id then
        Settings.OpenToCategory(id)
    end
end

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function CreateScrollFrame(panel)
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 500)
    scrollFrame:SetScrollChild(content)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)

    return content
end

local function UpdateContentHeight(content)
    local bottom = 0
    for _, child in pairs({ content:GetRegions() }) do
        local _, _, _, _, y = child:GetPoint()
        if y then
            local childBottom = -y + (child.GetHeight and child:GetHeight() or 0)
            if childBottom > bottom then bottom = childBottom end
        end
    end
    for _, child in pairs({ content:GetChildren() }) do
        local _, _, _, _, y = child:GetPoint()
        if y then
            local childBottom = -y + child:GetHeight()
            if childBottom > bottom then bottom = childBottom end
        end
    end
    content:SetHeight(bottom + 60)
end

-- ── Builder ───────────────────────────────────────────────────────────────────

local Builder = {}
Builder.__index = Builder

--- Add a checkbox toggle with a label and short description.
---@param opts table  { label, desc, checked, onToggle, tooltip?, indent?, gap? }
function Builder:Toggle(opts)
    local anchor  = self.lastAnchor.desc or self.lastAnchor
    local content = self.content

    local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    check:SetPoint("LEFT", content, "LEFT", 16 + (opts.indent or 0), 0)
    check:SetPoint("TOP", anchor, "BOTTOM", 0, -(opts.gap or 8))
    check:SetChecked(opts.checked)
    check.text:SetText(opts.label)
    check:SetScript("OnClick", function(btn)
        opts.onToggle(btn:GetChecked())
    end)

    if opts.tooltip then
        check:SetScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine(opts.label, 1, 1, 1)
            GameTooltip:AddLine(opts.tooltip, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 26, -2)
    desc:SetWidth(400)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.54, 0.49, 0.42)
    desc:SetText(opts.desc or "")

    check.desc    = desc
    self.lastAnchor = check
    return self
end

--- Add a gold section heading with a horizontal rule.
---@param text string
function Builder:Section(text)
    local anchor  = self.lastAnchor.desc or self.lastAnchor
    local content = self.content

    local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("LEFT", content, "LEFT", 16, 0)
    heading:SetPoint("TOP", anchor, "BOTTOM", 0, -20)
    heading:SetTextColor(0.79, 0.66, 0.30)
    heading:SetText(text)

    local rule = content:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", heading, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    rule:SetColorTexture(0.23, 0.18, 0.10)

    self.lastAnchor = heading
    return self
end

--- Add a labeled slider with a live value readout.
--- opts.key must be unique across all sliders in the panel (used for the frame name).
---@param opts table  { label, key, min, max, value, onChanged, step?, suffix?, width?, indent?, gap? }
function Builder:Slider(opts)
    local anchor  = self.lastAnchor.desc or self.lastAnchor
    local content = self.content

    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", content, "LEFT", 16 + (opts.indent or 0), 0)
    label:SetPoint("TOP", anchor, "BOTTOM", 0, -(opts.gap or 12))
    label:SetText(opts.label)

    local slider = CreateFrame("Slider", "LuckySettings_Slider_" .. opts.key, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -14)
    slider:SetWidth(opts.width or 160)
    slider:SetMinMaxValues(opts.min, opts.max)
    slider:SetValueStep(opts.step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(opts.value)
    slider.Low:SetText(opts.min)
    slider.High:SetText(opts.max)

    local valueText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetText(opts.value .. (opts.suffix or ""))

    slider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val + 0.5)
        valueText:SetText(val .. (opts.suffix or ""))
        opts.onChanged(val)
    end)

    -- Invisible spacer so the next element anchors below the slider cleanly
    local spacer = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    spacer:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)
    spacer:SetText("")
    slider.desc = spacer

    self.lastAnchor = slider
    return self
end

-- ── Panel factory ─────────────────────────────────────────────────────────────

--- Create a new settings panel, register it, and return a builder.
--- The builder's category is available as builder.category.
---@param displayName string  Name shown in Interface Options
---@return table  builder
function LuckySettings:NewPanel(displayName)
    local panel = CreateFrame("Frame")
    panel.name  = displayName

    local category = self:Register(panel, displayName)
    local content  = CreateScrollFrame(panel)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(displayName)

    panel:HookScript("OnShow", function()
        UpdateContentHeight(content)
    end)

    local builder = setmetatable({
        category   = category,
        panel      = panel,
        content    = content,
        lastAnchor = title,
    }, Builder)

    --- Open this panel in Interface Options.
    function builder:Open()
        LuckySettings:Open(self.category)
    end

    return builder
end
