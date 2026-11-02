# 0001. Swift 6 with strict concurrency

Status: Accepted
Date: 2026-11-02

## Context

The app mixes the main thread (AppKit, SwiftUI), a timer task and system
callbacks that arrive on other queues (notifications, sleep, fatal signals).
Data races there would show up as rare, hard-to-reproduce bugs.

## Decision

Swift 6 language mode with strict concurrency checking, in every target.
UI and app-layer types are `@MainActor`; core types are `Sendable` values.

## Consequences

- Races are compile errors, and Swift 6 traps at runtime when a callback
  runs on the wrong actor. Some system APIs need care: e.g. the async
  `requestAuthorization` instead of a completion handler that would be
  main-actor isolated (`PhaseSignaler`).
- Dependencies must build under Swift 6 strict concurrency.
