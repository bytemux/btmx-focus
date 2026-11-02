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

## Index

Taken from [spec §5](../spec.md#5-technical-approach):

| #    | Topic                                                  | Status  |
| ---- | ------------------------------------------------------ | ------- |
| 0001 | Swift 6 with strict concurrency                         | Planned |
| [0002](0002-status-item-with-appkit.md) | Status item with AppKit, popover content in SwiftUI | Accepted |
| 0003 | Minimum macOS version: 15                               | Planned |
| 0004 | Pure `TimerEngine` + `@Observable` model                | Planned |
| 0005 | Deadline-based timing; reset on system sleep            | Planned |
| [0006](0006-swiftpm-package-instead-of-xcode-project.md) | SwiftPM package instead of an Xcode project | Superseded by 0009 |
| 0007 | End-of-phase signals: notification + `NSSound`          | Planned |
| [0008](0008-settings-in-userdefaults-through-preferences.md) | Settings in `UserDefaults` through `Preferences` | Accepted |
| [0009](0009-xcode-swift-testing-and-snapshot-tests.md) | SwiftPM package built with Xcode; Swift Testing + snapshot tests | Accepted |
| [0010](0010-e2e-tests-through-accessibility-and-real-input.md) | E2E tests drive the bundled app through Accessibility and real input | Accepted |
