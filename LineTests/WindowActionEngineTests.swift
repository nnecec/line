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

@testable import Line
import XCTest

@MainActor
final class WindowActionEngineTests: XCTestCase {
    func testLatestTaskRegistryKeepsReplacementWhenOlderTaskFinishes() async throws {
        let registry = LatestTaskRegistry<Int, Int>()
        let firstStarted = expectation(description: "first operation started")
        let releaseFirst = AsyncGate()
        let first = registry.replace(for: 1) {
            firstStarted.fulfill()
            await releaseFirst.wait()
            return 1
        }

        await fulfillment(of: [firstStarted], timeout: 1)
        let second = registry.replace(for: 1) { 2 }
        releaseFirst.open()

        XCTAssertEqual(try await first.task.value, 1)

        registry.remove(first, for: 1)
        XCTAssertEqual(registry.activeCount, 1)

        XCTAssertEqual(try await second.task.value, 2)
        registry.remove(second, for: 1)
        XCTAssertEqual(registry.activeCount, 0)
    }

    func testLatestTaskRegistryCancelsReplacedTask() async {
        let registry = LatestTaskRegistry<Int, Int>()
        let firstStarted = expectation(description: "first operation started")
        let first = registry.replace(for: 1) {
            firstStarted.fulfill()
            try await Task.sleep(for: .seconds(30))
            return 1
        }

        await fulfillment(of: [firstStarted], timeout: 1)
        let second = registry.replace(for: 1) { 2 }

        switch await first.task.result {
        case .success:
            XCTFail("Replacing a task must cancel the previous task")
        case let .failure(error):
            XCTAssertTrue(error is CancellationError, "unexpected replacement error: \(error)")
        }

        registry.remove(first, for: 1)
        XCTAssertEqual(registry.activeCount, 1)
        registry.remove(second, for: 1)
    }

    // MARK: - Basic Apply Success Path

    func testApplyStandardActionReturnsSuccess() async throws {
        guard AccessibilityManager.shared.isGranted else {
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

    func testResizeActionWithoutWindowFails() async throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("没有可用显示器")
        }

        let result = try await WindowActionEngine.shared.apply(
            .standard(.maximize),
            window: nil,
            screen: screen
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.newTargetWindow)
    }

    // MARK: - Focus Action Routing

    func testApplyFocusActionRoutesToWindowUtility() async throws {
        guard AccessibilityManager.shared.isGranted else {
            throw XCTSkip("需要 Accessibility 权限")
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let window = try? Window(pid: frontmostApp.processIdentifier),
              let screen = NSScreen.main else {
            throw XCTSkip("需要可用窗口")
        }

        let action = WindowAction.focus(.down)

        let result = try await WindowActionEngine.shared.apply(action, window: window, screen: screen)

        guard let targetWindow = result.newTargetWindow else {
            throw XCTSkip("当前窗口下方没有可聚焦窗口")
        }

        XCTAssertTrue(result.success)
        XCTAssertNotEqual(targetWindow.cgWindowID, window.cgWindowID)
    }

    func testDirectionalFocusActionUsesDirectionalRoute() {
        var routedDirection: NavigationDirection?
        var stackRouteCallCount = 0

        let target = WindowActionEngine.resolveFocusTarget(
            for: .focus(.down),
            currentWindow: nil,
            directionalFocus: { _, direction in
                routedDirection = direction
                return nil
            },
            stackFocus: { _ in
                stackRouteCallCount += 1
                return nil
            }
        )

        XCTAssertNil(target)
        XCTAssertEqual(routedDirection, .down)
        XCTAssertEqual(stackRouteCallCount, 0)
    }

    func testStackFocusActionUsesStackRoute() {
        var directionalRouteCallCount = 0
        var stackRouteCallCount = 0

        let target = WindowActionEngine.resolveFocusTarget(
            for: .focus(.focusNextInStack),
            currentWindow: nil,
            directionalFocus: { _, _ in
                directionalRouteCallCount += 1
                return nil
            },
            stackFocus: { _ in
                stackRouteCallCount += 1
                return nil
            }
        )

        XCTAssertNil(target)
        XCTAssertEqual(directionalRouteCallCount, 0)
        XCTAssertEqual(stackRouteCallCount, 1)
    }

    // MARK: - Quick Action Handling

    func testQuickActionsExecuteImmediately() async throws {
        guard AccessibilityManager.shared.isGranted else {
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
        guard AccessibilityManager.shared.isGranted else {
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

@MainActor
private final class AsyncGate {
    private var continuation: CheckedContinuation<(), Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
