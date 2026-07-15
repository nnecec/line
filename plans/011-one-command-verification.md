# 011: 一键验证基础设施

**状态**: TODO  
**优先级**: P0（快速胜利，测试基础设施）  
**发现**: COV-15  
**基准 commit**: 79ff450  
**工作量估算**: S（1小时）  
**风险**: LOW

---

## 问题

没有文档化的一键命令来运行所有测试和报告覆盖率。贡献者和 CI 缺乏标准化验证流程。

**当前状态**:
- 测试命令分散在 README 和 CONTRIBUTING.md
- 无覆盖率报告生成
- 无简单的 "make test" 等价物

---

## 实施计划

### 第 1 步：创建 Makefile

在项目根目录创建 `Makefile`:

```makefile
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
```

---

### 第 2 步：更新 README.md

在 README.md 的 "Build and test" 部分添加：

```markdown
## Build and test

**快速开始**:

```bash
# 运行所有测试
make test

# 运行测试并查看覆盖率
make test-coverage

# Debug 构建
make build

# 查看所有命令
make help
```

**详细命令** (如果不使用 Makefile):

```bash
# 现有的详细命令...
```
```

---

### 第 3 步：更新 CONTRIBUTING.md

在 CONTRIBUTING.md 的 "Build and test" 部分更新：

```markdown
## Build and test

在提交 PR 前运行完整验证：

```bash
make test           # 所有测试
make lint           # SwiftFormat 检查
make build-release  # Release 构建验证
```

或使用详细命令：

```bash
# 现有命令...
```
```

---

### 第 4 步：添加覆盖率脚本

创建 `scripts/coverage-report.sh`:

```bash
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
```

```bash
chmod +x scripts/coverage-report.sh
```

---

### 第 5 步：测试 Makefile

```bash
# 测试每个目标
make help
make test
make test-coverage
make lint
make clean
```

**预期**: 所有命令正常工作

---

### 第 6 步：添加 CI 验证

如果项目有 GitHub Actions，确保 CI 使用这些命令。在 `.github/workflows/ci.yml` 中：

```yaml
- name: Run tests
  run: make test

- name: Check format
  run: make lint
```

---

## 验证标准

### 手动测试

```bash
# 1. 运行测试
make test
# 应该: 运行所有测试，显示结果

# 2. 覆盖率
make test-coverage
# 应该: 显示覆盖率百分比

# 3. 帮助
make help
# 应该: 显示所有可用命令

# 4. 构建
make build
# 应该: 成功构建

# 5. Lint
make lint
# 应该: 显示格式问题（如果有）
```

---

## 范围界限

**包含**:
- Makefile 创建
- README 和 CONTRIBUTING 更新
- 覆盖率报告脚本

**不包含**:
- 修改现有测试
- CI 配置大改（只是使用新命令）
- 覆盖率阈值强制（可选后续）

---

## 维护说明

**Makefile 优势**:
- 单一入口点
- 一致的命令跨环境
- 易于扩展

**未来增强**:
- 添加 `make watch-test`（持续测试）
- 添加覆盖率阈值检查
- 添加性能基准测试目标

**相关计划**:
- 所有测试计划受益于此基础设施
