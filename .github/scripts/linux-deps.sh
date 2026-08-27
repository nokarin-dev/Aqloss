#!/usr/bin/env bash
set -euo pipefail

profile="${1:-desktop}"

sudo apt-get update -y

case "${profile}" in
  audio)
    # clang/libclang: bindgen for cpal's pipewire/libspa-sys
    sudo apt-get install -y \
      pkg-config clang libclang-dev \
      libasound2-dev libpulse-dev libpipewire-0.3-dev
    ;;
  desktop)
    sudo apt-get install -y \
      clang cmake ninja-build pkg-config libclang-dev \
      libgtk-3-dev liblzma-dev libstdc++-12-dev \
      libasound2-dev libpulse-dev libpipewire-0.3-dev \
      dpkg-dev fakeroot wget file
    ;;
  *)
    echo "Unknown profile: ${profile}" >&2
    exit 1
    ;;
esac
