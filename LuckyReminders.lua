-- LuckyReminders: one window of things to go and do, opened at login and on
-- entering a rest area. Any Lucky addon adds a section of rows to it:
--
--   LuckyReminders:Register("lowStock", {
--       title = "Low Stock",   -- optional, a section without one has no title line
--       order = 20,            -- lowest first, default 100
--       rows  = function() return { { itemID = 1234, detail = "3 / 20" } } end,
--   })
--
-- rows() is asked again on every redraw and returns nil or an empty list while
-- there is nothing to remind about. A row is { icon, text, detail }, or
-- { itemID, detail } to have the item's icon and link filled in; a section of
-- item rows sorts by name. Call LuckyReminders:Refresh() when the rows change.

if LuckysUtilsSkipLoad then return end

LuckyReminders = LuckyReminders or {}

local Reminders = LuckyReminders
local S = LuckyUtilsStrings.reminders

local DEFAULT_SECONDS = 10
-- Bag contents are still streaming in at PLAYER_ENTERING_WORLD.
local LOGIN_DELAY = 2
local MAX_ROWS = 12
local ROW_H = 22
local HEADER_H = 36
local ICON_INDENT = 24
local FALLBACK_ICON = 134400
local DEFAULT_ORDER = 100
local DEFAULT_DIM_SECONDS = 3
local DEFAULT_DIM_ALPHA = 0.3
local DIM_FADE = 0.25

-- State lives on the global so a newer library copy inherits it.
Reminders.sources = Reminders.sources or {}

--- The account-wide settings: seconds, stayWhileResting, dimSeconds, dimAlpha
--- and pos.
function Reminders.Saved()
    LuckySettingsDB = LuckySettingsDB or {}
    LuckySettingsDB.reminders = LuckySettingsDB.reminders or {}
    return LuckySettingsDB.reminders
end

local function Seconds()
    return Reminders.Saved().seconds or DEFAULT_SECONDS
end

local function DimSeconds()
    return Reminders.Saved().dimSeconds or DEFAULT_DIM_SECONDS
end

local function DimAlpha()
    return Reminders.Saved().dimAlpha or DEFAULT_DIM_ALPHA
end

local function StaysOpen()
    return Seconds() == 0 or (Reminders.Saved().stayWhileResting == true and IsResting())
end

function Reminders:Register(id, source)
    self.sources[id] = source
end

