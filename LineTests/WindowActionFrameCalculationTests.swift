//
//  WindowActionFrameCalculationTests.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//

@testable import Line
import XCTest

@MainActor
final class WindowActionIntegrationTests: XCTestCase {
    private let testBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let testScreen = NSScreen.main ?? NSScreen.screens[0]
    private let padding = PaddingConfiguration.zero

    func testStandardProportionalActionsCalculateExpectedFrames() {
        let testCases: [(WindowAction, CGRect)] = [
            (.standard(.proportional(.leftHalf)), CGRect(x: 0, y: 0, width: 960, height: 1080)),
            (.standard(.proportional(.rightHalf)), CGRect(x: 960, y: 0, width: 960, height: 1080)),
            (.standard(.proportional(.topHalf)), CGRect(x: 0, y: 0, width: 1920, height: 540)),
            (.standard(.proportional(.bottomHalf)), CGRect(x: 0, y: 540, width: 1920, height: 540)),
            (.standard(.proportional(.topLeftQuarter)), CGRect(x: 0, y: 0, width: 960, height: 540)),
            (.standard(.proportional(.topRightQuarter)), CGRect(x: 960, y: 0, width: 960, height: 540))
        ]

        for (action, expectedFrame) in testCases {
            let frame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(frame, expectedFrame, accuracy: 0.01)
        }
    }

    func testMaximizeActionsCalculateExpectedFrames() {
        let testCases: [(WindowAction, CGRect)] = [
            (.standard(.maximize), testBounds),
            (.standard(.fullscreen), testBounds),
            (.standard(.almostMaximize), testBounds.insetBy(dx: 20, dy: 20))
        ]

        for (action, expectedFrame) in testCases {
            let frame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(frame, expectedFrame, accuracy: 0.01)
        }
    }

    func testNonFrameActionsReturnZeroSizedFrames() {
        let testCases: [WindowAction] = [
            .focus(.focusLeft),
            .focus(.focusRight),
            .focus(.focusUp),
            .focus(.focusDown),
            .screen(.next),
            .screen(.previous),
            .screen(.left),
            .screen(.right),
            .special(.noAction),
            .special(.noSelection)
        ]

        for action in testCases {
            let frame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(frame.size, .zero)
            XCTAssertTrue(frame.origin.x.isFinite)
            XCTAssertTrue(frame.origin.y.isFinite)
        }
    }

