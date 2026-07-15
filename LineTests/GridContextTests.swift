//
//  GridContextTests.swift
//  LineTests
//
//  Tests for GridContext initialization and configuration.
//

import XCTest
@testable import Line

final class GridContextTests: XCTestCase {

    func testGridContextInitialization() {
        let screen = NSScreen.main!
        let template = GridTemplate(rows: 3, columns: 4, gap: 8)
        let geometry = GridGeometry(
            screenFrame: screen.frame,
            workingBounds: screen.visibleFrame,
            template: template
        )

        let context = GridContext(
            window: nil,
            screen: screen,
            geometry: geometry,
            template: template,
            bundleId: "com.test.app"
        )

        XCTAssertNotNil(context.screen)
        XCTAssertEqual(context.template.rows, 3)
        XCTAssertEqual(context.template.columns, 4)
        XCTAssertEqual(context.bundleId, "com.test.app")
    }

    func testGridContextWithoutWindow() {
        let screen = NSScreen.main!
        let template = GridTemplate.default
        let geometry = GridGeometry(
            screenFrame: screen.frame,
            workingBounds: screen.visibleFrame,
            template: template
        )

        let context = GridContext(
            window: nil,
            screen: screen,
            geometry: geometry,
            template: template,
            bundleId: nil
        )

        XCTAssertNil(context.window)
        XCTAssertNil(context.bundleId)
    }

    func testGridContextWithDifferentScreens() {
        guard NSScreen.screens.count > 1 else {
            throw XCTSkip("需要多个屏幕")
        }

        let screen1 = NSScreen.screens[0]
        let screen2 = NSScreen.screens[1]

        // 不同屏幕的网格应该有不同的边界
        XCTAssertNotEqual(screen1.visibleFrame, screen2.visibleFrame)

        let template = GridTemplate.default
        let geometry1 = GridGeometry(
            screenFrame: screen1.frame,
            workingBounds: screen1.visibleFrame,
            template: template
        )
        let geometry2 = GridGeometry(
            screenFrame: screen2.frame,
            workingBounds: screen2.visibleFrame,
            template: template
        )

        XCTAssertNotEqual(geometry1.workingBounds, geometry2.workingBounds)
    }

    func testGridContextWithCustomTemplate() {
        let screen = NSScreen.main!
        let customTemplate = GridTemplate(rows: 5, columns: 6, gap: 12)
        let geometry = GridGeometry(
            screenFrame: screen.frame,
            workingBounds: screen.visibleFrame,
            template: customTemplate
        )

        let context = GridContext(
            window: nil,
            screen: screen,
            geometry: geometry,
            template: customTemplate,
            bundleId: nil
        )

        XCTAssertEqual(context.template.rows, 5)
        XCTAssertEqual(context.template.columns, 6)
        XCTAssertEqual(context.template.gap, 12)
    }
}
