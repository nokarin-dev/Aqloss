#!/usr/bin/env bash
set -euo pipefail

REF="${GITHUB_REF:-}"
REF_NAME="${GITHUB_REF_NAME:-}"

if [[ "${REF}" != refs/tags/v* ]]; then
  echo "Release workflows must run on a tag matching v* (got: ${REF:-empty})." >&2
  echo "Push a tag such as v1.0.0, or dispatch the workflow from that tag." >&2
  exit 1
fi

TAG_BARE="${REF_NAME#v}"
if [ -z "${TAG_BARE}" ]; then
  echo "Could not parse version from tag: ${REF_NAME}" >&2
  exit 1
fi

TAG_VERSION="${TAG_BARE}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
if [ -f "${ROOT}/version.yaml" ]; then
  VERSION="$(grep -E '^version:' "${ROOT}/version.yaml" | head -1 | sed 's/^version:[[:space:]]*//')"
fi
if [ -z "${VERSION}" ] && [ -f "${ROOT}/pubspec.yaml" ]; then
  PUBSPEC="$(grep -E '^version:' "${ROOT}/pubspec.yaml" | head -1 | sed 's/^version:[[:space:]]*//')"
  VERSION="${PUBSPEC%%+*}"
fi

if [ -z "${VERSION}" ]; then
  echo "Could not read version from version.yaml or pubspec.yaml" >&2
  exit 1
fi

if [ "${TAG_VERSION}" != "${VERSION}" ]; then
  echo "Tag '${REF_NAME}' does not match version.yaml ('${VERSION}')." >&2
  echo "Update version.yaml (and run dart run tool/sync_version.dart) before tagging." >&2
  exit 1
fi

echo "Release version OK: ${REF_NAME} ≡ ${VERSION}"
