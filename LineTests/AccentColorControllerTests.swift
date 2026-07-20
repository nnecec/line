//
//  AccentColorControllerTests.swift
//  LineTests
//

import AppKit
import Defaults
@testable import Line
import SwiftUI
import XCTest

@MainActor
final class AccentColorControllerTests: XCTestCase {
    private var originalMode: AccentColorOption = .default
    private var originalCustom: Color = .teal
    private var originalLast1: Color = .black
    private var originalLast2: Color = .black
    private var originalColor1: Color = .accentColor
    private var originalColor2: Color = .accentColor

    override func setUp() async throws {
        try await super.setUp()
        originalMode = Defaults[.accentColorMode]
        originalCustom = Defaults[.customAccentColor]
        originalLast1 = Defaults[.lastUsedAccentColor1]
        originalLast2 = Defaults[.lastUsedAccentColor2]
        originalColor1 = AccentColorController.shared.color1
        originalColor2 = AccentColorController.shared.color2
    }

    override func tearDown() async throws {
        Defaults[.accentColorMode] = originalMode
        Defaults[.customAccentColor] = originalCustom
        Defaults[.lastUsedAccentColor1] = originalLast1
        Defaults[.lastUsedAccentColor2] = originalLast2
        AccentColorController.shared.color1 = originalColor1
        AccentColorController.shared.color2 = originalColor2
        try await super.tearDown()
    }

    func testDefaultModeUsesNeutralAccentWithoutTint() async {
        Defaults[.accentColorMode] = .default

        await AccentColorController.shared.refresh()

        XCTAssertFalse(AccentColorController.shared.usesAccentTint)
        assertColorsSimilar(
            AccentColorController.shared.color1,
            Color.primary,
            "default mode should publish a neutral primary color"
        )
        assertColorsSimilar(
            AccentColorController.shared.color2,
            Color.primary,
            "default mode should keep color2 neutral"
        )
    }

    func testRefreshAppliesCustomAccentColor() async {
        let primary = Color(red: 0.91, green: 0.12, blue: 0.34)
        Defaults[.accentColorMode] = .custom
        Defaults[.customAccentColor] = primary

        await AccentColorController.shared.refresh()

        XCTAssertTrue(AccentColorController.shared.usesAccentTint)
        assertColorsSimilar(
            AccentColorController.shared.color1,
            primary,
            "custom mode should publish customAccentColor as color1"
        )
        assertColorsSimilar(
            AccentColorController.shared.color2,
            primary,
            "custom mode should keep color2 equal to color1"
        )
        assertColorsSimilar(
            Defaults[.lastUsedAccentColor1],
            primary,
            "lastUsedAccentColor1 should persist color1"
        )
        assertColorsSimilar(
            Defaults[.lastUsedAccentColor2],
            primary,
            "lastUsedAccentColor2 should persist color2"
        )
    }

    private func assertColorsSimilar(
        _ actual: Color,
        _ expected: Color,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualNS = NSColor(actual)
        let expectedNS = NSColor(expected)
        XCTAssertTrue(
            actualNS.isSimilar(to: expectedNS, threshold: 0.05),
            "\(message) - actual \(actualNS) vs expected \(expectedNS)",
            file: file,
            line: line
        )
    }
}
