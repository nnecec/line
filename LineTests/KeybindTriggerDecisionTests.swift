//
//  KeybindTriggerDecisionTests.swift
//  LineTests
//

import CoreGraphics
@testable import Line
import XCTest

final class KeybindTriggerDecisionTests: XCTestCase {
    private let trigger: Set<CGKeyCode> = [.kVK_Function]
    private let action = BoundWindowAction(
        action: .standard(.maximize),
        keybind: [.kVK_ANSI_M]
    )

    private func input(
        type: CGEventType = .keyDown,
        isARepeat: Bool = false,
        isLineOpen: Bool = false,
        pressedKeys: Set<CGKeyCode> = [],
        flagKeys: Set<CGKeyCode>? = nil,
        matchedAction: BoundWindowAction? = nil,
        matchedBypassAction: BoundWindowAction? = nil
    ) -> KeybindTriggerDecision.Input {
        .init(
            type: type,
            isARepeat: isARepeat,
            isLineOpen: isLineOpen,
            pressedKeys: pressedKeys,
            flagKeys: flagKeys ?? trigger,
            triggerKey: trigger,
            matchedAction: matchedAction,
            matchedBypassAction: matchedBypassAction
        )
    }

    func testEscapeWhileOpenForceClosesAndConsumes() {
        let out = KeybindTriggerDecision.decide(
            input(isLineOpen: true, pressedKeys: [.kVK_Escape], flagKeys: [])
        )
        XCTAssertEqual(out.result, .consume)
        XCTAssertEqual(out.effects, [.close(force: true)])
    }

    func testKeyUpWhileOpenForwards() {
        let out = KeybindTriggerDecision.decide(
            input(type: .keyUp, isLineOpen: true, pressedKeys: [], flagKeys: trigger)
        )
        XCTAssertEqual(out.result, .forward)
        XCTAssertTrue(out.effects.isEmpty)
    }

    func testLosingTriggerWhileOpenClosesSoftly() {
        let out = KeybindTriggerDecision.decide(
            input(type: .flagsChanged, isLineOpen: true, pressedKeys: [], flagKeys: [])
        )
        XCTAssertEqual(out.result, .forward)
        XCTAssertEqual(out.effects, [.close(force: false)])
    }

    func testTriggerPlusActionOpens() {
        let out = KeybindTriggerDecision.decide(
            input(
                pressedKeys: [.kVK_ANSI_M],
                flagKeys: trigger,
                matchedAction: action
            )
        )
        XCTAssertEqual(out.result, .opening)
        XCTAssertEqual(
            out.effects,
            [.open(action: action, overrideExistingTriggerDelay: true)]
        )
    }

    func testTriggerOnlyOpensNoSelection() {
        let out = KeybindTriggerDecision.decide(
            input(pressedKeys: [], flagKeys: trigger)
        )
        XCTAssertEqual(out.result, .opening)
        guard case let .open(opened, overrideDelay)? = out.effects.first else {
            return XCTFail("expected open effect")
        }
        XCTAssertEqual(opened.action, .special(.noSelection))
        XCTAssertTrue(overrideDelay) // !isARepeat
    }

    func testTriggerOnlyRepeatDoesNotOverrideDelay() {
        let out = KeybindTriggerDecision.decide(
            input(isARepeat: true, pressedKeys: [], flagKeys: trigger)
        )
        guard case let .open(_, overrideDelay)? = out.effects.first else {
            return XCTFail("expected open")
        }
        XCTAssertFalse(overrideDelay)
    }

    func testBypassActionOpensWithoutTrigger() {
        let bypass = BoundWindowAction(action: .standard(.maximize), keybind: [.kVK_Control, .kVK_ANSI_M])
        let out = KeybindTriggerDecision.decide(
            input(
                pressedKeys: [.kVK_ANSI_M],
                flagKeys: [.kVK_Control],
                matchedBypassAction: bypass
            )
        )
        XCTAssertEqual(out.result, .opening)
        XCTAssertEqual(out.effects.first, .open(action: bypass, overrideExistingTriggerDelay: true))
    }

    func testNonMatchingKeysCloseAndForward() {
        let out = KeybindTriggerDecision.decide(
            input(pressedKeys: [.kVK_ANSI_A], flagKeys: [])
        )
        XCTAssertEqual(out.result, .forward)
        XCTAssertEqual(out.effects, [.close(force: false)])
    }

    func testEmptyKeysNotifyDoubleClickThenClose() {
        let out = KeybindTriggerDecision.decide(
            input(pressedKeys: [], flagKeys: [])
        )
        XCTAssertEqual(out.result, .forward)
        XCTAssertEqual(
            out.effects,
            [.notifyDoubleClickKeyUp, .close(force: false)]
        )
    }

    func testRepeatWithoutCanRepeatDoesNotOpenAgain() {
        // action.canRepeat is typically false for maximize — still returns opening with empty effects
        let out = KeybindTriggerDecision.decide(
            input(
                isARepeat: true,
                pressedKeys: [.kVK_ANSI_M],
                flagKeys: trigger,
                matchedAction: action
            )
        )
        XCTAssertEqual(out.result, .opening)
        // If canRepeat is false, no open effect
        if !action.action.canRepeat {
            XCTAssertTrue(out.effects.isEmpty)
        }
    }

    func testFinalizeOpeningBecomesConsumeWhenLineOpen() {
        XCTAssertEqual(
            KeybindTriggerDecision.finalizeResult(.opening, isLineOpenAfterEffects: true),
            .consume
        )
        XCTAssertEqual(
            KeybindTriggerDecision.finalizeResult(.opening, isLineOpenAfterEffects: false),
            .opening
        )
    }
}
