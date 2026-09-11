#!/bin/bash
# Writes the raw store captures into Docs/app-store/<device>/ by rendering the real
# screens with the test fixtures — 6.9" phone (1320 × 2868) and 13" tablet
# (2064 × 2752), the native sizes Vitrine frames and derives every other size from.
#
#   Scripts/capture-screenshots.sh [iphone|ipad|all] [simulator name]
#
# The phone set runs on an iPhone simulator, the tablet set on an iPad one, so each
# screen lays out with its own idiom. Simulators default to the ones the store
# session creates; pass another name to use a different one.

set -euo pipefail

TARGET="${1:-all}"
SIMULATOR="${2:-}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$REPO/build/DerivedData"

capture() {
    local class="$1" simulator="$2" device="$3"
    echo "== $device on $simulator"
    xcodebuild -project "$REPO/HomeKitBridge.xcodeproj" -scheme HomeKitBridge \
        -destination "platform=iOS Simulator,name=$simulator" \
        -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"HomeKitBridgeTests/$class" \
        test 2>&1 | tee "$REPO/build/capture-$device.log" | grep -E "SCREENSHOT|Executed|error:" || true
    ls -la "$REPO/Docs/app-store/$device"
}

mkdir -p "$REPO/build"

case "$TARGET" in
iphone)
    capture PhoneScreenshotCaptureTests "${SIMULATOR:-HomeSync-Store-iPhone17ProMax}" iphone
    ;;
ipad)
    capture PadScreenshotCaptureTests "${SIMULATOR:-HomeSync-Store-iPadPro13}" ipad
    ;;
all)
    capture PhoneScreenshotCaptureTests "${SIMULATOR:-HomeSync-Store-iPhone17ProMax}" iphone
    capture PadScreenshotCaptureTests "${SIMULATOR:-HomeSync-Store-iPadPro13}" ipad
    ;;
*)
    echo "usage: $(basename "$0") [iphone|ipad|all] [simulator name]" >&2
    exit 64
    ;;
esac
