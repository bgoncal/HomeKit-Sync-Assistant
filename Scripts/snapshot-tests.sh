#!/bin/bash
# Runs the snapshot + logic tests on one platform.
#
#   Scripts/snapshot-tests.sh iphone [simulator name]
#   Scripts/snapshot-tests.sh mac
#
# Mac Catalyst apps are always sandboxed, so the tests cannot read or write the
# reference images inside the repository. For "mac" this script copies them into
# the app container before the run and copies them back afterwards; the images in
# the repository stay the source of truth either way.

set -euo pipefail

PLATFORM="${1:-iphone}"
SIMULATOR="${2:-iPhone 17}"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOTS="$REPO/HomeKitBridgeTests/__Snapshots__"
CONTAINER="$HOME/Library/Containers/com.panta.homekitsync/Data/Documents/__Snapshots__"

case "$PLATFORM" in
iphone)
    xcodebuild -project "$REPO/HomeKitBridge.xcodeproj" -scheme HomeKitBridge \
        -destination "platform=iOS Simulator,name=$SIMULATOR" test
    ;;
mac)
    mkdir -p "$SNAPSHOTS" "$CONTAINER"
    rsync -a --delete "$SNAPSHOTS/" "$CONTAINER/"

    set +e
    xcodebuild -project "$REPO/HomeKitBridge.xcodeproj" -scheme HomeKitBridge \
        -destination 'platform=macOS,variant=Mac Catalyst' test
    STATUS=$?
    set -e

    # Newly recorded references are written inside the container; bring them home.
    rsync -a "$CONTAINER/" "$SNAPSHOTS/"
    exit $STATUS
    ;;
*)
    echo "usage: $(basename "$0") [iphone|mac] [simulator name]" >&2
    exit 64
    ;;
esac
