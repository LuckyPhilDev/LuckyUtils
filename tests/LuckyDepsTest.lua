-- luacheck: globals LuckyDeps C_AddOns

-- Covers how LuckyDeps reads the three dependency states a settings row cares
-- about, because "switched off" is the only one the player can put right from
-- the panel and it has to be told apart from "not installed".
--
-- Run from the addon root: lua tests/LuckyDepsTest.lua

LuckyDeps = nil

local installed = {}
local enabledCalls = {}

C_AddOns = {
    IsAddOnLoaded = function(name)
        local addon = installed[name]
        return addon ~= nil and addon.loaded == true
    end,
    GetAddOnInfo = function(name)
        local addon = installed[name]
        if not addon then return nil, nil, nil, false, "MISSING" end
        return name, name, nil, addon.loaded == true, addon.reason
    end,
    GetAddOnMetadata = function(name, field)
        local addon = installed[name]
        return addon and field == "Version" and addon.version or nil
    end,
    GetAddOnDependencies = function(name)
        -- Returns varargs like the real one. Two is as many as any check needs.
        local addon = installed[name]
        local dependencies = addon and addon.dependencies or {}
        return dependencies[1], dependencies[2]
    end,
    EnableAddOn = function(name) table.insert(enabledCalls, name) end,
}

dofile("LuckyStrings.lua")
dofile("Strings.lua")
dofile("LuckyDeps.lua")

local S = LuckyDeps.Status

-- ─── Loaded and current ──────────────────────────────────────────────────────

installed.Baganator = { loaded = true, version = "1.4.0" }

local ok, msg, status = LuckyDeps:Check("Baganator")
assert(ok, "a loaded addon should pass")
assert(msg == nil, "a passing check should carry no message")
assert(status == S.OK, "a loaded addon should report ok, reported " .. tostring(status))

-- ─── Installed but switched off ──────────────────────────────────────────────

installed.Baganator = { loaded = false, reason = "DISABLED" }

ok, msg, status = LuckyDeps:Check("Baganator")
assert(not ok, "a switched-off addon should fail")
assert(status == S.DISABLED, "a switched-off addon should report disabled, reported " .. tostring(status))
assert(msg:find("switched off"), "a switched-off addon should say so, said: " .. tostring(msg))

-- A dependency of its own being off leaves it just as fixable from here.
installed.Baganator = { loaded = false, reason = "DEP_DISABLED" }
_, _, status = LuckyDeps:Check("Baganator")
assert(status == S.DISABLED, "a disabled dependency should report disabled, reported " .. tostring(status))

-- ─── Not installed at all ────────────────────────────────────────────────────

installed.Baganator = nil

ok, msg, status = LuckyDeps:Check("Baganator")
assert(not ok, "a missing addon should fail")
assert(status == S.MISSING, "a missing addon should report missing, reported " .. tostring(status))
assert(msg:find("required"), "a missing addon should say it is required, said: " .. tostring(msg))
assert(not msg:find("switched off"), "a missing addon must not offer the switch-on wording")

-- ─── Loaded but too old ──────────────────────────────────────────────────────

installed.Baganator = { loaded = true, version = "1.4.0" }

ok, msg, status = LuckyDeps:Check("Baganator", "2.0.0")
assert(not ok, "a version below the minimum should fail")
assert(status == S.OUTDATED, "an old version should report outdated, reported " .. tostring(status))
assert(msg:find("2.0.0"), "an old version should name the minimum, said: " .. tostring(msg))

ok = LuckyDeps:Check("Baganator", "1.4.0")
assert(ok, "a version exactly at the minimum should pass")

-- ─── Switching one on ────────────────────────────────────────────────────────

-- Baganator is no use without Syndicator, so enabling it alone would still
-- leave the feature unavailable after the reload.
installed.Baganator = { loaded = false, reason = "DISABLED", dependencies = { "Syndicator" } }
installed.Syndicator = { loaded = false, reason = "DISABLED" }

enabledCalls = {}
LuckyDeps:Enable("Baganator")
assert(enabledCalls[1] == "Baganator", "the addon itself should be enabled first")
assert(enabledCalls[2] == "Syndicator", "its dependencies should be enabled too")
assert(#enabledCalls == 2, "nothing else should be enabled, enabled " .. #enabledCalls)

print("LuckyDeps: all checks passed")
