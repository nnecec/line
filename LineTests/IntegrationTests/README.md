# 集成测试文档

## 概述

`IntegrationTests/` 目录包含端到端集成测试，验证从触发器到窗口操作的完整流程。

## 测试特点

### 依赖项

这些测试需要：

- **Accessibility 权限**（必需）：测试需要真实的窗口操作权限
- **前台应用窗口**：需要至少一个可操作的窗口
- **系统状态**：测试结果可能受全屏、Stage Manager 等影响
- **屏幕配置**：某些测试假设有主屏幕

### 不稳定性因素

集成测试可能因以下原因不稳定：

1. **窗口状态变化**：其他应用或用户操作可能改变窗口状态
2. **系统干扰**：通知、弹窗等可能影响测试
3. **时间依赖**：异步操作可能导致竞态条件
4. **权限状态**：Accessibility 权限可能在运行时改变

### 测试覆盖

当前集成测试覆盖：

- **键绑定到窗口移动流程**：验证 action 应用后窗口确实移动
- **快速动作流程**：测试 minimize、hide 等无需帧计算的 action
- **Focus 动作流程**：验证窗口焦点切换
- **错误传播**：验证错误在完整栈中正确传播
- **多动作序列**：测试连续执行多个 action
- **边界条件**：测试 noOp、无效窗口等场景

## 运行测试

### 本地运行

```bash
# 运行所有集成测试
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/EndToEndIntegrationTests

# 运行特定测试
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/EndToEndIntegrationTests/testKeybindTriggersWindowResize
```

### 最佳实践

1. **干净环境**：关闭不必要的应用，减少干扰
2. **单独运行**：集成测试最好单独运行，不要与单元测试混合
3. **重试机制**：失败的测试可能需要重试
4. **权限检查**：确保 Accessibility 权限已授予

### CI 环境

在 CI 中运行集成测试需要特殊配置：

- CI 环境可能没有 Accessibility 权限
- 某些测试可能需要跳过（使用 `XCTSkip`）
- 建议使用专门的测试环境或模拟窗口

## 测试限制

### 自动化限制

以下流程难以完全自动化，需要手动测试：

1. **完整键盘快捷键流程**：真实的键盘事件模拟复杂
2. **鼠标拖拽捕捉**：CGEvent 模拟不够可靠
3. **Grid 覆盖层 UI**：UI 交互需要 XCUITest
4. **多显示器场景**：需要真实的多显示器设置
5. **全屏应用交互**：全屏模式行为特殊

### 覆盖范围界限

**集成测试的职责**：

- 验证"快乐路径"端到端流程
- 验证组件间集成正确
- 捕获真实使用场景中的问题

**不是集成测试的职责**：

- 详尽的边缘情况测试（由单元测试覆盖）
- UI 交互细节（需要 XCUITest）
- 性能基准测试（需要专门的性能测试）

## 维护指南

### 添加新测试

添加新的集成测试时：

1. 遵循现有测试结构和命名约定
2. 使用 `XCTSkip` 处理缺失的依赖
3. 在测试前后清理状态（如果可能）
4. 添加清晰的注释说明测试目的

### 处理不稳定测试

如果测试不稳定：

1. 识别不稳定的根本原因
2. 添加适当的延迟或重试逻辑
3. 考虑将测试标记为手动测试
4. 记录已知的不稳定因素

### 未来改进

可能的改进方向：

1. **专用测试应用**：创建一个简单的测试应用，状态可预测
2. **XCUITest 集成**：使用 XCUITest 进行真实 UI 交互测试
3. **性能基准**：添加性能回归测试
4. **多环境支持**：测试多显示器、全屏、Stage Manager 等场景

## 相关文档

- `WindowActionEngineTests.swift`：并发和取消测试
- `SessionManagerTests.swift`：会话管理单元测试
- `LineCoordinatorPolicyTests.swift`：协调器策略测试
- 计划文档 `plans/012-end-to-end-tests.md`
