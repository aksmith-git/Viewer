#!/bin/bash
# Archive Viewer and upload it to App Store Connect (TestFlight / review).
# Needs: Xcode signed in to the team's Apple ID (Settings > Accounts), and the app record created in
# App Store Connect with bundle ID com.adriansmith.viewer. Bump CFBundleVersion in project.yml for each upload.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
rm -rf build/Viewer.xcarchive build/export
xcodebuild archive -project Viewer.xcodeproj -scheme Viewer -configuration Release -destination generic/platform=iOS \
    -archivePath build/Viewer.xcarchive -allowProvisioningUpdates DEVELOPMENT_TEAM=77STY5BM38 CODE_SIGN_STYLE=Automatic \
    > build/archive.log 2>&1 || { grep -E "error:" build/archive.log | sort -u | head; exit 1; }
cat > build/ExportOptions.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>77STY5BM38</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PL
xcodebuild -exportArchive -archivePath build/Viewer.xcarchive -exportOptionsPlist build/ExportOptions.plist \
    -exportPath build/export -allowProvisioningUpdates > build/export.log 2>&1 \
    || { grep -E "error|Error" build/export.log | sort -u | head -20; exit 1; }
grep -E "Upload succeeded|EXPORT SUCCEEDED" build/export.log || tail -5 build/export.log
