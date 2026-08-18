LuckyUtils = nil

dofile("LuckyUtils.lua")

local target = {
    nested = {
        keep = true,
    },
}

LuckyUtils.ApplyDefaults(target, {
    enabled = true,
    nested = {
        keep = false,
        added = 42,
    },
})

assert(target.enabled == true, "top-level default should be applied")
assert(target.nested.keep == true, "existing nested value should be preserved")
assert(target.nested.added == 42, "missing nested value should be applied")

assert(LuckyUtils.FormatMoney(123456) == "12g 34s 56c", "gold amount formats all denominations")
assert(LuckyUtils.FormatMoney(3456) == "34s 56c", "sub-gold amount omits gold")
assert(LuckyUtils.FormatMoney(56) == "56c", "sub-silver amount omits gold and silver")
assert(LuckyUtils.FormatMoney(0) == "0c", "zero formats as copper")

-- Debounced: a burst of calls queues one timer; the action runs once per burst.
local pendingTimers = {}
C_Timer = { After = function(_, fn) pendingTimers[#pendingTimers + 1] = fn end }

local runs = 0
local bump = LuckyUtils.Debounced(0.1, function() runs = runs + 1 end)
bump(); bump(); bump()
assert(#pendingTimers == 1, "a burst should queue a single timer")
pendingTimers[1]()
assert(runs == 1, "the action should run once per burst")
bump()
assert(#pendingTimers == 2, "a later call should queue a fresh timer")

print("3 LuckyUtils tests passed")
