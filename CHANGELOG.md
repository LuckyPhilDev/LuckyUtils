## [1.11.0] - 2026-08-18

### Added
- The library is version-gated behind LibStub as `LuckysUtils-1.0` and ships `LibStub.lua`. Consumers embed their own copy via `.pkgmeta` externals and load `Libs\LuckysUtils\embeds.xml` before their own files; the newest copy loaded wins and publishes the same globals as always. Check which copy won in-game with `/dump LibStub.minors["LuckysUtils-1.0"]`.
- `LuckyUtils.FormatMoney(copper)` formats a copper amount as plain "12g 34s 56c" chat text.
- `LuckyUtils.Debounced(seconds, action)` wraps an action so a burst of calls runs it once after the delay.

### Improved
- Runtime state (item caches, roster callbacks, the minimap broker queue, the error watcher and its handler chain) now lives on the module globals, so loading several embedded copies never duplicates frames, event handlers, or error prompts.
- LuckySettings and LuckyBugs initialise off the hosting addon's own load event, so they work embedded under any addon folder name.
- `embeds.xml` now loads every module, including LuckyBugs, in the same order as the standalone addon.
