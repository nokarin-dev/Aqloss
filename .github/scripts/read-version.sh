#!/usr/bin/env bash
set -euo pipefail

version=""
build=""

if [ -f version.yaml ]; then
  version="$(grep -E '^version:' version.yaml | head -1 | sed 's/^version:[[:space:]]*//')"
  build="$(grep -E '^build:' version.yaml | head -1 | sed 's/^build:[[:space:]]*//')"
fi

if [ -z "${version}" ] && [ -f pubspec.yaml ]; then
  pubspec="$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//')"
  version="${pubspec%%+*}"
  build="${pubspec#*+}"
  [ "${build}" = "${pubspec}" ] && build="1"
fi

if [ -z "${version}" ]; then
  echo "Could not determine app version from version.yaml or pubspec.yaml" >&2
  exit 1
fi

build="${build:-1}"
pubspec="${version}+${build}"

{
  echo "version=${version}"
  echo "build=${build}"
  echo "pubspec=${pubspec}"
} >> "${GITHUB_OUTPUT}"

echo "App version: ${pubspec}"
