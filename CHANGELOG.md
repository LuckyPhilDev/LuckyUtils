## [1.16.0] - 2026-08-29

### Improved
- A rich settings row may name a `Slider` as its `parent`, not just a `Toggle`. The child locks and dims while the parent reads zero and unlocks the moment it is dragged off zero; previously a slider parent gave indentation only.
- A rich settings row given a `warning` string now draws a red `triangle-alert` icon in its leading space, with the warning in a tooltip on hover. The control shifts right to make room, and the icon forwards hover to the row so the About rail still tracks it. Previously `warning` reached the About rail only. An optional `warningLevel`, a string or a zero-arg function returning `caution` or `danger`, paints it amber or red and is re-read whenever the row's value changes, so a row is loud only on the choice that is actually irreversible.
- A settings group whose rows outgrow the panel now folds them into a scrolling region the first time it is shown, instead of running off the bottom. It happens after the group is built, so the rows keep the anchor chain they were placed in, and a group that built its own `Fill` region is left alone. A group that fits looks unchanged: the scrollbar hides itself and gives its width back. `VersionGate` MINOR is 14.

### Fixed
- A scrolling region whose content fits no longer keeps its scrollbar, or the width reserved for it. `OnScrollRangeChanged` only fires when the range changes, so a region built around content that already fitted never heard about it; the bar now follows the child measured against the region, on size as well as range, and is settled once at build time.
- A settings row locks when any ancestor is cleared, not just the row directly above it. `applyEnabled` read the parent's checkbox without asking whether that parent was itself enabled, so a grandchild under a ticked parent stayed usable while the grandparent was off, and toggling a parent only re-applied one level of children instead of the whole subtree.

## [1.15.1] - 2026-08-26

### Fixed
- Copies of this library from before the version gate open each file with `LuckyUI = {}` rather than `LuckyUI = LuckyUI or {}`, and consult nothing that would stop them, so one loading after the winning copy replaced the published tables and dropped every function added since. Consumers then called a nil on a table that still looked intact, which is what `LuckySettings:NewRichPanel` and `LuckyDeps:StandaloneRemovable` were both hitting. The winning copy now remembers what it published as its own host finishes loading and puts it back as each later addon comes in.

## [1.15.0] - 2026-08-26

### Added
- A one-time panel at login tells the player they can uninstall the standalone `Luckys_Utils` addon. It appears only where `LuckyDeps:StandaloneRemovable()` holds, meaning an embedded copy is loaded and no installed addon lists the standalone as a required dependency. Dismissal persists in `LuckySettingsDB.standaloneNoticeSeen`.

### Improved
- `LuckyUI.CreateHeader` draws its close button with the shared `x` icon rather than a red plate with a text `x`, matching the borderless row actions.

### Fixed
- At an equal `MINOR` an embedded copy now takes the registration from the standalone rather than skipping, so a half-installed standalone that happened to load first can no longer leave consumers calling functions it never published. A higher `MINOR` still wins outright either way, and two embedded copies at one version keep the first-wins rule.
