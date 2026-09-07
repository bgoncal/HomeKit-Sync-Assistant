#!/bin/bash
# Writes store-ready 6.7" screenshots into Screenshots/ by rendering the real
# screens with the test fixtures.
#
#   Scripts/capture-screenshots.sh [simulator name]

set -euo pipefail

SIMULATOR="${1:-iPhone 17}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$REPO/Screenshots"

xcodebuild -project "$REPO/HomeKitBridge.xcodeproj" -scheme HomeKitBridge \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -only-testing:HomeKitBridgeTests/ScreenshotCaptureTests \
    test 2>&1 | tee /tmp/capture-screenshots.log | grep -E "SCREENSHOT|Executed" || true

ls -la "$OUTPUT"
