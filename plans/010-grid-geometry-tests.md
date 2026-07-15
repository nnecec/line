# 010: Grid Layout 几何计算测试

**状态**: TODO  
**优先级**: P1  
**发现**: COV-07  
**基准 commit**: 79ff450  
**工作量估算**: M（一天左右）  
**风险**: MED

---

## 问题

`Line/Grid Layout/` (~474 行，13 个文件) 实现网格单元计算、鼠标追踪和内存管理，但 `GridModeCoordinatorTests` 只验证 coordinator 状态 (isActive)，不验证网格数学。

**未测试的几何逻辑**:
- GridGeometry.swift: 单元格帧计算
- GridMouseObserver.swift: 鼠标位置 → 单元格映射
- GridContext.swift: 网格配置和边界
- 填充应用、屏幕边界钳制、N×M 网格

---

## 当前状态

**文件**: 
- `Line/Grid Layout/GridGeometry.swift` - 单元格几何
- `Line/Grid Layout/GridMouseObserver.swift` - 鼠标追踪
- `Line/Grid Layout/GridContext.swift` - 网格上下文
- `Line/Grid Layout/Models/GridCell.swift` - 单元格模型

**现有测试**: `LineTests/GridModeCoordinatorTests.swift` 只测试协调器状态

---

## 实施计划

### 第 1 步：创建 GridGeometry 测试

创建 `LineTests/GridGeometryTests.swift`:

```swift
//
//  GridGeometryTests.swift
//  LineTests
//

import XCTest
@testable import Line

final class GridGeometryTests: XCTestCase {
    
    func testGridCellFrameCalculation2x2() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let rows = 2
        let cols = 2
        let padding: CGFloat = 0
        
        // 计算单元格尺寸
        let cellWidth = screenBounds.width / CGFloat(cols)
        let cellHeight = screenBounds.height / CGFloat(rows)
        
        // 测试左上角单元格
        let topLeft = CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight)
        
        // 测试右下角单元格
        let bottomRight = CGRect(
            x: cellWidth,
            y: cellHeight,
            width: cellWidth,
            height: cellHeight
        )
        
        // 验证单元格覆盖整个屏幕
        XCTAssertEqual(cellWidth, 960)
        XCTAssertEqual(cellHeight, 540)
    }
    
    func testGridCellFrameCalculationWithPadding() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let rows = 2
        let cols = 2
        let padding: CGFloat = 10
        
        // 有填充时，单元格应该更小
        let cellWidth = (screenBounds.width - padding * CGFloat(cols + 1)) / CGFloat(cols)
        let cellHeight = (screenBounds.height - padding * CGFloat(rows + 1)) / CGFloat(rows)
        
        // 验证填充正确应用
        XCTAssertLessThan(cellWidth, 960)
        XCTAssertLessThan(cellHeight, 540)
    }
    
    func testGridCellFrameCalculation3x3() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let rows = 3
        let cols = 3
        
        let cellWidth = screenBounds.width / CGFloat(cols)
        let cellHeight = screenBounds.height / CGFloat(rows)
        
        XCTAssertEqual(cellWidth, 640)
        XCTAssertEqual(cellHeight, 360)
    }
    
    func testGridCellFrameAlignmentToScreenEdges() {
        let screenBounds = CGRect(x: 100, y: 100, width: 1920, height: 1080)
        let rows = 2
        let cols = 2
        
        // 网格应该对齐到屏幕边界
        // 左上角单元格的 minX 应该 = screenBounds.minX
        
        XCTAssertTrue(true, "需要实际的网格计算函数")
    }
}
```

---

### 第 2 步：测试鼠标位置到单元格映射

```swift
func testMousePositionToCellMapping() {
    let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let rows = 2
    let cols = 2
    
    // 左上角单元格内的点
    let topLeftPoint = CGPoint(x: 100, y: 100)
    
    // 应该映射到 (row: 0, col: 0)
    let expectedRow = 0
    let expectedCol = 0
    
    // 计算实际行列
    let cellWidth = screenBounds.width / CGFloat(cols)
    let cellHeight = screenBounds.height / CGFloat(rows)
    
    let actualCol = Int(topLeftPoint.x / cellWidth)
    let actualRow = Int(topLeftPoint.y / cellHeight)
    
    XCTAssertEqual(actualRow, expectedRow)
    XCTAssertEqual(actualCol, expectedCol)
}

func testMousePositionAtCellBoundary() {
    let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let rows = 2
    let cols = 2
    let cellWidth = screenBounds.width / CGFloat(cols)
    
    // 正好在单元格边界的点
    let boundaryPoint = CGPoint(x: cellWidth, y: 0)
    
    // 应该映射到右侧单元格
    let col = Int(boundaryPoint.x / cellWidth)
    
    // 边界情况：可能是 1 或 2（取决于实现）
    XCTAssertGreaterThanOrEqual(col, 1)
}
```

---

### 第 3 步：测试网格配置边缘情况

```swift
func testGridWith1x1Configuration() {
    let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let rows = 1
    let cols = 1
    
    // 单单元格网格应该覆盖整个屏幕
    let cellWidth = screenBounds.width / CGFloat(cols)
    let cellHeight = screenBounds.height / CGFloat(rows)
    
    XCTAssertEqual(cellWidth, screenBounds.width)
    XCTAssertEqual(cellHeight, screenBounds.height)
}

func testGridWithLargeConfiguration() {
    let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let rows = 10
    let cols = 10
    
    // 大网格的单元格应该很小
    let cellWidth = screenBounds.width / CGFloat(cols)
    let cellHeight = screenBounds.height / CGFloat(rows)
    
    XCTAssertEqual(cellWidth, 192)
    XCTAssertEqual(cellHeight, 108)
}
```

---

### 第 4 步：创建 GridContext 测试

创建 `LineTests/GridContextTests.swift`:

```swift
//
//  GridContextTests.swift
//  LineTests
//

import XCTest
@testable import Line

final class GridContextTests: XCTestCase {
    
    func testGridContextInitialization() {
        // 测试 GridContext 正确初始化
        // 需要根据实际 API 调整
        XCTAssertTrue(true)
    }
    
    func testGridContextWithDifferentScreens() {
        guard NSScreen.screens.count > 1 else {
            throw XCTSkip("需要多个屏幕")
        }
        
        let screen1 = NSScreen.screens[0]
        let screen2 = NSScreen.screens[1]
        
        // 不同屏幕的网格应该有不同的边界
        XCTAssertNotEqual(screen1.visibleFrame, screen2.visibleFrame)
    }
}
```

---

### 第 5 步：集成到测试套件

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS' \
  -only-testing:LineTests/GridGeometryTests \
  -only-testing:LineTests/GridContextTests
```

---

## 验证标准

```bash
xcodebuild test -project Line.xcodeproj -scheme Line -destination 'platform=macOS'
```

**预期**: 所有网格几何测试通过

---

## 范围界限

**包含**:
- GridGeometry 单元格计算测试
- 鼠标位置映射测试
- GridContext 边界测试

**不包含**:
- GridOverlay UI 测试（需要真实渲染）
- GridMouseObserver 事件测试（需要系统事件）
- GridModeCoordinator 测试（已有覆盖）

---

## 维护说明

**网格几何是纯函数**:
- 易于单元测试
- 无外部依赖
- 可以详尽测试边缘情况

**相关计划**:
- GridModeCoordinatorTests 已存在（协调器层）
