//
//  CustomWindowActionUnit.swift
//  Line
//
//  Created by nnecec on 2024-01-01.
//

import SwiftUI

enum CustomWindowActionUnit: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case pixels = 0
    case percentage = 1

    var suffix: String {
        switch self {
        case .pixels:
            String(localized: "px", comment: "Unit symbol: pixels")
        case .percentage:
            String(localized: "%", comment: "Unit symbol: percentage")
        }
    }

    var fractionLength: NumberFormatStyleConfiguration.Precision {
        switch self {
        case .pixels:
            .fractionLength(0)
        case .percentage:
            .fractionLength(1...3)
        }
    }

    func roundIfNeeded(_ value: Double) -> Double {
        switch self {
        case .pixels:
            value.rounded(.towardZero)
        case .percentage:
            (value * 1000.0).rounded(.towardZero) / 1000.0
        }
    }
}
