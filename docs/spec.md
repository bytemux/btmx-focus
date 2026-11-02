# btmx-focus — Product & Technical Spec

Status: Draft · Last updated: 2026-10-31

btmx-focus is a native macOS menu-bar app that keeps you in a focus / rest
rhythm. This document describes the full product we're aiming for and marks
what ships in the **MVP**. Architectural decisions are recorded separately as
ADRs in [`docs/adr/`](adr/).

Reference material lives in `sources/` (git-ignored, main checkout only):
screenshots of an existing Pomodoro-style app we use for inspiration, and
`tooling.md` listing the installed dev tools.

---

## 1. Release legend

| Tag      | Scope                                                                      |
| -------- | -------------------------------------------------------------------------- |
| **MVP**  | Fixed 30 / 5 focus–rest cycle, each phase started manually with Play; menu-bar countdown; popover with Play/Pause, Skip, Reset, Quit; end-of-phase icon change + notification + fixed system sound; reset on sleep. Nothing else ships in it. |
| **v0.2** | Settings window: custom durations, long breaks, daily target, auto-start option, sleep behaviour option, notification toggle; launch at login; global shortcuts; persisted timer; progress ring. |
| **v0.3** | Sound customization: choose sounds, volume, ticking sound.                  |
| **v0.4** | Tasks.                                                                      |
| **v0.5** | Reports / history.                                                          |
| **Later**| Ideas we keep in view but haven't scheduled (blocking, automation, sync).  |
| **Never**| Explicit non-goals (ads, upsells).                                          |

---

## 2. MVP at a glance

The MVP does one thing: **alternate between 30 minutes of focus and 5 minutes
of rest, with an always-accurate countdown in the macOS menu bar.** The user
starts every phase by pressing Play; the app never starts a phase on its own.

In scope:

- Menu-bar-only app (no Dock icon, no main window).
- Fixed cycle: Focus 30:00 → Rest 5:00 → Focus 30:00 → …
- When a phase ends, the next phase is loaded at full length and **waits for
  the user to press Play**.
- Menu-bar label shows a phase icon + `mm:ss`, updated every second while
  running.
- Clicking the menu-bar item opens a small popover: phase name, large `mm:ss`,
  a Play / Pause button under the time, plus Skip, Reset and Quit.
- End of phase: the icon changes, a system notification is posted and a
  built-in macOS sound plays.
- If the Mac sleeps, the timer resets.

Out of scope for MVP (see roadmap §6): settings, custom durations, sound
choice / volume, long breaks, auto-start, launch at login, global shortcuts,
tasks, reports, persistence across app restarts.

---

## 3. Functional spec

### 3.1 Timer cycle — **MVP**

| Phase | Duration (MVP, fixed) | Next phase |
| ----- | --------------------- | ---------- |
| Focus | 30 min                | Rest       |
| Rest  | 5 min                 | Focus      |

- On launch the app is **Ready** for Focus, showing `30:00` with a Play button.
- When a running phase reaches `00:00`, the app switches to **Ready** for the
  next phase at its full duration (e.g. after Focus it shows `05:00` with Play)
  and signals the end of the phase (§3.6). It does **not** start the next
  phase by itself.
- There is no cycle counter or long break in the MVP.

### 3.2 Timer states — **MVP**

```
                 play                       pause
  Ready(phase) ────────▶ Running(phase) ───────────▶ Paused(phase)
      ▲                       │       ◀───────────        │
      │                       │           play            │
      │   phase ends          │                           │
      └──── Ready(next) ◀─────┘                           │
                                                          │
  Reset, Mac sleep  ──▶  Ready(Focus)   ◀─────────────────┘ (reset)
  Skip              ──▶  Ready(next phase)
```

| State   | Holds                          | Menu-bar label                  | Popover button |
| ------- | ------------------------------ | ------------------------------- | -------------- |
| Ready   | phase                          | phase icon only (no time)       | ▶ Play         |
| Running | phase, `endDate`               | live `mm:ss` + coloured phase icon | ❚❚ Pause    |
| Paused  | phase, `remaining` (Duration)  | frozen `mm:ss` + paused icon    | ▶ Play         |

Actions:

