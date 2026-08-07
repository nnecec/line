//
//  GridGeometryTests.swift
//  LineTests
//
//  Tests for GridGeometry cell calculations and region mapping.
//

@testable import Line
import XCTest

final class GridGeometryTests: XCTestCase {
    // MARK: - Basic Cell Frame Calculations

    func testGridCellFrameCalculation2x2() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 计算单元格尺寸
        let expectedCellWidth: CGFloat = 960
        let expectedCellHeight: CGFloat = 540

        // 测试左上角单元格 (row: 0, column: 0)
        let topLeftRegion = GridRegion.single(GridCell(row: 0, column: 0))
        let topLeftRect = geometry.rect(for: topLeftRegion)

        XCTAssertEqual(topLeftRect.width, expectedCellWidth, accuracy: 0.1)
        XCTAssertEqual(topLeftRect.height, expectedCellHeight, accuracy: 0.1)
        XCTAssertEqual(topLeftRect.minX, 0, accuracy: 0.1)

        // 测试右下角单元格 (row: 1, column: 1)
        let bottomRightRegion = GridRegion.single(GridCell(row: 1, column: 1))
        let bottomRightRect = geometry.rect(for: bottomRightRegion)

        XCTAssertEqual(bottomRightRect.width, expectedCellWidth, accuracy: 0.1)
        XCTAssertEqual(bottomRightRect.height, expectedCellHeight, accuracy: 0.1)
        XCTAssertEqual(bottomRightRect.minX, expectedCellWidth, accuracy: 0.1)
    }

    func testGridCellFrameCalculationWithGap() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10
        let template = GridTemplate(rows: 2, columns: 2, gap: gap)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 有间隙时，单元格应该更小
        // cellWidth = (1920 - 10 * 1) / 2 = 955
        let expectedCellWidth: CGFloat = (1920 - gap * 1) / 2
        let expectedCellHeight: CGFloat = (1080 - gap * 1) / 2

        let region = GridRegion.single(GridCell(row: 0, column: 0))
        let rect = geometry.rect(for: region)

        XCTAssertEqual(rect.width, expectedCellWidth, accuracy: 0.1)
        XCTAssertEqual(rect.height, expectedCellHeight, accuracy: 0.1)
        XCTAssertLessThan(rect.width, 960)
        XCTAssertLessThan(rect.height, 540)
    }

    func testGridCellFrameCalculation3x3() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 3, columns: 3, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        let expectedCellWidth: CGFloat = 640
        let expectedCellHeight: CGFloat = 360

        let region = GridRegion.single(GridCell(row: 0, column: 0))
        let rect = geometry.rect(for: region)

        XCTAssertEqual(rect.width, expectedCellWidth, accuracy: 0.1)
        XCTAssertEqual(rect.height, expectedCellHeight, accuracy: 0.1)
    }

    func testGridCellFrameAlignmentToScreenEdges() {
        let workingBounds = CGRect(x: 100, y: 100, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 左上角单元格的 minX 应该 = workingBounds.minX
        let topLeftRegion = GridRegion.single(GridCell(row: 0, column: 0))
        let topLeftRect = geometry.rect(for: topLeftRegion)

        XCTAssertEqual(topLeftRect.minX, workingBounds.minX, accuracy: 0.1)
    }

    // MARK: - Mouse Position to Cell Mapping

    func testMousePositionToCellMapping() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 左上角单元格内的点 (macOS 坐标系，原点在左下)
        // row: 0 (top) 应该在 Y 的高位置
        let topLeftPoint = CGPoint(x: 100, y: 900) // 高 Y 值 = 屏幕顶部

        let cell = geometry.cell(atGlobalPoint: topLeftPoint)

        XCTAssertNotNil(cell)
        XCTAssertEqual(cell?.row, 0) // 顶部行
        XCTAssertEqual(cell?.column, 0) // 左列
    }

    func testMousePositionBottomRightCell() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 右下角单元格内的点 (macOS 坐标系)
        let bottomRightPoint = CGPoint(x: 1800, y: 100) // 低 Y 值 = 屏幕底部

        let cell = geometry.cell(atGlobalPoint: bottomRightPoint)

        XCTAssertNotNil(cell)
        XCTAssertEqual(cell?.row, 1) // 底部行
        XCTAssertEqual(cell?.column, 1) // 右列
    }

    func testMousePositionAtCellBoundary() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        let cellWidth = workingBounds.width / 2

        // 正好在单元格边界的点
        let boundaryPoint = CGPoint(x: cellWidth, y: 900)

        let cell = geometry.cell(atGlobalPoint: boundaryPoint)

        XCTAssertNotNil(cell)
        // 边界应该属于右侧单元格
        XCTAssertEqual(cell?.column, 1)
    }

    func testMousePositionOutsideBounds() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 在边界外的点
        let outsidePoint = CGPoint(x: -100, y: 500)

        let cell = geometry.cell(atGlobalPoint: outsidePoint)

        XCTAssertNil(cell)
    }

    func testClampedCellOutsideBounds() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 2, columns: 2, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // Left of bounds, mid-height (macOS bottom-left origin): clamps to left edge, bottom half → row 1.
        let outsideMid = CGPoint(x: -100, y: 500)
        let midCell = geometry.clampedCell(atGlobalPoint: outsideMid)
        XCTAssertEqual(midCell.row, 1)
        XCTAssertEqual(midCell.column, 0)

        // Far above maxY: clamp hits exclusive max edge and falls back to top-left.
        let outsideTop = CGPoint(x: -100, y: 2000)
        let topCell = geometry.clampedCell(atGlobalPoint: outsideTop)
        XCTAssertEqual(topCell.row, 0)
        XCTAssertEqual(topCell.column, 0)
    }

    // MARK: - Grid Configuration Edge Cases

    func testGridWith1x1Configuration() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 1, columns: 1, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 单单元格网格应该覆盖整个屏幕
        let region = GridRegion.single(GridCell(row: 0, column: 0))
        let rect = geometry.rect(for: region)

        XCTAssertEqual(rect.width, workingBounds.width, accuracy: 0.1)
        XCTAssertEqual(rect.height, workingBounds.height, accuracy: 0.1)
    }

    func testGridWithLargeConfiguration() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 10, columns: 10, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 大网格的单元格应该很小
        let expectedCellWidth: CGFloat = 192
        let expectedCellHeight: CGFloat = 108

        let region = GridRegion.single(GridCell(row: 0, column: 0))
        let rect = geometry.rect(for: region)

        XCTAssertEqual(rect.width, expectedCellWidth, accuracy: 0.1)
        XCTAssertEqual(rect.height, expectedCellHeight, accuracy: 0.1)
    }

    // MARK: - Region Calculations

    func testMultiCellRegion() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 4, columns: 4, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 2x2 区域从 (0, 0) 开始
        let region = GridRegion(
            startingAt: GridCell(row: 0, column: 0),
            size: GridSize(rows: 2, columns: 2),
            in: template
        )
        let rect = geometry.rect(for: region)

        // 应该覆盖 4 个单元格
        let expectedWidth = workingBounds.width / 2
        let expectedHeight = workingBounds.height / 2

        XCTAssertEqual(rect.width, expectedWidth, accuracy: 0.1)
        XCTAssertEqual(rect.height, expectedHeight, accuracy: 0.1)
    }

    func testRegionWithGap() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10
        let template = GridTemplate(rows: 4, columns: 4, gap: gap)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // 2x2 区域，间隙会影响总尺寸
        let region = GridRegion(
            startingAt: GridCell(row: 0, column: 0),
            size: GridSize(rows: 2, columns: 2),
            in: template
        )
        let rect = geometry.rect(for: region)

        // cellWidth = (1920 - 10 * 3) / 4 = 472.5
        // 2 cells width = 472.5 * 2 + 10 = 955
        let cellWidth = (workingBounds.width - gap * 3) / 4
        let expectedWidth = cellWidth * 2 + gap

        XCTAssertEqual(rect.width, expectedWidth, accuracy: 0.1)
    }

    // MARK: - Coordinate System Tests

    func testMacOSCoordinateSystemTopCell() {
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let template = GridTemplate(rows: 4, columns: 4, gap: 0)
        let geometry = GridGeometry(
            screenFrame: workingBounds,
            workingBounds: workingBounds,
            template: template
        )

        // row: 0 (顶部) 在 macOS 坐标系中应该有高 Y 值
        let topRegion = GridRegion.single(GridCell(row: 0, column: 0))
        let topRect = geometry.rect(for: topRegion)

        let bottomRegion = GridRegion.single(GridCell(row: 3, column: 0))
        let bottomRect = geometry.rect(for: bottomRegion)

        // 顶部单元格的 Y 应该高于底部单元格
        XCTAssertGreaterThan(topRect.minY, bottomRect.minY)
    }

    // MARK: - Thumbnail Bounds

    func testThumbnailBoundsGeneration() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let workingBounds = CGRect(x: 0, y: 50, width: 1920, height: 1030)
        let center = CGPoint(x: 960, y: 540)

        let thumbnail = GridGeometry.thumbnailBounds(
            centeredAt: center,
            screenFrame: screenFrame,
            workingBounds: workingBounds
        )

        // 缩略图应该在屏幕内
        XCTAssertTrue(screenFrame.contains(thumbnail))

        // 缩略图应该比原始尺寸小
        XCTAssertLessThan(thumbnail.width, workingBounds.width)
        XCTAssertLessThan(thumbnail.height, workingBounds.height)
    }

    func testThumbnailBoundsRespectMargin() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let workingBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // 极端位置：左上角
        let topLeftCenter = CGPoint(x: 0, y: 1080)
        let thumbnail = GridGeometry.thumbnailBounds(
            centeredAt: topLeftCenter,
            screenFrame: screenFrame,
            workingBounds: workingBounds
        )

        // 应该有 24pt 边距
        let expectedMargin: CGFloat = 24
        XCTAssertGreaterThanOrEqual(thumbnail.minX, expectedMargin)
        XCTAssertLessThanOrEqual(thumbnail.maxY, screenFrame.maxY - expectedMargin)
    }
}
