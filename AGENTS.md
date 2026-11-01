# btmx-focus

Native macOS menu-bar focus timer. Spec: `docs/spec.md`. ADRs: `docs/adr/`.
Build, run, logs: `docs/building.md`. Tests: `docs/testing.md`.

## Commands

Run `swift test` after every change.

```sh
swift test                                   # unit + snapshot tests
SNAPSHOT_RECORD=1 swift test                 # re-record snapshots
scripts/build-app.sh && open build/btmx-focus.app
swiftformat . && swiftlint
```

Requires Xcode with its license accepted, plus SwiftLint and SwiftFormat. If
a command fails because one is missing or the license isn't accepted, stop
and tell the user; don't work around it.

## Testing the UI

Do not use computer use, screenshots or screen recording. Verify what you
can with `swift test` (including the snapshot tests), a clean build and the
logs (`crash-*.log`, and `breadcrumbs.log` with Debug Logging on). Then hand
over to the user, who tests the UI by hand, and say what to look for.

## Agent skills

### Issue tracker

GitHub Issues in `bytemux/btmx-focus`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
