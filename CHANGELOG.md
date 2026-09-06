## [Unreleased]

### Added
- A rich settings row takes `wip = true` and carries a blue WIP badge beside its label, marking a feature still being built. It sits after the NEW badge where a row has both, and every row type that already took `since` takes it. `VersionGate` MINOR is 16.

## [1.17.0] - 2026-09-03

### Added
- A rich settings row may take a strings table as its first positional field, `g:Toggle{ S.autoRepair, ... }`, and reads `label`, `desc`, `note`, `warning`, `suffix`, `tooltip` and `placeholder` from it where the row names none itself. `parent` accepts the same table. A row with no string label now fails at build with a message naming the key, instead of a nil index further in.
- A panel or group given a `db` binds rows that name a `key` to it: `checked`, `value` and the Select value become live reads of `db[key]`, so reopening the panel never shows a stale control, and the change handler writes `db[key]` before running any `onToggle`, `onChanged` or `onSelect` the row named. `MultiSelect` takes `keys = { optionKey = field }` the same way. A row's own `db` wins over the group's, which wins over the panel's, for per-character stores. Without a `db`, `key` keeps its old meaning as a slider frame-name suffix. `VersionGate` MINOR is 15.
- A `portal` icon joins the shared set in `Media/icons`, a spiral drawn as a filled outline rather than a stroke so it holds its weight at any size. `LuckyIcon("portal")` gives its path.
