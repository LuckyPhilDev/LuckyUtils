-- LuckyUtils: General-purpose utility functions for Lucky Phil's addons.

LuckyUtils = LuckyUtils or {}

-- ---------------------------------------------------------------------------
-- Database Helpers
-- ---------------------------------------------------------------------------

--- Apply default values to a table, recursively for nested tables.
-- Keys already present in target are left unchanged.
--
-- Usage:
--   LuckyGrabbagDB = LuckyGrabbagDB or {}
--   LuckyUtils.ApplyDefaults(LuckyGrabbagDB, {
--       devMode     = false,
--       showButtons = true,
--       threshold   = { min = 1, max = 10 },
--   })
--
-- @param target    table  The table to fill in (e.g. your SavedVariables)
-- @param defaults  table  Default values to apply
function LuckyUtils.ApplyDefaults(target, defaults)
    for key, default in pairs(defaults) do
        if target[key] == nil then
            if type(default) == "table" then
                target[key] = {}
                LuckyUtils.ApplyDefaults(target[key], default)
            else
                target[key] = default
            end
        elseif type(target[key]) == "table" and type(default) == "table" then
            LuckyUtils.ApplyDefaults(target[key], default)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Character Helpers
-- ---------------------------------------------------------------------------

--- Return the canonical "Name-Realm" key for the current character.
-- Uses UnitFullName for cross-realm accuracy, falling back to
-- UnitName + GetRealmName when needed.
--
-- @return string  e.g. "Tharindel-Silvermoon"
function LuckyUtils.CharacterKey()
    local name, realm = UnitFullName("player")
    name  = name  or UnitName("player") or "Unknown"
    realm = realm or GetRealmName()     or "Unknown"
    return name .. "-" .. realm
end
