# 0013. No network, sandboxed, no ads or upsells

Status: Accepted
Date: 2026-11-02

## Context

The reference app we draw on shows cross-promotion banners and "Upgrade to
Pro" prompts inside core flows. A focus timer that interrupts focus works
against itself. Distribution (Mac App Store vs. Developer ID) is still
open.

## Decision

- No network access and no analytics; nothing leaves the Mac.
- App Sandbox on, so both distribution channels stay possible.
- Never: ad banners, cross-promotion, or upsells inside core flows. How the
  app is paid for, if at all, is decided separately.

## Consequences

- Features that need the network (sync, update checks) need this ADR
  revisited first.
- Files live in the sandbox container, not `~/Library` directly.
