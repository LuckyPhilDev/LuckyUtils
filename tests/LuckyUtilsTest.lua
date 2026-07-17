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

print("1 LuckyUtils test passed")
