-- Luckys_Utils version gate. Every copy of this library, the standalone addon
-- and each consumer's embedded Libs\LuckysUtils, loads this file first.
-- LibStub decides whether this copy is the newest seen so far; when it is not,
-- every following file returns immediately and the winning copy's definitions
-- stand. The modules publish the same globals they always have (LuckyUI,
-- LuckyLog, ...) and mutate them in place, so the LibStub entry only
-- arbitrates versions; consumers keep calling the globals.
--
-- Bump MINOR on every release that changes any file in this library.
-- A breaking API change goes in a new "LuckysUtils-2.0" major instead.

local MAJOR, MINOR = "LuckysUtils-1.0", 14

-- Folder this copy loads from: the host addon when embedded, Luckys_Utils when
-- standalone. Nil under a plain-Lua test harness, hence the fallback.
local host = ... or "Luckys_Utils"

-- The standalone addon is being retired, so at an equal version an embedded
-- copy takes the registration rather than deferring to whichever loaded first.
-- An embedded copy ships inside the addon that needs it; a standalone left over
-- from an older install should not get to decide what every consumer runs. A
-- genuinely newer copy still wins on version alone, whichever kind it is.
local held = LibStub.minors[MAJOR]
if held == MINOR and host ~= "Luckys_Utils" and LuckysUtilsWinner == "Luckys_Utils" then
    LibStub.minors[MAJOR] = MINOR - 1
end

local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
-- Taking over from an equal version is not an upgrade, so migrations must read
-- the version actually held rather than the one stepped back to force the swap.
if lib then oldminor = held end

-- Every copy that loads, winner or loser, leaves its host's folder name here,
-- so the library can tell whether an embedded copy is present alongside the
-- standalone addon (see LuckyDeps:StandaloneRemovable).
LuckysUtilsHosts = LuckysUtilsHosts or {}
LuckysUtilsHosts[#LuckysUtilsHosts + 1] = host

-- Read by the top of every other file in this library: true when an equal or
-- newer copy already loaded and this copy's files must not run.
LuckysUtilsSkipLoad = (lib == nil)
if not lib then return end

-- Which host's copy holds the registration, so a later embedded copy can tell
-- whether the copy it is meeting is the standalone.
LuckysUtilsWinner = host

lib.oldminor = oldminor

-- Full path to a file in the winning copy's Media folder. The standalone addon
-- keeps Media at its root; an embedded copy carries it under Libs\LuckysUtils
-- inside whichever addon hosts it, so the path must be built from the host
-- name rather than written out.
local mediaRoot = (host == "Luckys_Utils")
    and "Interface\\AddOns\\Luckys_Utils\\Media\\"
    or ("Interface\\AddOns\\" .. host .. "\\Libs\\LuckysUtils\\Media\\")

function LuckyMedia(fileName)
    return mediaRoot .. fileName
end

-- Full path to one of the shared icons in Media\icons, named without its
-- extension. The art is white, so whatever draws it picks the colour;
-- LuckyUI.CreateIconButton tints it gold unless told otherwise.
function LuckyIcon(name)
    return mediaRoot .. "icons\\" .. name .. ".tga"
end

-- Upgrade migrations, run before the newer copy's module files load.
-- if oldminor and oldminor < 2 then
--     -- migrate state created by minor 1 here
-- end

-- Self-healing against pre-gate copies -----------------------------------------
-- Copies of this library from before the version gate open every file with
-- `LuckyUI = {}` rather than `LuckyUI = LuckyUI or {}`. They consult nothing,
-- so when one loads after the winning copy it replaces the published tables
-- outright and every function added since simply disappears; consumers then
-- call a nil on a table that still looks fine. Nothing can stop that
-- assignment, so instead the winner remembers what it published as its own
-- host finishes loading, and puts it back as each later addon comes in.
--
-- ponytail: restores between addon loads, not during one. A consumer that
-- calls into the library from its own file scope, after a pre-gate copy has
-- loaded in the same addon, is still on its own. Hook into the loader if that
-- ever shows up in a report.
local PUBLISHED = {
    "LuckyBankQueue", "LuckyBugs", "LuckyDB", "LuckyDeps", "LuckyIcon",
    "LuckyItem", "LuckyLog", "LuckyMedia", "LuckyMinimap", "LuckyProfiles",
    "LuckyPromo", "LuckyRoster", "LuckySettings", "LuckySound", "LuckyStrings",
    "LuckyUI", "LuckyUtils", "LuckyUtilsStrings",
}

lib.published = lib.published or {}

local function rememberPublished()
    for _, name in ipairs(PUBLISHED) do
        if _G[name] ~= nil then lib.published[name] = _G[name] end
    end
end

local function restorePublished()
    for name, value in pairs(lib.published) do
        if _G[name] ~= value then _G[name] = value end
    end
end

lib.RestorePublished = restorePublished

-- One frame for the library, kept across a takeover so a newer copy inherits it
-- rather than leaving a second listener behind.
local healer = lib.healer or CreateFrame("Frame")
lib.healer = healer
healer:UnregisterAllEvents()
healer:RegisterEvent("ADDON_LOADED")
healer:RegisterEvent("PLAYER_LOGIN")
healer:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == host then
        rememberPublished()
    else
        restorePublished()
    end
end)
