#!/bin/bash
# Build for a real device and sign with the team wildcard development profile (no Xcode account needed).
#   CONFIG=Debug|Release (default Release)  -> build/device/Viewer.app
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${CONFIG:-Release}
TEAM=77STY5BM38
ID=com.adriansmith.viewer
IDENTITY=${IDENTITY:-"Apple Development: Adrian Smith (84TKH9988X)"}
xcodegen generate --quiet
xcodebuild build -project Viewer.xcodeproj -scheme Viewer -configuration "$CONFIG" -destination generic/platform=iOS \
    -derivedDataPath build/dd-device CODE_SIGNING_ALLOWED=NO > build/device-build.log 2>&1 \
    || { grep -E "error:" build/device-build.log | sort -u | head; exit 1; }
rm -rf build/device && mkdir -p build/device
cp -R "build/dd-device/Build/Products/$CONFIG-iphoneos/Viewer.app" build/device/
APP=build/device/Viewer.app
cp signing/team-wildcard.mobileprovision "$APP/embedded.mobileprovision"
cat > build/device/entitlements.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>application-identifier</key><string>$TEAM.$ID</string>
<key>com.apple.developer.team-identifier</key><string>$TEAM</string>
<key>get-task-allow</key><true/>
</dict></plist>
PL
find "$APP" -name "*.framework" -o -name "*.dylib" | while read -r f; do codesign -f -s "$IDENTITY" "$f" 2>/dev/null; done
codesign -f -s "$IDENTITY" --entitlements build/device/entitlements.plist "$APP"
codesign -v --deep "$APP" && echo "$APP"
