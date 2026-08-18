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
-- Formatting Helpers
-- ---------------------------------------------------------------------------

--- Format a copper amount as plain "12g 34s 56c" chat text, omitting leading
-- zero denominations. Use GetMoneyString instead when coin icons are wanted.
--
-- @param copper number  Amount in copper
-- @return string
function LuckyUtils.FormatMoney(copper)
    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, cop)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

-- ---------------------------------------------------------------------------
-- Timing Helpers
-- ---------------------------------------------------------------------------

--- Wrap an action so a burst of calls runs it once, `seconds` later. Pass 0 to
-- coalesce a burst into a single run on the next frame.
--
-- @param seconds number    Delay before the action runs
-- @param action  function  The work to run once per burst
-- @return function  Call this as often as you like
function LuckyUtils.Debounced(seconds, action)
    local queued = false
    return function()
        if queued then return end

        queued = true
        C_Timer.After(seconds, function()
            queued = false
            action()
        end)
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
