//
//  MiddleClickTrigger.swift
//  Line
//
//  Created by nnecec on 2025-08-29.
//

import AppKit
import Defaults

/// Reads middle-click events using a PassiveEventMonitor, and triggers Line open/close callbacks, when appropriate.
final class MiddleClickTrigger {
    // Callbacks
    private let openCallback: (BoundWindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLineOpen: () -> Bool

    private var monitor: PassiveEventMonitor?

    // Defaults
    private var middleClickTriggersLine: Bool { Defaults[.middleClickTriggersLine] }
    private var useTriggerDelay: Bool { Defaults[.enableTriggerDelayOnMiddleClick] && Defaults[.triggerDelay] > 0.1 }
    private var doubleClickToTrigger: Bool { Defaults[.doubleClickToTrigger] }

    private lazy var triggerDelayTimer = TriggerDelayTimer(openCallback: openCallback)
    private lazy var doubleClickTimer = DoubleClickTimer { [weak self] action in
        guard let self else { return }

        if useTriggerDelay {
            triggerDelayTimer.handleTrigger(startingAction: BoundWindowAction(action: .special(.noSelection), keybind: []))
        } else {
            openCallback(action)
        }
    }

    /// Initializes a ``MiddleClickObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the middle mouse button is pressed, and Line should be activated.
    ///   - closeCallback: what to do when the middle mouse button is released, and Line should be closed.
    init(
        openCallback: @escaping (BoundWindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLineOpen: @escaping () -> Bool
    ) {
        // We will never start off with an action from this trigger, so pass in nil
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLineOpen = checkIfLineOpen
    }

    func start() {
        stop()

        let monitor = PassiveEventMonitor(
            "middle_click_trigger",
            events: [.otherMouseDown, .otherMouseUp],
            callback: handleOtherMouseKeypress
        )
        monitor.start()

        self.monitor = monitor
    }

    func stop() {
        monitor?.stop()
        monitor = nil
    }

    // MARK: Private

    private func handleOtherMouseKeypress(_ event: CGEvent) {
        Task { @MainActor in
            guard middleClickTriggersLine else {
                return
            }

            if event.type == .otherMouseDown,
               event.getIntegerValueField(.mouseEventButtonNumber) == 2 {
                if doubleClickToTrigger {
                    doubleClickTimer.handleKeyDown(startingAction: BoundWindowAction(action: .special(.noSelection), keybind: []))
                } else if useTriggerDelay {
                    triggerDelayTimer.handleTrigger(startingAction: BoundWindowAction(action: .special(.noSelection), keybind: []))
                } else {
                    openCallback(BoundWindowAction(action: .special(.noSelection), keybind: []))
                }
            } else {
                if !checkIfLineOpen() {
                    doubleClickTimer.handleKeyUp()
                }

                triggerDelayTimer.cancel()
                closeCallback(false)
            }
        }
    }
}