| Action | Allowed in      | Effect                                                         |
| ------ | --------------- | -------------------------------------------------------------- |
| Play   | Ready           | Running, `endDate = now + phase duration`                      |
| Play   | Paused          | Running, `endDate = now + remaining`                           |
| Pause  | Running         | Paused, `remaining = endDate − now`                            |
| Skip   | any             | Ready for the other phase, full duration, no signal (§3.6)     |
| Reset  | Running, Paused, Ready(Rest) | Ready(Focus), `30:00`                             |
| Quit   | any             | Terminate app (no confirmation in MVP)                         |

### 3.3 Time-keeping rules — **MVP**

The timer is **deadline-based**, not tick-counting:

- While running we store the absolute `endDate` and derive
  `remaining = endDate − now` on every display refresh. A missed or late tick
  never causes drift.
- The display refreshes once per second, aligned to the second boundary so
  the label changes at the same moment the remaining whole second changes.
- Remaining time is displayed **rounded up** to the whole second
  (`29:59.4` shows `30:00`; `00:00` appears only at the deadline).
- Phase end is scheduled for exactly `endDate`, not detected on the next tick.
- While the display is asleep or the screen is locked, nobody sees the
  seconds: the app skips per-second updates and wakes only at `endDate`,
  then resumes per-second updates on wake / unlock.
- The popover's view exists only while it's open, so a closed popover costs
  nothing.
- Clock changes (manual time change, time zone change): only absolute
  instants are stored, so time zone changes have no effect; a manual clock
  change is handled by recomputing from `endDate` (an observed jump of more
  than a few seconds may be treated like sleep — decided in ADR 0005).

### 3.4 Sleep / wake — **MVP**

- When the system goes to sleep (`NSWorkspace.willSleepNotification`), the
  timer **resets** to Ready(Focus), `30:00`, in whatever state it was in.
- No notification or sound is played for a sleep reset.
- Display sleep and screen lock **without** system sleep do not reset the
  timer.

### 3.5 UI — **MVP**

#### Menu-bar item

- Label = `mm:ss` + space + SF Symbol once a phase has been started
  (Running or Paused), using **monospaced digits** so the status item
  doesn't change width every second. In Ready (not started) it shows the
  icon only.
- The icon sits **to the right of the time** and stays anchored there:
  status items grow to the left, so starting or stopping the timer adds or
  removes the time without moving the icon.
- Phase icons (SF Symbols, final pick during implementation):
  - Ready / Running Focus: `timer`
  - Ready / Running Rest: `cup.and.saucer`
  - Paused: `pause.circle`
- Ready and Running are visually distinguishable, so a glance tells whether
  the clock is actually moving: running icons are filled and coloured —
  **red** during Focus, **green** during Rest. Ready and Paused icons are
  outline template images in the menu bar's normal white / gray, adapting
  to light / dark menu bars.
- Durations ≥ 60 min (not possible in MVP) would render as `h:mm:ss`.

#### Popover

Clicking the item opens an `NSPopover` hosting a SwiftUI view,
modelled on `sources/main.png` but without task field, ring, footer or ads:

```
┌───────────────────────────┐
│          Focus            │   phase name
│                           │
│          30:00            │   large monospaced time
│            ▶              │   Play / Pause button under the time
│                           │
│  Skip ⏭      Reset ↺   ⋯  │   ⋯ menu: Quit btmx-focus ⌘Q
└───────────────────────────┘
```

- Opening the popover makes the app active, so it has the keyboard: Space /
  Return toggles Play / Pause; Esc closes it and hands the keyboard back to
  the previous app. Global shortcuts are v0.2.
- The popover's time updates live while open.

### 3.6 End-of-phase signal — **MVP**

When a running phase reaches `00:00`:

1. The menu-bar icon switches to the next phase's Ready icon.
2. A system notification is posted (`UserNotifications`):
   - after Focus: "Focus done — time for a 5 min break"
   - after Rest: "Break over — ready for 30 min of focus"
3. A built-in macOS sound plays via `NSSound` (sounds in
   `/System/Library/Sounds`), fixed in MVP:
   - after Focus: **Glass**
   - after Rest: **Hero**

Rules:

- The sound is played by the app, not attached to the notification, so it is
  heard even if notifications are denied or muted; the notification itself
  is posted silently to avoid a double sound.
