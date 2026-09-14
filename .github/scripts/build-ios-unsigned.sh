#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# aqloss_rust_core is CocoaPods-only. SPM makes xcodebuild -showBuildSettings return nothing.
flutter config --no-enable-swift-package-manager
flutter pub get

APP="$ROOT/build/ios/iphoneos/Runner.app"
BUILD_DIR="$ROOT/build/ios"
mkdir -p "$BUILD_DIR"

set +e
flutter build ios --release --no-codesign
flutter_status=$?
set -e

if [ -d "$APP" ]; then
  echo "Runner.app ready (flutter exit ${flutter_status})"
  exit 0
fi

echo "flutter did not write Runner.app; xcodebuild with signing off" >&2
if [ ! -f "$ROOT/ios/Flutter/Generated.xcconfig" ]; then
  echo "Missing ios/Flutter/Generated.xcconfig" >&2
  exit 1
fi

if [ -f "$ROOT/ios/Podfile" ]; then
  (cd "$ROOT/ios" && pod install)
fi

cd "$ROOT/ios"
xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  BUILD_DIR="$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  "CODE_SIGN_IDENTITY[sdk=iphoneos*]"= \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  VALIDATE_PRODUCT=NO \
  build

if [ -d "$APP" ]; then
  exit 0
fi

FOUND="$(find "$BUILD_DIR" -name 'Runner.app' -type d | head -n 1 || true)"
if [ -z "$FOUND" ]; then
  echo "Missing Runner.app under $BUILD_DIR" >&2
  find "$BUILD_DIR" -name '*.app' | head -20 >&2 || true
  exit 1
fi

mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
cp -R "$FOUND" "$APP"
