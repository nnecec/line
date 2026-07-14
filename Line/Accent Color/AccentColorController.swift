//
//  AccentColorController.swift
//  Line
//
//  Created by nnecec on 2025-09-06.
//

import Defaults
import Scribe
import SwiftUI

/// Publishes Line's effective accent color.
@Loggable
@MainActor
final class AccentColorController: ObservableObject {
    static let shared = AccentColorController()

    @Published var color1: Color = .accentColor
    @Published var color2: Color = .accentColor

    private init() {}

    func refresh(ignoreThrottle _: Bool = false) async {
        log.info("Refreshing accent color based on system accent setting")
        color1 = .accentColor
        color2 = .accentColor

        Defaults[.lastUsedAccentColor1] = color1
        Defaults[.lastUsedAccentColor2] = color2
    }
}

extension Color {
    static var systemGray: Color {
        Color(nsColor: NSColor.systemGray.blended(withFraction: 0.2, of: .black)!)
    }
}
