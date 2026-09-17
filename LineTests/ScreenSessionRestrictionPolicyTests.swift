//
//  ScreenSessionRestrictionPolicyTests.swift
//  LineTests
//

@testable import Line
import XCTest

final class ScreenSessionRestrictionPolicyTests: XCTestCase {
    func testLockRestrictsAndCancelsWithoutSchedulingResume() {
        var state = ScreenSessionRestrictionPolicy.State.unrestricted

        XCTAssertEqual(
            ScreenSessionRestrictionPolicy.reduce(state: &state, event: .locked),
            [.cancelPendingWindowActions]
        )
        XCTAssertTrue(state.isRestricted)
        XCTAssertEqual(state.resumeGeneration, 1)
    }

    func testUnlockRestrictsThenSchedulesResumeDelay() {
        var state = ScreenSessionRestrictionPolicy.State.unrestricted

        XCTAssertEqual(
            ScreenSessionRestrictionPolicy.reduce(state: &state, event: .unlocked),
            [.cancelPendingWindowActions, .beginResumeDelay]
        )
        XCTAssertTrue(state.isRestricted)
        XCTAssertEqual(state.resumeGeneration, 1)
    }

    func testWakeAndScreenWakeMatchUnlock() {
        for event: ScreenSessionRestrictionPolicy.Event in [.didWake, .screensDidWake] {
            var state = ScreenSessionRestrictionPolicy.State.unrestricted
            XCTAssertEqual(
                ScreenSessionRestrictionPolicy.reduce(state: &state, event: event),
                [.cancelPendingWindowActions, .beginResumeDelay]
            )
            XCTAssertTrue(state.isRestricted)
        }
    }

    func testSleepAndScreenSleepMatchLock() {
        for event: ScreenSessionRestrictionPolicy.Event in [.willSleep, .screensDidSleep] {
            var state = ScreenSessionRestrictionPolicy.State.unrestricted
            XCTAssertEqual(
                ScreenSessionRestrictionPolicy.reduce(state: &state, event: event),
                [.cancelPendingWindowActions]
            )
            XCTAssertTrue(state.isRestricted)
        }
    }

    func testMatchingResumeDelayLiftsRestriction() {
        var state = ScreenSessionRestrictionPolicy.State.unrestricted
        _ = ScreenSessionRestrictionPolicy.reduce(state: &state, event: .unlocked)

        XCTAssertEqual(
            ScreenSessionRestrictionPolicy.reduce(
                state: &state,
                event: .resumeDelayElapsed(generation: 1)
            ),
            []
        )
        XCTAssertFalse(state.isRestricted)
        XCTAssertEqual(state.resumeGeneration, 1)
    }

    func testStaleResumeDelayDoesNotLiftRestriction() {
        var state = ScreenSessionRestrictionPolicy.State.unrestricted
        _ = ScreenSessionRestrictionPolicy.reduce(state: &state, event: .unlocked)
        _ = ScreenSessionRestrictionPolicy.reduce(state: &state, event: .didWake)

        XCTAssertEqual(
            ScreenSessionRestrictionPolicy.reduce(
                state: &state,
                event: .resumeDelayElapsed(generation: 1)
            ),
            []
        )
        XCTAssertTrue(state.isRestricted)
        XCTAssertEqual(state.resumeGeneration, 2)
    }

    func testLockDuringCooldownInvalidatesResume() {
        var state = ScreenSessionRestrictionPolicy.State.unrestricted
        _ = ScreenSessionRestrictionPolicy.reduce(state: &state, event: .unlocked)
        _ = ScreenSessionRestrictionPolicy.reduce(state: &state, event: .locked)

        XCTAssertTrue(state.isRestricted)
        XCTAssertEqual(state.resumeGeneration, 2)
        XCTAssertEqual(
            ScreenSessionRestrictionPolicy.reduce(
                state: &state,
                event: .resumeDelayElapsed(generation: 1)
            ),
            []
        )
        XCTAssertTrue(state.isRestricted)
    }

    func testRepeatedLockStillCancelsPendingActions() {
        var state = ScreenSessionRestrictionPolicy.State.unrestricted
        _ = ScreenSessionRestrictionPolicy.reduce(state: &state, event: .locked)

        XCTAssertEqual(
            ScreenSessionRestrictionPolicy.reduce(state: &state, event: .locked),
            [.cancelPendingWindowActions]
        )
        XCTAssertTrue(state.isRestricted)
        XCTAssertEqual(state.resumeGeneration, 2)
    }

    func testPhantomFnFlagsOpenThenSoftCloseIsForcedWhenRestricted() {
        let trigger: Set<CGKeyCode> = [.kVK_Function]
        let open = KeybindTriggerDecision.decide(
            .init(
                type: .flagsChanged,
                isARepeat: false,
                isLineOpen: false,
                pressedKeys: [],
                flagKeys: trigger,
                triggerKey: trigger,
                matchedAction: nil,
                matchedBypassAction: nil
            )
        )
        XCTAssertEqual(open.result, .opening)
        guard case let .open(opened, overrideDelay)? = open.effects.first else {
            return XCTFail("expected open effect")
        }
        XCTAssertEqual(opened.action, .special(.noSelection))
        XCTAssertTrue(overrideDelay)

        let close = KeybindTriggerDecision.decide(
            .init(
                type: .flagsChanged,
                isARepeat: false,
                isLineOpen: true,
                pressedKeys: [],
                flagKeys: [],
                triggerKey: trigger,
                matchedAction: nil,
                matchedBypassAction: nil
            )
        )
        XCTAssertEqual(close.effects, [.close(force: false)])
        XCTAssertTrue(
            LineCoordinatorOpeningPolicy.shouldForceClose(
                requestedForceClose: false,
                isRestricted: true
            )
        )
        XCTAssertFalse(LineCoordinatorOpeningPolicy.shouldBeginOpening(isRestricted: true))
        XCTAssertFalse(WindowDragMonitoringPolicy.shouldProcessDragEvent(isRestricted: true))
    }

    func testRestrictionFlagPublishIsReadableOffMainActor() {
        let previous = ScreenSessionRestrictionFlag.isRestricted
        defer { ScreenSessionRestrictionFlag.publish(previous) }

        ScreenSessionRestrictionFlag.publish(true)
        XCTAssertTrue(ScreenSessionRestrictionFlag.isRestricted)
        ScreenSessionRestrictionFlag.publish(false)
        XCTAssertFalse(ScreenSessionRestrictionFlag.isRestricted)
    }
}
