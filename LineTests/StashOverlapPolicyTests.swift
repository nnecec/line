//
//  StashOverlapPolicyTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class StashOverlapPolicyTests: XCTestCase {
    private let tolerance: CGFloat = 100

    func testSameScreenSameEdgeKeepsSeparatedWindowsStashed() {
        let existing = CGRect(x: 0, y: 0, width: 300, height: 200)
        let incoming = CGRect(x: 0, y: 300, width: 300, height: 200)

        XCTAssertFalse(
            StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: incoming,
                incomingEdge: .left,
                existingFrame: existing,
                existingEdge: .left,
                isSameScreen: true,
                minimumVisibleSize: tolerance
            )
        )
    }

    func testSameScreenSameEdgeReplacesWindowWithoutEnoughVisibleSpace() {
        let existing = CGRect(x: 0, y: 0, width: 300, height: 300)
        let incoming = CGRect(x: 0, y: 50, width: 300, height: 300)

        XCTAssertTrue(
            StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: incoming,
                incomingEdge: .right,
                existingFrame: existing,
                existingEdge: .right,
                isSameScreen: true,
                minimumVisibleSize: tolerance
            )
        )
    }

    func testDifferentEdgesNeverReplaceEachOther() {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 300)

        XCTAssertFalse(
            StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: frame,
                incomingEdge: .left,
                existingFrame: frame,
                existingEdge: .right,
                isSameScreen: true,
                minimumVisibleSize: tolerance
            )
        )
    }

    func testDifferentScreensNeverReplaceEachOther() {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 300)

        XCTAssertFalse(
            StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: frame,
                incomingEdge: .left,
                existingFrame: frame,
                existingEdge: .left,
                isSameScreen: false,
                minimumVisibleSize: tolerance
            )
        )
    }

    func testBottomEdgeUsesHorizontalVisibleSpace() {
        let existing = CGRect(x: 0, y: 0, width: 300, height: 200)
        let incomingWithEnoughSpace = CGRect(x: 250, y: 0, width: 300, height: 200)
        let incomingWithoutEnoughSpace = CGRect(x: 50, y: 0, width: 300, height: 200)

        XCTAssertFalse(
            StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: incomingWithEnoughSpace,
                incomingEdge: .bottom,
                existingFrame: existing,
                existingEdge: .bottom,
                isSameScreen: true,
                minimumVisibleSize: tolerance
            )
        )
        XCTAssertTrue(
            StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: incomingWithoutEnoughSpace,
                incomingEdge: .bottom,
                existingFrame: existing,
                existingEdge: .bottom,
                isSameScreen: true,
                minimumVisibleSize: tolerance
            )
        )
    }
}

// MARK: - StashZOrderPolicy

final class StashZOrderPolicyTests: XCTestCase {
    func testStashedInZOrderPreservesFrontToBackAndDropsMissing() {
        let stashed: [CGWindowID: String] = [
            10: "back",
            30: "front",
            20: "mid"
        ]
        // Simulated CG list order: front → back (30, 99, 20, 10)
        let zOrdered: [CGWindowID] = [30, 99, 20, 10]

        let ordered = StashZOrderPolicy.stashedInZOrder(
            zOrderedWindowIDs: zOrdered,
            stashed: stashed
        )

        XCTAssertEqual(ordered, ["front", "mid", "back"])
    }

    func testStashedInZOrderEmptyWhenNoOverlap() {
        let ordered = StashZOrderPolicy.stashedInZOrder(
            zOrderedWindowIDs: [1, 2, 3] as [CGWindowID],
            stashed: [CGWindowID: String]()
        )
        XCTAssertTrue(ordered.isEmpty)
    }

    func testIsMouseNearAnyStashHitsStashedFrameWithTolerance() {
        let stashed = CGRect(x: 0, y: 0, width: 20, height: 200)
        // 10pt outside the stashed rect horizontally → inside default 15pt tolerance
        let location = CGPoint(x: 25, y: 100)

        XCTAssertTrue(
            StashZOrderPolicy.isMouseNearAnyStash(
                location: location,
                stashedFrames: [stashed],
                revealedFrames: []
            )
        )
    }

    func testIsMouseNearAnyStashHitsRevealedFrameWithTolerance() {
        let revealed = CGRect(x: 100, y: 100, width: 400, height: 300)
        let location = CGPoint(x: 90, y: 250) // 10pt left of revealed

        XCTAssertTrue(
            StashZOrderPolicy.isMouseNearAnyStash(
                location: location,
                stashedFrames: [],
                revealedFrames: [revealed]
            )
        )
    }

    func testIsMouseNearAnyStashReturnsFalseWhenFar() {
        let stashed = CGRect(x: 0, y: 0, width: 20, height: 200)
        let revealed = CGRect(x: 0, y: 0, width: 400, height: 300)
        let location = CGPoint(x: 800, y: 600)

        XCTAssertFalse(
            StashZOrderPolicy.isMouseNearAnyStash(
                location: location,
                stashedFrames: [stashed],
                revealedFrames: [revealed]
            )
        )
    }
}
