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

local MAJOR, MINOR = "LuckysUtils-1.0", 3

-- Folder this copy loads from: the host addon when embedded, Luckys_Utils when
-- standalone. Nil under a plain-Lua test harness, hence the fallback.
local host = ... or "Luckys_Utils"

local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

-- Every copy that loads, winner or loser, leaves its host's folder name here,
-- so the library can tell whether an embedded copy is present alongside the
-- standalone addon (see LuckyDeps:StandaloneRemovable).
LuckysUtilsHosts = LuckysUtilsHosts or {}
LuckysUtilsHosts[#LuckysUtilsHosts + 1] = host

-- Read by the top of every other file in this library: true when an equal or
-- newer copy already loaded and this copy's files must not run.
LuckysUtilsSkipLoad = (lib == nil)
if not lib then return end

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

-- Upgrade migrations, run before the newer copy's module files load.
-- if oldminor and oldminor < 2 then
--     -- migrate state created by minor 1 here
-- end
