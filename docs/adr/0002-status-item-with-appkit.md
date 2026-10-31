# 0002. Status item with AppKit, popover content in SwiftUI

Status: Accepted
Date: 2026-10-31

## Context

The menu-bar label shows a live `mm:ss` countdown. The spec requires
monospaced digits so the status item doesn't change width every second, and
an icon that changes with the timer state. SwiftUI's `MenuBarExtra` renders
its label through the system and ignores most font modifiers, including
`monospacedDigit()`.

## Decision

Use `NSStatusItem` directly. Set its button's `attributedTitle` with
`NSFont.monospacedDigitSystemFont` and a template SF Symbol image. Clicking
it toggles a transient `NSPopover` whose content is a SwiftUI view hosted in
`NSHostingController`. The status item redraws from the `@Observable` model
using `withObservationTracking`.

## Consequences

- Full control over the label font, image and accessibility label.
- The app has a custom `@main` that runs `NSApplication` instead of a
  SwiftUI `App`; adding SwiftUI scenes (e.g. a Settings window in v0.2)
  means either opening AppKit windows or moving to a SwiftUI `App` with
  an app-delegate adaptor.
- Popover views stay in SwiftUI, so most UI work is unaffected.
