## [Unreleased]

### Added
- A one-time panel at login tells the player they can uninstall the standalone `Luckys_Utils` addon. It appears only where `LuckyDeps:StandaloneRemovable()` holds, meaning an embedded copy is loaded and no installed addon lists the standalone as a required dependency. Dismissal persists in `LuckySettingsDB.standaloneNoticeSeen`.

### Improved
- `LuckyUI.CreateHeader` draws its close button with the shared `x` icon rather than a red plate with a text `x`, matching the borderless row actions.

### Fixed
- At an equal `MINOR` an embedded copy now takes the registration from the standalone rather than skipping, so a half-installed standalone that happened to load first can no longer leave consumers calling functions it never published. A higher `MINOR` still wins outright either way, and two embedded copies at one version keep the first-wins rule.

## [1.14.0] - 2026-08-25

### Added
- `RichGroup:ButtonRow(opts)` puts sibling actions side by side on one row instead of stacking a full-width button each. Every button takes `label`, an optional shared-icon name in `icon`, `desc` and `onClick`, and keeps its own About entry. They are drawn borderless, matching `LuckyUI.CreateIconButton`: gold art and label with no plate, lit on hover by the icon added over itself.
- Three more shared icons in `Media\icons`: `copy`, `pencil` and `trash`.
- `NewRichPanel` derives a What's New floor when the panel names no `minVersion`: two minors back from the addon's `## Version`, so the list keeps itself current with no constant to bump. An explicit `minVersion`, or a legacy `recentVersions` list, still wins.
- `LuckyUI.DOT` is the separator glyph to join label parts with, a middle dot everywhere except ruRU, whose font has no glyph for one and takes a hyphen instead. Callers add their own spacing around it.
- `RichGroup:Frame(height)` adds an empty row of the given height in the normal top-down flow, for callers that draw their own contents. Returns the frame rather than the group, unlike the other row builders.

### Fixed
- `RichBuilder:Finalize` publishes `whatsNewGroup` before any early return, so a panel that ends up with no What's New floor still hands callers a group. `LuckyPromo:AddToRichGroup(panel.whatsNewGroup, ...)` errored on a nil group otherwise.
- The floating screenshot preview in `LuckyRichSettings` hides when the cursor leaves the row that opened it, instead of lingering until a row with no screenshot is hovered.
- `LuckyUI.TITLE_FONT` and `LuckyUI.BODY_FONT` follow `STANDARD_TEXT_FONT` rather than hardcoding `Fonts\FRIZQT__.TTF`, which carries no Cyrillic or CJK glyphs, so ruRU, koKR, zhCN and zhTW clients draw text instead of empty boxes. `LuckySettings` and `LuckyRichSettings` take their font from `LuckyUI.BODY_FONT` for the same reason.
