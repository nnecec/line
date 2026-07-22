//
//  GridContextTests.swift
//  LineTests
//
//  Tests for GridContext initialization and configuration.
//

import XCTest
@testable import Line

@MainActor
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
        XCTAssertNil(context.windowProperties)
        XCTAssertNil(context.record)
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

    func testGridContextStoresSnapshottedWindowProperties() {
        let screen = NSScreen.main!
        let template = GridTemplate.default
        let geometry = GridGeometry(
            screenFrame: screen.frame,
            workingBounds: screen.visibleFrame,
            template: template
        )
        let properties = WindowProperties(
            frame: CGRect(x: 10, y: 20, width: 300, height: 200),
            isResizable: true
        )
        let record = WindowRecord(
            initialFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            lastAction: nil
        )

        let context = GridContext(
            window: nil,
            screen: screen,
            geometry: geometry,
            template: template,
            bundleId: "com.test.app",
            windowProperties: properties,
            record: record
        )

        XCTAssertEqual(context.windowProperties, properties)
        XCTAssertEqual(context.record, record)
    }

    func testPreparePreviewUsesCachedPropertiesWithoutAX() {
        let screen = NSScreen.main!
        let workingBounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template,
            displayBounds: workingBounds
        )
        let properties = WindowProperties(
            frame: CGRect(x: 50, y: 50, width: 200, height: 150),
            isResizable: true
        )
        let region = GridRegion(from: .topLeft, to: GridCell(row: 1, column: 0))

        let context = GridContext(
            window: nil,
            screen: screen,
            geometry: geometry,
            template: template,
            bundleId: nil,
            windowProperties: properties,
            record: nil
        )

        let prepared = context.preparePreview(for: region)

        // Cached properties flow into the request (no live AX needed).
        XCTAssertEqual(prepared.request.windowProperties, properties)
        XCTAssertEqual(prepared.request.padding, .zero)
        XCTAssertEqual(prepared.request.bounds, workingBounds)
        XCTAssertTrue(prepared.action.isGridLayoutAction)

        // Frame matches geometry-derived custom action calculation.
        let expectedAction = geometry.customAction(for: region)
        let expectedRequest = WindowResizeRequest(
            window: nil,
            action: expectedAction,
            screen: screen,
            bounds: workingBounds,
            padding: .zero,
            windowProperties: properties,
            record: nil
        )
        let expectedFrame = WindowFrameResolver.calculateFrame(for: expectedRequest).frame
        XCTAssertEqual(prepared.targetFrame.padded, expectedFrame, accuracy: 0.01)
        XCTAssertEqual(
            prepared.targetFrame.padded,
            CGRect(x: 0, y: 0, width: 500, height: 800),
            accuracy: 0.01
        )
    }

    func testGridContextWithDifferentScreens() throws {
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
