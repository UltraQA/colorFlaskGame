#!/usr/bin/env bash
set -euo pipefail

PROJECT="ColorFlaskGame.xcodeproj"
SCHEME="ColorFlaskGame"
CONFIGURATION="Release"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SIMULATOR_OS="${SIMULATOR_OS:-26.0.1}"
DERIVED_DATA_PATH="build/DerivedDataRelease"

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available. Install Xcode and select it with xcode-select."
  exit 1
fi

echo "Running release sanity build for $SCHEME..."
echo "Target simulator: $SIMULATOR_NAME / iOS $SIMULATOR_OS"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

echo "Release sanity build passed."
