//
//  GridCell.swift
//  Line
//
//  Represents a single cell in the grid.
//  Created by nnecec on 2024-12-30.

//

import Foundation

/// A single cell in the grid. (0, 0) is the visual top-left corner.
struct GridCell: Codable, Hashable {
    var row: Int
    var column: Int

    /// Visual top-left cell.
    static let topLeft = GridCell(row: 0, column: 0)
}
