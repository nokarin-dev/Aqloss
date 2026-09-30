#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:-Aqloss-x86_64.AppImage}"
BUNDLE="${BUNDLE:-build/linux/x64/release/bundle}"
ZSYNC_NAME="$(basename "${OUTPUT}").zsync"
UPDATE_INFO="${UPDATE_INFO:-gh-releases-zsync|nokarin-dev|Aqloss|latest|${ZSYNC_NAME}}"

if [ ! -d "${BUNDLE}" ]; then
  echo "Flutter Linux bundle not found: ${BUNDLE}" >&2
  exit 1
fi

APPIMAGETOOL_VERSION="${APPIMAGETOOL_VERSION:-1.9.1}"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage"

if ! command -v wget >/dev/null 2>&1; then
  echo "wget is required to download appimagetool" >&2
  exit 1
fi

wget -q "${APPIMAGETOOL_URL}" -O /tmp/appimagetool.AppImage
chmod +x /tmp/appimagetool.AppImage
(
  cd /tmp
  ./appimagetool.AppImage --appimage-extract >/dev/null
)
APPIMAGETOOL="/tmp/squashfs-root/AppRun"
if [ ! -x "${APPIMAGETOOL}" ]; then
  echo "Failed to extract appimagetool from ${APPIMAGETOOL_URL}" >&2
  exit 1
fi

mkdir -p AppDir/app AppDir/usr/share/icons/hicolor/256x256/apps \
  AppDir/usr/share/mime/packages AppDir/usr/share/metainfo

cp -r "${BUNDLE}/." AppDir/app/

if [ -f assets/icons/icon_256.png ]; then
  cp assets/icons/icon_256.png \
    AppDir/usr/share/icons/hicolor/256x256/apps/xyz.nokarin.aqloss.png
  cp assets/icons/icon_256.png AppDir/xyz.nokarin.aqloss.png
else
  printf 'PNG' > AppDir/xyz.nokarin.aqloss.png
fi

cp linux/xyz.nokarin.aqloss.desktop AppDir/xyz.nokarin.aqloss.desktop
cp linux/xyz.nokarin.aqloss.xml AppDir/usr/share/mime/packages/xyz.nokarin.aqloss.xml
cp linux/xyz.nokarin.aqloss.metainfo.xml \
  AppDir/usr/share/metainfo/xyz.nokarin.aqloss.metainfo.xml

cat > AppDir/AppRun <<'EOF'
#!/bin/sh
APPDIR="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$APPDIR/app/lib:$LD_LIBRARY_PATH"
EXE_NAME=$(find "$APPDIR/app" -maxdepth 1 -type f ! -name "*.so" ! -name "*.desktop" | xargs -I{} basename {} | head -1)
[ -z "$EXE_NAME" ] && echo "Aqloss: executable not found" >&2 && exit 1
cd "$APPDIR/app"
exec "./$EXE_NAME" "$@"
EOF
chmod +x AppDir/AppRun

ARCH=x86_64 "${APPIMAGETOOL}" --no-appstream -u "${UPDATE_INFO}" AppDir "${OUTPUT}"
chmod +x "${OUTPUT}"
if [ ! -f "${ZSYNC_NAME}" ]; then
  echo "appimagetool did not write ${ZSYNC_NAME}" >&2
  exit 1
fi
echo "Built ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
echo "Built ${ZSYNC_NAME}"
