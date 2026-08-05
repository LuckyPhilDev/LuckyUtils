LuckyBugs = nil

dofile("LuckyBugs/Core.lua")

local passed = 0

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function newRecorder(overrides)
    overrides = overrides or {}
    local clock = 0
    local prompted = {}
    local recorder = LuckyBugs:NewRecorder({
        now             = function() clock = clock + 1 return "t" .. clock end,
        isPromptEnabled = overrides.isPromptEnabled or function() return true end,
        onPrompt        = function(entry) prompted[#prompted + 1] = entry end,
        maxLog          = overrides.maxLog,
        maxPrompts      = overrides.maxPrompts,
    })
    return recorder, prompted
end

local GRABBAG_ERROR = "Interface/AddOns/Luckys_Grab_Bag/features/AutoRepair.lua:42: attempt to index a nil value"
local GRABBAG_STACK = "Interface/AddOns/Luckys_Grab_Bag/features/AutoRepair.lua:42: in function `Repair'"

-- Relevance -----------------------------------------------------------------

assertEqual(LuckyBugs.IsLuckyError(GRABBAG_ERROR), true, "lucky path is ours")
assertEqual(LuckyBugs.IsLuckyError("Interface/AddOns/SomeOtherAddon/Core.lua:9: boom"), false,
    "other addon is not ours")
passed = passed + 1

-- Attribution ---------------------------------------------------------------

assertEqual(LuckyBugs.AddonFolder(GRABBAG_ERROR), "Luckys_Grab_Bag", "folder from a forward-slash path")
assertEqual(LuckyBugs.AddonFolder("Interface\\AddOns\\Luckys_Loot_Wishlist\\Core.lua:3: boom"),
    "Luckys_Loot_Wishlist", "folder from a backslash path")
assertEqual(
    LuckyBugs.AddonFolder("Interface/AddOns/Luckys_Utils/LuckyUI.lua:12: boom\n"
        .. "Interface/AddOns/Luckys_Character_Mount/Core.lua:80: in function `Init'"),
    "Luckys_Character_Mount", "blames the addon rather than the shared library")
assertEqual(LuckyBugs.AddonFolder("Interface/AddOns/Luckys_Utils/LuckyUI.lua:12: boom"),
    "Luckys_Utils", "falls back to the shared library when it is alone")
passed = passed + 1

-- Capture and filtering -----------------------------------------------------

do
    local recorder, prompted = newRecorder()

    local ignored, promptedIgnored = recorder:Capture("Interface/AddOns/Other/Core.lua:1: boom", "")
    assertEqual(ignored, nil, "another addon's error is not recorded")
    assertEqual(promptedIgnored, false, "another addon's error does not prompt")

    local entry, wasPrompted = recorder:Capture(GRABBAG_ERROR, GRABBAG_STACK)
    assertEqual(entry.folder, "Luckys_Grab_Bag", "entry records the addon folder")
    assertEqual(entry.count, 1, "first occurrence counts once")
    assertEqual(wasPrompted, true, "first occurrence prompts")
    assertEqual(#prompted, 1, "prompt callback fired once")
    assertEqual(#recorder:Entries(), 1, "one entry recorded")
    passed = passed + 1
end

-- De-duplication ------------------------------------------------------------

do
    local recorder, prompted = newRecorder()
    recorder:Capture(GRABBAG_ERROR, GRABBAG_STACK)
    local repeated, wasPrompted = recorder:Capture(GRABBAG_ERROR, GRABBAG_STACK)

    assertEqual(#recorder:Entries(), 1, "a repeat does not add an entry")
    assertEqual(repeated.count, 2, "a repeat bumps the count")
    assertEqual(wasPrompted, false, "a repeat does not prompt again")
    assertEqual(#prompted, 1, "prompt callback still fired once")
    passed = passed + 1
end

do
    local recorder = newRecorder()
    recorder:Capture("Interface/AddOns/Luckys_Grab_Bag/Core.lua:7: bad argument to table: 0x1a2b3c", "")
    recorder:Capture("Interface/AddOns/Luckys_Grab_Bag/Core.lua:7: bad argument to table: 0xff0099", "")

    assertEqual(#recorder:Entries(), 1, "differing table addresses are the same bug")
    passed = passed + 1
end

-- Prompt limits -------------------------------------------------------------

do
    local recorder, prompted = newRecorder({ maxPrompts = 2 })
    for i = 1, 4 do
        recorder:Capture("Interface/AddOns/Luckys_Grab_Bag/Core.lua:" .. i .. ": boom", "")
    end

    assertEqual(#prompted, 2, "prompts stop at the session limit")
    assertEqual(#recorder:Entries(), 4, "errors are still recorded after the prompt limit")
    passed = passed + 1
end

do
    local recorder, prompted = newRecorder({ isPromptEnabled = function() return false end })
    local _, wasPrompted = recorder:Capture(GRABBAG_ERROR, GRABBAG_STACK)

    assertEqual(wasPrompted, false, "prompting off means no prompt")
    assertEqual(#prompted, 0, "prompt callback not fired")
    assertEqual(#recorder:Entries(), 1, "error is still recorded while prompting is off")
    passed = passed + 1
end

-- Log size and seeding ------------------------------------------------------

do
    local recorder = newRecorder({ maxLog = 3 })
    for i = 1, 5 do
        recorder:Capture("Interface/AddOns/Luckys_Grab_Bag/Core.lua:" .. i .. ": boom", "")
    end
    local entries = recorder:Entries()

    assertEqual(#entries, 3, "log is capped")
    assertEqual(entries[1].message:find(":5:", 1, true) ~= nil, true, "newest error is first")
    passed = passed + 1
end

do
    local recorder = newRecorder({ maxLog = 3 })
    recorder:Capture(GRABBAG_ERROR, GRABBAG_STACK)
    recorder:Seed({
        { message = "old one", count = 1 },
        { message = "old two", count = 1 },
        { message = "old three", count = 1 },
    })
    local entries = recorder:Entries()

    assertEqual(#entries, 3, "seeding respects the log cap")
    assertEqual(entries[1].message, GRABBAG_ERROR, "this session stays newest")
    assertEqual(entries[2].previousSession, true, "seeded entries are marked")
    passed = passed + 1
end

do
    local recorder = newRecorder()
    for i = 1, 4 do
        recorder:Capture("Interface/AddOns/Luckys_Grab_Bag/Core.lua:" .. i .. ": boom", "")
    end

    assertEqual(#recorder:Recent(2), 2, "Recent returns the requested count")
    assertEqual(#recorder:Recent(99), 4, "Recent never returns more than it has")
    passed = passed + 1
end

-- Report text ---------------------------------------------------------------

do
    local recorder = newRecorder()
    local entry = recorder:Capture(GRABBAG_ERROR, GRABBAG_STACK)
    local report = LuckyBugs.FormatReport(entry, {
        addon  = "Lucky's Grab-bag 1.4.2",
        utils  = "1.7.3",
        build  = "11.2.0 (61234)",
        locale = "enGB",
    })

    assertEqual(report:find("Lucky's Grab-bag 1.4.2", 1, true) ~= nil, true, "report names the addon")
    assertEqual(report:find("seen 1x", 1, true) ~= nil, true, "report shows the occurrence count")
    assertEqual(report:find(GRABBAG_ERROR, 1, true) ~= nil, true, "report includes the message")
    assertEqual(report:find(GRABBAG_STACK, 1, true) ~= nil, true, "report includes the stack")
    passed = passed + 1
end

do
    local recorder = newRecorder()
    local entry = recorder:Capture(GRABBAG_ERROR, string.rep("Luckys_Grab_Bag/Core.lua:1\n", 300))
    local report = LuckyBugs.FormatReport(entry, {})

    assertEqual(#report < 2000, true, "report stays inside a Discord message")
    assertEqual(report:find("(truncated)", 1, true) ~= nil, true, "truncation is marked")
    passed = passed + 1
end

print(string.format("%d LuckyBugs tests passed", passed))
