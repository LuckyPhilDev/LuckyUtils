-- luacheck: globals LibStub LuckysUtilsSkipLoad LuckysUtilsHosts LuckyMedia LuckyIcon LuckyUtils

-- Two copies of the library loading in one session: LibStub must let exactly
-- one copy's files run, whichever registers the highest minor first, and the
-- gate flag must steer every subsequent file of a losing copy away.

LibStub = nil
LuckysUtilsSkipLoad = nil
LuckysUtilsHosts = nil
LuckyMedia = nil
LuckyIcon = nil
LuckyUtils = nil

-- First copy loads: registers and runs. Loaded via dofile, so the host
-- fallback makes it behave as the standalone addon.
dofile("LibStub.lua")
dofile("VersionGate.lua")
assert(LuckysUtilsSkipLoad == false, "first copy should run")
local _, registeredMinor = LibStub("LuckysUtils-1.0")
dofile("LuckyUtils.lua")
assert(type(LuckyUtils.FormatMoney) == "function", "first copy defines the API")
local firstFormatMoney = LuckyUtils.FormatMoney

-- The standalone copy resolves media against its own folder.
assert(LuckyMedia("x.tga") == "Interface\\AddOns\\Luckys_Utils\\Media\\x.tga",
    "standalone media path should point at the Luckys_Utils folder")
assert(LuckyIcon("check") == "Interface\\AddOns\\Luckys_Utils\\Media\\icons\\check.tga",
    "a shared icon resolves by name, under Media\\icons")

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
assert(minor == registeredMinor, "minor must be unchanged by the gated copy")

-- A newer embedded copy must win: it reruns the files, replaces function
-- bodies, and re-resolves media against its own host addon's folder.
local realNewLibrary = LibStub.NewLibrary
LibStub.NewLibrary = function(self, major, _)
    return realNewLibrary(self, major, registeredMinor + 1)
end
local gate = assert(loadfile("VersionGate.lua"))
gate("SomeHost")
LibStub.NewLibrary = realNewLibrary
assert(LuckysUtilsSkipLoad == false, "newer copy should run")
dofile("LuckyUtils.lua")
assert(type(LuckyUtils.FormatMoney) == "function"
    and LuckyUtils.FormatMoney ~= "sentinel-not-replaced",
    "newer copy must replace function bodies")
assert(select(2, LibStub("LuckysUtils-1.0")) == registeredMinor + 1,
    "minor should now be the newer copy's")
assert(LuckyMedia("x.tga") == "Interface\\AddOns\\SomeHost\\Libs\\LuckysUtils\\Media\\x.tga",
    "embedded media path should point inside the host addon")
assert(LuckyIcon("check") == "Interface\\AddOns\\SomeHost\\Libs\\LuckysUtils\\Media\\icons\\check.tga",
    "shared icons follow the host addon too")

-- Every copy, winner or loser, records its host for the standalone check.
local seen = {}
for _, host in ipairs(LuckysUtilsHosts) do seen[host] = (seen[host] or 0) + 1 end
assert(seen["Luckys_Utils"] == 2, "both standalone-shaped loads should be recorded")
assert(seen["SomeHost"] == 1, "the embedded load should be recorded")

print("VersionGate tests passed")
