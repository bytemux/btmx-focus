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

## Change flow

When the user asks for changes in chat ("добавляем X и Y", "add X"), or
says `/implement` / "implement spec", go through these steps without
being asked for each one. Stop only at the plan approval (step 2).

1. **Look first.** Read the code, `GLOSSARY.md` and the ADRs the request
   touches. Don't change files yet.
2. **Plan for approval.** Present the plan (plan mode when available) and
   wait for a yes:
   - per item: what changes for the user, then the files and approach;
   - where the user asked for options (designs, icons) or a real choice
     exists: 2–3 variants with a recommended one;
   - decisions you'd make yourself (edge cases, behaviour the request
     doesn't cover), stated so the user can overrule them;
   - how it will be tested, and which PRs it becomes (see Pull requests:
     `feat`/`fix` separate from `docs`/`chore`).
   Answers like "yes", "да", "go" approve it; changes to the plan mean a
   revised plan, not a start.
3. **Branch from fresh main.** `git fetch origin`, then
   `git switch -c claude/<topic> origin/main` (works in a worktree too).
   A dirty working tree: `git stash push -u -m "<topic>-wip"` first
   (don't ask). One branch per PR; never stack PRs.
4. **Build and test.** Implement with unit tests; update `GLOSSARY.md`
   (and an ADR for a real decision) in the same change. Then
   `swift test`, `SNAPSHOT_RECORD=1 swift test` if the UI changed (open
   and look at every changed PNG, the README image included),
   `swiftformat . && swiftlint`, `scripts/build-app.sh`. All green
   before committing.
5. **Commit, push, PR.** Conventional commit and PR title (Pull requests
   below). If `git push` fails with "Permission denied (publickey)", push
   over HTTPS with the `gh` login:
   `git -c url."https://github.com/".insteadOf=git@github.com: push -u origin HEAD`.
   PR body: what changes, what to check by hand, tests. Ends with the
   attribution line.
6. **Review with a subagent.** Start a subagent (Agent tool) that runs the
   `code-review` skill as `/code-review low --comment --fix <PR number>`:
   it posts its findings as PR comments and applies the fixes. Then check
   its diff, run step 4's checks again, commit (`fix: address review` or
   similar) and push to the same PR.
7. **Report.** Summary first: what the user must do (merge, check by hand,
   choose), the PR links, what wasn't verified. Offer to launch the test
   build: quit the installed app first (`osascript -e 'quit app id
   "com.btmx.focus"'`, only one copy can run), then
   `open build/btmx-focus.app`. Before merging a `feat` or `fix` PR, offer
   to run the E2E suite (it takes the mouse; only on a yes).

Merging releases automatically (ADR 0017); the user merges.

## Pull requests

The PR title becomes the merge commit's title, and the Release workflow,
which runs on every merge to main, reads the version bump from it
(`docs/building.md` → Releasing). Start it with a conventional type:
`feat:` or `fix:` (minor), `type!:` (major), `perf:`, `refactor:` or
`revert:` (patch), `docs:`, `chore:`, `ci:`, `test:`, `style:` or `build:`
(no release). A title with no type fails the PR title check (ADR 0018).

Don't stack PRs (base one PR on another's branch): if the base merges
first, the stacked one merges into that branch and never reaches main.

## Testing the UI

`swift test` always. The E2E suite (`scripts/e2e.sh`) and `focus-drive`
take over the user's mouse and keyboard, so run them **only when the user
asks** (typically before a release), and say so before starting. Afterwards
review the screenshots it saves (`build/e2e/<timestamp>/`). To look at the
running UI, use `focus-drive`. Otherwise verify with `swift test`, a clean
build and the logs, and tell the user what to check by hand
(`docs/building.md`).

A popover change also changes the README image
(`docs/images/readme.popover.png`): it's a snapshot, re-recorded with the
others; commit it with the change.

The E2E suite covers the critical path only (ADR 0010): extend its two
flows, and cover buttons and edge cases in unit or snapshot tests.

## Agent skills

### Issue tracker

GitHub Issues in `bytemux/btmx-focus`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
