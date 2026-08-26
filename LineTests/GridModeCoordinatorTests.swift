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

    // MARK: - Grid Memory Lifecycle Policy

    func testGridMemorySaveRequiresLivePermissionApplicationAndSession() {
        XCTAssertTrue(
            GridMemoryLifecyclePolicy.shouldSaveAfterSuccessfulApply(
                requested: true,
                hasMemorySize: true,
                isAccessibilityGranted: true,
                isTargetApplicationRunning: true,
                isSessionGenerationCurrent: true
            )
        )

        XCTAssertFalse(
            GridMemoryLifecyclePolicy.shouldSaveAfterSuccessfulApply(
                requested: true,
                hasMemorySize: true,
                isAccessibilityGranted: false,
                isTargetApplicationRunning: true,
                isSessionGenerationCurrent: true
            )
        )
        XCTAssertFalse(
            GridMemoryLifecyclePolicy.shouldSaveAfterSuccessfulApply(
                requested: true,
                hasMemorySize: true,
                isAccessibilityGranted: true,
                isTargetApplicationRunning: false,
                isSessionGenerationCurrent: true
            )
        )
        XCTAssertFalse(
            GridMemoryLifecyclePolicy.shouldSaveAfterSuccessfulApply(
                requested: true,
                hasMemorySize: true,
                isAccessibilityGranted: true,
                isTargetApplicationRunning: true,
                isSessionGenerationCurrent: false
            )
        )
    }

    func testTerminatedProcessOnlyCancelsItsOwnGrid() {
        XCTAssertTrue(
            GridMemoryLifecyclePolicy.shouldCancelGrid(
                targetProcessIdentifier: 42,
                terminatedProcessIdentifier: 42
            )
        )
        XCTAssertFalse(
            GridMemoryLifecyclePolicy.shouldCancelGrid(
                targetProcessIdentifier: 43,
                terminatedProcessIdentifier: 42
            )
        )
        XCTAssertFalse(
            GridMemoryLifecyclePolicy.shouldCancelGrid(
                targetProcessIdentifier: nil,
                terminatedProcessIdentifier: 42
            )
        )
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

@MainActor
final class WindowEngineBoundaryTests: XCTestCase {
    func testNoOpFocusAndQuickActionsDoNotEnterResize() async throws {
        for action in [
            BoundWindowAction(action: .special(.noAction), keybind: []),
            BoundWindowAction(action: .focus(.focusDown), keybind: []),
            BoundWindowAction(action: .special(.minimize), keybind: [])
        ] {
            let fake = BoundaryFake()
            let outcome = try await WindowEngine.execute(
                makeRequest(action: action),
                using: fake.boundary
            )

            XCTAssertNil(outcome)
            XCTAssertEqual(fake.effects, [])
        }
    }

    func testResizeRecordsFirstFrameAndEffectsInOrder() async throws {
        let fake = BoundaryFake()
        let action = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let outcome = try await WindowEngine.execute(
            makeRequest(action: action),
            using: fake.boundary
        )

        XCTAssertEqual(outcome?.finalFrame, fake.finalFrame)
        XCTAssertEqual(fake.effects, ["record-first", "record", "resize", "stash"])
    }

    func testUnavailableSystemWindowManagerUsesOrdinaryResize() async throws {
        let fake = BoundaryFake(systemFrame: nil)
        let action = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let request = makeRequest(action: action, useSystemWindowManager: true)
        let outcome = try await WindowEngine.execute(request, using: fake.boundary)

        XCTAssertEqual(outcome?.finalFrame, fake.finalFrame)
        XCTAssertTrue(fake.effects.contains("system"))
        XCTAssertTrue(fake.effects.contains("resize"))
        XCTAssertEqual(fake.effects.last, "stash")
    }

    func testCancellationRemainsCancellationError() async {
        let fake = BoundaryFake(resizeError: CancellationError())
        let action = BoundWindowAction(action: .standard(.maximize), keybind: [])

        do {
            _ = try await WindowEngine.execute(makeRequest(action: action), using: fake.boundary)
            XCTFail("Cancellation must be propagated")
        } catch {
            XCTAssertTrue(error is CancellationError)
            XCTAssertFalse(fake.effects.contains("stash"))
        }
    }

    func testResizeErrorFallsBackToCurrentFrame() async throws {
        let fake = BoundaryFake(resizeError: BoundaryFakeError.resizeFailed)
        let action = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let outcome = try await WindowEngine.execute(makeRequest(action: action), using: fake.boundary)

        XCTAssertEqual(outcome?.finalFrame, fake.currentFrame)
        XCTAssertFalse(fake.effects.contains("stash"))
    }

    func testSuccessfulFinalFrameResizeRecordsAndRunsStashAftermath() async throws {
        let fake = BoundaryFake()
        let action = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let request = makeRequest(action: action, shouldStoreAsFinalFrame: true)
        _ = try await WindowEngine.execute(request, using: fake.boundary)

        XCTAssertEqual(fake.effects, ["record-first", "resize", "record-final", "stash"])
    }

    private func makeRequest(
        action: BoundWindowAction,
        useSystemWindowManager: Bool = false,
        shouldStoreAsFinalFrame: Bool = false
    ) -> WindowExecutionRequest {
        WindowExecutionRequest(
            action: action,
            screen: NSScreen.main ?? NSScreen.screens[0],
            targetFrame: CGRect(x: 20, y: 20, width: 700, height: 500),
            paddedBounds: CGRect(x: 0, y: 0, width: 1440, height: 900),
            resolvedWindowProperties: .init(
                snapshotFrame: CGRect(x: 100, y: 100, width: 500, height: 400),
                isResizable: true,
                isFullscreen: false,
                isEnhancedUserInterface: false
            ),
            willChangeScreens: false,
            shouldStoreAsFinalFrame: shouldStoreAsFinalFrame,
            useSystemWindowManager: useSystemWindowManager,
            focusWindowOnResize: false,
            moveCursorWithWindow: false,
            animate: false
        )
    }
}

@MainActor
private final class BoundaryFake {
    var effects: [String] = []
    let currentFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
    let finalFrame = CGRect(x: 20, y: 20, width: 700, height: 500)
    private let systemFrame: CGRect?
    private let resizeError: Error?

    init(systemFrame: CGRect? = nil, resizeError: Error? = nil) {
        self.systemFrame = systemFrame
        self.resizeError = resizeError
    }

    lazy var boundary = WindowExecutionBoundary(
        currentFrame: { self.currentFrame },
        recordFirstIfNeeded: { _ in self.effects.append("record-first") },
        record: { [self] properties, _ in
            effects.append(properties?.frame == finalFrame ? "record-final" : "record")
        },
        removeLastAction: { self.effects.append("remove-last") },
        resolveRecord: { nil },
        focus: { self.effects.append("focus") },
        setFullscreen: { _ in self.effects.append("fullscreen-off") },
        resize: { [self] _, _, _, _, _ in
            effects.append("resize")
            if let resizeError {
                throw resizeError
            }
            return finalFrame
        },
        systemResize: { [self] _ in
            effects.append("system")
            return systemFrame
        },
        moveCursor: { _ in self.effects.append("cursor") },
        stashAftermath: { _, _ in self.effects.append("stash") }
    )
}

enum BoundaryFakeError: Error {
    case resizeFailed
}
