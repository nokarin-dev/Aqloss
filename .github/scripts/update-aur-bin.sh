#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKGDIR="${ROOT}/packaging/aur/aqloss-bin"
PKGBUILD="${PKGDIR}/PKGBUILD"

TAG="${TAG:-${1:-}}"
if [ -z "${TAG}" ]; then
  VERSION=""
  if [ -f "${ROOT}/version.yaml" ]; then
    VERSION="$(grep -E '^version:' "${ROOT}/version.yaml" | head -1 | sed 's/^version:[[:space:]]*//')"
  fi
  if [ -z "${VERSION}" ]; then
    echo "Pass a tag or set version.yaml" >&2
    exit 1
  fi
  TAG="v${VERSION}"
fi
case "${TAG}" in
  v*) ;;
  *) TAG="v${TAG}" ;;
esac
VERSION="${TAG#v}"

DEB_URL="https://github.com/nokarin-dev/Aqloss/releases/download/${TAG}/Aqloss-linux-installer.deb"
DEB="${TMPDIR:-/tmp}/Aqloss-linux-installer-${VERSION}.deb"

echo "Fetching ${DEB_URL}"
curl -fsSL -o "${DEB}" "${DEB_URL}"
SHA256="$(sha256sum "${DEB}" | awk '{print $1}')"
echo "sha256 ${SHA256}"

python3 - "${PKGBUILD}" "${VERSION}" "${SHA256}" <<'PY'
from pathlib import Path
import re
import sys

path, version, sha256 = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text()
text = re.sub(r"^pkgver=.*$", f"pkgver={version}", text, count=1, flags=re.M)
text = re.sub(r"^pkgrel=.*$", "pkgrel=1", text, count=1, flags=re.M)
text = re.sub(r"^sha256sums=\(.*\)$", f"sha256sums=('{sha256}')", text, count=1, flags=re.M)
path.write_text(text)
PY

if command -v makepkg >/dev/null 2>&1; then
  (cd "${PKGDIR}" && makepkg --printsrcinfo > .SRCINFO)
else
  echo "makepkg not found; .SRCINFO was not regenerated" >&2
fi

echo "Updated ${PKGDIR} for ${TAG}"
echo "Publish: .github/scripts/publish-aur-bin.sh then git -C \$AUR_DIR push origin master"
