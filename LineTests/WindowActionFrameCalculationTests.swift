//
//  WindowActionFrameCalculationTests.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//

@testable import Line
import XCTest

@MainActor
final class WindowActionIntegrationTests: XCTestCase {
    private let testBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let testScreen = NSScreen.main ?? NSScreen.screens[0]
    private let padding = PaddingConfiguration.zero

    func testStandardProportionalActionsCalculateExpectedFrames() {
        let testCases: [(WindowAction, CGRect)] = [
            (.standard(.proportional(.leftHalf)), CGRect(x: 0, y: 0, width: 960, height: 1080)),
            (.standard(.proportional(.rightHalf)), CGRect(x: 960, y: 0, width: 960, height: 1080)),
            (.standard(.proportional(.topHalf)), CGRect(x: 0, y: 0, width: 1920, height: 540)),
            (.standard(.proportional(.bottomHalf)), CGRect(x: 0, y: 540, width: 1920, height: 540)),
            (.standard(.proportional(.topLeftQuarter)), CGRect(x: 0, y: 0, width: 960, height: 540)),
            (.standard(.proportional(.topRightQuarter)), CGRect(x: 960, y: 0, width: 960, height: 540))
        ]

        for (action, expectedFrame) in testCases {
            let frame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(frame, expectedFrame, accuracy: 0.01)
        }
    }

    func testMaximizeActionsCalculateExpectedFrames() {
        let testCases: [(WindowAction, CGRect)] = [
            (.standard(.maximize), testBounds),
            (.standard(.fullscreen), testBounds),
            (.standard(.almostMaximize), testBounds.insetBy(dx: 20, dy: 20))
        ]

        for (action, expectedFrame) in testCases {
            let frame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(frame, expectedFrame, accuracy: 0.01)
        }
    }

    func testNonFrameActionsReturnZeroSizedFrames() {
        let testCases: [WindowAction] = [
            .focus(.focusLeft),
            .focus(.focusRight),
            .focus(.focusUp),
            .focus(.focusDown),
            .screen(.next),
            .screen(.previous),
            .screen(.left),
            .screen(.right),
            .special(.noAction),
            .special(.noSelection)
        ]

        for action in testCases {
            let frame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(frame.size, .zero)
            XCTAssertTrue(frame.origin.x.isFinite)
            XCTAssertTrue(frame.origin.y.isFinite)
        }
    }

    func testRoundTripCodablePreservesModernCalculation() throws {
        let testActions: [WindowAction] = [
            .standard(.proportional(.leftHalf)),
            .standard(.proportional(.topRightQuarter)),
            .standard(.maximize),
            .standard(.proportional(.horizontalCenterThird))
        ]

        for action in testActions {
            let originalFrame = WindowFrameResolver.calculateFrame(
                for: action,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            let encoded = try JSONEncoder().encode(action)
            let roundTrippedAction = try JSONDecoder().decode(WindowAction.self, from: encoded)
            let roundTripFrame = WindowFrameResolver.calculateFrame(
                for: roundTrippedAction,
                bounds: testBounds,
                screen: testScreen,
                padding: padding
            )

            XCTAssertEqual(originalFrame, roundTripFrame, accuracy: 0.01)
        }
    }

    func testFillAvailableSpaceUsesClosestNonOverlappingObstacles() {
        let currentFrame = CGRect(x: 300, y: 300, width: 300, height: 200)
        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.fillAvailableSpace),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            visibleWindowFrames: [
                CGRect(x: 0, y: 0, width: 250, height: 1080),
                CGRect(x: 900, y: 0, width: 200, height: 1080),
                CGRect(x: 250, y: 0, width: 650, height: 250),
                CGRect(x: 250, y: 600, width: 650, height: 200)
            ]
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, CGRect(x: 250, y: 250, width: 650, height: 350), accuracy: 0.01)
    }

    func testFillAvailableSpaceIgnoresOverlappingWindows() {
        let currentFrame = CGRect(x: 300, y: 300, width: 300, height: 200)
        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.fillAvailableSpace),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            visibleWindowFrames: [
                CGRect(x: 280, y: 280, width: 100, height: 100)
            ]
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, testBounds, accuracy: 0.01)
    }

    func testStashActionCalculatesRevealedFrameAtCenterWithCurrentSize() {
        let currentFrame = CGRect(x: 100, y: 120, width: 320, height: 240)
        let request = WindowResizeRequest(
            window: nil,
            action: .stash(name: "Scratchpad", edge: .right),
            screen: testScreen,
            bounds: testBounds,
            padding: padding,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true)
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, CGRect(x: 800, y: 420, width: 320, height: 240), accuracy: 0.01)
    }

    func testProportionalLayoutCalculatesCorrectFrames() {
        let testCases: [(ProportionalLayout, CGRect)] = [
            (.leftHalf, CGRect(x: 0, y: 0, width: 960, height: 1080)),
            (.rightHalf, CGRect(x: 960, y: 0, width: 960, height: 1080)),
            (.topHalf, CGRect(x: 0, y: 0, width: 1920, height: 540)),
            (.bottomHalf, CGRect(x: 0, y: 540, width: 1920, height: 540)),
            (.topLeftQuarter, CGRect(x: 0, y: 0, width: 960, height: 540)),
            (.topRightQuarter, CGRect(x: 960, y: 0, width: 960, height: 540))
        ]

        for (layout, expectedFrame) in testCases {
            let calculatedFrame = layout.calculateFrame(in: testBounds)
            XCTAssertEqual(calculatedFrame, expectedFrame, accuracy: 0.01)
        }
    }
}
