# 0012. Diagnostics without disk writes in normal use

Status: Accepted
Date: 2026-11-02

## Context

A timer runs all day, so a crash report should say what the user did last.
Logging every action to disk all day costs writes and disk space for a
problem that is rare.

## Decision

- The last 50 recent actions (user actions and system events, each with
  the state before → after) stay in memory, mirrored to the unified log
  (subsystem `com.btmx.focus`, not persisted by default).
- Fatal signals, including Swift runtime traps, write the crash reason, the
  last user action and the recent actions to a crash file, then let the
  process crash so macOS still writes its `.ips` report. The next launch
  names it `crash-<date>.log` and keeps the 5 newest.
- Debug Logging (More menu, off by default) also appends every action to
  `breadcrumbs.log`, rotated at 512 KB with one previous file kept (at most
  1 MB).
- Logs stay on the Mac, in the sandbox container's
  `Library/Logs/btmx-focus/`; "Show Logs in Finder" opens it.

## Consequences

- The crash handler may only touch pre-rendered bytes and file descriptors
  (`CrashLog`), so recent actions are rendered as text when recorded.
- Diagnosing a non-crash bug needs Debug Logging on, or the unified log.
