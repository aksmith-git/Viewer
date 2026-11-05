#!/bin/bash
# Generate the project and run the unit tests on the simulator. Full log: build/test.log
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodegen generate --quiet || exit 1
xcodebuild test -project Viewer.xcodeproj -scheme Viewer \
    -destination "platform=iOS Simulator,name=${SIM:-iPhone 17e}" -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -derivedDataPath build/dd \
    CODE_SIGN_IDENTITY=- > build/test.log 2>&1
rc=$?
grep -E "error:|Test Case .* failed|XCTAssert|Executed [0-9]+ test" build/test.log | sort -u | tail -25
grep -qE "\*\* TEST SUCCEEDED \*\*" build/test.log && echo "TEST SUCCEEDED" || echo "TEST FAILED"
exit $rc
