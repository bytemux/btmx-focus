# 0007. End-of-phase signal: app-played sound, silent notification

Status: Accepted
Date: 2026-11-02

## Context

At phase end the user must notice, even if notifications are denied, muted
or hidden by a macOS Focus mode. A sound attached to the notification is
lost whenever the notification is.

## Decision

- The app plays a built-in system sound itself with `NSSound` (Glass after
  Focus, Hero after Rest), and posts the `UserNotifications` banner
  without a sound, so there's never a double sound.
- Notification permission is requested on the first Play, not at launch;
  if denied, everything else still works.
- The menu-bar icon switches to the next phase's Ready icon.
- Skip, Reset and the sleep reset never signal.
- The app doesn't try to bypass Do Not Disturb or Focus modes for the
  notification.

## Consequences

- The sound plays even under Do Not Disturb. Whether it should respect it
  is a later option.
- Banners show while the popover has made the app active (a foreground
  notification delegate).
