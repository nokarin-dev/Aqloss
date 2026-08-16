#!/usr/bin/env bash
set -euo pipefail

# Overwrite the rolling "Apple Build" GitHub Release (tag apple-build).
# Triggered from a version tag (v1.0.1); does not create a new Apple release.

TAG="apple-build"
VERSION_TAG="${GITHUB_REF_NAME:?GITHUB_REF_NAME is required}"
SHA="${GITHUB_SHA:?GITHUB_SHA is required}"
SHORT="${SHA:0:8}"
DIST="${1:-dist}"

files=(
  "${DIST}/Aqloss-macos.dmg"
  "${DIST}/Aqloss-macos-portable.zip"
  "${DIST}/Aqloss-ios.ipa"
)

for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then
    echo "Missing artifact: $f" >&2
    find "${DIST}" -type f | sort || true
    exit 1
  fi
done

notes="$(cat <<EOF
Unsigned macOS and iOS builds. Files here are replaced on every stable tag; there is no per-version Apple history.

Current binaries match **${VERSION_TAG}** (\`${SHORT}\`).

**macOS** — unsigned. Gatekeeper will block it; right-click the app → Open.

- [Aqloss-macos.dmg](https://github.com/nokarin-dev/aqloss/releases/download/${TAG}/Aqloss-macos.dmg)
- [Aqloss-macos-portable.zip](https://github.com/nokarin-dev/aqloss/releases/download/${TAG}/Aqloss-macos-portable.zip)

**iOS** — unsigned IPA, sideload only.

- [Aqloss-ios.ipa](https://github.com/nokarin-dev/aqloss/releases/download/${TAG}/Aqloss-ios.ipa)

Windows / Linux / Android stay on [${VERSION_TAG}](https://github.com/nokarin-dev/aqloss/releases/tag/${VERSION_TAG}).
EOF
)"

git tag -f "${TAG}" "${SHA}"
if [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  git push -f "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "refs/tags/${TAG}"
else
  git push -f origin "refs/tags/${TAG}"
fi

if gh release view "${TAG}" >/dev/null 2>&1; then
  gh release edit "${TAG}" \
    --title "Apple Build" \
    --prerelease \
    --latest=false \
    --notes "${notes}"
  gh release upload "${TAG}" "${files[@]}" --clobber
else
  gh release create "${TAG}" "${files[@]}" \
    --title "Apple Build" \
    --prerelease \
    --latest=false \
    --notes "${notes}" \
    --target "${SHA}"
fi

echo "Updated ${TAG} from ${VERSION_TAG} (${SHORT})."
