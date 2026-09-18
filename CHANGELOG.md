## [1.19.0] - 2026-09-18

### Added
- `LuckyBankRun` runs every Lucky addon's bank jobs one at a time and lists the items still to move in a window beside the bank, Blizzard's or Baganator's. Addons register jobs with `OnBankOpen(order, job)` or run one-off jobs with `Queue(job)`; a job is a `plan` that returns its moves and a `run` that reports each through `Tick` and ends with `Done`. Every job is planned before the first one runs, so the window lists the whole run from the start. `AddSettingsToggle(group, since)` adds the shared Hide Bank Queue toggle to a rich settings group. `VersionGate` MINOR is 20.
- `LuckyBankRun:AddModeSetting(group, opts)` adds a shared Auto or Manual choice. Manual mode lists the planned items on bank open and holds the jobs until the player presses Start at the top of the window, or an addon calls `StartBankJobs()`.
- A rich settings `Select` row takes `disabled = true` and locks the same way a disabled `Toggle` does.
- Shared icons `play`, `pause`, `square`, `arrow-down-to-line` and `arrow-up-from-line`, from Lucide like the rest of the set.
- `LuckySettings.Rich.IconTextButton(parent, label, icon)` builds the borderless gold icon-and-label button `ButtonRow` uses, for any frame that wants to match the settings panel. It returns the button and its width.
- A `LuckyBankRun` job takes `direction = "deposit"` or `"withdraw"`, drawn as an arrow before each of its rows. Hovering the arrow explains it, and hovering the item shows its tooltip. The Start button is the icon-and-label style with the play icon.
- The Bank Queue window has a Pause button while a run is going, and Resume once paused, in Auto and Manual mode alike. A job steps to its next move with `job:After(delay, fn)`, which holds the step while paused and drops it once the job is dropped; a job that never calls it pauses only between jobs.
- `LuckyDeps:IsEnabled(addonName, minVersion)` takes an optional minimum version, read from the addon's `.toc` so it works before that addon loads.
