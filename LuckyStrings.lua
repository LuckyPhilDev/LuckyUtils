-- LuckyStrings: user-facing string tables that fail visibly instead of silently.
--
-- A plain table returns nil for a mistyped key, which reaches SetText as a blank
-- label or a hard error several frames from the cause. Sealing the table swaps
-- that for a red placeholder naming the exact key, so a typo shows up in the
-- first screenshot rather than in a bug report.
--
--   MyAddon.Strings = LuckyStrings.New("MyAddon.Strings", {
--       minimap = { drag = "Drag: Move button" },
--   })
--
--   local S = MyAddon.Strings.minimap
--   S.drag   --> "Drag: Move button"
--   S.dragg  --> "|cffff0000[MyAddon.Strings.minimap.dragg]|r"

if LuckysUtilsSkipLoad then return end

LuckyStrings = LuckyStrings or {}

local function seal(tbl, path)
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            seal(value, path .. "." .. tostring(key))
        end
    end
    return setmetatable(tbl, {
        __index = function(_, key)
            return "|cffff0000[" .. path .. "." .. tostring(key) .. "]|r"
        end,
    })
end

--- Seal a table of user-facing strings against missing keys, in place.
--- Nested tables are sealed too. Iteration with pairs/ipairs is unaffected.
---@param namespace string  Prefix for the placeholder, e.g. "MyAddon.Strings"
---@param tbl table
---@return table  The same table, sealed
function LuckyStrings.New(namespace, tbl)
    return seal(tbl, namespace)
end
