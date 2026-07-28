//
//  KeybindBindingPolicyTests.swift
//  LineTests
//

import CoreGraphics
@testable import Line
import XCTest

final class KeybindBindingPolicyTests: XCTestCase {
    private let trigger: Set<CGKeyCode> = [.kVK_Function]

    // MARK: - Effective Keybind Tests

    func testEffectiveKeybindWithoutBypassIncludesTrigger() {
        let action = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )
        XCTAssertEqual(
            KeybindBindingPolicy.effectiveKeybind(for: action, triggerKey: trigger),
            trigger.union([.kVK_ANSI_M])
        )
    }

    func testEffectiveKeybindWithBypassIgnoresTrigger() {
        let action = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_Control, .kVK_ANSI_M],
            bypassTriggerKey: true
        )
        XCTAssertEqual(
            KeybindBindingPolicy.effectiveKeybind(for: action, triggerKey: trigger),
            [.kVK_Control, .kVK_ANSI_M]
        )
    }

    func testEffectiveSelectionWithoutBypassIncludesTrigger() {
        let selection: Set<CGKeyCode> = [.kVK_ANSI_A]

        let effective = KeybindBindingPolicy.effectiveSelection(
            selection: selection,
            bypassTriggerKey: false,
            triggerKey: trigger
        )

        XCTAssertEqual(effective, trigger.union([.kVK_ANSI_A]))
    }

    func testEffectiveSelectionWithBypassIgnoresTrigger() {
        let selection: Set<CGKeyCode> = [.kVK_Control, .kVK_ANSI_A]

        let effective = KeybindBindingPolicy.effectiveSelection(
            selection: selection,
            bypassTriggerKey: true,
            triggerKey: trigger
        )

        XCTAssertEqual(effective, [.kVK_Control, .kVK_ANSI_A])
    }

    // MARK: - Conflict Detection Tests

    func testNoConflictWhenAllKeybindsDifferent() {
        let action1 = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )
        let action2 = BoundWindowAction(
            action: .standard(.center(.geometric)),
            keybind: [.kVK_ANSI_B],
            bypassTriggerKey: false
        )

        let conflicts = KeybindBindingPolicy.conflictingIDs(in: [action1, action2], triggerKey: trigger)

        XCTAssertTrue(conflicts.isEmpty)
    }

    func testConflictDetectedWhenTwoActionsShareKeybind() {
        let action1 = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )
        let action2 = BoundWindowAction(
            action: .standard(.center(.geometric)),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )

        let conflicts = KeybindBindingPolicy.conflictingIDs(in: [action1, action2], triggerKey: trigger)

        XCTAssertEqual(conflicts, [action1.id, action2.id])
    }

    func testConflictAcrossThreeActionsWithSameKeybind() {
        let action1 = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )
        let action2 = BoundWindowAction(
            action: .standard(.center(.geometric)),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )
        let action3 = BoundWindowAction(
            action: .standard(.proportional(.leftHalf)),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )

        let conflicts = KeybindBindingPolicy.conflictingIDs(
            in: [action1, action2, action3],
            triggerKey: trigger
        )

        XCTAssertEqual(conflicts, [action1.id, action2.id, action3.id])
    }

    func testBypassAndNonBypassCanConflict() {
        let customTrigger: Set<CGKeyCode> = [.kVK_Control]
        // action1: bypass mode, effective = [Control, A]
        let action1 = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_Control, .kVK_ANSI_A],
            bypassTriggerKey: true
        )
        // action2: normal mode with trigger = [Control], effective = [Control, A]
        let action2 = BoundWindowAction(
            action: .standard(.center(.geometric)),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )

        let conflicts = KeybindBindingPolicy.conflictingIDs(
            in: [action1, action2],
            triggerKey: customTrigger
        )

        XCTAssertEqual(conflicts, [action1.id, action2.id])
    }

    func testEmptyKeybindExcludedFromConflictDetection() {
        let action1 = BoundWindowAction(action: .special(.noSelection), keybind: [])
        let action2 = BoundWindowAction(action: .special(.undo), keybind: [])

        let conflicts = KeybindBindingPolicy.conflictingIDs(
            in: [action1, action2],
            triggerKey: trigger
        )

        XCTAssertTrue(conflicts.isEmpty)
    }

    func testPartialConflictOnlyIncludesConflictingIDs() {
        let action1 = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )
        let action2 = BoundWindowAction(
            action: .standard(.center(.geometric)),
            keybind: [.kVK_ANSI_A],
            bypassTriggerKey: false
        )
        let action3 = BoundWindowAction(
            action: .standard(.proportional(.leftHalf)),
            keybind: [.kVK_ANSI_B],
            bypassTriggerKey: false
        )

        let conflicts = KeybindBindingPolicy.conflictingIDs(
            in: [action1, action2, action3],
            triggerKey: trigger
        )

        XCTAssertEqual(conflicts, [action1.id, action2.id])
        XCTAssertFalse(conflicts.contains(action3.id))
    }

    // MARK: - Recording Validation Tests

    func testValidationUnchangedWhenSelectionMatchesPrevious() {
        let keys: Set<CGKeyCode> = [.kVK_ANSI_M]

        let result = KeybindBindingPolicy.validateRecording(
            selection: keys,
            previousSelection: keys,
            bypassTriggerKey: false,
            triggerKey: trigger,
            existing: []
        )

        XCTAssertEqual(result, .unchanged)
    }

    func testValidationMissingModifierInBypassWhenNoModifier() {
        let result = KeybindBindingPolicy.validateRecording(
            selection: [.kVK_ANSI_M],
            previousSelection: [],
            bypassTriggerKey: true,
            triggerKey: trigger,
            existing: []
        )

        XCTAssertEqual(result, .missingModifierInBypass)
    }

    func testValidationConflictWithDisplayName() {
        let existing = BoundWindowAction(
            action: .standard(.proportional(.leftHalf)),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )

        let result = KeybindBindingPolicy.validateRecording(
            selection: [.kVK_ANSI_M],
            previousSelection: [],
            bypassTriggerKey: false,
            triggerKey: trigger,
            existing: [existing]
        )

        guard case .conflict(let displayName) = result else {
            XCTFail("Expected conflict but got \(result)")
            return
        }
        XCTAssertFalse(displayName.isEmpty)
    }

    func testValidationConflictFallbackToDirectionName() {
        let existing = BoundWindowAction(
            action: .standard(.proportional(.leftHalf)),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )

        let result = KeybindBindingPolicy.validateRecording(
            selection: [.kVK_ANSI_M],
            previousSelection: [],
            bypassTriggerKey: false,
            triggerKey: trigger,
            existing: [existing]
        )

        guard case .conflict(let displayName) = result else {
            XCTFail("Expected conflict but got \(result)")
            return
        }
        XCTAssertFalse(displayName.isEmpty)
    }

    func testValidationValidWhenNoConflictAndChanged() {
        let existing = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_B],
            bypassTriggerKey: false
        )

        let result = KeybindBindingPolicy.validateRecording(
            selection: [.kVK_ANSI_A],
            previousSelection: [.kVK_ANSI_B],
            bypassTriggerKey: false,
            triggerKey: trigger,
            existing: [existing]
        )

        XCTAssertEqual(result, .valid)
    }

    func testValidationBypassWithModifierValid() {
        let result = KeybindBindingPolicy.validateRecording(
            selection: [.kVK_Control, .kVK_ANSI_A],
            previousSelection: [],
            bypassTriggerKey: true,
            triggerKey: trigger,
            existing: []
        )

        XCTAssertEqual(result, .valid)
    }

    func testValidationConflictChecksEffectiveKeybind() {
        let customTrigger: Set<CGKeyCode> = [.kVK_Control]
        // existing bypass action: effective = [Control, A]
        let existing = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_Control, .kVK_ANSI_A],
            bypassTriggerKey: true
        )
        // selection normal mode with trigger = [Control]: effective = [Control, A]

        let result = KeybindBindingPolicy.validateRecording(
            selection: [.kVK_ANSI_A],
            previousSelection: [],
            bypassTriggerKey: false,
            triggerKey: customTrigger,
            existing: [existing]
        )

        guard case .conflict = result else {
            XCTFail("Expected conflict but got \(result)")
            return
        }
    }
}
