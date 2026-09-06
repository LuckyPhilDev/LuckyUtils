## [1.18.0] - 2026-09-06

### Added
- A rich settings row takes `wip = true` and carries a blue WIP badge beside its label, marking a feature still being built. It sits after the NEW badge where a row has both, and every row type that already took `since` takes it. `VersionGate` MINOR is 16.
- `LuckyUI.EnableAutoHide(frame, seconds)` stamps `StartAutoHide([seconds])` and `StopAutoHide()` on a frame, hiding it after the wait and counting it down as a gold bar draining right to left along its foot. The frame fades out over the last three quarters of a second rather than vanishing, and its base alpha is restored when it goes. The bar is measured from the frame's current width each tick, so one that resizes to fit its own text stays correct. The mouse reaching the frame puts the wait back to full and holds it there, so looking away gives the whole wait again. `OnEnter` and `OnLeave` are hooked rather than set; `OnUpdate` is taken over.
