# 0010. E2E tests drive the bundled app through Accessibility and real input

Status: Accepted
Date: 2026-11-02

## Context

`swift test` (ADR 0009) covers the engine, the app layer and how the views
look, but not the AppKit wiring: the status item, the popover's anchoring and
focus, the `⋯` menu, the Settings window. That was checked by hand against
the manual MVP list, and agents weren't allowed to look at the UI at all.

The usual tool, XCUITest, needs an Xcode project and a UI-test bundle
target, which ADR 0009 avoids. Third-party screen-automation tools
(e.g. Peekaboo) add a dependency and drive the screen by image rather than
by element.

## Decision

- **E2E build.** `scripts/build-app.sh e2e` builds a debug app, bundle id
  `com.btmx.focus.e2e`, named "btmx-focus E2E". It runs next to the user's
  real instance and has its own sandbox container, so its settings and
  logs are separate. Only this build (debug, this bundle id) accepts the
  `--e2e-*` launch arguments: short schedule, no notifications and so no
  permission prompt, debug logging on, wipe settings.
- **Accessibility identifiers** for the status item, the popover's controls,
  the `⋯` menu items and the Settings window live in `BtmxFocusUIContract`,
  shared by the app and the driver. Elements are looked up by identifier.
  The one exception is SwiftUI's Settings tab buttons, which get the SF
  Symbol name as identifier, so they're found by label.
- **Driver** (`BtmxFocusDriver`, in the package) uses the Accessibility API
  to read the app, and real `CGEvent` mouse and keyboard input to act. The
  pointer is put back after each click. Before a click it checks that the
  element is on screen (not behind the notch or pushed off the menu bar)
  and is the topmost element at its centre. Waits poll every 50 ms (2 s
  default). Breadcrumbs come from the unified log (`log stream`), because
  reading `breadcrumbs.log` inside another app's container triggers a
  macOS prompt. The driver checks Accessibility and Screen Recording up
  front and never triggers a prompt.
- **Real input only.** An `AXPress` mode for background runs was considered
  and dropped. It bypasses what the user actually does: synthetic presses
  passed while real clicks failed (the popover didn't get keyboard focus).
- **`focus-drive`** CLI on the same library (`tree`, `click`, `key`, `shot`,
  `launch`, `quit`) for exploring the UI by hand or from an agent, in
  place of screenshots or computer use.
- **E2E suite** (`BtmxFocusE2ETests`, Swift Testing) is skipped unless
  `E2E=1`, runs serialized, and launches a fresh app per test. It covers
  the critical path only (timer flow, Settings, Quit) in as few launches
  as possible; details stay in unit and snapshot tests.
- **Run on request only**, typically before a release, since it takes the
  user's mouse and keyboard. Agents don't run it (or `focus-drive`) on
  their own.
  `scripts/e2e.sh` builds the E2E app, counts down, runs the suite and
  prints the screenshot folder (`build/e2e/<timestamp>/`, gitignored).
  Each checkpoint saves a screenshot; a failure saves a full screenshot,
  the AX tree and the breadcrumbs.

## Consequences

- The manual MVP check shrinks to what can't be driven from outside: real
  sleep, the notification banner and prompt, the sounds, plus what the
  critical path leaves out (no Dock icon, the icon staying put, click
  outside, Settings tabs, ⌘W).
- E2E runs take over the mouse and keyboard for about half a minute and need
  Accessibility and Screen Recording for the app they run from (terminal or
  editor). They can't run in the background or on CI as they are.
- The app carries debug-only E2E hooks, gated by build configuration and
  bundle id.
- Fixed waits remain where macOS gives no signal: about 1 s after launch
  before the menu bar routes clicks to a new status item, the app's 0.3 s
  "don't reopen on the closing click" guard, and negative checks ("still
  closed", "clock doesn't move"). If the suite gets flaky, look there first.
- The status item's colour (red/green while running, gray otherwise) isn't
  in the AX tree; the suite reads it from screenshot pixels (`Pixels`).
