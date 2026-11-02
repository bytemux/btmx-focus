#!/usr/bin/env bash
# Builds the app bundle from the SwiftPM package and ad-hoc signs it.
# Usage: scripts/build-app.sh [debug|release|e2e]   (default: release)
#   release, debug → build/btmx-focus.app      (com.btmx.focus)
#   e2e            → build/btmx-focus E2E.app  (com.btmx.focus.e2e): a debug
#                    build that runs next to the real app, has its own sandbox
#                    container and accepts the E2E launch arguments (ADR 0010)
set -euo pipefail

cd "$(dirname "$0")/.."
variant="${1:-release}"
case "$variant" in
    release | debug)
        config="$variant"
        name="btmx-focus"
        bundle_id="com.btmx.focus"
        ;;
    e2e) # bundle id and name must match E2EContract (Sources/BtmxFocusUIContract)
        config="debug"
        name="btmx-focus E2E"
        bundle_id="com.btmx.focus.e2e"
        ;;
    *)
        echo "usage: $0 [debug|release|e2e]" >&2
        exit 2
        ;;
esac
app="build/$name.app"

swift build -c "$config" --product BtmxFocus
bin_path="$(swift build -c "$config" --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/BtmxFocus" "$app/Contents/MacOS/btmx-focus"
cp Support/Info.plist "$app/Contents/Info.plist"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" \
    -c "Set :CFBundleName $name" -c "Set :CFBundleDisplayName $name" "$plist"
# The About panel's version (AboutPanel.commitKey): the commit, for now.
commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
[ -z "$(git status --porcelain 2>/dev/null)" ] || commit="$commit-dirty"
/usr/libexec/PlistBuddy -c "Add :BtmxCommit string $commit" "$plist"

codesign --force --sign - --options runtime \
    --entitlements Support/btmx-focus.entitlements "$app"

echo "Built $app"
