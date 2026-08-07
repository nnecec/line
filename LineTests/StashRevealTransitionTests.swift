//
//  StashRevealTransitionTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class StashRevealTransitionTests: XCTestCase {
    func testSwitchingRevealTargetKeepsOnlyOneWindowRevealed() throws {
        var transition = StashRevealTransition(throttleInterval: 0)
        let first = try XCTUnwrap(transition.beginReveal(windowID: 10, now: 1))
        XCTAssertTrue(transition.activate(first.token))
        XCTAssertTrue(transition.complete(first.token))
        let second = try XCTUnwrap(transition.beginReveal(windowID: 20, now: 2))

        XCTAssertEqual(second.previousRevealedWindowID, 10)
        XCTAssertTrue(transition.isWindowRevealed(10))
        XCTAssertFalse(transition.isWindowRevealed(20))
        let hide = try XCTUnwrap(
            transition.beginHide(windowID: 10, now: 3, allowUnrevealed: true, shouldThrottle: false)
        )
        XCTAssertTrue(transition.complete(hide))
        XCTAssertTrue(transition.activate(second.token))
        XCTAssertTrue(transition.complete(second.token))
        XCTAssertFalse(transition.isWindowRevealed(10))
        XCTAssertTrue(transition.isWindowRevealed(20))
    }

    func testPreviousHideFailureKeepsOldWindowRevealed() throws {
        var transition = StashRevealTransition(throttleInterval: 0)
        let firstReveal = try XCTUnwrap(transition.beginReveal(windowID: 10, now: 1))
        XCTAssertTrue(transition.activate(firstReveal.token))
        XCTAssertTrue(transition.complete(firstReveal.token))

        let secondReveal = try XCTUnwrap(transition.beginReveal(windowID: 20, now: 3))
        let hide = try XCTUnwrap(
            transition.beginHide(windowID: 10, now: 4, allowUnrevealed: true, shouldThrottle: false)
        )

        XCTAssertTrue(transition.fail(hide))
        XCTAssertTrue(transition.isWindowRevealed(10))
        XCTAssertFalse(transition.isWindowRevealed(20))
        XCTAssertTrue(transition.fail(secondReveal.token))
    }

    func testUnrelatedHideFailureDoesNotClearCurrentReveal() throws {
        var transition = StashRevealTransition(throttleInterval: 0)
        let reveal = try XCTUnwrap(transition.beginReveal(windowID: 10, now: 1))
        XCTAssertTrue(transition.activate(reveal.token))
        XCTAssertTrue(transition.complete(reveal.token))
        let hide = try XCTUnwrap(
            transition.beginHide(windowID: 20, now: 2, allowUnrevealed: true, shouldThrottle: false)
        )

        XCTAssertTrue(transition.fail(hide))
        XCTAssertTrue(transition.isWindowRevealed(10))
    }

    func testRapidRevealSwitchIgnoresSupersededTokens() throws {
        var transition = StashRevealTransition(throttleInterval: 0)
        let firstReveal = try XCTUnwrap(transition.beginReveal(windowID: 10, now: 1))
        XCTAssertTrue(transition.activate(firstReveal.token))
        XCTAssertTrue(transition.complete(firstReveal.token))

        let secondReveal = try XCTUnwrap(transition.beginReveal(windowID: 20, now: 2))
        let firstHide = try XCTUnwrap(
            transition.beginHide(windowID: 10, now: 3, allowUnrevealed: true, shouldThrottle: false)
        )
        let thirdReveal = try XCTUnwrap(transition.beginReveal(windowID: 30, now: 4))
        let secondHide = try XCTUnwrap(
            transition.beginHide(windowID: 10, now: 5, allowUnrevealed: true, shouldThrottle: false)
        )

        XCTAssertFalse(transition.complete(firstHide))
        XCTAssertTrue(transition.complete(secondHide))
        XCTAssertFalse(transition.activate(secondReveal.token))
        XCTAssertTrue(transition.activate(thirdReveal.token))
        XCTAssertTrue(transition.complete(thirdReveal.token))
        XCTAssertTrue(transition.isWindowRevealed(30))
    }

    func testRevealFailureReturnsWindowToHiddenState() throws {
        var transition = StashRevealTransition(throttleInterval: 0)
        let reveal = try XCTUnwrap(transition.beginReveal(windowID: 10, now: 1))

        XCTAssertTrue(transition.activate(reveal.token))
        XCTAssertTrue(transition.fail(reveal.token))
        XCTAssertFalse(transition.isWindowRevealed(10))
    }

    func testHideFailureRestoresRevealedState() throws {
        var transition = StashRevealTransition(throttleInterval: 0)
        let reveal = try XCTUnwrap(transition.beginReveal(windowID: 10, now: 1))
        XCTAssertTrue(transition.activate(reveal.token))
        XCTAssertTrue(transition.complete(reveal.token))
        let hide = try XCTUnwrap(
            transition.beginHide(windowID: 10, now: 2, allowUnrevealed: false, shouldThrottle: true)
        )

        XCTAssertTrue(transition.fail(hide))
        XCTAssertTrue(transition.isWindowRevealed(10))
    }

    func testThrottleDoesNotExtendWhenARequestIsRejected() {
        var transition = StashRevealTransition(throttleInterval: 0.1)

        let first = transition.beginReveal(windowID: 10, now: 1)
        XCTAssertNotNil(first)
        if let first {
            XCTAssertTrue(transition.fail(first.token))
        }
        XCTAssertNil(transition.beginReveal(windowID: 10, now: 1.05))
        XCTAssertNotNil(transition.beginReveal(windowID: 10, now: 1.11))
    }

    func testRemoveClearsRevealAndThrottleState() {
        var transition = StashRevealTransition(throttleInterval: 10)
        XCTAssertNotNil(transition.beginReveal(windowID: 10, now: 1))

        transition.remove(windowID: 10)

        XCTAssertFalse(transition.isWindowRevealed(10))
        XCTAssertNotNil(transition.beginReveal(windowID: 10, now: 2))
    }
}
