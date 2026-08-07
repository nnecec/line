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

@MainActor
final class DefaultsGridMemoryStoreTests: XCTestCase {
    private var rawMemory: [String: GridSize] = [:]
    private var store: DefaultsGridMemoryStore!

    override func setUp() {
        super.setUp()
        rawMemory = [:]
        store = DefaultsGridMemoryStore(
            read: { [unowned self] in rawMemory },
            write: { [unowned self] in rawMemory = $0 }
        )
    }

    func testSavesAndReadsTypedRecords() {
        let key = GridMemoryKey(bundleId: "com.example.Editor", screenIdentifier: "screen-a")
        let size = GridSize(rows: 2, columns: 3)

        store.save(size, for: key)

        XCTAssertEqual(store.size(for: key), size)
        XCTAssertEqual(store.records(), [GridMemoryRecord(key: key, size: size)])
    }

    func testRemovingSelectedKeysPreservesUnknownRawEntries() {
        let removed = GridMemoryKey(bundleId: "com.example.Remove", screenIdentifier: "screen-a")
        let kept = GridMemoryKey(bundleId: "com.example.Keep", screenIdentifier: "screen-b")
        rawMemory = [
            "com.example.Remove::screen-a": GridSize(rows: 1, columns: 2),
            "com.example.Keep::screen-b": GridSize(rows: 2, columns: 1),
            "future-format": GridSize(rows: 3, columns: 3)
        ]

        store.remove(Set([removed]))

        XCTAssertNil(rawMemory["com.example.Remove::screen-a"])
        XCTAssertNotNil(store.size(for: kept))
        XCTAssertNotNil(rawMemory["future-format"])
    }

    func testRecordsIgnoreMalformedEntriesAndSortByAppThenScreen() {
        let firstKey = GridMemoryKey(bundleId: "com.example.Alpha", screenIdentifier: "screen-b")
        let secondKey = GridMemoryKey(bundleId: "com.example.Alpha", screenIdentifier: "screen-a")
        let thirdKey = GridMemoryKey(bundleId: "com.example.Zulu", screenIdentifier: "screen-a")
        rawMemory = [
            "com.example.Zulu::screen-a": GridSize(rows: 1, columns: 3),
            "malformed": GridSize(rows: 9, columns: 9),
            "::screen": GridSize(rows: 9, columns: 9),
            "bundle::": GridSize(rows: 9, columns: 9),
            "bundle::screen::extra": GridSize(rows: 9, columns: 9),
            "com.example.Alpha::screen-b": GridSize(rows: 1, columns: 2),
            "com.example.Alpha::screen-a": GridSize(rows: 2, columns: 1)
        ]

        XCTAssertEqual(store.records().map(\.key), [secondKey, firstKey, thirdKey])
    }

    func testRemoveAllClearsKnownAndUnknownEntries() {
        rawMemory = [
            "com.example.Editor::screen-a": GridSize(rows: 1, columns: 2),
            "future-format": GridSize(rows: 3, columns: 3)
        ]

        store.removeAll()

        XCTAssertTrue(rawMemory.isEmpty)
    }
}

@MainActor
private final class InMemoryGridMemoryStore: GridMemoryPersisting {
    private var memory: [GridMemoryKey: GridSize]

    init(memory: [GridMemoryKey: GridSize] = [:]) {
        self.memory = memory
    }

    func size(for key: GridMemoryKey) -> GridSize? {
        memory[key]
    }

    func save(_ size: GridSize, for key: GridMemoryKey) {
        memory[key] = size
    }

    func records() -> [GridMemoryRecord] {
        memory.map { GridMemoryRecord(key: $0.key, size: $0.value) }
            .sorted {
                if $0.key.bundleId != $1.key.bundleId {
                    return $0.key.bundleId.localizedStandardCompare($1.key.bundleId) == .orderedAscending
                }
                return $0.key.screenIdentifier.localizedStandardCompare($1.key.screenIdentifier) == .orderedAscending
            }
    }

    func remove(_ keys: Set<GridMemoryKey>) {
        for key in keys {
            memory.removeValue(forKey: key)
        }
    }

    func removeAll() {
        memory.removeAll()
    }
}

@MainActor
final class GridConfigurationManagerTests: XCTestCase {
    private var manager: GridConfigurationManager!
    private var persistentStore: InMemoryGridMemoryStore!
    private var originalDefaultTemplate: GridTemplate!
    private var originalScreenTemplates: [String: GridTemplate]!

    override func setUp() {
        super.setUp()
        originalDefaultTemplate = Defaults[.defaultGridTemplate]
        originalScreenTemplates = Defaults[.screenGridTemplates]
        Defaults[.defaultGridTemplate] = .default
        Defaults[.screenGridTemplates] = [:]
        persistentStore = InMemoryGridMemoryStore()
        manager = GridConfigurationManager(persistentStore: persistentStore)
    }

    override func tearDown() {
        manager.clearAllSessionMemory()
        Defaults[.defaultGridTemplate] = originalDefaultTemplate
        Defaults[.screenGridTemplates] = originalScreenTemplates
        super.tearDown()
    }

    func testInitializesPublishedRecordsFromInjectedStore() {
        let key = GridMemoryKey(bundleId: "com.example.Editor", screenIdentifier: "screen-a")
        let size = GridSize(rows: 2, columns: 1)
        let store = InMemoryGridMemoryStore(memory: [key: size])

        let manager = GridConfigurationManager(persistentStore: store)

        XCTAssertEqual(manager.persistentRecords, [GridMemoryRecord(key: key, size: size)])
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
        XCTAssertTrue(persistentStore.records().isEmpty)
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
        XCTAssertEqual(manager.persistentRecords.map(\.key), [key])

        manager.clearMemory(for: Set([key]))

        XCTAssertTrue(persistentStore.records().isEmpty)
        XCTAssertTrue(manager.persistentRecords.isEmpty)
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
