#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

flutter build ios --config-only --release --no-codesign

BUILD_DIR="$ROOT/build/ios"
mkdir -p "$BUILD_DIR"

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

DEST="$BUILD_DIR/iphoneos/Runner.app"
if [ -d "$DEST" ]; then
  exit 0
fi

FOUND="$(find "$BUILD_DIR" -name 'Runner.app' -type d | head -n 1 || true)"
if [ -z "$FOUND" ]; then
  echo "Missing Runner.app under $BUILD_DIR" >&2
  find "$BUILD_DIR" -name '*.app' | head -20 >&2 || true
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -R "$FOUND" "$DEST"
