#!/usr/bin/env bash
# Builds build/btmx-focus.app from the SwiftPM package and ad-hoc signs it.
# Usage: scripts/build-app.sh [debug|release]   (default: release)
set -euo pipefail

cd "$(dirname "$0")/.."
config="${1:-release}"
app="build/btmx-focus.app"

swift build -c "$config" --product BtmxFocus
bin_path="$(swift build -c "$config" --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/BtmxFocus" "$app/Contents/MacOS/btmx-focus"
cp Support/Info.plist "$app/Contents/Info.plist"

codesign --force --sign - --options runtime \
    --entitlements Support/btmx-focus.entitlements "$app"

echo "Built $app"
