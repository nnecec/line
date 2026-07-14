//
//  WindowActionTests.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Unit tests for WindowAction ADT implementation.
//  Tests cover: legacy conversion, codable round-trips, and type safety.
//

import Defaults
@testable import Line
import XCTest

final class WindowActionTests: XCTestCase {
    // MARK: - Legacy Conversion Tests

    func testLegacyConversion_StandardActions() throws {
        let legacyActions: [(WindowDirection, WindowAction)] = [
            (.leftHalf, .standard(.proportional(.leftHalf))),
            (.topRightQuarter, .standard(.proportional(.topRightQuarter))),
            (.maximize, .standard(.maximize)),
            (.center, .standard(.center(.geometric))),
            (.macOSCenter, .standard(.center(.macOS)))
        ]

        for (legacy, expectedV2) in legacyActions {
            let converted = try decodeLegacyWindowAction(legacyWindowActionObject(legacy))
            XCTAssertEqual(converted, expectedV2, "Legacy \(legacy) should convert to \(expectedV2)")
        }
    }

    func testLegacyConversion_IncrementalActions() throws {
        let legacyActions: [(WindowDirection, WindowAction)] = [
            (.larger, .incremental(.larger)),
            (.moveLeft, .incremental(.moveLeft)),
            (.growTop, .incremental(.growTop)),
            (.shrinkBottom, .incremental(.shrinkBottom))
        ]

        for (legacy, expectedV2) in legacyActions {
            let converted = try decodeLegacyWindowAction(legacyWindowActionObject(legacy))
            XCTAssertEqual(converted, expectedV2, "Legacy \(legacy) should convert to \(expectedV2)")
        }
    }

    func testLegacyConversion_FocusActions() throws {
        let legacyActions: [(WindowDirection, WindowAction)] = [
            (.focusLeft, .focus(.focusLeft)),
            (.focusUp, .focus(.focusUp)),
            (.focusNextInStack, .focus(.focusNextInStack))
        ]

        for (legacy, expectedV2) in legacyActions {
            let converted = try decodeLegacyWindowAction(legacyWindowActionObject(legacy))
            XCTAssertEqual(converted, expectedV2, "Legacy \(legacy) should convert to \(expectedV2)")
        }
    }

    func testLegacyConversion_ScreenSwitchActions() throws {
        let legacyActions: [(WindowDirection, WindowAction)] = [
            (.nextScreen, .screen(.next)),
            (.leftScreen, .screen(.left))
        ]

        for (legacy, expectedV2) in legacyActions {
            let converted = try decodeLegacyWindowAction(legacyWindowActionObject(legacy))
            XCTAssertEqual(converted, expectedV2, "Legacy \(legacy) should convert to \(expectedV2)")
        }
    }

    func testLegacyConversion_CustomAction() throws {
        let converted = try decodeLegacyWindowAction(legacyWindowActionObject(.custom, [
            "name": "Custom 50%",
            "unit": CustomWindowActionUnit.percentage.rawValue,
            "anchor": CustomWindowActionAnchor.topLeft.rawValue,
            "sizeMode": CustomWindowActionSizeMode.custom.rawValue,
            "width": 50.0,
            "height": 100.0,
            "positionMode": CustomWindowActionPositionMode.coordinates.rawValue,
            "xPoint": 0.0,
            "yPoint": 0.0
        ]))

        guard case let .custom(custom) = converted else {
            XCTFail("Should convert to custom action")
            return
        }

        XCTAssertEqual(custom.name, "Custom 50%")
        XCTAssertEqual(custom.unit, .percentage)
        XCTAssertEqual(custom.anchor, .topLeft)
        XCTAssertEqual(custom.width, 50.0)
        XCTAssertEqual(custom.height, 100.0)
    }

