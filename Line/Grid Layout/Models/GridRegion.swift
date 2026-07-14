//
//  GridRegion.swift
//  Line
//
//  Represents a rectangular region in the grid.
//  Created by nnecec on 2024-12-30.

//

import Foundation

/// A rectangular region spanning from start to end (inclusive).
struct GridRegion: Codable, Hashable {
    var start: GridCell
    var end: GridCell

    /// Create a normalized region from two cells (any order).
    init(from cell1: GridCell, to cell2: GridCell) {
        self.start = GridCell(
            row: min(cell1.row, cell2.row),
            column: min(cell1.column, cell2.column)
        )
        self.end = GridCell(
            row: max(cell1.row, cell2.row),
            column: max(cell1.column, cell2.column)
        )
    }

    /// Create a region from a starting cell and size, clamping to template bounds.
    /// Preserves the size by adjusting start position if needed.
    init(startingAt cell: GridCell, size: GridSize, in template: GridTemplate) {
        var adjustedStart = cell

        // Clamp to ensure the region fits within the template
        if cell.column + size.columns > template.columns {
            adjustedStart.column = template.columns - size.columns
        }
        if cell.row + size.rows > template.rows {
            adjustedStart.row = template.rows - size.rows
        }

        // Ensure start is never negative
        adjustedStart.column = max(0, adjustedStart.column)
        adjustedStart.row = max(0, adjustedStart.row)

        self.start = adjustedStart
        self.end = GridCell(
            row: adjustedStart.row + size.rows - 1,
            column: adjustedStart.column + size.columns - 1
        )
    }

    /// The size of this region in grid cells.
    var size: GridSize {
        GridSize(
            rows: end.row - start.row + 1,
            columns: end.column - start.column + 1
        )
    }

    /// Single-cell region.
    static func single(_ cell: GridCell) -> GridRegion {
        GridRegion(from: cell, to: cell)
    }
}
