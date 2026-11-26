# 0018. Only typed commits release; PR titles are checked

Status: Accepted
Date: 2026-11-25

## Context

ADR 0017 releases on every push to main and counts a commit with no
conventional type as a patch. "Create LICENSE", committed straight to
main from GitHub's web page, so started a release of an app that hadn't
changed.

## Decision

- Only these types release: breaking (`type!:` or a `BREAKING CHANGE:`
  footer) → major, `feat`/`fix` → minor, `perf`/`refactor`/`revert` →
  patch.
- `docs`, `chore`, `ci`, `test`, `style`, `build` and titles with no type
  don't release and stay out of the changelog. An untyped title shows a
  warning on the run.
- A PR title check rejects a PR whose title has no type; it is a
  required check on main, which also only takes changes through PRs.

## Consequences

- A change committed outside a PR can't release by accident; to release
  it, open a PR with a typed title.
- The list of types lives in `release.yml` and `pr-title.yml`; change
  both together.
