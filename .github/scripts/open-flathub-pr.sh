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
gh repo clone "${FLATHUB_REPO}" "${WORKDIR}" -- --branch "${FLATHUB_BASE}" --single-branch
cd "${WORKDIR}"

git checkout -B "${BRANCH}" "${FLATHUB_BASE}"

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


text = upsert_tag(text, aqloss_url, aqloss_tag)
text = upsert_tag(text, "https://github.com/flutter/flutter.git", flutter_tag)
path.write_text(text)
print(f"generate from {aqloss_url} {aqloss_tag}, Flutter {flutter_tag}")
PY

echo "Running ${FLATPAK_FLUTTER_IMAGE} ..."
docker run --rm \
  -v "${WORKDIR}:/usr/src/flatpak" \
  -u "$(id -u):$(id -g)" \
  "${FLATPAK_FLUTTER_IMAGE}" \
  flatpak-flutter.yaml

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

git add xyz.nokarin.aqloss.yaml flatpak-flutter.yaml generated
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
