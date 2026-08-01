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
}
