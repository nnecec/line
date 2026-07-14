//
//  GridSize.swift
//  Line
//
//  Represents the size of a region in grid cells.
//  Created by nnecec on 2024-12-30.

//

import Defaults
import Foundation

/// Size in grid cells (rows and columns).
struct GridSize: Codable, Hashable, Defaults.Serializable {
    var rows: Int
    var columns: Int

    init(rows: Int, columns: Int) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
    }

    /// Clamp size to fit within the given template.
    func clamped(to template: GridTemplate) -> GridSize {
        GridSize(
            rows: min(rows, template.rows),
            columns: min(columns, template.columns)
        )
    }

    /// Default size for new apps or missing memory.
    static let `default` = GridSize(rows: 1, columns: 1)
}
