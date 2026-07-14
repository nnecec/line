//
//  DataPatcherTests.swift
//  LineTests
//

import Defaults
@testable import Line
import XCTest

final class DataPatcherTests: XCTestCase {
    private let userDefaults = UserDefaults.standard

    private var originalAccentColorMode: AccentColorOption = .system
    private var originalHideOnNoSelection = false
    private var originalPatchesApplied: DataPatcher.Patches = []

    private var originalUseSystemAccentColor: Any?
    private var originalProcessWallpaper: Any?
    private var originalHideUntilDirectionIsChosen: Any?

    override func setUp() {
        super.setUp()
        originalAccentColorMode = Defaults[.accentColorMode]
        originalHideOnNoSelection = Defaults[.hideOnNoSelection]
        originalPatchesApplied = Defaults[.patchesApplied]
        originalUseSystemAccentColor = userDefaults.object(forKey: legacyUseSystemAccentColorKey)
        originalProcessWallpaper = userDefaults.object(forKey: legacyProcessWallpaperKey)
        originalHideUntilDirectionIsChosen = userDefaults.object(forKey: legacyHideUntilDirectionIsChosenKey)
    }

    override func tearDown() {
        Defaults[.accentColorMode] = originalAccentColorMode
        Defaults[.hideOnNoSelection] = originalHideOnNoSelection
        Defaults[.patchesApplied] = originalPatchesApplied
        restoreLegacyValue(originalUseSystemAccentColor, forKey: legacyUseSystemAccentColorKey)
        restoreLegacyValue(originalProcessWallpaper, forKey: legacyProcessWallpaperKey)
        restoreLegacyValue(originalHideUntilDirectionIsChosen, forKey: legacyHideUntilDirectionIsChosenKey)
        super.tearDown()
    }

    func testRunMigratesSystemAccentColorPreference() {
        Defaults[.patchesApplied] = []
        Defaults[.accentColorMode] = .custom
        setLegacyBool(true, forKey: legacyUseSystemAccentColorKey)
        setLegacyBool(false, forKey: legacyProcessWallpaperKey)

        DataPatcher.run()

        XCTAssertEqual(Defaults[.accentColorMode], .system)
        XCTAssertTrue(Defaults[.patchesApplied].contains(.changeToAccentColorMode))
    }

    func testRunMigratesWallpaperAccentColorPreference() {
        Defaults[.patchesApplied] = []
        Defaults[.accentColorMode] = .custom
        setLegacyBool(false, forKey: legacyUseSystemAccentColorKey)
        setLegacyBool(true, forKey: legacyProcessWallpaperKey)

        DataPatcher.run()

        XCTAssertEqual(Defaults[.accentColorMode], .wallpaper)
        XCTAssertTrue(Defaults[.patchesApplied].contains(.changeToAccentColorMode))
    }

    func testRunMigratesHideUntilDirectionIsChosenPreference() {
        Defaults[.patchesApplied] = []
        Defaults[.hideOnNoSelection] = false
        setLegacyBool(true, forKey: legacyHideUntilDirectionIsChosenKey)

        DataPatcher.run()

        XCTAssertTrue(Defaults[.hideOnNoSelection])
        XCTAssertTrue(Defaults[.patchesApplied].contains(.changeTohideOnNoSelection))
    }

    func testRunIsIdempotentWhenPatchesAlreadyApplied() {
        Defaults[.patchesApplied] = []
        Defaults[.accentColorMode] = .custom
        setLegacyBool(true, forKey: legacyUseSystemAccentColorKey)
        setLegacyBool(false, forKey: legacyProcessWallpaperKey)

        DataPatcher.run()
        Defaults[.accentColorMode] = .custom
        setLegacyBool(false, forKey: legacyUseSystemAccentColorKey)
        setLegacyBool(true, forKey: legacyProcessWallpaperKey)

        DataPatcher.run()

        XCTAssertEqual(Defaults[.accentColorMode], .custom)
        XCTAssertTrue(Defaults[.patchesApplied].contains(.changeToAccentColorMode))
    }

    private func setLegacyBool(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    private func restoreLegacyValue(_ value: Any?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}

private let legacyUseSystemAccentColorKey = "useSystemAccentColor"
private let legacyProcessWallpaperKey = "processWallpaper"
private let legacyHideUntilDirectionIsChosenKey = "hideUntilDirectionIsChosen"
