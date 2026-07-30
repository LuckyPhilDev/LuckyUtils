-- LuckySettings: Shared settings registration and panel builder for Lucky Phil's addons.

LuckySettings = LuckySettings or {}

local PREFIX = "|cffc9a84c[LuckySettings]|r"
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

-- ── Registration ──────────────────────────────────────────────────────────────

--- Register a canvas settings panel with the game's Interface Options.
---@param canvas Frame  The settings panel frame to register
---@param displayName string  The name shown in the settings list
---@return table|nil  category
function LuckySettings:Register(canvas, displayName)
    Log("Register called for:", displayName)
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        Log("FAIL — Settings API not available (Settings =", tostring(Settings) .. ")")
        return nil
    end
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, canvas, displayName)
    if not ok then
        Log("FAIL — RegisterCanvasLayoutCategory threw:", tostring(category))
        return nil
    end
    if category then
        local ok2, err = pcall(Settings.RegisterAddOnCategory, category)
        if not ok2 then
            Log("FAIL — RegisterAddOnCategory threw:", tostring(err))
        else
            local id = (type(category.GetID) == "function" and category:GetID()) or category.ID
            Log("OK — registered, category ID:", tostring(id))
        end
    else
        Log("FAIL — RegisterCanvasLayoutCategory returned nil for:", displayName)
    end
    return category
end

--- Open the settings panel for a previously registered category.
---@param category table  The category object returned by Register()
function LuckySettings:Open(category)
    Log("Open called, category:", tostring(category))
    if not category then
        Log("FAIL — category is nil, cannot open")
        print("Settings panel not registered.")
        return
    end
    if not Settings or not Settings.OpenToCategory then
        Log("FAIL — Settings.OpenToCategory not available")
        return
    end
    local id = (type(category.GetID) == "function" and category:GetID()) or category.ID
    Log("Opening category ID:", tostring(id))
    if id then
        Settings.OpenToCategory(id)
    else
        Log("FAIL — could not extract category ID")
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

    Log("CreateScrollFrame — scrollFrame:", tostring(scrollFrame),
        "content:", tostring(content),
        "width:", tostring(scrollFrame:GetWidth() or 500))

    return content
end

local function UpdateContentHeight(content)
    local bottom = 0
    local regionCount, childCount = 0, 0
    for _, child in pairs({ content:GetRegions() }) do
        regionCount = regionCount + 1
        local numPoints = child.GetNumPoints and child:GetNumPoints() or 0
        if numPoints == 0 then
            Log("  region", regionCount, "has NO anchor points, type:", child:GetObjectType(),
                "shown:", tostring(child:IsShown()))
        else
            local _, _, _, _, y = child:GetPoint()
            if y then
                local childBottom = -y + (child.GetHeight and child:GetHeight() or 0)
                if childBottom > bottom then bottom = childBottom end
            else
                Log("  region", regionCount, "has nil Y offset, type:", child:GetObjectType())
            end
        end
    end
    for _, child in pairs({ content:GetChildren() }) do
        childCount = childCount + 1
        local numPoints = child.GetNumPoints and child:GetNumPoints() or 0
        if numPoints == 0 then
            Log("  child", childCount, "has NO anchor points, type:", child:GetObjectType(),
                "shown:", tostring(child:IsShown()))
        else
            local _, _, _, _, y = child:GetPoint()
            if y then
                local childBottom = -y + child:GetHeight()
                if childBottom > bottom then bottom = childBottom end
            else
                Log("  child", childCount, "has nil Y offset, type:", child:GetObjectType())
            end
        end
    end
    Log("UpdateContentHeight — regions:", regionCount, "children:", childCount,
        "bottom:", bottom, "finalHeight:", bottom + 60)
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

