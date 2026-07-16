# Makefile for Line

.PHONY: help test test-coverage build build-release package-local lint format clean

help:
	@echo "Line 开发命令:"
	@echo "  make test           - 运行所有测试"
	@echo "  make test-coverage  - 运行测试并生成覆盖率报告"
	@echo "  make build          - Debug 构建"
	@echo "  make build-release  - Release 构建（无签名）"
	@echo "  make package-local  - 本地 Development 签名 DMG（测辅助功能用）"
	@echo "  make lint           - 运行 SwiftFormat 检查"
	@echo "  make format         - 格式化代码"
	@echo "  make clean          - 清理构建产物"

# 运行所有测试
test:
	xcodebuild test \
		-project Line.xcodeproj \
		-scheme Line \
		-destination 'platform=macOS'

# 运行测试并生成覆盖率
test-coverage:
	xcodebuild test \
		-project Line.xcodeproj \
		-scheme Line \
		-destination 'platform=macOS' \
		-enableCodeCoverage YES \
		-resultBundlePath TestResults.xcresult
	@echo "\n生成覆盖率报告..."
	xcrun xccov view --report TestResults.xcresult

# Debug 构建
build:
	xcodebuild \
		-project Line.xcodeproj \
		-scheme Line \
		-configuration Debug \
		CODE_SIGNING_ALLOWED=NO \
		build

# Release 构建（无签名）
build-release:
	xcodebuild \
		-project Line.xcodeproj \
		-scheme "Line (GH ACTIONS)" \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		CODE_SIGNING_ALLOWED=NO \
		build

# 本地 Development 签名 DMG（测辅助功能；非正式发布）
# 用法: make package-local
# 或:   make package-local VERSION=0.0.1
package-local:
	scripts/release/build_local_signed_package.sh

# Lint 检查
lint:
	mint run swiftformat --lint . --reporter github-actions-log

# 格式化代码
format:
	mint run swiftformat .

# 清理
clean:
	rm -rf DerivedData
	rm -rf TestResults.xcresult
	xcodebuild clean \
		-project Line.xcodeproj \
		-scheme Line
