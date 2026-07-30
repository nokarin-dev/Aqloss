#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is required before configuring safe.directory" >&2
  exit 1
fi

if [ -n "${GIT_CONFIG_GLOBAL:-}" ]; then
  mkdir -p "$(dirname "${GIT_CONFIG_GLOBAL}")"
  touch "${GIT_CONFIG_GLOBAL}"
fi

add_safe() {
  local dir="$1"
  [ -n "$dir" ] || return 0
  git config --global --add safe.directory "$dir"
  echo "git safe.directory += ${dir}"
}

workspace="${GITHUB_WORKSPACE:-$(pwd)}"
add_safe "${workspace}"

if [ -n "${FLUTTER_ROOT:-}" ] && [ -d "${FLUTTER_ROOT}" ]; then
  add_safe "${FLUTTER_ROOT}"
fi

if command -v find >/dev/null 2>&1 && [ -d /__t/flutter ]; then
  while IFS= read -r -d '' dir; do
    add_safe "$dir"
  done < <(find /__t/flutter -maxdepth 3 -type d -name flutter -print0 2>/dev/null || true)
fi

if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
  add_safe "*"
fi
