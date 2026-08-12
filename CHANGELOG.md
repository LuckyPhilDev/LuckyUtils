## [1.8.0] - 2026-08-12

### Added
- Lua errors raised by Lucky addons are now caught and shown in a panel that offers to report them on the Discord, with recent errors kept between sessions.
- Settings panels and groups can now build their contents the first time they are shown rather than up front, and toggles and sliders can read their value each time a panel opens, so a setting changed elsewhere never shows stale.

### Improved
- Updated for World of Warcraft patch 12.1.

## [1.7.2] - 2026-07-31

### Improved
- Wide screenshots in settings panels now open at full size beside the cursor instead of shrinking into an unreadable strip in the About sidebar.

## [1.7.1] - 2026-07-30

### Fixed
- Settings panels no longer fail to open when an out-of-date copy of the library has been left behind inside another addon's folder.

## [1.7.0] - 2026-07-25

### Added
- Addons can now move items between bags and bank tabs one at a time, waiting for each transfer to finish, so bulk moves no longer drop or duplicate stacks when the server is slow.
- Settings saved by an addon can now be upgraded safely when its options change, with the old settings left untouched if anything goes wrong.

### Improved
- The About sidebar in settings panels is now optional and can be turned off for individual pages, so pages that need the full width get it.
