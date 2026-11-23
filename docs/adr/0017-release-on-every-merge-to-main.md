# 0017. Release on every merge to main

Status: Accepted
Date: 2026-11-23

## Context

ADR 0016 releases by dispatching the Release workflow by hand. Merged
features then wait until someone remembers to release, and a docs-only
merge followed by a dispatch put out a version with no app change.

## Decision

- The Release workflow runs on every push to main, i.e. every merged PR;
  dispatching it by hand (with the dry run) stays.
- The version bump still comes from the conventional type of each commit
  since the latest tag, which for a merge is the PR title. `docs:` and
  `chore:` don't count: they bump nothing and stay out of the changelog.
  With nothing else since the tag, the run ends green without releasing.
- Runs don't overlap (one concurrency group); a run queued behind
  another computes from the tag that one created.

## Consequences

- main must stay releasable: the E2E suite and the manual check run
  before merging a `feat` or `fix` PR, not before a release.
- PR titles decide releases, so they need a conventional type (AGENTS.md).
  A title without one releases a patch.
- Several merges in a row can each release; a queued run that finds
  nothing new ends without releasing.
