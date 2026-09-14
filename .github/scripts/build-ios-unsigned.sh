#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter config --no-enable-swift-package-manager
flutter pub get
flutter build ios --config-only --release --no-codesign

if [ ! -f "$ROOT/ios/Flutter/Generated.xcconfig" ]; then
  echo "Missing ios/Flutter/Generated.xcconfig" >&2
  exit 1
fi

if [ -f "$ROOT/ios/Podfile" ] && [ ! -d "$ROOT/ios/Pods" ]; then
  (cd "$ROOT/ios" && pod install)
fi

BUILD_DIR="$ROOT/build/ios"
DEST_DIR="$BUILD_DIR/iphoneos"
DEST="$DEST_DIR/Runner.app"
mkdir -p "$DEST_DIR"

find_runner_app() {
  local p
  for p in \
    "$DEST" \
    "$BUILD_DIR/Release-iphoneos/Runner.app" \
    "$BUILD_DIR/Build/Products/Release-iphoneos/Runner.app" \
    "$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/Runner.app"
  do
    if [ -d "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  find "$BUILD_DIR" -name 'Runner.app' -type d 2>/dev/null | head -n 1
}

place_runner_app() {
  local found="$1"
  if [ "$found" = "$DEST" ]; then
    return 0
  fi
  mkdir -p "$DEST_DIR"
  rm -rf "$DEST"
  cp -R "$found" "$DEST"
}

run_xcodebuild() {
  xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$DEST_DIR" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    PROVISIONING_PROFILE_SPECIFIER= \
    VALIDATE_PRODUCT=NO \
    "$@"
}

cd "$ROOT/ios"
set +e
run_xcodebuild -destination 'generic/platform=iOS' build
xb_status=$?
if [ "$xb_status" -ne 0 ]; then
  echo "generic iOS destination failed; retry sdk-only" >&2
  run_xcodebuild build
  xb_status=$?
fi
set -e

found="$(find_runner_app || true)"
if [ -n "${found:-}" ]; then
  place_runner_app "$found"
  echo "Runner.app ready"
  exit 0
fi

echo "Missing Runner.app under $BUILD_DIR (xcodebuild exit ${xb_status})" >&2
find "$BUILD_DIR" -name '*.app' | head -20 >&2 || true
exit 1
