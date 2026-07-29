#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:-Aqloss-linux-portable.tar.gz}"
BUNDLE="${BUNDLE:-build/linux/x64/release/bundle}"

if [ ! -d "${BUNDLE}" ]; then
  echo "Flutter Linux bundle not found: ${BUNDLE}" >&2
  exit 1
fi

tar -czf "${OUTPUT}" -C "${BUNDLE}" .
echo "Built ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
