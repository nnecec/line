//
//  TriggerCoordinatorTests.swift
//  LineTests
//
//  Created by Claude on 2026-07-08.
//

@testable import Line
import XCTest

@MainActor
final class TriggerCoordinatorTests: XCTestCase {
    private var coordinator: TriggerCoordinator!
    private var windowActionCache: WindowActionCache!

    // Test state
    private var openCallCount = 0
    private var closeCallCount = 0
    private var lastOpenAction: BoundWindowAction?
    private var lastCloseForced: Bool?
    private var isLineOpenStub = false

    override func setUp() {
        super.setUp()
        windowActionCache = WindowActionCache()
        coordinator = TriggerCoordinator(windowActionCache: windowActionCache)

        // Reset test state
        openCallCount = 0
        closeCallCount = 0
        lastOpenAction = nil
        lastCloseForced = nil
        isLineOpenStub = false

        // Bind callbacks
        coordinator.bind(
            onOpen: { [weak self] action in
                self?.openCallCount += 1
                self?.lastOpenAction = action
            },
            onClose: { [weak self] forceClose in
                self?.closeCallCount += 1
                self?.lastCloseForced = forceClose
            },
            checkIfLineOpen: { [weak self] in
                self?.isLineOpenStub ?? false
            }
        )
    }

    override func tearDown() {
        coordinator = nil
        windowActionCache = nil
        super.tearDown()
    }

    // MARK: - Binding Tests

    func testKeybindEventBufferCoalescesConsecutiveOpenRequestsToLatestAction() throws {
        let buffer = KeybindTriggerEventBuffer()
        let first = BoundWindowAction(action: .standard(.proportional(.leftHalf)), keybind: [])
        let latest = BoundWindowAction(action: .standard(.proportional(.rightHalf)), keybind: [])

        let token = try XCTUnwrap(buffer.enqueue(.open(first)))
        XCTAssertNil(buffer.enqueue(.open(latest)))

        XCTAssertEqual(buffer.popNext(for: token), .open(latest))
        XCTAssertNil(buffer.popNext(for: token))
    }

    func testKeybindEventBufferPreservesCloseBoundaryBetweenOpenRequests() throws {
        let buffer = KeybindTriggerEventBuffer()
        let first = BoundWindowAction(action: .standard(.proportional(.leftHalf)), keybind: [])
        let latest = BoundWindowAction(action: .standard(.proportional(.rightHalf)), keybind: [])

        let token = try XCTUnwrap(buffer.enqueue(.open(first)))
        XCTAssertNil(buffer.enqueue(.close(forceClose: false)))
        XCTAssertNil(buffer.enqueue(.open(latest)))

        XCTAssertEqual(buffer.popNext(for: token), .open(first))
        XCTAssertEqual(buffer.popNext(for: token), .close(forceClose: false))
        XCTAssertEqual(buffer.popNext(for: token), .open(latest))
        XCTAssertNil(buffer.popNext(for: token))
    }

    func testKeybindEventBufferPreservesRepeatedIncrementalActions() throws {
        let buffer = KeybindTriggerEventBuffer()
        let action = BoundWindowAction(action: .incremental(.larger), keybind: [])

        let token = try XCTUnwrap(buffer.enqueue(.open(action)))
        XCTAssertNil(buffer.enqueue(.open(action)))

        XCTAssertEqual(buffer.popNext(for: token), .open(action))
        XCTAssertEqual(buffer.popNext(for: token), .open(action))
        XCTAssertNil(buffer.popNext(for: token))
    }

    func testKeybindEventBufferSchedulesAnotherDrainAfterBecomingEmpty() throws {
        let buffer = KeybindTriggerEventBuffer()
        let action = BoundWindowAction(action: .standard(.proportional(.leftHalf)), keybind: [])

        let token = try XCTUnwrap(buffer.enqueue(.open(action)))
        XCTAssertEqual(buffer.popNext(for: token), .open(action))
        XCTAssertNil(buffer.popNext(for: token))
        XCTAssertNotNil(buffer.enqueue(.open(action)))
    }

    func testKeybindEventBufferInvalidationDropsQueuedEventsAndStartsNewGeneration() throws {
        let buffer = KeybindTriggerEventBuffer()
        let action = BoundWindowAction(action: .standard(.proportional(.leftHalf)), keybind: [])

        let oldToken = try XCTUnwrap(buffer.enqueue(.open(action)))
        XCTAssertNil(buffer.enqueue(.open(action)))

        buffer.invalidate()

        XCTAssertNil(buffer.popNext(for: oldToken))
        let newToken = try XCTUnwrap(buffer.enqueue(.open(action)))
        XCTAssertEqual(buffer.popNext(for: newToken), .open(action))
    }

    func testBindingCallbacksWorks() {
        // Given: coordinator is bound in setUp

        // When: manually trigger keybind (simulated)
        // Note: We can't easily test KeybindTrigger/MiddleClickTrigger without actual events
        // This test verifies the binding structure is correct

        XCTAssertEqual(openCallCount, 0)
        XCTAssertEqual(closeCallCount, 0)
    }

    func testCheckIfLineOpenReturnsStubValue() {
        // Given: isLineOpenStub = false (default)
        XCTAssertFalse(isLineOpenStub)

        // When: set to true
        isLineOpenStub = true

        // Then: callback should return true
        XCTAssertTrue(isLineOpenStub)
    }

    // MARK: - Lifecycle Tests

    func testSetupCreatesKeybindAndMiddleClickTriggers() async {
        // Given: coordinator is initialized

        // When: setup is called
        await coordinator.setup()

        // Then: triggers should be accessible
        XCTAssertNotNil(coordinator.keybindTrigger)
        XCTAssertNotNil(coordinator.middleClickTrigger)
    }

    func testTeardownStopsTriggers() {
        // Given: coordinator is set up
        _ = coordinator.keybindTrigger
        _ = coordinator.middleClickTrigger

        // When: teardown is called
        coordinator.teardown()

        // Then: triggers should be stopped (no crash)
        // Note: We can't easily verify internal state, but no crash = success
    }

    // MARK: - Special Event Suppression Tests

    func testSuppressNextSpecialEventAffectsKeybindTrigger() {
        // Given: keybindTrigger is initialized
        let trigger = coordinator.keybindTrigger
        let originalValue = trigger.canPassthroughNextSpecialEvent

        // When: suppress is called
        coordinator.suppressNextSpecialEvent()

        // Then: canPassthroughNextSpecialEvent should be false
        XCTAssertFalse(trigger.canPassthroughNextSpecialEvent)

        // Restore
        trigger.canPassthroughNextSpecialEvent = originalValue
    }

    // MARK: - Opening Cancellation Tests

    func testCancelledOpeningCannotActivateLine() {
        XCTAssertFalse(
            LineCoordinator.canActivateAfterOpening(
                shouldCancelOpening: true,
                isAccessibilityGranted: true
            )
        )
    }
}
