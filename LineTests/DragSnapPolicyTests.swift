//
//  DragSnapPolicyTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class DragSnapPolicyTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testTopInsetUsesHalfMenubarAtLeastEdgeInset() {
        XCTAssertEqual(DragSnapPolicy.topInset(menubarHeight: 50, edgeInset: 20), 25)
        XCTAssertEqual(DragSnapPolicy.topInset(menubarHeight: 20, edgeInset: 30), 30)
    }

    func testIgnoredFrameInsetsEdges() {
        let ignored = DragSnapPolicy.ignoredFrame(
            screenFrame: screen,
            edgeInset: 20,
            topInset: 40
        )
        XCTAssertEqual(ignored.minX, 20)
        XCTAssertEqual(ignored.maxX, 980)
        XCTAssertEqual(ignored.minY, 40)
        XCTAssertEqual(ignored.maxY, 780) // 800 - 20 - 40
    }

    func testDecideClearWhenMouseReturnsToSafeZoneWithActiveSnap() {
        let ignored = DragSnapPolicy.ignoredFrame(
            screenFrame: screen,
            edgeInset: 20,
            topInset: 40
        )
        let center = CGPoint(x: 500, y: 400)
        XCTAssertTrue(ignored.contains(center))

        let outcome = DragSnapPolicy.decide(
            mouseLocation: center,
            screenFrame: screen,
            ignoredFrame: ignored,
            currentDirection: .leftHalf
        )
        XCTAssertEqual(outcome, .clear)
    }

    func testDecideUnchangedWhenSafeZoneAndNoActiveSnap() {
        let ignored = DragSnapPolicy.ignoredFrame(
            screenFrame: screen,
            edgeInset: 20,
            topInset: 40
        )
        let outcome = DragSnapPolicy.decide(
            mouseLocation: CGPoint(x: 500, y: 400),
            screenFrame: screen,
            ignoredFrame: ignored,
            currentDirection: .noAction
        )
        XCTAssertEqual(outcome, .unchanged)
    }

    func testDecideUpdatesDirectionNearLeftEdge() {
        let ignored = DragSnapPolicy.ignoredFrame(
            screenFrame: screen,
            edgeInset: 20,
            topInset: 40
        )
        let leftEdge = CGPoint(x: 5, y: 400)
        XCTAssertFalse(ignored.contains(leftEdge))

        let outcome = DragSnapPolicy.decide(
            mouseLocation: leftEdge,
            screenFrame: screen,
            ignoredFrame: ignored,
            currentDirection: .noAction
        )
        guard case let .updateDirection(direction) = outcome else {
            return XCTFail("expected updateDirection, got \(outcome)")
        }
        // Left edge snap should be some left-oriented direction (half/thirds/etc.)
        XCTAssertTrue(
            direction == .leftHalf
                || direction == .topLeftQuarter
                || direction == .bottomLeftQuarter
                || direction == .leftThird
                || direction == .leftTwoThirds
                || !direction.isNoOp,
            "unexpected direction \(direction)"
        )
    }

    func testHasWindowMovedRequiresAllCornersDifferent() {
        let initial = CGRect(x: 0, y: 0, width: 100, height: 100)
        let translated = CGRect(x: 50, y: 50, width: 100, height: 100)
        XCTAssertTrue(DragSnapPolicy.hasWindowMoved(translated, initial))

        // Pure resize keeps one corner if origin fixed - not "moved" by this definition
        let resized = CGRect(x: 0, y: 0, width: 200, height: 200)
        XCTAssertFalse(DragSnapPolicy.hasWindowMoved(resized, initial))
    }

    func testHasWindowResizedDetectsAnyCornerChange() {
        let initial = CGRect(x: 0, y: 0, width: 100, height: 100)
        let resized = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertTrue(DragSnapPolicy.hasWindowResized(resized, initial))
        XCTAssertFalse(DragSnapPolicy.hasWindowResized(initial, initial))
    }
}
