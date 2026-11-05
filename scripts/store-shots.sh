#!/bin/bash
# Raw App Store screenshots: scripts/store-shots.sh "<simulator name>" <out dir>
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=$1 OUT=$2
SIM=$(xcrun simctl list devices | grep "$NAME (" | grep -oE "[0-9A-F-]{36}" | head -1)
TMP=/tmp/viewer-samples
rm -rf $TMP && cp -R ViewerTests/Fixtures/samples $TMP
mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4
xcrun simctl uninstall "$SIM" com.adriansmith.viewer 2>/dev/null || true
xcrun simctl install "$SIM" build/dd/Build/Products/Debug-iphonesimulator/Viewer.app
shot() {  # shot <name> <mode> [launch args...]
    local n=$1 mode=$2; shift 2
    xcrun simctl ui "$SIM" appearance "$mode"
    xcrun simctl launch --terminate-running-process "$SIM" com.adriansmith.viewer "$@" >/dev/null
    sleep ${WAIT:-5}
    xcrun simctl io "$SIM" screenshot "$OUT/$n.png" >/dev/null 2>&1
}
# warm up and fill recents (oldest first)
for f in Files/Report.pdf Data/cities.csv Docs/Planet.swift Data/app-config.json Docs/README.md Website/index.html; do
    xcrun simctl launch --terminate-running-process "$SIM" com.adriansmith.viewer -open "$TMP/$f" >/dev/null; sleep 3
done
xcrun simctl launch --terminate-running-process "$SIM" com.adriansmith.viewer >/dev/null; sleep 1
shot 1-web light -open "$TMP/Website/index.html"
shot 2-console dark -open "$TMP/Website/index.html" -showConsole YES
shot 3-markdown light -open "$TMP/Docs/README.md"
shot 4-code dark -open "$TMP/Docs/Planet.swift"
shot 5-json light -open "$TMP/Data/app-config.json"
shot 6-csv light -open "$TMP/Data/cities.csv"
shot 7-pdf light -open "$TMP/Files/Report.pdf"
shot 8-home light
xcrun simctl status_bar "$SIM" clear
ls "$OUT"
