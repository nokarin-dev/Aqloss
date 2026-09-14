#!/usr/bin/env bash
set -euo pipefail

if xcodebuild -showsdks 2>/dev/null | grep -vi simulator | grep -q iphoneos; then
  echo "iOS device SDK already present"
  xcodebuild -showsdks
  exit 0
fi

echo "iOS device SDK missing; downloading platform"
xcrun simctl list >/dev/null 2>&1 || true
sleep 2

for attempt in 1 2 3 4 5; do
  echo "xcodebuild -downloadPlatform iOS (attempt $attempt)"
  if xcodebuild -downloadPlatform iOS; then
    exit 0
  fi
  sleep $((attempt * 8))
  xcrun simctl list >/dev/null 2>&1 || true
done

echo "downloadPlatform iOS failed" >&2
xcodebuild -showsdks >&2 || true
exit 1
