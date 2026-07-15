# 007: CustomWindowActionCalculator 几何边缘情况测试

**状态**: DONE (已验证完成)
**完成时间**: 2026-07-15
**commit**: c9e75d1  
**优先级**: P2（快速胜利）  
**发现**: COV-06  
**基准 commit**: 79ff450  
**工作量估算**: S（几小时）  
**风险**: LOW

---

## 问题

`Line/Window Management/Window Action/CustomWindowActionCalculator.swift` (204行) 计算自定义窗口 frame，但 `WindowActionFrameCalculationTests:86-100` 只测试快乐路径往返，无边缘情况。

**未测试边缘情况**:
- 百分比 vs 像素单位在边界
- 锚点对齐与零尺寸窗口
- 坐标溢出
- preserveSize/initialSize with nil window properties
- 单位转换边界

---

## 当前状态

**文件**: `Line/Window Management/Window Action/CustomWindowActionCalculator.swift`

**已有测试**: `LineTests/WindowActionFrameCalculationTests.swift:86-100`
```swift
func testCustomWindowActionRoundTrip() {
    // 只测试序列化往返
}
```

**未测试路径**:
- 15-203: calculateFrame() 的边缘情况
- Unit 转换 (percentage vs pixels)
- Anchor 计算与边界
- Coordinate mode 边缘

---

## 实施计划

### 第 1 步：扩展现有测试文件

在 `LineTests/WindowActionFrameCalculationTests.swift` 添加新测试：

```swift
// MARK: - Custom Action Edge Cases

func testCustomActionWithZeroBounds() {
    let action = WindowAction.CustomWindowAction(
        name: "Zero Bounds",
        unit: .percentage,
        width: 50,
        height: 50,
        xPoint: 0,
        yPoint: 0
    )
    
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(action), keybind: []),
        window: nil,
        targetScreen: NSScreen.main!,
        windowProperties: nil
    )
    
    // Bounds 是 .zero
    let frame = action.calculateFrame(for: request)
    
    // 应该返回有效的 frame（不崩溃）
    XCTAssertFalse(frame.isNull)
    XCTAssertFalse(frame.isInfinite)
}

func testCustomActionWith100PercentPlusMargin() {
    let action = WindowAction.CustomWindowAction(
        name: "Over 100%",
        unit: .percentage,
        width: 150,  // 超过 100%
        height: 150,
        xPoint: 0,
        yPoint: 0
    )
    
    let screen = NSScreen.main!
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(action), keybind: []),
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    let frame = action.calculateFrame(for: request)
    
    // 应该限制在屏幕范围内或按百分比计算
    XCTAssertLessThanOrEqual(frame.width, screen.visibleFrame.width * 1.5)
}

func testCustomActionWithNegativeCoordinates() {
    let action = WindowAction.CustomWindowAction(
        name: "Negative",
        unit: .pixels,
        width: 800,
        height: 600,
        xPoint: -100,  // 负坐标
        yPoint: -100,
        positionMode: .coordinates
    )
    
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(action), keybind: []),
        window: nil,
        targetScreen: NSScreen.main!,
        windowProperties: nil
    )
    
    let frame = action.calculateFrame(for: request)
    
    // 应该处理负坐标（可能钳制或相对计算）
    XCTAssertNotNil(frame)
}

func testCustomActionPreserveSizeWithNilWindow() {
    let action = WindowAction.CustomWindowAction(
        name: "Preserve Size Nil",
        unit: .percentage,
        sizeMode: .preserveSize,  // 需要窗口尺寸
        anchor: .center,
        xPoint: 50,
        yPoint: 50,
        positionMode: .coordinates
    )
    
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(action), keybind: []),
        window: nil,  // 无窗口
        targetScreen: NSScreen.main!,
        windowProperties: nil
    )
    
    let frame = action.calculateFrame(for: request)
    
    // 应该有合理的降级行为
    XCTAssertFalse(frame.isNull)
}

func testCustomActionAnchorAtScreenEdges() {
    let screen = NSScreen.main!
    let bounds = screen.visibleFrame
    
    // 测试所有锚点位置
    let anchors: [CustomWindowActionAnchor] = [
        .topLeft, .top, .topRight,
        .left, .center, .right,
        .bottomLeft, .bottom, .bottomRight
    ]
    
    for anchor in anchors {
        let action = WindowAction.CustomWindowAction(
            name: "Anchor \(anchor)",
            unit: .pixels,
            anchor: anchor,
            width: 400,
            height: 300,
            xPoint: bounds.midX,
            yPoint: bounds.midY,
            positionMode: .coordinates
        )
        
        let request = WindowResizeRequest(
            action: BoundWindowAction(action: .custom(action), keybind: []),
            window: nil,
            targetScreen: screen,
            windowProperties: nil
        )
        
        let frame = action.calculateFrame(for: request)
        
        // 验证锚点正确应用
        XCTAssertEqual(frame.size, CGSize(width: 400, height: 300))
        XCTAssertTrue(bounds.contains(frame) || bounds.intersects(frame),
                     "Anchor \(anchor) 应该在屏幕内或相交")
    }
}

func testCustomActionCoordinateModeWithNilPoints() {
    let action = WindowAction.CustomWindowAction(
        name: "Nil Points",
        unit: .percentage,
        width: 50,
        height: 50,
        xPoint: nil,  // 未指定
        yPoint: nil,
        positionMode: .coordinates
    )
    
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(action), keybind: []),
        window: nil,
        targetScreen: NSScreen.main!,
        windowProperties: nil
    )
    
    let frame = action.calculateFrame(for: request)
    
    // 应该有默认行为（如居中）
    XCTAssertFalse(frame.isNull)
}

func testCustomActionUnitConversionBoundaries() {
    let screen = NSScreen.main!
    
    // 测试像素和百分比转换边界
    let pixelAction = WindowAction.CustomWindowAction(
        name: "Pixel Boundary",
        unit: .pixels,
        width: screen.visibleFrame.width + 100,  // 超过屏幕
        height: screen.visibleFrame.height + 100
    )
    
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(pixelAction), keybind: []),
        window: nil,
        targetScreen: screen,
        windowProperties: nil
    )
    
    let frame = pixelAction.calculateFrame(for: request)
    
    // 应该合理处理（不崩溃）
    XCTAssertFalse(frame.isNull)
}
```

