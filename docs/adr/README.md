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

| #    | Topic                                                  | Status  |
| ---- | ------------------------------------------------------ | ------- |
| [0001](0001-swift-6-strict-concurrency.md) | Swift 6 with strict concurrency | Accepted |
| [0002](0002-status-item-with-appkit.md) | Status item with AppKit, popover content in SwiftUI | Accepted |
| [0003](0003-minimum-macos-15.md) | Minimum macOS version: 15 | Accepted |
| [0004](0004-pure-timer-engine-and-observable-model.md) | Pure `TimerEngine` wrapped by an `@Observable` model | Accepted |
| [0005](0005-deadline-based-timing-and-sleep-reset.md) | Deadline-based timing; reset on system sleep | Accepted, amended by 0015 |
| [0006](0006-swiftpm-package-instead-of-xcode-project.md) | SwiftPM package instead of an Xcode project | Superseded by 0009 |
| [0007](0007-end-of-phase-signal-app-sound-silent-notification.md) | End-of-phase signal: app-played sound, silent notification | Accepted |
| [0008](0008-settings-in-userdefaults-through-preferences.md) | Settings in `UserDefaults` through `Preferences` | Accepted |
| [0009](0009-xcode-swift-testing-and-snapshot-tests.md) | SwiftPM package built with Xcode; Swift Testing + snapshot tests | Accepted |
| [0010](0010-e2e-tests-through-accessibility-and-real-input.md) | E2E tests drive the bundled app through Accessibility and real input | Accepted |
| [0011](0011-each-phase-waits-for-play.md) | Each phase waits for Play | Accepted |
| [0012](0012-diagnostics-without-disk-writes.md) | Diagnostics without disk writes in normal use | Accepted |
| [0013](0013-no-network-sandboxed-no-ads.md) | No network, sandboxed, no ads or upsells | Accepted |
| [0014](0014-focus-mode-detection-through-infocusstatuscenter.md) | Focus mode detection through `INFocusStatusCenter` | Accepted |
| [0015](0015-sleep-behaviour-setting.md) | Sleep behaviour setting: reset, pause or keep counting | Accepted |
| [0016](0016-unsigned-releases-through-own-homebrew-tap.md) | Unsigned releases through our own Homebrew tap | Accepted |
