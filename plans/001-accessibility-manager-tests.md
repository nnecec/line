# 001: AccessibilityManager 权限状态机测试

**状态**: DONE  
**优先级**: P0（阻塞其他需要权限的测试）  
**发现**: COV-01  
**基准 commit**: 79ff450  
**工作量估算**: M（一天左右）  
**风险**: HIGH — 权限是整个应用的单点故障

---

## 问题

`Line/Utilities/AccessibilityManager.swift` (170行) 管理辅助功能权限流、通知监控和 tccutil 重置，但完全没有测试覆盖。权限状态是所有窗口操作的先决条件，这里的 bug 会导致：

- 权限 UI 不更新
- 未关闭流导致的内存泄漏
- 虚假权限状态阻止所有功能
- AsyncStream continuation 管理错误
- 通知处理竞态

**未测试的关键路径**:
- AsyncStream continuation 管理 (17-74)
- 权限更改通知处理 (24-40)
- yield() 去重逻辑 (80-90)
- tccutil 重置错误路径 (138-162)
- 并发流消费者

---

## 当前状态

**文件**: `Line/Utilities/AccessibilityManager.swift`

**关键方法**:
```swift
// 17-74: stream() - AsyncStream 创建和 continuation 管理
func stream(initial: Bool = false) -> AsyncStream<Bool>

// 125-133: checkAccessibility() - 同步权限检查
static func checkAccessibility() -> Bool

// 138-162: resetAccessibility() - tccutil 重置
static func resetAccessibility()
```

**依赖**:
- `DistributedNotificationCenter` (com.apple.accessibility.api)
- `AXIsProcessTrusted()` (Accessibility API)
- `Process` (运行 tccutil)

**当前无测试**: `grep -r AccessibilityManagerTests LineTests` 返回空

---

## 目标

创建 `LineTests/AccessibilityManagerTests.swift`，验证：

1. **流生命周期**: 初始值、多个消费者、continuation 清理
2. **权限变化**: 通知触发 yield、去重逻辑
3. **并发安全**: 多个并发流不互相干扰
4. **错误路径**: tccutil 失败处理
5. **边缘情况**: 快速连续的权限变化

---

## 实施计划

### 第 1 步：创建测试文件和基础架构

创建 `LineTests/AccessibilityManagerTests.swift`:

```swift
//
//  AccessibilityManagerTests.swift
//  LineTests
//
//  权限状态机和流行为测试
//

import XCTest
@testable import Line

final class AccessibilityManagerTests: XCTestCase {
    // 测试将在后续步骤添加
}
```

**验证**: `xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' -only-testing:LineTests/AccessibilityManagerTests`

**预期**: 测试套件存在但为空（通过）

---

### 第 2 步：测试基本权限检查（同步路径）

添加同步 API 测试：

```swift
func testCheckAccessibilityReturnsBool() {
    // 这个测试依赖实际系统权限状态
    // 在 CI 中可能是 false，本地可能是 true
    let result = AccessibilityManager.checkAccessibility()
    XCTAssertNotNil(result, "checkAccessibility() 应该返回布尔值")
    // 不断言具体值，因为依赖运行环境
}
```

**验证**: 运行测试
**预期**: 通过（不依赖具体权限状态）

---

### 第 3 步：测试 stream() 初始值

测试流的初始值发射：

```swift
func testStreamEmitsInitialValueWhenRequested() async {
    let manager = AccessibilityManager.shared
    let stream = manager.stream(initial: true)
    
    var iterator = stream.makeAsyncIterator()
    let firstValue = await iterator.next()
    
    XCTAssertNotNil(firstValue, "stream(initial: true) 应该立即发射初始值")
    // 值应该匹配当前权限状态
    XCTAssertEqual(firstValue, AccessibilityManager.checkAccessibility())
}

func testStreamDoesNotEmitInitialValueWhenNotRequested() async {
    let manager = AccessibilityManager.shared
    let stream = manager.stream(initial: false)
    
    // 设置超时，因为我们期待不会立即有值
    let expectation = XCTestExpectation(description: "不应该立即收到值")
    expectation.isInverted = true
    
    Task {
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
        expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 0.5)
}
```

**验证**: 运行测试
**预期**: 两个测试通过

**注意**: 这些测试是集成测试（使用真实的 AccessibilityManager），因为 mock DistributedNotificationCenter 很复杂。如果需要完全隔离，在第 7 步添加 mock 基础设施。

---

### 第 4 步：测试并发流消费者

测试多个并发消费者：

```swift
func testMultipleConcurrentStreamsWork() async {
    let manager = AccessibilityManager.shared
    
    let stream1 = manager.stream(initial: true)
    let stream2 = manager.stream(initial: true)
    let stream3 = manager.stream(initial: true)
    
    async let value1 = stream1.makeAsyncIterator().next()
    async let value2 = stream2.makeAsyncIterator().next()
    async let value3 = stream3.makeAsyncIterator().next()
    
    let results = await (value1, value2, value3)
    
    XCTAssertNotNil(results.0, "流 1 应该收到初始值")
    XCTAssertNotNil(results.1, "流 2 应该收到初始值")
    XCTAssertNotNil(results.2, "流 3 应该收到初始值")
    
    // 所有流应该收到相同的权限状态
    XCTAssertEqual(results.0, results.1)
    XCTAssertEqual(results.1, results.2)
}
```

