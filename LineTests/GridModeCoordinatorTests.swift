//
//  GridModeCoordinatorTests.swift
//  LineTests
//
//  Created by Claude on 2026-07-08.
//

@testable import Line
import XCTest

@MainActor
final class GridModeCoordinatorTests: XCTestCase {
    private var coordinator: GridModeCoordinator!
    private var indicatorService: WindowActionIndicatorService!

    override func setUp() {
        super.setUp()
        indicatorService = WindowActionIndicatorService()
        coordinator = GridModeCoordinator(indicatorService: indicatorService)
    }

    override func tearDown() {
        coordinator = nil
        indicatorService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationCreatesCoordinator() {
        XCTAssertNotNil(coordinator)
        XCTAssertFalse(coordinator.isActive)
    }

    // MARK: - Preview Throttle Policy

    func testPreviewThrottleIntervalIsWithinTargetRange() {
        // Plan 008: hover previews debounced to ~16–32 ms.
        let interval = GridMouseObserver.previewThrottleInterval
        XCTAssertGreaterThanOrEqual(interval, .milliseconds(16))
        XCTAssertLessThanOrEqual(interval, .milliseconds(32))
    }

    // MARK: - State Tests

    func testIsActiveReturnsFalseInitially() {
        XCTAssertFalse(coordinator.isActive)
    }

    func testIsActiveReturnsTrueAfterOpen() async {
        // Given: coordinator is not active
        XCTAssertFalse(coordinator.isActive)

        // When: open grid mode with no window
        var completionCalled = false
        let result = await coordinator.open(
            window: nil,
            initialMousePosition: CGPoint(x: 100, y: 100),
            onComplete: {
                completionCalled = true
            }
        )

        // Then: coordinator should be active
        XCTAssertEqual(result, .opened)
        XCTAssertTrue(coordinator.isActive)
        XCTAssertFalse(completionCalled) // Not called yet until close
    }

    func testIsActiveReturnsFalseAfterClose() async {
        // Given: coordinator is active
        let result = await coordinator.open(
            window: nil,
            initialMousePosition: CGPoint(x: 100, y: 100),
            onComplete: {}
        )
        XCTAssertEqual(result, .opened)
        XCTAssertTrue(coordinator.isActive)

        // When: close grid mode
        coordinator.close(reason: .cancelled)

        // Then: coordinator should not be active
        XCTAssertFalse(coordinator.isActive)
    }

    // MARK: - Open/Close Tests

    func testOpenWithNilWindowDoesNotCrash() async {
        // When: open with nil window
        let result = await coordinator.open(
            window: nil,
            initialMousePosition: CGPoint(x: 100, y: 100),
            onComplete: {}
        )

        // Then: should be active
        XCTAssertEqual(result, .opened)
        XCTAssertTrue(coordinator.isActive)
    }

    func testCloseWithCancelledReason() async {
        // Given: coordinator is active
        var completionCalled = false
        let result = await coordinator.open(
            window: nil,
            initialMousePosition: CGPoint(x: 100, y: 100),
            onComplete: {
                completionCalled = true
            }
        )
        XCTAssertEqual(result, .opened)

        // When: close with cancelled reason
        coordinator.close(reason: .cancelled)

        // Then: direct close only cleans up state; completion belongs to commit/cancel flows
        XCTAssertFalse(completionCalled)
        XCTAssertFalse(coordinator.isActive)
    }

    func testCloseWithCommittedReason() async {
        // Given: coordinator is active
        var completionCalled = false
        let result = await coordinator.open(
            window: nil,
            initialMousePosition: CGPoint(x: 100, y: 100),
            onComplete: {
                completionCalled = true
            }
        )
        XCTAssertEqual(result, .opened)

        // When: close with committed reason
        coordinator.close(reason: .committed)

        // Then: direct close only cleans up state; completion belongs to commit/cancel flows
        XCTAssertFalse(completionCalled)
        XCTAssertFalse(coordinator.isActive)
    }

    // MARK: - Commit Hovered Selection Tests

    func testCommitHoveredSelectionWhenNotActive() async {
        // Given: coordinator is not active
        XCTAssertFalse(coordinator.isActive)

        // When: commit hovered selection
        var completionCalled = false
        await coordinator.commitHoveredSelection(onComplete: {
            completionCalled = true
        })

        // Then: should call completion (no-op)
        XCTAssertTrue(completionCalled)
        XCTAssertFalse(coordinator.isActive)
    }

    func testCommitHoveredSelectionWhenActive() async {
        // Given: coordinator is active
        let result = await coordinator.open(
            window: nil,
            initialMousePosition: CGPoint(x: 100, y: 100),
            onComplete: {}
        )
        XCTAssertEqual(result, .opened)
        XCTAssertTrue(coordinator.isActive)

        // When: commit hovered selection
        var commitCompletionCalled = false
        await coordinator.commitHoveredSelection(onComplete: {
            commitCompletionCalled = true
        })

        // Then: should call completion and close
        XCTAssertTrue(commitCompletionCalled)
        XCTAssertFalse(coordinator.isActive)
    }

    // MARK: - Multiple Open/Close Cycles

    func testMultipleOpenCloseCycles() async {
        for _ in 0 ..< 3 {
            // Open
            let result = await coordinator.open(
                window: nil,
                initialMousePosition: CGPoint(x: 100, y: 100),
                onComplete: {}
            )
            XCTAssertEqual(result, .opened)
            XCTAssertTrue(coordinator.isActive)

            // Close
            coordinator.close(reason: .cancelled)
            XCTAssertFalse(coordinator.isActive)
        }
    }
}
