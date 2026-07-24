//
//  KeybindTrigger.swift
//  Line
//
//  Created by nnecec on 2023-06-18.
//

import Cocoa
import Defaults
import Scribe

/// Monitors `keyDown`, `keyUp`, and `flagsChanged` events using an ActiveEventMonitor, invoking Line’s open and close callbacks as needed.
/// Additionally, this class manages keybind action retrieval and updates Line based on those actions.
@Loggable
final class KeybindTrigger {
    // Parameters
    private let windowActionCache: WindowActionCache
    private let openCallback: (BoundWindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLineOpen: () -> Bool

    // State-tracking
    private var pressedKeys: Set<CGKeyCode> = []
    private(set) var effectiveEventFlags: CGEventFlags = []
    private var eventMonitor: ActiveEventMonitor?

    private var systemKeybindCache: Set<Set<CGKeyCode>> = []
    private var keybindCacheUpdatedAt: ContinuousClock.Instant?
    private let keybindCacheLifetime: ContinuousClock.Duration = .seconds(30)

    /// Special events only contain the globe key, as it can also be used as an emoji key.
    private let specialEventKeys: [CGKeyCode] = [.kVK_Globe_Emoji]

    /// Will be set to `false` if the mouse has been moved by LineCoordinator.
    var canPassthroughNextSpecialEvent = true

    private var useTriggerDelay: Bool { Defaults[.triggerDelay] > 0.1 }
    private var doubleClickToTrigger: Bool { Defaults[.doubleClickToTrigger] }
    private var sideDependentTriggerKey: Bool { Defaults[.sideDependentTriggerKey] }
    private var triggerKey: Set<CGKeyCode> {
        sideDependentTriggerKey ? Defaults[.triggerKey] : Defaults[.triggerKey].baseModifiers
    }

    private lazy var triggerDelayTimer = TriggerDelayTimer(openCallback: openCallback)
    private lazy var doubleClickTimer = DoubleClickTimer { [weak self] action in
        guard let self else { return }

        if useTriggerDelay {
            startTriggerDelayTimer(
                startingAction: action,
                overrideExistingTriggerDelayTimerAction: true
            )
        } else {
            openCallback(action)
        }
    }

    /// Initializes a ``KeybindObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Line should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Line should be closed.
    init(
        windowActionCache: WindowActionCache,
        openCallback: @escaping (BoundWindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLineOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLineOpen = checkIfLineOpen
    }

    func start() async {
        guard await AccessibilityManager.shared.isGranted else {
            return
        }

        eventMonitor?.stop()

        let eventMonitor = ActiveEventMonitor(
            "keybind_trigger",
            events: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event -> ActiveEventMonitor.EventHandling in
            guard let self else { return .forward }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                .baseKey(flags: .init(rawValue: UInt(event.flags.rawValue)))

            var filteredFlags = event.flags
            if keyCode.isFnSpecialKey, !effectiveEventFlags.contains(.maskSecondaryFn) {
                filteredFlags.remove(.maskSecondaryFn)
            }

            let isLineOpen = checkIfLineOpen()
            effectiveEventFlags = filteredFlags

            if event.type == .keyUp {
                pressedKeys.remove(keyCode)
            } else if event.type == .keyDown {
                pressedKeys.insert(keyCode)
            }

            // Special events such as the emoji key
            if specialEventKeys.contains(keyCode) {
                let canPassthrough = canPassthroughNextSpecialEvent
                canPassthroughNextSpecialEvent = true // reset
                return canPassthrough ? .forward : .ignore
            }

            // If this is a valid event, don't passthrough
            let result = performKeybind(
                type: event.type,
                isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                flags: filteredFlags,
                isLineOpen: isLineOpen
            )

            if result == .consume {
                log.debug("Blocked event")
                return .ignore
            }

            // If this shouldn't consume the event, and Line isn't in the process of opening (possibly due to trigger delays),
            // check if it was a system keybind (ex. screenshot), and in that case, passthrough and force-close Line
            refreshSystemKeybindCacheIfNeeded()
            if result != .opening, event.type == .keyDown, systemKeybindCache.contains(pressedKeys) {
                closeLine(forceClose: true)
            }

            return .forward
        }

        eventMonitor.start()
        self.eventMonitor = eventMonitor
    }

    func stop() {
        eventMonitor?.stop()
        eventMonitor = nil

        // Reset states
        pressedKeys = []
        canPassthroughNextSpecialEvent = true
    }

    enum PerformKeybindResult {
        case consume
        case forward
        case opening
    }

    /// Determines if an event corresponds to a valid Line action.
    private func performKeybind(type: CGEventType, isARepeat: Bool, flags: CGEventFlags, isLineOpen: Bool) -> PerformKeybindResult {
        let flagKeys = sideDependentTriggerKey ? flags.keyCodes : flags.keyCodes.baseModifiers
        let allPressedKeys: Set<CGKeyCode> = pressedKeys.union(flagKeys)
        let actionKeys: Set<CGKeyCode> = Set(allPressedKeys.subtracting(triggerKey).map(\.baseModifier))
        let allPressedKeysBaseModifiers: Set<CGKeyCode> = Set(allPressedKeys.map(\.baseModifier))

        let decision = KeybindTriggerDecision.decide(
            .init(
                type: type,
                isARepeat: isARepeat,
                isLineOpen: isLineOpen,
                pressedKeys: pressedKeys,
                flagKeys: flagKeys,
                triggerKey: triggerKey,
                matchedAction: windowActionCache.actionsByKeybind[actionKeys],
                matchedBypassAction: windowActionCache.bypassedActionsByKeybind[allPressedKeysBaseModifiers]
            )
        )

        for effect in decision.effects {
            switch effect {
            case let .close(force):
                closeLine(forceClose: force)
            case let .open(action, overrideDelay):
                openLine(startingAction: action, overrideExistingTriggerDelayTimerAction: overrideDelay)
            case .notifyDoubleClickKeyUp:
                doubleClickTimer.handleKeyUp()
            }
        }

        let finalized = KeybindTriggerDecision.finalizeResult(
            decision.result,
            isLineOpenAfterEffects: checkIfLineOpen()
        )

        switch finalized {
        case .consume: return .consume
        case .forward: return .forward
        case .opening: return .opening
        }
    }

    private func openLine(startingAction: BoundWindowAction, overrideExistingTriggerDelayTimerAction: Bool) {
        if checkIfLineOpen() {
            openCallback(startingAction) // Only update Line to the latest BoundWindowAction
        } else {
            if doubleClickToTrigger {
                doubleClickTimer.handleKeyDown(startingAction: startingAction)
            } else if useTriggerDelay {
                startTriggerDelayTimer(
                    startingAction: startingAction,
                    overrideExistingTriggerDelayTimerAction: overrideExistingTriggerDelayTimerAction
                )
            } else {
                openCallback(startingAction)
            }
        }
    }

    private func closeLine(forceClose: Bool) {
        triggerDelayTimer.cancel()
        closeCallback(forceClose)
        pressedKeys = []
    }

    private func startTriggerDelayTimer(
        startingAction: BoundWindowAction,
        overrideExistingTriggerDelayTimerAction: Bool
    ) {
        // If a trigger delay timer is already active, only update its startingAction when
        // overrideExistingTriggerDelayTimerAction is true. If it's false, keep the existing
        // timer and its startingAction (do not create a new timer with nil).
        if triggerDelayTimer.isActive {
            if overrideExistingTriggerDelayTimerAction {
                triggerDelayTimer.updateStartingAction(with: startingAction)
            }
        } else {
            // No active timer, create one with the provided startingAction.
            triggerDelayTimer.handleTrigger(startingAction: startingAction)
        }
    }

    private func refreshSystemKeybindCacheIfNeeded() {
        let shouldRefresh: Bool = if let keybindCacheUpdatedAt {
            keybindCacheUpdatedAt.duration(to: .now) > keybindCacheLifetime
        } else {
            true
        }

        guard shouldRefresh else {
            return
        }

        systemKeybindCache = CGKeyCode.systemKeybinds
        keybindCacheUpdatedAt = .now
    }
}
