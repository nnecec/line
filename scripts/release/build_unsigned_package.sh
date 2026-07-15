#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT_DIR/dist"}
VERSION=${VERSION:-$(ruby scripts/release/read_xcconfig_value.rb Line/Config.xcconfig VERSION)}
BUILD_NUMBER=${BUILD_NUMBER:-$(git rev-list --count HEAD)}
CONFIGURATION=Release
PRODUCTS_DIR="$OUTPUT_DIR/DerivedData/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/Line.app"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  echo "VERSION must look like 1.2.3." >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

rm -rf \
  "$OUTPUT_DIR/dmg-root" \
  "$OUTPUT_DIR/Line-unsigned.dmg" \
  "$OUTPUT_DIR/Line-unsigned.zip" \
  "$OUTPUT_DIR/SHA256SUMS.txt"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project Line.xcodeproj \
  -scheme "Line (GH ACTIONS)" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$OUTPUT_DIR/DerivedData" \
  VERSION="$VERSION" \
  BUILD_NUMBER="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

test -d "$APP_PATH"
ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
ACTUAL_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")
test "$ACTUAL_VERSION" = "$VERSION"
test "$ACTUAL_BUILD" = "$BUILD_NUMBER"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_DIR/Line-unsigned.zip"

mkdir -p "$OUTPUT_DIR/dmg-root"
ditto "$APP_PATH" "$OUTPUT_DIR/dmg-root/Line.app"
ln -s /Applications "$OUTPUT_DIR/dmg-root/Applications"

hdiutil create \
  -volname Line \
  -srcfolder "$OUTPUT_DIR/dmg-root" \
  -format UDZO \
  -ov \
  "$OUTPUT_DIR/Line-unsigned.dmg"

(
  cd "$OUTPUT_DIR"
  shasum -a 256 Line-unsigned.zip Line-unsigned.dmg > SHA256SUMS.txt
)

echo "Unsigned packages created in $OUTPUT_DIR:"
echo "  Line-unsigned.dmg"
echo "  Line-unsigned.zip"
echo "  SHA256SUMS.txt"
