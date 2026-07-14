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
