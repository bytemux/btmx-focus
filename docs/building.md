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
Tests/BtmxFocusSnapshotTests/  snapshot tests + reference images
Support/                   Info.plist + entitlements for the .app bundle
Sources/BtmxFocusUIContract/  accessibility ids + E2E launch arguments
Sources/BtmxFocusDriver/   E2E driver (Accessibility + real input)
Sources/FocusDrive/        focus-drive CLI on the driver
Tests/BtmxFocusE2ETests/   E2E suite (runs only with E2E=1)
scripts/build-app.sh       builds build/btmx-focus.app (or the E2E app)
scripts/e2e.sh             builds the E2E app and runs the E2E suite
```

## Requirements

- macOS 15 or newer
- Xcode 16+ (Swift 6), selected with `xcode-select` and its license
  accepted (ADR 0009)
- `brew install swiftlint swiftformat`

If any of these is missing, the command that needs it fails with its own
message; fix the setup and rerun.

## Build and launch the app

```sh
scripts/build-app.sh          # release build → build/btmx-focus.app
open build/btmx-focus.app
```

The app appears in the menu bar only (no Dock icon). Click the item to open
the popover. Quit from the `⋯` menu in the popover.

For a debug build: `scripts/build-app.sh debug`. `scripts/build-app.sh e2e`
builds `build/btmx-focus E2E.app` for the E2E tests (`docs/testing.md`).

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

## Editing in Xcode

`open Package.swift` opens the package in Xcode, where you can edit, run the
tests and run the `BtmxFocus` scheme. Running from Xcode works like
`swift run`: the app isn't bundled, so notifications are off. Use
`scripts/build-app.sh` to test notifications.

## Manual MVP check

`scripts/e2e.sh` covers the status item, the popover, the `⋯` menu and
Settings (`docs/testing.md`). What it can't drive, check by hand with the
bundled app:

1. No Dock icon.
2. ▶ shows the time to the left of the icon without the icon moving.
3. Sleep the Mac (Apple menu → Sleep), wake it: Ready(Focus) `30:00`. (The
   E2E suite only simulates the sleep notification.)
4. The first ▶ asks for notification permission.
5. Phase end: a notification banner, and the Glass sound (after focus) or
   Hero (after rest). To check this without waiting 30 minutes, launch the
   E2E app with a short schedule:
   `open "build/btmx-focus E2E.app" --args --e2e-focus-seconds 5 --e2e-rest-seconds 5`.
