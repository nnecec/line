# Makefile for Line

.PHONY: help test test-coverage build build-release lint format clean

help:
	@echo "Line 开发命令:"
	@echo "  make test           - 运行所有测试"
	@echo "  make test-coverage  - 运行测试并生成覆盖率报告"
	@echo "  make build          - Debug 构建"
	@echo "  make build-release  - Release 构建（无签名）"
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
