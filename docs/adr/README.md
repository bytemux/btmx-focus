# Architecture Decision Records

One file per decision: `NNNN-short-title.md`, numbered sequentially, never
renumbered. Superseded ADRs stay in place with their status updated.

## Template

```markdown
# NNNN. Title

Status: Proposed | Accepted | Superseded by NNNN
Date: YYYY-MM-DD

## Context
What forces are at play and why a decision is needed.

## Decision
What we chose.

## Consequences
What becomes easier or harder as a result.
```

## Planned

Taken from [spec §5](../spec.md#5-technical-approach):

| #    | Topic                                                  | Status  |
| ---- | ------------------------------------------------------ | ------- |
| 0001 | Swift 6 with strict concurrency                         | Planned |
| 0002 | SwiftUI `MenuBarExtra` (window style) for the popover   | Planned |
| 0003 | Minimum macOS version: 15                               | Planned |
| 0004 | Pure `TimerEngine` + `@Observable` model                | Planned |
| 0005 | Deadline-based timing; reset on system sleep            | Planned |
| 0006 | Xcode app + local `BtmxFocusCore` Swift package         | Planned |
| 0007 | End-of-phase signals: notification + `NSSound`          | Planned |
