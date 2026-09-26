## [1.21.0] - 2026-09-26

### Added
- `LuckyUI.SideColumn(key, anchorFrame)` returns the one column of buttons down the right of a window that every Lucky addon shares under that key, so their buttons stack instead of overlapping. `column:AddButton(opts)` adds a button stacked by `opts.order`; hidden buttons leave no gap, and right-dragging any button moves the whole column, its position saved in `LuckySettingsDB`. `LuckyUI.SeedSideColumnPosition(key, pos)` carries over a position an addon saved itself. `VersionGate` MINOR is 24.
- `LuckyUI.CreateActionButton(parent, opts)` builds a 42px square button with the standard square highlight, for full-colour `Interface\Icons` art.
