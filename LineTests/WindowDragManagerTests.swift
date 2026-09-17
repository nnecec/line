//
//  WindowDragManagerTests.swift
//  LineTests
//
//  Permission-free tests for WindowDragManager's monitoring policy.
//

@testable import Line
import XCTest

final class WindowDragManagerTests: XCTestCase {
    func testMonitoringIsDisabledWhenNoDragFeatureNeedsIt() {
        XCTAssertFalse(
            WindowDragMonitoringPolicy.shouldMonitor(
                windowSnapping: false,
                restoreWindowFrameOnDrag: false,
                hasStashedWindows: false
            )
        )
    }

    func testFrameSamplingPolicyThrottlesContinuousReads() {
        XCTAssertTrue(DragFrameSamplingPolicy.shouldSample(lastSampleTime: nil, now: 1))
        XCTAssertFalse(DragFrameSamplingPolicy.shouldSample(lastSampleTime: 1, now: 1.049))
        XCTAssertTrue(DragFrameSamplingPolicy.shouldSample(lastSampleTime: 1, now: 1.05))
    }

    func testRestrictedScreenSessionIgnoresDragEvents() {
        XCTAssertFalse(WindowDragMonitoringPolicy.shouldProcessDragEvent(isRestricted: true))
        XCTAssertTrue(WindowDragMonitoringPolicy.shouldProcessDragEvent(isRestricted: false))
    }

    func testEachDragFeatureIndependentlyEnablesMonitoring() {
        let featureStates = [
            (windowSnapping: true, restoreWindowFrameOnDrag: false, hasStashedWindows: false),
            (windowSnapping: false, restoreWindowFrameOnDrag: true, hasStashedWindows: false),
            (windowSnapping: false, restoreWindowFrameOnDrag: false, hasStashedWindows: true)
        ]

        for state in featureStates {
            XCTAssertTrue(
                WindowDragMonitoringPolicy.shouldMonitor(
                    windowSnapping: state.windowSnapping,
                    restoreWindowFrameOnDrag: state.restoreWindowFrameOnDrag,
                    hasStashedWindows: state.hasStashedWindows
                )
            )
        }
    }

    func testDragSessionRequestsWindowResolutionOnlyOnce() {
        var session = DragSnapSession()

        XCTAssertEqual(
            session.handle(.dragged(currentFrame: nil, configuration: .disabled)),
            [.resolveWindow]
        )
        XCTAssertEqual(
            session.handle(.dragged(currentFrame: nil, configuration: .disabled)),
            []
        )
    }

    func testDragSessionResolutionFailureIsResetByRelease() {
        var session = DragSnapSession()

        _ = session.handle(.dragged(currentFrame: nil, configuration: .disabled))
        XCTAssertEqual(session.handle(.windowResolutionFailed), [])
        XCTAssertEqual(
            session.handle(.dragged(currentFrame: nil, configuration: .disabled)),
            []
        )
        XCTAssertEqual(
            session.handle(.released(currentFrame: nil, hasSnapAction: false, windowSnapping: false)),
            [.closePreview, .clearRuntimeState]
        )
        XCTAssertEqual(
            session.handle(.dragged(currentFrame: nil, configuration: .disabled)),
            [.resolveWindow]
        )
    }

    func testDragSessionProducesMoveEffectsInExecutionOrder() {
        var session = DragSnapSession()
        let initial = CGRect(x: 0, y: 0, width: 100, height: 100)
        let moved = CGRect(x: 50, y: 50, width: 120, height: 100)

        _ = session.handle(.dragged(currentFrame: nil, configuration: .disabled))
        _ = session.handle(.windowResolved(initialFrame: initial))

        XCTAssertEqual(
            session.handle(
                .dragged(
                    currentFrame: moved,
                    configuration: .init(windowSnapping: true, restoreInitialWindowSize: true)
                )
            ),
            [.restoreInitialWindowSize, .updateSnap, .notifyWindowManipulated, .eraseWindowRecords]
        )
    }

    func testDragSessionPureResizeOnlyUpdatesWindowBookkeeping() {
        var session = DragSnapSession()
        let initial = CGRect(x: 0, y: 0, width: 100, height: 100)
        let resized = CGRect(x: 0, y: 0, width: 150, height: 100)

        _ = session.handle(.dragged(currentFrame: nil, configuration: .disabled))
        _ = session.handle(.windowResolved(initialFrame: initial))

        XCTAssertEqual(
            session.handle(
                .dragged(
                    currentFrame: resized,
                    configuration: .init(windowSnapping: true, restoreInitialWindowSize: true)
                )
            ),
            [.notifyWindowManipulated, .eraseWindowRecords]
        )
    }

