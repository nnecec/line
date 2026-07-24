//
//  StashAftermathDecisionTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class StashAftermathDecisionTests: XCTestCase {
    private func input(
        action: WindowAction,
        isManaged: Bool = false,
        preferredScreenDiffersFromCurrent: Bool = false,
        isWindowFullyOnScreen: Bool = false,
        lastActionForUndo: WindowAction? = nil
    ) -> StashAftermathDecision.Input {
        .init(
            action: action,
            isManaged: isManaged,
            preferredScreenDiffersFromCurrent: preferredScreenDiffersFromCurrent,
            isWindowFullyOnScreen: isWindowFullyOnScreen,
            lastActionForUndo: lastActionForUndo
        )
    }

    func testStashActionOnCurrentScreen() {
        let action = WindowAction.stash(name: "Stash", edge: .left)
        XCTAssertEqual(
            StashAftermathDecision.decide(input(action: action)),
            .stash
        )
    }

    func testStashActionRedirectsWhenPreferredScreenDiffers() {
        let action = WindowAction.stash(name: "Stash", edge: .right)
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(action: action, preferredScreenDiffersFromCurrent: true)
            ),
            .redirectStashToPreferredScreen
        )
    }

    func testInitialFrameUnstashesWithoutReset() {
        XCTAssertEqual(
            StashAftermathDecision.decide(input(action: .special(.initialFrame))),
            .unstash(resetFrame: false)
        )
    }

    func testUndoReprocessesLastAction() {
        let last = WindowAction.standard(.maximize)
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(action: .special(.undo), lastActionForUndo: last)
            ),
            .reprocess(last)
        )
    }

    func testUndoWithMissingLastActionIsIgnored() {
        XCTAssertEqual(
            StashAftermathDecision.decide(input(action: .special(.undo))),
            .ignore
        )
    }

    func testUndoOfUndoIsIgnored() {
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(action: .special(.undo), lastActionForUndo: .special(.undo))
            ),
            .ignore
        )
    }

    func testIncrementalSizeOnManagedWindowRefreshesAndMayMarkRevealed() {
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(
                    action: .incremental(.growRight),
                    isManaged: true,
                    isWindowFullyOnScreen: true
                )
            ),
            .refreshManagedFrames(markRevealedIfFullyOnScreen: true)
        )
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(
                    action: .incremental(.larger),
                    isManaged: true,
                    isWindowFullyOnScreen: false
                )
            ),
            .refreshManagedFrames(markRevealedIfFullyOnScreen: false)
        )
    }

    func testIncrementalSizeOnUnmanagedWindowIsIgnored() {
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(action: .incremental(.growTop), isManaged: false)
            ),
            .ignore
        )
    }

    func testIncrementalMoveIsIgnored() {
        XCTAssertEqual(
            StashAftermathDecision.decide(
                input(action: .incremental(.moveLeft), isManaged: true)
            ),
            .ignore
        )
    }

    func testOtherActionsUnmanage() {
        XCTAssertEqual(
            StashAftermathDecision.decide(input(action: .standard(.maximize), isManaged: true)),
            .unmanage
        )
        XCTAssertEqual(
            StashAftermathDecision.decide(input(action: .standard(.proportional(.leftHalf)))),
            .unmanage
        )
    }

    func testSizeAdjustingIncrementalClassification() {
        XCTAssertTrue(StashAftermathDecision.isSizeAdjustingIncremental(.growLeft))
        XCTAssertTrue(StashAftermathDecision.isSizeAdjustingIncremental(.scaleUp))
        XCTAssertFalse(StashAftermathDecision.isSizeAdjustingIncremental(.moveUp))
        XCTAssertFalse(StashAftermathDecision.isSizeAdjustingIncremental(.moveRight))
    }
}
