#!/usr/bin/env bash
# Fail CI when core geometry calculators drop below a coverage floor.
# Usage: scripts/ci/check_calculator_coverage.sh TestResults.xcresult

set -euo pipefail

RESULT_BUNDLE="${1:-TestResults.xcresult}"
# Floor is intentionally modest: these files already have dedicated unit tests.
# Raise it when calculator tests expand; do not lower it to paper over regressions.
MIN_LINE_PERCENT="${CALCULATOR_COVERAGE_MIN:-50}"

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "error: result bundle not found: $RESULT_BUNDLE" >&2
  exit 1
fi

REPORT_JSON=$(mktemp)
trap 'rm -f "$REPORT_JSON"' EXIT

xcrun xccov view --report --json "$RESULT_BUNDLE" >"$REPORT_JSON"

python3 - "$REPORT_JSON" "$MIN_LINE_PERCENT" <<'PY'
import json
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
min_percent = float(sys.argv[2])

# Paths as reported by xccov (suffix match).
required_suffixes = (
    "Window Management/Window Action/WindowActionCalculator.swift",
    "Window Management/Window Action/CustomWindowActionCalculator.swift",
    "Window Management/Window Action/SpecialActionCalculator.swift",
    "Grid Layout/GridGeometry.swift",
)

data = json.loads(report_path.read_text())
files = {}

def walk(node):
    if isinstance(node, dict):
        path = node.get("path") or node.get("name")
        if path and str(path).endswith(".swift"):
            files[str(path)] = node
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(data)

def line_coverage(node):
    # xccov JSON shapes vary slightly by Xcode version.
    for key in ("lineCoverage", "lineCoveragePercentage"):
        if key in node and node[key] is not None:
            value = float(node[key])
            return value * 100.0 if value <= 1.0 else value
    covered = node.get("coveredLines")
    executable = node.get("executableLines")
    if covered is not None and executable:
        return 100.0 * float(covered) / float(executable)
    return None

missing = []
below = []
ok = []

for suffix in required_suffixes:
    match = next((path for path in files if path.endswith(suffix) or path.replace("\\", "/").endswith(suffix)), None)
    if match is None:
        missing.append(suffix)
        continue
    percent = line_coverage(files[match])
    if percent is None:
        missing.append(f"{suffix} (no line coverage fields)")
        continue
    label = f"{suffix}: {percent:.1f}%"
    if percent + 1e-9 < min_percent:
        below.append(label)
    else:
        ok.append(label)

print("=== Calculator coverage gate ===")
print(f"minimum line coverage: {min_percent:.0f}%")
for line in ok:
    print(f"PASS  {line}")
for line in below:
    print(f"FAIL  {line}")
for line in missing:
    print(f"MISS  {line}")

if missing or below:
    sys.exit(1)
print("All calculator coverage floors met.")
PY
