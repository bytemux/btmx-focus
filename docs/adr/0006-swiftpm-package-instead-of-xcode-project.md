# 0006. SwiftPM package instead of an Xcode project

Status: Superseded by 0009
Date: 2026-10-31

## Context

The spec proposed an Xcode app target plus a local Swift package for the
engine. A hand-maintained `.xcodeproj` is hard to review in diffs and
requires full Xcode to build. The MVP needs no asset catalogs, storyboards
or extensions.

## Decision

Keep everything in one SwiftPM package:

- `BtmxFocusCore`: the pure engine library, tested with Swift Testing.
- `BtmxFocus`: the executable app.

`scripts/build-app.sh` builds the executable and assembles
`build/btmx-focus.app` with `Support/Info.plist` (`LSUIElement`, bundle id
`com.btmx.focus`) and `Support/btmx-focus.entitlements` (App Sandbox), then
ad-hoc signs it with the hardened runtime.

## Consequences

- Builds with either the Command Line Tools or Xcode; `open Package.swift`
  still gives an Xcode editing and debugging experience.
- Running from Xcode or `swift run` isn't bundled, so features that need a
  bundle (notifications) are turned off there; test them with the script.
- Developer ID signing, notarization, an app icon or extensions will need
  either more script steps or an Xcode project (e.g. generated with
  XcodeGen or Tuist). We'll revisit this before distribution (#26).
