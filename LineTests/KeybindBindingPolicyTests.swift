//
//  KeybindBindingPolicyTests.swift
//  LineTests
//

import CoreGraphics
@testable import Line
import XCTest

final class KeybindBindingPolicyTests: XCTestCase {
    private let trigger: Set<CGKeyCode> = [.kVK_Function]

    func testEffectiveKeybindUnionsTriggerUnlessBypass() {
        let normal = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )
        XCTAssertEqual(
            KeybindBindingPolicy.effectiveKeybind(for: normal, triggerKey: trigger),
            trigger.union([.kVK_ANSI_M])
        )

        let bypass = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_Control, .kVK_ANSI_M],
            bypassTriggerKey: true
        )
        XCTAssertEqual(
            KeybindBindingPolicy.effectiveKeybind(for: bypass, triggerKey: trigger),
            [.kVK_Control, .kVK_ANSI_M]
        )
    }

    func testConflictingIDsDetectsSharedEffectiveChords() {
        let a = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )
        let b = BoundWindowAction(
            action: .standard(.center(.geometric)),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )
        let conflicts = KeybindBindingPolicy.conflictingIDs(in: [a, b], triggerKey: trigger)
        XCTAssertEqual(conflicts, [a.id, b.id])
    }

    func testConflictingIDsIgnoresEmptyKeybinds() {
        let empty = BoundWindowAction(action: .special(.noSelection), keybind: [])
        let other = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [.kVK_ANSI_M],
            bypassTriggerKey: false
        )
        XCTAssertTrue(
            KeybindBindingPolicy.conflictingIDs(in: [empty, other], triggerKey: trigger).isEmpty
        )
    }

    func testValidateRecordingUnchanged() {
        let keys: Set<CGKeyCode> = [.kVK_ANSI_M]
        XCTAssertEqual(
            KeybindBindingPolicy.validateRecording(
                selection: keys,
                previousSelection: keys,
                bypassTriggerKey: false,
                triggerKey: trigger,
                existing: []
            ),
            .unchanged
        )
    }

    func testValidateRecordingRequiresModifierInBypass() {
        XCTAssertEqual(
            KeybindBindingPolicy.validateRecording(
                selection: [.kVK_ANSI_M],
                previousSelection: [],
                bypassTriggerKey: true,
                triggerKey: trigger,
                existing: []
            ),
            .missingModifierInBypass
        )
    }

    func testValidateRecordingDetectsConflict() {
        let existing = BoundWindowAction(
            action: .standard(.maximize),
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
        guard case let .conflict(name) = result else {
            return XCTFail("expected conflict, got \(result)")
        }
        XCTAssertFalse(name.isEmpty)
    }

    func testValidateRecordingAcceptsUnique() {
        XCTAssertEqual(
            KeybindBindingPolicy.validateRecording(
                selection: [.kVK_ANSI_X],
                previousSelection: [],
                bypassTriggerKey: false,
                triggerKey: trigger,
                existing: []
            ),
            .valid
        )
    }
}
