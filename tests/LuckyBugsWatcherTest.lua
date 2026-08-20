-- Drives LuckyBugs/Watcher.lua end to end against a stubbed WoW API: error
-- handler chaining, the prompt, the report window, and SavedVariables.

local shown, timers, frames = {}, {}, {}
local inCombat = false

local function stubFrame()
    local f = {}
    setmetatable(f, { __index = function() return function() return f end end })
    f.SetScript        = function(_, script, fn) f[script] = fn return f end
    f.SetText          = function(_, text) rawset(f, "shownText", text) end
    f.GetText          = function() return rawget(f, "shownText") end
    f.CreateFontString = function() return stubFrame() end
    f.CreateTexture    = function() return stubFrame() end
    f.GetName          = function() return "LuckyBugsReport" end
    frames[#frames + 1] = f
    return f
end

CreateFrame        = function() return stubFrame() end
CreateColor        = function() return {} end
UIParent           = stubFrame()
UISpecialFrames    = {}
StaticPopupDialogs = {}
StaticPopup_Show   = function(which, arg1) shown[#shown + 1] = { which = which, arg1 = arg1 } end
InCombatLockdown   = function() return inCombat end
C_Timer            = { After = function(_, fn) timers[#timers + 1] = fn end }
C_AddOns           = {
    GetAddOnMetadata = function(_, field)
        if field == "Title" then return "|cffffd100Lucky's Grab-bag|r" end
        if field == "Version" then return "1.4.2" end
    end,
}
GetBuildInfo = function() return "11.2.0", "61234" end
GetLocale    = function() return "enGB" end
tinsert      = table.insert
date         = os.date
SlashCmdList = {}

-- A real stack names the file that raised, so the stub echoes it back.
local lastRaised = ""
debugstack = function() return lastRaised .. ": in function `Handler'" end

local previousHandlerCalls = 0
local handler = function() previousHandlerCalls = previousHandlerCalls + 1 end
geterrorhandler = function() return handler end
seterrorhandler = function(h) handler = h end

dofile("LuckyStrings.lua")
dofile("Strings.lua")
dofile("LuckyUI.lua")
dofile("LuckyBugs/Core.lua")
dofile("LuckyBugs/Watcher.lua")

local passed = 0

-- The watcher confirms its slash commands in chat; keep that out of the results.
local realPrint = print
print = function() end

local function check(condition, label)
    if not condition then error("FAILED: " .. label, 2) end
    passed = passed + 1
end

local function raise(message)
    lastRaised = message
    handler(message)
end

local function fire(event, ...)
    for _, f in ipairs(frames) do
        if f.OnEvent then f.OnEvent(f, event, ...) end
    end
end

check(handler ~= nil, "error handler installed as the file loads")

-- SavedVariables arrive before ADDON_LOADED, carrying one error from last time.
LuckySettingsDB = { bugs = { prompt = true, log = {
    { message = "Interface/AddOns/Luckys_Grab_Bag/Old.lua:1: stale", count = 4, when = "yesterday" },
} } }
fire("ADDON_LOADED", "SomeOtherAddon")
fire("ADDON_LOADED", "Luckys_Utils")

raise("Interface/AddOns/Luckys_Grab_Bag/features/AutoRepair.lua:42: attempt to index a nil value")
check(previousHandlerCalls == 1, "chains to the previous error handler")
check(#timers == 1, "prompt is deferred out of the error handler")

timers[1]()
check(#shown == 1, "prompt shown")
check(shown[1].which == "LUCKY_BUGS_REPORT", "prompt uses the LuckyBugs dialog")
check(shown[1].arg1 == "Lucky's Grab-bag", "prompt names the addon without colour codes")

raise("Interface/AddOns/SomeoneElse/Core.lua:9: boom")
check(previousHandlerCalls == 2, "another addon's error still reaches the previous handler")
check(#timers == 1, "another addon's error never prompts")

inCombat = true
raise("Interface/AddOns/Luckys_Grab_Bag/Core.lua:99: second bug")
check(#timers == 2, "a second error queues a prompt")
timers[2]()
check(#shown == 1, "prompt is held back during combat")

inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(#shown == 2, "held prompt shows once combat ends")

LuckyBugs:Show()
local counter, report
for _, f in ipairs(frames) do
    local text = rawget(f, "shownText")
    if text and text:find("Error 1 of", 1, true) then counter = f end
    if text and text:find("second bug", 1, true) then report = f end
end
check(counter ~= nil, "report window shows a counter")
check(counter:GetText() == "Error 1 of 3", "counter covers this session and the seeded error")
check(report ~= nil, "report window opens on the newest error")
check(report:GetText():find("Lucky's Grab-bag 1.4.2", 1, true) ~= nil, "report names the addon and version")
check(report:GetText():find("WoW 11.2.0 (61234)", 1, true) ~= nil, "report names the game build")
check(#UISpecialFrames == 1, "report window closes with Escape")

StaticPopupDialogs["LUCKY_BUGS_REPORT"].OnAlt()
check(LuckySettingsDB.bugs.prompt == false, "Stop Asking turns prompting off")

raise("Interface/AddOns/Luckys_Grab_Bag/Core.lua:120: third bug")
check(#timers == 2, "no prompt once the user has opted out")

SlashCmdList["LUCKYBUGS"]("on")
check(LuckySettingsDB.bugs.prompt == true, "/luckybugs on turns prompting back on")
SlashCmdList["LUCKYBUGS"]("off")
check(LuckySettingsDB.bugs.prompt == false, "/luckybugs off turns prompting off")

fire("PLAYER_LOGOUT")
check(#LuckySettingsDB.bugs.log == 4, "errors are saved for the next session")
check(LuckySettingsDB.bugs.log[1].message:find("third bug", 1, true) ~= nil, "newest error is saved first")

realPrint(string.format("%d LuckyBugs watcher tests passed", passed))
