#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/ios/Runner.xcodeproj"

need_download() {
  local out
  out="$(xcodebuild -project "$PROJ" -scheme Runner -showdestinations 2>&1 || true)"
  printf '%s\n' "$out"
  printf '%s\n' "$out" | grep -q 'error:iOS .* is not installed'
}

if ! need_download; then
  echo "iOS device destination is present"
  exit 0
fi

xcrun simctl list >/dev/null 2>&1 || true
sleep 2

for attempt in 1 2 3 4 5 6; do
  echo "xcodebuild -downloadPlatform iOS (attempt $attempt)"
  if xcodebuild -downloadPlatform iOS; then
    xcodebuild -project "$PROJ" -scheme Runner -showdestinations || true
    exit 0
  fi
  echo "downloadPlatform failed; retrying"
  sleep $((attempt * 8))
  killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
  xcrun simctl list >/dev/null 2>&1 || true
  sleep 2
done

echo "downloadPlatform iOS failed" >&2
xcodebuild -showsdks >&2 || true
exit 1
