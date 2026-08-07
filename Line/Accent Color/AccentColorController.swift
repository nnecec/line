//
//  AccentColorController.swift
//  Line
//
//  Created by nnecec on 2025-09-06.
//

import Defaults
import Scribe
import SwiftUI

/// Publishes Line's effective accent color according to the user's accent settings.
/// Automatically refreshes when `accentColorMode` or `customAccentColor` changes.
@Loggable
@MainActor
final class AccentColorController: ObservableObject {
    static let shared = AccentColorController()

    @Published var color1: Color = Defaults[.lastUsedAccentColor1]
    @Published var color2: Color = Defaults[.lastUsedAccentColor2]

    /// Whether overlays should tint glass / borders with the accent.
    var usesAccentTint: Bool {
        Defaults[.accentColorMode].usesAccentTint
    }

    private let wallpaperProcessor = WallpaperProcessor()
    private var observationTask: Task<(), Never>?

    private init() {
        self.observationTask = Task { [weak self] in
            let updates = Defaults.updates(
                .accentColorMode,
                .customAccentColor
            )

            for await _ in updates {
                guard
                    !Task.isCancelled,
                    let self
                else {
                    break
                }
                await refresh()
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    func refresh(ignoreThrottle: Bool = false) async {
        switch Defaults[.accentColorMode] {
        case .default:
            log.info("Refreshing accent color for default (neutral glass) mode")
            // Neutral highlight used only for soft edges when no accent tint is active.
            color1 = Color.primary
            color2 = Color.primary

        case .system:
            log.info("Refreshing accent color based on system accent setting")
            color1 = Color.accentColor
            color2 = Color.accentColor

        case .wallpaper:
            log.info("Refreshing accent color based on wallpaper analysis")
            let colors = await wallpaperProcessor.fetchLatest(ignoreThrottle: ignoreThrottle)
            color1 = colors.primary
            // Secondary wallpaper sample for subtle rim variation only.
            color2 = colors.secondary

        case .custom:
            log.info("Refreshing accent color based on custom selection")
            color1 = Defaults[.customAccentColor]
            color2 = Defaults[.customAccentColor]
        }

        Defaults[.lastUsedAccentColor1] = color1
        Defaults[.lastUsedAccentColor2] = color2
    }
}

extension Color {
    static var systemGray: Color {
        Color(nsColor: NSColor.systemGray.blended(withFraction: 0.2, of: .black)!)
    }
}
