#!/bin/bash
# Regenerate the project and build for the simulator (no tests).
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild build -project Viewer.xcodeproj -scheme Viewer -destination "platform=iOS Simulator,name=${SIM_NAME:-iPhone 17e}" \
    -derivedDataPath build/dd CODE_SIGN_IDENTITY=- > build/build.log 2>&1 || { grep -E "error:" build/build.log | sort -u | head; exit 1; }
echo "build ok"
