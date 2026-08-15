## [1.9.1] - 2026-08-15

### Improved
- The promo section ships its own artwork for each addon, in place of borrowed game icons. The files are in `Media` as `promo-<addon>.tga`, so an addon's minimap button can point at the same art.

## [1.9.0] - 2026-08-15

### Added
- Rich settings panels now carry the addon's version beside its name in the title bar, with the library version in the tooltip, and offer Dev Mode and Minimap Button as title bar toggles so addons no longer need a General group holding two rows.
- `LuckyUI.CreateIconButton` builds the shared gold icon button, with a text or live tooltip, optional border cropping for `Interface\Icons` art, and `SetIconColor` / `SetIconDesaturated` for tinting it by state.

### Improved
- The What's New list now scrolls inside the first settings group instead of taking a tab of its own, so the group's version and promo rows stay pinned below it however long the list gets.
- The promo section is now a row of icons with Discord first, in place of a stacked list.
- Lucky's Wardrobe is listed in the promo section.

## [1.8.1] - 2026-08-13

### Added
- Minimap buttons now also register with display addons such as Titan Panel, Bazooka and ChocolateBar, so an addon can sit on a panel instead of the minimap. Addons that pass their folder name are listed under the title and version read from their TOC.

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
