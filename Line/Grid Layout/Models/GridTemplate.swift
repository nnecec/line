//
//  GridTemplate.swift
//  Line
//
//  Grid template definition with rows, columns, and gap.
//  Created by nnecec on 2024-12-30.

//

import Defaults
import Foundation

/// Defines the grid structure for a screen: rows, columns, and gap between cells.
struct GridTemplate: Codable, Hashable, Defaults.Serializable {
    var rows: Int
    var columns: Int
    var gap: CGFloat

    init(rows: Int, columns: Int, gap: CGFloat = 8) {
        self.rows = max(1, min(10, rows))
        self.columns = max(1, min(10, columns))
        self.gap = max(0, min(32, gap))
    }

    /// Default template: 3 rows x 4 columns (displayed as "4 列 x 3 行")
    static let `default` = GridTemplate(rows: 3, columns: 4, gap: 8)
}
