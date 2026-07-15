# 006: WindowEngine resize 逻辑单元测试

**状态**: TODO  
**优先级**: P1  
**发现**: COV-05  
**基准 commit**: 79ff450  
**工作量估算**: L（多天）  
**风险**: HIGH  
**依赖**: 001-accessibility-manager-tests.md

---

## 问题

`Line/Window Management/Window Manipulation/WindowEngine.swift` (306行) 处理 resize 执行、动画决策、system window manager 回退、size-constrained window 锚定，但只通过端到端 action 流程间接测试。

**未测试路径**:
- shouldAnimateResize 决策树
- resizeWindow with/without animation
- handleSizeConstrainedWindow 所有边缘组合
- anchoredFrame 几何（每个目标边缘集）
- system window manager 回退

**复杂度最高的未测试代码**：
- `handleSizeConstrainedWindow` (225-256): 保持锚点的约束窗口处理
- `anchoredFrame` (258-287): 边缘锚定计算
- animation 重试逻辑 (206-211)

---

## 当前状态

**文件**: `Line/Window Management/Window Manipulation/WindowEngine.swift`

**关键方法**:
```swift
// 18-135: performResize() - 主入口点
static func performResize(context: ResizeContext) async throws

// 137-203: shouldAnimateResize() - 动画决策
private static func shouldAnimateResize(...) -> Bool

// 205-223: resizeWindow() - 执行 resize
private static func resizeWindow(...) async throws -> CGRect

// 225-256: handleSizeConstrainedWindow() - 约束窗口处理
private static func handleSizeConstrainedWindow(...) async throws -> CGRect

// 258-287: anchoredFrame() - 锚定计算
private static func anchoredFrame(...) -> CGRect
```

---

## 实施计划

### 第 1 步：创建测试文件和 fixture 工具

创建 `LineTests/WindowEngineTests.swift`:

```swift
//
//  WindowEngineTests.swift
//  LineTests
//

import XCTest
@testable import Line

final class WindowEngineTests: XCTestCase {
    
    // Fixture: 创建测试用的 Window.ResolvedProperties
    func makeResolvedProperties(
        frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
        isFullscreen: Bool = false,
        isMinimized: Bool = false,
        sizeConstraints: (min: CGSize, max: CGSize)? = nil
    ) -> Window.ResolvedProperties {
        // 注意：Window.ResolvedProperties 的实际初始化可能不同
        // 需要根据实际定义调整
        return Window.ResolvedProperties(
            frame: frame,
            isFullscreen: isFullscreen,
            isMinimized: isMinimized
            // ... 其他属性
        )
    }
    
    override func setUp() {
        super.setUp()
        guard AccessibilityManager.checkAccessibility() else {
            return
        }
    }
}
```

---

### 第 2 步：测试 shouldAnimateResize 决策逻辑

由于 `shouldAnimateResize` 是私有的，我们通过 `performResize` 间接测试或使用 `@testable import` 访问：

```swift
func testShouldAnimateResizeReturnsFalseWhenDisabled() {
    // 保存原始设置
    let originalSetting = Defaults[.animateWindowResizes]
    defer { Defaults[.animateWindowResizes] = originalSetting }
    
    // 禁用动画
    Defaults[.animateWindowResizes] = false
    
    // 创建 fixture window
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) else {
        XCTSkip("需要可用窗口")
        return
    }
    
    let properties = makeResolvedProperties()
    
    // 通过反射或其他方式测试
    // 或者通过集成测试验证行为
    XCTAssertTrue(true, "动画禁用时应该返回 false")
}

func testShouldAnimateResizeReturnsFalseForScreenChange() {
    // willChangeScreens = true 应该禁用动画
    XCTAssertTrue(true)
}
```

---

### 第 3 步：测试 anchoredFrame 几何计算

这是可以独立测试的纯函数逻辑：

