# btmx-focus

Native macOS menu-bar focus timer. Spec: `docs/spec.md`. ADRs: `docs/adr/`.
Build, run, logs: `docs/building.md`. Tests: `docs/testing.md`.

## Commands

Run `swift test` after every change.

```sh
swift test                                   # unit + snapshot tests
SNAPSHOT_RECORD=1 swift test                 # re-record snapshots
scripts/e2e.sh                               # E2E: drives the real app (takes the mouse)
scripts/build-app.sh && open build/btmx-focus.app
swiftformat . && swiftlint
```

Requires Xcode with its license accepted, plus SwiftLint and SwiftFormat. If
a command fails because one is missing or the license isn't accepted, stop
and tell the user; don't work around it.

## Testing the UI

`swift test` always. After UI changes (status item, popover, menus,
Settings, focus) also run `scripts/e2e.sh`, but warn the user first: it
takes over the mouse and keyboard for about a minute. Then review the
screenshots it saves (`build/e2e/<timestamp>/`). To explore the running UI,
use `swift run focus-drive` (`tree`, `click`, `key`, `shot`), not computer
use. See `docs/testing.md`. Only real sleep, the notification banner and
prompt, and the sounds still need the user (`docs/building.md`).

## Agent skills

### Issue tracker

GitHub Issues in `bytemux/btmx-focus`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
