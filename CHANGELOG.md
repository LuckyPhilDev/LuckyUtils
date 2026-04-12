## [1.0.0] - 2026-04-12

### Added

- **LuckyUI** — dark/gold colour palette as RGB constants and WoW colour-escape strings, shared font and backdrop definitions, and frame builders: styled panels, gradient headers with close button, primary/secondary/danger buttons, gold-accent checkboxes, labelled dividers, and `EnableDrag` for drag-to-move frames with SavedVariables position persistence.
- **LuckySettings** — fluent builder for Interface Options panels. `NewPanel` creates and registers a scrollable settings page; builder methods add checkboxes (`Toggle`), segmented pill selectors (`Selector`), sliders with live value readouts (`Slider`), and gold section headings with rules (`Section`). Includes a `/lsdebug` command to toggle internal diagnostics.
- **LuckyMinimap** — minimap button factory with no external library required. Buttons support shift-drag repositioning, click and tooltip callbacks, and SavedVariables persistence for both position and visibility.
- **LuckyLog** — debug logger factory. `LuckyLog:New(prefix, fn)` returns a logger that prints only when the supplied flag function returns true, keeping release builds silent.
- **LuckyDeps** — dependency checker: `IsEnabled` tests whether an addon is installed and loadable; `Check` confirms it is loaded and optionally validates a minimum version string.
- **LuckySound** — sound helpers: `Path` builds the Interface path for addon-relative files; `Play` and `PlayKit` play a file or SoundKit ID on a chosen channel; `Stop` stops a playing handle.
- **LuckyUtils** — `ApplyDefaults` for recursive SavedVariables initialisation (existing values are never overwritten), and `CharacterKey` for a reliable `Name-Realm` character identifier.
