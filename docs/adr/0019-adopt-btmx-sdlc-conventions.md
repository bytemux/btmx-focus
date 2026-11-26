# 0019. Adopt btmx-sdlc conventions; SemVer with `fix` → patch

Status: Accepted
Date: 2026-11-26

## Context

btmx-sdlc (`bytemux/btmx-sdlc`) holds the shared conventions for issues,
branches, commits and PRs, and the `init-repo` skill that sets them up in
a repo. Its release CI and versioning rules come from this repo
(ADR 0017, 0018). btmx-focus didn't follow the rest: branches
`claude/<topic>` without an issue, merge commits, no pre-commit hooks, and
`fix` released a minor version, which SemVer gives to new features only.

## Decision

- Follow btmx-sdlc `docs/conventions.md`: issue types `Story`, `Task`,
  `Bug`, `Spike`; every change has an issue; branch `<type>/<n>-<slug>`
  from `gh issue develop`; PRs through skill:pr; squash merge only, the
  squash commit is the PR title + `(#PR)` and the PR body.
- pre-commit hooks (`.pre-commit-config.yaml`) check the commit message
  and the branch name and block commits on main.
- The version script moves from `release.yml` to `scripts/next-version.sh`,
  a copy of btmx-sdlc's, which has its tests. Versions follow SemVer:
  `fix` is a **patch** now (was minor); the rest of ADR 0018 stays.
- The PR title check is the btmx-sdlc `pr-title.yml`; the required check on
  main is `pr-title` (was `Conventional type`).

## Consequences

- A fix-only merge releases `x.y.(z+1)` instead of `x.(y+1).0`.
- A change starts with an issue; Spec issues are Stories and tickets are
  Tasks (`docs/agents/issue-tracker.md`).
- `next-version.sh` and `pr-title.yml` are copies: change them in
  btmx-sdlc first, then copy them here.
- Merge commits already on main are still read by the script.
