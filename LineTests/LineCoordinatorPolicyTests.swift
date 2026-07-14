//
//  LineCoordinatorPolicyTests.swift
//  LineTests
//
//  Created by Codex on 2026-07-10.
//

@testable import Line
import XCTest

@MainActor
final class LineCoordinatorPolicyTests: XCTestCase {
    func testOpeningPolicyReturnsFalseWhenOpeningWasCancelled() {
        XCTAssertFalse(
            LineCoordinatorOpeningPolicy.canActivateAfterOpening(
                shouldCancelOpening: true,
                isAccessibilityGranted: true
            )
        )
    }

    func testOpeningPolicyReturnsFalseWhenAccessibilityIsMissing() {
        XCTAssertFalse(
            LineCoordinatorOpeningPolicy.canActivateAfterOpening(
                shouldCancelOpening: false,
                isAccessibilityGranted: false
            )
        )
    }

    func testGridOpenPolicyDoesNotActivateOrStartTimeoutWhenOpenFailed() {
        let instructions = LineCoordinatorOpeningPolicy.instructionsAfterGridOpen(
            result: .failed,
            shouldAbortOpening: false
        )

        XCTAssertTrue(instructions.shouldCancelPartiallyOpenedLine)
        XCTAssertFalse(instructions.shouldActivateLine)
        XCTAssertFalse(instructions.shouldStartTimeout)
    }

    func testGridOpenPolicyActivatesAndStartsTimeoutWhenOpenSucceededAndOpeningWasNotAborted() {
        let instructions = LineCoordinatorOpeningPolicy.instructionsAfterGridOpen(
            result: .opened,
            shouldAbortOpening: false
        )

        XCTAssertFalse(instructions.shouldCancelPartiallyOpenedLine)
        XCTAssertTrue(instructions.shouldActivateLine)
        XCTAssertTrue(instructions.shouldStartTimeout)
    }

    func testGridOpenPolicyCancelsPartialOpenWhenOpenSucceededButOpeningWasAborted() {
        let instructions = LineCoordinatorOpeningPolicy.instructionsAfterGridOpen(
            result: .opened,
            shouldAbortOpening: true
        )

        XCTAssertTrue(instructions.shouldCancelPartiallyOpenedLine)
        XCTAssertFalse(instructions.shouldActivateLine)
        XCTAssertFalse(instructions.shouldStartTimeout)
    }

    func testChangePolicyRestartsTimeoutOnlyWhenWindowActionSessionIsActiveAndResultRequestsIt() {
        let timeoutResult = WindowActionSession.ChangeResult.timeoutOnly

        XCTAssertTrue(
            LineCoordinatorChangePolicy.instructions(
                isSessionActive: true,
                result: timeoutResult,
                hapticFeedbackEnabled: true
            ).shouldRestartTimeout
        )
        XCTAssertFalse(
            LineCoordinatorChangePolicy.instructions(
                isSessionActive: false,
                result: timeoutResult,
                hapticFeedbackEnabled: true
            ).shouldRestartTimeout
        )
        XCTAssertFalse(
            LineCoordinatorChangePolicy.instructions(
                isSessionActive: true,
                result: .ignored,
                hapticFeedbackEnabled: true
            ).shouldRestartTimeout
        )
    }

    func testChangePolicySuppressesHapticWhenGlobalHapticSettingIsDisabled() {
        let hapticResult = WindowActionSession.ChangeResult.hapticOnly(disabled: false)

        let instructions = LineCoordinatorChangePolicy.instructions(
            isSessionActive: true,
            result: hapticResult,
            hapticFeedbackEnabled: false
        )

        XCTAssertFalse(instructions.shouldPerformHapticFeedback)
    }

    func testChangePolicyReturnsContinuationActionWhenWindowActionSessionResultContainsOne() {
        let continuationAction = BoundWindowAction(
            action: .standard(.proportional(.leftHalf)),
            keybind: []
        )
        let result = changeResult(continuationAction: continuationAction)

        let instructions = LineCoordinatorChangePolicy.instructions(
            isSessionActive: true,
            result: result,
            hapticFeedbackEnabled: true
        )

        XCTAssertEqual(instructions.continuation, continuationAction)
    }

    func testClosePolicyReleasesCoordinatorStateBeforeWindowActionSessionApply() {
        let instructions = LineCoordinatorClosePolicy.windowActionSessionCloseInstructions

        XCTAssertTrue(instructions.shouldReleaseCoordinatorStateBeforeSessionApply)
    }

    private func changeResult(
        shouldRestartTimeout: Bool = true,
        shouldPerformHapticFeedback: Bool = false,
        continuationAction: BoundWindowAction? = nil
    ) -> WindowActionSession.ChangeResult {
        WindowActionSession.ChangeResult(
            isIgnored: false,
            wasIntercepted: false,
            shouldRestartTimeout: shouldRestartTimeout,
            shouldUpdateIndicators: false,
            shouldApplyImmediately: false,
            shouldApplyFocusAction: false,
            shouldPerformHapticFeedback: shouldPerformHapticFeedback,
            continuation: continuationAction.map { .init(action: $0) }
        )
    }
}
