#!/bin/bash
# Sign Line-<version>.zip with Sparkle, update appcast.xml, open automation PR.
# Expects: RELEASE_TAG, APP_VERSION, APP_BUILD, SPARKLE_PRIVATE_KEY, GH_TOKEN, GITHUB_REPOSITORY
# Optional: ZIP_PATH (default dist/Line-$APP_VERSION.zip), DERIVED_DATA for sign_update

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

: "${RELEASE_TAG:?}"
: "${APP_VERSION:?}"
: "${APP_BUILD:?}"
: "${SPARKLE_PRIVATE_KEY:?}"
: "${GH_TOKEN:?}"
: "${GITHUB_REPOSITORY:?}"

ZIP_PATH="${ZIP_PATH:-dist/Line-${APP_VERSION}.zip}"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-26.0}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/dist/DerivedData}"
BRANCH="automation/appcast-${RELEASE_TAG}"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing zip for Sparkle enclosure: $ZIP_PATH" >&2
  exit 1
fi

SPARKLE_PUBLIC_ED_KEY=$(ruby scripts/release/read_xcconfig_value.rb Line/Config.xcconfig SPARKLE_PUBLIC_ED_KEY)
printf '%s' "$SPARKLE_PRIVATE_KEY" | \
  SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
  ruby scripts/release/verify_sparkle_key_pair.rb

# Resolve Sparkle packages if needed so sign_update exists
if [[ ! -d "$DERIVED_DATA/SourcePackages" ]]; then
  xcodebuild \
    -resolvePackageDependencies \
    -project Line.xcodeproj \
    -scheme Line \
    -derivedDataPath "$DERIVED_DATA"
fi

SIGN_UPDATE=$(find "$DERIVED_DATA/SourcePackages/artifacts" -path "*/Sparkle/bin/sign_update" -type f 2>/dev/null | head -1)
if [[ -z "$SIGN_UPDATE" ]]; then
  echo "Could not find Sparkle sign_update tool under $DERIVED_DATA" >&2
  exit 1
fi

SIGN_OUTPUT=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$ZIP_PATH")
ED_SIGNATURE=$(printf '%s\n' "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
ASSET_LENGTH=$(printf '%s\n' "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')
if [[ -z "$ED_SIGNATURE" || -z "$ASSET_LENGTH" ]]; then
  # Fallback: length from filesystem if tool output format differs
  ASSET_LENGTH=$(wc -c <"$ZIP_PATH" | tr -d ' ')
  ED_SIGNATURE=$(printf '%s\n' "$SIGN_OUTPUT" | sed -n 's/.*edSignature="\([^"]*\)".*/\1/p')
fi
test -n "$ED_SIGNATURE"
test -n "$ASSET_LENGTH"

PUBLISHED_AT=$(gh release view "$RELEASE_TAG" --json publishedAt --jq '.publishedAt // .createdAt')
if [[ -z "$PUBLISHED_AT" || "$PUBLISHED_AT" == "null" ]]; then
  PUB_DATE=$(date -u '+%a, %d %b %Y %H:%M:%S +0000')
else
  PUB_DATE=$(ruby -rtime -e 'puts Time.parse(ARGV.fetch(0)).rfc2822' "$PUBLISHED_AT")
fi

ZIP_BASENAME=$(basename "$ZIP_PATH")
RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/${RELEASE_TAG}/${ZIP_BASENAME}"

export APPCAST_PATH="${APPCAST_PATH:-appcast.xml}"
export APP_VERSION
export APP_BUILD
export MINIMUM_SYSTEM_VERSION
export RELEASE_URL
export ED_SIGNATURE
export ASSET_LENGTH
export PUB_DATE

ruby scripts/release/update_appcast.rb
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout appcast.xml
fi

if git diff --quiet -- appcast.xml; then
  echo "Appcast is already current for $RELEASE_TAG."
  exit 0
fi

verify_existing_appcast_branch() {
  git fetch origin "$BRANCH"
  BASE_SHA="${RELEASE_COMMIT:-$(gh release view "$RELEASE_TAG" --json targetCommitish --jq '.targetCommitish')}"
  # targetCommitish may be "main"; resolve tag commit
  TAG_SHA=$(git rev-list -n 1 "$RELEASE_TAG" 2>/dev/null || true)
  if [[ -n "$TAG_SHA" ]]; then
    BASE_SHA="$TAG_SHA"
  fi

  if ! git merge-base --is-ancestor "$BASE_SHA" FETCH_HEAD; then
    echo "Existing appcast branch is not based on the released commit." >&2
    exit 1
  fi

  CHANGED_FILES=$(git diff --name-only "$BASE_SHA" FETCH_HEAD)
  if [[ "$CHANGED_FILES" != "appcast.xml" ]]; then
    echo "Existing appcast branch contains changes outside appcast.xml." >&2
    exit 1
  fi

  if ! git diff --quiet FETCH_HEAD -- appcast.xml; then
    echo "Existing appcast branch does not match the generated feed." >&2
    exit 1
  fi
}

EXISTING_PR=$(gh pr list --head "$BRANCH" --base main --state open --json url --jq '.[0].url // empty')
if [[ -n "$EXISTING_PR" ]]; then
  verify_existing_appcast_branch
  echo "Appcast pull request already exists: $EXISTING_PR"
  exit 0
fi

if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  verify_existing_appcast_branch
  gh pr create \
    --base main \
    --head "$BRANCH" \
    --title "chore: publish appcast for $RELEASE_TAG" \
    --body "Publishes the Sparkle feed entry for $RELEASE_TAG after GitHub Release assets were published. Merge this PR so in-app updates can see the new version. Packages are not Apple-notarized."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git switch -c "$BRANCH"
git add appcast.xml
git commit -m "chore: publish appcast for $RELEASE_TAG"
gh auth setup-git
git push origin HEAD:"$BRANCH"

gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "chore: publish appcast for $RELEASE_TAG" \
  --body "Publishes the Sparkle feed entry for $RELEASE_TAG after GitHub Release assets were published.

- Enclosure: \`${ZIP_BASENAME}\` on Release ${RELEASE_TAG}
- Packages are **not** Apple Developer ID signed or notarized
- Merge this PR so Sparkle can discover the update via \`appcast.xml\` on \`main\`"
