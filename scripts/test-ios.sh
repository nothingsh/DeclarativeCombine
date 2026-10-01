#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -z "${IOS_SIMULATOR_ID:-}" ]]; then
    echo "Set IOS_SIMULATOR_ID to an installed iOS Simulator UDID."
    echo "Usage: IOS_SIMULATOR_ID=<UDID> scripts/test-ios.sh [xcodebuild arguments]"
    echo "Available simulators:"
    xcrun simctl list devices available
    exit 64
fi

validation_dir="$repo_root/.build/validation"
mkdir -p "$validation_dir"
run_dir="$(mktemp -d "$validation_dir/run-$(date +%Y%m%d-%H%M%S)-XXXXXX")"

# Save the entire log and preserve xcodebuild's status across tee.
set +e
xcodebuild \
    -scheme DeclarativeUIKitCombine \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
    -derivedDataPath "$validation_dir/DerivedData" \
    -resultBundlePath "$run_dir/Tests.xcresult" \
    -parallel-testing-enabled NO \
    "$@" \
    test 2>&1 | tee "$run_dir/xcodebuild.log"
build_status=${PIPESTATUS[0]}
set -e

echo "Validation artifacts: $run_dir"
exit "$build_status"
