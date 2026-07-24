//
//  KeybindBindingPolicy.swift
//  Line
//
//  Shared effective-keybind and conflict rules for settings list + recorder.
//

import CoreGraphics
import Foundation

enum KeybindBindingPolicy {
    /// Keys that actually fire an action: either the action's full bypass chord,
    /// or trigger ∪ action keybind.
    static func effectiveKeybind(
        for action: BoundWindowAction,
        triggerKey: Set<CGKeyCode>
    ) -> Set<CGKeyCode> {
        action.bypassTriggerKey ? action.keybind : triggerKey.union(action.keybind)
    }

    static func effectiveSelection(
        selection: Set<CGKeyCode>,
        bypassTriggerKey: Bool,
        triggerKey: Set<CGKeyCode>
    ) -> Set<CGKeyCode> {
        bypassTriggerKey ? selection : triggerKey.union(selection)
    }

    /// IDs of actions that share an effective keybind with at least one other action.
    static func conflictingIDs(
        in actions: [BoundWindowAction],
        triggerKey: Set<CGKeyCode>
    ) -> Set<BoundWindowAction.ID> {
        var idsByKeybind = [Set<CGKeyCode>: [BoundWindowAction.ID]]()

        for action in actions {
            guard !action.keybind.isEmpty else { continue }
            let effective = effectiveKeybind(for: action, triggerKey: triggerKey)
            idsByKeybind[effective, default: []].append(action.id)
        }

        return idsByKeybind.values.reduce(into: Set<BoundWindowAction.ID>()) { conflicts, ids in
            guard ids.count > 1 else { return }
            conflicts.formUnion(ids)
        }
    }

    enum RecordingValidation: Equatable {
        case unchanged
        case missingModifierInBypass
        case conflict(displayName: String)
        case valid
    }

    /// Validate a newly recorded keybind against existing bindings.
    static func validateRecording(
        selection: Set<CGKeyCode>,
        previousSelection: Set<CGKeyCode>,
        bypassTriggerKey: Bool,
        triggerKey: Set<CGKeyCode>,
        existing: [BoundWindowAction]
    ) -> RecordingValidation {
        if previousSelection == selection {
            return .unchanged
        }

        if bypassTriggerKey, selection.filter(\.isModifier).isEmpty {
            return .missingModifierInBypass
        }

        let effectiveSelection = effectiveSelection(
            selection: selection,
            bypassTriggerKey: bypassTriggerKey,
            triggerKey: triggerKey
        )

        for keybind in existing {
            let effectiveExisting = effectiveKeybind(for: keybind, triggerKey: triggerKey)
            guard effectiveSelection == effectiveExisting else { continue }

            let displayName = keybind.displayName
            if !displayName.isEmpty {
                return .conflict(displayName: displayName)
            }
            return .conflict(displayName: keybind.direction.name.lowercased())
        }

        return .valid
    }
}
