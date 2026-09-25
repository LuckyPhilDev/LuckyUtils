-- luacheck: ignore 111 113 121

LuckyUI = nil
LuckysUtilsSkipLoad = nil
LuckySettingsDB = nil
STANDARD_TEXT_FONT = "font"
function GetLocale() return "enUS" end

-- Frames stubbed as far as SideColumn reaches: real Show, Hide, points and
-- script hooks, everything else a no-op.
local function newFrame()
    local frame = { shown = true, scripts = {}, hooks = {} }
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true; self:Fire("OnShow") end
    function frame:Hide() self.shown = false; self:Fire("OnHide") end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetPoint(_, relativeTo) self.point = relativeTo end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:HookScript(name, fn)
        self.hooks[name] = self.hooks[name] or {}
        table.insert(self.hooks[name], fn)
    end
    function frame:Fire(name)
        if self.scripts[name] then self.scripts[name](self) end
        for _, fn in ipairs(self.hooks[name] or {}) do fn(self) end
    end
    function frame:GetHighlightTexture() return { SetBlendMode = function() end } end
    for _, noop in ipairs({ "SetSize", "SetMovable", "SetClampedToScreen", "SetHighlightTexture",
        "SetNormalTexture", "RegisterForDrag" }) do
        frame[noop] = function() end
    end
    return frame
end

function CreateFrame() return newFrame() end

dofile("LuckyUI.lua")

local passed = 0
local function check(label, actual, expected)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local auctionHouse = newFrame()

-- Two addons asking for the same key get the one column.
local column = LuckyUI.SideColumn("AuctionHouse", auctionHouse)
check("same key, same column", LuckyUI.SideColumn("AuctionHouse", auctionHouse), column)

-- Buttons stack by order, whichever addon added them first.
local restock = column:AddButton({ order = 40 })
local quickbuy = column:AddButton({ order = 10 })
local quest = column:AddButton({ order = 30 })
check("lowest order at the top", quickbuy.point, column)
check("next hangs below it", quest.point, quickbuy)
check("last hangs below that", restock.point, quest)

-- A hidden button leaves no gap.
quest:Hide()
check("gap closes when hidden", restock.point, quickbuy)
quest:Show()
check("reopens when shown", restock.point, quest)
quickbuy:Hide()
check("new top when the first hides", quest.point, column)

-- A seeded position only fills an empty slot.
LuckyUI.SeedSideColumnPosition("AuctionHouse", { x = 12, y = -30 })
check("seed fills an empty slot", LuckySettingsDB.sideColumns.AuctionHouse.x, 12)
LuckyUI.SeedSideColumnPosition("AuctionHouse", { x = 99, y = 0 })
check("seed never overwrites", LuckySettingsDB.sideColumns.AuctionHouse.x, 12)

print(string.format("%d LuckyUI SideColumn tests passed", passed))