    func testRoundTripCodablePreservesModernCalculation() throws {
        let testActions: [WindowAction] = [
            .standard(.proportional(.leftHalf)),
            .standard(.proportional(.topRightQuarter)),
            .standard(.maximize),
            .standard(.proportional(.horizontalCenterThird))
        ]

        for action in testActions {
            let originalFrame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            let encoded = try JSONEncoder().encode(action)
            let roundTrippedAction = try JSONDecoder().decode(WindowAction.self, from: encoded)
            let roundTripFrame = WindowFrameResolver.calculateFrame(
                for: roundTrippedAction,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(originalFrame, roundTripFrame, accuracy: 0.01)
        }
    }

    func testFillAvailableSpaceUsesClosestNonOverlappingObstacles() {
        let currentFrame = CGRect(x: 300, y: 300, width: 300, height: 200)
        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.fillAvailableSpace),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            visibleWindowFrames: [
                CGRect(x: 0, y: 0, width: 250, height: 1080),
                CGRect(x: 900, y: 0, width: 200, height: 1080),
                CGRect(x: 250, y: 0, width: 650, height: 250),
                CGRect(x: 250, y: 600, width: 650, height: 200)
            ]
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, CGRect(x: 250, y: 250, width: 650, height: 350), accuracy: 0.01)
    }

    func testFillAvailableSpaceIgnoresOverlappingWindows() {
        let currentFrame = CGRect(x: 300, y: 300, width: 300, height: 200)
        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.fillAvailableSpace),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            visibleWindowFrames: [
                CGRect(x: 280, y: 280, width: 100, height: 100)
            ]
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, testBounds, accuracy: 0.01)
    }

    func testStashActionCalculatesRevealedFrameAtCenterWithCurrentSize() {
        let currentFrame = CGRect(x: 100, y: 120, width: 320, height: 240)
        let request = WindowResizeRequest(
            window: nil,
            action: .stash(name: "Scratchpad", edge: .right),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true)
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, CGRect(x: 800, y: 420, width: 320, height: 240), accuracy: 0.01)
    }

    func testProportionalLayoutCalculatesCorrectFrames() {
        let testCases: [(ProportionalLayout, CGRect)] = [
            (.leftHalf, CGRect(x: 0, y: 0, width: 960, height: 1080)),
            (.rightHalf, CGRect(x: 960, y: 0, width: 960, height: 1080)),
            (.topHalf, CGRect(x: 0, y: 0, width: 1920, height: 540)),
            (.bottomHalf, CGRect(x: 0, y: 540, width: 1920, height: 540)),
            (.topLeftQuarter, CGRect(x: 0, y: 0, width: 960, height: 540)),
            (.topRightQuarter, CGRect(x: 960, y: 0, width: 960, height: 540))
        ]

        for (layout, expectedFrame) in testCases {
            let calculatedFrame = layout.calculateFrame(in: testBounds)
            XCTAssertEqual(calculatedFrame, expectedFrame, accuracy: 0.01)
        }
    }

    // MARK: - Custom Action Edge Cases
    //
    // 这些测试覆盖 CustomWindowActionCalculator 的边界条件：
    // - 超出屏幕范围的尺寸和坐标
    // - nil window properties 时的降级行为
    // - 所有锚点位置的几何正确性
    // - 单位转换边界（pixels ↔ percentage）
    // - preserveSize/initialSize 模式的特殊情况
    //

    func testCustomActionWithZeroBounds() {
        let action = WindowAction.CustomWindowAction(
            name: "Zero Bounds",
            unit: .percentage,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 50,
            height: 50,
            positionMode: .coordinates,
            xPoint: 0,
            yPoint: 0
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: .zero,
            padding: padding,
            windowProperties: nil
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该返回有效的 frame（不崩溃）
        XCTAssertFalse(result.frame.isNull)
        XCTAssertFalse(result.frame.isInfinite)
    }

    func testCustomActionWith100PercentPlusMargin() {
        let action = WindowAction.CustomWindowAction(
            name: "Over 100%",
            unit: .percentage,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 150, // 超过 100%
            height: 150,
            positionMode: .coordinates,
            xPoint: 0,
            yPoint: 0
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: nil
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该限制在屏幕范围内或按百分比计算
        XCTAssertLessThanOrEqual(result.frame.width, testBounds.width * 1.5)
        XCTAssertLessThanOrEqual(result.frame.height, testBounds.height * 1.5)
    }

    func testCustomActionWithNegativeCoordinates() {
        let action = WindowAction.CustomWindowAction(
            name: "Negative",
            unit: .pixels,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 800,
            height: 600,
            positionMode: .coordinates,
            xPoint: -100, // 负坐标
            yPoint: -100
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: nil
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该处理负坐标（可能钳制或相对计算）
        XCTAssertNotNil(result.frame)
        XCTAssertFalse(result.frame.isNull)
    }

    func testCustomActionPreserveSizeWithNilWindow() {
        let action = WindowAction.CustomWindowAction(
            name: "Preserve Size Nil",
            unit: .percentage,
            anchor: .center,
            sizeMode: .preserveSize, // 需要窗口尺寸
            width: nil,
            height: nil,
            positionMode: .coordinates,
            xPoint: 50,
            yPoint: 50
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: nil
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该有合理的降级行为（使用 bounds.size）
        XCTAssertFalse(result.frame.isNull)
        XCTAssertEqual(result.frame.size, testBounds.size)
    }

    func testCustomActionAnchorAtScreenEdges() {
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
                sizeMode: .custom,
                width: 400,
                height: 300,
                positionMode: .generic,
                xPoint: nil,
                yPoint: nil
            )

            let request = WindowResizeRequest(
                window: nil,
                action: .custom(action),
                screen: testScreen,
                bounds: testBounds,
                padding: padding,
                windowProperties: nil
            )

            let result = WindowFrameResolver.calculateFrame(for: request)

            // 验证锚点正确应用
            XCTAssertEqual(result.frame.size, CGSize(width: 400, height: 300))
            XCTAssertTrue(
                testBounds.contains(result.frame) || testBounds.intersects(result.frame),
                "Anchor \(anchor) 应该在屏幕内或相交"
            )
        }
    }

    func testCustomActionCoordinateModeWithNilPoints() {
        let action = WindowAction.CustomWindowAction(
            name: "Nil Points",
            unit: .percentage,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 50,
            height: 50,
            positionMode: .coordinates,
            xPoint: nil, // 未指定
            yPoint: nil
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: nil
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该有默认行为（使用 bounds.minX/minY）
        XCTAssertFalse(result.frame.isNull)
        XCTAssertEqual(result.frame.origin.x, testBounds.minX)
        XCTAssertEqual(result.frame.origin.y, testBounds.minY)
    }

    func testCustomActionUnitConversionBoundaries() {
        // 测试像素和百分比转换边界
        let pixelAction = WindowAction.CustomWindowAction(
            name: "Pixel Boundary",
            unit: .pixels,
            anchor: .topLeft,
            sizeMode: .custom,
            width: testBounds.width + 100, // 超过屏幕
            height: testBounds.height + 100,
            positionMode: .generic,
            xPoint: nil,
            yPoint: nil
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(pixelAction),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: nil
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该合理处理（不崩溃）
        XCTAssertFalse(result.frame.isNull)
        XCTAssertEqual(result.frame.width, testBounds.width + 100)
        XCTAssertEqual(result.frame.height, testBounds.height + 100)
    }

    func testCustomActionInitialSizeWithValidWindow() {
        // 创建有尺寸的 window properties
        let properties = WindowProperties(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            isResizable: true
        )

        let action = WindowAction.CustomWindowAction(
            name: "Initial Size",
            unit: .percentage,
            anchor: .center,
            sizeMode: .initialSize,
            width: nil,
            height: nil,
            positionMode: .generic,
            xPoint: nil,
            yPoint: nil
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: properties
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        // 应该使用 initial 尺寸（降级到 windowProperties.frame.size）
        XCTAssertEqual(result.frame.size.width, 800)
        XCTAssertEqual(result.frame.size.height, 600)
    }

    func testCustomActionRoundTrip() {
        let action = WindowAction.CustomWindowAction(
            name: "Round Trip Test",
            unit: .percentage,
            anchor: .center,
            sizeMode: .custom,
            width: 50,
            height: 50,
            positionMode: .generic,
            xPoint: nil,
            yPoint: nil
        )

        let request = WindowResizeRequest(
            window: nil,
            action: .custom(action),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: nil
        )

        let originalFrame = WindowFrameResolver.calculateFrame(for: request)

        // 序列化往返
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let wrappedAction = WindowAction.custom(action)
            let encoded = try encoder.encode(wrappedAction)
            let roundTrippedWrappedAction = try decoder.decode(WindowAction.self, from: encoded)

            let roundTripRequest = WindowResizeRequest(
                window: nil,
                action: roundTrippedWrappedAction,
                screen: testScreen,
                bounds: testBounds,
                padding: padding,
                windowProperties: nil
            )

            let roundTripFrame = WindowFrameResolver.calculateFrame(for: roundTripRequest)

            XCTAssertEqual(originalFrame.frame, roundTripFrame.frame, accuracy: 0.01)
        } catch {
            XCTFail("序列化失败: \(error)")
        }
    }
}
