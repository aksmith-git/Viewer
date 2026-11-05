#!/bin/bash
# scripts/sim-shot.sh <name> <sample path relative to samples/> [light|dark] [extra launch args...]
# Copies the samples to /tmp (the simulator can't read ~/Documents), opens one in Viewer, screenshots it.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=$1 REL=$2 MODE=${3:-light}; shift 3 || shift $#
SIM_NAME=${SIM_NAME:-iPhone 17e}
SIM=$(xcrun simctl list devices | grep "$SIM_NAME (" | grep -oE "[0-9A-F-]{36}" | head -1)
TMP=/tmp/viewer-samples
rm -rf $TMP && cp -R ViewerTests/Fixtures/samples $TMP
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl ui "$SIM" appearance "$MODE"
xcrun simctl install "$SIM" build/dd/Build/Products/Debug-iphonesimulator/Viewer.app
xcrun simctl launch --terminate-running-process "$SIM" com.adriansmith.viewer -open "$TMP/$REL" "$@" >/dev/null
sleep ${WAIT:-4}
mkdir -p build/shots
xcrun simctl io "$SIM" screenshot "build/shots/$NAME.png" >/dev/null 2>&1
sips -Z 800 "build/shots/$NAME.png" --out "build/shots/$NAME-s.png" >/dev/null
echo "build/shots/$NAME-s.png"
