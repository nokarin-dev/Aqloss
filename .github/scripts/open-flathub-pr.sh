#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLATHUB_REPO="${FLATHUB_REPO:-flathub/xyz.nokarin.aqloss}"
FLATHUB_BASE="${FLATHUB_BASE:-master}"
AQLOSS_GIT="${AQLOSS_GIT:-https://github.com/nokarin-dev/Aqloss.git}"
FLATPAK_FLUTTER_IMAGE="${FLATPAK_FLUTTER_IMAGE:-theappgineer/flatpak-flutter:0.15.0}"
FLUTTER_TAG="${FLUTTER_TAG:-3.47.1}"

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN is required (a PAT that can push to ${FLATHUB_REPO})." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run ${FLATPAK_FLUTTER_IMAGE}" >&2
  exit 1
fi

TAG="${TAG:-${1:-}}"
if [ -z "${TAG}" ]; then
  VERSION=""
  if [ -f "${ROOT}/version.yaml" ]; then
    VERSION="$(grep -E '^version:' "${ROOT}/version.yaml" | head -1 | sed 's/^version:[[:space:]]*//')"
  fi
  if [ -z "${VERSION}" ]; then
    echo "Pass a tag or set version.yaml" >&2
    exit 1
  fi
  TAG="v${VERSION}"
fi
case "${TAG}" in
  v*) ;;
  *) TAG="v${TAG}" ;;
esac
BRANCH="update-${TAG}"

WORKDIR="${WORKDIR:-${RUNNER_TEMP:-/tmp}/flathub-aqloss}"
rm -rf "${WORKDIR}"
mkdir -p "$(dirname "${WORKDIR}")"

gh auth setup-git
gh repo clone "${FLATHUB_REPO}" "${WORKDIR}" -- --branch "${FLATHUB_BASE}"
cd "${WORKDIR}"

if git ls-remote --exit-code origin "refs/heads/${BRANCH}" >/dev/null 2>&1; then
  git fetch origin "${BRANCH}"
  git checkout -B "${BRANCH}" "origin/${BRANCH}"
else
  git checkout -B "${BRANCH}" "${FLATHUB_BASE}"
fi

if ! grep -qs 'path = shared-modules' .gitmodules; then
  git submodule add --depth 1 https://github.com/flathub/shared-modules.git shared-modules
fi

python3 - "${AQLOSS_GIT}" "${TAG}" "${FLUTTER_TAG}" <<'PY'
import sys
from pathlib import Path

aqloss_url, aqloss_tag, flutter_tag = sys.argv[1], sys.argv[2], sys.argv[3]
path = Path("flatpak-flutter.yaml")
text = path.read_text()


def upsert_tag(text: str, url: str, tag: str) -> str:
    needle = f"url: {url}"
    idx = text.find(needle)
    if idx < 0:
        raise SystemExit(f"git url not found in flatpak-flutter.yaml: {url}")
    after = idx + len(needle)
    rest = text[after:]
    if rest.startswith("\n        tag:"):
        end = rest.find("\n", 1)
        return text[:after] + f"\n        tag: {tag}" + rest[end:]
    return text[:after] + f"\n        tag: {tag}" + rest


def add_finish_arg(text: str, arg: str) -> str:
    if arg in text:
        return text
    header = "finish-args:\n"
    start = text.find(header)
    if start < 0:
        raise SystemExit("finish-args not found in flatpak-flutter.yaml")
    end = start + len(header)
    for line in text[end:].splitlines(keepends=True):
        if not line.startswith("  - "):
            break
        end += len(line)
    return text[:end] + f"  - {arg}\n" + text[end:]


text = upsert_tag(text, aqloss_url, aqloss_tag)
text = upsert_tag(text, "https://github.com/flutter/flutter.git", flutter_tag)
# The tray icon registers with the host StatusNotifier watcher
text = add_finish_arg(text, "--talk-name=org.kde.StatusNotifierWatcher")
path.write_text(text)
print(f"generate from {aqloss_url} {aqloss_tag}, Flutter {flutter_tag}")
PY

# sqlite3 3.5.2 dest is download-<sha8>; skip the 3.3.0 registry patch.
python3 - <<'PY'
import json
from pathlib import Path

