## [1.15.0] - 2026-08-26

### Added
- A one-time panel at login tells the player they can uninstall the standalone `Luckys_Utils` addon. It appears only where `LuckyDeps:StandaloneRemovable()` holds, meaning an embedded copy is loaded and no installed addon lists the standalone as a required dependency. Dismissal persists in `LuckySettingsDB.standaloneNoticeSeen`.

### Improved
- `LuckyUI.CreateHeader` draws its close button with the shared `x` icon rather than a red plate with a text `x`, matching the borderless row actions.

### Fixed
- At an equal `MINOR` an embedded copy now takes the registration from the standalone rather than skipping, so a half-installed standalone that happened to load first can no longer leave consumers calling functions it never published. A higher `MINOR` still wins outright either way, and two embedded copies at one version keep the first-wins rule.
