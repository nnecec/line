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
            "Balanced frost so the desktop shows through clearly."
        case .tinted:
            "A subtle accent whisper on glass when an accent mode is selected."
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

/// Stroke treatment for the window destination preview.
enum PreviewBorderStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case none
    case hairline
    case accent
    case gradient

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .none: "None"
        case .hairline: "Hairline"
        case .accent: "Accent"
        case .gradient: "Gradient"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .none:
            "No border - rely on glass edge and shadow alone."
        case .hairline:
            "A subtle system edge without accent color."
        case .accent:
            "A solid border using the current accent color."
        case .gradient:
            "A diagonal gradient between primary and secondary accents."
        }
    }

    /// Whether the thickness slider should be shown for this style.
    var usesThickness: Bool {
        switch self {
        case .none, .hairline: false
        case .accent, .gradient: true
        }
    }
}
