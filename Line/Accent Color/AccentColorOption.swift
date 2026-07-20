//
//  AccentColorOption.swift
//  Line
//
//  Created by nnecec on 2025-09-07.
//

import Defaults
import SwiftUI

enum AccentColorOption: Int, Codable, Defaults.Serializable, CaseIterable {
    /// Neutral liquid glass with no accent tint (default).
    case `default` = 3
    case system = 0
    case wallpaper = 1
    case custom = 2

    /// Modes that apply an accent tint to overlays and previews.
    var usesAccentTint: Bool {
        switch self {
        case .default: false
        case .system, .wallpaper, .custom: true
        }
    }

    var image: Image {
        switch self {
        case .default: Image(systemName: "circle.dashed")
        case .system: Image(systemName: "apple.logo")
        case .wallpaper: Image(systemName: "photo")
        case .custom: Image(systemName: "eyedropper.halffull")
        }
    }

    var text: String {
        switch self {
        case .default: String(localized: "Default", comment: "Accent color option")
        case .system: String(localized: "System", comment: "Accent color option")
        case .wallpaper: String(localized: "Wallpaper", comment: "Accent color option")
        case .custom: String(localized: "Custom", comment: "Accent color option")
        }
    }
}
