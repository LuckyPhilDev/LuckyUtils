-- luacheck: globals CreateFrame Minimap LibStub LuckyMinimap C_AddOns

-- Covers the LibDataBroker launcher LuckyMinimap publishes for display addons
-- (Titan Panel and the like). The button itself is WoW frames all the way down,
-- so the frame API is stubbed just far enough for Create to run.

local function noop() end

local function stub(fields)
    return setmetatable(fields or {}, { __index = function() return noop end })
end

local frames

local function newFrame()
    local frame = stub({
        events  = {},
        scripts = {},
        SetScript      = function(self, event, fn) self.scripts[event] = fn end,
        RegisterEvent  = function(self, event) self.events[event] = true end,
        CreateTexture  = function() return stub() end,
        GetHighlightTexture = function() return stub() end,
    })
    frames[#frames + 1] = frame
    return frame
end

CreateFrame = function(_, name)
    local frame = newFrame()
    if name then _G[name] = frame end
    return frame
end

Minimap = stub({
    GetWidth           = function() return 140 end,
    GetHeight          = function() return 140 end,
    GetCenter          = function() return 0, 0 end,
    GetEffectiveScale  = function() return 1 end,
})

-- Only the one folder is installed, so an unknown tocname reads as absent.
C_AddOns = {
    GetAddOnMetadata = function(folder, field)
        if folder == "Luckys_Test" and field == "Title" then return "Lucky's Test" end
        return nil
    end,
}

local function fireLogin()
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_LOGIN and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, "PLAYER_LOGIN")
        end
    end
end

local function buildOptions(name)
    return {
        name    = name,
        tocname = "Luckys_Test",
        icon    = "Interface\\Icons\\INV_Misc_Bag_36",
        dbKey   = "minimap",
        db      = {},
        onClick = function() end,
        tooltip = function() end,
    }
end

--- Load a fresh copy of the module against the current LibStub.
local function reload()
    frames = {}
    LuckyMinimap = nil
    dofile("LuckyMinimap.lua")
end

-------------------------------------------------------------------------------
-- With no display addon there is no LibStub, and the button still has to build.
-------------------------------------------------------------------------------
LibStub = nil
reload()
LuckyMinimap:Create(buildOptions("LuckysTestMinimapButton"))
fireLogin()
assert(true, "a missing LibDataBroker did not stop the button being created")

-------------------------------------------------------------------------------
-- With a display addon present, a launcher is published at login.
-------------------------------------------------------------------------------
local registered = {}
local ldb = stub({
    NewDataObject = function(_, name, object) registered[name] = object end,
})
LibStub = stub({
    GetLibrary = function(_, name)
        if name == "LibDataBroker-1.1" then return ldb end
        return nil
    end,
})

reload()
local options = buildOptions("LuckysTestMinimapButton")
local clickedWith
options.onClick = function(_, mouseButton) clickedWith = mouseButton end
LuckyMinimap:Create(options)

assert(next(registered) == nil, "held the launcher back until login")

fireLogin()

local launcher = registered["LuckysTestMinimapButton"]
assert(launcher, "registered under the frame name, the id a display addon saves")
assert(launcher.type == "launcher", "declared the LDB launcher type")
assert(launcher.label == "Lucky's Test", "labelled with the title read out of the addon's TOC")
assert(launcher.tocname == "Luckys_Test", "named the addon folder so its version can be read")
assert(launcher.icon == options.icon, "carried the button icon across")
assert(launcher.OnTooltipShow == options.tooltip, "reused the button tooltip")

launcher.OnClick(nil, "RightButton")
assert(clickedWith == "RightButton", "a click on the display addon reaches the button handler")

-------------------------------------------------------------------------------
-- A button built after login has missed the sweep, so it publishes immediately.
-------------------------------------------------------------------------------
registered = {}
LuckyMinimap:Create(buildOptions("LuckysLateMinimapButton"))
assert(registered["LuckysLateMinimapButton"], "published a button created after login")

-------------------------------------------------------------------------------
-- Naming, when the addon says nothing and when it overrides the TOC.
-------------------------------------------------------------------------------
registered = {}
local unnamed = buildOptions("LuckysUnnamedMinimapButton")
unnamed.tocname = nil
LuckyMinimap:Create(unnamed)
assert(registered["LuckysUnnamedMinimapButton"].label == "LuckysUnnamedMinimapButton",
    "fell back to the frame name with no folder to read a title from")

local overridden = buildOptions("LuckysOverriddenMinimapButton")
overridden.text = "A Better Name"
LuckyMinimap:Create(overridden)
assert(registered["LuckysOverriddenMinimapButton"].label == "A Better Name",
    "an explicit label beat the TOC title")

print("LuckyMinimap tests passed")
