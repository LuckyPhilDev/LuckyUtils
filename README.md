[Join the Discord](https://discord.gg/87HRHcAYP)

# Lucky's Utils

Shared library for Lucky Phil's WoW addons. Provides a consistent UI theme, reusable frame components, settings panel builder, minimap button factory, and general utilities.

---

This addon is a **dependency** — it does nothing on its own. If another addon asked you to install it, you're in the right place. No configuration is needed.

---

## What's Included

- **LuckyUI** — dark/gold colour palette and frame builders: styled panels, headers, buttons, checkboxes, dividers, search inputs, and drag-to-move with position persistence.
- **LuckySettings** — fluent builder for Interface Options panels: toggles, selectors, sliders, and section headings.
- **LuckyRichSettings** — three-column settings panel with grouped navigation, hover descriptions, status badges, check-list dropdowns, and an About panel with screenshots, notes, and "What's New" highlights.
- **LuckyRoster** — shared, account-wide character roster (names, classes, professions) so dependent addons see one consistent list.
- **LuckyMinimap** — draggable minimap buttons with saved position and visibility state, no extra library required.
- **LuckyLog** — gated debug loggers that stay silent until an addon's debug flag is on.
- **LuckyDeps** — optional dependency checks with version validation.
- **LuckySound** — helpers for addon sound files and built-in WoW sound kit entries.
- **LuckyUtils** — general utilities: recursive SavedVariables initialisation and canonical `Name-Realm` character keys.

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

The library loads before your addon code. All globals (`LuckyUI`, `LuckySettings`, `LuckyRichSettings`, `LuckyRoster`, `LuckyMinimap`, `LuckyLog`, `LuckyDeps`, `LuckySound`, `LuckyUtils`) are available after `ADDON_LOADED` fires for your addon.

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

## Author

Lucky Phil
