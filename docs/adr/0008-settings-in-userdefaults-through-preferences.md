# 0008. Settings in `UserDefaults` through `Preferences`

Status: Accepted
Date: 2026-11-01

## Context

v0.2 adds a Settings window (General, Intervals, Notifications & Sounds).
Settings must apply without a restart and survive relaunch. The defaults
are product decisions (30/5/15 min, long break every 4, …) that should be
tested like the engine, but the app target has no tests. The app has a
custom `@main` that runs `NSApplication` (ADR 0002), so SwiftUI's `Settings`
scene isn't available without moving to a SwiftUI `App`.

## Decision

- `Preferences`, a value type in `BtmxFocusCore`, holds every user setting
  with its default. It loads from `UserDefaults` with one key per setting,
  named after the property; a missing key or a value of the wrong type
  reads as the default. Saving writes only the settings that changed, so
  settings the user never touched follow future changes to their default.
  It also describes what changed between two values, for the recent-actions
  log.
- `SettingsStore`, an `@Observable` class in the app, holds the live
  `Preferences`. Every change is saved at once and recorded with
  `CrashLog.record`. Consumers (the status item now; the timer and signaler
  as their settings land) read from it and update through observation.
- Debug Logging is a diagnostic toggle in the `⋯` menu, not a user setting:
  it stays a separate `@AppStorage` key owned by `CrashLog`.
- The Settings window is an AppKit `NSWindow` hosting a SwiftUI `TabView`
  of `Form`s, consistent with ADR 0002. One instance, created on first open
  and reused; its frame is autosaved. Opening it closes the popover,
  activates the app (no Dock icon) and makes the window key.
- Launch at login (planned) will not be stored: its checkbox will read
  `SMAppService` live.

## Consequences

- Defaults and persistence are covered by `swift test`; the window is
  checked by hand.
- Renaming a `Preferences` property renames its key, so a rename needs a
  migration or users lose that setting.
- No Save button and no separate model per tab; adding a setting means a
  property with a default, a line in `init(defaults:)` and a control.
- Settings sit in the app's sandboxed defaults domain
  (`~/Library/Containers/com.btmx.focus/Data/Library/Preferences/`), shared
  with debug logging and the window frame.