    func testLegacyConversion_CycleAction() throws {
        let converted = try decodeLegacyWindowAction(legacyWindowActionObject(.cycle, [
            "cycle": [
                legacyWindowActionObject(.leftHalf),
                legacyWindowActionObject(.rightHalf)
            ]
        ]))

        guard case let .cycle(actions) = converted else {
            XCTFail("Should convert to cycle action")
            return
        }

        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[0], .standard(.proportional(.leftHalf)))
        XCTAssertEqual(actions[1], .standard(.proportional(.rightHalf)))
    }

    // MARK: - Round-Trip Conversion Tests

    func testRoundTripConversion_PreservesEquality() throws {
        let testActions: [(WindowDirection, Set<CGKeyCode>)] = [
            (.leftHalf, []),
            (.maximize, []),
            (.moveUp, []),
            (.focusLeft, []),
            (.nextScreen, [])
        ]

        for (legacyDirection, keybind) in testActions {
            let original = try decodeLegacyBoundWindowAction(legacyWindowActionObject(legacyDirection, [
                "keybind": Array(keybind)
            ]))
            let encoded = try JSONEncoder().encode(original)
            let backToLegacy = try JSONDecoder().decode(BoundWindowAction.self, from: encoded)

            XCTAssertEqual(backToLegacy.action, WindowAction(legacyDirection), "Round-trip should preserve action for \(legacyDirection)")
            XCTAssertEqual(original.keybind, backToLegacy.keybind, "Round-trip should preserve keybind")
        }
    }

    func testRoundTripConversion_CustomAction() throws {
        let original = try decodeLegacyWindowAction(legacyWindowActionObject(.custom, [
            "name": "Test Custom",
            "unit": CustomWindowActionUnit.percentage.rawValue,
            "anchor": CustomWindowActionAnchor.center.rawValue,
            "sizeMode": CustomWindowActionSizeMode.custom.rawValue,
            "width": 75.0,
            "height": 50.0,
            "positionMode": CustomWindowActionPositionMode.generic.rawValue
        ]))

        let encoded = try JSONEncoder().encode(original)
        let backToLegacy = try JSONDecoder().decode(WindowAction.self, from: encoded)

        guard case let .custom(custom) = backToLegacy else {
            XCTFail("Should round-trip as custom action")
            return
        }

        XCTAssertEqual(custom.name, "Test Custom")
        XCTAssertEqual(custom.unit, .percentage)
        XCTAssertEqual(custom.anchor, .center)
        XCTAssertEqual(custom.width, 75.0)
        XCTAssertEqual(custom.height, 50.0)
    }

    // MARK: - Codable Tests

    func testCodable_StandardAction() throws {
        let action = WindowAction.standard(.proportional(.leftHalf))

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(WindowAction.self, from: encoded)

        XCTAssertEqual(action, decoded, "Codable round-trip should preserve equality")
    }

    func testCodable_CustomAction() throws {
        let custom = WindowAction.CustomWindowAction(
            name: "Custom Test",
            unit: .percentage,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 50.0,
            height: 100.0,
            positionMode: .coordinates,
            xPoint: 0.0,
            yPoint: 0.0
        )
        let action = WindowAction.custom(custom)

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(WindowAction.self, from: encoded)

        XCTAssertEqual(action, decoded, "Codable round-trip should preserve equality")
    }

    func testCodable_StashActionRoundTripPreservesEdges() throws {
        for edge in [StashEdge.left, .right, .bottom] {
            let action = WindowAction.stash(name: "Scratchpad", edge: edge)

            let encoded = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(WindowAction.self, from: encoded)

            XCTAssertEqual(decoded, action)
            XCTAssertEqual(decoded.stashEdge, edge)
        }
    }

    func testCodable_DecodesLegacyStashWithoutEdgeAsLeft() throws {
        let decoded = try decodeLegacyWindowAction(legacyWindowActionObject(.stash, [
            "name": "Legacy Stash"
        ]))

        XCTAssertEqual(decoded, .stash(name: "Legacy Stash", edge: .left))
        XCTAssertEqual(decoded.stashEdge, .left)
    }

    func testStashEdge_UsesPayloadAndLegacyCustomNameFallback() {
        XCTAssertEqual(WindowAction.stash(name: "Left", edge: .left).stashEdge, .left)
        XCTAssertEqual(WindowAction.stash(name: "Right", edge: .right).stashEdge, .right)
        XCTAssertEqual(WindowAction.stash(name: "Bottom", edge: .bottom).stashEdge, .bottom)

        let legacyCustom = WindowAction.custom(WindowAction.CustomWindowAction(
            name: "Legacy Stash Right",
            unit: .percentage,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 50,
            height: 50,
            positionMode: .coordinates,
            xPoint: 0,
            yPoint: 0
        ))

        XCTAssertEqual(legacyCustom.stashEdge, .right)
    }

    func testStashPersistence_RoundTripsThroughDefaultsStringValue() throws {
        let action = WindowAction.stash(name: "Scratchpad", edge: .bottom)
        let persisted = try XCTUnwrap(action.stashPersistenceValue)
        let restored = try XCTUnwrap(WindowAction(stashPersistenceValue: persisted))

        XCTAssertEqual(restored, action)
        XCTAssertEqual(restored.stashEdge, .bottom)
    }

    func testStashedWindowStore_MatchesByStashActionIdentity() {
        let requested = BoundWindowAction(action: .stash(name: "Scratchpad", edge: .right), keybind: [])
        let sameScreenWrongEdge = BoundWindowAction(action: .stash(name: "Scratchpad", edge: .left), keybind: [])
        let sameScreenWrongName = BoundWindowAction(action: .stash(name: "Notes", edge: .right), keybind: [])
        let sameScreenMatchingAction = BoundWindowAction(action: .stash(name: "Scratchpad", edge: .right), keybind: [])

        XCTAssertFalse(StashedWindowsStore.stashActionsMatch(requested: requested, stashed: sameScreenWrongEdge))
        XCTAssertFalse(StashedWindowsStore.stashActionsMatch(requested: requested, stashed: sameScreenWrongName))
        XCTAssertTrue(StashedWindowsStore.stashActionsMatch(requested: requested, stashed: sameScreenMatchingAction))
    }

    func testCodable_CycleAction() throws {
        let action = WindowAction.cycle([
            .standard(.proportional(.leftHalf)),
            .standard(.proportional(.rightHalf)),
            .standard(.maximize)
        ])

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(WindowAction.self, from: encoded)

        XCTAssertEqual(action, decoded, "Codable round-trip should preserve nested cycle actions")
    }

    func testCodable_DecodesLegacyFormat() throws {
        // Simulate legacy JSON format
        let legacyJSON = """
        {
            "direction": "LeftHalf",
            "keybind": []
        }
        """

        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(WindowAction.self, from: data)

        XCTAssertEqual(decoded, .standard(.proportional(.leftHalf)), "Should decode legacy JSON format")
    }

    func testCodable_EncodesInLegacyFormat() throws {
        let action = WindowAction.standard(.proportional(.rightHalf))

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encoded = try encoder.encode(action)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertTrue(json.contains("\"direction\""), "Should encode with 'direction' key")
        XCTAssertTrue(json.contains("\"RightHalf\""), "Should encode direction as string")
    }

    // MARK: - ProportionalLayout Tests

    func testProportionalLayout_CalculatesCorrectFrame() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

        let testCases: [(ProportionalLayout, CGRect)] = [
            (.leftHalf, CGRect(x: 0, y: 0, width: 500, height: 800)),
            (.topRightQuarter, CGRect(x: 500, y: 0, width: 500, height: 400)),
            (.horizontalCenterThird, CGRect(x: 333.33333333333331, y: 0, width: 333.33333333333331, height: 800))
        ]

        for (layout, expectedFrame) in testCases {
            let calculatedFrame = layout.calculateFrame(in: bounds)
            XCTAssertEqual(calculatedFrame, expectedFrame, accuracy: 0.01, "Layout \(layout) should calculate correct frame")
        }
    }

    // MARK: - BoundWindowAction Tests

    func testBoundWindowAction_LegacyConversion() throws {
        let bound = try decodeLegacyBoundWindowAction(legacyWindowActionObject(.leftHalf, [
            "keybind": [123],
            "bypassTriggerKey": true
        ]))

        XCTAssertEqual(bound.action, .standard(.proportional(.leftHalf)))
        XCTAssertEqual(bound.keybind, [123])
        XCTAssertTrue(bound.bypassTriggerKey)
    }

    func testBoundWindowAction_CodableRoundTrip() throws {
        let bound = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [123, 456],
            bypassTriggerKey: true
        )

        let encoded = try JSONEncoder().encode(bound)
        let decoded = try JSONDecoder().decode(BoundWindowAction.self, from: encoded)

        XCTAssertEqual(bound.action, decoded.action)
        XCTAssertEqual(bound.keybind, decoded.keybind)
        XCTAssertEqual(bound.bypassTriggerKey, decoded.bypassTriggerKey)
        // Note: ID is regenerated on decode, so we don't compare it
    }

    func testBoundWindowAction_DecodesLegacyFormatWithMissingBypassTriggerKey() throws {
        // Old exports didn't include bypassTriggerKey
        let legacyJSON = """
        {
            "direction": "Maximize",
            "keybind": [123]
        }
        """

        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BoundWindowAction.self, from: data)

        XCTAssertEqual(decoded.action, .standard(.maximize))
        XCTAssertEqual(decoded.keybind, [123])
        XCTAssertFalse(decoded.bypassTriggerKey, "Should default to false when missing")
    }

    func testBoundWindowAction_EncodesWithBypassTriggerKey() throws {
        let bound = BoundWindowAction(
            action: .standard(.maximize),
            keybind: [123],
            bypassTriggerKey: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encoded = try encoder.encode(bound)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertTrue(json.contains("\"bypassTriggerKey\""), "Should encode bypassTriggerKey field")
        XCTAssertTrue(json.contains("true"), "Should encode bypassTriggerKey value")
    }

    // MARK: - Keybind Export Tests

    func testKeybindExport_UsesCanonicalLegacyDirectionsForV2Actions() {
        let cases: [(WindowAction, WindowDirection)] = [
            (.standard(.proportional(.topHalf)), .topHalf),
            (.standard(.center(.macOS)), .macOSCenter),
            (.incremental(.moveRight), .moveRight),
            (.focus(.focusLeft), .focusLeft),
            (.screen(.next), .nextScreen)
        ]

        for (action, expectedDirection) in cases {
            let boundAction = BoundWindowAction(action: action, keybind: [123])
            let exported = SavedWindowActionFormat(boundAction)

            XCTAssertEqual(exported.direction, expectedDirection, "Should export \(action) as \(expectedDirection)")
            XCTAssertEqual(exported.keybind, [123])
        }
    }

    func testKeybindExport_PreservesCustomAndStashPayloads() {
        let custom = WindowAction.CustomWindowAction(
            name: "Custom Test",
            unit: .percentage,
            anchor: .topLeft,
            sizeMode: .custom,
            width: 50.0,
            height: 75.0,
            positionMode: .coordinates,
            xPoint: 10.0,
            yPoint: 20.0
        )
        let customExport = SavedWindowActionFormat(BoundWindowAction(action: .custom(custom), keybind: [12]))

        XCTAssertEqual(customExport.direction, .custom)
        XCTAssertEqual(customExport.keybind, [12])
        XCTAssertEqual(customExport.name, "Custom Test")
        XCTAssertEqual(customExport.unit, .percentage)
        XCTAssertEqual(customExport.anchor, .topLeft)
        XCTAssertEqual(customExport.sizeMode, .custom)
        XCTAssertEqual(customExport.width, 50.0)
        XCTAssertEqual(customExport.height, 75.0)
        XCTAssertEqual(customExport.positionMode, .coordinates)
        XCTAssertEqual(customExport.xPoint, 10.0)
        XCTAssertEqual(customExport.yPoint, 20.0)

        let stashExport = SavedWindowActionFormat(BoundWindowAction(action: .stash(name: "Scratchpad", edge: .right), keybind: [13]))

        XCTAssertEqual(stashExport.direction, .stash)
        XCTAssertEqual(stashExport.keybind, [13])
        XCTAssertEqual(stashExport.name, "Scratchpad")
        XCTAssertEqual(stashExport.stashEdge, .right)
    }

    func testKeybindExport_PreservesCycleNestedLegacyDirections() {
        let action = WindowAction.cycle([
            .standard(.proportional(.topHalf)),
            .standard(.proportional(.rightThird))
        ])

        let exported = SavedWindowActionFormat(BoundWindowAction(action: action, keybind: [14]))

        XCTAssertEqual(exported.direction, .cycle)
        XCTAssertEqual(exported.keybind, [14])
        XCTAssertEqual(exported.cycle?.map(\.direction), [.topHalf, .rightThird])
        XCTAssertEqual(exported.cycle?.map(\.keybind), [[], []])
    }
}

