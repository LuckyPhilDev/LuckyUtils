## [Unreleased]

### Added
- `LuckyBankRun` runs every Lucky addon's bank jobs one at a time and lists the items still to move in a window beside the bank, Blizzard's or Baganator's. Addons register jobs with `OnBankOpen(order, job)` or run one-off jobs with `Queue(job)`; a job is a `plan` that returns its moves and a `run` that reports each through `Tick` and ends with `Done`. Every job is planned before the first one runs, so the window lists the whole run from the start. `AddSettingsToggle(group, since)` adds the shared Hide Bank Queue toggle to a rich settings group.
- A rich settings `Select` row takes `disabled = true` and locks the same way a disabled `Toggle` does.
- Shared icons `play`, `pause`, `square`, `arrow-down-to-line` and `arrow-up-from-line`, from Lucide like the rest of the set.
- `LuckySettings.Rich.IconTextButton(parent, label, icon)` builds the borderless gold icon-and-label button `ButtonRow` uses, for any frame that wants to match the settings panel. It returns the button and its width.
- A `LuckyBankRun` job takes `direction = "deposit"` or `"withdraw"`, drawn as an arrow before each of its rows. Hovering the arrow explains it, and hovering the item shows its tooltip.
- `LuckyDeps:IsEnabled(addonName, minVersion)` takes an optional minimum version, read from the addon's `.toc` so it works before that addon loads.

## [1.18.3] - 2026-09-15

### Fixed
- A rich settings `Select` dropdown no longer draws a black shadow smeared through its text. `VersionGate` MINOR is 19.

## [1.18.2] - 2026-09-12

### Fixed
- A rich settings group whose rows outgrow the panel draws them again, rather than a scrollbar over an empty page. The scrollbar re-anchored the scroll frame from inside its own layout callbacks, which left the scroll child with no position; it now settles a frame later. `VersionGate` MINOR is 18.

## [1.18.1] - 2026-09-07

### Fixed
- `LuckyUI.EnableAutoHide` asks the frame for the mouse each tick instead of hooking `OnEnter` and `OnLeave`. A mouse-enabled child takes the mouse off its parent, so a cursor resting on a button inside the frame used to read as having left it and the frame hid underneath. `OnEnter` and `OnLeave` are no longer touched; `OnUpdate` is still taken over. `VersionGate` MINOR is 17.

## [1.18.0] - 2026-09-06

### Added
- A rich settings row takes `wip = true` and carries a blue WIP badge beside its label, marking a feature still being built. It sits after the NEW badge where a row has both, and every row type that already took `since` takes it. `VersionGate` MINOR is 16.
- `LuckyUI.EnableAutoHide(frame, seconds)` stamps `StartAutoHide([seconds])` and `StopAutoHide()` on a frame, hiding it after the wait and counting it down as a gold bar draining right to left along its foot. The frame fades out over the last three quarters of a second rather than vanishing, and its base alpha is restored when it goes. The bar is measured from the frame's current width each tick, so one that resizes to fit its own text stays correct. The mouse reaching the frame puts the wait back to full and holds it there, so looking away gives the whole wait again. `OnEnter` and `OnLeave` are hooked rather than set; `OnUpdate` is taken over.
