#!/usr/bin/env bash
set -euo pipefail

dnf install -y \
  @development-tools \
  git \
  curl \
  wget \
  unzip \
  xz \
  which \
  findutils \
  tar \
  jq \
  ca-certificates \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  gtk3-devel \
  xz-devel \
  libstdc++-devel \
  alsa-lib-devel \
  pulseaudio-libs-devel \
  mesa-libGL-devel \
  rpm-build \
  desktop-file-utils \
  hicolor-icon-theme

required_cmds=(
  git curl wget unzip xz jq which tar
  clang cmake ninja pkg-config
  rpmbuild
)
missing=0
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command after dnf install: $cmd" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "Fedora RPM build dependencies installed."
