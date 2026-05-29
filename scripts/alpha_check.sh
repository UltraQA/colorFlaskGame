#!/usr/bin/env bash
set -euo pipefail

PROJECT="ColorFlaskGame.xcodeproj"
SCHEME="ColorFlaskGame"
CONFIGURATION="Debug"
SIMULATOR_NAME="iPhone 15"
SIMULATOR_OS="17.4"
DERIVED_DATA_PATH="build/DerivedData"

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available. Install Xcode and select it with xcode-select."
  exit 1
fi

echo "Running alpha readiness tests for $SCHEME..."

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test

echo "Alpha readiness tests passed."
