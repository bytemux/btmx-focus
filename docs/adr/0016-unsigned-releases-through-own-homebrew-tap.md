# 0016. Unsigned releases through our own Homebrew tap

Status: Accepted
Date: 2026-11-02

## Context

v1 needs a way to install. The app is only ad-hoc signed: there is no
Apple Developer Program membership, so no Developer ID signing and no
notarization. macOS 15 blocks the first launch of a downloaded app that
isn't notarized. Since 1 September 2026 the official `homebrew/cask`
disables casks that fail Gatekeeper, and Homebrew 5 dropped
`--no-quarantine`. ADR 0013 rules out an in-app updater.

## Decision

- Each release is a GitHub Release `v<version>` with
  `btmx-focus-<version>.dmg`, built by `scripts/release.sh` from main in
  the manually dispatched Release workflow. The workflow computes the
  version from the commits since the latest tag (breaking → major,
  feat/fix → minor, else patch; first release 1.0.0); the macOS runner
  only starts when there is something to release.
- Homebrew installs it from our own tap, `bytemux/homebrew-tap`
  (`brew install bytemux/tap/btmx-focus`); `scripts/release.sh` updates
  the cask's version and checksum.
- The cask's `postflight` clears the quarantine flag, so a brew install
  opens without the Gatekeeper prompt. The cask's caveats and the release
  notes say so. A direct DMG download still needs Open Anyway.
- Apple silicon only.

## Consequences

- Updates come through `brew upgrade` or a new download; the app never
  checks for them.
- The `postflight` workaround is one Homebrew may block later; then brew
  users get the same Open Anyway step as DMG users.
- Notarization (paid membership) would remove the Gatekeeper step and
  open the official `homebrew/cask`; the tap and release flow stay.
