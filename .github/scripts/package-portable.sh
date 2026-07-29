#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:-Aqloss-linux-portable.tar.gz}"
BUNDLE="${BUNDLE:-build/linux/x64/release/bundle}"

tar -czf "${OUTPUT}" -C "${BUNDLE}" .
echo "Built ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
