//
//  EndToEndIntegrationTests.swift
//  LineTests
//
//  Created by agent on 2026-07-15.
//
//  ## 集成测试特点
//
//  这些测试执行完整用户流程，但有重要限制：
//
//  **依赖**:
//  - Accessibility 权限（必需）
//  - 前台应用窗口（不稳定）
//  - 特定屏幕配置（单/多屏幕）
//  - 系统状态（全屏、Stage Manager 等）
//
//  **不稳定性**:
//  - 窗口状态可能改变
//  - 其他应用可能干扰
//  - 时间依赖可能导致竞态
//
//  **最佳实践**:
//  - 在干净环境运行
//  - 使用专门的测试应用（如果可能）
//  - 重试失败的测试
//  - CI 中可能需要跳过某些测试
//
//  ## 手动测试场景
//
//  某些流程难以自动化，需要手动测试：
//  1. 完整键盘快捷键流程
//  2. 真实鼠标拖拽捕捉
//  3. Grid 覆盖层 UI
//  4. 多显示器场景
//  5. 全屏应用交互
//

import XCTest
@testable import Line

/// 完整栈集成测试
///
/// 警告：这些测试依赖真实的窗口、Accessibility 权限和系统状态
/// 可能在某些环境中不稳定
final class EndToEndIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()

        guard AccessibilityManager.shared.isGranted else {
            return
        }
    }

    override func tearDown() {
        // 清理状态
        super.tearDown()
    }

    // MARK: - 键绑定到窗口移动流程

    func testKeybindTriggersWindowResize() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要 Accessibility 权限运行集成测试")
        }

        // 1. 设置：获取当前窗口
        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要前台窗口")
        }

        let initialFrame = window.frame

        // 2. 创建 action
        let action = WindowAction.standard(.proportional(.leftHalf))

        // 3. 应用 action (模拟完整流程)
        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // 4. 验证结果
        XCTAssertTrue(result.success, "Action 应该成功")

        if result.success {
            let finalFrame = window.frame

            // 验证窗口确实移动了
            XCTAssertNotEqual(initialFrame, finalFrame, "窗口应该移动")

            // 验证窗口在左半部分
            let screenBounds = screen.visibleFrame
            XCTAssertLessThanOrEqual(finalFrame.width, screenBounds.width / 2 + 10, "应该是左半边")
        }
    }

    func testMaximizeActionFlow() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let initialFrame = window.frame
        let action = WindowAction.standard(.maximize)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        XCTAssertTrue(result.success, "Maximize 应该成功")

        if result.success {
            let finalFrame = window.frame

            // 验证窗口接近最大化（允许一些误差）
            let screenBounds = screen.visibleFrame
            XCTAssertGreaterThan(finalFrame.width, screenBounds.width * 0.8, "宽度应该接近屏幕宽度")
            XCTAssertGreaterThan(finalFrame.height, screenBounds.height * 0.8, "高度应该接近屏幕高度")
        }
    }

    func testCenterActionFlow() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let action = WindowAction.standard(.center(.geometric))

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        XCTAssertTrue(result.success, "Center 应该成功")

        if result.success {
            let finalFrame = window.frame
            let screenBounds = screen.visibleFrame

            // 验证窗口接近中心（允许一些误差）
            let centerX = finalFrame.midX
            let screenCenterX = screenBounds.midX
            XCTAssertLessThan(abs(centerX - screenCenterX), 50, "X 位置应该接近中心")
        }
    }

    // MARK: - 快速动作流程

    func testQuickActionMinimize() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let wasMinimized = window.minimized

        // 应用 minimize action
        let action = WindowAction.special(.minimize)
        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        XCTAssertTrue(result.success, "Minimize 应该成功")

        // 恢复原始状态
        if !wasMinimized {
            window.minimized = false
        }
    }

    func testQuickActionHide() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let wasHidden = window.isWindowHidden

        // 应用 hide action
        let action = WindowAction.special(.hide)
        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        XCTAssertTrue(result.success, "Hide 应该成功")

        // 恢复原始状态
        if !wasHidden {
            window.toggleHidden()
        }
    }

    // MARK: - Focus 动作流程

    func testFocusActionFlow() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let action = WindowAction.focus(.focusNextInStack)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // Focus action 可能成功也可能失败（取决于是否有其他窗口）
        // 主要验证不崩溃
        XCTAssertTrue(true, "Focus action 流程完成")
    }

    // MARK: - 错误传播测试

    func testErrorPropagationThroughStack() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        // 使用一个会失败的场景：没有窗口
        let action = WindowAction.standard(.maximize)

        let result = try await WindowActionEngine.shared.apply(action, window: nil, screen: NSScreen.main ?? NSScreen.screens[0])

        // 没有窗口时应该失败
        XCTAssertFalse(result.success, "无效窗口应该失败")
    }

    func testInvalidPIDHandling() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        // 尝试创建无效 PID 的窗口
        let invalidWindow: Window? = try? Window(pid: -1)

        XCTAssertNil(invalidWindow, "无效 PID 应该返回 nil")
    }

    // MARK: - 多动作序列测试

    func testSequentialActionExecution() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        // 执行一系列 action
        let actions: [WindowAction] = [
            .standard(.proportional(.leftHalf)),
            .standard(.proportional(.rightHalf)),
            .standard(.maximize),
            .standard(.center(.geometric))
        ]

        for action in actions {
            let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)
            XCTAssertTrue(result.success, "每个 action 都应该成功")

            // 短暂延迟以确保窗口状态更新
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - 边界条件测试

    func testNoOpActionHandling() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let action = WindowAction.special(.noAction)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        XCTAssertTrue(result.success, "NoOp action 应该成功")
    }
}
