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
}
