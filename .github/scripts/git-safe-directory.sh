#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is required before configuring safe.directory" >&2
  exit 1
fi

workspace="${GITHUB_WORKSPACE:-$(pwd)}"

if [ -n "${GIT_CONFIG_GLOBAL:-}" ]; then
  mkdir -p "$(dirname "${GIT_CONFIG_GLOBAL}")"
  touch "${GIT_CONFIG_GLOBAL}"
fi

git config --global --add safe.directory "${workspace}"
echo "git safe.directory set for ${workspace}"