    func testDragSessionReleaseAppliesSnapThenClearsRuntimeState() {
        var session = DragSnapSession()
        let initial = CGRect(x: 0, y: 0, width: 100, height: 100)
        let moved = CGRect(x: 50, y: 50, width: 100, height: 100)

        _ = session.handle(.dragged(currentFrame: nil, configuration: .disabled))
        _ = session.handle(.windowResolved(initialFrame: initial))

        XCTAssertEqual(
            session.handle(.released(currentFrame: moved, hasSnapAction: true, windowSnapping: true)),
            [.closePreview, .applySnap, .clearRuntimeState]
        )
    }

    func testDragSessionReleaseStillCleansUpWhenSnappingWasDisabledMidDrag() {
        var session = DragSnapSession()
        _ = session.handle(.dragged(currentFrame: nil, configuration: .disabled))
        _ = session.handle(.windowResolved(initialFrame: CGRect(x: 0, y: 0, width: 100, height: 100)))

        XCTAssertEqual(
            session.handle(
                .released(
                    currentFrame: CGRect(x: 50, y: 50, width: 100, height: 100),
                    hasSnapAction: true,
                    windowSnapping: false
                )
            ),
            [.closePreview, .clearRuntimeState]
        )
    }

    func testDragSessionUsesLastKnownFrameWhenReleaseSnapshotIsUnavailable() {
        var session = DragSnapSession()
        let initial = CGRect(x: 0, y: 0, width: 100, height: 100)
        let moved = CGRect(x: 50, y: 50, width: 100, height: 100)

        _ = session.handle(.dragged(currentFrame: nil, configuration: .disabled))
        _ = session.handle(.windowResolved(initialFrame: initial))
        _ = session.handle(.dragged(currentFrame: moved, configuration: .disabled))
        XCTAssertEqual(session.lastKnownFrame, moved)

        XCTAssertEqual(
            session.handle(.released(currentFrame: nil, hasSnapAction: true, windowSnapping: true)),
            [.closePreview, .applySnap, .clearRuntimeState]
        )
        XCTAssertNil(session.lastKnownFrame)
    }
}

final class DragEventCoalescerTests: XCTestCase {
    typealias Coalescer = DragEventCoalescer<Int>

    func testDraggedEventsCoalesceToLatestState() {
        let coalescer = Coalescer()
        XCTAssertTrue(coalescer.submitDragged(1))
        XCTAssertFalse(coalescer.submitDragged(2))
        XCTAssertFalse(coalescer.submitDragged(3))

        guard let scheduled = coalescer.next() else {
            return XCTFail("Expected a dragged event")
        }
        XCTAssertEqual(scheduled.generation, 0)
        guard case .dragged(3) = scheduled.event else {
            return XCTFail("The drain must consume the latest state")
        }
        XCTAssertNil(coalescer.next())
    }

    func testReleaseDiscardsPendingDraggedAndHasPriority() {
        let coalescer = Coalescer()
        XCTAssertTrue(coalescer.submitDragged(1))
        XCTAssertFalse(coalescer.submitReleased(2))

        guard case .released(2) = coalescer.next()?.event else {
            return XCTFail("Release must take priority")
        }
        XCTAssertNil(coalescer.next())
    }

    func testInvalidationAdvancesGenerationAndDropsOldWork() {
        let coalescer = Coalescer()
        XCTAssertTrue(coalescer.submitDragged(1))
        coalescer.invalidate()
        XCTAssertEqual(coalescer.generation, 1)
        XCTAssertNil(coalescer.next())

        XCTAssertTrue(coalescer.submitDragged(2))
        guard case .dragged(2) = coalescer.next()?.event else {
            return XCTFail("Reset must allow a fresh snapshot")
        }
    }

    func testReleaseInvalidatesDraggedGenerationButStillDrainsRelease() {
        let coalescer = Coalescer()
        XCTAssertTrue(coalescer.submitDragged(1))
        XCTAssertFalse(coalescer.submitReleased(2))
        XCTAssertFalse(coalescer.submitDragged(3))
        XCTAssertEqual(coalescer.generation, 1)

        guard case .released(2) = coalescer.next()?.event else {
            return XCTFail("Release must not be discarded by generation invalidation")
        }
        XCTAssertNil(coalescer.next())
        coalescer.invalidate()
        XCTAssertTrue(coalescer.submitDragged(4))
    }

    func testCoalescerCanBeReusedAfterDrain() {
        let coalescer = Coalescer()
        XCTAssertTrue(coalescer.submitDragged(1))
        XCTAssertNotNil(coalescer.next())
        XCTAssertNil(coalescer.next())

        XCTAssertTrue(coalescer.submitDragged(2))
        guard case .dragged(2) = coalescer.next()?.event else {
            return XCTFail("Expected the next session's dragged state")
        }
    }
}
