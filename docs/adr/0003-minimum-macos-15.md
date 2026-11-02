# 0003. Minimum macOS version: 15

Status: Accepted
Date: 2026-11-02

## Context

The app is new and has no users on older systems. Supporting older macOS
versions costs availability checks and fallbacks for the APIs we rely on.

## Decision

Require macOS 15 (`platforms: [.macOS(.v15)]`). Everything we use or plan
to use is available without availability checks: `@Observable`,
`onKeyPress`, `SMAppService` (launch at login), SwiftData (tasks and
reports).

## Consequences

- No `#available` branches.
- Users on macOS 14 and older can't run the app.
