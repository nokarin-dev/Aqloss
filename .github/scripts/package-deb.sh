#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"
OUTPUT="${2:-Aqloss-linux-installer.deb}"
BUNDLE="${BUNDLE:-build/linux/x64/release/bundle}"
PKG="aqloss_${VERSION}_amd64"

mkdir -p "${PKG}/DEBIAN" "${PKG}/opt/aqloss" "${PKG}/usr/bin" \
  "${PKG}/usr/share/applications" \
  "${PKG}/usr/share/icons/hicolor/256x256/apps" \
  "${PKG}/usr/share/mime/packages"

cp -r "${BUNDLE}/." "${PKG}/opt/aqloss/"

EXE="$(find "${PKG}/opt/aqloss" -maxdepth 1 -type f ! -name '*.so' ! -name '*.desktop' | head -1)"
EXE_NAME="$(basename "${EXE}")"
[ "${EXE_NAME}" != "aqloss" ] && mv "${EXE}" "${PKG}/opt/aqloss/aqloss"

ln -sf /opt/aqloss/aqloss "${PKG}/usr/bin/aqloss"
cp linux/xyz.nokarin.aqloss.desktop "${PKG}/usr/share/applications/xyz.nokarin.aqloss.desktop"
cp linux/xyz.nokarin.aqloss.xml "${PKG}/usr/share/mime/packages/xyz.nokarin.aqloss.xml"

if [ -f assets/icons/icon_256.png ]; then
  cp assets/icons/icon_256.png \
    "${PKG}/usr/share/icons/hicolor/256x256/apps/xyz.nokarin.aqloss.png"
fi

cat > "${PKG}/DEBIAN/control" <<EOF
Package: aqloss
Version: ${VERSION}
Architecture: amd64
Maintainer: nokarin <contact@nokarin.my.id>
Description: High-quality local music player powered by a Rust audio engine.
Depends: libgtk-3-0, libblkid1, liblzma5, libasound2
Section: sound
Priority: optional
Homepage: https://github.com/nokarin-dev/aqloss
EOF

cat > "${PKG}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
chmod +x /opt/aqloss/aqloss 2>/dev/null || true
update-mime-database /usr/share/mime 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0
EOF
chmod 755 "${PKG}/DEBIAN/postinst"

cat > "${PKG}/DEBIAN/postrm" <<'EOF'
#!/bin/sh
update-mime-database /usr/share/mime 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0
EOF
chmod 755 "${PKG}/DEBIAN/postrm"

fakeroot dpkg-deb --build "${PKG}"
mv "${PKG}.deb" "${OUTPUT}"
echo "Built ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
