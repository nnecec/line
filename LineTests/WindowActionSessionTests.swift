//
//  WindowActionSessionTests.swift
//  LineTests
//
//  Created by Codex on 2026-07-08.
//

import AppKit
import Defaults
@testable import Line
import XCTest

@MainActor
final class WindowActionSessionTests: XCTestCase {
    private var originalCycleModeRestartEnabled = false
    private var originalCycleBackwardsOnShiftPressed = false
    private var originalPreviewVisibility = false
    private var originalTriggerKey: Set<CGKeyCode> = []

    override func setUp() {
        super.setUp()
        originalCycleModeRestartEnabled = Defaults[.cycleModeRestartEnabled]
        originalCycleBackwardsOnShiftPressed = Defaults[.cycleBackwardsOnShiftPressed]
        originalPreviewVisibility = Defaults[.previewVisibility]
        originalTriggerKey = Defaults[.triggerKey]
    }

    override func tearDown() {
        Defaults[.cycleModeRestartEnabled] = originalCycleModeRestartEnabled
        Defaults[.cycleBackwardsOnShiftPressed] = originalCycleBackwardsOnShiftPressed
        Defaults[.previewVisibility] = originalPreviewVisibility
        Defaults[.triggerKey] = originalTriggerKey
        super.tearDown()
    }

    func testCycleStartsAtFirstItemWhenRestartIsEnabled() async {
        Defaults[.cycleModeRestartEnabled] = true

        let first = WindowAction.standard(.proportional(.leftHalf))
        let second = WindowAction.standard(.proportional(.rightHalf))
        let cycle = BoundWindowAction(action: .cycle([first, second]), keybind: [])
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            cycle,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertFalse(result.isIgnored)
        XCTAssertEqual(session.action.action, first)
        XCTAssertEqual(session.parentAction?.action, cycle.action)
        XCTAssertTrue(result.shouldUpdateIndicators)
    }

    func testCycleHoverDoesNotAdvanceWhenCurrentActionIsAlreadyInCycle() async {
        Defaults[.cycleModeRestartEnabled] = false

        let first = WindowAction.standard(.proportional(.leftHalf))
        let second = WindowAction.standard(.proportional(.rightHalf))
        let current = BoundWindowAction(action: first, keybind: [])
        let cycle = BoundWindowAction(action: .cycle([first, second]), keybind: [])
        let session = WindowActionSession.testSession(action: current)

        let result = await session.changeAction(
            cycle,
            input: .init(disableHapticFeedback: true, canAdvanceCycle: false)
        )

        XCTAssertFalse(result.isIgnored)
        XCTAssertTrue(result.shouldRestartTimeout)
        XCTAssertFalse(result.shouldUpdateIndicators)
        XCTAssertEqual(session.action.action, first)
    }

    func testEmptyCycleDoesNotCrashWhenRestartIsEnabled() async {
        Defaults[.cycleModeRestartEnabled] = true

        let cycle = BoundWindowAction(action: .cycle([]), keybind: [])
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            cycle,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertTrue(result.isIgnored)
        XCTAssertEqual(session.action.action, WindowAction.special(.noSelection))
        XCTAssertNil(session.parentAction)
        XCTAssertFalse(result.shouldUpdateIndicators)
    }

    func testEmptyCycleDoesNotCrashWhenRestartIsDisabled() async {
        Defaults[.cycleModeRestartEnabled] = false

        let cycle = BoundWindowAction(action: .cycle([]), keybind: [])
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            cycle,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertTrue(result.isIgnored)
        XCTAssertEqual(session.action.action, WindowAction.special(.noSelection))
        XCTAssertNil(session.parentAction)
        XCTAssertFalse(result.shouldUpdateIndicators)
    }

    func testEmptyCycleHoverDoesNotAdvance() async {
        let current = BoundWindowAction(action: .standard(.proportional(.leftHalf)), keybind: [])
        let cycle = BoundWindowAction(action: .cycle([]), keybind: [])
        let session = WindowActionSession.testSession(action: current)

        let result = await session.changeAction(
            cycle,
            input: .init(disableHapticFeedback: true, canAdvanceCycle: false)
        )

        XCTAssertTrue(result.isIgnored)
        XCTAssertEqual(session.action.action, current.action)
        XCTAssertNil(session.parentAction)
        XCTAssertFalse(result.shouldRestartTimeout)
        XCTAssertFalse(result.shouldUpdateIndicators)
    }

    func testInterceptedActionStopsRegularProgression() async {
        let requestedAction = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let session = WindowActionSession.testSession(
            interception: InterceptionStub(shouldIntercept: true)
        )

        let result = await session.changeAction(requestedAction, input: .init())

        XCTAssertTrue(result.wasIntercepted)
        XCTAssertFalse(result.shouldRestartTimeout)
        XCTAssertFalse(result.shouldUpdateIndicators)
        XCTAssertEqual(session.action.action, WindowAction.special(.noSelection))
    }

    func testPreviewDisabledResizeActionAppliesImmediately() async {
        Defaults[.previewVisibility] = false

        let requestedAction = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            requestedAction,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertFalse(result.isIgnored)
        XCTAssertTrue(result.shouldUpdateIndicators)
        XCTAssertTrue(result.shouldApplyImmediately)
        XCTAssertFalse(result.shouldApplyFocusAction)
    }

    func testFocusActionRequestsFocusApply() async {
        Defaults[.previewVisibility] = true

        let requestedAction = BoundWindowAction(action: .focus(.focusNextInStack), keybind: [])
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            requestedAction,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertFalse(result.isIgnored)
        XCTAssertTrue(result.shouldUpdateIndicators)
        XCTAssertFalse(result.shouldApplyImmediately)
        XCTAssertTrue(result.shouldApplyFocusAction)
    }

    func testDisableHapticFeedbackSuppressesChangeResultHapticInstruction() async {
        let requestedAction = BoundWindowAction(action: .standard(.maximize), keybind: [])
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            requestedAction,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertFalse(result.isIgnored)
        XCTAssertFalse(result.shouldPerformHapticFeedback)
    }

    func testScreenCycleProducesContinuationForParentCycleAction() async {
        Defaults[.cycleModeRestartEnabled] = true

        let screenAction = WindowAction.screen(.next)
        let cycle = BoundWindowAction(
            action: .cycle([screenAction, .standard(.maximize)]),
            keybind: []
        )
        let session = WindowActionSession.testSession()

        let result = await session.changeAction(
            cycle,
            input: .init(disableHapticFeedback: true)
        )

        XCTAssertFalse(result.isIgnored)
        XCTAssertEqual(result.continuation?.action.action, cycle.action)
    }
}

private extension WindowActionSession {
    static func testSession(
        action: BoundWindowAction = BoundWindowAction(action: .special(.noSelection), keybind: []),
        interception: (any WindowActionInterception)? = nil
    ) -> WindowActionSession {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let prepared = WindowResizeExecution.prepareResolved(
            action: action,
            window: nil,
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: .zero,
            windowProperties: nil,
            record: nil
        )
        return WindowActionSession(preparedResize: prepared, interception: interception)
    }
}

private extension BoundWindowAction {
    static let noSelection = BoundWindowAction(action: .special(.noSelection), keybind: [])
}

private struct InterceptionStub: WindowActionInterception {
    let shouldIntercept: Bool

    func intercept(_: BoundWindowAction, screen _: NSScreen) -> Bool {
        shouldIntercept
    }
}
