//
//  StashSessionFramePolicyTests.swift
//  LineTests
//

import AppKit
@testable import Line
import XCTest

final class StashSessionFramePolicyTests: XCTestCase {
    func testFrameForLayoutPrefersRevealedFrameWhenPresent() {
        let revealed = CGRect(x: 100, y: 50, width: 800, height: 600)
        let current = CGRect(x: -50, y: 0, width: 40, height: 600)

        let result = StashSessionFramePolicy.frameForLayout(
            revealedFrame: revealed,
            currentFrame: current
        )

        XCTAssertEqual(result, revealed)
    }

    func testFrameForLayoutFallsBackToCurrentFrameWhenRevealedIsNil() {
        let current = CGRect(x: 10, y: 20, width: 300, height: 200)

        let result = StashSessionFramePolicy.frameForLayout(
            revealedFrame: nil,
            currentFrame: current
        )

        XCTAssertEqual(result, current)
    }

    @MainActor
    func testPrepareResolvedPreservesOverrideWindowPropertiesFrame() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            XCTFail("No screen available for test")
            return
        }

        let overrideFrame = CGRect(x: 40, y: 80, width: 640, height: 480)
        let override = WindowProperties(frame: overrideFrame, isResizable: true)
        let padding = PaddingConfiguration.getConfiguredPadding(for: screen)

        let prepared = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .special(.noSelection), keybind: []),
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: padding,
            initialMousePosition: .zero,
            windowProperties: override,
            record: nil
        )

        XCTAssertEqual(prepared.request.windowProperties?.frame, overrideFrame)
        XCTAssertEqual(prepared.request.windowProperties?.isResizable, true)
    }
}
