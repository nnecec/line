//
//  WindowEngineTests.swift
//  LineTests
//
//  Created via plan 006-window-engine-tests.md on 2026-07-15.
//
//  ## 测试策略
//
//  WindowEngine 包含复杂的窗口操作逻辑和几何计算。
//
//  **测试方法**:
//  - anchoredFrame 和 shouldAnchorDuringAnimation 是静态方法，可以直接通过 @testable import 测试
//  - 私有方法通过公共 API performResize 的行为间接测试
//
//  ## 测试限制
//
//  - 部分测试需要真实窗口和 Accessibility 权限
//  - 动画测试依赖时间，可能不稳定
//  - 无法完全 mock CoreGraphics API
//

@testable import Line
import XCTest

final class WindowEngineTests: XCTestCase {
    func testResizeCancellationIsPropagatedToCaller() {
        XCTAssertThrowsError(
            try WindowEngine.frameAfterResizeError(
                CancellationError(),
                currentFrame: CGRect(x: 10, y: 20, width: 300, height: 200)
            )
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    // MARK: - anchoredFrame Tests (纯几何计算)

    func testAnchoredFramePreservesTopLeft() {
        // Given: 约束窗口，实际尺寸小于目标尺寸，目标触碰左上角
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: 100, y: 200, width: 800, height: 600)
        let targetEdges: Edge.Set = [.top, .leading]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When: 计算锚定后的帧
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 应该保持左上角位置
        XCTAssertEqual(anchored.minX, requestedFrame.minX, accuracy: 0.1, "Left edge should be preserved")
        XCTAssertEqual(anchored.minY, requestedFrame.minY, accuracy: 0.1, "Top edge should be preserved")
        XCTAssertEqual(anchored.size, actualSize, "Size should match actual size")
    }

    func testAnchoredFramePreservesBottomRight() {
        // Given: 约束窗口，目标触碰右下角
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: 1120, y: 580, width: 800, height: 600)
        let targetEdges: Edge.Set = [.bottom, .trailing]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 应该保持右下角位置
        XCTAssertEqual(anchored.maxX, requestedFrame.maxX, accuracy: 0.1, "Right edge should be preserved")
        XCTAssertEqual(anchored.maxY, requestedFrame.maxY, accuracy: 0.1, "Bottom edge should be preserved")
        XCTAssertEqual(anchored.size, actualSize, "Size should match actual size")
    }

