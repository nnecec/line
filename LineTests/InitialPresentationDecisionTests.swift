//
//  InitialPresentationDecisionTests.swift
//  LineTests
//
//  Created by Codex on 2026-07-08.
//

import ApplicationServices
import Defaults
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

final class StaleInstanceTerminationDecisionTests: XCTestCase {
    private let launchDate = Date(timeIntervalSince1970: 100)

    func testMatchingIdentityAllowsTermination() {
        let identity = RunningApplicationIdentity(
            processIdentifier: 101,
            bundleIdentifier: "com.nnecec.Line",
            launchDate: launchDate
        )

        XCTAssertEqual(
            StaleInstanceTerminationDecision.resolve(
                recordedIdentity: identity,
                observedIdentity: identity,
                currentPID: 100,
                currentBundleIdentifier: "com.nnecec.Line"
            ),
            .terminate
        )
    }

    func testPIDReuseWithDifferentLaunchDateDoesNotTerminate() {
        let recorded = RunningApplicationIdentity(
            processIdentifier: 101,
            bundleIdentifier: "com.nnecec.Line",
            launchDate: launchDate
        )
        let observed = RunningApplicationIdentity(
            processIdentifier: 101,
            bundleIdentifier: "com.nnecec.Line",
            launchDate: launchDate.addingTimeInterval(1)
        )

        XCTAssertEqual(
            StaleInstanceTerminationDecision.resolve(
                recordedIdentity: recorded,
                observedIdentity: observed,
                currentPID: 100,
                currentBundleIdentifier: "com.nnecec.Line"
            ),
            .doNotKill
        )
    }

    func testBundleMismatchDoesNotTerminate() {
        let identity = RunningApplicationIdentity(
            processIdentifier: 101,
            bundleIdentifier: "com.example.Other",
            launchDate: launchDate
        )

        XCTAssertEqual(
            StaleInstanceTerminationDecision.resolve(
                recordedIdentity: identity,
                observedIdentity: identity,
                currentPID: 100,
                currentBundleIdentifier: "com.nnecec.Line"
            ),
            .doNotKill
        )
    }

    func testMissingIdentityDoesNotTerminate() {
        let identity = RunningApplicationIdentity(
            processIdentifier: 101,
            bundleIdentifier: nil,
            launchDate: nil
        )

        XCTAssertEqual(
            StaleInstanceTerminationDecision.resolve(
                recordedIdentity: identity,
                observedIdentity: identity,
                currentPID: 100,
                currentBundleIdentifier: "com.nnecec.Line"
            ),
            .doNotKill
        )
    }

    func testPIDThatHasExitedWaitsWithoutTermination() {
        let identity = RunningApplicationIdentity(
            processIdentifier: 101,
            bundleIdentifier: "com.nnecec.Line",
            launchDate: launchDate
        )

        XCTAssertEqual(
            StaleInstanceTerminationDecision.resolve(
                recordedIdentity: identity,
                observedIdentity: nil,
                currentPID: 100,
                currentBundleIdentifier: "com.nnecec.Line"
            ),
            .wait
        )
    }
}

final class AXValueBoundaryAdapterTests: XCTestCase {
    func testRecognizesOpaqueCoreFoundationTypesWithoutIPC() throws {
        let element = AXUIElementCreateSystemWide()
        var point = CGPoint.zero
        let value = try XCTUnwrap(AXValueCreate(.cgPoint, &point))
        let unrelated = NSObject()

        XCTAssertTrue(AXValueBoundaryPolicy.isAXUIElement(element))
        XCTAssertTrue(AXValueBoundaryPolicy.isAXValue(value))
        XCTAssertFalse(AXValueBoundaryPolicy.isAXUIElement(unrelated))
        XCTAssertFalse(AXValueBoundaryPolicy.isAXValue(unrelated))
    }

    func testAdapterReturnsAnUnrelatedObjectWithoutCastingIt() throws {
        let object = NSObject()

        let unpacked = try AXValueBoundaryAdapter.unpack(object)

        XCTAssertTrue(unpacked as AnyObject === object)
    }

    func testAdapterConvertsAXValueAndPropagatesGetValueFailure() throws {
        var point = CGPoint.zero
        let value = try XCTUnwrap(AXValueCreate(.cgPoint, &point))

        do {
            _ = try AXValueBoundaryAdapter.unpack(value, getValue: { _, _, _ in false })
            XCTFail("Expected AXValueGetValue failure to throw")
        } catch {
            XCTAssertEqual(error as? AXError, .illegalArgument)
        }
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

@MainActor
final class ApplicationPresentationReachabilityTests: XCTestCase {
    private var previousHideMenuBarIcon = false
    private var previousShowDockIcon = false

    override func setUp() {
        super.setUp()
        previousHideMenuBarIcon = Defaults[.hideMenuBarIcon]
        previousShowDockIcon = Defaults[.showDockIcon]
    }

    override func tearDown() {
        Defaults[.hideMenuBarIcon] = previousHideMenuBarIcon
        Defaults[.showDockIcon] = previousShowDockIcon
        super.tearDown()
    }

    func testEnsureReachablePresentationRestoresMenuBarIconWhenDockIsHidden() {
        Defaults[.showDockIcon] = false
        Defaults[.hideMenuBarIcon] = true

        ApplicationPresentationController.shared.ensureReachablePresentation()

        XCTAssertFalse(Defaults[.hideMenuBarIcon])
        XCTAssertFalse(Defaults[.showDockIcon])
    }

    func testEnsureReachablePresentationKeepsHiddenMenuBarIconWhenDockIsVisible() {
        Defaults[.showDockIcon] = true
        Defaults[.hideMenuBarIcon] = true

        ApplicationPresentationController.shared.ensureReachablePresentation()

        XCTAssertTrue(Defaults[.hideMenuBarIcon])
        XCTAssertTrue(Defaults[.showDockIcon])
    }
}
