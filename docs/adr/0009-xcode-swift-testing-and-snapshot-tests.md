# 0009. SwiftPM package built with Xcode; Swift Testing + snapshot tests

Status: Accepted
Date: 2026-11-02

Supersedes 0006.

## Context

ADR 0006 kept everything in one SwiftPM package and let it build with either
Xcode or the Command Line Tools, so contributors without full Xcode (or
without its license accepted) could still build and test.

Routine changes should be verified without opening the app, which means
testing the app layer and its look, not just the engine. Snapshot tests use
Point-Free's swift-snapshot-testing, which builds on XCTest; the Command Line
Tools ship Swift Testing but not XCTest. Supporting both toolchains would
mean either skipping snapshots on one of them or maintaining our own
snapshot library.

## Decision

- One SwiftPM package, no `.xcodeproj` (unchanged from 0006):
  - `BtmxFocusCore`: the pure engine.
  - `BtmxFocusKit`: the app layer (models, views, status-item presentation).
  - `BtmxFocus`: the executable, thin AppKit wiring only.
  - `BtmxFocusTestSupport`: fakes shared by the test targets.
- `scripts/build-app.sh` builds the executable and assembles
  `build/btmx-focus.app` with `Support/Info.plist` (`LSUIElement`, bundle id
  `com.btmx.focus`) and `Support/btmx-focus.entitlements` (App Sandbox), then
  ad-hoc signs it with the hardened runtime.
- Xcode (with its license accepted) is required. The Command Line Tools
  alone are not supported. A missing tool or unaccepted license fails with
  the tool's own message; there is no fallback.
- `swift test` is the one test command and always includes the snapshot
  tests, which need XCTest (only Xcode ships it). That is why Xcode is
  required. Running the unit tests without the snapshots on the Command Line
  Tools was rejected: a suite that silently skips part of itself on some
  machines isn't the suite.
- Tests are written in Swift Testing. Views and the status item are covered
  by swift-snapshot-testing (test-only dependency) with committed reference
  images; see `docs/testing.md`.

## Consequences

- `swift test` runs everything, snapshots included, on any machine with
  Xcode; there is one toolchain to support.
- Contributors need full Xcode installed and its license accepted.
- `open Package.swift` still gives an Xcode editing and debugging
  experience. Running from Xcode or `swift run` isn't bundled, so features
  that need a bundle (notifications) are turned off there; test them with
  the script.
- Snapshot references are recorded on macOS 27, light appearance only, with
  no CI; they must be re-recorded after macOS updates
  (`SNAPSHOT_RECORD=1 swift test`).
- Developer ID signing, notarization, an app icon or extensions will need
  either more script steps or an Xcode project (e.g. generated with XcodeGen
  or Tuist). We'll revisit this before distribution (#26).
