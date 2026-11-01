# Building & running btmx-focus locally

btmx-focus is a single Swift package. There is no `.xcodeproj`; a small
script wraps the built binary into a signed `.app` bundle.

```
Package.swift
Sources/BtmxFocusCore/     timer engine + formatting (pure, no UI)
Sources/BtmxFocusKit/      app layer: TimerModel, SettingsStore, views,
                           status-item presentation, crash log
Sources/BtmxFocus/         thin AppKit wiring: app delegate, status item,
                           Settings window, end-of-phase signals
Sources/BtmxFocusTestSupport/  fake clock and harness shared by the tests
Tests/BtmxFocusCoreTests/  Swift Testing tests for the engine
Tests/BtmxFocusKitTests/   app-layer unit tests
Tests/BtmxFocusSnapshotTests/  snapshot tests (Xcode only) + reference images
Support/                   Info.plist + entitlements for the .app bundle
scripts/build-app.sh       builds build/btmx-focus.app
```

## Requirements

- macOS 15 or newer
- Swift 6 toolchain: Xcode 16+ **or** the Command Line Tools
  (`xcode-select --install`)
- Optional: `brew install swiftlint swiftformat`

If Xcode is installed but you haven't accepted its license, every `swift`
command fails with "You have not agreed to the Xcode license agreements".
Either accept it once:

```sh
sudo xcodebuild -license accept
```

or run commands against the Command Line Tools instead:

```sh
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
```

## Build and launch the app

```sh
scripts/build-app.sh          # release build → build/btmx-focus.app
open build/btmx-focus.app
```

The app appears in the menu bar only (no Dock icon). Click the item to open
the popover. Quit from the `⋯` menu in the popover.

For a debug build: `scripts/build-app.sh debug`.

To rebuild while the app is running, quit it first (`⋯` → Quit, or
`osascript -e 'quit app "btmx-focus"'`). macOS allows only one instance.
`pkill` also works.

### Logs & crash reports

Logs are in `~/Library/Containers/com.btmx.focus/Data/Library/Logs/btmx-focus/`
(`~/Library/Logs/btmx-focus/` under `swift run`); `⋯` → "Show Logs in Finder"
opens it. Nothing is written there during normal use.

- `crash-<date>.log`: written when the app crashes; starts with the crash
  reason and the last user action, then the last 50 actions. The 5 newest
  are kept.
- `breadcrumbs.log` (+ `breadcrumbs.previous.log`): only with `⋯` → Debug
  Logging on; every action with state before → after, capped at 1 MB total.
- macOS's own report with the stack trace:
  `~/Library/Logs/DiagnosticReports/btmx-focus-*.ips`.

Live stream: `log stream --predicate 'subsystem == "com.btmx.focus"'`.

### Notifications

The first time you press Play, macOS asks for permission to show
notifications. If you deny it, the end-of-phase sound still plays. Change it
later in System Settings → Notifications → btmx-focus.

The app is ad-hoc signed, so after a rebuild macOS may treat it as a new app
and ask again.

### Running without a bundle

`swift run BtmxFocus` also starts the app, but it isn't inside a bundle, so
notifications are turned off (the sound and everything else still work). Use
it for quick UI iteration only.

## Tests

```sh
swift test
```

Unit tests use a fake clock and snapshot tests compare rendered views with
committed reference images; see `docs/testing.md`.

## Lint & format

```sh
swiftformat .            # apply formatting (config: .swiftformat)
swiftformat --lint .     # check only
swiftlint                # config: .swiftlint.yml
```

With only the Command Line Tools, SwiftLint needs to be told where SourceKit is:

```sh
TOOLCHAIN_DIR=/Library/Developer/CommandLineTools swiftlint
```

## Editing in Xcode

`open Package.swift` opens the package in Xcode, where you can edit, run the
tests and run the `BtmxFocus` scheme. Running from Xcode works like
`swift run`: the app isn't bundled, so notifications are off. Use
`scripts/build-app.sh` to test notifications.

## Manual MVP check

Against spec §7, with the bundled app:

1. Menu bar shows the focus icon only (no time); no Dock icon.
2. Popover: "Focus", `30:00`, ▶ under the time.
3. ▶ shows `29:59` to the left of the icon without the icon moving; the
   icon turns red (green during rest). ❚❚ pauses it and the icon goes back
   to gray; ▶ resumes.
4. Skip → Ready(Rest) `05:00`, no sound. Reset → Ready(Focus) `30:00`.
5. Phase end: a notification, the Glass sound (after focus) or Hero (after
   rest), and the next phase waits at full length with ▶. To check this
   without waiting 30 minutes, temporarily change `Schedule.standard` in
   `Sources/BtmxFocusCore/TimerEngine.swift` to a few seconds and rebuild.
6. Sleep the Mac (Apple menu → Sleep), wake it: Ready(Focus) `30:00`.
