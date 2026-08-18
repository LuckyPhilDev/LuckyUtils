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

local MAJOR, MINOR = "LuckysUtils-1.0", 1

local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

-- Read by the top of every other file in this library: true when an equal or
-- newer copy already loaded and this copy's files must not run.
LuckysUtilsSkipLoad = (lib == nil)
if not lib then return end

lib.oldminor = oldminor

-- Upgrade migrations, run before the newer copy's module files load.
-- if oldminor and oldminor < 2 then
--     -- migrate state created by minor 1 here
-- end
