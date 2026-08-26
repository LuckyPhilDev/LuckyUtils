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

-- ─── An embedded copy takes an equal version from the standalone ─────────────
-- Serroc's case: a standalone that loaded first and half-installed decided what
-- every consumer ran. At the same version the embedded copy now takes over, so
-- the copy that ships with the addon needing it is the one that runs.

LibStub = nil
LuckysUtilsSkipLoad = nil
LuckysUtilsHosts = nil
LuckysUtilsWinner = nil
LuckyUtils = nil

dofile("LibStub.lua")
dofile("VersionGate.lua")            -- standalone, via the host fallback
assert(LuckysUtilsSkipLoad == false, "the standalone loads first and wins")
assert(LuckysUtilsWinner == "Luckys_Utils", "the standalone should hold the registration")
local tiedMinor = select(2, LibStub("LuckysUtils-1.0"))

gate("EmbeddedHost")                 -- same version, embedded
assert(LuckysUtilsSkipLoad == false, "an embedded copy must take an equal version")
assert(LuckysUtilsWinner == "EmbeddedHost", "the embedded copy should now hold it")
assert(select(2, LibStub("LuckysUtils-1.0")) == tiedMinor,
    "taking over must leave the registered version where it was")
assert(LuckyMedia("x.tga") == "Interface" .. string.char(92) .. "AddOns" .. string.char(92)
    .. "EmbeddedHost" .. string.char(92) .. "Libs" .. string.char(92) .. "LuckysUtils"
    .. string.char(92) .. "Media" .. string.char(92) .. "x.tga",
    "the embedded copy's own media paths should be in force")

-- A second standalone still loses to it, so the swap is not a free-for-all.
gate()
assert(LuckysUtilsSkipLoad == true, "a standalone must not take an equal version back")
assert(LuckysUtilsWinner == "EmbeddedHost", "the embedded copy keeps the registration")

-- Two embedded copies at one version keep the first-wins rule.
gate("OtherHost")
assert(LuckysUtilsSkipLoad == true, "embedded copies do not leapfrog each other")

print("VersionGate tests passed")
