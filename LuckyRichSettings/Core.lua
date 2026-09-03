-- LuckyRichSettings: high-fidelity settings panel with an optional About rail.
-- Adds LuckySettings:NewRichPanel() — a richer alternative to NewPanel for
-- addons that want grouped navigation, hover descriptions, and a screenshot
-- optional About panel. Coexists with NewPanel/Builder (the simpler single-column API).
--
-- Usage (contents lambdas — preferred):
--   LuckySettings:NewRichPanel("My Addon", {
--       addonFolder = "MyAddon_Folder",  -- image paths, and the version shown by the title
--       imagesRoot  = "images",          -- subfolder under the addon
--       db          = db,                -- store for rows that name a `key`
--   }, function(panel)
--       panel:Group("General", function(g)   -- opts table may sit between name and lambda
--           g:Toggle{ S.foo, key = "foo" }   -- strings table first: label, desc, note, warning, suffix
--           g:Toggle{ S.bar, key = "bar", parent = S.foo,
--                     onToggle = function(v) MyAddon.Bar:Apply() end }  -- runs after the write
--           g:MultiSelect{ S.raids, keys = { lfr = "logLFR", normal = "logNormal" }, options = ... }
--           g:Toggle{ label = "...", desc = "...",
--                     checked = function() return db.foo end,
--                     onToggle = function(v) db.foo = v end }
--           g:Slider{ label = "...", min = 1, max = 10, value = ..., onChanged = ... }
--           g:Select{ label = "...", options = {{ key = "a", label = "A" }},
--                     value = function() return db.pick end,
--                     onSelect = function(key) db.pick = key end,
--                     newLine = true }  -- dropdown below the label, not beside it
--           g:Button{ label = "Configure…", parent = "Some Toggle", onClick = ... }
--       end)
--       panel:Group("Per character", { db = charDB }, function(g) ... end)  -- group store wins
--   end)
-- Toggle `checked`, Slider `value` and Select `value` accept a plain value or a
-- zero-arg function. Function-valued state is re-read every time the panel opens,
-- so changes made while it was closed never show stale controls.
-- The panel lambda runs once, the first time the panel is shown, so nothing is
-- built for players who never open the settings, and values like
-- `checked = db.foo` are read at open time rather than at login. Finalize()
-- runs automatically after the panel lambda returns.
--
-- A group lambda defers further: its rows build the first time that group is
-- activated, so opening the panel only builds the group on screen. Exception:
-- a panel with minVersion/recentVersions builds every group at first show,
-- because What's New has to scan all rows for `since` flags.
--
-- Usage (imperative — still supported):
--   local panel = LuckySettings:NewRichPanel("My Addon", { ... })
--   local g = panel:Group("General")
--   g:Toggle{ ... }
--   panel:Finalize()
--
-- The module is split across LuckyRichSettings/Core.lua, About.lua, Rows.lua,
-- and Panel.lua, loaded in that order. Internals are shared through `ns.Rich`,
-- this addon's private namespace table (the host addon's when embedded), so
-- the split adds no globals.
if LuckysUtilsSkipLoad then return end

local ns = select(2, ...)
ns.Rich = {}
local Rich = ns.Rich

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
    caution     = { 0.949, 0.741, 0.259 },
    success     = { 0.353, 0.620, 0.290 },
    border      = { 1.0, 0.824, 0.392, 0.08 },
    border2     = { 1.0, 0.824, 0.392, 0.15 },
}

local R_FONT = LuckyUI.BODY_FONT

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

local function parseVersion(v)
    if type(v) ~= "string" then return nil end
    local maj, min, pat = v:match("^(%d+)%.(%d+)%.(%d+)")
    if not maj then
        maj, min = v:match("^(%d+)%.(%d+)")
        pat = "0"
    end
    if not maj then return nil end
    return tonumber(maj), tonumber(min), tonumber(pat or "0")
end

-- Returns -1, 0, 1 for a<b, a==b, a>b. nil if either unparseable.
local function compareVersions(a, b)
    local a1, a2, a3 = parseVersion(a)
    local b1, b2, b3 = parseVersion(b)
    if not a1 or not b1 then return nil end
    if a1 ~= b1 then return a1 < b1 and -1 or 1 end
    if a2 ~= b2 then return a2 < b2 and -1 or 1 end
    if a3 ~= b3 then return a3 < b3 and -1 or 1 end
    return 0
end

-- Default What's New floor when a panel names no minVersion: two minors back
-- from the addon's own .toc version, so a release cannot ship still trumpeting
-- features from several cycles ago and nobody has to bump a constant by hand.
local WHATS_NEW_MINOR_SPAN = 2

local function whatsNewFloor(addonFolder)
    if not addonFolder then return nil end
    local version = C_AddOns.GetAddOnMetadata(addonFolder, "Version") or ""
    local major, minor = version:match("^(%d+)%.(%d+)")
    if not major then return "0.0.0" end
    return major .. "." .. math.max(tonumber(minor) - WHATS_NEW_MINOR_SPAN, 0) .. ".0"
end

local function isVersionRecent(panel, since)
    if not since then return false end
    if panel.minVersion then
        local cmp = compareVersions(since, panel.minVersion)
        return cmp ~= nil and cmp >= 0
    end
    if panel.recentVersions then
        for _, v in ipairs(panel.recentVersions) do
            if v == since then return true end
        end
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

-- Public theme handles for popups/dialogs that want to match the rich panel.
LuckySettings.Rich = {
    Theme    = R,
    Font     = R_FONT,
    FillBg   = rFillBg,
    EdgeRule = rEdgeRule,
}

-- Internals shared with the other LuckyRichSettings files.
Rich.R                = R
Rich.Font             = R_FONT
Rich.FillBg           = rFillBg
Rich.EdgeRule         = rEdgeRule
Rich.RichBuilder      = RichBuilder
Rich.RichGroup        = RichGroup
Rich.isVersionRecent  = isVersionRecent
Rich.whatsNewFloor    = whatsNewFloor
Rich.firstRealSetting = firstRealSetting
