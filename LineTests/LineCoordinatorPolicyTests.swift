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
    func testOpeningAdmissionQueuesGridReopenAfterPreviousOpeningWasCancelled() {
        XCTAssertEqual(
            LineCoordinatorOpeningPolicy.admission(
                isLineOpening: true,
                shouldCancelOpening: true,
                direction: .noSelection
            ),
            .queueReopen
        )
    }

    func testOpeningAdmissionIgnoresDuplicateGridOpenWhileCurrentOpeningRemainsValid() {
        XCTAssertEqual(
            LineCoordinatorOpeningPolicy.admission(
                isLineOpening: true,
                shouldCancelOpening: false,
                direction: .noSelection
            ),
            .ignore
        )
    }

    func testOpeningAdmissionUpdatesDirectionalActionWhileCurrentOpeningRemainsValid() {
        XCTAssertEqual(
            LineCoordinatorOpeningPolicy.admission(
                isLineOpening: true,
                shouldCancelOpening: false,
                direction: .leftHalf
            ),
            .updatePendingAction
        )
    }

    func testOpeningReplayRequiresLatestRequestGeneration() {
        XCTAssertTrue(
            LineCoordinatorOpeningPolicy.shouldReplayOpening(
                requestGeneration: 3,
                latestGeneration: 3
            )
        )
        XCTAssertFalse(
            LineCoordinatorOpeningPolicy.shouldReplayOpening(
                requestGeneration: 3,
                latestGeneration: 4
            )
        )
    }

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

    func testSessionChangeEffectsRestartsTimeoutOnlyWhenSessionActiveAndResultRequestsIt() {
        XCTAssertTrue(
            SessionChangeEffects.shouldRestartTimeout(
                isSessionActive: true,
                resultRequestsRestart: true
            )
        )
        XCTAssertFalse(
            SessionChangeEffects.shouldRestartTimeout(
                isSessionActive: false,
                resultRequestsRestart: true
            )
        )
        XCTAssertFalse(
            SessionChangeEffects.shouldRestartTimeout(
                isSessionActive: true,
                resultRequestsRestart: false
            )
        )
    }

    func testSessionChangeEffectsSuppressesHapticWhenGlobalSettingIsDisabled() {
        XCTAssertFalse(
            SessionChangeEffects.shouldPerformHaptic(
                resultRequestsHaptic: true,
                hapticFeedbackEnabled: false
            )
        )
        XCTAssertTrue(
            SessionChangeEffects.shouldPerformHaptic(
                resultRequestsHaptic: true,
                hapticFeedbackEnabled: true
            )
        )
    }

    func testClosePolicyReleasesCoordinatorStateBeforeWindowActionSessionApply() {
        let instructions = LineCoordinatorClosePolicy.windowActionSessionCloseInstructions

        XCTAssertTrue(instructions.shouldReleaseCoordinatorStateBeforeSessionApply)
    }
}