--- Every source's rows, lowest order first, leaving out sources with none. A
--- source that errors is reported and skipped, so it cannot blank the rest.
function Reminders:Sections()
    local sections = {}
    for id, source in pairs(self.sources) do
        local ok, rows = xpcall(source.rows, geterrorhandler())
        if ok and rows and #rows > 0 then
            sections[#sections + 1] = {
                id = id, title = source.title, order = source.order or DEFAULT_ORDER, rows = rows,
            }
        end
    end
    table.sort(sections, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    return sections
end

local function ItemLine(row, info)
    return {
        icon   = info and info.icon or FALLBACK_ICON,
        text   = info and info.link or S.itemFallback:format(row.itemID),
        detail = row.detail,
        name   = info and info.name or "",
    }
end

--- The window's lines, top to bottom: each section's title, then its rows.
function Reminders.Lines(sections, infos)
    local lines = {}
    for _, section in ipairs(sections) do
        if section.title then lines[#lines + 1] = { title = section.title } end
        local rows = {}
        for i, row in ipairs(section.rows) do
            rows[i] = row.itemID and ItemLine(row, infos[row.itemID]) or row
        end
        if section.rows[1].itemID then
            table.sort(rows, function(a, b) return (a.name or "") < (b.name or "") end)
        end
        for i = 1, math.min(#rows, MAX_ROWS) do lines[#lines + 1] = rows[i] end
        if #rows > MAX_ROWS then lines[#lines + 1] = { text = S.more:format(#rows - MAX_ROWS) } end
    end
    return lines
end

local function Approach(current, target, step)
    if current < target then return math.min(target, current + step) end
    return math.max(target, current - step)
end

-- Dims the window once it has sat unhovered for the dim wait, and brings it
-- back under the mouse. Runs on a child because the auto-hide owns the
-- window's own OnUpdate.
local function WatchDim(f)
    f.dimmer = CreateFrame("Frame", nil, f)
    f.dimmer:SetScript("OnUpdate", function(_, elapsed)
        local wait = DimSeconds()
        if wait == 0 or f:IsMouseOver() then
            f.brightLeft = wait
        else
            f.brightLeft = math.max(0, f.brightLeft - elapsed)
        end
        local target = (wait == 0 or f.brightLeft > 0) and 1 or DimAlpha()
        if target ~= f.dimLevel then
            f.dimLevel = Approach(f.dimLevel, target, elapsed / DIM_FADE)
            f:SetAutoHideAlpha(f.dimLevel)
        end
    end)
end

local function Brighten(f)
    f.brightLeft, f.dimLevel = DimSeconds(), 1
    f:SetAutoHideAlpha(1)
end

local function Frame()
    if Reminders.frame then return Reminders.frame end
    local f = LuckyUI.CreatePanel("LuckyRemindersFrame", UIParent, 340, 100)
    LuckyUI.CreateHeader(f, S.title)
    f:SetFrameStrata("MEDIUM")
    LuckyUI.EnableDrag(f, { db = Reminders.Saved(), key = "pos", default = { "TOPLEFT", "TOPLEFT", 20, -120 } })
    LuckyUI.EnableAutoHide(f, DEFAULT_SECONDS)
    WatchDim(f)
    Brighten(f)
    f.lines = {}
    Reminders.frame = f
    return f
end

local function Line(f, i)
    local line = f.lines[i]
    if line then return line end
    local C = LuckyUI.C
    line = CreateFrame("Frame", nil, f)
    line:SetHeight(ROW_H)
    line:SetPoint("TOPLEFT", 10, -HEADER_H - (i - 1) * ROW_H)
    line:SetPoint("RIGHT", -10, 0)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(18, 18)
    line.icon:SetPoint("LEFT")
    line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    line.detail = line:CreateFontString(nil, "OVERLAY")
    line.detail:SetFont(LuckyUI.BODY_FONT, 12, "")
    line.detail:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    line.detail:SetPoint("RIGHT")
    line.text = line:CreateFontString(nil, "OVERLAY")
    line.text:SetFont(LuckyUI.BODY_FONT, 12, "")
    line.text:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    line.text:SetJustifyH("LEFT")
    line.text:SetPoint("RIGHT", line.detail, "LEFT", -8, 0)
    f.lines[i] = line
    return line
end

local function Draw(f, lines)
    local WC = LuckyUI.WC
    for i, entry in ipairs(lines) do
        local line = Line(f, i)
        line.icon:SetTexture(entry.icon)
        line.text:SetPoint("LEFT", line, "LEFT", entry.title and 0 or ICON_INDENT, 0)
        line.text:SetText(entry.title and (WC.goldPrimary .. entry.title .. WC.reset) or entry.text)
        line.detail:SetText(entry.detail or "")
        line:Show()
    end
    for i = #lines + 1, #f.lines do f.lines[i]:Hide() end
    f:SetHeight(HEADER_H + #lines * ROW_H + 10)
end

local function RunTimer(f)
    if StaysOpen() then
        f:StopAutoHide()
    else
        f:StartAutoHide(Seconds())
    end
end

-- With open false the window is only redrawn if it is already up, so a row
-- clearing shrinks the list without popping the window back open.
local function Render(open)
    local sections = Reminders:Sections()
    local f = Reminders.frame
    if #sections == 0 then
        if f and f:IsShown() then
            f:StopAutoHide()
            f:Hide()
        end
        return
    end
    if not open and not (f and f:IsShown()) then return end

    local itemIDs = {}
    for _, section in ipairs(sections) do
        for _, row in ipairs(section.rows) do
            if row.itemID then itemIDs[#itemIDs + 1] = row.itemID end
        end
    end
    LuckyItem:GetMany(itemIDs, function(infos)
        f = Frame()
        if not open and not f:IsShown() then return end
        Draw(f, Reminders.Lines(sections, infos))
        f:Show()
        if not open then return end
        Brighten(f)
        RunTimer(f)
    end)
end

function Reminders:Show()
    Render(true)
end

function Reminders:Refresh()
    Render(false)
end

--- The window's timer, its hold while resting and its dimming, for any Lucky
--- addon's rich settings group. Every addon's copy reads and writes the same account-wide
--- values.
function Reminders:AddSettings(group, since)
    local function Apply()
        local f = Reminders.frame
        if f and f:IsShown() then RunTimer(f) end
    end
    group:Slider({
        label     = S.seconds,
        desc      = S.secondsDesc,
        key       = "LuckyRemindersSeconds",
        since     = since,
        min       = 0,
        max       = 60,
        suffix    = S.secondsUnit,
        value     = Seconds,
        onChanged = function(value)
            Reminders.Saved().seconds = value
            Apply()
        end,
    })
    group:Slider({
        label     = S.dimSeconds,
        desc      = S.dimSecondsDesc,
        key       = "LuckyRemindersDimSeconds",
        since     = since,
        min       = 0,
        max       = 60,
        suffix    = S.secondsUnit,
        value     = DimSeconds,
        onChanged = function(value)
            Reminders.Saved().dimSeconds = value
            if Reminders.frame then Brighten(Reminders.frame) end
        end,
    })
    group:Slider({
        label     = S.dimAlpha,
        desc      = S.dimAlphaDesc,
        key       = "LuckyRemindersDimAlpha",
        since     = since,
        min       = 10,
        max       = 100,
        step      = 5,
        suffix    = S.percentUnit,
        value     = function() return math.floor(DimAlpha() * 100 + 0.5) end,
        onChanged = function(value) Reminders.Saved().dimAlpha = value / 100 end,
    })
    group:Toggle({
        label    = S.stay,
        desc     = S.stayDesc,
        since    = since,
        checked  = function() return Reminders.Saved().stayWhileResting == true end,
        onToggle = function(checked)
            Reminders.Saved().stayWhileResting = checked
            Apply()
        end,
    })
end

local function OnRestingChanged()
    local resting = IsResting()
    -- Nil until the login delay is under way, so a resting update that beats
    -- PLAYER_ENTERING_WORLD cannot open the window early.
    if Reminders.wasResting == nil or resting == Reminders.wasResting then return end
    Reminders.wasResting = resting
    local f = Reminders.frame
    if resting then
        Reminders:Show()
    elseif f and f:IsShown() and Reminders.Saved().stayWhileResting then
        RunTimer(f)
    end
end

local watcher = Reminders.watcher or CreateFrame("Frame")
Reminders.watcher = watcher
watcher:UnregisterAllEvents()
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_UPDATE_RESTING")
watcher:SetScript("OnEvent", function(_, event, isLogin, isReload)
    if event == "PLAYER_ENTERING_WORLD" and (isLogin or isReload) then
        Reminders.wasResting = IsResting()
        C_Timer.After(LOGIN_DELAY, function() Reminders:Show() end)
    else
        -- A summon or portal out of a rest area can skip PLAYER_UPDATE_RESTING,
        -- so every world entry rechecks.
        OnRestingChanged()
    end
end)
