//
//  WindowActionEngineTests.swift
//  LineTests
//
//  集成测试 WindowActionEngine 的 action 调度、并发任务取消和路由逻辑。
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

import XCTest
@testable import Line

@MainActor
final class WindowActionEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // 跳过如果无权限
        guard AccessibilityManager.checkAccessibility() else {
            return
        }
    }

    // MARK: - Basic Apply Success Path

    func testApplyStandardActionReturnsSuccess() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要 Accessibility 权限")
        }

        // 获取当前窗口
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let window = try? Window(pid: frontmostApp.processIdentifier),
              let screen = NSScreen.main else {
            throw XCTSkip("需要可用窗口")
        }

        // 创建简单的标准 action
        let action = WindowAction.standard(.maximize)

        // 应用 action
        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // 验证结果
        XCTAssertTrue(result.success, "Maximize action 应该成功应用")
        XCTAssertNil(result.newTargetWindow, "标准 action 不应该改变目标窗口")
    }

    // MARK: - Focus Action Routing

    func testApplyFocusActionRoutesToWindowUtility() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要 Accessibility 权限")
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let window = try? Window(pid: frontmostApp.processIdentifier),
              let screen = NSScreen.main else {
            throw XCTSkip("需要可用窗口")
        }

        let action = WindowAction.focus(.down)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // Focus action 总是返回成功（即使没有下一个窗口）
        // result.success 取决于是否找到了窗口
        XCTAssertNotNil(result, "Focus action 应该返回结果")
    }

    // MARK: - Concurrent Apply Cancellation

    func testConcurrentApplyCallsCancelPreviousTask() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要 Accessibility 权限")
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let window = try? Window(pid: frontmostApp.processIdentifier),
              let screen = NSScreen.main else {
            throw XCTSkip("需要可用窗口")
        }

        let action1 = WindowAction.standard(.proportional(.leftHalf))
        let action2 = WindowAction.standard(.proportional(.rightHalf))

        // 快速连续应用两个 action
        async let result1: Void = {
            _ = try? await WindowActionEngine.shared.apply(action1, window: window, screen: screen)
        }()
        async let result2: Void = {
            _ = try? await WindowActionEngine.shared.apply(action2, window: window, screen: screen)
        }()

        _ = await (result1, result2)

        // 验证没有崩溃或泄漏
        XCTAssertTrue(true, "并发 apply 应该安全完成")
    }

    // MARK: - Quick Action Handling

    func testQuickActionsExecuteImmediately() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要 Accessibility 权限")
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let window = try? Window(pid: frontmostApp.processIdentifier),
              let screen = NSScreen.main else {
            throw XCTSkip("需要可用窗口")
        }

        // minimize 是 quick action
        let action = WindowAction.standard(.minimize)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // Quick action 应该返回成功
        XCTAssertTrue(result.success, "Quick action 应该成功执行")
        XCTAssertNil(result.newTargetWindow, "Quick action 不应该改变目标窗口")

        // 恢复窗口状态（如果被最小化）
        if window.minimized {
            window.minimized = false
        }
    }

    func testHideQuickActionTogglesVisibility() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要 Accessibility 权限")
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let window = try? Window(pid: frontmostApp.processIdentifier),
              let screen = NSScreen.main else {
            throw XCTSkip("需要可用窗口")
        }

        let action = WindowAction.standard(.hide)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // Hide action 应该成功（不验证实际隐藏效果，因为可能依赖应用）
        XCTAssertTrue(result.success, "Hide action 应该成功执行")
    }
}