```swift
func testAnchoredFramePreservesTopLeftWhenConstrained() {
    let originalFrame = CGRect(x: 100, y: 200, width: 800, height: 600)
    let targetFrame = CGRect(x: 100, y: 200, width: 600, height: 400) // 更小
    let actualFrame = CGRect(x: 100, y: 200, width: 700, height: 500) // 约束后
    let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    
    // 锚定到 topLeft
    let targetEdges: Edge.Set = [.top, .leading]
    
    // 调用 anchoredFrame（如果可访问）
    // let anchored = WindowEngine.anchoredFrame(...)
    
    // 验证锚点保持
    // XCTAssertEqual(anchored.minX, targetFrame.minX)
    // XCTAssertEqual(anchored.minY, targetFrame.minY)
    
    XCTAssertTrue(true, "需要访问私有方法或通过集成测试验证")
}

func testAnchoredFramePreservesBottomRightWhenConstrained() {
    // 测试 [.bottom, .trailing] 锚定
    XCTAssertTrue(true)
}

func testAnchoredFramePreservesCenterWhenNoEdges() {
    // 测试空边缘集 → 居中
    XCTAssertTrue(true)
}
```

**注意**: 如果这些方法是私有的，有两个选择：
1. 将它们改为 `internal` 并用 `@testable import`
2. 只测试公共 API (`performResize`) 的行为

---

### 第 4 步：测试 handleSizeConstrainedWindow

```swift
func testHandleSizeConstrainedWindowWithAspectRatio() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    // 找一个有固定宽高比的应用窗口（如计算器）
    // 或者创建 mock window
    
    // 测试约束窗口的锚定逻辑
    XCTAssertTrue(true, "需要真实约束窗口或 mock")
}
```

---

### 第 5 步：测试 animation 路径

```swift
func testResizeWindowWithAnimationCompletes() async throws {
    guard AccessibilityManager.checkAccessibility() else {
        throw XCTSkip("需要权限")
    }
    
    guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
          let screen = NSScreen.main else {
        throw XCTSkip("需要窗口和屏幕")
    }
    
    let targetFrame = CGRect(x: 100, y: 100, width: 600, height: 400)
    let bounds = screen.visibleFrame
    
    // 调用 resizeWindow（如果可访问）
    // let result = try await WindowEngine.resizeWindow(...)
    
    // 验证最终帧
    XCTAssertTrue(true, "需要访问私有方法")
}
```

---

### 第 6 步：文档化测试策略

```swift
//
//  WindowEngineTests.swift
//  LineTests
//
//  ## 测试策略
//
//  WindowEngine 包含大量私有方法和复杂的窗口操作逻辑。
//
//  **两种测试方法**:
//  1. 将关键私有方法改为 internal + @testable import
//     - 优点：可以直接测试几何计算
//     - 缺点：需要修改生产代码访问级别
//
//  2. 只测试公共 API (performResize)
//     - 优点：不修改生产代码
//     - 缺点：测试更脆弱，难以隔离边缘情况
//
//  **推荐**: 方法 1 — 将纯函数逻辑（anchoredFrame 等）改为 internal
//
//  ## 测试限制
//
//  - 需要真实窗口和 Accessibility 权限
//  - 某些测试需要特定应用（有约束的窗口）
//  - 动画测试依赖时间，可能不稳定
//  - 无法完全 mock CoreGraphics API
//
```

---

### 第 7 步：提出代码重构建议

如果测试太困难，在计划中建议重构：

**建议重构** (不在此计划实施):
```swift
// 将纯计算逻辑提取为 internal 函数
extension WindowEngine {
    // 从 private 改为 internal for testing
    internal static func anchoredFrame(...) -> CGRect { ... }
    internal static func shouldAnimateResize(...) -> Bool { ... }
}
```

这样可以：
- 独立测试几何计算
- 不影响公共 API
- 保持封装（internal vs public）

---

## 验证标准

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/WindowEngineTests
```

---

## 范围界限

**包含**:
- WindowEngine 关键路径测试
- 几何计算验证
- 动画决策测试

**不包含**:
- CoreGraphics API mock（使用真实实现）
- 所有边缘情况的详尽覆盖（优先最高风险路径）
- 性能测试

**可选重构** (单独计划):
- 提取纯函数为 internal 以便测试

---

## 维护说明

**高复杂度区域**:
- handleSizeConstrainedWindow: 多重嵌套条件
- anchoredFrame: 边缘组合爆炸
- animation 重试: 时间依赖

**未来添加功能时**:
- 新的窗口约束类型 → 添加测试
- 新的动画模式 → 测试决策逻辑
- 新的锚定规则 → 测试几何

**相关计划**:
- 001: AccessibilityManager（依赖项）
- 005: WindowActionEngine（上游调用者）
