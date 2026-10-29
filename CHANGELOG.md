## [1.23.6] - 2026-10-29

### Changed
- Settings panel values, dropdowns, notices, version tags and section rules sit 8px from the right edge instead of 14px. `VersionGate` MINOR is 33.

## [1.23.5] - 2026-10-15

### Added
- Settings rows take `requiresReload = true`. Changing the row offers a reload once its handler has run. `VersionGate` MINOR is 32.

## [1.23.4] - 2026-10-14

### Fixed
- `LuckyItem` no longer errors when loading items on patch 12.x with the game's deprecation fallbacks turned off. `VersionGate` MINOR is 31.

## [1.23.3] - 2026-10-13

### Changed
- Loads on patch 12.1.5 (interface 120105). `VersionGate` MINOR is 30.

## [1.23.2] - 2026-10-07

### Added
- The promo row now includes Lucky's Actionbars and Lucky's Loadouts, and `LuckyPromo:GetIcon` returns their artwork. `VersionGate` MINOR is 29.

## [1.23.1] - 2026-10-05

### Added
- Loads on WoW Forever (interface 16001).

### Fixed
- Leaving a rich settings panel for another page no longer freezes the game. Blizzard unanchors the page as it hides it, and resolving a long group's rows against nothing could stall for over a minute; the page is now re-anchored as it hides. (Thanks for the report Tuulani)
- Opening a settings panel during combat, for example from a minimap click, now waits until combat ends instead of being blocked by the game.
- Rich settings `MultiSelect` re-reads its summary each time the panel opens, so options changed elsewhere no longer show stale text. `VersionGate` MINOR is 28.

## [1.23.0] - 2026-10-02

### Added
- `LuckyInstance.Current()` classifies where the player is as `openworld`, `raid`, `mythicplus`, `dungeon`, `delve`, `battleground`, `arena` or `scenario`, with the instance details. Delves are recognised by difficulty, not `C_PartyInfo.IsDelveInProgress`, which also reports true in delve-like scenarios. Also `LuckyInstance.IsDelve(difficultyID)` and `LuckyInstance.KeystoneLevel()`. `VersionGate` MINOR is 26.
- `LuckyReminders`: a shared Reminders window that opens at login and on entering a rest area. `Register(id, { title, order, rows })` adds a section, `Refresh()` redraws it when rows change, and `AddSettings(group, since)` adds the account-wide timer, dimming and Keep Reminders Open While Resting settings to a rich settings group. A timer of 0 keeps the window up until it is closed, and the window can dim to a chosen opacity after a chosen wait until hovered. `LuckyUI.EnableAutoHide` frames gain `SetAutoHideAlpha(alpha)`, the alpha the frame waits at and its closing fade scales down from. `VersionGate` MINOR is 27.
