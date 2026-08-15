-- LuckyRichSettings/Panel.lua: left nav, group management and lazy building,
-- the What's New list, and the LuckySettings:NewRichPanel factory.

local ns = select(2, ...)
local Rich = ns.Rich

local R                 = Rich.R
local R_FONT            = Rich.Font
local rFillBg           = Rich.FillBg
local rEdgeRule         = Rich.EdgeRule
local RichBuilder       = Rich.RichBuilder
local RichGroup         = Rich.RichGroup
local isVersionRecent   = Rich.isVersionRecent
local firstRealSetting  = Rich.firstRealSetting
local buildAbout        = Rich.buildAbout
local aboutShow         = Rich.aboutShow
local hideImagePreview  = Rich.hideImagePreview
local refreshLiveValues = Rich.refreshLiveValues
local resolveValue      = Rich.resolveValue

local PREFIX = "|cffc9a84c[LuckyRichSettings]|r"
local WHATS_NEW = "What's New"
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

local function ensureGroupBuilt(group)
    local build = group and group._contents
    if not build then return end
    group._contents = nil -- cleared first so a build error can't rerun and double-add rows
    build(group)
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

-- ─── Group / Panel ────────────────────────────────────────────────────────────

--- Add a navigation group. `contents(group)` is optional and builds the rows
--- lazily, the first time the group is activated while the panel is shown.
--- `opts` may be omitted entirely: Group(name, function(g) ... end).
function RichBuilder:Group(name, opts, contents)
    if type(opts) == "function" then
        contents, opts = opts, nil
    end
    opts = opts or {}

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
        showAbout  = self.about and opts.showAbout ~= false,
        settings   = {},
        byLabel    = {},
        _contents  = contents,
    }, RichGroup)

    table.insert(self.groups, group)
    group.navButton = makeNavButton(self, group, #self.groups)

    if #self.groups == 1 then self:SetActiveGroup(group) end

    return group
end

function RichBuilder:_setAboutVisibility(showAbout)
    if not self.about then return end

    self.center:ClearAllPoints()
    self.center:SetPoint("TOPLEFT", self.nav, "TOPRIGHT", 0, 0)
    if showAbout then
        self.about:Show()
        self.center:SetPoint("BOTTOMRIGHT", self.about, "BOTTOMLEFT", 0, 0)
    else
        self.about:Hide()
        self.center:SetPoint("BOTTOMRIGHT")
    end
end

function RichBuilder:SetActiveGroup(group)
    if self.activeGroup == group then return end
    if self.activeGroup then
        self.activeGroup.content:Hide()
        styleNav(self.activeGroup.navButton, false)
    end
    self.activeGroup = group
    -- While hidden, defer to the canvas OnShow hook so login stays cheap.
    if self.canvas:IsShown() then ensureGroupBuilt(group) end
    self:_setAboutVisibility(group.showAbout)
    group.content:Show()
    styleNav(group.navButton, true)
    if group.showAbout then
        self:UpdateAbout(nil) -- falls back to first setting in active group
    else
        self.hoveredSetting = nil
    end
end

function RichBuilder:OnOpen(fn)
    self._onOpen = fn
end

-- Call after all groups/settings are added. Scans for settings flagged with a
-- `since` version in `recentVersions` and appends a scrolling "What's New" list
-- to the first group, mirroring them as clickable cards that activate the
-- source group. It scrolls, so the group's bottom rows (version info, promo)
-- stay pinned below it however long the list gets.
function RichBuilder:Finalize()
    if self._finalized then return end
    self._finalized = true
    if not self.recentVersions and not self.minVersion then return end

    -- What's New scans real rows for `since` flags, so pending group lambdas
    -- must run now. Panels without minVersion/recentVersions keep full laziness.
    for _, g in ipairs(self.groups) do ensureGroupBuilt(g) end

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

    -- Callers hang their version info and promo rows off this group, so it is
    -- published even when nothing is new enough to list.
    local host = self.groups[1]
    self.whatsNewGroup = host
    if #grouped == 0 then return end

    -- A group named for the list does not need the heading repeated inside it.
    if host.name ~= WHATS_NEW then host:Section(WHATS_NEW) end
    host:BeginScroll(0)

    for _, gn in ipairs(grouped) do
        host:Section(gn.group.name)
        for _, s in ipairs(gn.items) do
            host:Card({
                label       = s.label,
                since       = s.since,
                source      = s,
                sourceGroup = gn.group,
            })
        end
    end

    host:EndScroll()
    self.whatsNewGroup = host
end

function RichBuilder:Open()
    LuckySettings:Open(self.category)
end

-- ─── Title bar ────────────────────────────────────────────────────────────────

-- The addon's own version sits beside its name; the library version it is
-- running on only matters when someone is filing a bug, so it hides in the
-- tooltip rather than taking a row of its own.
local function makeTitleVersion(titleBar, titleL, version)
    local hit = CreateFrame("Frame", nil, titleBar)
    hit:SetPoint("LEFT", titleL, "RIGHT", 6, -1)

    local text = hit:CreateFontString(nil, "OVERLAY")
    text:SetFont(R_FONT, 11, "")
    text:SetPoint("LEFT")
    text:SetText("(v" .. version .. ")")
    text:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
    hit:SetSize(text:GetStringWidth(), 18)

    hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("Version " .. version)
        GameTooltip:AddLine("Lucky's Utils v"
            .. (C_AddOns.GetAddOnMetadata("Luckys_Utils", "Version") or "?"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return hit
end

-- Settings every addon in the suite has, offered as title bar buttons so they
-- don't each need a General group holding two rows.
local TITLE_TOGGLES = {
    { key = "devMode", label = "Dev Mode",
      icon = "Interface\\AddOns\\Luckys_Utils\\Media\\dev-mode.tga" },
    { key = "minimapButton", label = "Minimap Button",
      icon = "Interface\\AddOns\\Luckys_Utils\\Media\\minimap-button.tga" },
}

local TITLE_TOGGLE_OFF = { 0.34, 0.32, 0.28, 0.85 }

local function makeTitleToggle(titleBar, spec, opts)
    local checked

    local btn = LuckyUI.CreateIconButton(titleBar, {
        icon     = spec.icon,
        size     = 22,
        anchor   = "ANCHOR_BOTTOM",
        tooltip  = function(tooltip)
            tooltip:AddLine(opts.label or spec.label)
            if checked then
                tooltip:AddLine("On", R.success[1], R.success[2], R.success[3])
            else
                tooltip:AddLine("Off", 0.6, 0.6, 0.6)
            end
            if opts.desc then tooltip:AddLine(opts.desc, 0.6, 0.6, 0.6, true) end
        end,
    })

    -- Vertex colour multiplies over the texture, so tinting it gold undoes the
    -- desaturation: the off state has to be painted grey outright.
    local function paint()
        local tint = checked and LuckyUI.C.goldIcon or TITLE_TOGGLE_OFF
        btn:SetIconDesaturated(not checked)
        btn:SetIconColor(tint[1], tint[2], tint[3], tint[4])
    end
    local function readState()
        checked = resolveValue(opts.checked) and true or false
        paint()
    end
    readState()

    btn:HookScript("OnShow", readState)
    btn:SetScript("OnClick", function(self)
        checked = not checked
        paint()
        if opts.onToggle then opts.onToggle(checked) end
        self:GetScript("OnEnter")(self)
    end)

    return btn
end

-- ─── Factory ──────────────────────────────────────────────────────────────────

--- Create a rich settings panel with grouped navigation and an optional About rail.
--- When `contents` is given, it runs once on first show with the builder as its
--- argument, and Finalize() is called automatically afterwards.
---@param displayName string
---@param opts table?  { addonFolder?: string, imagesRoot?: string, showAbout?: boolean, version?: string,
---                      devMode?: table, minimapButton?: table }  -- title bar toggles: { checked, onToggle, label?, desc? }
---@param contents fun(panel: table)?  builds the groups and rows lazily
---@return table builder
function LuckySettings:NewRichPanel(displayName, opts, contents)
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

    local addonVersion = opts.version
        or (opts.addonFolder and C_AddOns.GetAddOnMetadata(opts.addonFolder, "Version"))
    if addonVersion then makeTitleVersion(titleBar, titleL, addonVersion) end

    local anchor
    for _, spec in ipairs(TITLE_TOGGLES) do
        local toggle = opts[spec.key]
        if toggle then
            local btn = makeTitleToggle(titleBar, spec, toggle)
            if anchor then
                btn:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
            else
                btn:SetPoint("RIGHT", -14, 0)
            end
            anchor = btn
        end
    end

    -- Navigation and content sit under the title bar. The About rail is
    -- optional so list-heavy panels can use the reclaimed width.
    local nav = CreateFrame("Frame", nil, content)
    nav:SetWidth(112)
    nav:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT")
    rFillBg(nav, R.bg3)
    rEdgeRule(nav, "RIGHT", R.border)

    local center = CreateFrame("Frame", nil, content)
    center:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
    rFillBg(center, R.bg)

    local showAbout = opts.showAbout ~= false
    local about
    if showAbout then
        about = CreateFrame("Frame", nil, content)
        about:SetWidth(210)
        about:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
        about:SetPoint("BOTTOMRIGHT")
        center:SetPoint("BOTTOMRIGHT", about, "BOTTOMLEFT", 0, 0)
    else
        center:SetPoint("BOTTOMRIGHT")
    end

    local builder = setmetatable({
        addonFolder    = opts.addonFolder,
        imagesRoot     = opts.imagesRoot,
        recentVersions = opts.recentVersions, -- list of versions whose settings get a NEW badge (legacy)
        minVersion     = opts.minVersion,     -- min semver; any `since` >= this gets a NEW badge
        canvas         = canvas,
        titleBar       = titleBar,
        nav            = nav,
        center         = center,
        about          = about,
        groups         = {},
        _contents      = contents,
    }, RichBuilder)

    if showAbout then buildAbout(builder) end

    builder.category = self:Register(canvas, displayName)

    canvas:HookScript("OnHide", function()
        builder.hoveredSetting = nil
        hideImagePreview()
    end)

    canvas:HookScript("OnShow", function()
        if builder._contents then
            local build = builder._contents
            builder._contents = nil -- cleared first so a build error can't rerun and double-add rows
            Log("Building lazy contents for:", displayName)
            build(builder)
            builder:Finalize()
        end
        if builder._onOpen then builder._onOpen() end
        refreshLiveValues(builder)
        if builder.activeGroup then
            ensureGroupBuilt(builder.activeGroup)
            builder:_setAboutVisibility(builder.activeGroup.showAbout)
            if builder.activeGroup.showAbout then
                aboutShow(builder, builder.hoveredSetting or firstRealSetting(builder.activeGroup))
            end
        end
    end)

    return builder
end
