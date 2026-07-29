#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"
OUTPUT="${2:-Aqloss-linux-installer.rpm}"
BUNDLE_DIR="${BUNDLE:-build/linux/x64/release/bundle}"
RPMROOT="${RPMROOT:-$PWD/rpmbuild}"

if [ ! -d "${BUNDLE_DIR}" ]; then
  echo "Flutter Linux bundle not found: ${BUNDLE_DIR}" >&2
  exit 1
fi

mkdir -p "${RPMROOT}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
echo "${BUNDLE_DIR}" > "${RPMROOT}/SOURCES/bundle_path.txt"

[ -f assets/icons/icon_256.png ] && \
  cp assets/icons/icon_256.png "${RPMROOT}/SOURCES/aqloss.png"

cp linux/xyz.nokarin.aqloss.desktop "${RPMROOT}/SOURCES/xyz.nokarin.aqloss.desktop"
cp linux/xyz.nokarin.aqloss.xml "${RPMROOT}/SOURCES/xyz.nokarin.aqloss.xml"

cat > "${RPMROOT}/SPECS/aqloss.spec" <<SPEC
Name:           Aqloss
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        High-quality local music player
License:        GPLv3
URL:            https://github.com/nokarin-dev/aqloss
BuildArch:      x86_64
Requires:       gtk3, xz-libs, alsa-lib

%description
Aqloss is a cross-platform music player engineered for bit-perfect, lossless, and hi-res audio playback.

%install
BUNDLE=\$(cat ${RPMROOT}/SOURCES/bundle_path.txt)
mkdir -p %{buildroot}/opt/aqloss %{buildroot}/usr/bin \
  %{buildroot}/usr/share/applications \
  %{buildroot}/usr/share/icons/hicolor/256x256/apps \
  %{buildroot}/usr/share/mime/packages
cp -r \$BUNDLE/. %{buildroot}/opt/aqloss/
EXE=\$(find %{buildroot}/opt/aqloss -maxdepth 1 -type f ! -name "*.so" ! -name "*.desktop" | head -1)
EXE_NAME=\$(basename \$EXE)
[ "\$EXE_NAME" != "aqloss" ] && mv "\$EXE" %{buildroot}/opt/aqloss/aqloss
chmod +x %{buildroot}/opt/aqloss/aqloss
ln -s /opt/aqloss/aqloss %{buildroot}/usr/bin/aqloss
cp ${RPMROOT}/SOURCES/xyz.nokarin.aqloss.desktop \
  %{buildroot}/usr/share/applications/xyz.nokarin.aqloss.desktop
cp ${RPMROOT}/SOURCES/xyz.nokarin.aqloss.xml \
  %{buildroot}/usr/share/mime/packages/xyz.nokarin.aqloss.xml
if [ -f "${RPMROOT}/SOURCES/aqloss.png" ]; then
  cp ${RPMROOT}/SOURCES/aqloss.png \
    %{buildroot}/usr/share/icons/hicolor/256x256/apps/xyz.nokarin.aqloss.png
fi

%post
update-mime-database /usr/share/mime 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0

%postun
update-mime-database /usr/share/mime 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0

%files
%attr(0755, root, root) /usr/bin/aqloss
/opt/aqloss/*
/usr/share/applications/xyz.nokarin.aqloss.desktop
/usr/share/mime/packages/xyz.nokarin.aqloss.xml
%if 0%{?aqloss_has_icon}
/usr/share/icons/hicolor/256x256/apps/xyz.nokarin.aqloss.png
%endif
SPEC

RPM_DEFINES=(
  --define "_topdir ${RPMROOT}"
  --define "_builddir ${RPMROOT}/BUILD"
  --define "__os_install_post %{nil}"
)
if [ -f "${RPMROOT}/SOURCES/aqloss.png" ]; then
  RPM_DEFINES+=(--define "aqloss_has_icon 1")
fi

rpmbuild -bb "${RPM_DEFINES[@]}" "${RPMROOT}/SPECS/aqloss.spec"

RPM_FILE="$(find "${RPMROOT}/RPMS/x86_64" -name '*.rpm' | head -1)"
[ -z "${RPM_FILE}" ] && echo "RPM not found" >&2 && exit 1
cp "${RPM_FILE}" "${OUTPUT}"
echo "Built ${OUTPUT}"
