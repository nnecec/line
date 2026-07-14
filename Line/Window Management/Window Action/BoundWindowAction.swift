//
//  BoundWindowAction.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Represents a WindowAction bound to a keybind.
//  Separates the orthogonal concerns of "what action to perform" and "how to trigger it".
//  This is the top-level type stored in Defaults for user keybind configurations.
//

import CoreGraphics
import Defaults
import Foundation
import SwiftUI

/// A window action bound to a specific keybind.
/// The action itself (WindowAction) is independent of how it's triggered.
struct BoundWindowAction: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    let action: WindowAction
    let keybind: Set<CGKeyCode>
    var bypassTriggerKey: Bool

    init(id: UUID = UUID(), action: WindowAction, keybind: Set<CGKeyCode>, bypassTriggerKey: Bool = false) {
        self.id = id
        self.action = action
        self.keybind = keybind
        self.bypassTriggerKey = bypassTriggerKey
    }

    // MARK: - Legacy Conversion

    /// Creates a BoundWindowAction from a legacy WindowAction.
    /// Note: Legacy conversion is deprecated and will be removed in future versions.
    init(legacy _: Any) {
        // Placeholder for legacy migration - not used in new architecture
        self.id = UUID()
        self.action = .special(.noAction)
        self.keybind = []
        self.bypassTriggerKey = false
    }

    /// Converts back to legacy WindowAction format.
    /// Note: Legacy conversion is deprecated and will be removed in future versions.
    func toLegacy() -> Any {
        // Placeholder for legacy migration - not used in new architecture
        self
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case direction
        case keybind
        case name
        case unit
        case anchor
        case sizeMode
        case width
        case height
        case positionMode
        case xPoint
        case yPoint
        case cycle
        case bypassTriggerKey
    }

    /// Decodes from the legacy SavedWindowActionFormat.
    /// The ID is regenerated on decode to maintain backward compatibility with the legacy system.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode the action from the legacy format
        self.action = try WindowAction(from: decoder)

        // Decode keybind
        self.keybind = try container.decode(Set<CGKeyCode>.self, forKey: .keybind)

        // Decode bypassTriggerKey (may not be present in old exports)
        self.bypassTriggerKey = try container.decodeIfPresent(Bool.self, forKey: .bypassTriggerKey) ?? false

        // Generate a new UUID (matches legacy behavior)
        self.id = UUID()
    }

    /// Encodes to the legacy SavedWindowActionFormat.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode the action in legacy format
        try action.encode(to: encoder)

        // Encode keybind
        try container.encode(keybind, forKey: .keybind)

        // Encode bypassTriggerKey (fixes the missing field bug in legacy export)
        try container.encode(bypassTriggerKey, forKey: .bypassTriggerKey)

        // Note: ID is NOT encoded (matches legacy behavior - regenerated on import)
    }
}

// MARK: - Defaults.Serializable Conformance

extension BoundWindowAction: Defaults.Serializable {}

// MARK: - Default Keybinds

extension BoundWindowAction {
    /// Alias for defaults to match the key name in Defaults.Keys
    /// The actual default keybinds are defined in WindowAction+Defaults.swift
    static var defaults: [BoundWindowAction] {
        defaultKeybinds
    }
}

// MARK: - Convenience Computed Properties

extension BoundWindowAction {
    /// Whether this action changes the screen.
    var willChangeScreen: Bool {
        if case .screen = action {
            return true
        }
        return false
    }

    /// Whether this action focuses a window without resizing.
    var willFocusWindow: Bool {
        if case .focus = action {
            return true
        }
        return false
    }

    /// Whether this action is a no-op.
    var isNoOp: Bool {
        if case let .special(special) = action {
            return special == .noAction || special == .noSelection
        }
        return false
    }

    /// Whether this action can be customized (has a name property).
    var isCustomizable: Bool {
        switch action {
        case .custom, .stash:
            true
        default:
            false
        }
    }

    /// Display name for this action (for UI).
    var displayName: String {
        switch action {
        case let .custom(custom):
            custom.name
        case let .stash(name, _):
            name
        case .cycle:
            "Cycle"
        default:
            // Use the legacy direction's raw value for now
            // TODO: Add proper localized display names
            ""
        }
    }

    /// Compatibility method for getName() - returns a display name for the action
    func getActionName() -> String {
        // For custom and stash actions, use their names
        if !displayName.isEmpty {
            return displayName
        }

        // Otherwise, use the direction's raw value
        return direction.rawValue
    }

    /// Legacy compatibility: access direction for old code
    var direction: WindowDirection {
        action.legacyExportDirection
    }

    /// Legacy compatibility: access name for custom/stash actions
    var name: String? {
        switch action {
        case let .custom(custom):
            custom.name
        case let .stash(name, _):
            name
        default:
            nil
        }
    }

    /// Legacy compatibility: check if this is a cycle action
    var isCycleAction: Bool {
        if case .cycle = action {
            return true
        }
        return false
    }

    /// Legacy compatibility: get cycle actions
    var cycle: [BoundWindowAction]? {
        if case let .cycle(actions) = action {
            return actions.map { BoundWindowAction(action: $0, keybind: []) }
        }
        return nil
    }

    /// Check if this action was generated by the grid layout system.
    var isGridLayoutAction: Bool {
        if case let .custom(custom) = action {
            return custom.name == "autogenerated_grid_layout" ||
                custom.name == "autogenerated_record_autogenerated_grid_layout"
        }
        return false
    }

    /// Whether this action will manipulate the existing window frame.
    var willManipulateExistingWindowFrame: Bool {
        if case .incremental = action {
            return true
        }
        return false
    }
}