- Notification permission is requested on the first Play, not at launch.
  If denied, everything else still works.
- Skip and Reset never trigger the signal.
- macOS Focus modes / Do Not Disturb may suppress the notification; the app
  does not try to bypass that. (Whether the sound should also respect DND is
  a v0.3 setting.)

### 3.7 App lifecycle — **MVP**

- `LSUIElement = YES`: no Dock icon, no app switcher entry.
- Single instance.
- On launch: Ready(Focus). Timer state is **not** persisted across
  quit/relaunch in the MVP.

### 3.8 Diagnostics — **MVP**

- No disk writes during normal use. The last 50 actions (play, pause, skip,
  reset, popover open/close, phase end, system sleep, clock change,
  notification permission result, launch, quit), each with the state
  before → after, are kept **in memory** and mirrored to the unified log
  (subsystem `com.btmx.focus`, not persisted by default).
- Fatal signals (including Swift runtime traps) write the crash reason, the
  **last user action** and those recent actions to a crash file, then the
  app crashes normally so macOS still writes its `.ips` report. The next
  launch names it `crash-<date>.log`; only the **5 newest** are kept.
- **Debug Logging** (`⋯` menu, off by default) additionally appends every
  action to `breadcrumbs.log`, rotated at 512 KB with one previous file
  kept, so at most **1 MB** on disk.
- Logs stay on the Mac (sandbox container `Library/Logs/btmx-focus/`);
  `⋯` → "Show Logs in Finder" opens the folder.

---

## 4. Non-functional requirements

| Area           | Requirement                                                              | Release |
| -------------- | ------------------------------------------------------------------------ | ------- |
| Accuracy       | Displayed remaining time never off by more than 1 s from `endDate − now`; phase-end signal fires within 1 s of `endDate`. | MVP |
| Energy         | ≤ 1 wake-up per second while running; no periodic wake-ups while Ready or Paused. Should not appear in "Apps Using Significant Energy". Use timer tolerance. | MVP |
| Memory         | < 50 MB resident.                                                         | MVP |
| Launch         | Status item visible < 1 s after launch.                                   | MVP |
| Accessibility  | Status item and popover controls have VoiceOver labels ("Focus, running, 24 minutes 13 seconds remaining"). | MVP |
| Localization   | Strings go through String Catalogs from day one; English only at MVP.    | MVP |
| Privacy        | No network access, no analytics, no ads. App Sandbox enabled.             | MVP |
| Appearance     | Correct in light, dark, and tinted menu bars.                             | MVP |

---

## 5. Technical approach

Architectural choices below are proposals; each significant one becomes an
ADR before or during implementation.

