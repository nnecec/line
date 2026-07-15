#!/bin/bash
# 生成详细的覆盖率报告

set -e

echo "运行测试并生成覆盖率..."
xcodebuild test \
    -project Line.xcodeproj \
    -scheme Line \
    -destination 'platform=macOS' \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults.xcresult

echo ""
echo "=== 覆盖率报告 ==="
xcrun xccov view --report TestResults.xcresult

echo ""
echo "=== 文件级覆盖率 ==="
xcrun xccov view --report --files-for-target Line.app TestResults.xcresult | \
    grep -E "\.swift" | \
    sort -k2 -rn | \
    head -20

echo ""
echo "完整报告位于: TestResults.xcresult"
echo "在 Xcode 中打开: open TestResults.xcresult"
