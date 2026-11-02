# btmx-focus

A macOS menu-bar timer that keeps the user in a rhythm of Focus and Rest,
one click away.

## Timer

**Phase**:
One stretch of the cycle: Focus, Rest or a Long break.
_Avoid_: session, pomodoro, round

**Focus**:
The working phase, 30 minutes by default.
_Avoid_: work, work session, work interval

**Rest**:
The regular break after Focus, 5 minutes by default.
_Avoid_: short break (Settings label only), pause

**Long break**:
A longer break that replaces Rest after a set number of Focus intervals.
_Avoid_: big break

**Break**:
Either Rest or a Long break, when the difference doesn't matter.

**Focus interval**:
A Focus phase that reached its phase end; skipped Focus phases don't count.
_Avoid_: pomodoro, completed session

**Cycle**:
The repeating sequence of phases: Focus, Rest, Focus, … with a Long break in
place of Rest every few Focus intervals.

**Schedule**:
The length of each phase.
_Avoid_: durations, config

**Ready**:
The state of a phase loaded at full length and waiting for Play.
_Avoid_: idle, stopped

**Running**:
The state of a phase counting down to its deadline.
_Avoid_: active, ticking

**Paused**:
The state of a phase stopped part-way, keeping its remaining time.

**Deadline**:
The instant a Running phase ends.
_Avoid_: end time, alarm time

**Remaining time**:
How long is left of the current phase, shown rounded up to the whole second.

**Progress ring**:
A circle that empties clockwise from 12 o'clock as the remaining time runs
down: behind the phase name, clock and Play/Pause in the popover, and as the
menu-bar icon while Running.
Purely visual; it can't be dragged.
_Avoid_: progress bar, dial

**Phase end**:
The moment a Running phase reaches its deadline; the next phase becomes Ready.
_Avoid_: timeout, completion

## Actions

**Play**:
Starts a Ready phase or resumes a Paused one.
_Avoid_: start, resume

**Pause**:
Stops a Running phase and keeps its remaining time.

**Skip**:
Moves to the next phase, Ready at full length, without an end-of-phase signal.
_Avoid_: next, advance

**Reset**:
Returns to Ready Focus at full length.
_Avoid_: stop, restart

**Sleep reset**:
The Reset the app performs when the Mac goes to sleep.

**Auto-start**:
An option under which the next phase starts Running at the previous phase's
deadline instead of waiting for Play.
_Avoid_: auto-advance, continuous mode

**Daily target**:
The number of Focus intervals the user aims for in a day, shown as
"Today n/target".
_Avoid_: goal, quota

**Daily tally**:
How many Focus intervals the user completed today (the n in "Today
n/target"). It starts again at local midnight and survives quit and relaunch.
_Avoid_: streak, score

## Signals

**End-of-phase signal**:
What tells the user a phase ended: the icon change, a notification and a
sound. Skip and Reset never give one.
_Avoid_: alarm, alert, chime

**Silent during Focus**:
The option (off by default) that drops the sound from the end-of-phase
signal while Do Not Disturb or another Focus mode is on. If the app can't
tell (no permission), the sound plays. Shown only in builds that can read
the Focus status.
_Avoid_: mute, quiet hours

## Interface

**Menu-bar item**:
The app's only permanent presence: a phase icon and, once a phase has
started, its remaining time. A click opens the popover; a right-click plays
or pauses.
_Avoid_: tray icon, status bar icon

**Popover**:
The small panel that opens from the menu-bar item, with the phase, the
remaining time and the timer controls.
_Avoid_: window, dropdown, main window

**More menu**:
The `⋯` menu in the popover, holding the app actions (Settings, Debug
Logging, Show Logs in Finder, Quit).
_Avoid_: overflow menu, gear menu

**Settings window**:
Where the user changes the schedule, signals and other options.
_Avoid_: preferences

**Appearance**:
Whether the popover and the Settings window follow the system's light or
dark mode (Auto, the default) or are forced Light or Dark. The menu-bar item
always follows the menu bar.
_Avoid_: theme, dark mode (for the setting)

**Focus mode**:
The macOS system feature that silences notifications. Not part of this app,
which is why the app is called btmx-focus and not Focus.
_Avoid_: using it for the Focus phase

## Diagnostics

**Recent actions**:
The last actions (user actions and system events, each with the state
before and after) the app keeps in memory for a crash file.
_Avoid_: history (reserved for reports), log

**Crash file**:
What the app leaves behind when it crashes: the crash reason, the last user
action and the recent actions.
_Avoid_: crash log (that's macOS's `.ips` report)

**Debug Logging**:
An opt-in diagnostic mode that also writes every action to disk.
_Avoid_: verbose mode, breadcrumbs (a single logged line is a breadcrumb)
