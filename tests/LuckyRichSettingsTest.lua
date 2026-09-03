-- luacheck: globals CreateFrame LuckySettings LuckyUI C_AddOns

-- Covers where LuckyRichSettings puts rows: the What's New list folds into the
-- first group as a scrolling region, and that region has to end above the
-- group's bottom rows (version info, promo) rather than run over them. The
-- panel is WoW frames all the way down, so the frame API is stubbed just far
-- enough for the builders to run and record their anchors.

local function noop() end

local stubMeta = { __index = function(_, key)
    -- A plain Frame has no SetEnabled in game, and MultiSelect branches on that
    -- to tell the modern dropdown from the legacy one. Kinds that really have
    -- it declare it below.
    if key == "SetEnabled" then return nil end
    return noop
end }

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
        kind     = kind,
        parent   = parent,
        children = {},
        textures = {},
        points  = {},
        scripts = {},
        height  = 0,
        width   = 400,
        SetPoint = function(self, point, rel, relPoint, x, y)
            self.points[point] = { rel = rel, relPoint = relPoint, x = x, y = y }
        end,
        ClearAllPoints   = function(self) self.points = {} end,
        SetParent        = function(self, p) self.parent = p end,
        SetHeight        = function(self, h) self.height = h end,
        GetHeight        = function(self) return self.height end,
        SetWidth         = function(self, w) self.width = w end,
        GetWidth         = function(self) return self.width end,
        SetSize          = function(self, w, h) self.width, self.height = w, h end,
        CreateTexture    = function(self)
            local tex = stub({
                points   = {},
                SetPoint = function(t, point, rel) t.points[point] = { rel = rel } end,
                SetVertexColor = function(t, r, g, b) t.color = { r, g, b } end,
            })
            if self.textures then table.insert(self.textures, tex) end
            return tex
        end,
        CreateFontString = function() return newText() end,
        HookScript       = function(self, event, fn) self.scripts[event] = fn end,
        SetScript        = function(self, event, fn) self.scripts[event] = fn end,
    })
    if kind == "Button" then
        frame.fontString   = newText()
        frame.GetFontString = function(self) return self.fontString end
    end
    if kind == "Button" or kind == "CheckButton" or kind == "DropdownButton" then
        frame.SetEnabled = function(self, on) self.enabled = on end
    end

    if kind == "CheckButton" then
        frame.checked    = false
        frame.SetChecked = function(self, on) self.checked = on and true or false end
        frame.GetChecked = function(self) return self.checked end
    end

    if kind == "Slider" then
        frame.value    = 0
        frame.Low      = newText()
        frame.High     = newText()
        frame.SetValue = function(self, v)
            self.value = v
            local fn = self.scripts.OnValueChanged
            if fn then fn(self, v) end
        end
        frame.GetValue   = function(self) return self.value end
        frame.SetEnabled = function(self, on) self.enabled = on end
    end
    if kind == "ScrollFrame" then
        frame.ScrollBar = stub({ SetShown = function(self, shown) self.shown = shown end })
    elseif kind == "DropdownButton" then
        frame.SetupMenu       = function(self, fn) self.menu = fn end
        frame.SetDefaultText  = function(self, text) self.text = text end
    end
    return frame
end

function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_EnableDropDown(dd) dd.enabled = true end
function UIDropDownMenu_DisableDropDown(dd) dd.enabled = false end

CreateFrame = function(kind, _, parent)
    local frame = newFrame(kind, parent)
    if parent and parent.children then table.insert(parent.children, frame) end
    return frame
end

