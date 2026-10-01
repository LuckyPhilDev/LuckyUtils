-- luacheck: ignore 111 113 121 122

LuckyReminders = nil
LuckysUtilsSkipLoad = nil
LuckySettingsDB = nil
LuckyUtilsStrings = { reminders = { title = "Reminders", more = "and %d more", itemFallback = "Item %d" } }
UIParent = {}

local resting = false
function IsResting() return resting end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flushTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end

local reported = {}
function geterrorhandler() return function(err) reported[#reported + 1] = err end end

-- Any widget method answers with another widget, so the window builds without
-- a client; the tests read the few fields they care about directly.
local function widget()
    return setmetatable({}, { __index = function(_, key)
        if key == "IsMouseOver" then return function(self) return self.mouseOver == true end end
        if key == "IsShown" then return function(self) return self.shown ~= false end end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "Hide" then return function(self) self.shown = false end end
        if key == "SetText" then return function(self, text) self.text = text end end
        return function() return widget() end
    end })
end

local events = {}
function CreateFrame()
    local frame = widget()
    frame.SetScript = function(_, name, fn)
        if name == "OnEvent" then events.handler = fn end
        if name == "OnUpdate" then events.dim = fn end
    end
    return frame
end

LuckyUI = {
    BODY_FONT = "font",
    C = { textLight = { 1, 1, 1 }, textMuted = { 1, 1, 1 } },
    WC = { goldPrimary = "<", reset = ">" },
    CreatePanel = function() return widget() end,
    CreateHeader = function() end,
    EnableDrag = function() end,
    EnableAutoHide = function(f)
        f.StartAutoHide = function(self, seconds) self.hidesIn = seconds end
        f.StopAutoHide = function(self) self.hidesIn = false end
        f.SetAutoHideAlpha = function(self, alpha) self.alpha = alpha end
    end,
}

local NAMES = { [1] = "Cherry", [2] = "Apple", [3] = "Banana" }
LuckyItem = { GetMany = function(_, ids, onReady)
    local infos = {}
    for _, id in ipairs(ids) do
        if NAMES[id] then infos[id] = { name = NAMES[id], link = "[" .. NAMES[id] .. "]", icon = id } end
    end
    onReady(infos)
end }

dofile("LuckyReminders.lua")

local passed = 0
local function check(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local function fire(event, ...)
    events.handler(nil, event, ...)
    flushTimers()
end

local function window() return LuckyReminders.frame end

-- Sections ---------------------------------------------------------------------
local stock = { { itemID = 1, detail = "1 / 5" }, { itemID = 2, detail = "0 / 5" }, { itemID = 9, detail = "x" } }
local chores = {}
LuckyReminders:Register("stock", { title = "Low Stock", order = 20, rows = function() return stock end })
LuckyReminders:Register("chores", { order = 10, rows = function() return chores end })
LuckyReminders:Register("silent", { rows = function() end })
LuckyReminders:Register("broken", { rows = function() error("boom") end })

local sections = LuckyReminders:Sections()
check(#sections, 1, "sources with no rows, and one that errors, are left out")
check(#reported, 1, "the error is reported")

chores = { { icon = "hammer", text = "Repair your gear", detail = "35%" } }
sections = LuckyReminders:Sections()
check(sections[1].id, "chores", "lowest order first")
check(sections[2].id, "stock", "then the next")

-- Lines ------------------------------------------------------------------------
local infos = { [1] = { name = "Cherry", link = "[Cherry]", icon = 1 }, [2] = { name = "Apple", link = "[Apple]", icon = 2 } }
local lines = LuckyReminders.Lines(sections, infos)
check(#lines, 5, "a row, then a title and three items")
check(lines[1].text, "Repair your gear", "an untitled section opens with its first row")
check(lines[2].title, "Low Stock", "a titled section opens with its title")
check(lines[3].text, "Item 9", "an item that did not load falls back to its id, sorting first")
check(lines[4].text, "[Apple]", "item rows sort by name")
check(lines[5].detail, "1 / 5", "and keep their detail")

local many = {}
for i = 1, 15 do many[i] = { icon = "x", text = "row " .. i } end
lines = LuckyReminders.Lines({ { rows = many } }, {})
check(#lines, 13, "a long section is cut to twelve rows and a count")
check(lines[13].text, "and 3 more", "naming how many were cut")

-- Opening ----------------------------------------------------------------------
LuckyReminders:Refresh()
check(window(), nil, "a refresh never opens the window")

fire("PLAYER_UPDATE_RESTING")
check(window(), nil, "nor does a resting update before the world is entered")

fire("PLAYER_ENTERING_WORLD", true, false)
check(window():IsShown(), true, "logging in opens it")
check(window().hidesIn, 10, "on the default timer")

window():Hide()
fire("PLAYER_ENTERING_WORLD", false, false)
check(window():IsShown(), false, "a zone change does not")

resting = true
fire("PLAYER_UPDATE_RESTING")
check(window():IsShown(), true, "entering a rest area does")

-- Timer ------------------------------------------------------------------------
LuckyReminders.Saved().seconds = 0
LuckyReminders:Show()
check(window().hidesIn, false, "a timer of 0 leaves the window up")

LuckyReminders.Saved().seconds = 25
LuckyReminders.Saved().stayWhileResting = true
LuckyReminders:Show()
check(window().hidesIn, false, "held open while resting")

resting = false
fire("PLAYER_UPDATE_RESTING")
check(window().hidesIn, 25, "and timed once you leave")

-- Dimming ----------------------------------------------------------------------
local function tick(elapsed) events.dim(nil, elapsed) end

LuckyReminders:Show()
tick(3)
tick(1)
check(window().alpha, 0.3, "out of the box it dims to 30% after three seconds")

LuckyReminders.Saved().dimSeconds = 0
LuckyReminders:Show()
tick(60)
check(window().alpha, 1, "a dim wait of 0 never dims")

LuckyReminders.Saved().dimSeconds = 5
LuckyReminders.Saved().dimAlpha = 0.4
LuckyReminders:Show()
tick(4)
check(window().alpha, 1, "full brightness for the wait")
tick(0.875)
tick(0.125)
check(window().alpha, 0.5, "then it fades")
tick(1)
check(window().alpha, 0.4, "down to the dimmed opacity")

window().mouseOver = true
tick(1)
check(window().alpha, 1, "hovering brings it back")
window().mouseOver = false
tick(4)
check(window().alpha, 1, "and leaving gives the whole wait again")
tick(2)
check(window().alpha, 0.4, "before it dims once more")

LuckyReminders:Refresh()
check(window().alpha, 0.4, "a redraw leaves it dimmed")
LuckyReminders:Show()
check(window().alpha, 1, "opening it again starts bright")
LuckyReminders.Saved().dimSeconds = nil

-- Clearing ---------------------------------------------------------------------
window().hidesIn = "untouched"
chores = {}
LuckyReminders:Refresh()
check(window():IsShown(), true, "one section clearing leaves the rest up")
check(window().hidesIn, "untouched", "without restarting the timer")

stock = {}
LuckyReminders:Refresh()
check(window():IsShown(), false, "the last row clearing closes the window")

LuckyReminders:Show()
check(window():IsShown(), false, "and with nothing to remind about it stays shut")

print(passed .. " LuckyReminders tests passed")
