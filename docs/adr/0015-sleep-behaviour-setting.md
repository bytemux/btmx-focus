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
  `NSWorkspace.didWakeNotification` (and at any tick) the model catches up
  with every deadline that has passed:
  - Each passed phase is completed in order, exactly as if the Mac had
    been awake: the long-break cycle advances, Idle skip applies (using
    the idle time read at wake) and each phase end is logged. A Focus that
    ended while asleep does **not** count towards the daily tally: nobody
    worked it.
  - Only the **latest** phase end is signalled: one sound, one banner,
    describing the phase that is now Ready (or, with Auto-start, already
    Running with part of its time gone).

The rule lives in `TimerEngine.systemWillSleep(now:)` (per
`TimerEngine.sleepBehaviour`) and in `TimerModel.tick()`, which completes
all passed deadlines but signals once. The same coalescing applies to a
manual clock jump past several deadlines.

## Consequences

- ADR 0005's deadline-based timing still holds; its sleep-reset decision
  is now just the default (0005 is amended, not superseded).
- With Keep counting and Auto-start, a long sleep advances the cycle
  (the literal meaning of "keep counting") but leaves "Today" as it was.
  The model knows a phase ended while asleep because it completed it
  between `willSleep` and the catch-up at `didWake`, whichever tick runs
  first after wake.
- Whether `CGEventSource` idle time includes the time asleep decides
  whether Idle skip fires for a Focus that ended while asleep; that is a
  manual check, not something the tests can see.
- Pause and Keep counting changes take effect at the next sleep.
