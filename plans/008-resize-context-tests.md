# 008: ResizeContext 状态包装特性测试

**状态**: DONE  
**优先级**: P2（快速胜利）  
**发现**: COV-09  
**基准 commit**: 79ff450  
**工作量估算**: S（几小时）  
**风险**: LOW

---

## 问题

`Line/Window Management/Window Manipulation/ResizeContext.swift` (185行) 包装 WindowResizeRequest 并管理可变状态（action, screen, resolvedWindowProperties）和缓存（cachedTargetFrame），但缺少专门的特性测试。

**未测试路径**:
- 缓存失效（action/screen 改变时）
- refreshResolvedState() 异步协调
- rebuildRequest() 选择性快照保留
- 遗留兼容性方法

---

## 当前状态

**文件**: `Line/Window Management/Window Manipulation/ResizeContext.swift`

**关键方法**:
```swift
// 25-35: init - 创建上下文
// 67-88: cachedTargetFrame - 缓存的目标帧
// 134-150: refreshResolvedState() - 更新状态
// 155-172: setAction/setScreen - 状态修改器
// 89-107: rebuildRequest() - 重建请求
```

---

## 实施计划

### 第 1 步：创建测试文件

创建 `LineTests/ResizeContextTests.swift`:

```swift
//
//  ResizeContextTests.swift
//  LineTests
//

import XCTest
@testable import Line

final class ResizeContextTests: XCTestCase {
    
    func makeTestAction() -> BoundWindowAction {
        BoundWindowAction(action: .standard(.maximize), keybind: [])
    }
    
    func makeTestScreen() -> NSScreen {
        NSScreen.main!
    }
}
```

---

### 第 2 步：测试缓存失效

```swift
func testCachedTargetFrameInvalidatesOnActionChange() {
    let initialAction = BoundWindowAction(action: .standard(.leftHalf), keybind: [])
    let screen = makeTestScreen()
    
    let context = ResizeContext(
        action: initialAction,
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    // 第一次访问计算缓存
    let frame1 = context.cachedTargetFrame
    
    // 改变 action
    let newAction = BoundWindowAction(action: .standard(.rightHalf), keybind: [])
    context.setAction(newAction)
    
    // 应该重新计算
    let frame2 = context.cachedTargetFrame
    
    // 左半 vs 右半应该不同
    XCTAssertNotEqual(frame1, frame2)
}

func testCachedTargetFrameInvalidatesOnScreenChange() {
    let action = makeTestAction()
    let screen1 = NSScreen.screens[0]
    
    let context = ResizeContext(
        action: action,
        window: nil,
        targetScreen: screen1,
        windowProperties: nil
    )
    
    let frame1 = context.cachedTargetFrame
    
    // 如果有多个屏幕
    if NSScreen.screens.count > 1 {
        let screen2 = NSScreen.screens[1]
        context.setScreen(screen2)
        
        let frame2 = context.cachedTargetFrame
        
        // 不同屏幕应该有不同的帧
        XCTAssertNotEqual(frame1, frame2)
    } else {
        XCTSkip("需要多个屏幕测试屏幕改变")
    }
}

func testCachedTargetFrameReusesComputationWhenUnchanged() {
    let action = makeTestAction()
    let screen = makeTestScreen()
    
    let context = ResizeContext(
        action: action,
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    // 多次访问应该返回相同实例（缓存）
    let frame1 = context.cachedTargetFrame
    let frame2 = context.cachedTargetFrame
    
    XCTAssertEqual(frame1, frame2)
}
```

---

### 第 3 步：测试 refreshResolvedState

```swift
func testRefreshResolvedStateUpdatesAllProperties() async {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) else {
        throw XCTSkip("需要窗口")
    }
    
    let action = makeTestAction()
    let screen = makeTestScreen()
    
    let context = ResizeContext(
        action: action,
        window: window,
        targetScreen: screen,
        windowProperties: nil
    )
    
    // refreshResolvedState 应该填充 resolvedWindowProperties
    await context.refreshResolvedState()
    
    XCTAssertNotNil(context.resolvedWindowProperties)
}
```

---

### 第 4 步：测试 rebuildRequest

```swift
func testRebuildRequestPreservesSnapshots() {
    let action = makeTestAction()
    let screen = makeTestScreen()
    
    let context = ResizeContext(
        action: action,
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    // rebuildRequest 应该创建新的 request
    let rebuilt = context.rebuildRequest(preserveSnapshots: true)
    
    XCTAssertNotNil(rebuilt)
    XCTAssertEqual(rebuilt.action.action, action.action)
}
```

---

### 第 5 步：测试遗留兼容性

```swift
func testLegacyCompatibilityMethods() {
    let action = makeTestAction()
    let screen = makeTestScreen()
    
    let context = ResizeContext(
        action: action,
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    // 测试遗留访问器（如果存在）
    XCTAssertEqual(context.action.action, action.action)
    XCTAssertEqual(context.screen, screen)
}
```

---

### 第 6 步：测试边缘情况

```swift
func testResizeContextWithNilWindow() {
    let action = makeTestAction()
    let screen = makeTestScreen()
    
    let context = ResizeContext(
        action: action,
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    // 应该正常工作
    XCTAssertNotNil(context.cachedTargetFrame)
    XCTAssertNil(context.window)
}

func testResizeContextWithNilScreen() {
    let action = makeTestAction()
    
    // 某些 action 可能不需要 screen
    let context = ResizeContext(
        action: action,
        window: nil,
        targetScreen: nil,
        windowProperties: nil
    )
    
    // 应该不崩溃
    XCTAssertNil(context.screen)
}
```

---

## 验证标准

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/ResizeContextTests
```

---

## 范围界限

**包含**:
- ResizeContext 状态管理测试
- 缓存失效逻辑
- 状态刷新测试

**不包含**:
- WindowResizeRequest 内部逻辑（不同的职责）
- 完整的 WindowAction 计算（由其他测试覆盖）

---

## 维护说明

**ResizeContext 是数据持有者**:
- 主要逻辑委托给 WindowResizeRequest
- 测试重点：缓存和状态管理

**相关计划**:
- 005: WindowActionEngine（使用 ResizeContext）
- 006: WindowEngine（使用 ResizeContext）
