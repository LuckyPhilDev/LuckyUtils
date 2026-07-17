LuckyBankQueue = nil

dofile("LuckyBankQueue.lua")

local passed = 0

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function key(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

local function newHarness(initial, initialCursor)
    local containers = initial
    local cursor = initialCursor
    local scheduled = 0

    local function getInfo(bag, slot)
        return containers[key(bag, slot)]
    end

    local function pickup(bag, slot)
        local containerKey = key(bag, slot)
        local item = containers[containerKey]
        if not cursor then
            if not item then return end
            cursor = { itemID = item.itemID, count = item.count }
            containers[containerKey] = nil
            return
        end

        if not item then
            containers[containerKey] = cursor
            cursor = nil
            return
        end

        if item.itemID == cursor.itemID then
            item.count = item.count + cursor.count
            cursor = nil
        else
            containers[containerKey], cursor = cursor, item
        end
    end

    local function split(bag, slot, amount)
        local containerKey = key(bag, slot)
        local item = containers[containerKey]
        if not item or amount <= 0 or amount >= item.count then return end
        item.count = item.count - amount
        cursor = { itemID = item.itemID, count = amount }
    end

    return {
        containers = containers,
        options = {
            getContainerItemInfo = getInfo,
            pickupContainerItem = pickup,
            splitContainerItem = split,
            getCursorInfo = function()
                return cursor and "item" or nil, cursor and cursor.itemID or nil
            end,
            schedule = function(_, callback)
                scheduled = scheduled + 1
                callback()
            end,
            findDestination = function(_, excluded, step)
                local destination = step.destination
                local destinationKey = key(destination.bag, destination.slot)
                if excluded[destinationKey] then return nil end
                return destination.bag, destination.slot
            end,
        },
        scheduledCount = function() return scheduled end,
        cursorItemID = function() return cursor and cursor.itemID or nil end,
    }
end

local harness = newHarness({
    ["0:1"] = { itemID = 1001, count = 5 },
    ["0:2"] = { itemID = 1002, count = 3 },
})
local completed = false
local queue = LuckyBankQueue:New(harness.options)
queue:Enqueue({ sourceBag = 0, sourceSlot = 1, itemID = 1001, amount = 2, destination = { bag = 10, slot = 1 } })
queue:Enqueue({ sourceBag = 0, sourceSlot = 2, itemID = 1002, destination = { bag = 10, slot = 2 } })
queue:Start(function() completed = true end)

assertEqual(completed, true, "queue completion")
assertEqual(queue:IsRunning(), false, "queue stopped")
assertEqual(queue:GetPendingCount(), 0, "queue drained")
assertEqual(harness.containers["0:1"].count, 3, "split source remainder")
assertEqual(harness.containers["10:1"].count, 2, "split destination count")
assertEqual(harness.containers["0:2"], nil, "whole source moved")
assertEqual(harness.containers["10:2"].count, 3, "whole destination count")
passed = passed + 1

local lockedHarness = newHarness({
    ["0:1"] = { itemID = 2001, count = 1, isLocked = true },
})
local originalSchedule = lockedHarness.options.schedule
lockedHarness.options.schedule = function(delay, callback)
    local source = lockedHarness.containers["0:1"]
    if source then
        source.isLocked = false
    end
    originalSchedule(delay, callback)
end
local lockedComplete = false
local lockedQueue = LuckyBankQueue:New(lockedHarness.options)
lockedQueue:Enqueue({ sourceBag = 0, sourceSlot = 1, itemID = 2001, destination = { bag = 10, slot = 1 } })
lockedQueue:Start(function() lockedComplete = true end)
assertEqual(lockedComplete, true, "locked source eventually completes")
assert(lockedHarness.scheduledCount() > 0, "locked source should poll")
passed = passed + 1

local failedCode
local failedHarness = newHarness({
    ["0:1"] = { itemID = 3001, count = 1 },
})
failedHarness.options.findDestination = function() return nil end
failedHarness.options.onError = function(_, _, code) failedCode = code end
local failedQueue = LuckyBankQueue:New(failedHarness.options)
failedQueue:Enqueue({ sourceBag = 0, sourceSlot = 1, itemID = 3001 })
failedQueue:Start()
assertEqual(failedCode, "destination_missing", "missing destination error")
assertEqual(failedQueue:IsRunning(), false, "failed queue stopped")
assertEqual(failedHarness.containers["0:1"].itemID, 3001, "failed transfer restores source")
passed = passed + 1

local alternateHarness = newHarness({
    ["0:1"] = { itemID = 4001, count = 1 },
    ["10:1"] = { itemID = 4999, count = 1 },
})
alternateHarness.options.findDestination = function(_, excluded)
    if not excluded["10:1"] then return 10, 1 end
    return 10, 2
end
local alternateQueue = LuckyBankQueue:New(alternateHarness.options)
alternateQueue:Enqueue({ sourceBag = 0, sourceSlot = 1, itemID = 4001 })
alternateQueue:Start()
assertEqual(alternateHarness.containers["10:1"].itemID, 4999, "incompatible destination unchanged")
assertEqual(alternateHarness.containers["10:2"].itemID, 4001, "alternate destination receives item")
passed = passed + 1

local busyHarness = newHarness({
    ["0:1"] = { itemID = 5001, count = 1 },
}, { itemID = 5999, count = 1 })
local busyCode
busyHarness.options.onError = function(_, _, code) busyCode = code end
local busyQueue = LuckyBankQueue:New(busyHarness.options)
busyQueue:Enqueue({ sourceBag = 0, sourceSlot = 1, itemID = 5001, destination = { bag = 10, slot = 1 } })
busyQueue:Start()
assertEqual(busyCode, "cursor_busy", "busy cursor error")
assertEqual(busyHarness.containers["0:1"].itemID, 5001, "busy cursor leaves source unchanged")
assertEqual(busyHarness.cursorItemID(), 5999, "busy cursor remains untouched")
passed = passed + 1

print(string.format("%d LuckyBankQueue tests passed", passed))
