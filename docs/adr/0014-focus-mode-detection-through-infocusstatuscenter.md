# 0014. Focus mode detection through `INFocusStatusCenter`

Status: Accepted
Date: 2026-11-02

## Context

The app plays the end-of-phase sound itself (ADR 0007), so it plays under
Do Not Disturb and Focus modes. Silent during Focus needs to know whether a
Focus mode (Do Not Disturb is one) is on. The app is sandboxed (ADR 0013).
Options on macOS 15+:

- `INFocusStatusCenter` (Intents): the only public API. Needs the
  Communication Notifications entitlement (a provisioning profile; ad-hoc
  signing can't carry it) and a one-time user permission. Without either,
  the status is unknown.
- Reading `~/Library/DoNotDisturb/DB/*.json`: blocked by the sandbox and by
  Full Disk Access, undocumented.
- Old `com.apple.notificationcenterui` defaults and distributed
  notifications: gone since macOS 12; sandboxed apps get no payload anyway.
- Private `DoNotDisturb.framework`: private API, breaks between releases.
- Letting the notification carry the sound (the system silences it under a
  Focus): needs no extra permission, but loses the volume setting and goes
  silent whenever notifications are off or denied, which ADR 0007 rejected.

## Decision

- Read the status through `INFocusStatusCenter`, behind `FocusStatusSource`
  (`SystemFocusStatus` in the app, a fake in tests).
- Ask for the Focus status permission only when the user turns Silent
  during Focus on, never at launch. `NSFocusStatusUsageDescription` is in
  `Info.plist`.
- The decision is pure: `Preferences.endSound(after:focusActive:)`. An
  unknown status (no permission, no entitlement) plays the sound; the end of
  a phase must be noticed.
- The option is off by default, so ADR 0007's behaviour is unchanged until
  the user opts in.

## Consequences

- The Communication Notifications entitlement is not in
  `btmx-focus.entitlements` yet: an ad-hoc-signed app with it won't launch.
  Until the app is signed with a provisioning profile that grants it (App
  Store or Developer ID, to be confirmed in the developer portal), the
  option has no effect and the sound always plays.
- Only the sound is affected; the notification is already held back by the
  system under a Focus.
