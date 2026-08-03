[Join the Discord](https://discord.gg/87HRHcAYP)

# Lucky's Utils

Shared library for Lucky Phil's WoW addons. Provides a consistent UI theme, reusable frame components, settings panel builder, minimap button factory, and general utilities.

---

This addon is a **dependency** — it does nothing on its own. If another addon asked you to install it, you're in the right place. No configuration is needed.

---

## What's Included

- **LuckyUI** — dark/gold colour palette and frame builders: styled panels, headers, buttons, checkboxes, dividers, search inputs, and drag-to-move with position persistence.
- **LuckySettings** — fluent builder for Interface Options panels: toggles, selectors, sliders, and section headings.
- **LuckyRichSettings** — settings panel with grouped navigation, hover descriptions, status badges, check-list dropdowns, inline notice banners, options that can be marked unavailable, and an optional About panel with screenshots, notes, and "What's New" highlights.
- **LuckyRoster** — shared, account-wide character roster (names, classes, professions) so dependent addons see one consistent list.
- **LuckyProfiles** — turn any config table into a copy-paste share string and read it back, with a checksum so corrupted strings fail cleanly. Includes ready-made export and import panels.
- **LuckyItem** — load item and spell data reliably, with a callback that only fires once the name, icon and link have actually arrived from the server. Results are cached for the session, with a batch helper for flicker-free list rendering.
- **LuckyMinimap** — draggable minimap buttons with saved position and visibility state, plus one-call registration in Blizzard's AddOn Compartment, no extra library required.
- **LuckyLog** — gated debug loggers that stay silent until an addon's debug flag is on.
- **LuckyDeps** — optional dependency checks with version validation.
- **LuckySound** — helpers for addon sound files and built-in WoW sound kit entries.
- **LuckyUtils** — general utilities: recursive SavedVariables initialisation and canonical `Name-Realm` character keys.
- **LuckyDB**: transactional, sequential SavedVariables migrations with recursive defaults and schema version checks.
- **LuckyBankQueue**: sequential container transfers with lock polling, cursor recovery, partial-stack support, and destination retries.

---

## For Addon Developers

### Installation as a dependency

Add to your `.toc`:

```
## OptionalDeps: Luckys_Utils
```

And to your `.pkgmeta` to embed it in packaged releases:

```yaml
externals:
  YourAddon/Luckys_Utils: https://github.com/LuckyPhilDev/LuckyUtils
```

The library loads before your addon code. All globals (`LuckyUI`, `LuckySettings`, `LuckyRichSettings`, `LuckyRoster`, `LuckyMinimap`, `LuckyProfiles`, `LuckyItem`, `LuckyLog`, `LuckyDeps`, `LuckySound`, `LuckyUtils`, `LuckyDB`, `LuckyBankQueue`) are available after `ADDON_LOADED` fires for your addon.

---

### LuckyUtils

```lua
-- Apply defaults to a SavedVariables table (recursive for nested tables)
LuckyUtils.ApplyDefaults(MyAddonDB, {
    devMode    = false,
    showPanel  = true,
    threshold  = { min = 1, max = 10 },
})

-- Canonical "Name-Realm" key for the current character
local key = LuckyUtils.CharacterKey()  -- e.g. "Tharindel-Silvermoon"
```

---

### LuckyDB

Migrations run in version order on a working copy. The original SavedVariables table keeps its identity and is only changed after every migration succeeds.

```lua
local database, versionOrError = LuckyDB:Initialize(MyAddonDB, {
    version = 2,
    defaults = {
        enabled = true,
        alerts = { sound = true },
    },
    migrations = {
        [1] = function(data)
            data.alerts = { sound = data.playSound ~= false }
            data.playSound = nil
        end,
        [2] = function(data)
            data.enabled = data.enabled ~= false
        end,
    },
})

if not database then
    error("Database migration failed: " .. versionOrError)
end
```

The schema version is stored in `__schemaVersion` by default. Pass `versionKey` to use a different field. A migration may raise an error or return `false, message`; either result rolls back the entire upgrade.

---

### LuckyBankQueue

Provide a destination resolver, enqueue source slots, then start the queue. Native WoW container, cursor, and timer APIs are used unless test doubles are supplied.

```lua
local queue = LuckyBankQueue:New({
    findDestination = function(itemID, excluded, step)
        return MyAddon.FindWarbandDestination(itemID, excluded, step)
    end,
    onError = function(_, step, code)
        LuckyLog("MyAddon", "Transfer failed", step.itemID, code)
    end,
})

queue:Enqueue({
    sourceBag = sourceBag,
    sourceSlot = sourceSlot,
    itemID = itemID,
    amount = amount,
})

queue:Start(function()
    MyAddon:RefreshBankState()
end)
```

`findDestination(itemID, excluded, step)` returns a bag and slot. The queue waits for locked slots, skips incompatible slots, retries when a partial merge leaves an item on the cursor, restores the cursor item to its source on failure, and reports stable error codes through `onError`. Use `GetPendingCount()`, `IsRunning()`, and `Cancel()` to inspect or stop a queue.

---

### LuckyUI

**Colour palette** — `LuckyUI.C` (RGBA 0–1 tables) and `LuckyUI.WC` (WoW colour escape strings):

```lua
-- Print with gold accent
print(LuckyUI.WC.goldPrimary .. "MyAddon" .. LuckyUI.WC.reset .. ": hello")
```

Key palette tokens: `bgDark`, `bgPanel`, `bgInput`, `goldPrimary`, `goldAccent`, `goldMuted`, `textLight`, `textMuted`, `danger`, `info`, `success`, `purple`.

**Frame helpers:**

```lua
-- Styled panel (dark bg, gold border, draggable)
local panel = LuckyUI.CreatePanel("MyPanel", UIParent, 400, 300)

-- Header bar with title and close button
LuckyUI.CreateHeader(panel, "My Addon")

-- Buttons: "primary" | "secondary" (default) | "danger"
local btn = LuckyUI.CreateButton(parent, "Save", 90, 28, "primary")

-- Checkbox (gold fill when checked)
local cb = LuckyUI.CreateCheckbox(parent, 16)

-- Horizontal divider with optional label
local div = LuckyUI.CreateDivider(parent, "Section Title")

-- Drag-to-move with SavedVariables persistence
LuckyUI.EnableDrag(myFrame, {
    db      = MyAddonDB,
    key     = "windowPos",
    default = { "TOP", "TOP", 0, -200 },
})
-- Restores saved position immediately; adds myFrame:RestorePosition()

-- Search input with placeholder and clear button
local search = LuckyUI.CreateSearchBox(parent, {
    width       = 220,
    placeholder = "Search mounts...",
    onChange    = function(query) FilterList(query) end,  -- query is trimmed
})
search:SetPoint("TOPLEFT", 12, -12)
-- Adds search:SetQuery(text) and search:Clear(); both fire onChange
```

**Virtualised scrolling list** — builds only enough row frames to fill the visible area and recycles them as you scroll, so a few hundred rows stay smooth. You own the look of a row; the list owns scrolling and pooling. Pairs naturally with the search box above.

```lua
local list = LuckyUI.CreateScrollList(panel, {
    rowHeight = 24,
    -- Build a row once; return the frame. Called per pooled slot, not per item.
    createRow = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetFont(LuckyUI.BODY_FONT, 12)
        row.text:SetPoint("LEFT", 6, 0)
        return row
    end,
    -- Fill a row from a data entry. Called whenever a slot is reused.
    updateRow = function(row, item, index) row.text:SetText(item.name) end,
    onClick   = function(item, index) print("clicked", item.name) end,  -- optional
})
list:SetPoint("TOPLEFT", 12, -48)
list:SetSize(280, 360)

list:SetData(myArray)   -- replace data and redraw from the top
list:Refresh()          -- redraw visible rows after editing the data in place
list:ScrollTo(20)       -- scroll a 1-based index to the top
```

---

### LuckySettings

```lua
local panel = LuckySettings:NewPanel("My Addon")

panel:Section("General")
panel:Toggle({
    label    = "Enable feature",
    desc     = "Turns the feature on or off.",
    checked  = MyAddonDB.featureEnabled,
    onToggle = function(v) MyAddonDB.featureEnabled = v end,
})
panel:Selector({
    label   = "Mode",
    value   = MyAddonDB.mode,
    choices = { { value="auto", label="Auto" }, { value="manual", label="Manual" } },
    onChange = function(v) MyAddonDB.mode = v end,
})
panel:Slider({
    label     = "Threshold",
    key       = "threshold",
    min       = 1, max = 100, value = MyAddonDB.threshold,
    suffix    = "%",
    onChanged = function(v) MyAddonDB.threshold = v end,
})

-- Open programmatically
panel:Open()
-- or: LuckySettings:Open(panel.category)
```

---

### LuckyMinimap

```lua
LuckyMinimap:Create({
    name    = "MyAddonMinimapButton",
    icon    = "Interface\\Icons\\INV_Misc_Bag_36",
    dbKey   = "minimap",   -- key in db for { minimapPos, hide }
    db      = MyAddonDB,
    onClick = function(_, mouseBtn)
        if mouseBtn == "LeftButton" then MyAddon:Toggle() end
    end,
    tooltip = function(tt)
        tt:AddLine(LuckyUI.WC.goldPrimary .. "My Addon" .. LuckyUI.WC.reset)
        tt:AddLine("Left-click: Toggle", 0.91, 0.86, 0.78)
        tt:AddLine("Drag: Move button", 0.54, 0.49, 0.42)
    end,
})
```

**AddOn Compartment** — register the addon in Blizzard's native button list at the top of the minimap, as an alternative or companion to the minimap button. The same `onClick` and `tooltip` functions drive both, so a user running several Lucky addons can collapse the cluster of minimap buttons into one menu.

```lua
LuckyMinimap:RegisterCompartment({
    name    = "My Addon",
    icon    = "Interface\\Icons\\INV_Misc_Bag_36",
    onClick = function(_, mouseBtn)
        if mouseBtn == "LeftButton" then MyAddon:Toggle() end
    end,
    tooltip = function(tt)
        tt:AddLine(LuckyUI.WC.goldPrimary .. "My Addon" .. LuckyUI.WC.reset)
        tt:AddLine("Click: Toggle", 0.91, 0.86, 0.78)
    end,
})
-- Returns false on older clients with no compartment; safe to ignore.
```

---

### LuckyProfiles

Export and import any config table as a single share string, so users can copy a setup between characters or send it to a friend. The string carries a checksum, so a truncated or mistyped paste is rejected with a clear message instead of loading garbage. Nothing in the string is executable, so importing is safe.

```lua
-- Low-level encode / decode
local str = LuckyProfiles:Encode(MyAddonDB.profiles.current)

local data, err = LuckyProfiles:Decode(str)
if data then
    -- apply data
else
    print(err)  -- e.g. "The share string is corrupted or incomplete."
end

-- Ready-made panels (built on LuckyUI)
LuckyProfiles:ShowExport("Export Profile", MyAddonDB.profiles.current)

LuckyProfiles:ShowImport("Import Profile", function(decoded)
    MyAddonDB.profiles.current = decoded
    MyAddon:Refresh()
end)
```

Export only the portable subset of your DB — functions and frame references are skipped automatically, but leaving them out keeps the string small.

---

### LuckyItem

Item and spell data is not always ready the instant you ask for it. The name, icon, quality and link arrive from the server a moment later, so a row drawn immediately shows blanks that fill in on the next frame. LuckyItem hands you a callback that fires only once the data is present, and caches the result for the rest of the session.

```lua
-- Resolve one item; the callback fires immediately on a cache hit
LuckyItem:Get(19019, function(info)
    if info then
        print(info.icon, info.name, info.link, info.quality)
    end
end)

-- Load a whole list, then render once with no per-row flicker
LuckyItem:GetMany({ 19019, 17182, 18803 }, function(results)
    for id, info in pairs(results) do
        AddRow(info)  -- info is nil for any id that failed to load
    end
end)

-- Synchronous render path: read what's already cached, never trigger a load
local info = LuckyItem:GetCached(19019)
if LuckyItem:IsCached(19019) then ... end

-- Spells work the same way
LuckyItem:GetSpell(2061, function(info)
    if info then print(info.name, info.icon, info.castTime) end
end)
```

Item info fields: `id`, `name`, `link`, `quality`, `icon`, `itemLevel`, `minLevel`, `type`, `subType`, `equipLoc`, `classID`, `subclassID`, `sellPrice`, `isReagent`. Spell info fields: `id`, `name`, `icon`, `castTime`.

---

### LuckyLog

```lua
local DevLog = LuckyLog:New("|cffc9a84cMyAddon|r:", function()
    return MyAddonDB and MyAddonDB.devMode
end)

-- Prints only when devMode is true
DevLog("Player entered zone:", GetZoneText())
```

---

### LuckyDeps

```lua
-- Check if an optional dependency is installed and enabled
if LuckyDeps:IsEnabled("WeakAuras") then ... end

-- Check if loaded and optionally at minimum version
local ok, err = LuckyDeps:Check("Details", "9.0.0")
if not ok then print(err) end
```

---

### LuckySound

```lua
-- Play an addon sound file
LuckySound:Play(LuckySound:Path("MyAddon", "sounds\\alert.ogg"))

-- Play a built-in WoW sound
LuckySound:PlayKit(SOUNDKIT.IG_QUEST_LOG_OPEN)

-- Stop a playing sound
local _, handle = LuckySound:Play(path)
LuckySound:Stop(handle)
```

---

## A note on AI

My addons are made by one person who plays the game and wants them to work properly. I use AI tools to move faster, mostly on code, bug hunting, and docs, but every change is reviewed and tested in game before release. If a feature feels off or something breaks, that's mine to fix, and the Discord is the fastest way to reach me.

## Author

Lucky Phil
