-- luacheck: globals LibStub LuckysUtilsSkipLoad LuckyUtils

-- Two copies of the library loading in one session: LibStub must let exactly
-- one copy's files run, whichever registers the highest minor first, and the
-- gate flag must steer every subsequent file of a losing copy away.

LibStub = nil
LuckysUtilsSkipLoad = nil
LuckyUtils = nil

-- First copy loads: registers and runs.
dofile("LibStub.lua")
dofile("VersionGate.lua")
assert(LuckysUtilsSkipLoad == false, "first copy should run")
dofile("LuckyUtils.lua")
assert(type(LuckyUtils.FormatMoney) == "function", "first copy defines the API")
local firstFormatMoney = LuckyUtils.FormatMoney

-- Second copy with the same minor loads: must be gated off entirely.
dofile("LibStub.lua")
dofile("VersionGate.lua")
assert(LuckysUtilsSkipLoad == true, "equal-minor copy must be skipped")
LuckyUtils.FormatMoney = "sentinel-not-replaced"
dofile("LuckyUtils.lua")
assert(LuckyUtils.FormatMoney == "sentinel-not-replaced",
    "a gated copy's files must not redefine the API")
LuckyUtils.FormatMoney = firstFormatMoney

-- Exactly one library registration, at the current minor.
local lib, minor = LibStub("LuckysUtils-1.0")
assert(lib ~= nil, "library must be registered")
assert(minor == 1, "registered minor should be 1, got " .. tostring(minor))

-- A newer minor must win: it reruns the files and replaces function bodies.
local realNewLibrary = LibStub.NewLibrary
LibStub.NewLibrary = function(self, major, _)  -- simulate a copy built as minor 2
    return realNewLibrary(self, major, 2)
end
dofile("VersionGate.lua")
LibStub.NewLibrary = realNewLibrary
assert(LuckysUtilsSkipLoad == false, "newer copy should run")
dofile("LuckyUtils.lua")
assert(type(LuckyUtils.FormatMoney) == "function"
    and LuckyUtils.FormatMoney ~= "sentinel-not-replaced",
    "newer copy must replace function bodies")
assert(select(2, LibStub("LuckysUtils-1.0")) == 2, "minor should now be 2")

print("VersionGate tests passed")
