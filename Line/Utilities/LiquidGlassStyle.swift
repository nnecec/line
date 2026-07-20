//
//  LiquidGlassStyle.swift
//  Line
//
//  Shared glass material presets for overlays and previews.
//

import Defaults
import SwiftUI

/// System liquid-glass material variants exposed in settings.
enum LiquidGlassStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case clear
    case regular
    case tinted

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .clear: "Clear"
        case .regular: "Regular"
        case .tinted: "Tinted"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .clear:
            "Maximum transparency with a light system glass edge."
        case .regular:
            "Balanced blur and body so the overlay stays readable on busy desktops."
        case .tinted:
            "Tint the glass with the current accent color."
        }
    }
}

/// How the hover grid is drawn over the screen.
enum GridOverlayDrawStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case cells
    case lines

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .cells: "Cells"
        case .lines: "Lines"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .cells:
            "Rounded tiles with true gaps between cells."
        case .lines:
            "Minimal crosshairs for a lighter overlay."
        }
    }
}
