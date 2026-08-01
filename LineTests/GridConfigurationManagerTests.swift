//
//  GridConfigurationManagerTests.swift
//  LineTests
//

import AppKit
import Defaults
@testable import Line
import XCTest

final class GridWindowMemoryStoreTests: XCTestCase {
    func testKeepsIndependentSizesForWindowsOfTheSameProcess() {
        var store = GridWindowMemoryStore(capacity: 4)
        let first = GridWindowMemoryKey(
            processIdentifier: 42,
            windowID: 100,
            screenIdentifier: "screen-a"
        )
        let second = GridWindowMemoryKey(
            processIdentifier: 42,
            windowID: 101,
            screenIdentifier: "screen-a"
        )

        store.save(GridSize(rows: 1, columns: 2), for: first)
        store.save(GridSize(rows: 2, columns: 1), for: second)

        XCTAssertEqual(store.size(for: first), GridSize(rows: 1, columns: 2))
        XCTAssertEqual(store.size(for: second), GridSize(rows: 2, columns: 1))
    }

    func testSeparatesTheSameWindowAcrossScreens() {
        var store = GridWindowMemoryStore(capacity: 4)
        let firstScreen = GridWindowMemoryKey(
            processIdentifier: 42,
            windowID: 100,
            screenIdentifier: "screen-a"
        )
        let secondScreen = GridWindowMemoryKey(
            processIdentifier: 42,
            windowID: 100,
            screenIdentifier: "screen-b"
        )

        store.save(GridSize(rows: 1, columns: 2), for: firstScreen)
        store.save(GridSize(rows: 2, columns: 1), for: secondScreen)

        XCTAssertEqual(store.size(for: firstScreen), GridSize(rows: 1, columns: 2))
        XCTAssertEqual(store.size(for: secondScreen), GridSize(rows: 2, columns: 1))
    }

    func testEvictsTheOldestWindowWhenCapacityIsReached() {
        var store = GridWindowMemoryStore(capacity: 2)
        let first = GridWindowMemoryKey(processIdentifier: 1, windowID: 1, screenIdentifier: "screen")
        let second = GridWindowMemoryKey(processIdentifier: 1, windowID: 2, screenIdentifier: "screen")
        let third = GridWindowMemoryKey(processIdentifier: 1, windowID: 3, screenIdentifier: "screen")

        store.save(GridSize(rows: 1, columns: 1), for: first)
        store.save(GridSize(rows: 1, columns: 2), for: second)
        store.save(GridSize(rows: 2, columns: 1), for: third)

        XCTAssertNil(store.size(for: first))
        XCTAssertEqual(store.size(for: second), GridSize(rows: 1, columns: 2))
        XCTAssertEqual(store.size(for: third), GridSize(rows: 2, columns: 1))
        XCTAssertEqual(store.count, 2)
    }

    func testClearsOnlyTheTerminatedProcess() {
        var store = GridWindowMemoryStore(capacity: 4)
        let terminated = GridWindowMemoryKey(processIdentifier: 42, windowID: 1, screenIdentifier: "screen")
        let surviving = GridWindowMemoryKey(processIdentifier: 43, windowID: 1, screenIdentifier: "screen")

        store.save(GridSize(rows: 1, columns: 2), for: terminated)
        store.save(GridSize(rows: 2, columns: 1), for: surviving)
        store.removeAll(processIdentifier: 42)

        XCTAssertNil(store.size(for: terminated))
        XCTAssertEqual(store.size(for: surviving), GridSize(rows: 2, columns: 1))
    }
}

final class GridMemoryRecordTests: XCTestCase {
    func testParsesValidPersistentRecordsAndSortsByAppThenScreen() {
        let firstKey = GridMemoryKey(bundleId: "com.example.Alpha", screenIdentifier: "screen-b")
        let secondKey = GridMemoryKey(bundleId: "com.example.Alpha", screenIdentifier: "screen-a")
        let thirdKey = GridMemoryKey(bundleId: "com.example.Zulu", screenIdentifier: "screen-a")
        let memory = [
            thirdKey.storageKey: GridSize(rows: 1, columns: 3),
            "malformed": GridSize(rows: 9, columns: 9),
            "::screen": GridSize(rows: 9, columns: 9),
            "bundle::": GridSize(rows: 9, columns: 9),
            "bundle::screen::extra": GridSize(rows: 9, columns: 9),
            firstKey.storageKey: GridSize(rows: 1, columns: 2),
            secondKey.storageKey: GridSize(rows: 2, columns: 1)
        ]

        let records = GridMemoryRecord.records(from: memory)

        XCTAssertEqual(records.map(\.key), [secondKey, firstKey, thirdKey])
        XCTAssertEqual(records.map(\.id), [secondKey.storageKey, firstKey.storageKey, thirdKey.storageKey])
    }
}

@MainActor
final class GridConfigurationManagerTests: XCTestCase {
    private let manager = GridConfigurationManager.shared
    private var originalDefaultTemplate: GridTemplate!
    private var originalScreenTemplates: [String: GridTemplate]!
    private var originalGridMemory: [String: GridSize]!

    override func setUp() {
        super.setUp()
        originalDefaultTemplate = Defaults[.defaultGridTemplate]
        originalScreenTemplates = Defaults[.screenGridTemplates]
        originalGridMemory = Defaults[.gridMemory]
        Defaults[.defaultGridTemplate] = .default
        Defaults[.screenGridTemplates] = [:]
        Defaults[.gridMemory] = [:]
        manager.clearAllSessionMemory()
    }

