## [1.20.0] - 2026-09-21

### Added
- A rich settings row's `disabled` may be a function instead of a boolean. It is re-read whenever the panel refreshes, so a row can lock on another row's value, and choosing a `Select` option now refreshes every row in the panel the way opening it does. `VersionGate` MINOR is 22.
- `LuckyUI.CreateWindow(name, w, h, title, opts)` builds the standard Lucky window: gold-bordered panel, `CreateHeader` title bar, dragged by the header with its position saved to `opts.db[opts.key]`, and closed on Escape. `LuckyUI.HEADER_HEIGHT` gives the header's height for laying out content below it, and `CreateHeader` now sets `frame.closeButton`.
- `LuckyUI.CreateInput(parent, opts)` builds a plain text input in the search box's style. `CreateSearchBox` is now built on it.
- `LuckyUI.CreateButton` buttons dim while disabled. `LuckyUI.StyleButton(btn, text, variant)` gives the same look to a button you created yourself, for one that needs a global name or a secure template.
- Shared icons `eraser` and `square-pen`, from Lucide like the rest of the set.

### Fixed
- `LuckyBankRun:AddModeSetting` gives its dropdown a narrower width, so the Warbank Stocking Mode label is no longer covered by it.
- The Hide Bank Queue toggle locks while the mode is Manual, which needs the window for its Start button, and returns to the player's own choice on Auto.
