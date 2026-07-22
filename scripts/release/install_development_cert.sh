#!/bin/bash
# Import an Apple Development certificate (.p12, base64) into a temporary keychain.
# Used by Publish CI so build_package.sh can Development-sign release assets.
#
# Required env:
#   APPLE_DEVELOPMENT_CERT_BASE64  — PKCS#12 certificate + private key, base64
#   P12_PASSWORD                   — password for the .p12
#   KEYCHAIN_PASSWORD              — password for the temporary keychain
#
# Optional:
#   KEYCHAIN_PATH                  — default: $RUNNER_TEMP/line-development.keychain-db
#
# After the signing job finishes, runners should delete the temporary keychain:
#   security delete-keychain "$KEYCHAIN_PATH"

set -euo pipefail

test -n "${APPLE_DEVELOPMENT_CERT_BASE64:-}" || {
  echo "APPLE_DEVELOPMENT_CERT_BASE64 is required." >&2
  exit 1
}
test -n "${P12_PASSWORD:-}" || {
  echo "P12_PASSWORD is required." >&2
  exit 1
}
test -n "${KEYCHAIN_PASSWORD:-}" || {
  echo "KEYCHAIN_PASSWORD is required." >&2
  exit 1
}

CERTIFICATE_PATH="${CERTIFICATE_PATH:-${RUNNER_TEMP:-/tmp}/apple-development.p12}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-${RUNNER_TEMP:-/tmp}/line-development.keychain-db}"

cleanup() {
  rm -f "$CERTIFICATE_PATH"
}
trap cleanup EXIT

printf '%s' "$APPLE_DEVELOPMENT_CERT_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"

security delete-keychain "$KEYCHAIN_PATH" 2>/dev/null || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
# Prefer narrow trusted apps over unrestricted -A; partition-list still applied below.
security import "$CERTIFICATE_PATH" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productbuild \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH" $(security list-keychain -d user | sed -e s/\"//g)

IDENTITY=$(
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" |
    sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' |
    head -n 1
)

if [[ -z "$IDENTITY" ]]; then
  echo "Imported keychain has no Apple Development identity." >&2
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" >&2 || true
  exit 1
fi

echo "Imported Development identity: $IDENTITY"
echo "KEYCHAIN_PATH=$KEYCHAIN_PATH"
