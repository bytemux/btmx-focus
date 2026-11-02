# 0004. Pure `TimerEngine` wrapped by an `@Observable` model

Status: Accepted
Date: 2026-11-02

## Context

The timer's rules (phase transitions, remaining time, phase end) are the
product. They depend on time, and tests that wait for real time are slow
and flaky. Side effects (sound, notification, icon) must not leak into the
rules.

## Decision

- `TimerEngine` in `BtmxFocusCore` is a value type: state plus actions
  (`play`, `pause`, `skip`, `reset`, `tick`). Every time-dependent call
  takes `now`, so the engine never reads the clock. A phase end returns a
  `TimerEvent` instead of doing anything.
- `TimerModel` in `BtmxFocusKit`, `@Observable @MainActor`, owns the
  engine, an injected `TimerClock` and a `PhaseSignalSink`. It schedules
  ticks, observes system events and turns `TimerEvent`s into the
  end-of-phase signal. The UI binds to it.

## Consequences

- Engine and model tests run with a fake clock and never sleep
  (`docs/testing.md`).
- Every new rule (long breaks, auto-start, idle skip) goes into the engine
  first, with its inputs passed in rather than read from the system.
