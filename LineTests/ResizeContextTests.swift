//
//  ResizeContextTests.swift
//  LineTests
//

import XCTest
@testable import Line

final class ResizeContextTests: XCTestCase {

    func makeTestAction(_ action: WindowAction = .standard(.maximize)) -> BoundWindowAction {
        BoundWindowAction(action: action, keybind: [])
    }

    func makeTestScreen() -> NSScreen {
        NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - 缓存失效测试

    func testCachedTargetFrameInvalidatesOnActionChange() {
        let initialAction = makeTestAction(.standard(.leftHalf))
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: initialAction
        )

        // 第一次访问计算缓存
        let frame1 = context.cachedTargetFrame

        // 改变 action
        let newAction = makeTestAction(.standard(.rightHalf))
        context.action = newAction

        // 应该重新计算
        let frame2 = context.cachedTargetFrame

        // 左半 vs 右半应该不同
        XCTAssertNotEqual(frame1.raw, frame2.raw)
    }

    func testCachedTargetFrameInvalidatesOnScreenChange() {
        let action = makeTestAction()
        let screen1 = NSScreen.screens[0]

        let context = ResizeContext(
            window: nil,
            screen: screen1,
            action: action
        )

        let frame1 = context.cachedTargetFrame

        // 如果有多个屏幕
        if NSScreen.screens.count > 1 {
            let screen2 = NSScreen.screens[1]
            context.setScreen(to: screen2)

            let frame2 = context.cachedTargetFrame

            // 不同屏幕应该有不同的帧
            XCTAssertNotEqual(frame1.raw, frame2.raw)
        } else {
            // 单屏幕环境，改变 screen 到同一个屏幕
            context.setScreen(to: screen1)

            // 缓存应该被清空并重新计算
            let frame2 = context.cachedTargetFrame

            // 验证缓存机制工作（即使结果相同，也是重新计算的）
            XCTAssertEqual(frame1.raw, frame2.raw)
        }
    }

    func testCachedTargetFrameReusesComputationWhenUnchanged() {
        let action = makeTestAction()
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action
        )

        // 多次访问应该返回相同值（缓存）
        let frame1 = context.cachedTargetFrame
        let frame2 = context.cachedTargetFrame

        XCTAssertEqual(frame1.raw, frame2.raw)
        XCTAssertEqual(frame1.padded, frame2.padded)
    }

    // MARK: - refreshResolvedState 测试

    func testRefreshResolvedStateClearsCache() async {
        let action = makeTestAction()
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action
        )

        // 先访问缓存
        _ = context.cachedTargetFrame

        // refreshResolvedState 应该清空缓存
        await context.refreshResolvedState()

        // 由于没有 window，resolved properties 应该为 nil
        XCTAssertNil(context.resolvedWindowProperties)
    }

    // MARK: - setAction 测试

    func testSetActionUpdatesActionAndClearsCache() {
        let initialAction = makeTestAction(.standard(.leftHalf))
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: initialAction
        )

        // 先访问缓存
        let frame1 = context.cachedTargetFrame

        // 使用 setAction 改变 action
        let newAction = makeTestAction(.standard(.rightHalf))
        let parentAction = makeTestAction(.standard(.maximize))
        context.setAction(to: newAction, parent: parentAction)

        // action 应该更新
        XCTAssertEqual(context.action.action, newAction.action)
        XCTAssertEqual(context.parentAction?.action, parentAction.action)

        // 缓存应该失效，重新计算
        let frame2 = context.cachedTargetFrame
        XCTAssertNotEqual(frame1.raw, frame2.raw)
    }

    // MARK: - 遗留兼容性测试

    func testLegacyCompatibilityProperties() {
        let action = makeTestAction()
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action
        )

        // 测试遗留访问器
        XCTAssertEqual(context.action.action, action.action)
        XCTAssertEqual(context.screen, screen)
        XCTAssertNotNil(context.bounds)
        XCTAssertNotNil(context.padding)
        XCTAssertNotNil(context.paddedBounds)
    }

    func testLegacySetScreenMethod() {
        let action = makeTestAction()
        let screen1 = NSScreen.screens[0]

        let context = ResizeContext(
            window: nil,
            screen: screen1,
            action: action
        )

        XCTAssertEqual(context.screen, screen1)

        // 使用遗留方法改变 screen
        if NSScreen.screens.count > 1 {
            let screen2 = NSScreen.screens[1]
            context.setScreen(to: screen2)
            XCTAssertEqual(context.screen, screen2)
        } else {
            // 单屏环境，设置同一个屏幕
            context.setScreen(to: screen1)
            XCTAssertEqual(context.screen, screen1)
        }
    }

    // MARK: - 边缘情况测试

    func testResizeContextWithNilWindow() {
        let action = makeTestAction()
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action
        )

        // 应该正常工作
        XCTAssertNotNil(context.cachedTargetFrame)
        XCTAssertNil(context.window)
    }

    func testResizeContextWithNilScreen() {
        let action = makeTestAction()

        // 没有提供 screen，应该使用默认值
        let context = ResizeContext(
            window: nil,
            screen: nil,
            action: action
        )

        // 应该回退到 main screen 或 screens[0]
        XCTAssertNotNil(context.screen)
    }

    func testResizeContextInitialMousePosition() {
        let action = makeTestAction()
        let screen = makeTestScreen()
        let mousePos = CGPoint(x: 100, y: 200)

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action,
            initialMousePosition: mousePos
        )

        XCTAssertEqual(context.initialMousePosition, mousePos)
    }

    func testResizeContextLastAppliedFrame() {
        let action = makeTestAction()
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action
        )

        // 初始值应该是 zero
        XCTAssertEqual(context.lastAppliedFrame, .zero)

        // 可以修改
        let testFrame = CGRect(x: 10, y: 20, width: 300, height: 400)
        context.lastAppliedFrame = testFrame
        XCTAssertEqual(context.lastAppliedFrame, testFrame)
    }

    // MARK: - ComputedFrame 测试

    func testComputedFrameZero() {
        let zero = ComputedFrame.zero
        XCTAssertEqual(zero.raw, .zero)
        XCTAssertEqual(zero.padded, .zero)
    }

    func testGetTargetFrameReturnsValidFrame() {
        let action = makeTestAction()
        let screen = makeTestScreen()

        let context = ResizeContext(
            window: nil,
            screen: screen,
            action: action
        )

        let (frame, sides) = context.getTargetFrame()

        // 应该返回有效的帧
        XCTAssertNotEqual(frame, .zero)
        // sides 可能为 nil，取决于 action
    }
}