@MainActor
final class WindowActionMigrationTests: XCTestCase {
    private let testBounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let testScreen = NSScreen.main ?? NSScreen.screens[0]
    private let currentFrame = CGRect(x: 100, y: 120, width: 320, height: 240)

    func testMaximizeFamilyMatchesLegacyBaseline() {
        let cases: [(WindowAction.StandardWindowAction, CGRect)] = [
            (.maximize, testBounds),
            (.almostMaximize, testBounds.insetBy(dx: 20, dy: 20)),
            (.fullscreen, testBounds)
        ]

        for (standardAction, expectedFrame) in cases {
            let request = makeRequest(action: .standard(standardAction))
            let result = WindowFrameResolver.calculateFrame(for: request)

            XCTAssertEqual(result.frame, expectedFrame, accuracy: 0.01)
        }
    }

    func testInitialFrameUsesInjectedWindowRecord() {
        let initialFrame = CGRect(x: 20, y: 30, width: 400, height: 300)
        let record = WindowRecord(initialFrame: initialFrame, lastAction: nil)
        let request = makeRequest(action: .special(.initialFrame), record: record)

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, initialFrame, accuracy: 0.01)
    }

    func testInitialFrameUsesInjectedWindowRecordWithoutWindowProperties() {
        let initialFrame = CGRect(x: 20, y: 30, width: 400, height: 300)
        let request = WindowResizeRequest(
            window: nil,
            action: .special(.initialFrame),
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            record: WindowRecord(initialFrame: initialFrame, lastAction: nil)
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, initialFrame, accuracy: 0.01)
    }

    func testUndoUsesInjectedLastAction() {
        let record = WindowRecord(initialFrame: nil, lastAction: .standard(.almostMaximize))
        let request = makeRequest(action: .special(.undo), record: record)

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, testBounds.insetBy(dx: 20, dy: 20), accuracy: 0.01)
    }

    func testDerivedRequestPreservesInjectedSnapshots() {
        let initialFrame = CGRect(x: 20, y: 30, width: 400, height: 300)
        let record = WindowRecord(initialFrame: initialFrame, lastAction: .standard(.almostMaximize))
        let request = makeRequest(action: .special(.undo), record: record)

        // Runtime ResizeContext rebuilds requests around live AX windows; this covers
        // the injected snapshot contract without requiring Accessibility permission.
        let derivedRequest = request.withAction(.special(.initialFrame))
        let result = WindowFrameResolver.calculateFrame(for: derivedRequest)

        XCTAssertEqual(derivedRequest.record, record)
        XCTAssertEqual(derivedRequest.windowProperties, request.windowProperties)
        XCTAssertEqual(result.frame, initialFrame, accuracy: 0.01)
    }

    func testSpecialActionsFallBackToCurrentFrameWhenRecordIsMissing() {
        let initialFrameRequest = makeRequest(action: .special(.initialFrame))
        let undoRequest = makeRequest(action: .special(.undo))

        let initialFrameResult = WindowFrameResolver.calculateFrame(for: initialFrameRequest)
        let undoResult = WindowFrameResolver.calculateFrame(for: undoRequest)

        XCTAssertEqual(initialFrameResult.frame, currentFrame, accuracy: 0.01)
        XCTAssertEqual(undoResult.frame, currentFrame, accuracy: 0.01)
    }

    func testCustomActionPreserveSizeUsesInjectedWindowProperties() {
        let action = makeCustomSizeModeAction(sizeMode: .preserveSize)
        let request = makeRequest(action: .custom(action))

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(
            result.frame,
            CGRect(x: 680, y: 560, width: 320, height: 240),
            accuracy: 0.01
        )
    }

    func testCustomActionInitialSizeUsesInjectedWindowRecord() {
        let initialFrame = CGRect(x: 20, y: 30, width: 410, height: 260)
        let action = makeCustomSizeModeAction(sizeMode: .initialSize)
        let request = makeRequest(
            action: .custom(action),
            record: WindowRecord(initialFrame: initialFrame, lastAction: nil)
        )

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(
            result.frame,
            CGRect(x: 590, y: 540, width: 410, height: 260),
            accuracy: 0.01
        )
    }

    func testCustomActionInitialSizeFallsBackToCurrentFrameWhenRecordIsMissing() {
        let action = makeCustomSizeModeAction(sizeMode: .initialSize)
        let request = makeRequest(action: .custom(action))

        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(
            result.frame,
            CGRect(x: 680, y: 560, width: 320, height: 240),
            accuracy: 0.01
        )
        XCTAssertNotEqual(result.frame.size, testBounds.size)
    }

    func testIncrementalMoveUsesConfiguredSizeIncrement() {
        let originalIncrement = Defaults[.sizeIncrement]
        Defaults[.sizeIncrement] = 42
        defer { Defaults[.sizeIncrement] = originalIncrement }

        let request = makeRequest(action: .incremental(.moveRight))
        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, currentFrame.offsetBy(dx: 42, dy: 0), accuracy: 0.01)
    }

    func testIncrementalMoveFallsBackWhenConfiguredSizeIncrementIsInvalid() {
        let originalIncrement = Defaults[.sizeIncrement]
        Defaults[.sizeIncrement] = -5
        defer { Defaults[.sizeIncrement] = originalIncrement }

        let request = makeRequest(action: .incremental(.moveDown))
        let result = WindowFrameResolver.calculateFrame(for: request)

        XCTAssertEqual(result.frame, currentFrame.offsetBy(dx: 0, dy: 30), accuracy: 0.01)
    }

    func testResizeContextUsesConfiguredPaddingByDefault() {
        let originalUseSystemWindowManager = Defaults[.useSystemWindowManagerWhenAvailable]
        let originalEnablePadding = Defaults[.enablePadding]
        let originalPadding = Defaults[.padding]
        let originalPaddingMinimumScreenSize = Defaults[.paddingMinimumScreenSize]
        defer {
            Defaults[.useSystemWindowManagerWhenAvailable] = originalUseSystemWindowManager
            Defaults[.enablePadding] = originalEnablePadding
            Defaults[.padding] = originalPadding
            Defaults[.paddingMinimumScreenSize] = originalPaddingMinimumScreenSize
        }

        let configuredPadding = PaddingConfiguration(
            window: 12,
            externalBar: 3,
            top: 7,
            bottom: 11,
            right: 13,
            left: 17,
            configureScreenPadding: true
        )
        Defaults[.useSystemWindowManagerWhenAvailable] = false
        Defaults[.enablePadding] = true
        Defaults[.padding] = configuredPadding
        Defaults[.paddingMinimumScreenSize] = 0

        let context = ResizeContext(
            screen: testScreen,
            bounds: testBounds,
            action: BoundWindowAction(action: .standard(.maximize), keybind: [])
        )

        XCTAssertEqual(context.padding, configuredPadding)
        XCTAssertEqual(
            context.paddedBounds,
            configuredPadding.applyToBounds(testBounds, screen: testScreen),
            accuracy: 0.01
        )
    }

    func testResizeContextUsesExplicitPaddingWhenProvided() {
        let explicitPadding = PaddingConfiguration(
            window: 8,
            externalBar: 2,
            top: 4,
            bottom: 6,
            right: 10,
            left: 12,
            configureScreenPadding: true
        )

        let context = ResizeContext(
            screen: testScreen,
            bounds: testBounds,
            padding: explicitPadding,
            action: BoundWindowAction(action: .standard(.maximize), keybind: [])
        )

        XCTAssertEqual(context.padding, explicitPadding)
        XCTAssertEqual(
            context.paddedBounds,
            explicitPadding.applyToBounds(testBounds, screen: testScreen),
            accuracy: 0.01
        )
    }

    func testResizeContextExplicitZeroPaddingStaysUnpadded() {
        let originalUseSystemWindowManager = Defaults[.useSystemWindowManagerWhenAvailable]
        let originalEnablePadding = Defaults[.enablePadding]
        let originalPadding = Defaults[.padding]
        let originalPaddingMinimumScreenSize = Defaults[.paddingMinimumScreenSize]
        defer {
            Defaults[.useSystemWindowManagerWhenAvailable] = originalUseSystemWindowManager
            Defaults[.enablePadding] = originalEnablePadding
            Defaults[.padding] = originalPadding
            Defaults[.paddingMinimumScreenSize] = originalPaddingMinimumScreenSize
        }

        Defaults[.useSystemWindowManagerWhenAvailable] = false
        Defaults[.enablePadding] = true
        Defaults[.padding] = PaddingConfiguration(
            window: 20,
            externalBar: 5,
            top: 10,
            bottom: 10,
            right: 10,
            left: 10,
            configureScreenPadding: true
        )
        Defaults[.paddingMinimumScreenSize] = 0

        let context = ResizeContext(
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            action: BoundWindowAction(action: .standard(.maximize), keybind: [])
        )

        XCTAssertEqual(context.padding, .zero)
        XCTAssertEqual(context.paddedBounds, testBounds, accuracy: 0.01)
    }

    func testResizeContextSetScreenRefreshesConfiguredPadding() {
        let originalUseSystemWindowManager = Defaults[.useSystemWindowManagerWhenAvailable]
        let originalEnablePadding = Defaults[.enablePadding]
        let originalPadding = Defaults[.padding]
        let originalPaddingMinimumScreenSize = Defaults[.paddingMinimumScreenSize]
        defer {
            Defaults[.useSystemWindowManagerWhenAvailable] = originalUseSystemWindowManager
            Defaults[.enablePadding] = originalEnablePadding
            Defaults[.padding] = originalPadding
            Defaults[.paddingMinimumScreenSize] = originalPaddingMinimumScreenSize
        }

        let configuredPadding = PaddingConfiguration(
            window: 14,
            externalBar: 4,
            top: 8,
            bottom: 10,
            right: 12,
            left: 16,
            configureScreenPadding: true
        )
        let context = ResizeContext(
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            action: BoundWindowAction(action: .standard(.maximize), keybind: [])
        )

        Defaults[.useSystemWindowManagerWhenAvailable] = false
        Defaults[.enablePadding] = true
        Defaults[.padding] = configuredPadding
        Defaults[.paddingMinimumScreenSize] = 0

        context.setScreen(to: testScreen)

        XCTAssertEqual(context.padding, Defaults[.padding])
        XCTAssertEqual(context.padding, configuredPadding)
    }

    func testWindowResizeRequestPaddedBoundsUsesScreenForIgnoredNotch() {
        let originalIgnoreNotch = Defaults[.ignoreNotch]
        Defaults[.ignoreNotch] = true
        defer { Defaults[.ignoreNotch] = originalIgnoreNotch }

        let padding = PaddingConfiguration(
            window: 0,
            externalBar: 0,
            top: testScreen.menubarHeight + 20,
            bottom: 0,
            right: 0,
            left: 0,
            configureScreenPadding: true
        )
        let request = WindowResizeRequest(
            window: nil,
            action: .standard(.maximize),
            screen: testScreen,
            bounds: testBounds,
            padding: padding
        )

        XCTAssertEqual(
            request.paddedBounds,
            padding.applyToBounds(testBounds, screen: testScreen),
            accuracy: 0.01
        )

        if testScreen.menubarHeight > 0 {
            let withoutScreen = padding.applyToBounds(testBounds)
            XCTAssertGreaterThan(abs(request.paddedBounds.height - withoutScreen.height), 0.01)
        }
    }

    func testWindowResizeExecutionPreparesTargetFrameWithInjectedSettingsSnapshot() async {
        let padding = PaddingConfiguration(
            window: 12,
            externalBar: 0,
            top: 8,
            bottom: 10,
            right: 14,
            left: 16,
            configureScreenPadding: true
        )

        let prepared = await WindowResizeExecution.prepare(
            action: BoundWindowAction(action: .standard(.maximize), keybind: []),
            window: nil,
            screen: testScreen,
            bounds: testBounds,
            settings: WindowResizeExecution.SettingsSnapshot(padding: padding)
        )

        XCTAssertEqual(prepared.request.padding, padding)
        XCTAssertEqual(
            prepared.targetFrame.padded,
            padding.applyToBounds(testBounds, screen: testScreen),
            accuracy: 0.01
        )
    }

    func testWindowResizeExecutionUsesInjectedWindowRecordForInitialFrame() {
        let initialFrame = CGRect(x: 40, y: 50, width: 420, height: 280)

        let prepared = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .special(.initialFrame), keybind: []),
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            record: WindowRecord(initialFrame: initialFrame, lastAction: nil)
        )

        XCTAssertEqual(prepared.request.record?.initialFrame, initialFrame)
        XCTAssertEqual(prepared.targetFrame.padded, initialFrame, accuracy: 0.01)
    }

    func testWindowResizeExecutionPreparesGridLayoutActionWithoutGridContextLeakage() {
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: testBounds,
            workingBounds: testBounds,
            template: template,
            displayBounds: testBounds
        )
        let action = geometry.customAction(for: GridRegion(from: .topLeft, to: GridCell(row: 1, column: 0)))

        let prepared = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: action, keybind: []),
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            record: nil
        )

        XCTAssertEqual(
            prepared.targetFrame.padded,
            CGRect(x: 0, y: 0, width: 500, height: 800),
            accuracy: 0.01
        )
    }

    func testWindowResizeExecutionLegacyContextPreservesPreparedRequest() {
        let prepared = WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: .standard(.almostMaximize), keybind: []),
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            record: nil
        )

        let context = ResizeContext(preparedResize: prepared)

        XCTAssertEqual(context.bounds, testBounds)
        XCTAssertEqual(context.padding, .zero)
        XCTAssertEqual(context.action.action, WindowAction.standard(.almostMaximize))
        XCTAssertEqual(context.cachedTargetFrame.padded, prepared.targetFrame.padded, accuracy: 0.01)
    }

    private func makeRequest(
        action: WindowAction,
        record: WindowRecord? = nil
    ) -> WindowResizeRequest {
        WindowResizeRequest(
            window: nil,
            action: action,
            screen: testScreen,
            bounds: testBounds,
            padding: .zero,
            windowProperties: WindowProperties(frame: currentFrame, isResizable: true),
            record: record
        )
    }

    private func makeCustomSizeModeAction(sizeMode: CustomWindowActionSizeMode) -> WindowAction.CustomWindowAction {
        WindowAction.CustomWindowAction(
            name: "Custom Size Mode",
            unit: .pixels,
            anchor: .bottomRight,
            sizeMode: sizeMode,
            width: 999,
            height: 777,
            positionMode: .generic,
            xPoint: nil,
            yPoint: nil
        )
    }
}

