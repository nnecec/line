//
//  WindowResizeExecutionSessionTests.swift
//  LineTests
//

import AppKit
@testable import Line
import XCTest

@MainActor
final class WindowResizeExecutionSessionTests: XCTestCase {
    private var screen: NSScreen!

    override func setUp() {
        super.setUp()
        screen = NSScreen.main ?? NSScreen.screens.first
        XCTAssertNotNil(screen)
    }

    func testLayoutFramePrefersRevealedFrame() {
        let revealed = CGRect(x: 10, y: 20, width: 300, height: 200)
        let current = CGRect(x: -50, y: 0, width: 300, height: 200)
        XCTAssertEqual(
            WindowResizeExecution.layoutFrame(revealedFrame: revealed, currentFrame: current),
            revealed
        )
    }

    func testLayoutFrameFallsBackToCurrent() {
        let current = CGRect(x: 1, y: 2, width: 3, height: 4)
        XCTAssertEqual(
            WindowResizeExecution.layoutFrame(revealedFrame: nil, currentFrame: current),
            current
        )
    }

    func testBootstrapUsesInjectedRevealedFrameWithoutWindow() async {
        // No window: bootstrap still produces a Prepared Resize for noSelection.
        let prepared = await WindowResizeExecution.bootstrap(
            window: nil,
            screen: screen,
            initialMousePosition: CGPoint(x: 12, y: 34),
            revealedFrameForStashedWindow: { _ in
                XCTFail("should not query stash without a window")
                return nil
            }
        )
        XCTAssertEqual(prepared.action.direction, .noSelection)
        XCTAssertEqual(prepared.initialMousePosition, CGPoint(x: 12, y: 34))
        XCTAssertEqual(prepared.screen, screen)
    }

    func testTransitionReusesLayoutSnapshotAndDoesNotRequireAX() {
        let layoutFrame = CGRect(x: 100, y: 100, width: 400, height: 300)
        let properties = WindowProperties(frame: layoutFrame, isResizable: true)
        let base = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .special(.noSelection), keybind: []),
            window: nil,
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: .zero,
            windowProperties: properties,
            record: nil
        )

        let next = WindowResizeExecution.transition(
            from: base,
            toAction: BoundWindowAction(action: .standard(.maximize), keybind: [])
        )

        XCTAssertEqual(next.action.direction, .maximize)
        XCTAssertEqual(next.windowProperties?.frame, layoutFrame)
        XCTAssertEqual(next.bounds, base.bounds)
        XCTAssertEqual(next.padding, base.padding)
        XCTAssertEqual(next.initialMousePosition, base.initialMousePosition)
    }

    func testTransitionToNewScreenRefreshesBoundsAndPadding() {
        let base = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .standard(.maximize), keybind: []),
            window: nil,
            screen: screen,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            padding: .zero,
            windowProperties: WindowProperties(frame: .zero, isResizable: true),
            record: nil
        )

        let next = WindowResizeExecution.transition(
            from: base,
            toAction: base.action,
            screen: screen
        )

        XCTAssertEqual(next.bounds, screen.cgSafeScreenFrame)
        // padding is recomputed for the target screen (may be non-zero from Defaults)
        XCTAssertEqual(next.screen, screen)
        XCTAssertEqual(next.windowProperties?.frame, .zero)
    }

    func testPrepareImmediateInheritsWindowPropertiesOverride() async {
        let override = WindowProperties(
            frame: CGRect(x: 50, y: 60, width: 200, height: 150),
            isResizable: true
        )
        let session = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .standard(.maximize), keybind: []),
            window: nil,
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: .zero,
            windowProperties: override,
            record: nil
        )

        let immediate = await WindowResizeExecution.prepareImmediate(from: session)

        XCTAssertEqual(immediate.windowProperties?.frame, override.frame)
        XCTAssertEqual(immediate.action.direction, .maximize)
    }
}
