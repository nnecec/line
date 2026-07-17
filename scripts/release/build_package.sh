#!/bin/bash
# Build installable packages:
#   dist/Line-<VERSION>.zip
#   dist/Line-<VERSION>.dmg
#   dist/SHA256SUMS.txt
#
# Default: Apple Development–signed (stable Accessibility TCC).
# Set ALLOW_UNSIGNED=1 to skip signing (verification / CI compile checks only).
#
# Requires VERSION (x.y.z) and optional BUILD_NUMBER (default: git commit count).
# Optional: CODE_SIGN_IDENTITY, DEVELOPMENT_TEAM.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT_DIR/dist"}
VERSION=${VERSION:-$(ruby scripts/release/read_xcconfig_value.rb Line/Config.xcconfig VERSION)}
BUILD_NUMBER=${BUILD_NUMBER:-$(git rev-list --count HEAD)}
CONFIGURATION=Release
PRODUCTS_DIR="$OUTPUT_DIR/DerivedData/Build/Products/$CONFIGURATION"
APP_PATH="$PRODUCTS_DIR/Line.app"
ZIP_NAME="Line-${VERSION}.zip"
DMG_NAME="Line-${VERSION}.dmg"
ALLOW_UNSIGNED=${ALLOW_UNSIGNED:-0}
DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-3F4PBYM8L4}
ENTITLEMENTS="$ROOT_DIR/Line/Line.entitlements"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  echo "VERSION must look like 1.2.3." >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

resolve_development_identity() {
  if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$CODE_SIGN_IDENTITY"
    return 0
  fi

  security find-identity -v -p codesigning |
    sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' |
    head -n 1
}

sign_app_development() {
  local identity="$1"
  local nested

  echo "Signing with: $identity (team $DEVELOPMENT_TEAM)"

  # Sign nested Mach-O first, then the app bundle (stable DR for Accessibility).
  while IFS= read -r nested; do
    [[ -n "$nested" ]] || continue
    codesign --force --options runtime --timestamp=none --sign "$identity" "$nested"
  done < <(
    find "$APP_PATH/Contents" \
      \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' -o -name '*.xpc' -o -name '*.plugin' \) \
      2>/dev/null |
      sort -r
  )

  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --options runtime --timestamp=none \
      --entitlements "$ENTITLEMENTS" \
      --sign "$identity" \
      "$APP_PATH"
  else
    codesign --force --options runtime --timestamp=none \
      --sign "$identity" \
      "$APP_PATH"
  fi

  codesign --verify --deep --strict "$APP_PATH"

  local signing_info designated
  signing_info=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)
  echo "$signing_info"

  if echo "$signing_info" | grep -q 'Signature=adhoc'; then
    echo "App is still ad hoc signed; Accessibility permission will be unstable." >&2
    exit 1
  fi

  if ! echo "$signing_info" | grep -q 'Authority=Apple Development'; then
    echo "Expected an Apple Development authority on the signed app." >&2
    exit 1
  fi

  designated=$(codesign -dr - "$APP_PATH" 2>&1)
  echo "$designated"

  if ! echo "$designated" | grep -q 'identifier "com.nnecec.Line"'; then
    echo "Designated requirement is missing the app identifier." >&2
    exit 1
  fi
}

rm -rf \
  "$OUTPUT_DIR/dmg-root" \
  "$OUTPUT_DIR/$ZIP_NAME" \
  "$OUTPUT_DIR/$DMG_NAME" \
  "$OUTPUT_DIR/SHA256SUMS.txt"
# Remove legacy asset names if present
rm -f \
  "$OUTPUT_DIR/Line-unsigned.zip" \
  "$OUTPUT_DIR/Line-unsigned.dmg"
mkdir -p "$OUTPUT_DIR"

# Build unsigned, then apply Development signature. Avoids Automatic signing /
# Apple portal access on CI (free Apple ID + imported .p12 is enough).
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

if [[ "$ALLOW_UNSIGNED" == "1" ]]; then
  echo "ALLOW_UNSIGNED=1: skipping code signature (Accessibility will be unstable)."
else
  IDENTITY=$(resolve_development_identity)
  if [[ -z "$IDENTITY" ]]; then
    echo "No Apple Development identity found." >&2
    echo "Import a Development .p12 (CI secrets) or create a certificate in Xcode," >&2
    echo "or set CODE_SIGN_IDENTITY. For unsigned packages only, set ALLOW_UNSIGNED=1." >&2
    exit 1
  fi
  sign_app_development "$IDENTITY"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_DIR/$ZIP_NAME"

mkdir -p "$OUTPUT_DIR/dmg-root"
ditto "$APP_PATH" "$OUTPUT_DIR/dmg-root/Line.app"
ln -sf /Applications "$OUTPUT_DIR/dmg-root/Applications"

hdiutil create \
  -volname Line \
  -srcfolder "$OUTPUT_DIR/dmg-root" \
  -format UDZO \
  -ov \
  "$OUTPUT_DIR/$DMG_NAME"

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ZIP_NAME" "$DMG_NAME" >SHA256SUMS.txt
)

echo "Packages created in $OUTPUT_DIR:"
echo "  $ZIP_NAME"
echo "  $DMG_NAME"
echo "  SHA256SUMS.txt"
