# btmx-focus

Native macOS menu-bar focus timer. Spec: `docs/spec.md`. ADRs: `docs/adr/`.
Build, run, logs: `docs/building.md`.

## Commands

```sh
swift test                                   # engine tests
scripts/build-app.sh && open build/btmx-focus.app
swiftformat . && swiftlint
```

If Xcode's license isn't accepted, prefix with
`DEVELOPER_DIR=/Library/Developer/CommandLineTools` (and `TOOLCHAIN_DIR=` the
same path for SwiftLint).

## Testing the UI

Do not use computer use, screenshots or screen recording. Verify what you
can with `swift test`, a clean build and the logs (`breadcrumbs.log`,
`crash-*.log`). Then hand over to the user, who tests the UI by hand, and
say what to look for.
