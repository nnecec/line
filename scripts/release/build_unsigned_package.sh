#!/bin/bash
# Back-compat wrapper. Prefer scripts/release/build_package.sh.
# Emits Line-<VERSION>.zip / .dmg (not Line-unsigned.*).

set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
exec "$ROOT_DIR/scripts/release/build_package.sh" "$@"
