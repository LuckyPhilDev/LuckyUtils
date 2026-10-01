## [Unreleased]

### Added
- `LuckyInstance.Current()` classifies where the player is as `openworld`, `raid`, `mythicplus`, `dungeon`, `delve`, `battleground`, `arena` or `scenario`, with the instance details. Delves are recognised by difficulty, not `C_PartyInfo.IsDelveInProgress`, which also reports true in delve-like scenarios. Also `LuckyInstance.IsDelve(difficultyID)` and `LuckyInstance.KeystoneLevel()`. `VersionGate` MINOR is 26.

## [1.22.0] - 2026-09-26

### Added
- `LuckyBankRun:AddFooter(footer)` adds a line to the foot of the Bank Queue window, under a divider. `footer()` returns text, or nil for none, and is asked again on every redraw. `VersionGate` MINOR is 25.
