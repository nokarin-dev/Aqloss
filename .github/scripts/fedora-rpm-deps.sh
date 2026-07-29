#!/usr/bin/env bash
# Install everything needed to build Flutter Linux + RPM inside a Fedora container.
# Must run BEFORE actions/checkout when the image has no git (bare fedora:NN).
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

echo "Fedora RPM build dependencies installed."