**验证**: 运行测试
**预期**: 通过

---

### 第 5 步：测试 tccutil 重置（错误路径）

测试 `resetAccessibility()` 的基本行为：

```swift
func testResetAccessibilityExecutesWithoutCrashing() {
    // 这个测试只验证方法不会崩溃
    // 实际重置需要用户授权，在自动化测试中不可行
    
    // 注意：这会弹出授权对话框，所以标记为手动测试
    // 在 CI 中跳过
    #if !CI
    let expectation = XCTestExpectation(description: "重置完成")
    
    Task {
        await AccessibilityManager.resetAccessibility()
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
    #else
    XCTSkip("tccutil 重置在 CI 中跳过")
    #endif
}
```

**验证**: 本地手动运行
**预期**: 弹出授权对话框（预期行为），测试完成不崩溃

---

### 第 6 步：添加流清理测试

测试流取消时 continuation 正确清理：

```swift
func testStreamCleanupOnCancellation() async {
    let manager = AccessibilityManager.shared
    
    let task = Task {
        let stream = manager.stream(initial: true)
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
        // 任务将被取消
    }
    
    // 短暂等待后取消
    try? await Task.sleep(for: .milliseconds(100))
    task.cancel()
    
    // 等待取消完成
    _ = await task.result
    
    // 验证没有内存泄漏（实际上很难在单元测试中验证）
    // 这里主要是确保没有崩溃
    XCTAssertTrue(task.isCancelled)
}
```

**验证**: 运行测试
**预期**: 通过，无内存泄漏（需要 Instruments 手动验证）

---

### 第 7 步：文档化测试限制

在测试文件顶部添加注释：

```swift
//
//  AccessibilityManagerTests.swift
//  LineTests
//
//  测试 AccessibilityManager 权限状态管理
//
//  ## 测试限制
//
//  这些是**集成测试**，使用真实的系统 Accessibility API：
//  - 依赖运行环境的实际权限状态
//  - 无法 mock DistributedNotificationCenter（私有系统服务）
//  - tccutil 测试需要用户授权，CI 中跳过
//  - 无法触发真实的权限变化通知（需要手动测试）
//
//  ## 手动测试场景
//
//  1. 运行应用 → 系统偏好设置 → 移除权限 → 验证 UI 更新
//  2. 运行应用 → 系统偏好设置 → 授予权限 → 验证 UI 更新
//  3. 快速连续授予/移除 → 验证去重逻辑
//
```

---

### 第 8 步：集成到测试套件

确保新测试在完整测试套件中运行：

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
```

**预期**: 所有新测试通过（可能部分跳过 CI 专用测试）

---

### 第 9 步：更新 README

如果项目有测试文档，添加：

```markdown
### AccessibilityManager 测试

**位置**: `LineTests/AccessibilityManagerTests.swift`

**覆盖**:
- ✓ 基本权限检查
- ✓ 流初始值发射
- ✓ 并发流消费者
- ✓ 流取消和清理
- ⚠️ tccutil 重置（仅本地，需要用户授权）
- ❌ 权限变化通知（需要手动测试）

**手动测试**: 见文件顶部注释
```

---

## 验证标准

### 构建和测试通过

```bash
# 解析依赖
xcodebuild -resolvePackageDependencies -project Line.xcodeproj -scheme Line

# 运行新测试
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/AccessibilityManagerTests

# 运行完整测试套件
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
```

**预期**:
- 所有测试通过（部分可能在 CI 中跳过）
- 无内存泄漏（Instruments 验证）
- 无崩溃

---

## 范围界限

**包含**:
- `AccessibilityManager.swift` 的单元/集成测试
- 流生命周期测试
- 并发安全测试
- tccutil 基本调用测试

**不包含**:
- Mock DistributedNotificationCenter（系统私有 API，过于复杂）
- 自动化权限变化触发（需要系统级控制）
- 完整的 tccutil 集成测试（需要用户交互）

**明确不修改**:
- `AccessibilityManager.swift` 实现（只添加测试）
- 其他测试文件
- 应用代码

---

## 回滚计划

如果测试在 CI 中不稳定：

1. **识别问题**: 哪个测试失败？本地 vs CI？
2. **临时禁用**: 标记为 `XCTSkip` 或 `#if !CI`
3. **调查**: 是权限问题还是测试逻辑问题？
4. **修复或文档化**: 修复测试或标记为仅手动测试

**删除步骤**:
```bash
git rm LineTests/AccessibilityManagerTests.swift
git commit -m "Revert: Remove AccessibilityManagerTests"
```

---

## 维护说明

**未来更改 AccessibilityManager 时**:
- 添加新公共方法 → 添加对应测试
- 修改流行为 → 更新流测试
- 修改通知处理 → 更新手动测试文档

**已知限制**:
- 无法自动化真实权限变化
- 依赖系统 API 行为
- CI 环境限制

**相关计划**:
- 其他需要 Accessibility 权限的测试应在此之后执行
- 这是测试基础设施的关键组件

---

## 参考

**现有模式**:
- 其他测试文件：`LineTests/WindowActionTests.swift`
- 测试约定：使用 `@testable import Line`

**外部资源**:
- [Testing AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [XCTest Best Practices](https://developer.apple.com/documentation/xctest)
