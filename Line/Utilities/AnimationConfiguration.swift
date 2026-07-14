//
//  AnimationConfiguration.swift
//  Line
//
//  Created by nnecec on 2023-10-27.
//

import Defaults
import SwiftUI

enum AnimationConfiguration: Int, Defaults.Serializable, CaseIterable, Identifiable {
    var id: Self { self }

    case fluid = 0
    case relaxed = 1
    case snappy = 2
    case brisk = 3
    case instant = 4

    var name: LocalizedStringKey {
        switch self {
        case .fluid:
            "Fluid"
        case .relaxed:
            "Relaxed"
        case .snappy:
            "Snappy"
        case .brisk:
            "Brisk"
        case .instant:
            "Instant"
        }
    }

    // MARK: Preview Window

    var previewWindow: Animation? {
        switch self {
        case .fluid:
            .timingCurve(0, 0.26, 0.45, 1, duration: 0.325)
        case .relaxed:
            .timingCurve(0.15, 0.8, 0.46, 1, duration: 0.3)
        case .snappy:
            .timingCurve(0.22, 1, 0.47, 1, duration: 0.25)
        case .brisk:
            .timingCurve(0.25, 1, 0.48, 1, duration: 0.15)
        default:
            nil
        }
    }
}
