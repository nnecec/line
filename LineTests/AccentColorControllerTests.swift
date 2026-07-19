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
    private var originalMode: AccentColorOption = .system
    private var originalCustom: Color = .teal
    private var originalGradient: Color = .blue
    private var originalUseGradient = false
    private var originalLast1: Color = .black
    private var originalLast2: Color = .black
    private var originalColor1: Color = .accentColor
    private var originalColor2: Color = .accentColor

    override func setUp() async throws {
        try await super.setUp()
        originalMode = Defaults[.accentColorMode]
        originalCustom = Defaults[.customAccentColor]
        originalGradient = Defaults[.gradientColor]
        originalUseGradient = Defaults[.useGradient]
        originalLast1 = Defaults[.lastUsedAccentColor1]
        originalLast2 = Defaults[.lastUsedAccentColor2]
        originalColor1 = AccentColorController.shared.color1
        originalColor2 = AccentColorController.shared.color2
    }

    override func tearDown() async throws {
        Defaults[.accentColorMode] = originalMode
        Defaults[.customAccentColor] = originalCustom
        Defaults[.gradientColor] = originalGradient
        Defaults[.useGradient] = originalUseGradient
        Defaults[.lastUsedAccentColor1] = originalLast1
        Defaults[.lastUsedAccentColor2] = originalLast2
        AccentColorController.shared.color1 = originalColor1
        AccentColorController.shared.color2 = originalColor2
        try await super.tearDown()
    }

    /// User symptom: choosing Custom accent mode does not apply the chosen colors.
    func testRefreshAppliesCustomAccentColorsWithoutGradient() async {
        let primary = Color(red: 0.91, green: 0.12, blue: 0.34)
        Defaults[.accentColorMode] = .custom
        Defaults[.customAccentColor] = primary
        Defaults[.useGradient] = false
        Defaults[.gradientColor] = Color(red: 0.1, green: 0.8, blue: 0.2)

        await AccentColorController.shared.refresh()

        assertColorsSimilar(
            AccentColorController.shared.color1,
            primary,
            "custom mode should publish customAccentColor as color1"
        )
        assertColorsSimilar(
            AccentColorController.shared.color2,
            primary,
            "without gradient, color2 should match color1"
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

    func testRefreshAppliesCustomGradientColor() async {
        let primary = Color(red: 0.2, green: 0.4, blue: 0.9)
        let secondary = Color(red: 0.95, green: 0.55, blue: 0.1)
        Defaults[.accentColorMode] = .custom
        Defaults[.customAccentColor] = primary
        Defaults[.gradientColor] = secondary
        Defaults[.useGradient] = true

        await AccentColorController.shared.refresh()

        assertColorsSimilar(
            AccentColorController.shared.color1,
            primary,
            "custom mode should publish customAccentColor as color1"
        )
        assertColorsSimilar(
            AccentColorController.shared.color2,
            secondary,
            "with gradient, color2 should publish gradientColor"
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
            "\(message) — actual \(actualNS) vs expected \(expectedNS)",
            file: file,
            line: line
        )
    }
}
