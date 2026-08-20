-- luacheck: globals LuckyStrings

-- A sealed strings table has to keep behaving like the plain table it replaced:
-- real keys read through, iteration is untouched, and only a genuine miss turns
-- into the red placeholder.
--
-- Run from the addon root: lua tests/LuckyStringsTest.lua

dofile("LuckyStrings.lua")

local S = LuckyStrings.New("Test", {
    top = "top level",
    nested = {
        one = "first",
        deeper = { two = "second" },
    },
    list = { "a", "b" },
})

local function check(condition, label)
    if not condition then error("FAILED: " .. label, 2) end
end

check(S.top == "top level", "a real top-level key reads through")
check(S.nested.one == "first", "a real nested key reads through")
check(S.nested.deeper.two == "second", "sealing recurses to any depth")

check(S.missing == "|cffff0000[Test.missing]|r", "a top-level miss names itself")
check(S.nested.missing == "|cffff0000[Test.nested.missing]|r", "a nested miss names its full path")
check(S.nested.deeper.gone == "|cffff0000[Test.nested.deeper.gone]|r", "a deep miss names its full path")

local keys = 0
for _ in pairs(S.nested) do keys = keys + 1 end
check(keys == 2, "pairs still sees only the real keys")

check(#S.list == 2 and S.list[1] == "a", "an array part is left alone")

print("LuckyStrings tests passed")
