# Makefile for Line

.PHONY: help test test-unit test-integration test-coverage build build-release package-local lint format clean

help:
	@echo "Line development commands:"
	@echo "  make test              - unit + integration (integration may XCTSkip)"
	@echo "  make test-unit         - unit tests only (required CI path)"
	@echo "  make test-integration  - EndToEndIntegrationTests only"
	@echo "  make test-coverage     - unit tests + report + calculator coverage floor"
	@echo "  make build             - Debug build"
	@echo "  make build-release     - unsigned Release configuration"
	@echo "  make package-local     - local Development-signed DMG (Accessibility testing)"
	@echo "  make lint              - SwiftFormat check"
	@echo "  make format            - SwiftFormat write"
	@echo "  make clean             - remove local build products"

# All tests in the Line scheme (integration cases XCTSkip without Accessibility)
test:
	xcodebuild test \
		-project Line.xcodeproj \
		-scheme Line \
		-destination 'platform=macOS'

# Matches the required CI unit job
test-unit:
	xcodebuild test \
		-project Line.xcodeproj \
		-scheme Line \
		-destination 'platform=macOS' \
		-skip-testing:LineTests/EndToEndIntegrationTests

# Real-window path; expected to skip on CI runners without Accessibility
test-integration:
	xcodebuild test \
		-project Line.xcodeproj \
		-scheme Line \
		-destination 'platform=macOS' \
		-only-testing:LineTests/EndToEndIntegrationTests

# Unit coverage + calculator floor (same gate as CI)
test-coverage:
	rm -rf TestResults.xcresult
	xcodebuild test \
		-project Line.xcodeproj \
		-scheme Line \
		-destination 'platform=macOS' \
		-skip-testing:LineTests/EndToEndIntegrationTests \
		-enableCodeCoverage YES \
		-resultBundlePath TestResults.xcresult
	@echo "\nCoverage report:"
	xcrun xccov view --report TestResults.xcresult
	scripts/ci/check_calculator_coverage.sh TestResults.xcresult

# Debug build
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

# 无 Developer ID 的可分发包（与 Publish 产物命名一致）
# 用法: make package VERSION=0.1.0
package:
	scripts/release/build_package.sh

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
