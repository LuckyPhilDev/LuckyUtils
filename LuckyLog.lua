-- LuckyLog: Shared dev-logging factory for Lucky Phil's addons.
-- Creates gated loggers that only print when an addon's debug flag is on.

LuckyLog = {}

--- Create a new logger function.
---@param prefix string  Colored prefix string (e.g. "|cff00cc00Lucky:|r")
---@param isEnabledFn function  Returns true when logging is active
---@return function  logger(first, ...)  — silently returns when disabled
function LuckyLog:New(prefix, isEnabledFn)
    return function(first, ...)
        if not isEnabledFn() then return end
        if select("#", ...) == 0 then
            print(prefix .. " " .. tostring(first))
        else
            print(prefix .. " " .. tostring(first), ...)
        end
    end
end
