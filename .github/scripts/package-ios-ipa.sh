#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

APP="${1:-build/ios/iphoneos/Runner.app}"
IPA="${2:-Aqloss-ios.ipa}"
MIN_KB="${IPA_MIN_KB:-1024}"

if [ -L "$APP" ]; then
  APP="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$APP")"
fi

if [ ! -f "$APP/Runner" ] || [ ! -s "$APP/Runner" ] || [ ! -f "$APP/Info.plist" ]; then
  echo "Incomplete Runner.app at $APP" >&2
  ls -la "$APP" >&2 || true
  find build/ios -name 'Runner.app' -type d 2>/dev/null | head -20 >&2 || true
  exit 1
fi

app_kb="$(du -sk "$APP" | awk '{print $1}')"
if [ "$app_kb" -lt "$MIN_KB" ]; then
  echo "Runner.app is ${app_kb}KB; expected at least ${MIN_KB}KB" >&2
  du -ah "$APP" | head -40 >&2
  exit 1
fi

rm -rf Payload "$IPA"
mkdir Payload
ditto "$APP" Payload/Runner.app
zip -qr "$IPA" Payload
rm -rf Payload

ipa_kb="$(du -sk "$IPA" | awk '{print $1}')"
if [ "$ipa_kb" -lt "$MIN_KB" ]; then
  echo "$IPA is ${ipa_kb}KB; expected at least ${MIN_KB}KB" >&2
  unzip -l "$IPA" | head -40 >&2
  exit 1
fi

echo "Wrote $IPA (${ipa_kb}KB) from $APP (${app_kb}KB)"