LuckyUI = stub({
    Backdrop = {},
    BODY_FONT = "Fonts/locale-specific.ttf",
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

-- The panel draws in whatever face LuckyUI resolved for the client locale. A
-- hardcoded roman font here is what left Cyrillic clients reading empty boxes.
assert(LuckySettings.Rich.Font == LuckyUI.BODY_FONT, "rich settings take the shared locale font")

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
-- Measured from the child against the region, not from the scroll range: a
-- region that fits from the moment it is built has a range of zero that never
-- changes, which left the bar showing over content that did not need it.
local scroll = scrollChild.parent
scroll:SetHeight(200)
scroll.scripts.OnScrollRangeChanged(scroll)
assert(scroll.ScrollBar.shown == false, "a list that fits shows no scrollbar")
assert(scroll.points.BOTTOMRIGHT.rel == 0, "and the rows take back the scrollbar's width")

scroll:SetHeight(20)
scroll.scripts.OnScrollRangeChanged(scroll)
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
-- ButtonRow puts its buttons side by side, each only as wide as it reads.
-------------------------------------------------------------------------------
local clicked
local actions = panel:Group("Actions")
actions:ButtonRow({ buttons = {
    { label = "New",    icon = "plus",  desc = "Start an empty one" },
    { label = "Delete", icon = "trash", onClick = function() clicked = "Delete" end },
    { label = "Cancel" },
} })

local new, delete = findSetting(actions, "New"), findSetting(actions, "Delete")
local cancel = findSetting(actions, "Cancel")
assert(new.row == delete.row and new.row == cancel.row, "the buttons share one row")

-- The stub measures every label at 40, so an icon button is 40 + 14 + 6 wide.
assert(new.button.width == 60, "an icon button fits its label and its icon")
assert(cancel.button.width == 40, "a button without an icon is only its label wide")

-- SetPoint("LEFT", x, y) anchors to the parent, so the stub records the offset as `rel`.
assert(new.button.points.LEFT.rel == 14, "the first button starts at the row indent")
assert(delete.button.points.LEFT.rel == 14 + 60 + 20, "the next clears the first plus the gap")
assert(cancel.button.points.LEFT.rel == 14 + 60 + 20 + 60 + 20, "and so does the one after it")

delete.button.scripts.OnClick()
assert(clicked == "Delete", "each button runs its own onClick")

-- The What's New floor a panel gets when it names none: two minors back from
-- the .toc version, so a release cannot ship still trumpeting old features.
local whatsNewFloor = ns.Rich.whatsNewFloor

LuckyPromo = stub()

local function setVersion(version)
    C_AddOns.GetAddOnMetadata = function(_, key)
        return key == "Version" and version or nil
    end
end

local function floorFor(version)
    setVersion(version)
    return whatsNewFloor("Any_Addon")
end

assert(floorFor("1.24.0") == "1.22.0", "two minors back")
assert(floorFor("1.23.1") == "1.21.0", "the patch number does not matter")
assert(floorFor("1.24") == "1.22.0", "a two part version still reads")
assert(floorFor("2.0.0") == "2.0.0", "a fresh major highlights only itself")
assert(floorFor("2.1.0") == "2.0.0", "one minor in reaches back to the major")
assert(floorFor("") == "0.0.0", "an unreadable version shows everything")
assert(floorFor("nightly") == "0.0.0", "a non-numeric version shows everything")
assert(whatsNewFloor(nil) == nil, "no addon folder means no derived floor")

setVersion("1.5.0")
local derived = LuckySettings:NewRichPanel("Derived Addon", { addonFolder = "Any_Addon" })
assert(derived.minVersion == "1.3.0", "a panel with no minVersion derives one")

local legacy = LuckySettings:NewRichPanel("Legacy Addon",
    { addonFolder = "Any_Addon", recentVersions = { "1.5.0" } })
assert(legacy.minVersion == nil, "a recentVersions panel keeps its legacy list")

-------------------------------------------------------------------------------
-- The promo row hangs off whatsNewGroup, so it is published even when no floor
-- can be worked out at all and there is no list to build.
-------------------------------------------------------------------------------
local floorless = LuckySettings:NewRichPanel("Floorless Addon", {})
local only = floorless:Group("Only")
floorless:Finalize()
assert(floorless.minVersion == nil, "no addon folder leaves the panel without a floor")
assert(floorless.whatsNewGroup == only, "the first group is published with no What's New list")

-------------------------------------------------------------------------------
-- A Slider parent locks its children at zero, the way a cleared Toggle does.
-------------------------------------------------------------------------------
local gated = LuckySettings:NewRichPanel("Gated Addon", {})
local gatedRows = gated:Group("Gated")
gatedRows:Slider({ label = "Hold",   min = 0, max = 120, value = 0 })
gatedRows:Slider({ label = "Forget", min = 0, max = 30, value = 5, parent = "Hold" })
gated:Finalize()

local hold   = findSetting(gatedRows, "Hold").slider
local forget = findSetting(gatedRows, "Forget").slider
assert(forget.enabled == false, "a child under a slider parked at zero starts locked")

hold:SetValue(30)
assert(forget.enabled == true, "dragging the parent off zero unlocks the child")

hold:SetValue(0)
assert(forget.enabled == false, "back to zero locks the child again")

-------------------------------------------------------------------------------
-- A warning gives the row a red icon in its leading space, and the control
-- shifts right to clear it.
-------------------------------------------------------------------------------
local risky = LuckySettings:NewRichPanel("Risky Addon", {})
local riskyRows = risky:Group("Risky")
riskyRows:Toggle({ label = "Safe",   checked = false })
riskyRows:Toggle({ label = "Sharp",  checked = false, warning = "This one bites." })
riskyRows:Toggle({ label = "Nested", checked = false, parent = "Sharp", warning = "So does this." })
risky:Finalize()

local safe   = findSetting(riskyRows, "Safe")
local sharp  = findSetting(riskyRows, "Sharp")
local nested = findSetting(riskyRows, "Nested")

assert(safe.checkbox.points.LEFT.rel == 14, "a row with no warning keeps the plain indent")
assert(sharp.checkbox.points.LEFT.rel == 14 + 14 + 6, "a warning shifts the control clear of the icon")
assert(nested.checkbox.points.LEFT.rel == 30 + 14 + 6, "a child row shifts from its own deeper indent")

-- The icon is built before the checkbox, and is the only other frame on the row.
local warnIcon
for _, child in ipairs(sharp.row.children) do
    if child ~= sharp.checkbox then warnIcon = child break end
end
assert(warnIcon, "a warning row carries an icon frame")
assert(warnIcon.points.LEFT.rel == 14, "the icon takes the space the control gave up")

-- Hovering the icon must still drive the About rail, or it goes blank behind
-- the tooltip the icon puts up.
local hovered
risky.UpdateAbout = function(_, setting) hovered = setting end
warnIcon.scripts.OnEnter()
assert(hovered == sharp, "hovering the icon still updates the About rail")

-------------------------------------------------------------------------------
-- A group too long for the panel folds its rows into a scrolling region rather
-- than running off the bottom.
-------------------------------------------------------------------------------
local tall = LuckySettings:NewRichPanel("Tall Addon", {})
local tallRows = tall:Group("Tall")
for i = 1, 6 do tallRows:Toggle({ label = "Row " .. i, checked = false }) end
tallRows:BottomLabel({ label = "Version", value = "1.0" })
tall:Finalize()

local firstRow = findSetting(tallRows, "Row 1").row
local lastRow  = findSetting(tallRows, "Row 6").row
local headingBefore = firstRow.points.TOPLEFT.rel

assert(tallRows:AutoScroll(), "a group with rows and no fill region of its own scrolls")
local inner = firstRow.parent
assert(inner, "the rows moved into the scroll child")
assert(lastRow.parent == inner, "every row moved, not just the first")
assert(firstRow.points.TOPLEFT.rel == inner, "the first row re-anchors inside the region")
assert(headingBefore ~= inner, "and was anchored outside it before")

-- Anchored to the heading and stretched down to the bottom row, so the rows
-- take the space between them rather than overlapping either.
assert(tallRows.fillHolder.points.TOPLEFT.rel == tallRows.heading, "the region starts below the heading")
assert(tallRows.fillHolder.points.BOTTOM.rel == tallRows.bottomSettings[1].row,
    "and stops above the bottom rows")

assert(tallRows:AutoScroll() == false, "scrolling an already scrolling group does nothing")

-- A group that built its own list region keeps it; a second would nest.
local listed = LuckySettings:NewRichPanel("Listed Addon", {})
local listedRows = listed:Group("Listed")
listedRows:Toggle({ label = "Above the list", checked = false })
listedRows:Fill()
listed:Finalize()
assert(listedRows:AutoScroll() == false, "a group that called Fill is left alone")

-------------------------------------------------------------------------------
-- Clearing a parent locks its grandchildren too, not just the row below it.
-------------------------------------------------------------------------------
local nested = LuckySettings:NewRichPanel("Nested Addon", {})
local nestedRows = nested:Group("Nested")
nestedRows:Toggle({ label = "Feature", checked = true })
nestedRows:Toggle({ label = "Keep in keys", checked = true, parent = "Feature" })
nestedRows:Slider({ label = "Minimum key", min = 2, max = 10, value = 10, parent = "Keep in keys" })
nestedRows:MultiSelect({
    label     = "Difficulties",
    parent    = "Keep in keys",
    options   = { { key = "heroic", label = "Heroic" } },
    isChecked = function() return true end,
})
nested:Finalize()

local feature  = findSetting(nestedRows, "Feature").checkbox
local minKey   = findSetting(nestedRows, "Minimum key").slider
local diffs    = findSetting(nestedRows, "Difficulties").dropdown

assert(minKey.enabled ~= false, "a grandchild under two ticked parents starts unlocked")

feature:SetChecked(false)
feature.scripts.OnClick(feature)
assert(minKey.enabled == false, "clearing the grandparent locks the slider under it")
assert(diffs.enabled == false, "and the dropdown beside it")

feature:SetChecked(true)
feature.scripts.OnClick(feature)
assert(minKey.enabled == true, "ticking it back unlocks them again")
assert(diffs.enabled == true, "both of them")

-------------------------------------------------------------------------------
-- A warning whose level depends on the row's value repaints when it changes, so
-- the row can read amber on the safe choice and red on the one that sticks.
-------------------------------------------------------------------------------
local R = LuckySettings.Rich.Theme
local mode = "safe"
local graded = LuckySettings:NewRichPanel("Graded Addon", {})
local gradedRows = graded:Group("Graded")
gradedRows:Select({
    label        = "What happens",
    warning      = "The risky one cannot be undone.",
    warningLevel = function() return mode == "safe" and "caution" or "danger" end,
    options      = { { key = "safe", label = "Safe" }, { key = "risky", label = "Risky" } },
    value        = function() return mode end,
    onSelect     = function(key) mode = key end,
})
gradedRows:Toggle({ label = "Plain warning", checked = false, warning = "Always loud." })
graded:Finalize()

local function warnColour(label)
    local row = findSetting(gradedRows, label).row
    for _, child in ipairs(row.children) do
        if child.textures and child.textures[1] and child.textures[1].color then
            return child.textures[1].color
        end
    end
end

local function sameColour(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

assert(sameColour(warnColour("What happens"), R.caution), "the safe choice paints the icon amber")
assert(sameColour(warnColour("Plain warning"), R.warn),
    "a warning with no level stays red, the louder of the two")

mode = "risky"
findSetting(gradedRows, "What happens").refreshSelect()
assert(sameColour(warnColour("What happens"), R.warn), "picking the risky choice turns it red")

mode = "safe"
findSetting(gradedRows, "What happens").refreshSelect()
assert(sameColour(warnColour("What happens"), R.caution), "and going back turns it amber again")

-------------------------------------------------------------------------------
-- Rows bound to a store: a strings table fills the text, `key` reads and
-- writes db[key], and a handler the row named runs after the write.
-------------------------------------------------------------------------------
local store = { repair = true, timer = 5, pick = "b", lfr = false, normal = true }
local charStore = { dismiss = true }
local S = {
    repair = { label = "Auto Repair", desc = "Repairs.", note = "A note." },
    guild  = { label = "Guild Funds", desc = "Pays." },
    timer  = { label = "Timer", desc = "Seconds.", suffix = "s" },
    pick   = { label = "Pick", desc = "One of." },
    raids  = { label = "Raids", desc = "Which." },
    dismiss = { label = "Dismiss", desc = "Per character." },
}
local applied = {}
local bound = LuckySettings:NewRichPanel("Bound", { db = store })
local rows = bound:Group("Rows")
rows:Toggle{ S.repair, key = "repair", onToggle = function(v) applied[#applied + 1] = v end }
rows:Toggle{ S.guild, key = "guild", parent = S.repair }
rows:Slider{ S.timer, key = "timer", min = 1, max = 10 }
rows:Select{ S.pick, key = "pick", options = { { key = "a", label = "A" }, { key = "b", label = "B" } } }
rows:MultiSelect{ S.raids, keys = { lfr = "lfr", normal = "normal" },
    options = { { key = "lfr", label = "LFR" }, { key = "normal", label = "Normal" } } }
local perChar = bound:Group("Per character", { db = charStore })
perChar:Toggle{ S.dismiss, key = "dismiss" }
bound:Finalize()

local repair = findSetting(rows, "Auto Repair")
assert(repair, "the strings table supplied the label")
assert(repair.desc == "Repairs." and repair.note == "A note.", "and the desc and note")
assert(repair.checkbox.checked == true, "checked is read from the store")
assert(findSetting(rows, "Guild Funds").parentSetting == repair, "a strings table names a parent")
assert(findSetting(rows, "Timer").suffix == "s", "a slider takes its suffix from the strings table")

repair.checkbox.checked = false
repair.checkbox.scripts.OnClick(repair.checkbox)
assert(store.repair == false, "toggling writes the store")
assert(applied[1] == false, "and then runs the row's own handler")

store.repair = true
bound.canvas.scripts.OnShow()
assert(repair.checkbox.checked == true, "reopening re-reads the store")

findSetting(rows, "Timer").slider:SetValue(8)
assert(store.timer == 8, "a slider writes the store")

local pick = findSetting(rows, "Pick")
assert(pick.dropdown.text == "B", "a select reads the store")
openMenu(pick.dropdown)[1].func()
assert(store.pick == "a", "and writes it")

assert(findSetting(perChar, "Dismiss").checkbox.checked == true, "a group's own store wins over the panel's")
local ownStore = { solo = true }
rows:Toggle{ label = "Solo", key = "solo", db = ownStore }
assert(findSetting(rows, "Solo").checkbox.checked == true, "a row's own store wins over the group's")

local ok, err = pcall(function() rows:Toggle{ key = "typo" } end)
assert(not ok and err:find("typo"), "a row with no label fails naming its key")
ok = pcall(function() rows:Toggle{ nil, key = "repair" } end)
assert(not ok, "a nil strings table (a typo in S) fails at build")

-- Without a store, `key` is only the slider's frame-name suffix, as before.
local unbound = LuckySettings:NewRichPanel("Unbound", {})
local free = unbound:Group("Free")
free:Slider{ label = "Delay", key = "Delay", min = 0, max = 5, value = 2 }
assert(findSetting(free, "Delay").slider.value == 2, "an unbound slider keeps its plain value")

print("LuckyRichSettings tests passed")
