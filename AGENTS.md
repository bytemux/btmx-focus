# btmx-focus

Native macOS menu-bar focus timer. Language: `GLOSSARY.md`. Decisions:
`docs/adr/`. Planned work: GitHub Issues.
Build, run, logs: `docs/building.md`. Tests: `docs/testing.md`.

## Commands

Run `swift test` after every change.

```sh
swift test                                   # unit + snapshot tests
SNAPSHOT_RECORD=1 swift test                 # re-record snapshots
scripts/e2e.sh                               # E2E: only when the user asks (takes the mouse)
scripts/build-app.sh && open build/btmx-focus.app
swiftformat . && swiftlint
```

Requires Xcode with its license accepted, plus SwiftLint and SwiftFormat. If
a command fails because one is missing or the license isn't accepted, stop
and tell the user; don't work around it.

## Testing the UI

`swift test` always. The E2E suite (`scripts/e2e.sh`) and `focus-drive`
take over the user's mouse and keyboard, so run them **only when the user
asks** (typically before a release), and say so before starting. Afterwards
review the screenshots it saves (`build/e2e/<timestamp>/`). To look at the
running UI, use `focus-drive`. Otherwise verify with `swift test`, a clean
build and the logs, and tell the user what to check by hand
(`docs/building.md`).

The E2E suite covers the critical path only (ADR 0010): extend its two
flows, and cover buttons and edge cases in unit or snapshot tests.

## Agent skills

### Issue tracker

GitHub Issues in `bytemux/btmx-focus`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
