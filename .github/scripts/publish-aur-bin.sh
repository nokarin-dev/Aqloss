#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKGDIR="${ROOT}/packaging/aur/aqloss-bin"
AUR_REMOTE="${AUR_REMOTE:-ssh://aur@aur.archlinux.org/aqloss-bin.git}"
AUR_DIR="${AUR_DIR:-${TMPDIR:-/tmp}/aqloss-bin-aur}"

if [ ! -f "${PKGDIR}/PKGBUILD" ] || [ ! -f "${PKGDIR}/.SRCINFO" ]; then
  echo "Run update-aur-bin.sh first" >&2
  exit 1
fi

VERSION="$(grep -E '^pkgver=' "${PKGDIR}/PKGBUILD" | head -1 | cut -d= -f2)"

if [ -d "${AUR_DIR}/.git" ]; then
  git -C "${AUR_DIR}" fetch origin
  git -C "${AUR_DIR}" checkout master
  git -C "${AUR_DIR}" pull --ff-only origin master || true
else
  rm -rf "${AUR_DIR}"
  git clone "${AUR_REMOTE}" "${AUR_DIR}"
fi

cp "${PKGDIR}/PKGBUILD" "${PKGDIR}/.SRCINFO" "${AUR_DIR}/"

git -C "${AUR_DIR}" add PKGBUILD .SRCINFO
if git -C "${AUR_DIR}" diff --cached --quiet; then
  echo "AUR tree already matches ${VERSION}"
  exit 0
fi

if git -C "${AUR_DIR}" rev-parse --verify HEAD >/dev/null 2>&1; then
  MSG="update to ${VERSION}"
else
  MSG="initial import: aqloss-bin ${VERSION}"
fi

git -C "${AUR_DIR}" commit -m "${MSG}"

echo "Commit ready in ${AUR_DIR}"
echo "Push: git -C ${AUR_DIR} push origin master"
