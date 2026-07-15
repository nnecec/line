//
//  AccessibilityManagerTests.swift
//  LineTests
//
//  测试 AccessibilityManager 权限状态管理
//
//  ## 测试限制
//
//  这些是**集成测试**，使用真实的系统 Accessibility API：
//  - 依赖运行环境的实际权限状态
//  - 无法 mock DistributedNotificationCenter（私有系统服务）
//  - tccutil 测试需要用户授权，CI 中跳过
//  - 无法触发真实的权限变化通知（需要手动测试）
//
//  ## 手动测试场景
//
//  1. 运行应用 → 系统偏好设置 → 移除权限 → 验证 UI 更新
//  2. 运行应用 → 系统偏好设置 → 授予权限 → 验证 UI 更新
//  3. 快速连续授予/移除 → 验证去重逻辑
//

import XCTest
@testable import Line

final class AccessibilityManagerTests: XCTestCase {

    // MARK: - 基本权限检查（同步路径）

    func testCheckAccessibilityReturnsBool() {
        // 这个测试依赖实际系统权限状态
        // 在 CI 中可能是 false，本地可能是 true
        let result = AccessibilityManager.checkAccessibility()
        XCTAssertNotNil(result, "checkAccessibility() 应该返回布尔值")
        // 不断言具体值，因为依赖运行环境
    }

    // MARK: - stream() 初始值

    func testStreamEmitsInitialValueWhenRequested() async {
        let manager = AccessibilityManager.shared
        let stream = manager.stream(initial: true)

        var iterator = stream.makeAsyncIterator()
        let firstValue = await iterator.next()

        XCTAssertNotNil(firstValue, "stream(initial: true) 应该立即发射初始值")
        // 值应该匹配当前权限状态
        XCTAssertEqual(firstValue, AccessibilityManager.checkAccessibility())
    }

    func testStreamDoesNotEmitInitialValueWhenNotRequested() async {
        let manager = AccessibilityManager.shared
        let stream = manager.stream(initial: false)

        // 设置超时，因为我们期待不会立即有值
        let expectation = XCTestExpectation(description: "不应该立即收到值")
        expectation.isInverted = true

        Task {
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 0.5)
    }

    // MARK: - 并发流消费者

    func testMultipleConcurrentStreamsWork() async {
        let manager = AccessibilityManager.shared

        let stream1 = manager.stream(initial: true)
        let stream2 = manager.stream(initial: true)
        let stream3 = manager.stream(initial: true)

        async let value1 = stream1.makeAsyncIterator().next()
        async let value2 = stream2.makeAsyncIterator().next()
        async let value3 = stream3.makeAsyncIterator().next()

        let results = await (value1, value2, value3)

        XCTAssertNotNil(results.0, "流 1 应该收到初始值")
        XCTAssertNotNil(results.1, "流 2 应该收到初始值")
        XCTAssertNotNil(results.2, "流 3 应该收到初始值")

        // 所有流应该收到相同的权限状态
        XCTAssertEqual(results.0, results.1)
        XCTAssertEqual(results.1, results.2)
    }

    // MARK: - tccutil 重置

    func testResetAccessibilityExecutesWithoutCrashing() async {
        // 这个测试只验证方法不会崩溃
        // 实际重置需要用户授权，在自动化测试中不可行

        // 注意：这会弹出授权对话框，所以标记为手动测试
        // 在 CI 中跳过
        #if !CI
        let expectation = XCTestExpectation(description: "重置完成")

        Task {
            await AccessibilityManager.resetAccessibility()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        #else
        throw XCTSkip("tccutil 重置在 CI 中跳过")
        #endif
    }

    // MARK: - 流清理

    func testStreamCleanupOnCancellation() async {
        let manager = AccessibilityManager.shared

        let task = Task {
            let stream = manager.stream(initial: true)
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            // 任务将被取消
        }

        // 短暂等待后取消
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // 等待取消完成
        _ = await task.result

        // 验证没有内存泄漏（实际上很难在单元测试中验证）
        // 这里主要是确保没有崩溃
        XCTAssertTrue(task.isCancelled)
    }
}
