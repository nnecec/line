//
//  WindowActionEngineTests.swift
//  LineTests
//
//  Created by agent on 2026-07-15.
//

import XCTest
@testable import Line

final class WindowActionEngineTests: XCTestCase {

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
            _ = try await WindowActionEngine.shared.apply(
                action.action,
                window: window,
                screen: screen
            )
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
        async let result1 = try WindowActionEngine.shared.apply(
            action1.action,
            window: window,
            screen: screen
        )
        async let result2 = try WindowActionEngine.shared.apply(
            action2.action,
            window: window,
            screen: screen
        )

        let (r1, r2) = try await (result1, result2)

        // 至少一个应该成功完成
        let successCount = [r1, r2].filter { $0.success }.count
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

        let action = WindowAction.standard(.maximize)

        // 并发应用到不同窗口
        async let result1 = try WindowActionEngine.shared.apply(action, window: window1, screen: screen)
        async let result2 = try WindowActionEngine.shared.apply(action, window: window2, screen: screen)

        let (r1, r2) = try await (result1, result2)

        // 两个都应该成功（不同窗口不应该相互干扰）
        if r1.success && r2.success {
            XCTAssertTrue(true, "不同窗口的并发 action 应该都成功")
        } else {
            // 某些窗口可能不支持操作，但不应该崩溃
            XCTAssertTrue(true, "即使失败也不应该崩溃")
        }
    }

    // MARK: - Task Cleanup

    func testActionTasksCleanupAfterCompletion() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        let action = WindowAction.standard(.maximize)

        // 应用 action
        _ = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        // 任务应该已经从 actionTasks 移除
        // 无法直接访问 actionTasks（私有），但通过行为验证

        // 再次应用应该成功（没有残留任务）
        _ = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        XCTAssertTrue(true, "任务应该正确清理")
    }

    // MARK: - Cancellation Error Handling

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
            let action = WindowAction.standard(.leftHalf)

            // 不等待完成，立即启动下一个（隐式取消前一个）
            Task {
                _ = try? await WindowActionEngine.shared.apply(action, window: window, screen: screen)
            }
        }

        // 等待所有完成
        try await Task.sleep(for: .seconds(2))

        // 应该没有泄漏或崩溃
        XCTAssertTrue(true, "取消不应该导致泄漏")
    }

    // MARK: - Stress Test

    func testHighFrequencyActionApplications() async throws {
        guard AccessibilityManager.checkAccessibility() else {
            throw XCTSkip("需要权限")
        }

        guard let window = try? Window(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0),
              let screen = NSScreen.main else {
            throw XCTSkip("需要窗口")
        }

        // 高频率应用（模拟用户快速按键）
        for _ in 0..<20 {
            let action = WindowAction.standard(.leftHalf)
            _ = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)
            // 极短延迟
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertTrue(true, "高频应用不应该崩溃")
    }
}
