//
//  MigratorTests.swift
//  LineTests
//

import CoreGraphics
import Defaults
@testable import Line
import XCTest

@MainActor
final class MigratorTests: XCTestCase {
    private var originalKeybinds: [BoundWindowAction] = []
    private var originalTriggerKey: Set<CGKeyCode> = []

    override func setUp() {
        super.setUp()
        originalKeybinds = Defaults[.keybinds]
        originalTriggerKey = Defaults[.triggerKey]
    }

    override func tearDown() {
        Defaults[.keybinds] = originalKeybinds
        Defaults[.triggerKey] = originalTriggerKey
        super.tearDown()
    }

    func testImportLineKeybindsDecodesCurrentFormat() throws {
        let saved = SavedKeybindsFormat(
            version: "2.0.0",
            triggerKey: Set<CGKeyCode>([CGKeyCode.kVK_Function, CGKeyCode.kVK_Shift]),
            actions: [savedAction(action: .standard(.maximize), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]))]
        )

        let imported = try Migrator.importLineKeybinds(from: JSONEncoder().encode(saved))

        XCTAssertEqual(imported.version, "2.0.0")
        XCTAssertEqual(imported.triggerKey, Set<CGKeyCode>([CGKeyCode.kVK_Function, CGKeyCode.kVK_Shift]))
        XCTAssertEqual(imported.actions.count, 1)
        XCTAssertEqual(imported.actions.first?.direction, .maximize)
        XCTAssertEqual(imported.actions.first?.keybind, Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]))
    }

    func testImportLegacyKeybindsDecodesSavedActionArray() throws {
        let legacyActions = [
            savedAction(action: .standard(.proportional(.leftHalf)), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_H]))
        ]

        let imported = try Migrator.importLineLegacyKeybinds(from: JSONEncoder().encode(legacyActions))

        XCTAssertNil(imported.version)
        XCTAssertNil(imported.triggerKey)
        XCTAssertEqual(imported.actions.count, 1)
        XCTAssertEqual(imported.actions.first?.direction, .leftHalf)
        XCTAssertEqual(imported.actions.first?.keybind, Set<CGKeyCode>([CGKeyCode.kVK_ANSI_H]))
    }

    func testImportRectangleKeybindsTranslatesKnownActions() throws {
        let rectangleJSON = """
        {
          "shortcuts": {
            "leftHalf": {
              "keyCode": 0,
              "modifierFlags": 0
            },
            "todoAction": {
              "keyCode": 1,
              "modifierFlags": 0
            }
          }
        }
        """

        let imported = try Migrator.importRectangleKeybinds(from: Data(rectangleJSON.utf8))

        XCTAssertEqual(imported.actions.count, 1)
        XCTAssertEqual(imported.actions.first?.direction, .leftHalf)
        XCTAssertEqual(imported.actions.first?.keybind, Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]))
    }

    func testImportLineKeybindsThrowsOnInvalidJSON() {
        XCTAssertThrowsError(try Migrator.importLineKeybinds(from: Data("not-json".utf8)))
    }

    func testUpdateDefaultsReplacesEmptyDefaultsAndCallsOnSuccess() async {
        Defaults[.keybinds] = []
        let savedData = SavedKeybindsFormat(
            version: nil,
            triggerKey: nil,
            actions: [savedAction(action: .standard(.maximize), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_M]))]
        )
        var didCallOnSuccess = false

        await Migrator.updateDefaults(with: savedData, onSuccess: {
            didCallOnSuccess = true
        })

        XCTAssertTrue(didCallOnSuccess)
        XCTAssertEqual(Defaults[.keybinds].count, 1)
        XCTAssertEqual(Defaults[.keybinds].first?.action, .standard(.maximize))
        XCTAssertEqual(Defaults[.keybinds].first?.keybind, Set<CGKeyCode>([CGKeyCode.kVK_ANSI_M]))
    }

    func testUpdateDefaultsMergeAppendsDistinctKeybindsOnly() async {
        Defaults[.keybinds] = [
            boundAction(action: .standard(.proportional(.leftHalf)), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]))
        ]
        let savedData = SavedKeybindsFormat(
            version: nil,
            triggerKey: nil,
            actions: [
                savedAction(action: .standard(.proportional(.leftHalf)), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A])),
                savedAction(action: .standard(.proportional(.rightHalf)), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_D]))
            ]
        )
        var didCallOnSuccess = false

        await Migrator.updateDefaults(
            with: savedData,
            onSuccess: { didCallOnSuccess = true },
            importDecision: { .merge }
        )

        XCTAssertTrue(didCallOnSuccess)
        XCTAssertEqual(Defaults[.keybinds].count, 2)
        XCTAssertTrue(Defaults[.keybinds].contains { $0.action == .standard(.proportional(.leftHalf)) && $0.keybind == Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]) })
        XCTAssertTrue(Defaults[.keybinds].contains { $0.action == .standard(.proportional(.rightHalf)) && $0.keybind == Set<CGKeyCode>([CGKeyCode.kVK_ANSI_D]) })
    }

    func testUpdateDefaultsEraseReplacesExistingKeybinds() async {
        Defaults[.keybinds] = [
            boundAction(action: .standard(.proportional(.leftHalf)), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]))
        ]
        let savedData = SavedKeybindsFormat(
            version: nil,
            triggerKey: nil,
            actions: [savedAction(action: .standard(.maximize), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_M]))]
        )
        var didCallOnSuccess = false

        await Migrator.updateDefaults(
            with: savedData,
            onSuccess: { didCallOnSuccess = true },
            importDecision: { .erase }
        )

        XCTAssertTrue(didCallOnSuccess)
        XCTAssertEqual(Defaults[.keybinds].count, 1)
        XCTAssertEqual(Defaults[.keybinds].first?.action, .standard(.maximize))
        XCTAssertEqual(Defaults[.keybinds].first?.keybind, Set<CGKeyCode>([CGKeyCode.kVK_ANSI_M]))
    }

    func testUpdateDefaultsCancelKeepsExistingKeybindsAndDoesNotCallOnSuccess() async {
        let existing = boundAction(action: .standard(.proportional(.leftHalf)), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_A]))
        Defaults[.keybinds] = [existing]
        let savedData = SavedKeybindsFormat(
            version: nil,
            triggerKey: nil,
            actions: [savedAction(action: .standard(.maximize), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_M]))]
        )
        var didCallOnSuccess = false

        await Migrator.updateDefaults(
            with: savedData,
            onSuccess: { didCallOnSuccess = true },
            importDecision: { .cancel }
        )

        XCTAssertFalse(didCallOnSuccess)
        XCTAssertEqual(Defaults[.keybinds].count, 1)
        XCTAssertEqual(Defaults[.keybinds].first?.action, existing.action)
        XCTAssertEqual(Defaults[.keybinds].first?.keybind, existing.keybind)
    }

    func testUpdateDefaultsAppliesImportedTriggerKeyWhenPresent() async {
        Defaults[.keybinds] = []
        Defaults[.triggerKey] = Set<CGKeyCode>([CGKeyCode.kVK_Function])
        let savedData = SavedKeybindsFormat(
            version: nil,
            triggerKey: Set<CGKeyCode>([CGKeyCode.kVK_Control]),
            actions: [savedAction(action: .standard(.maximize), keybind: Set<CGKeyCode>([CGKeyCode.kVK_ANSI_M]))]
        )

        await Migrator.updateDefaults(with: savedData, onSuccess: {})

        XCTAssertEqual(Defaults[.triggerKey], Set<CGKeyCode>([CGKeyCode.kVK_Control]))
    }

    private func savedAction(action: WindowAction, keybind: Set<CGKeyCode>) -> SavedWindowActionFormat {
        SavedWindowActionFormat(boundAction(action: action, keybind: keybind))
    }

    private func boundAction(action: WindowAction, keybind: Set<CGKeyCode>) -> BoundWindowAction {
        BoundWindowAction(action: action, keybind: keybind)
    }
}
