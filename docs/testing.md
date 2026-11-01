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
| `BtmxFocusCore` | `BtmxFocusCoreTests` | `TimerEngine`, `Preferences`, `ClockFormat`: pure values |
| `BtmxFocusKit` | `BtmxFocusKitTests` | `TimerModel`, `SettingsStore`, `StatusItemPresentation` in-process |
| `BtmxFocusKit` | `BtmxFocusSnapshotTests` | the rendered `PopoverView`, `SettingsView` and status-item button |
| `BtmxFocus` | none | `AppDelegate`, `StatusItemController`, `SettingsWindowController`, `PhaseSignaler`: thin AppKit wiring, tested by hand |

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

- `PopoverView` in Ready(Focus), Running(Focus), Paused, Ready(Rest)
- `SettingsView` on each tab
- the status-item button, Ready and Running

Each in the light appearance only, at a fixed size and on a fixed clock. A pixel may
differ by 2% (`perceptualPrecision: 0.98`) so anti-aliasing noise passes.

When a snapshot fails, the message gives the path of the new image next to
the reference; compare them. If the change is intended, re-record:

```sh
SNAPSHOT_RECORD=1 swift test --filter BtmxFocusSnapshotTests
```

then look at the changed PNGs (`git diff --stat`, open them) before
committing. Expect to re-record after macOS updates, which change how system
controls render. A new test with no reference records one and fails once;
run it again.

Offscreen rendering can't draw window-server materials: in the Settings
snapshots the tab bar shows the selected segment blank and the other labels
truncated. The real window looks right. The tab content is what those
snapshots check.

## Before committing

```sh
swift test && swiftformat --lint . && swiftlint
```

Tests need Xcode (ADR 0009): swift-snapshot-testing builds on XCTest, which
only Xcode ships.

## By hand

The tests don't open the app. For changes to the wiring (status item,
popover anchoring, Settings window, notifications, sounds), build and run it
(`docs/building.md`) and go through the manual check there.
