#!/usr/bin/env bash
set -euo pipefail

PROJECT="ColorFlaskGame.xcodeproj"
SCHEME="ColorFlaskGame"
CONFIGURATION="Debug"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SIMULATOR_DEVICE_TYPE="${SIMULATOR_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17}"
DERIVED_DATA_PATH="build/DerivedData"
BUNDLE_ID="com.fantasma.ColorFlaskGame"
FRESH_INSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh)
      FRESH_INSTALL=true
      shift
      ;;
    -h|--help)
      echo "Usage: scripts/run.sh [--fresh]"
      echo "  --fresh  Uninstall the existing app before installing this build."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: scripts/run.sh [--fresh]"
      exit 1
      ;;
  esac
done

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available. Install Xcode and select it with xcode-select."
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is not available. Install Xcode command line tools."
  exit 1
fi

DEVICE_ID="$(xcrun simctl list devices available "$SIMULATOR_NAME" | awk -F '[()]' -v name="$SIMULATOR_NAME" '$1 ~ "^[[:space:]]*" name "[[:space:]]*$" { print $2; exit }')"

if [[ -z "${DEVICE_ID}" ]]; then
  RUNTIME_ID="$(xcrun simctl list runtimes available | awk '/iOS/ { runtime = $NF } END { print runtime }')"

  if [[ -z "${RUNTIME_ID}" ]]; then
    echo "No available iOS simulator runtime was found."
    echo "Install an iOS simulator runtime in Xcode Settings > Platforms."
    exit 1
  fi

  echo "Creating '$SIMULATOR_NAME' with runtime '$RUNTIME_ID'."
  DEVICE_ID="$(xcrun simctl create "$SIMULATOR_NAME" "$SIMULATOR_DEVICE_TYPE" "$RUNTIME_ID")"
fi

DEVICE_STATE="$(xcrun simctl list devices "$DEVICE_ID" | awk -F '[()]' '/'"$DEVICE_ID"'/ { print $4; exit }')"

if [[ "${DEVICE_STATE}" != "Booted" ]]; then
  xcrun simctl boot "$DEVICE_ID"
fi

xcrun simctl bootstatus "$DEVICE_ID" -b

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/$SCHEME.app"

if [[ "$FRESH_INSTALL" == true ]]; then
  xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

if [[ "$FRESH_INSTALL" == true ]]; then
  echo "Launched fresh $SCHEME install on $SIMULATOR_NAME."
else
  echo "Launched $SCHEME on $SIMULATOR_NAME."
fi
