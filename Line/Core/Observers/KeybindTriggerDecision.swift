//
//  KeybindTriggerDecision.swift
//  Line
//
//  Pure decision table for keybind trigger events.
//  KeybindTrigger gathers CGEvent state and executes the outcome.
//

import CoreGraphics
import Foundation

/// Pure decision for whether a key event should open/close Line and whether to consume it.
enum KeybindTriggerDecision {
    enum Result: Equatable {
        case consume
        case forward
        case opening
    }

    enum Effect: Equatable {
        case close(force: Bool)
        case open(action: BoundWindowAction, overrideExistingTriggerDelay: Bool)
        case notifyDoubleClickKeyUp
    }

    struct Input: Equatable {
        var type: CGEventType
        var isARepeat: Bool
        var isLineOpen: Bool
        /// Keys currently considered pressed (after applying this event for keyDown/keyUp).
        var pressedKeys: Set<CGKeyCode>
        /// Modifier flag key codes (already side-dependent or base-normalized by the caller).
        var flagKeys: Set<CGKeyCode>
        var triggerKey: Set<CGKeyCode>
        /// `actionsByKeybind[actionKeys]` where actionKeys = pressed − trigger, base-normalized.
        var matchedAction: BoundWindowAction?
        /// `bypassedActionsByKeybind[allPressedKeys base modifiers]`.
        var matchedBypassAction: BoundWindowAction?
    }

    struct Output: Equatable {
        var result: Result
        var effects: [Effect]
    }

    static func decide(_ input: Input) -> Output {
        let allPressedKeys: Set<CGKeyCode> = input.pressedKeys.union(input.flagKeys)
        let containsTrigger = allPressedKeys.isSuperset(of: input.triggerKey)

        if input.isLineOpen {
            if input.pressedKeys.contains(.kVK_Escape) {
                return Output(result: .consume, effects: [.close(force: true)])
            }

            if input.type == .keyUp {
                return Output(result: .forward, effects: [])
            }

            if input.type != .keyDown, !containsTrigger {
                return Output(result: .forward, effects: [.close(force: false)])
            }
        }

        if input.type != .keyUp {
            if containsTrigger {
                if let action = input.matchedAction {
                    var effects: [Effect] = []
                    if !input.isARepeat || action.action.canRepeat {
                        effects.append(.open(action: action, overrideExistingTriggerDelay: true))
                    }
                    // Caller maps opening vs consume using checkIfLineOpen after open side effects.
                    return Output(result: .opening, effects: effects)
                }

                if allPressedKeys == input.triggerKey {
                    let noSelection = BoundWindowAction(action: .special(.noSelection), keybind: [])
                    return Output(
                        result: .opening,
                        effects: [
                            .open(
                                action: noSelection,
                                overrideExistingTriggerDelay: !input.isARepeat
                            )
                        ]
                    )
                }
            } else if let bypassed = input.matchedBypassAction {
                var effects: [Effect] = []
                if !input.isARepeat || bypassed.action.canRepeat {
                    effects.append(.open(action: bypassed, overrideExistingTriggerDelay: true))
                }
                return Output(result: .opening, effects: effects)
            } else {
                var effects: [Effect] = []
                if allPressedKeys.isEmpty {
                    effects.append(.notifyDoubleClickKeyUp)
                }
                effects.append(.close(force: false))
                return Output(result: .forward, effects: effects)
            }
        }

        return Output(result: .forward, effects: [])
    }

    /// After open effects, map `.opening` to `.consume` when Line is already open.
    static func finalizeResult(
        _ result: Result,
        isLineOpenAfterEffects: Bool
    ) -> Result {
        if result == .opening, isLineOpenAfterEffects {
            return .consume
        }
        return result
    }
}