final class WindowDragMouseUpPolicyTests: XCTestCase {
    func testSnappingDisabledRestoreMonitoringStillCleansUpOnMouseUp() {
        XCTAssertTrue(
            WindowDragMouseUpPolicy.shouldCleanupOnMouseUp(shouldMonitorDragActions: true)
        )
        XCTAssertFalse(
            WindowDragMouseUpPolicy.shouldApplySnapOnMouseUp(windowSnapping: false)
        )
    }

    func testSnappingDisabledStashMonitoringStillCleansUpOnMouseUp() {
        XCTAssertTrue(
            WindowDragMouseUpPolicy.shouldCleanupOnMouseUp(shouldMonitorDragActions: true)
        )
        XCTAssertFalse(
            WindowDragMouseUpPolicy.shouldApplySnapOnMouseUp(windowSnapping: false)
        )
    }

    func testSnappingEnabledCanStillApplySnapOnMouseUp() {
        XCTAssertTrue(
            WindowDragMouseUpPolicy.shouldCleanupOnMouseUp(shouldMonitorDragActions: true)
        )
        XCTAssertTrue(
            WindowDragMouseUpPolicy.shouldApplySnapOnMouseUp(windowSnapping: true)
        )
    }

    func testMouseUpDoesNotCleanUpWhenDragMonitoringIsInactive() {
        XCTAssertFalse(
            WindowDragMouseUpPolicy.shouldCleanupOnMouseUp(shouldMonitorDragActions: false)
        )
    }
}

// MARK: - Test Helpers

func legacyWindowActionObject(_ direction: WindowDirection, _ fields: [String: Any] = [:]) -> [String: Any] {
    var object = fields
    object["direction"] = direction.rawValue
    return object
}

func decodeLegacyWindowAction(_ object: [String: Any]) throws -> WindowAction {
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(WindowAction.self, from: data)
}

func decodeLegacyBoundWindowAction(_ object: [String: Any]) throws -> BoundWindowAction {
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(BoundWindowAction.self, from: data)
}

/// Asserts that two CGRects are equal within a given accuracy.
func XCTAssertEqual(
    _ lhs: CGRect,
    _ rhs: CGRect,
    accuracy: CGFloat,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(lhs.origin.x, rhs.origin.x, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.origin.y, rhs.origin.y, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy, message, file: file, line: line)
}
