# 0015. Sleep behaviour setting: reset, pause or keep counting

Status: Accepted
Date: 2026-11-02

## Context

ADR 0005 resets the timer to Ready Focus whenever the Mac goes to sleep.
That is safe, but it loses the phase in progress: closing the lid for a
few minutes in the middle of a Focus phase throws it away. Some users want
the phase to wait; others want the timer to track wall-clock time, as if
the Mac had stayed awake.

Keeping the deadline through a sleep means several deadlines can pass
before the Mac wakes: one without Auto-start (the phase ends and the next
waits for Play), any number with Auto-start (each next phase runs from the
previous deadline, ADR 0011). Signalling each of them would play a burst
of sounds and banners at wake.

## Decision

A Setting "When the Mac sleeps" (Settings → General, `sleepBehaviour`)
chooses what happens at `NSWorkspace.willSleepNotification`:

- **Reset** (default): the sleep reset of ADR 0005, unchanged.
- **Pause**: a Running phase is paused with its remaining time; a Ready
  or Paused one is untouched. Waking doesn't resume it; the user presses
  Play.
- **Keep counting**: nothing happens at sleep; the deadline stands. At
  `NSWorkspace.didWakeNotification` (or whichever tick runs first after
  wake) the model completes the phase whose deadline passed while asleep,
  as one the user was away for:
  - The sleep counts as idle time, so with Idle skip a Focus that ended
    during a sleep at least as long as the break skips the break.
  - The next phase waits for Play, even with Auto-start: the user wakes
    to a Ready phase (Focus, after a break or a skipped one), never to
    one that has been running unattended.
  - A Focus that ended while asleep does **not** count towards the daily
    tally: nobody worked it. The long-break cycle still advances.
  - The phase end is signalled once, at wake.

The rule lives in `TimerEngine.systemWillSleep(now:)` (per
`TimerEngine.sleepBehaviour`), `TimerEngine.tick(endedWhileAsleep:)` and
`TimerModel.tick()`. The model knows a phase ended while asleep because it
completed it between `willSleep` and the catch-up at `didWake`. A manual
clock jump past several Auto-started deadlines completes each of them but
signals only the latest.

## Consequences

- ADR 0005's deadline-based timing still holds; its sleep-reset decision
  is now just the default (0005 is amended, not superseded).
- Keep counting with Auto-start completes at most one phase per sleep:
  the next waits for Play, so a long sleep can't run through the cycle or
  fill "Today".
- The idle time used is the longer of `CGEventSource`'s and the time since
  `willSleep`, so Idle skip doesn't depend on whether the system counts
  sleep as idle.
- Pause and Keep counting changes take effect at the next sleep.