path = Path("foreign.json")
data = json.loads(path.read_text()) if path.exists() else {}
data["sqlite3"] = {
    "manifest": {
        "sources": [
            {
                "type": "file",
                "only-arches": ["x86_64"],
                "url": "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/libsqlite3.x64.linux.so",
                "sha256": "b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2",
                "dest": "$APP/.dart_tool/hooks_runner/shared/sqlite3/build/download-b1772918",
                "dest-filename": "libsqlite3.so",
            },
            {
                "type": "file",
                "only-arches": ["aarch64"],
                "url": "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/libsqlite3.arm64.linux.so",
                "sha256": "7f0db19fdb987298ab8def51431aba5cec28a81685e8b62cebbc7402df090a16",
                "dest": "$APP/.dart_tool/hooks_runner/shared/sqlite3/build/download-7f0db19f",
                "dest-filename": "libsqlite3.so",
            },
        ]
    }
}
path.write_text(json.dumps(data, indent=2) + "\n")
print("injected sqlite3 3.5.2 offline sources into foreign.json")
PY

echo "Running ${FLATPAK_FLUTTER_IMAGE} ..."
docker run --rm \
  -v "${WORKDIR}:/usr/src/flatpak" \
  -u "$(id -u):$(id -g)" \
  "${FLATPAK_FLUTTER_IMAGE}" \
  flatpak-flutter.yaml

python3 - <<'PY'
from pathlib import Path

path = Path("xyz.nokarin.aqloss.yaml")
text = path.read_text()
marker = "modules:\n"
idx = text.find(marker)
if idx < 0:
    raise SystemExit("modules: not found in xyz.nokarin.aqloss.yaml")
head, tail = text[: idx + len(marker)], text[idx + len(marker) :]

tray = "  - shared-modules/libayatana-appindicator/libayatana-appindicator-gtk3.json\n"
# flatpak-builder strips the archive's top directory, so configure runs in place
ffmpeg = """  - name: ffmpeg
    buildsystem: simple
    build-commands:
      - |
        ./configure --disable-everything --disable-autodetect --disable-doc --disable-network --disable-debug --disable-avdevice --disable-swscale --disable-postproc --disable-asm --enable-small --enable-static --disable-shared --enable-ffmpeg --disable-ffprobe --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-avfilter --enable-protocol=file,pipe --enable-demuxer=mov --enable-decoder=ac3,eac3 --enable-muxer=pcm_f32le --enable-encoder=pcm_f32le --enable-filter=aresample --extra-cflags=-Os
        make -j$(nproc)
        install -Dm755 ffmpeg /app/bin/ffmpeg
    sources:
      - type: archive
        url: https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz
        sha256: 733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1
"""

extra = ""
if tray in tail:
    print("tray indicator module already present")
else:
    extra += tray
    print("added tray indicator module")
if "name: ffmpeg\n" in tail:
    print("ffmpeg module already present")
else:
    extra += ffmpeg
    print("added ffmpeg module")
path.write_text(head + extra + tail)
PY

python3 - "${AQLOSS_GIT}" <<'PY'
import sys
from pathlib import Path

url = sys.argv[1]
path = Path("flatpak-flutter.yaml")
text = path.read_text()
needle = f"url: {url}"
idx = text.find(needle)
if idx < 0:
    raise SystemExit(f"git url not found in flatpak-flutter.yaml: {url}")
after = idx + len(needle)
rest = text[after:]
if rest.startswith("\n        tag:"):
    end = rest.find("\n", 1)
    text = text[:after] + rest[end:]
    path.write_text(text)
PY

find generated -name '*.orig' -delete
find generated -name '*.rej' -delete

git add xyz.nokarin.aqloss.yaml flatpak-flutter.yaml generated foreign.json .gitmodules shared-modules
if git diff --cached --quiet; then
  echo "Flathub repo already matches ${TAG}; nothing to commit."
  existing="$(gh pr list --repo "${FLATHUB_REPO}" --head "${BRANCH}" --json url --jq '.[0].url // empty')"
  if [ -n "${existing}" ]; then
    echo "Existing PR: ${existing}"
  fi
  exit 0
fi

git config user.name "nokarin-dev"
git config user.email "github@nokarin.xyz"
git commit -m "update to ${TAG}"

if git ls-remote --exit-code origin "refs/heads/${BRANCH}" >/dev/null 2>&1; then
  git push --force-with-lease origin "HEAD:${BRANCH}"
else
  git push -u origin "HEAD:${BRANCH}"
fi

existing="$(gh pr list --repo "${FLATHUB_REPO}" --head "${BRANCH}" --json number --jq '.[0].number // empty')"
if [ -n "${existing}" ]; then
  echo "Updated existing PR #${existing}"
  gh pr view "${existing}" --repo "${FLATHUB_REPO}" --json url --jq .url
  exit 0
fi

gh pr create \
  --repo "${FLATHUB_REPO}" \
  --base "${FLATHUB_BASE}" \
  --head "${BRANCH}" \
  --title "update to ${TAG}" \
  --body "Update Aqloss on Flathub to **${TAG}**."
