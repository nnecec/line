#!/bin/bash
# semantic-release prepareCmd: build installable packages for the next version.
set -euo pipefail

VERSION="${1:-${nextRelease_version:-}}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: sr_prepare.sh <version>" >&2
  exit 1
fi

export VERSION
export BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
export OUTPUT_DIR="${OUTPUT_DIR:-dist}"

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
"$ROOT_DIR/scripts/release/build_package.sh"

# Record for later workflow steps (appcast / summary)
mkdir -p "$ROOT_DIR/dist"
{
  echo "VERSION=$VERSION"
  echo "BUILD_NUMBER=$BUILD_NUMBER"
  echo "RELEASE_TAG=v$VERSION"
  echo "ZIP_NAME=Line-${VERSION}.zip"
  echo "DMG_NAME=Line-${VERSION}.dmg"
} | tee "$ROOT_DIR/dist/release-meta.env"
