# Testing btmx-focus

Run `swift test` after every change. It takes a few seconds and checks
everything except the AppKit wiring, without opening the app.

```sh
swift test                                   # all tests
swift test --filter TimerModelTests          # one suite
SNAPSHOT_RECORD=1 swift test                 # re-record every snapshot
```

## What runs where

| Target | Tests | Seam |
| --- | --- | --- |
| `BtmxFocusCore` | `BtmxFocusCoreTests` | `TimerEngine`, `Preferences`, `DailyTally`, `ClockFormat`: pure values |
| `BtmxFocusKit` | `BtmxFocusKitTests` | `TimerModel`, `SettingsStore`, `StatusItemPresentation` in-process |
| `BtmxFocusKit` | `BtmxFocusSnapshotTests` | the rendered `PopoverView`, `SettingsView` and status-item button |
| `BtmxFocus` | `BtmxFocusE2ETests` (only with `E2E=1`) | the bundled E2E app from outside: what a user sees, plus breadcrumbs |

Tests check behaviour through the public interface only, never private state.

### Unit tests

Everything time- or system-dependent is injected into `TimerModel`, so tests
drive it like the system would, with no waiting:

- `TimerHarness` (in `Sources/BtmxFocusTestSupport/`, shared by both test
  targets) builds a model on
  a `FakeClock`, a `RecordingSignaler` (stands in for `PhaseSignaler`) and
  private notification centers.
- `await harness.clock.advance(by:)` moves time and lets the tick loop run;
  `harness.clock.set(_:)` moves it without waking anything (a clock change).
- `harness.post(workspace:)`, `post(distributed:)` and `postClockChange()`
  deliver sleep, display, screen-lock and clock-change notifications.
- `SettingsStore` takes a per-test `UserDefaults` suite.

### Snapshot tests

`SnapshotTests` renders views with Point-Free's
[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
(a test-only dependency) and compares them with the reference PNGs in
`Tests/BtmxFocusSnapshotTests/__Snapshots__/`, which are committed:

- `PopoverView` in Ready(Focus), Running(Focus), Paused, Ready(Rest), Ready(Long break)
- each Settings tab's content (`SettingsTabContent`), without the tab bar:
  offscreen rendering can't draw its selected segment
- the status-item button, Ready and Running (Focus, Rest): the progress
  ring icon

Each at a fixed size, on a fixed clock and with private `UserDefaults`.

**Reference environment: macOS 27, light appearance.** For simplicity the
snapshots cover the light appearance only and the references are recorded on
macOS 27; there is no CI, so they are only as reliable as that match. On
another macOS version expect failures unrelated to your change: re-record on
macOS 27 or note the new version here when re-recording for everyone.

Each pixel may differ by up to 2% (`perceptualPrecision: 0.98`) so
anti-aliasing noise passes, but every pixel must pass (`precision` 1.0): one
pixel beyond that tolerance fails the image.

When a snapshot fails, the message gives the path of the new image next to
the reference; compare them. If the change is intended, re-record:

```sh
SNAPSHOT_RECORD=1 swift test --filter BtmxFocusSnapshotTests
```

then look at the changed PNGs (`git diff --stat`, open them) before
committing. Expect to re-record after macOS updates, which change how system
controls render. A new test with no reference records one and fails once;
run it again.

## Before committing

```sh
swift test && swiftformat --lint . && swiftlint
```

Tests need Xcode (ADR 0009): swift-snapshot-testing builds on XCTest, which
only Xcode ships.

## E2E tests

`scripts/e2e.sh` builds `build/btmx-focus E2E.app`
(`scripts/build-app.sh e2e`), counts down 3 s and runs `BtmxFocusE2ETests`.
The suite launches the real app and clicks through it like a user (ADR 0010).
**It takes over the mouse and keyboard for about half a minute; don't touch
them.** Run it on request, typically before a release; it isn't part of the
routine `swift test`. Extra arguments go to `swift test`:

```sh
scripts/e2e.sh                              # whole suite
scripts/e2e.sh --filter settingsAndQuit     # one test
```

It checks the critical path only, in three launches:

- **timer**: status item → popover with the keyboard; Play (time + red icon
  in the menu bar), Space pauses (gray), Reset, a 5 s phase end (rest waits
  at full length, signal breadcrumb), Skip, Esc (closes and hands back the
  keyboard).
- **settingsAndQuit**: `⋯` → Settings…, "Show timer in menu bar" off → icon
  only while running, `⋯` → Quit, still off after relaunch.

Everything else (every button, tabs, edge cases) is for unit and snapshot
tests, or a look by hand. Extend these flows rather than adding launches:
each one costs a few seconds.

### Permissions

The driver needs, for the app you run it from (Terminal, iTerm, your
editor), in System Settings → Privacy & Security:

- **Accessibility**: to read the app's controls and send clicks and keys.
- **Screen & System Audio Recording**: for screenshots and window titles.

It checks both before launching and fails naming the app to allow; it
never triggers a prompt. After granting, restart that app.

The status item must be visible: if the menu bar is full (or the item is
behind the notch), the test fails saying so; quit some menu-bar apps.

### How it works

- **E2E build**: bundle id `com.btmx.focus.e2e`, so it runs next to your
  real btmx-focus with its own settings and logs. Only this debug build
  accepts the launch arguments in `E2EContract` (`--e2e-focus-seconds`,
  `--e2e-rest-seconds`, `--e2e-no-notifications`, `--e2e-debug-logging`,
  `--e2e-reset-settings`, `--e2e-no-idle-skip`). Every test
  starts a fresh app with its settings wiped.
- **Driver** (`Sources/BtmxFocusDriver/`): finds elements by accessibility
  identifier (`AccessibilityID` in `BtmxFocusUIContract`, set by the app),
  clicks with real `CGEvent`s at their centre once they've stopped moving
  and are what's under the pointer, and puts the pointer back. Waits poll
  every 50 ms, 2 s by default. Breadcrumbs are read live from the unified
  log, not from the sandboxed `breadcrumbs.log`.
- **Artefacts** in `build/e2e/<timestamp>/` (gitignored, path printed at
  the end): a numbered screenshot per checkpoint (status item + popover +
  open menu, and the Settings window). For each failure, `…-FAILED.txt`
  plus a checkpoint screenshot. Look at the screenshots after UI changes.
- **A failure: read `…-FAILED.txt` first.** Its first line says who had the
  keyboard and what input was held (`frontmost=… e2eFrontmost=… held=…`),
  then the error, the AX tree and the breadcrumbs. Most failures are
  explained there; open the screenshot for visual questions only.
- **Leaked input**: a test that leaves a modifier or mouse button held
  fails, and the key is released, so it can't turn later clicks into
  ⌘-clicks or follow the user into other apps. `launch` refuses to start
  while anything is held.

### Exploring with `focus-drive`

The same driver as a CLI, for poking at the running E2E app by hand or from
an agent:

```sh
scripts/build-app.sh e2e
swift run focus-drive launch --e2e-reset-settings --e2e-focus-seconds 5
swift run focus-drive tree                    # AX tree with identifiers
swift run focus-drive click statusItem        # or any identifier, or `outside`
swift run focus-drive click btmx.popover.playPause
swift run focus-drive key space               # space, escape, cmd+w, …
swift run focus-drive shot running            # prints the screenshot path
swift run focus-drive state                   # who has the keyboard, held keys
swift run focus-drive release                 # release keys a run left held
swift run focus-drive quit
```

## By hand

What the E2E suite can't drive (real sleep, the notification prompt and
banner, sounds) is in the manual check in `docs/building.md`.
