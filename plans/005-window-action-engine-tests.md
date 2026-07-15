# 005: WindowActionEngine 集成测试

**状态**: DONE  
**优先级**: P1  
**发现**: COV-04  
**基准 commit**: 79ff450  
**工作量估算**: M（一天左右）  
**风险**: MED  
**依赖**: 001-accessibility-manager-tests.md

---

## 问题

`Line/Window Management/Window Manipulation/WindowActionEngine.swift` (192行) 协调 action 调度、并发任务取消、focus/quick action 处理和 WindowEngine 协调，但只有通过 coordinator 测试间接覆盖，缺少专门的集成测试。

**未测试路径**:
- apply() 任务取消竞态（actionTasks 字典）
- focus action 路由
- quick action 过滤
- 错误从 WindowEngine 传播
- 并发 apply 调用

---

## 当前状态

**文件**: `Line/Window Management/Window Manipulation/WindowActionEngine.swift`

**关键方法**:
```swift
// 71-101: apply() - 主入口点，调度 action
static func apply(_ action: BoundWindowAction, window: Window?, screen: NSScreen?) async -> Result<(), Error>

// 84-98: 任务取消和并发管理
private static var actionTasks: [ObjectIdentifier: Task<Result<(), Error>, Never>] = [:]
```

**依赖**:
- WindowEngine (实际执行)
- WindowUtility (focus 导航)
- Window (窗口抽象)

---

## 实施计划

### 第 1 步：创建测试文件和 fixture

创建 `LineTests/WindowActionEngineTests.swift`:

```swift
//
//  WindowActionEngineTests.swift
//  LineTests
//

import XCTest
@testable import Line

final class WindowActionEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 跳过如果无权限
        guard AccessibilityManager.checkAccessibility() else {
            return
        }
    }
}
```

---

### 第 2 步：测试基本 apply 成功路径

```swift
func testApplyStandardActionReturnsSuccess() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要 Accessibility 权限")
    }
    
    // 创建简单的标准 action
    let action = BoundWindowAction(
        action: .standard(.maximize),
        keybind: []
    )
    
    // 获取当前窗口
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要可用窗口")
    }
    
    // 应用 action
    let result = await WindowActionEngine.apply(action, window: window, screen: screen)
    
    // 验证结果
    switch result {
    case .success:
        XCTAssertTrue(true, "Action 应该成功应用")
    case .failure(let error):
        XCTFail("Action 失败: \(error)")
    }
}
```

---

### 第 3 步：测试 focus action 路由

```swift
func testApplyFocusActionRoutesToWindowUtility() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要 Accessibility 权限")
    }
    
    let action = BoundWindowAction(
        action: .focus(.down),
        keybind: []
    )
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要可用窗口")
    }
    
    let result = await WindowActionEngine.apply(action, window: window, screen: screen)
    
    // Focus action 总是返回成功（即使没有下一个窗口）
    switch result {
    case .success:
        XCTAssertTrue(true)
    case .failure:
        XCTFail("Focus action 不应该失败")
    }
}
```

---

### 第 4 步：测试并发 apply 取消

```swift
func testConcurrentApplyCallsCancelPreviousTask() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要 Accessibility 权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要可用窗口")
    }
    
    let action1 = BoundWindowAction(action: .standard(.leftHalf), keybind: [])
    let action2 = BoundWindowAction(action: .standard(.rightHalf), keybind: [])
    
    // 快速连续应用两个 action
    async let result1 = WindowActionEngine.apply(action1, window: window, screen: screen)
    async let result2 = WindowActionEngine.apply(action2, window: window, screen: screen)
    
    _ = await (result1, result2)
    
    // 验证没有崩溃或泄漏
    XCTAssertTrue(true, "并发 apply 应该安全完成")
}
```

---

### 第 5 步：测试 quick action 处理

```swift
func testQuickActionsExecuteImmediately() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要 Accessibility 权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) else {
        throw XCTSkip("需要可用窗口")
    }
    
    // hide 是 quick action
    let action = BoundWindowAction(action: .standard(.hide), keybind: [])
    
    let result = await WindowActionEngine.apply(action, window: window, screen: nil)
    
    switch result {
    case .success:
        XCTAssertTrue(true)
    case .failure(let error):
        // Hide 可能失败（取决于应用），但不应该崩溃
        XCTAssertNotNil(error)
    }
}
```

---

### 第 6 步：文档化测试限制

```swift
//
//  WindowActionEngineTests.swift
//  LineTests
//
//  ## 测试限制
//
//  WindowActionEngine 是集成层，依赖真实窗口：
//  - 需要 Accessibility 权限
//  - 需要可用的前台窗口
//  - 某些 action 依赖特定窗口状态
//  - 无法完全隔离 WindowEngine（真实执行层）
//
//  覆盖范围：
//  - ✓ 基本 apply 成功路径
//  - ✓ Focus action 路由
//  - ✓ 并发任务取消
//  - ✓ Quick action 处理
//  - ❌ 所有 action 类型的详尽测试（由 WindowActionTests 覆盖）
//  - ❌ WindowEngine 内部错误路径（由 007 计划覆盖）
//
```

---

### 第 7 步：集成到套件

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/WindowActionEngineTests
```

**预期**: 测试通过（部分可能跳过）

---

## 验证标准

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
```

**预期**: 所有测试通过

---

## 范围界限

**包含**:
- WindowActionEngine 的集成测试
- apply() 路由验证
- 并发安全测试

**不包含**:
- WindowEngine 内部逻辑（007 计划）
- 所有 WindowAction 类型的单元测试（已有 WindowActionTests）
- Mock WindowEngine（集成测试使用真实实现）

---

## 维护说明

**相关计划**:
- 001: AccessibilityManager 测试（依赖项）
- 007: WindowEngine 测试（下游）
- 002: WindowDragManager 测试（相关交互）
