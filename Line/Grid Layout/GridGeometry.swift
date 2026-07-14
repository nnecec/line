//
//  GridGeometry.swift
//  Line
//
//  Pure geometry logic for grid layout calculations.
//  Created by nnecec on 2024-12-30.

//

import Foundation

/// Pure geometry logic for grid calculations. Testable without AppKit dependencies.
struct GridGeometry {
    /// The full screen frame in global coordinates (flipped Y).
    let screenFrame: CGRect

    /// The usable working area (respects menu bar, dock, Stage Manager, padding).
    let workingBounds: CGRect

    /// The visible overlay grid bounds in global coordinates.
    let displayBounds: CGRect

    /// The grid template defining rows, columns, and gap.
    let template: GridTemplate

    init(
        screenFrame: CGRect,
        workingBounds: CGRect,
        template: GridTemplate,
        displayBounds: CGRect? = nil
    ) {
        self.screenFrame = screenFrame
        self.workingBounds = workingBounds
        self.template = template
        self.displayBounds = displayBounds ?? workingBounds
    }

    /// Create a centered thumbnail rect for the overlay, keeping the working area's aspect ratio.
    static func thumbnailBounds(centeredAt center: CGPoint, screenFrame: CGRect, workingBounds: CGRect) -> CGRect {
        let aspectRatio = max(workingBounds.width, 1) / max(workingBounds.height, 1)
        let maxWidth = min(320, max(180, screenFrame.width * 0.28))
        let maxHeight = min(240, max(140, screenFrame.height * 0.28))

        var width = maxWidth
        var height = width / aspectRatio
        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }

        let margin: CGFloat = 24
        let minX = screenFrame.minX + margin
        let maxX = max(minX, screenFrame.maxX - margin - width)
        let minY = screenFrame.minY + margin
        let maxY = max(minY, screenFrame.maxY - margin - height)

