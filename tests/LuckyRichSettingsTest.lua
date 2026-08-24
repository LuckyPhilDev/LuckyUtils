-- luacheck: globals CreateFrame LuckySettings LuckyUI C_AddOns

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
        CreateTexture    = function()
            return stub({
                points   = {},
                SetPoint = function(self, point, rel) self.points[point] = { rel = rel } end,
            })
        end,
        CreateFontString = function() return newText() end,
        HookScript       = function(self, event, fn) self.scripts[event] = fn end,
        SetScript        = function(self, event, fn) self.scripts[event] = fn end,
    })
    if kind == "Button" then
        frame.fontString   = newText()
        frame.GetFontString = function(self) return self.fontString end
    end
    if kind == "ScrollFrame" then
        frame.ScrollBar = stub({ SetShown = function(self, shown) self.shown = shown end })
    elseif kind == "DropdownButton" then
        frame.SetupMenu       = function(self, fn) self.menu = fn end
        frame.SetDefaultText  = function(self, text) self.text = text end
    end
    return frame
end

CreateFrame = function(kind, _, parent) return newFrame(kind, parent) end

LuckyUI = stub({
    Backdrop = {},
    C = { goldIcon = { 1, 1, 1 } },
    CreateIconButton = function(parent) return newFrame("Button", parent) end,
    CreateButton = function(parent) return newFrame("Button", parent) end,
})
LuckySettings = stub({ Register = function() return "category" end })
C_AddOns = stub({ GetAddOnMetadata = function() return "1.0.0" end })

-- Running a Select's menu generator against a stub root, so the test can read
-- back the entries it would have created and pick one.
local function openMenu(dd)
    local entries = {}
    dd.menu(dd, stub({
        CreateRadio = function(_, text, isSelected, setSelected)
            entries[#entries + 1] = { text = text, checked = isSelected(), func = setSelected }
        end,
    }))
    return entries
end

local ns = {}
dofile("LibStub.lua")
loadfile("VersionGate.lua")("Luckys_Utils")
dofile("LuckyStrings.lua")
dofile("Strings.lua")
loadfile("LuckyRichSettings/Core.lua")("Luckys_Utils", ns)
loadfile("LuckyRichSettings/About.lua")("Luckys_Utils", ns)
loadfile("LuckyRichSettings/Rows.lua")("Luckys_Utils", ns)
loadfile("LuckyRichSettings/Panel.lua")("Luckys_Utils", ns)

local devMode = false
local panel = LuckySettings:NewRichPanel("Test Addon", {
    minVersion = "1.2.0",
    devMode    = {
        checked  = function() return devMode end,
        onToggle = function(v) devMode = v end,
    },
})

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

-------------------------------------------------------------------------------
-- A host group already named for the list is not given the heading twice.
-------------------------------------------------------------------------------
local named = LuckySettings:NewRichPanel("Named Addon", { minVersion = "1.2.0" })
local host = named:Group("What's New")
named:Group("Vendors"):Toggle({ label = "Flag Decor", checked = false, since = "1.3.0" })
named:Finalize()

for _, s in ipairs(host.settings) do
    assert(s.name ~= "What's New", "the host group does not repeat its own name as a section")
end

-------------------------------------------------------------------------------
-- Select shows the option matching its value, and writes the key back.
-------------------------------------------------------------------------------
local minimapClick = "both"
local clicks = panel:Group("Clicks")
clicks:Select({
    label    = "Left-click opens",
    options  = {
        { key = "both",     label = "Wishlist and loot browser" },
        { key = "wishlist", label = "Wishlist only" },
    },
    value    = function() return minimapClick end,
    onSelect = function(key) minimapClick = key end,
})

local select = findSetting(clicks, "Left-click opens")
assert(select.dropdown.text == "Wishlist and loot browser", "the row reads the current value's label")

local buttons = openMenu(select.dropdown)
assert(#buttons == 2, "every option gets a menu button")
assert(buttons[1].checked == true and buttons[2].checked == false, "only the current option is checked")

buttons[2].func()
assert(minimapClick == "wishlist", "picking an option writes its key back")
assert(select.dropdown.text == "Wishlist only", "and the row follows the new value")

minimapClick = "both"
select.refreshSelect()
assert(select.dropdown.text == "Wishlist and loot browser", "a value changed elsewhere is re-read on open")

-------------------------------------------------------------------------------
-- ButtonRow puts its buttons side by side, every one at the widest label's width.
-------------------------------------------------------------------------------
local clicked
local actions = panel:Group("Actions")
actions:ButtonRow({ buttons = {
    { label = "New",    icon = "plus",  desc = "Start an empty one" },
    { label = "Delete", icon = "trash", onClick = function() clicked = "Delete" end },
    { label = "Cancel" },
} })

local new, delete = findSetting(actions, "New"), findSetting(actions, "Delete")
assert(new.row == delete.row, "the buttons share one row")
assert(new.button.width == delete.button.width, "and are sized to the widest label")
-- SetPoint("LEFT", x, y) anchors to the parent, so the stub records the offset as `rel`.
assert(delete.button.points.LEFT.rel == 14 + new.button.width + 6,
    "the second button clears the first plus the gap")
assert(new.row.points.TOPLEFT, "the row itself still flows down the group")

delete.button.scripts.OnClick()
assert(clicked == "Delete", "each button runs its own onClick")

-- The stub measures every label at 40, so an icon button is 40 + 46 wide and the
-- icon-plus-label block inside it is 14 + 5 + 40.
assert(new.button.width == 86, "an icon button fits its label plus the icon and padding")
assert(new.icon.points.LEFT.rel == (86 - 59) / 2,
    "the icon and its label centre in the button as one block")

local cancel = findSetting(actions, "Cancel")
assert(cancel.icon == nil, "a button can go without an icon")
assert(cancel.button.width == 86, "and still shares the row's width")

print("LuckyRichSettings tests passed")
