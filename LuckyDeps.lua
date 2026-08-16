-- LuckyDeps: Generic addon dependency checker for Lucky Phil's addons.
-- Checks whether optional dependencies are installed, loaded, and meet version requirements.

LuckyDeps = LuckyDeps or {}

local function parseVersion(str)
    local parts = {}
    for n in str:gmatch("%d+") do
        parts[#parts + 1] = tonumber(n)
    end
    return parts
end

local function isAtLeast(actual, minimum)
    local a = parseVersion(actual)
    local m = parseVersion(minimum)
    for i = 1, math.max(#a, #m) do
        local av = a[i] or 0
        local mv = m[i] or 0
        if av ~= mv then return av > mv end
    end
    return true
end

--- Returns true if an addon is installed and enabled, regardless of whether it has loaded yet.
---@param addonName string
---@return boolean
function LuckyDeps:IsEnabled(addonName)
    local _, _, _, loadable = C_AddOns.GetAddOnInfo(addonName)
    return loadable == true
end

LuckyDeps.Status = {
    OK       = "ok",
    MISSING  = "missing",   -- not installed, or installed but unusable
    DISABLED = "disabled",  -- installed and switched off, so the player can fix it
    OUTDATED = "outdated",
}

--- Checks whether an addon is loaded and meets an optional minimum version.
---@param addonName string
---@param minVersion string|nil
---@return boolean ok
---@return string|nil message
---@return string status one of LuckyDeps.Status
function LuckyDeps:Check(addonName, minVersion)
    local versionSuffix = minVersion and (" version " .. minVersion) or ""
    local failMessage = addonName .. versionSuffix .. " is required for this feature."

    if C_AddOns.IsAddOnLoaded(addonName) then
        if minVersion then
            local actual = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
            if not isAtLeast(actual, minVersion) then
                return false, failMessage, self.Status.OUTDATED
            end
        end
        return true, nil, self.Status.OK
    end

    -- Switched off is worth saying out loud, because it is the one failure the
    -- player can undo from here.
    local _, _, _, _, reason = C_AddOns.GetAddOnInfo(addonName)
    if reason == "DISABLED" or reason == "DEP_DISABLED" then
        return false, addonName .. " is installed but switched off for this character.",
            self.Status.DISABLED
    end

    return false, failMessage, self.Status.MISSING
end

--- Switches an addon on for this character, along with anything it declares a
--- dependency on. Takes effect on the next UI reload.
--- Only direct dependencies are followed, which covers every addon this suite
--- checks for; a dependency that is itself off and has its own would need more.
---@param addonName string
function LuckyDeps:Enable(addonName)
    C_AddOns.EnableAddOn(addonName)
    for _, dependency in ipairs({ C_AddOns.GetAddOnDependencies(addonName) }) do
        C_AddOns.EnableAddOn(dependency)
    end
end
