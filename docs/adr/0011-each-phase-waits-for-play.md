# 0011. Each phase waits for Play

Status: Accepted
Date: 2026-11-02

## Context

Most focus timers run the next phase as soon as one ends. That keeps the
rhythm, but a break that starts while the user is mid-thought, or a Focus
that starts while they're away, is time that didn't happen as counted.

## Decision

At phase end the next phase is loaded Ready at full length and waits for
Play. The app never starts a phase on its own. Auto-start is a later
opt-in Setting (off by default), not the default behaviour.

## Consequences

- Every Focus interval was started deliberately.
- The deadline is the phase end, not a cycle-wide schedule: the time
  between phase end and Play is untracked.
- Auto-start (Settings → General, #6) runs the next phase from the
  previous deadline, not from "now", so with it on the deadlines form a
  fixed rhythm. Idle skip reads the system idle time
  (`CGEventSource`, no permission) only at a Focus phase end.
