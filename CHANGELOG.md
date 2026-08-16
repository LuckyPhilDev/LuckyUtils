## [1.10.0] - 2026-08-16

### Added
- A setting whose `requires` check fails now greys its row out like an explicitly disabled one, so the About pane's warning is no longer the only sign the toggle does nothing. `LuckyDeps:Check` returns a status alongside its message, telling an addon that is installed but switched off apart from one that is absent.
- The About pane offers an Enable and Reload button when the dependency is only switched off, turning it and its own dependencies back on. `LuckyDeps:Enable` does the same from code.

### Improved
- Rich settings panels now show the addon's icon to the left of its name in the title bar, using the promo artwork for suite addons and the TOC `IconTexture` for anything else.
- The promo section ships its own artwork for each addon, in place of borrowed game icons. The files are in `Media` as `promo-<addon>.tga`, so an addon's minimap button can point at the same art.
