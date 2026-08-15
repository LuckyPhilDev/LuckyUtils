-- luacheck: globals CreateFrame LuckySettings LuckyUI

-- Covers where LuckyRichSettings puts rows: the What's New list folds into the
-- first group as a scrolling region, and that region has to end above the
-- group's bottom rows (version info, promo) rather than run over them. The
-- panel is WoW frames all the way down, so the frame API is stubbed just far
-- enough for the builders to run and record their anchors.

local function noop() end

local stubMeta = { __index = function() return noop end }

local function stub(fields)
    return setmetatable(fields or {}, stubMeta)
end

local function newText()
    return stub({
        GetStringWidth  = function() return 40 end,
        GetStringHeight = function() return 12 end,
    })
end

local function newFrame(kind, parent)
    local frame = stub({
        kind    = kind,
        parent  = parent,
        points  = {},
        scripts = {},
        height  = 0,
        width   = 400,
        SetPoint = function(self, point, rel, relPoint, x, y)
            self.points[point] = { rel = rel, relPoint = relPoint, x = x, y = y }
        end,
        ClearAllPoints   = function(self) self.points = {} end,
        SetHeight        = function(self, h) self.height = h end,
        GetHeight        = function(self) return self.height end,
        SetWidth         = function(self, w) self.width = w end,
        GetWidth         = function(self) return self.width end,
        SetSize          = function(self, w, h) self.width, self.height = w, h end,
        CreateTexture    = function() return stub() end,
        CreateFontString = function() return newText() end,
        HookScript       = function(self, event, fn) self.scripts[event] = fn end,
    })
    if kind == "ScrollFrame" then
        frame.ScrollBar = stub({ SetShown = function(self, shown) self.shown = shown end })
    end
    return frame
end

CreateFrame = function(kind, _, parent) return newFrame(kind, parent) end

LuckyUI = stub({ Backdrop = {} })
LuckySettings = stub({ Register = function() return "category" end })

local ns = {}
loadfile("LuckyRichSettings/Core.lua")("Luckys_Utils", ns)
loadfile("LuckyRichSettings/About.lua")("Luckys_Utils", ns)
loadfile("LuckyRichSettings/Rows.lua")("Luckys_Utils", ns)
loadfile("LuckyRichSettings/Panel.lua")("Luckys_Utils", ns)

local panel = LuckySettings:NewRichPanel("Test Addon", { minVersion = "1.2.0" })

local general = panel:Group("General")
general:Toggle({ label = "Dev Mode", checked = false })

local vendors = panel:Group("Vendors")
vendors:Toggle({ label = "Flag Decor", checked = false, since = "1.3.0" })
vendors:Toggle({ label = "Old Thing",  checked = false, since = "1.0.0" })

panel:Finalize()

local function findSetting(group, label)
    for _, s in ipairs(group.settings) do
        if s.label == label then return s end
    end
end

-------------------------------------------------------------------------------
-- What's New lands in the first group, not a group of its own.
-------------------------------------------------------------------------------
assert(#panel.groups == 2, "no extra nav group was added for What's New")
assert(panel.whatsNewGroup == general, "the first group hosts the What's New list")

local card = findSetting(general, "Flag Decor")
assert(card and card.isCard, "the flagged setting got a card in the host group")
assert(not findSetting(general, "Old Thing"), "a setting below minVersion stays off the list")

-------------------------------------------------------------------------------
-- Cards scroll: they are parented to the scroll child, which is sized to them.
-------------------------------------------------------------------------------
local scrollChild = card.row.parent
assert(scrollChild ~= general.content, "cards live in the scroll child, not the group content")
assert(scrollChild.height == 28 + 32, "the scroll child measures its section and card")
assert(findSetting(general, "Dev Mode").row.parent == general.content,
    "rows added before the list still flow down the group content")
assert(general.rowParent == nil, "the scroll region closed, so later rows flow normally again")

-------------------------------------------------------------------------------
-- The scrollbar shows only when the cards outgrow the region.
-------------------------------------------------------------------------------
local scroll = scrollChild.parent
scroll.scripts.OnScrollRangeChanged(scroll, 0, 0)
assert(scroll.ScrollBar.shown == false, "a list that fits shows no scrollbar")
assert(scroll.points.BOTTOMRIGHT.rel == 0, "and the rows take back the scrollbar's width")

scroll.scripts.OnScrollRangeChanged(scroll, 0, 120)
assert(scroll.ScrollBar.shown == true, "a list that overflows shows the scrollbar")
assert(scroll.points.BOTTOMRIGHT.rel == -22, "and the rows make room for it")

-------------------------------------------------------------------------------
-- Bottom rows push the scrolling region up instead of being overlapped by it.
-------------------------------------------------------------------------------
assert(general.fillHolder.points.BOTTOM.rel == general.content,
    "with no bottom rows the list runs to the bottom of the group")

general:BottomSection("Version info")
general:BottomLabel({ label = "Test Addon", value = "v1.3.0" })

assert(general.fillHolder.points.BOTTOM.rel == general.bottomSettings[1].row,
    "the list ends above the first bottom row")

print("LuckyRichSettings tests passed")
