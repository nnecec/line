#!/bin/bash
# Back-compat wrapper for unsigned packages (no stable Accessibility TCC).
# Prefer scripts/release/build_package.sh for public releases.

set -euo pipefail
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
export ALLOW_UNSIGNED=1
exec "$ROOT_DIR/scripts/release/build_package.sh" "$@"
