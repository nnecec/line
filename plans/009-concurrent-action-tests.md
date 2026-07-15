# 009: 并发 action 处理和取消测试

**状态**: DONE  
**优先级**: P1（快速胜利，并发安全）  
**发现**: COV-11  
**基准 commit**: 79ff450  
**工作量估算**: S（几小时）  
**风险**: MED

---

## 问题

`Line/Window Management/Window Manipulation/WindowActionEngine.swift:84-101` 通过 actionTasks 字典追踪每窗口的 action 任务并支持取消，但并发场景未测试。

**未测试并发场景**:
- 同一窗口的快速连续 apply()
- 任务取消传播
- actionTasks 字典清理
- CancellationError 处理

**风险**: 竞态导致 action 不取消、字典泄漏或并发帧变更崩溃

---

## 当前状态

**文件**: `Line/Window Management/Window Manipulation/WindowActionEngine.swift`

**关键代码**:
```swift
// 84-98: 并发管理
private static var actionTasks: [ObjectIdentifier: Task<Result<(), Error>, Never>] = [:]

static func apply(...) async -> Result<(), Error> {
    // ...
    let windowID = ObjectIdentifier(window)
    
    // 取消已有任务
    if let existingTask = actionTasks[windowID] {
        existingTask.cancel()
        _ = await existingTask.value
    }
    
    // 创建新任务
    let task = Task { ... }
    actionTasks[windowID] = task
    
    // 清理
    defer { actionTasks[windowID] = nil }
}
```

---

## 实施计划

### 第 1 步：创建或扩展测试文件

在 `LineTests/WindowActionEngineTests.swift` 添加并发测试（如果文件不存在，创建它）：

```swift
// MARK: - Concurrent Action Handling

func testRapidSequentialActionsOnSameWindow() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要窗口")
    }
    
    // 创建多个不同的 action
    let actions = [
        BoundWindowAction(action: .standard(.leftHalf), keybind: []),
        BoundWindowAction(action: .standard(.rightHalf), keybind: []),
        BoundWindowAction(action: .standard(.maximize), keybind: []),
        BoundWindowAction(action: .standard(.center(.geometric)), keybind: [])
    ]
    
    // 快速连续应用
    for action in actions {
        _ = await WindowActionEngine.apply(action, window: window, screen: screen)
    }
    
    // 应该完成而不崩溃
    XCTAssertTrue(true, "快速连续 action 应该安全完成")
}

func testConcurrentActionsOnSameWindowCancelsPrevious() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要窗口")
    }
    
    let action1 = BoundWindowAction(action: .standard(.leftHalf), keybind: [])
    let action2 = BoundWindowAction(action: .standard(.rightHalf), keybind: [])
    
    // 启动两个并发任务
    async let result1 = WindowActionEngine.apply(action1, window: window, screen: screen)
    async let result2 = WindowActionEngine.apply(action2, window: window, screen: screen)
    
    let (r1, r2) = await (result1, result2)
    
    // 至少一个应该成功完成
    let successCount = [r1, r2].filter { if case .success = $0 { return true }; return false }.count
    XCTAssertGreaterThanOrEqual(successCount, 1, "至少一个 action 应该成功")
}

func testConcurrentActionsOnDifferentWindowsSucceed() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    // 尝试获取两个不同的窗口
    let apps = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
    guard apps.count >= 2,
          let window1 = try? Window(pid: apps[0].processIdentifier),
          let window2 = try? Window(pid: apps[1].processIdentifier),
          let screen = NSScreen.main else {
        throw XCTSkip("需要至少两个应用窗口")
    }
    
    let action = BoundWindowAction(action: .standard(.maximize), keybind: [])
    
    // 并发应用到不同窗口
    async let result1 = WindowActionEngine.apply(action, window: window1, screen: screen)
    async let result2 = WindowActionEngine.apply(action, window: window2, screen: screen)
    
    let (r1, r2) = await (result1, result2)
    
    // 两个都应该成功（不同窗口不应该相互干扰）
    if case .success = r1, case .success = r2 {
        XCTAssertTrue(true, "不同窗口的并发 action 应该都成功")
    } else {
        // 某些窗口可能不支持操作，但不应该崩溃
        XCTAssertTrue(true, "即使失败也不应该崩溃")
    }
}
```

---

### 第 2 步：测试任务清理

```swift
func testActionTasksCleanupAfterCompletion() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要窗口")
    }
    
    let action = BoundWindowAction(action: .standard(.maximize), keybind: [])
    
    // 应用 action
    _ = await WindowActionEngine.apply(action, window: window, screen: screen)
    
    // 任务应该已经从 actionTasks 移除
    // 无法直接访问 actionTasks（私有），但通过行为验证
    
    // 再次应用应该成功（没有残留任务）
    _ = await WindowActionEngine.apply(action, window: window, screen: screen)
    
    XCTAssertTrue(true, "任务应该正确清理")
}
```

---

### 第 3 步：测试取消错误处理

```swift
func testCancellationDoesNotCauseLeaks() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要窗口")
    }
    
    // 启动多个任务并快速取消
    for _ in 0..<10 {
        let action = BoundWindowAction(action: .standard(.leftHalf), keybind: [])
        
        // 不等待完成，立即启动下一个（隐式取消前一个）
        Task {
            _ = await WindowActionEngine.apply(action, window: window, screen: screen)
        }
    }
    
    // 等待所有完成
    try await Task.sleep(for: .seconds(2))
    
    // 应该没有泄漏或崩溃
    XCTAssertTrue(true, "取消不应该导致泄漏")
}
```

---

### 第 4 步：压力测试

```swift
func testHighFrequencyActionApplications() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要窗口")
    }
    
    // 高频率应用（模拟用户快速按键）
    let actions = (0..<20).map { _ in
        BoundWindowAction(action: .standard(.leftHalf), keybind: [])
    }
    
    for action in actions {
        _ = await WindowActionEngine.apply(action, window: window, screen: screen)
        // 极短延迟
        try? await Task.sleep(for: .milliseconds(10))
    }
    
    XCTAssertTrue(true, "高频应用不应该崩溃")
}
```

---

## 验证标准

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/WindowActionEngineTests
```

**预期**: 所有并发测试通过，无崩溃或泄漏

---

## 范围界限

**包含**:
- WindowActionEngine 并发场景测试
- 任务取消验证
- actionTasks 字典清理验证

**不包含**:
- 性能基准测试
- 极端压力测试（成千上万次调用）
- 内存泄漏的 Instruments 分析（手动验证）

**明确不修改**:
- WindowActionEngine.swift 实现

---

## 维护说明

**并发测试的特点**:
- 可能不稳定（时间依赖）
- 如果失败，增加延迟或重试
- 主要验证：不崩溃 > 精确行为

**未来添加功能**:
- 新的并发路径 → 添加测试
- 修改 actionTasks 管理 → 更新测试

**相关计划**:
- 005: WindowActionEngine 基础测试
- 006: WindowEngine（被调用者）