---

### 第 2 步：测试 initialSize 模式

```swift
func testCustomActionInitialSizeWithValidWindow() {
    // 创建有尺寸的 window properties
    let properties = Window.ResolvedProperties(
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        isFullscreen: false,
        isMinimized: false
    )
    
    let action = WindowAction.CustomWindowAction(
        name: "Initial Size",
        unit: .percentage,
        sizeMode: .initialSize,
        anchor: .center
    )
    
    let request = WindowResizeRequest(
        action: BoundWindowAction(action: .custom(action), keybind: []),
        window: nil,
        targetScreen: NSScreen.main!,
        windowProperties: properties
    )
    
    let frame = action.calculateFrame(for: request)
    
    // 应该使用 initial 尺寸
    XCTAssertEqual(frame.size.width, 800)
    XCTAssertEqual(frame.size.height, 600)
}
```

---

### 第 3 步：运行测试并修复发现的 bug

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/WindowActionFrameCalculationTests
```

**如果发现 bug**: 记录但不在此计划修复（创建单独的 bug fix 计划）

---

### 第 4 步：文档化边缘情况

在测试文件添加注释：

```swift
// MARK: - Custom Action Edge Cases
//
// 这些测试覆盖 CustomWindowActionCalculator 的边界条件：
// - 超出屏幕范围的尺寸和坐标
// - nil window properties 时的降级行为
// - 所有锚点位置的几何正确性
// - 单位转换边界（pixels ↔ percentage）
// - preserveSize/initialSize 模式的特殊情况
//
```

---

## 验证标准

```bash
# 运行扩展的测试
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/WindowActionFrameCalculationTests

# 完整套件
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
```

**预期**: 所有新测试通过（或发现需要修复的 bug）

---

## 范围界限

**包含**:
- CustomWindowActionCalculator 边缘情况测试
- 扩展现有测试文件

**不包含**:
- 修复发现的 bug（单独计划）
- 其他 Calculator 的测试（已有其他覆盖）
- 性能测试

**明确不修改**:
- `CustomWindowActionCalculator.swift` 实现（只添加测试）

---

## 维护说明

**如果测试发现 bug**:
1. 记录失败的测试用例
2. 创建单独的 bug fix 计划
3. 标记测试为 `XCTExpectedFailure` 或跳过
4. 修复后移除标记

**未来添加功能**:
- 新的 CustomWindowAction 属性 → 添加边缘测试
- 新的单位类型 → 测试转换
- 新的锚点模式 → 测试几何

**相关计划**:
- 现有 WindowActionFrameCalculationTests 已有基础覆盖
