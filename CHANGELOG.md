## [Unreleased]

### Added
- `LuckyInstance.Current()` classifies where the player is as `openworld`, `raid`, `mythicplus`, `dungeon`, `delve`, `battleground`, `arena` or `scenario`, with the instance details. Delves are recognised by difficulty, not `C_PartyInfo.IsDelveInProgress`, which also reports true in delve-like scenarios. Also `LuckyInstance.IsDelve(difficultyID)` and `LuckyInstance.KeystoneLevel()`. `VersionGate` MINOR is 26.
- `LuckyReminders`: a shared Reminders window that opens at login and on entering a rest area. `Register(id, { title, order, rows })` adds a section, `Refresh()` redraws it when rows change, and `AddSettings(group, since)` adds the account-wide timer, dimming and Keep Reminders Open While Resting settings to a rich settings group. A timer of 0 keeps the window up until it is closed, and the window can dim to a chosen opacity after a chosen wait until hovered. `LuckyUI.EnableAutoHide` frames gain `SetAutoHideAlpha(alpha)`, the alpha the frame waits at and its closing fade scales down from. `VersionGate` MINOR is 27.

## [1.22.0] - 2026-09-26

### Added
- `LuckyBankRun:AddFooter(footer)` adds a line to the foot of the Bank Queue window, under a divider. `footer()` returns text, or nil for none, and is asked again on every redraw. `VersionGate` MINOR is 25.
