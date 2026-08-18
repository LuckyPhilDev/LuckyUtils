-- LuckyDB: Versioned, transactional SavedVariables migrations.

if LuckysUtilsSkipLoad then return end

LuckyDB = LuckyDB or {}

local DEFAULT_VERSION_KEY = "__schemaVersion"

local function deepCopy(value, copies)
    if type(value) ~= "table" then
        return value
    end

    copies = copies or {}
    if copies[value] then
        return copies[value]
    end

    local result = {}
    copies[value] = result
    for key, child in pairs(value) do
        result[deepCopy(key, copies)] = deepCopy(child, copies)
    end

    return result
end

local function replaceContents(target, source)
    for key in pairs(target) do
        target[key] = nil
    end

    local copy = deepCopy(source)
    for key, value in pairs(copy) do
        target[key] = value
    end
end

--- Initialize a SavedVariables table and migrate it to a target schema version.
-- Migrations run on a working copy. The original table is updated only after
-- every migration and the default merge succeeds.
--
-- @param database table The SavedVariables table to initialize
-- @param options table version, migrations, defaults, and optional versionKey
-- @return table|nil database on success
-- @return number|string target version on success, error code on failure
function LuckyDB:Initialize(database, options)
    if type(database) ~= "table" then
        return nil, "invalid_database"
    end
    if type(options) ~= "table" or type(options.version) ~= "number" then
        return nil, "invalid_options"
    end

    local targetVersion = options.version
    if targetVersion < 0 or targetVersion % 1 ~= 0 then
        return nil, "invalid_version:" .. tostring(targetVersion)
    end

    local versionKey = options.versionKey or DEFAULT_VERSION_KEY
    local currentVersion = database[versionKey] or 0
    if type(currentVersion) ~= "number" or currentVersion < 0 or currentVersion % 1 ~= 0 then
        return nil, "invalid_database_version:" .. tostring(currentVersion)
    end
    if currentVersion > targetVersion then
        return nil, "database_newer_than_code:" .. tostring(currentVersion)
    end

    local working = deepCopy(database)
    local migrations = options.migrations or {}

    for version = currentVersion + 1, targetVersion do
        local migration = migrations[version]
        if type(migration) ~= "function" then
            return nil, "missing_migration:" .. tostring(version)
        end

        local succeeded, migrationResult, migrationMessage = pcall(migration, working, version)
        if not succeeded then
            return nil, "migration_" .. tostring(version) .. "_failed:" .. tostring(migrationResult)
        end
        if migrationResult == false then
            return nil, "migration_" .. tostring(version) .. "_failed:" .. tostring(migrationMessage or "migration returned false")
        end

        working[versionKey] = version
    end

    LuckyUtils.ApplyDefaults(working, options.defaults or {})
    working[versionKey] = targetVersion
    replaceContents(database, working)

    return database, targetVersion
end
