LuckyUtils = nil
LuckyDB = nil

dofile("LuckyUtils.lua")
dofile("LuckyDB.lua")

local passed = 0

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local database = {
    oldName = "Lucky",
    nested = { keep = true },
}
local originalIdentity = database
local initialized, version = LuckyDB:Initialize(database, {
    version = 2,
    defaults = {
        enabled = true,
        nested = { keep = false, added = 42 },
    },
    migrations = {
        [1] = function(data)
            data.name = data.oldName
            data.oldName = nil
        end,
        [2] = function(data)
            data.name = data.name .. " Phil"
        end,
    },
})

assertEqual(initialized, originalIdentity, "database identity")
assertEqual(version, 2, "returned version")
assertEqual(database.__schemaVersion, 2, "stored version")
assertEqual(database.name, "Lucky Phil", "sequential migrations")
assertEqual(database.oldName, nil, "removed legacy field")
assertEqual(database.enabled, true, "top-level default")
assertEqual(database.nested.keep, true, "existing nested value")
assertEqual(database.nested.added, 42, "nested default")
passed = passed + 1

local failed = {
    value = "original",
    nested = { count = 1 },
}
local result, migrationError = LuckyDB:Initialize(failed, {
    version = 2,
    migrations = {
        [1] = function(data)
            data.value = "changed"
            data.nested.count = 2
        end,
        [2] = function()
            error("deliberate failure")
        end,
    },
})

assertEqual(result, nil, "failed result")
assert(migrationError:match("^migration_2_failed:"), "failed migration should identify its version")
assertEqual(failed.value, "original", "failed migration top-level rollback")
assertEqual(failed.nested.count, 1, "failed migration nested rollback")
assertEqual(failed.__schemaVersion, nil, "failed migration version rollback")
passed = passed + 1

local missingResult, missingError = LuckyDB:Initialize({}, {
    version = 1,
    migrations = {},
})
assertEqual(missingResult, nil, "missing migration result")
assertEqual(missingError, "missing_migration:1", "missing migration error")
passed = passed + 1

local future = { __schemaVersion = 3, value = "newer" }
local futureResult, futureError = LuckyDB:Initialize(future, {
    version = 2,
    migrations = {},
})
assertEqual(futureResult, nil, "future database result")
assertEqual(futureError, "database_newer_than_code:3", "future database error")
assertEqual(future.value, "newer", "future database unchanged")
passed = passed + 1

print(string.format("%d LuckyDB tests passed", passed))
