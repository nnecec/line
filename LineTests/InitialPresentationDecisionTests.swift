//
//  InitialPresentationDecisionTests.swift
//  LineTests
//
//  Created by Codex on 2026-07-08.
//

@testable import Line
import XCTest

final class InitialPresentationDecisionTests: XCTestCase {
    func testResolveShowsPermissionsWhenAccessibilityIsMissing() {
        XCTAssertEqual(
            InitialPresentationDecision.resolve(
                launchedAsLoginItem: false,
                isAccessibilityGranted: false
            ),
            .showPermissions
        )

        XCTAssertEqual(
            InitialPresentationDecision.resolve(
                launchedAsLoginItem: true,
                isAccessibilityGranted: false
            ),
            .showPermissions
        )
    }

    func testResolveAppliesBackgroundPresentationWhenAccessibilityIsGranted() {
        XCTAssertEqual(
            InitialPresentationDecision.resolve(
                launchedAsLoginItem: false,
                isAccessibilityGranted: true
            ),
            .applyBackgroundPresentation
        )

        XCTAssertEqual(
            InitialPresentationDecision.resolve(
                launchedAsLoginItem: true,
                isAccessibilityGranted: true
            ),
            .applyBackgroundPresentation
        )
    }
}

final class TerminateNotificationAcceptancePolicyTests: XCTestCase {
    func testMissingPIDIsRejected() {
        XCTAssertFalse(
            TerminateNotificationAcceptancePolicy.shouldAcceptTerminateNotification(
                senderPID: nil,
                currentPID: 100,
                senderBundleIdentifier: "com.nnecec.Line",
                currentBundleIdentifier: "com.nnecec.Line"
            )
        )
    }

    func testOwnPIDIsRejected() {
        XCTAssertFalse(
            TerminateNotificationAcceptancePolicy.shouldAcceptTerminateNotification(
                senderPID: 100,
                currentPID: 100,
                senderBundleIdentifier: "com.nnecec.Line",
                currentBundleIdentifier: "com.nnecec.Line"
            )
        )
    }

    func testWrongBundleIdentifierIsRejected() {
        XCTAssertFalse(
            TerminateNotificationAcceptancePolicy.shouldAcceptTerminateNotification(
                senderPID: 101,
                currentPID: 100,
                senderBundleIdentifier: "com.example.Other",
                currentBundleIdentifier: "com.nnecec.Line"
            )
        )
    }

    func testMatchingBundleIdentifierAndDifferentPIDIsAccepted() {
        XCTAssertTrue(
            TerminateNotificationAcceptancePolicy.shouldAcceptTerminateNotification(
                senderPID: 101,
                currentPID: 100,
                senderBundleIdentifier: "com.nnecec.Line",
                currentBundleIdentifier: "com.nnecec.Line"
            )
        )
    }

    func testNilCurrentBundleIdentifierIsRejected() {
        XCTAssertFalse(
            TerminateNotificationAcceptancePolicy.shouldAcceptTerminateNotification(
                senderPID: 101,
                currentPID: 100,
                senderBundleIdentifier: "com.nnecec.Line",
                currentBundleIdentifier: nil
            )
        )
    }
}

final class AppLaunchCoordinationPolicyTests: XCTestCase {
    func testDuplicateInstanceCoordinationRunsOutsideTests() {
        XCTAssertTrue(
            AppLaunchCoordinationPolicy.shouldCoordinateDuplicateInstances(isRunningTests: false)
        )
    }

    func testDuplicateInstanceCoordinationIsSkippedForTestHosts() {
        XCTAssertFalse(
            AppLaunchCoordinationPolicy.shouldCoordinateDuplicateInstances(isRunningTests: true)
        )
    }
}
