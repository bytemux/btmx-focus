# 0005. Deadline-based timing; reset on system sleep

Status: Accepted (sleep reset amended by 0015: now the default of a Setting)
Date: 2026-11-02

## Context

A countdown that decrements on each tick drifts: ticks arrive late, get
coalesced, or stop while the Mac sleeps. The timer must show the right time
(within 1 s of the deadline, phase end within 1 s of it) without waking the
CPU more than needed: at most once a second while Running and never while
Ready or Paused, so the app never shows up under "Apps Using Significant
Energy".

## Decision

- A Running phase stores its absolute deadline (wall-clock `Date`); the
  remaining time is always derived as `deadline − now`, rounded up to the
  whole second, so `00:00` appears only at the deadline.
- One `Task.sleep` (50 ms tolerance) to the next instant the displayed
  second changes, which is also exactly when the phase ends. While the
  display is asleep or the screen is locked nobody sees the seconds, so it
  sleeps straight to the deadline. Nothing is scheduled unless Running.
- On `NSWorkspace.willSleepNotification` the timer does a sleep reset, to
  Ready Focus, whatever its state, with no end-of-phase signal. Display
  sleep and screen lock without system sleep don't reset.
- Only absolute instants are stored, so time-zone changes have no effect;
  on a manual clock change the model recomputes from the deadline (a jump
  forward past it ends the phase).

## Consequences

- A late or missed tick never causes drift.
- A Mac that sleeps through a phase doesn't come back to a stale or
  finished timer, but the user loses the phase in progress. ADR 0015 makes
  this the default of "When the Mac sleeps" (reset / pause / keep counting).