    override func tearDown() {
        manager.clearAllSessionMemory()
        Defaults[.defaultGridTemplate] = originalDefaultTemplate
        Defaults[.screenGridTemplates] = originalScreenTemplates
        Defaults[.gridMemory] = originalGridMemory
        super.tearDown()
    }

    func testWindowMemoryOverridesPersistentAppFallbackWithoutChangingOtherWindows() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let firstWindow = GridWindowIdentity(processIdentifier: 42, windowID: 100)
        let secondWindow = GridWindowIdentity(processIdentifier: 42, windowID: 101)
        let bundleIdentifier = "com.example.Editor"

        manager.saveSize(
            GridSize(rows: 1, columns: 2),
            bundleId: bundleIdentifier,
            windowIdentity: firstWindow,
            screen: screen
        )

        XCTAssertEqual(
            manager.rememberedSize(
                bundleId: bundleIdentifier,
                windowIdentity: secondWindow,
                screen: screen
            ),
            GridSize(rows: 1, columns: 2)
        )

        manager.saveSize(
            GridSize(rows: 2, columns: 1),
            bundleId: bundleIdentifier,
            windowIdentity: secondWindow,
            screen: screen
        )

        XCTAssertEqual(
            manager.rememberedSize(
                bundleId: bundleIdentifier,
                windowIdentity: firstWindow,
                screen: screen
            ),
            GridSize(rows: 1, columns: 2)
        )
        XCTAssertEqual(
            manager.rememberedSize(
                bundleId: bundleIdentifier,
                windowIdentity: secondWindow,
                screen: screen
            ),
            GridSize(rows: 2, columns: 1)
        )
        XCTAssertEqual(
            manager.rememberedSize(bundleId: bundleIdentifier, screen: screen),
            GridSize(rows: 2, columns: 1)
        )
    }

    func testClearingSessionMemoryFallsBackToPersistentAppMemory() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let identity = GridWindowIdentity(processIdentifier: 42, windowID: 100)
        let bundleIdentifier = "com.example.Editor"

        manager.saveSize(
            GridSize(rows: 2, columns: 1),
            bundleId: bundleIdentifier,
            windowIdentity: identity,
            screen: screen
        )
        manager.saveSize(
            GridSize(rows: 1, columns: 2),
            bundleId: bundleIdentifier,
            screen: screen
        )

        manager.clearAllSessionMemory()

        XCTAssertEqual(
            manager.rememberedSize(
                bundleId: bundleIdentifier,
                windowIdentity: identity,
                screen: screen
            ),
            GridSize(rows: 1, columns: 2)
        )
    }

    func testWindowMemoryWorksWhenBundleIdentifierIsUnavailable() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let identity = GridWindowIdentity(processIdentifier: 42, windowID: 100)

        manager.saveSize(
            GridSize(rows: 2, columns: 1),
            bundleId: nil,
            windowIdentity: identity,
            screen: screen
        )

        XCTAssertEqual(
            manager.rememberedSize(bundleId: nil, windowIdentity: identity, screen: screen),
            GridSize(rows: 2, columns: 1)
        )
        XCTAssertTrue(Defaults[.gridMemory].isEmpty)
    }

    func testRemovingPersistentRecordsDoesNotClearWindowSessionMemory() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let identity = GridWindowIdentity(processIdentifier: 42, windowID: 100)
        let bundleIdentifier = "com.example.Editor"

        manager.saveSize(
            GridSize(rows: 2, columns: 1),
            bundleId: bundleIdentifier,
            windowIdentity: identity,
            screen: screen
        )
        let key = GridMemoryKey(bundleId: bundleIdentifier, screenIdentifier: screen.gridIdentifier)

        manager.clearMemory(for: Set([key]))

        XCTAssertTrue(Defaults[.gridMemory].isEmpty)
        XCTAssertEqual(
            manager.rememberedSize(
                bundleId: bundleIdentifier,
                windowIdentity: identity,
                screen: screen
            ),
            GridSize(rows: 2, columns: 1)
        )
    }

    func testClearingTerminatedProcessKeepsOtherProcessWindowMemory() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let terminatedWindow = GridWindowIdentity(processIdentifier: 42, windowID: 100)
        let survivingWindow = GridWindowIdentity(processIdentifier: 43, windowID: 100)

        manager.saveSize(
            GridSize(rows: 1, columns: 2),
            bundleId: nil,
            windowIdentity: terminatedWindow,
            screen: screen
        )
        manager.saveSize(
            GridSize(rows: 2, columns: 1),
            bundleId: nil,
            windowIdentity: survivingWindow,
            screen: screen
        )

        manager.clearSessionMemory(forProcessIdentifier: terminatedWindow.processIdentifier)

        XCTAssertEqual(
            manager.rememberedSize(bundleId: nil, windowIdentity: terminatedWindow, screen: screen),
            .default
        )
        XCTAssertEqual(
            manager.rememberedSize(bundleId: nil, windowIdentity: survivingWindow, screen: screen),
            GridSize(rows: 2, columns: 1)
        )
    }

    func testFullSessionClearInvalidatesEarlierGeneration() {
        let generation = manager.sessionGeneration

        manager.clearAllSessionMemory()

        XCTAssertFalse(manager.isCurrentSessionGeneration(generation))
        XCTAssertTrue(manager.isCurrentSessionGeneration(manager.sessionGeneration))
    }
}
