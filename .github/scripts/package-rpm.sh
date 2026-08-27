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

BUNDLE_DIR="$(cd "${BUNDLE_DIR}" && pwd)"
RPMROOT="$(mkdir -p "${RPMROOT}" && cd "${RPMROOT}" && pwd)"
OUTPUT_ABS="$(cd "$(dirname "${OUTPUT}")" && pwd)/$(basename "${OUTPUT}")"
CHANGELOG_DATE="$(date -u '+%a %b %d %Y')"

mkdir -p "${RPMROOT}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
printf '%s\n' "${BUNDLE_DIR}" > "${RPMROOT}/SOURCES/bundle_path.txt"

if [ -f assets/icons/icon_256.png ]; then
  cp assets/icons/icon_256.png "${RPMROOT}/SOURCES/aqloss.png"
fi

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
Requires:       gtk3, xz-libs, alsa-lib, pipewire-libs

%description
Aqloss is a cross-platform music player engineered for bit-perfect, lossless, and hi-res audio playback.

%install
set -euo pipefail
BUNDLE=\$(cat '${RPMROOT}/SOURCES/bundle_path.txt')
if [ ! -d "\$BUNDLE" ]; then
  echo "Bundle missing at \$BUNDLE" >&2
  exit 1
fi
mkdir -p %{buildroot}/opt/aqloss %{buildroot}/usr/bin \\
  %{buildroot}/usr/share/applications \\
  %{buildroot}/usr/share/icons/hicolor/256x256/apps \\
  %{buildroot}/usr/share/mime/packages
cp -a "\$BUNDLE"/. %{buildroot}/opt/aqloss/
EXE=\$(find %{buildroot}/opt/aqloss -maxdepth 1 -type f ! -name '*.so' ! -name '*.desktop' | head -1)
if [ -z "\$EXE" ]; then
  echo "No executable found under %{buildroot}/opt/aqloss" >&2
  ls -la %{buildroot}/opt/aqloss >&2 || true
  exit 1
fi
EXE_NAME=\$(basename "\$EXE")
if [ "\$EXE_NAME" != "aqloss" ]; then
  mv "\$EXE" %{buildroot}/opt/aqloss/aqloss
fi
chmod +x %{buildroot}/opt/aqloss/aqloss
ln -sf /opt/aqloss/aqloss %{buildroot}/usr/bin/aqloss
cp '${RPMROOT}/SOURCES/xyz.nokarin.aqloss.desktop' \\
  %{buildroot}/usr/share/applications/xyz.nokarin.aqloss.desktop
cp '${RPMROOT}/SOURCES/xyz.nokarin.aqloss.xml' \\
  %{buildroot}/usr/share/mime/packages/xyz.nokarin.aqloss.xml
if [ -f '${RPMROOT}/SOURCES/aqloss.png' ]; then
  cp '${RPMROOT}/SOURCES/aqloss.png' \\
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

%changelog
* ${CHANGELOG_DATE} nokarin <github@nokarin.my.id> - ${VERSION}-1
- Packaged Aqloss ${VERSION}
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

RPM_FILE="$(find "${RPMROOT}/RPMS" -type f -name '*.rpm' | head -1)"
if [ -z "${RPM_FILE}" ]; then
  echo "RPM not found under ${RPMROOT}/RPMS" >&2
  find "${RPMROOT}" -type f | head -50 >&2 || true
  exit 1
fi

cp "${RPM_FILE}" "${OUTPUT_ABS}"
echo "Built ${OUTPUT_ABS} ($(du -h "${OUTPUT_ABS}" | cut -f1))"
