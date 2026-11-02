#!/usr/bin/env bash
# Builds the E2E app and runs the E2E suite against it (ADR 0010).
# Usage: scripts/e2e.sh [swift test args…]   e.g. --filter TimerFlows
# Needs Accessibility and Screen Recording for the app you run it from.
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build-app.sh e2e

export E2E=1
export E2E_OUTPUT_DIR="${E2E_OUTPUT_DIR:-$PWD/build/e2e/$(date +%Y-%m-%dT%H%M%S)}"
mkdir -p "$E2E_OUTPUT_DIR"

echo "The E2E tests take over the mouse and keyboard. Hands off in…"
for i in 3 2 1; do
    echo "  $i"
    sleep 1
done

status=0
swift test --filter BtmxFocusE2ETests "$@" || status=$?
echo "Screenshots: $E2E_OUTPUT_DIR"
exit "$status"
