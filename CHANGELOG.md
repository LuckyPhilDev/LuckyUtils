## [Unreleased]

### Added
- `RichGroup:ButtonRow(opts)` puts sibling actions side by side on one row instead of stacking a full-width button each. Every button takes `label`, an optional shared-icon name in `icon`, `desc` and `onClick`, and keeps its own About entry. They are drawn borderless, matching `LuckyUI.CreateIconButton`: gold art and label with no plate, lit on hover by the icon added over itself.
- Three more shared icons in `Media\icons`: `copy`, `pencil` and `trash`.
- `NewRichPanel` derives a What's New floor when the panel names no `minVersion`: two minors back from the addon's `## Version`, so the list keeps itself current with no constant to bump. An explicit `minVersion`, or a legacy `recentVersions` list, still wins.

### Fixed
- `LuckyUI.TITLE_FONT` and `LuckyUI.BODY_FONT` follow `STANDARD_TEXT_FONT` rather than hardcoding `Fonts\FRIZQT__.TTF`, which carries no Cyrillic or CJK glyphs, so ruRU, koKR, zhCN and zhTW clients draw text instead of empty boxes. `LuckySettings` and `LuckyRichSettings` take their font from `LuckyUI.BODY_FONT` for the same reason.

## [1.13.1] - 2026-08-23

### Added
- Two more shared icons in `Media\icons`: `filter` and `layers`.

## [1.13.0] - 2026-08-23

### Added
- `LuckyIcon(name)` returns the full path to one of the shared icons now shipped in `Media\icons`, resolving against the winning copy the same way `LuckyMedia` does. The set is white line art so the drawing code picks the colour: `check`, `crosshair`, `crown`, `dice`, `plus`, `search`, `settings`, `sparkle`, `target`, `triangle-alert`, `x`.
- `LuckyUI.CreateIconButton` accepts a shared icon's bare name in `opts.icon`. Anything containing a path separator is still treated as the consumer's own texture, so existing callers are unaffected.

## [1.12.1] - 2026-08-22

### Added
- `RichGroup:Select(opts)` takes `newLine`. It defaults to false, putting the dropdown beside its label the way `MultiSelect` does; pass true for the previous two-line shape, label above the dropdown, which long option text still needs.

### Fixed
- The About rail keeps the setting you last hovered rather than resetting to the top of the group when the cursor leaves the row. Its own Enable and Reload button could not be reached before, because setting off towards it dismissed the panel holding it.

## [1.12.0] - 2026-08-20

### Added
- `LuckyStrings.New(namespace, tbl)` seals a table of user-facing strings in place, so a mistyped key returns a red `[namespace.key]` placeholder instead of nil. Nested tables are sealed too; `pairs` and `ipairs` are unaffected. The library's own copy now lives in `Strings.lua` as `LuckyUtilsStrings`.
- `RichGroup:Select(opts)` adds a single-choice dropdown row to a rich settings panel: `options` is a list of `{ key, label }`, `value` is the current key (or a function returning it, re-read every time the panel opens), and `onSelect(key)` writes the choice back. Locks and indents under `parent` like the other rows.

## [1.11.1] - 2026-08-18

### Added
- `LuckyMedia(fileName)` returns the full texture path into the winning copy's `Media` folder, resolving to the host addon's `Libs\LuckysUtils\Media` when embedded and to the standalone folder otherwise. Use it instead of writing `Interface\AddOns\Luckys_Utils\Media\...` paths out.
- `LuckyDeps:StandaloneRemovable()` reports whether the standalone addon could be uninstalled safely: an embedded copy is present and no installed addon still requires Luckys_Utils. Nothing calls it yet; it gates a future uninstall hint.

### Fixed
- The promo row icons, the Discord icon, and the dev-mode and minimap icons in rich settings panels now load when the library runs embedded without the standalone addon installed.
- Version labels in bug reports and the settings title tooltip fall back to the library registration instead of "?" when the standalone addon is absent.

## [1.11.0] - 2026-08-18

### Added
- The library is version-gated behind LibStub as `LuckysUtils-1.0` and ships `LibStub.lua`. Consumers embed their own copy via `.pkgmeta` externals and load `Libs\LuckysUtils\embeds.xml` before their own files; the newest copy loaded wins and publishes the same globals as always. Check which copy won in-game with `/dump LibStub.minors["LuckysUtils-1.0"]`.
- `LuckyUtils.FormatMoney(copper)` formats a copper amount as plain "12g 34s 56c" chat text.
- `LuckyUtils.Debounced(seconds, action)` wraps an action so a burst of calls runs it once after the delay.

### Improved
- Runtime state (item caches, roster callbacks, the minimap broker queue, the error watcher and its handler chain) now lives on the module globals, so loading several embedded copies never duplicates frames, event handlers, or error prompts.
- LuckySettings and LuckyBugs initialise off the hosting addon's own load event, so they work embedded under any addon folder name.
- `embeds.xml` now loads every module, including LuckyBugs, in the same order as the standalone addon.
