#!/bin/bash

# Build a locally Development-signed DMG/ZIP for Accessibility testing.
# This is NOT a release artifact: no Developer ID, no notarization, no appcast.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT_DIR/dist"}
VERSION=${VERSION:-$(ruby scripts/release/read_xcconfig_value.rb Line/Config.xcconfig VERSION)}
BUILD_NUMBER=${BUILD_NUMBER:-$(git rev-list --count HEAD)}
CONFIGURATION=${CONFIGURATION:-Release}
SCHEME=${SCHEME:-Line}
PRODUCTS_DIR="$OUTPUT_DIR/DerivedData/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/Line.app"
DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-3F4PBYM8L4}

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  echo "VERSION must look like 1.2.3." >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
  CODE_SIGN_IDENTITY=$(
    security find-identity -v -p codesigning |
      sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' |
      head -n 1
  )
fi

if [[ -z "${CODE_SIGN_IDENTITY}" ]]; then
  echo "No Apple Development identity found." >&2
  echo "Add a free Apple ID in Xcode Settings → Accounts, create an Apple Development certificate," >&2
  echo "then re-run this script. Or set CODE_SIGN_IDENTITY explicitly." >&2
  exit 1
fi

# Automatic signing requires the generic identity name, not the full certificate string.
XCODE_SIGN_IDENTITY="Apple Development"
if [[ "$CODE_SIGN_IDENTITY" == Developer\ ID\ Application* ]]; then
  XCODE_SIGN_IDENTITY="Developer ID Application"
fi

echo "Using identity: $CODE_SIGN_IDENTITY"
echo "Using team: $DEVELOPMENT_TEAM"

rm -rf \
  "$OUTPUT_DIR/dmg-root" \
  "$OUTPUT_DIR/Line-local.dmg" \
  "$OUTPUT_DIR/Line-local.zip" \
  "$OUTPUT_DIR/SHA256SUMS-local.txt"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project Line.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$OUTPUT_DIR/DerivedData" \
  VERSION="$VERSION" \
  BUILD_NUMBER="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="$XCODE_SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  build

test -d "$APP_PATH"
ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
ACTUAL_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")
test "$ACTUAL_VERSION" = "$VERSION"
test "$ACTUAL_BUILD" = "$BUILD_NUMBER"

codesign --verify --deep --strict "$APP_PATH"

SIGNING_INFO=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)
echo "$SIGNING_INFO"

if echo "$SIGNING_INFO" | grep -q 'Signature=adhoc'; then
  echo "App is still ad hoc signed; Accessibility permission will be unstable." >&2
  exit 1
fi

if ! echo "$SIGNING_INFO" | grep -q 'Authority=Apple Development'; then
  echo "Expected an Apple Development authority on the signed app." >&2
  exit 1
fi

DESIGNATED_REQUIREMENT=$(codesign -dr - "$APP_PATH" 2>&1)
echo "$DESIGNATED_REQUIREMENT"

if ! echo "$DESIGNATED_REQUIREMENT" | grep -q 'identifier "com.nnecec.Line"'; then
  echo "Designated requirement is missing the app identifier." >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_DIR/Line-local.zip"

mkdir -p "$OUTPUT_DIR/dmg-root"
ditto "$APP_PATH" "$OUTPUT_DIR/dmg-root/Line.app"
ln -sf /Applications "$OUTPUT_DIR/dmg-root/Applications"

hdiutil create \
  -volname Line \
  -srcfolder "$OUTPUT_DIR/dmg-root" \
  -format UDZO \
  -ov \
  "$OUTPUT_DIR/Line-local.dmg"

(
  cd "$OUTPUT_DIR"
  shasum -a 256 Line-local.zip Line-local.dmg > SHA256SUMS-local.txt
)

echo
echo "Local Development-signed packages created in $OUTPUT_DIR:"
echo "  Line-local.dmg"
echo "  Line-local.zip"
echo "  SHA256SUMS-local.txt"
echo
echo "Install to /Applications, then reset stale TCC rows before re-granting Accessibility:"
echo "  ditto \"$APP_PATH\" /Applications/Line.app"
echo "  tccutil reset Accessibility com.nnecec.Line"
echo
echo "These packages are for local Accessibility testing only."
echo "They are not notarized and must not replace official Developer ID releases."