    func testAnchoredFramePreservesTopEdgeOnly() {
        // Given: 只触碰顶部边缘
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: 500, y: 0, width: 800, height: 600)
        let targetEdges: Edge.Set = [.top]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 顶部对齐，水平居中
        XCTAssertEqual(anchored.minY, requestedFrame.minY, accuracy: 0.1, "Top edge should be preserved")
        XCTAssertEqual(anchored.midX, requestedFrame.midX, accuracy: 0.1, "Should be centered horizontally")
    }

    func testAnchoredFramePreservesLeadingEdgeOnly() {
        // Given: 只触碰左边缘
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: 0, y: 300, width: 800, height: 600)
        let targetEdges: Edge.Set = [.leading]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 左边对齐，垂直居中
        XCTAssertEqual(anchored.minX, requestedFrame.minX, accuracy: 0.1, "Left edge should be preserved")
        XCTAssertEqual(anchored.midY, requestedFrame.midY, accuracy: 0.1, "Should be centered vertically")
    }

    func testAnchoredFrameCentersWhenNoEdges() {
        // Given: 不触碰任何边缘
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: 500, y: 300, width: 800, height: 600)
        let targetEdges: Edge.Set = []
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 应该完全居中
        XCTAssertEqual(anchored.midX, requestedFrame.midX, accuracy: 0.1, "Should be centered horizontally")
        XCTAssertEqual(anchored.midY, requestedFrame.midY, accuracy: 0.1, "Should be centered vertically")
    }

    func testAnchoredFrameCentersHorizontallyWhenBothSidesTouch() {
        // Given: 触碰左右两边（全宽）
        let actualSize = CGSize(width: 1600, height: 500)
        let requestedFrame = CGRect(x: 0, y: 300, width: 1920, height: 600)
        let targetEdges: Edge.Set = [.leading, .trailing]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 水平居中
        XCTAssertEqual(anchored.midX, requestedFrame.midX, accuracy: 0.1, "Should be centered horizontally when both sides touch")
    }

    func testAnchoredFrameCentersVerticallyWhenTopBottomTouch() {
        // Given: 触碰上下两边（全高）
        let actualSize = CGSize(width: 700, height: 900)
        let requestedFrame = CGRect(x: 500, y: 0, width: 800, height: 1080)
        let targetEdges: Edge.Set = [.top, .bottom]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 垂直居中
        XCTAssertEqual(anchored.midY, requestedFrame.midY, accuracy: 0.1, "Should be centered vertically when top and bottom touch")
    }

    func testAnchoredFramePushesInsideBounds() {
        // Given: 锚定会导致窗口超出边界
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: 1800, y: 1000, width: 800, height: 600) // 右下角超出
        let targetEdges: Edge.Set = [.trailing, .bottom]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 应该被推回边界内
        XCTAssertLessThanOrEqual(anchored.maxX, bounds.maxX, "Should not exceed right bound")
        XCTAssertLessThanOrEqual(anchored.maxY, bounds.maxY, "Should not exceed bottom bound")
        XCTAssertGreaterThanOrEqual(anchored.minX, bounds.minX, "Should not go below left bound")
        XCTAssertGreaterThanOrEqual(anchored.minY, bounds.minY, "Should not go below top bound")
    }

    // MARK: - shouldAnchorDuringAnimation Tests

    func testShouldAnchorReturnsFalseWhenSizesMatch() {
        // Given: 实际尺寸与请求尺寸匹配
        let actualSize = CGSize(width: 800, height: 600)
        let requestedSize = CGSize(width: 800, height: 600)

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize
        )

        // Then: 不需要锚定
        XCTAssertFalse(shouldAnchor, "Should not anchor when sizes match")
    }

    func testShouldAnchorReturnsTrueWhenActualIsSmaller() {
        // Given: 实际尺寸小于请求尺寸（固定宽高比约束）
        let actualSize = CGSize(width: 700, height: 500)
        let requestedSize = CGSize(width: 800, height: 600)

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize
        )

        // Then: 需要锚定
        XCTAssertTrue(shouldAnchor, "Should anchor when actual size is smaller (aspect ratio constraint)")
    }

    func testShouldAnchorReturnsFalseWhenActualIsLarger() {
        // Given: 实际尺寸大于请求尺寸（最小尺寸约束）
        let actualSize = CGSize(width: 900, height: 700)
        let requestedSize = CGSize(width: 800, height: 600)

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize
        )

        // Then: 不锚定（避免抖动）
        XCTAssertFalse(shouldAnchor, "Should not anchor when actual is larger (minimum size constraint)")
    }

    func testShouldAnchorReturnsFalseWhenWidthLargerHeightSmaller() {
        // Given: 宽度大于请求，高度小于请求（混合约束）
        let actualSize = CGSize(width: 900, height: 500)
        let requestedSize = CGSize(width: 800, height: 600)

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize
        )

        // Then: 不锚定（宽度大于请求）
        XCTAssertFalse(shouldAnchor, "Should not anchor when width exceeds requested")
    }

    func testShouldAnchorReturnsFalseWhenHeightLargerWidthSmaller() {
        // Given: 高度大于请求，宽度小于请求
        let actualSize = CGSize(width: 700, height: 700)
        let requestedSize = CGSize(width: 800, height: 600)

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize
        )

        // Then: 不锚定（高度大于请求）
        XCTAssertFalse(shouldAnchor, "Should not anchor when height exceeds requested")
    }

    func testShouldAnchorRespectsToleranceForNearMatch() {
        // Given: 尺寸在容差范围内
        let actualSize = CGSize(width: 799, height: 599)
        let requestedSize = CGSize(width: 800, height: 600)
        let tolerance: CGFloat = 2

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize,
            tolerance: tolerance
        )

        // Then: 不需要锚定（在容差内视为匹配）
        XCTAssertFalse(shouldAnchor, "Should not anchor when within tolerance")
    }

    func testShouldAnchorReturnsTrueWhenBeyondTolerance() {
        // Given: 尺寸超出容差范围
        let actualSize = CGSize(width: 796, height: 596)
        let requestedSize = CGSize(width: 800, height: 600)
        let tolerance: CGFloat = 2

        // When
        let shouldAnchor = WindowEngine.shouldAnchorDuringAnimation(
            actualSize: actualSize,
            requestedSize: requestedSize,
            tolerance: tolerance
        )

        // Then: 需要锚定
        XCTAssertTrue(shouldAnchor, "Should anchor when beyond tolerance and smaller")
    }

    // MARK: - Edge Case Tests

    func testAnchoredFrameHandlesZeroSizeActual() {
        // Given: 实际尺寸为零（极端情况）
        let actualSize = CGSize(width: 0, height: 0)
        let requestedFrame = CGRect(x: 500, y: 300, width: 800, height: 600)
        let targetEdges: Edge.Set = [.top, .leading]
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 应该返回有效的帧（即使尺寸为零）
        XCTAssertEqual(anchored.origin, requestedFrame.origin, "Origin should be preserved for top-left anchor")
        XCTAssertEqual(anchored.size, actualSize, "Size should be preserved")
    }

    func testAnchoredFrameHandlesNegativeBounds() {
        // Given: 负坐标边界（多显示器场景）
        let actualSize = CGSize(width: 700, height: 500)
        let requestedFrame = CGRect(x: -800, y: 300, width: 800, height: 600)
        let targetEdges: Edge.Set = [.leading]
        let bounds = CGRect(x: -1920, y: 0, width: 1920, height: 1080)

        // When
        let anchored = WindowEngine.anchoredFrame(
            for: actualSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        // Then: 应该正确处理负坐标
        XCTAssertEqual(anchored.minX, requestedFrame.minX, accuracy: 0.1, "Should preserve left edge in negative coordinate space")
        XCTAssertGreaterThanOrEqual(anchored.minX, bounds.minX, "Should not exceed left bound")
    }
}
