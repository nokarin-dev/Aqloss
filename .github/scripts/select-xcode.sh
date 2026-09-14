#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob
apps=(/Applications/Xcode_26*.app)
if [ "${#apps[@]}" -eq 0 ]; then
  apps=(/Applications/Xcode_16.4.app)
fi
if [ "${#apps[@]}" -eq 0 ]; then
  echo "No Xcode app in /Applications" >&2
  ls -d /Applications/Xcode*.app >&2 || true
  exit 1
fi

pick="$(printf '%s\n' "${apps[@]}" | sort -V | tail -n 1)"
sudo xcode-select -s "$pick"
echo "Using $pick"
xcodebuild -version
