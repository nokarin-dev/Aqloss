#!/usr/bin/env bash
set -euo pipefail

SHA="${GITHUB_SHA:?GITHUB_SHA is required}"
SHORT="${SHA:0:8}"
EVENT="${GITHUB_EVENT_NAME:-}"
TAG="nightly"

write_out() {
  echo "should_build=${1}" >> "${GITHUB_OUTPUT:?}"
}

if [ "${EVENT}" = "workflow_dispatch" ]; then
  echo "Manual dispatch; building ${SHORT}."
  write_out true
  exit 0
fi

NIGHTLY="$(git ls-remote origin "refs/tags/${TAG}" | awk '{print $1}')"
if [ -z "${NIGHTLY}" ]; then
  echo "No ${TAG} tag yet; building ${SHORT}."
  write_out true
  exit 0
fi

if [ "${NIGHTLY}" != "${SHA}" ]; then
  echo "${TAG} is ${NIGHTLY:0:8}; HEAD is ${SHORT}. Building."
  write_out true
  exit 0
fi

echo "${TAG} already at ${SHORT}; skip."
write_out false