        return CGRect(
            x: min(max(center.x - width / 2, minX), maxX),
            y: min(max(center.y - height / 2, minY), maxY),
            width: width,
            height: height
        )
    }

    /// The display bounds in SwiftUI local coordinates.
    var localDisplayBounds: CGRect {
        CGRect(origin: .zero, size: displayBounds.size)
    }

    // MARK: - Cell Calculations

    /// Get the grid cell at a global point (macOS coordinates, origin bottom-left).
    /// Returns nil if the point is outside the visible overlay bounds.
    func cell(atGlobalPoint point: CGPoint) -> GridCell? {
        guard displayBounds.contains(point) else {
            return nil
        }

        // Convert global point to local coordinates relative to displayBounds
        // macOS uses bottom-left origin, so we measure from the bottom
        let localPoint = CGPoint(
            x: point.x - displayBounds.minX,
            y: point.y - displayBounds.minY
        )

        let cellWidth = (displayBounds.width - template.gap * CGFloat(template.columns - 1)) / CGFloat(template.columns)
        let cellHeight = (displayBounds.height - template.gap * CGFloat(template.rows - 1)) / CGFloat(template.rows)

        // Calculate column: each column is cellWidth wide with gap after it (except the last)
        let column: Int
        if localPoint.x < cellWidth {
            column = 0
        } else {
            // After first column: (cellWidth + gap) per column
            column = min(template.columns - 1, 1 + Int((localPoint.x - cellWidth) / (cellWidth + template.gap)))
        }

        // Calculate row from bottom: each row is cellHeight tall with gap after it (except the last)
        // localPoint.y is already measured from bottom (macOS coordinate system)
        let rowFromBottom: Int
        if localPoint.y < cellHeight {
            rowFromBottom = 0
        } else {
            // After first row: (cellHeight + gap) per row
            rowFromBottom = min(template.rows - 1, 1 + Int((localPoint.y - cellHeight) / (cellHeight + template.gap)))
        }

        // Convert to top-origin row index for GridCell
        // row=0 is top, row=template.rows-1 is bottom
        let row = template.rows - 1 - rowFromBottom

        return GridCell(row: row, column: column)
    }

    /// Clamp a global point to the nearest valid cell (for drag-out-of-bounds handling).
    func clampedCell(atGlobalPoint point: CGPoint) -> GridCell {
        let clampedPoint = CGPoint(
            x: max(displayBounds.minX, min(displayBounds.maxX, point.x)),
            y: max(displayBounds.minY, min(displayBounds.maxY, point.y))
        )

        return cell(atGlobalPoint: clampedPoint) ?? .topLeft
    }

    // MARK: - Region Calculations

    /// Create a region starting at a cell with a given size, clamping to template bounds.
    /// Preserves size by adjusting start position if needed.
    func region(startingAt cell: GridCell, size: GridSize) -> GridRegion {
        GridRegion(startingAt: cell, size: size, in: template)
    }

    /// Get the global frame (macOS coordinates) for a region.
    func rect(for region: GridRegion) -> CGRect {
        rect(for: region, in: workingBounds)
    }

    /// Get the local frame (SwiftUI coordinates) for a region in the visible overlay.
    func localRect(for region: GridRegion) -> CGRect {
        let displayRect = rect(for: region, in: displayBounds)

        return CGRect(
            x: displayRect.minX - displayBounds.minX,
            y: displayBounds.maxY - displayRect.maxY,
            width: displayRect.width,
            height: displayRect.height
        )
    }

    private func rect(for region: GridRegion, in bounds: CGRect) -> CGRect {
        let cellWidth = (bounds.width - template.gap * CGFloat(template.columns - 1)) / CGFloat(template.columns)
        let cellHeight = (bounds.height - template.gap * CGFloat(template.rows - 1)) / CGFloat(template.rows)

        // X position: measure from left (straightforward)
        let x = bounds.minX + CGFloat(region.start.column) * (cellWidth + template.gap)
        let width = CGFloat(region.size.columns) * cellWidth + CGFloat(region.size.columns - 1) * template.gap

        // Y position: convert from top-origin row index to bottom-origin macOS coordinates
        // region.start.row=0 (top row) should map to the HIGHEST Y value (near maxY)
        // region.start.row=3 (bottom row in 4x4) should map to the LOWEST Y value (near minY)
        let rowFromBottom = template.rows - 1 - region.start.row

        // Calculate Y from the bottom of workingBounds
        // Each row from bottom: position at (rowFromBottom * (cellHeight + gap))
        // But we want the BOTTOM edge of this region, so subtract (region.size.rows - 1) rows
        let y = bounds.minY + CGFloat(rowFromBottom - (region.size.rows - 1)) * (cellHeight + template.gap)
        let height = CGFloat(region.size.rows) * cellHeight + CGFloat(region.size.rows - 1) * template.gap

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Window Action Generation

    /// Generate a transient custom WindowAction for this grid region.
    func customAction(for region: GridRegion) -> WindowAction {
        let globalRect = rect(for: region)

        // Convert to percentage coordinates within workingBounds
        // IMPORTANT: macOS uses bottom-left origin, but WindowAction expects top-left origin
        // So we need to flip the Y coordinate
        let percentX = ((globalRect.minX - workingBounds.minX) / workingBounds.width) * 100
        let percentY = ((workingBounds.maxY - globalRect.maxY) / workingBounds.height) * 100
        let percentWidth = (globalRect.width / workingBounds.width) * 100
        let percentHeight = (globalRect.height / workingBounds.height) * 100

        return .custom(WindowAction.CustomWindowAction(
            name: "autogenerated_grid_layout",
            unit: CustomWindowActionUnit.percentage,
            anchor: CustomWindowActionAnchor.topLeft,
            sizeMode: CustomWindowActionSizeMode.custom,
            width: percentWidth,
            height: percentHeight,
            positionMode: CustomWindowActionPositionMode.coordinates,
            xPoint: percentX,
            yPoint: percentY
        ))
    }
}