--- Add a segmented pill selector with a label and description.
--- Each choice is a button; the active choice is highlighted in gold.
---@param opts table  { label, desc, value, choices, onChange, tooltip?, indent?, gap? }
---   choices = { { value = "on", label = "On" }, { value = "off", label = "Off" }, ... }
function Builder:Selector(opts)
    local anchor  = self.lastAnchor.desc or self.lastAnchor
    local content = self.content

    -- Label
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", content, "LEFT", 16 + (opts.indent or 0), 0)
    label:SetPoint("TOP", anchor, "BOTTOM", 0, -(opts.gap or 8))
    label:SetText(opts.label)

    if opts.tooltip then
        -- Attach tooltip to an invisible overlay on the label
        local hitFrame = CreateFrame("Frame", nil, content)
        hitFrame:SetAllPoints(label)
        hitFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(opts.label, 1, 1, 1)
            GameTooltip:AddLine(opts.tooltip, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        hitFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Pill container
    local container = CreateFrame("Frame", nil, content)
    container:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 26, -4)
    container:SetHeight(22)

    local buttons = {}
    local BTN_H = 22

    local function Refresh(selectedValue)
        for _, btn in ipairs(buttons) do
            if btn.choiceValue == selectedValue then
                btn:SetBackdropColor(0.788, 0.659, 0.298, 1)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1)
                btn.label:SetTextColor(0.102, 0.071, 0.035, 1)
            else
                btn:SetBackdropColor(0.051, 0.039, 0.020, 0.95)
                btn:SetBackdropBorderColor(0.227, 0.180, 0.102, 1)
                btn.label:SetTextColor(0.91, 0.863, 0.784, 1)
            end
        end
    end

    local totalW = 0
    for i, choice in ipairs(opts.choices) do
        local btnW = math.max(50, select(2, GameFontNormal:GetFont()) * #choice.label * 0.55 + 24)
        btnW = math.floor(btnW + 0.5)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(btnW, BTN_H)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11)
        lbl:SetPoint("CENTER")
        lbl:SetText(choice.label)
        btn.label = lbl
        btn.choiceValue = choice.value

        if i == 1 then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", -1, 0)
        end

        btn:SetScript("OnClick", function()
            Refresh(choice.value)
            opts.onChange(choice.value)
        end)

        btn:SetScript("OnEnter", function(self)
            if self.choiceValue ~= opts.value then
                self:SetBackdropBorderColor(0.545, 0.451, 0.251, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            Refresh(opts._currentValue or opts.value)
        end)

        buttons[i] = btn
        totalW = totalW + btnW - (i > 1 and 1 or 0)
    end
    container:SetWidth(totalW)

    -- Track current value for hover restore
    local origOnChange = opts.onChange
    opts.onChange = function(val)
        opts._currentValue = val
        origOnChange(val)
    end

    Refresh(opts.value)
    opts._currentValue = opts.value

    -- Description
    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(400)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.54, 0.49, 0.42)
    desc:SetText(opts.desc or "")

    container.desc = desc
    self.lastAnchor = container
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

--- Add a labeled push-button (with optional description below).
---@param opts table  { label, desc?, onClick, tooltip?, width?, indent?, gap? }
function Builder:Button(opts)
    local anchor  = self.lastAnchor.desc or self.lastAnchor
    local content = self.content

    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btn:SetSize(opts.width or 160, 22)
    btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (opts.indent or 0), -(opts.gap or 8))
    btn:SetText(opts.label)
    btn:SetScript("OnClick", function() opts.onClick() end)

    if opts.tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(opts.label, 1, 1, 1)
            GameTooltip:AddLine(opts.tooltip, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    if opts.desc then
        local desc = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 4, -2)
        desc:SetWidth(400)
        desc:SetJustifyH("LEFT")
        desc:SetTextColor(0.54, 0.49, 0.42)
        desc:SetText(opts.desc)
        btn.desc = desc
    end

    self.lastAnchor = btn
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
    Log("NewPanel called for:", displayName)
    local panel = CreateFrame("Frame")
    panel.name  = displayName
    panel:Hide() -- ensure first sidebar navigation triggers OnShow

    local category = self:Register(panel, displayName)
    local content  = CreateScrollFrame(panel)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(displayName)

    panel:HookScript("OnShow", function()
        Log("OnShow fired for:", displayName,
            "panel visible:", tostring(panel:IsVisible()),
            "panel size:", tostring(panel:GetWidth()) .. "x" .. tostring(panel:GetHeight()),
            "content size:", tostring(content:GetWidth()) .. "x" .. tostring(content:GetHeight()))
        UpdateContentHeight(content)
    end)

    panel:HookScript("OnHide", function()
        Log("OnHide fired for:", displayName)
    end)

    Log("NewPanel complete for:", displayName,
        "category:", tostring(category),
        "panel:", tostring(panel),
        "content:", tostring(content))

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

-- ── Debug mode init & slash command ──────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= "Luckys_Utils" then return end
    LuckySettingsDB = LuckySettingsDB or { debugMode = false }
    Log("LuckySettings loaded, debugMode:", tostring(LuckySettingsDB.debugMode))
end)

SLASH_LUCKYSETTINGSDEBUG1 = "/lsdebug"
SlashCmdList["LUCKYSETTINGSDEBUG"] = function()
    LuckySettingsDB = LuckySettingsDB or { debugMode = false }
    LuckySettingsDB.debugMode = not LuckySettingsDB.debugMode
    devLog = nil -- force re-init so the new flag takes effect
    print(PREFIX .. " debug mode: " .. (LuckySettingsDB.debugMode and "|cff69db7cON|r" or "|cffff6b6bOFF|r"))
end
