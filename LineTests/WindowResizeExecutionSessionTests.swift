//
//  WindowResizeExecutionSessionTests.swift
//  LineTests
//

import AppKit
import Defaults
@testable import Line
import XCTest

@MainActor
final class WindowResizeExecutionSessionTests: XCTestCase {
    private var screen: NSScreen!
    private let testBounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

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

    func testRequestUsesDefaultScreenBoundsAndPadding() {
        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.proportional(.rightHalf)),
            screen: screen
        )

        XCTAssertEqual(request.bounds, screen.cgSafeScreenFrame)
        XCTAssertEqual(request.padding, PaddingConfiguration.getConfiguredPadding(for: screen))
        XCTAssertEqual(
            request.paddedBounds,
            request.padding.applyToBounds(request.bounds, screen: screen),
            accuracy: 0.01
        )
    }

    func testPrepareResolvedCapturesEquivalentExecutionInputs() {
        let action = BoundWindowAction(action: .standard(.proportional(.rightHalf)), keybind: [])
        let parent = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let padding = PaddingConfiguration(
            window: 12,
            externalBar: 3,
            top: 7,
            bottom: 11,
            right: 13,
            left: 17,
            configureScreenPadding: true
        )
        let mousePosition = CGPoint(x: 123, y: 456)

        let prepared = WindowResizeExecution.prepareResolved(
            action: action,
            parentAction: parent,
            screen: screen,
            bounds: testBounds,
            padding: padding,
            initialMousePosition: mousePosition,
            windowProperties: nil,
            record: nil
        )

        XCTAssertEqual(prepared.bounds, testBounds)
        XCTAssertEqual(prepared.padding, padding)
        XCTAssertEqual(prepared.paddedBounds, padding.applyToBounds(testBounds, screen: screen), accuracy: 0.01)
        XCTAssertEqual(prepared.action.action, action.action)
        XCTAssertEqual(prepared.parentAction?.action, parent.action)
        XCTAssertEqual(prepared.initialMousePosition, mousePosition)
        XCTAssertEqual(prepared.targetFrame.padded, prepared.targetFrame.raw, accuracy: 0.01)
    }

    func testTransitionChangesActionAndPreservesResolvedSnapshots() {
        let properties = WindowProperties(
            frame: CGRect(x: 100, y: 120, width: 320, height: 240),
            isResizable: true
        )
        let record = WindowRecord(initialFrame: properties.frame, lastAction: nil)
        let base = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .standard(.proportional(.leftHalf)), keybind: []),
            parentAction: BoundWindowAction(action: .standard(.maximize), keybind: []),
            screen: screen,
            bounds: testBounds,
            padding: .zero,
            initialMousePosition: CGPoint(x: 20, y: 30),
            windowProperties: properties,
            record: record
        )

        let transitioned = WindowResizeExecution.transition(
            from: base,
            toAction: BoundWindowAction(action: .standard(.proportional(.rightHalf)), keybind: [])
        )

        XCTAssertEqual(transitioned.action.action, WindowAction.standard(.proportional(.rightHalf)))
        XCTAssertNil(transitioned.parentAction)
        XCTAssertNotEqual(transitioned.targetFrame.raw, base.targetFrame.raw)
        XCTAssertEqual(transitioned.windowProperties, properties)
        XCTAssertEqual(transitioned.record, record)
        XCTAssertEqual(transitioned.initialMousePosition, base.initialMousePosition)
    }

    func testTransitionToScreenRefreshesBoundsAndConfiguredPadding() {
        let configuredPadding = PaddingConfiguration(
            window: 14,
            externalBar: 4,
            top: 8,
            bottom: 10,
            right: 12,
            left: 16,
            configureScreenPadding: true
        )
        let originalUseSystemWindowManager = Defaults[.useSystemWindowManagerWhenAvailable]
        let originalEnablePadding = Defaults[.enablePadding]
        let originalPadding = Defaults[.padding]
        let originalPaddingMinimumScreenSize = Defaults[.paddingMinimumScreenSize]
        defer {
            Defaults[.useSystemWindowManagerWhenAvailable] = originalUseSystemWindowManager
            Defaults[.enablePadding] = originalEnablePadding
            Defaults[.padding] = originalPadding
            Defaults[.paddingMinimumScreenSize] = originalPaddingMinimumScreenSize
        }

        Defaults[.useSystemWindowManagerWhenAvailable] = false
        Defaults[.enablePadding] = true
        Defaults[.padding] = configuredPadding
        Defaults[.paddingMinimumScreenSize] = 0

        let base = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .standard(.maximize), keybind: []),
            screen: screen,
            bounds: testBounds,
            padding: .zero,
            windowProperties: nil,
            record: nil
        )
        let transitioned = WindowResizeExecution.transition(
            from: base,
            toAction: base.action,
            screen: screen
        )

        XCTAssertEqual(transitioned.bounds, screen.cgSafeScreenFrame)
        XCTAssertEqual(transitioned.padding, configuredPadding)
        XCTAssertEqual(
            transitioned.paddedBounds,
            configuredPadding.applyToBounds(transitioned.bounds, screen: screen),
            accuracy: 0.01
        )
    }

    func testExplicitZeroPaddingRemainsUnpadded() {
        let originalUseSystemWindowManager = Defaults[.useSystemWindowManagerWhenAvailable]
        let originalEnablePadding = Defaults[.enablePadding]
        let originalPadding = Defaults[.padding]
        let originalPaddingMinimumScreenSize = Defaults[.paddingMinimumScreenSize]
        defer {
            Defaults[.useSystemWindowManagerWhenAvailable] = originalUseSystemWindowManager
            Defaults[.enablePadding] = originalEnablePadding
            Defaults[.padding] = originalPadding
            Defaults[.paddingMinimumScreenSize] = originalPaddingMinimumScreenSize
        }

        Defaults[.useSystemWindowManagerWhenAvailable] = false
        Defaults[.enablePadding] = true
        Defaults[.padding] = PaddingConfiguration(
            window: 20,
            externalBar: 5,
            top: 10,
            bottom: 10,
            right: 10,
            left: 10,
            configureScreenPadding: true
        )
        Defaults[.paddingMinimumScreenSize] = 0

        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.maximize),
            screen: screen,
            bounds: testBounds,
            padding: .zero
        )

        XCTAssertEqual(request.padding, .zero)
        XCTAssertEqual(request.paddedBounds, testBounds, accuracy: 0.01)
    }

    func testPrepareResolvedUsesInjectedRecordForInitialFrame() {
        let initialFrame = CGRect(x: 20, y: 30, width: 400, height: 300)
        let prepared = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .special(.initialFrame), keybind: []),
            screen: screen,
            bounds: testBounds,
            padding: .zero,
            windowProperties: WindowProperties(frame: .zero, isResizable: true),
            record: WindowRecord(initialFrame: initialFrame, lastAction: nil)
        )

        XCTAssertEqual(prepared.record?.initialFrame, initialFrame)
        XCTAssertEqual(prepared.targetFrame.raw, initialFrame, accuracy: 0.01)
        XCTAssertEqual(prepared.targetFrame.padded, initialFrame, accuracy: 0.01)
    }

    func testComputedFrameZero() {
        let zero = ComputedFrame.zero

        XCTAssertEqual(zero.raw, .zero)
        XCTAssertEqual(zero.padded, .zero)
    }
}