| Concern          | Choice                                                                 | ADR |
| ---------------- | ---------------------------------------------------------------------- | --- |
| Language         | Swift 6, strict concurrency on                                         | 0001 |
| UI framework     | AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI views (`MenuBarExtra` can't render a monospaced-digit label) | [0002](adr/0002-status-item-with-appkit.md) |
| Min. macOS       | macOS 15 (`@Observable`, `onKeyPress`, SwiftData, `SMAppService`)      | 0003 |
| State            | Pure, testable `TimerEngine` (value-type state + actions, clock injected) wrapped by an `@Observable @MainActor` model the UI binds to | 0004 |
| Time source      | Wall clock (`Date`) for deadlines; a single `Task.sleep` to the next instant the displayed second changes (50 ms tolerance), only to the phase end while the display is asleep or locked, none while not running; reset on `NSWorkspace.willSleepNotification` | 0005 |
| Signals          | `UNUserNotificationCenter` (silent) + `NSSound` with built-in system sounds | 0007 |
| Persistence      | None in MVP. `UserDefaults` for settings through a `Preferences` value type (v0.2); SwiftData for tasks & history (v0.4+) | [0008](adr/0008-settings-in-userdefaults-through-preferences.md) |
| Project layout   | One SwiftPM package built with Xcode: `BtmxFocusCore` library (engine), `BtmxFocusKit` library (app layer), `BtmxFocus` executable (AppKit wiring), `BtmxFocusUIContract` (accessibility ids, E2E launch arguments), `BtmxFocusDriver` + `focus-drive` (E2E driver, ADR 0010), tests; `scripts/build-app.sh` wraps the binary into a signed `.app`. No `.xcodeproj` | [0009](adr/0009-xcode-swift-testing-and-snapshot-tests.md) |
| Identity         | Product name `btmx-focus`; bundle id proposal `com.btmx.focus`          | — |
| Tests            | Swift Testing (`@Test`) with a fake clock for the engine and app layer; swift-snapshot-testing for views and the status item; see [testing.md](testing.md) | [0009](adr/0009-xcode-swift-testing-and-snapshot-tests.md) |
| E2E tests        | The bundled E2E build driven through Accessibility and real `CGEvent` input (`scripts/e2e.sh`, `focus-drive`) | [0010](adr/0010-e2e-tests-through-accessibility-and-real-input.md) |
| Lint / format    | SwiftLint + SwiftFormat (installed via Homebrew), run in a pre-commit hook / CI | — |
| Build            | `swift build` / `swift test`; see [building.md](building.md)           | — |
| Icons            | SF Symbols (SF Symbols app installed for browsing)                     | — |
| Distribution     | MVP: local build, ad-hoc signed. Later: Developer ID + notarization, possibly Mac App Store | later |

Build and launch instructions: [`docs/building.md`](building.md). The
package needs Xcode.

### 5.1 Core module sketch — **MVP**

```swift
enum Phase { case focus, rest }

enum TimerState {
    case ready(Phase)
    case running(Phase, endDate: Date)
    case paused(Phase, remaining: Duration)
}

struct Schedule { var focus: Duration; var rest: Duration }   // MVP: 30 min / 5 min

enum TimerEvent { case phaseCompleted(Phase) }               // drives notification + sound

struct TimerEngine {
    private(set) var state: TimerState
    let schedule: Schedule

    mutating func play(now: Date)
    mutating func pause(now: Date)
    mutating func skip()
    mutating func reset()                       // also used on system sleep
    mutating func tick(now: Date) -> TimerEvent?  // completes the phase once endDate is reached
    func remaining(at now: Date) -> Duration
}
```

Everything time-dependent takes `now` as a parameter, so tests never sleep.
Side effects (notification, sound, icon) live in the app layer and react to
`TimerEvent`; the engine stays pure.

---

## 6. Full feature roadmap

Features observed in the reference app (`sources/*.png`) plus our own ideas,
grouped by release. Anything not marked MVP is explicitly **not** in the MVP.

### 6.1 Timer & cycle

| Feature                                                   | Release |
| --------------------------------------------------------- | ------- |
| Fixed 30 / 5 cycle, user presses Play for each phase       | **MVP** |
| Play / pause / skip / reset                                | **MVP** |
| Deadline-based timing; reset on system sleep               | **MVP** |
| Configurable focus and rest durations                      | v0.2 |
| Long break (e.g. 15 min every 4 focus intervals)           | v0.2 |
| Option: auto-start next phase (default off)                | v0.2 |
| Daily target (e.g. 10 focus intervals), "Today n/10"       | v0.2 |
| Option: sleep behaviour (reset / pause / keep counting)    | v0.2 |
| Skip break if user was idle (idle detection)               | v0.2 |
| Persist timer across app relaunch                          | v0.2 |
| Activity types with their own interval settings            | Later |

### 6.2 Menu bar & UI

| Feature                                                   | Release |
| --------------------------------------------------------- | ------- |
| Phase icon + `mm:ss` in menu bar                           | **MVP** |
| Popover: phase, large time, Play/Pause under it, Skip, Reset, Quit | **MVP** |
| Option to hide the time and show icon only                 | v0.2 |
| Coloured icon while running: red Focus, green Rest (`sources/tray_icon_duiring_session.png`) | **MVP** |
| Progress-ring icon while running                           | v0.2 |
| Circular progress ring with drag handle in popover (`sources/main.png`) | v0.2 |
| Appearance override (Auto / Light / Dark)                  | Later |

### 6.3 Notifications & sounds

| Feature                                                   | Release |
| --------------------------------------------------------- | ------- |
| System notification at end of focus / rest                 | **MVP** |
| Fixed built-in sound at end of focus / rest                | **MVP** |
| "Start" action button on the notification                  | v0.2 |
| Toggle notifications on/off                                | v0.2 |
| Choose phase-end sounds (separate for focus end / break end) | v0.3 |
| Notification sound volume                                  | v0.3 |
| Sound feedback on shortcut                                 | v0.3 |
| Ticking "chronometer" sound, frequency, volume, on/off during break | v0.3 |

### 6.4 System integration

| Feature                                                   | Release |
| --------------------------------------------------------- | ------- |
| Settings window (General / Intervals / Notifications & Sounds) | v0.2 |
| Launch at login (`SMAppService`)                           | v0.2 |
| Global shortcuts: start/pause, skip                        | v0.2 |
| About panel                                                | v0.2 |
| Set a macOS Focus mode during focus phase                  | Later |
| Automation: Shortcuts app actions / App Intents, URL scheme| Later |
| Blocking distracting apps & sites                          | Later |

### 6.5 Tasks — v0.4

Based on `sources/tasklist*.png`:

- To Do / Done lists, search, add task, complete task.
- Task fields: title, notes, due date, estimated intervals, completed intervals.
- Pick the current task before / while focusing; completed focus intervals are
  credited to it. Fallback bucket "Other" (toggleable).
- Per-task interval history (start date/time, duration), editable.
- Starred / favourite tasks.

### 6.6 Reports — v0.5

Based on `sources/reports*.png`:

- Summary: work intervals, skipped work intervals, completed tasks, total
  duration, estimation error.
- Bar chart per day with daily-target line; pie chart by task (Swift Charts).
- Filters: period presets, custom start/end date, units (intervals / hours),
  task filter.

### 6.7 Later / Never

| Feature                                   | Release |
| ----------------------------------------- | ------- |
| iCloud sync between Macs                  | Later |
| Export history (CSV)                      | Later |
| iOS / watchOS companion                   | Later |
| Cross-promotion ad banners                | **Never** |
| "Upgrade to Pro" upsell inside core flows | **Never** (monetization TBD separately) |

---

## 7. MVP acceptance criteria

1. Launching the app shows a menu-bar item with the Focus icon only (no
   time), and no Dock icon.
2. Clicking the item opens a popover showing "Focus", `30:00` and a Play
   button under the time.
3. Play → menu bar and popover count down every second; digits don't shift
   the menu-bar item width; the button becomes Pause.
4. Pause freezes the time; Play continues from the frozen value.
5. At `00:00` of Focus: a notification appears, the Glass sound plays, and
   the app shows Ready(Rest) `05:00` with Play — the countdown does **not**
   continue on its own. Same for Rest → Ready(Focus) `30:00` with the Hero
   sound.
6. With notifications denied, the sound still plays and the timer still
   switches phase.
7. Skip moves to the other phase in Ready state at full duration, with no
   notification or sound.
8. Reset returns to Ready(Focus) `30:00`.
9. Putting the Mac to sleep (in any state) and waking shows Ready(Focus)
   `30:00`, with no notification or sound.
10. Over a 2-hour run (screen awake) the displayed time drifts < 1 s from
    wall-clock.
11. Ready and Paused states cause no periodic CPU wake-ups (verify in
    Activity Monitor / Instruments).
12. VoiceOver reads the phase, state and remaining time.
13. Unit and snapshot tests pass via `swift test`; SwiftLint and SwiftFormat report
    no violations.

---

## 8. Decisions & open questions

| #  | Question                                                   | Decision |
| -- | ---------------------------------------------------------- | -------- |
| D1 | Auto-advance to next phase?                                | **No.** Next phase loads and waits for Play. Auto-start becomes a v0.2 option. |
| D2 | Behaviour on system sleep                                  | **Reset** to Ready(Focus). Configurable in v0.2. |
| D3 | Minimum macOS version                                      | **macOS 15.** |
| D4 | End-of-phase signal in MVP                                 | **Icon change + notification + built-in system sound.** Sound choice deferred to v0.3. |
| D5 | App name                                                   | **btmx-focus** (avoids clash with the macOS "Focus" feature). Repo rename pending. |
| Q1 | Distribution channel (Mac App Store vs. Developer ID)       | Open — decide before v0.2; keep sandbox on so both stay possible. |
| Q2 | Final SF Symbols and system sounds                         | Open — pick during implementation; Glass / Hero are placeholders. |
