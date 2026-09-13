#!/usr/bin/env bash
set -euo pipefail

TAG="nightly"
REPO="nokarin-dev/aqloss"
SHA="${GITHUB_SHA:?GITHUB_SHA is required}"
SHORT="${SHA:0:8}"
DIST="${1:-dist}"
APP_VERSION="${APP_VERSION:-unknown}"
DATE_UTC="$(date -u +%Y-%m-%d)"
SHIELD="https://img.shields.io/github/downloads/${REPO}/${TAG}"
DL="https://github.com/${REPO}/releases/download/${TAG}"

files=(
  "${DIST}/Aqloss-windows-installer.exe"
  "${DIST}/Aqloss-windows-portable.zip"
  "${DIST}/Aqloss-linux-installer.deb"
  "${DIST}/Aqloss-linux-installer.rpm"
  "${DIST}/Aqloss-linux.AppImage"
  "${DIST}/Aqloss-linux-portable.tar.gz"
  "${DIST}/Aqloss-android-arm64.apk"
  "${DIST}/Aqloss-android-arm32.apk"
  "${DIST}/Aqloss-android-x86_64.apk"
  "${DIST}/Aqloss-macos.dmg"
  "${DIST}/Aqloss-macos-portable.zip"
  "${DIST}/Aqloss-ios.ipa"
)

for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then
    echo "Missing artifact: $f" >&2
    find "${DIST}" -type f | sort || true
    exit 1
  fi
done

badge() {
  local file="$1" alt="$2" label="$3" logo="$4" color="$5"
  printf '[![%s](%s/%s?style=for-the-badge&logo=%s&logoColor=white&label=%s&color=%s)](%s/%s)' \
    "$alt" "$SHIELD" "$file" "$logo" "$label" "$color" "$DL" "$file"
}

notes="$(cat <<EOF
Rolling builds from main. This tag is overwritten by the next successful nightly. Not a versioned release.

Current binaries: app version **${APP_VERSION}**, commit \`${SHORT}\` (${DATE_UTC} UTC).

macOS and iOS are unsigned. I don't test them regularly. Stable Windows / Linux / Android stay on [latest](https://github.com/${REPO}/releases/latest).

## Downloads

### Windows
$(badge Aqloss-windows-installer.exe Windows-Installer Installer windows blue)
$(badge Aqloss-windows-portable.zip Windows-Portable Portable windows blue)

### Linux
$(badge Aqloss-linux-installer.deb Linux-Debian .deb linux e07334)
$(badge Aqloss-linux-installer.rpm Linux-RPM .rpm linux e07334)
$(badge Aqloss-linux.AppImage Linux-AppImage AppImage linux e07334)
$(badge Aqloss-linux-portable.tar.gz Linux-Portable Portable linux e07334)

### Android
$(badge Aqloss-android-arm64.apk Android-ARM64 ARM64 android 3ddc84)
$(badge Aqloss-android-arm32.apk Android-ARM32 ARM32 android 3ddc84)
$(badge Aqloss-android-x86_64.apk Android-x86_64 x86_64 android 3ddc84)

### macOS
Unsigned. Gatekeeper will block it; right-click the app, Open.

$(badge Aqloss-macos.dmg macOS-DMG DMG apple black)
$(badge Aqloss-macos-portable.zip macOS-Portable Portable apple black)

### iOS
Unsigned IPA, sideload only.

$(badge Aqloss-ios.ipa iOS-IPA IPA apple black)
EOF
)"

git tag -f "${TAG}" "${SHA}"
if [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  git push -f "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "refs/tags/${TAG}"
else
  git push -f origin "refs/tags/${TAG}"
fi

if gh release view "${TAG}" >/dev/null 2>&1; then
  gh release edit "${TAG}" \
    --title "Nightly" \
    --prerelease \
    --latest=false \
    --notes "${notes}"
  gh release upload "${TAG}" "${files[@]}" --clobber
else
  gh release create "${TAG}" "${files[@]}" \
    --title "Nightly" \
    --prerelease \
    --latest=false \
    --notes "${notes}" \
    --target "${SHA}"
fi

echo "Updated ${TAG} from ${SHORT} (${APP_VERSION})."
