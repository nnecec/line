//
//  ActionPreview.swift
//  Line
//
//  Created by nnecec on 2026-03-09.
//

import Defaults
import SwiftUI

struct ActionPreview: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @Default(.accentColorMode) private var accentColorMode

    let action: WindowAction

    var body: some View {
        GeometryReader { proxy in
            let frame = frame(in: proxy)

            blurredWindow()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .animation(.easeInOut(duration: 0.20), value: frame)
        }
    }

    @ViewBuilder
    private func blurredWindow() -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let usesGlass = !reduceTransparency
        let usesAccentTint = accentColorMode.usesAccentTint

        DestinationPreviewChrome(
            shape: shape,
            usesGlass: usesGlass,
            glassStyle: usesAccentTint ? .tinted : .regular,
            borderStyle: usesAccentTint ? .hairline : .hairline,
            borderThickness: 0.85,
            accent: accentColorController.color1,
            secondaryAccent: accentColorController.color2,
            tintOpacity: 0.06,
            usesAccentTint: usesAccentTint,
            isShown: true
        )
    }

    private func frame(in proxy: GeometryProxy) -> CGRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return .zero
        }

        return WindowFrameResolver.calculateFrame(
            for: action,
            bounds: CGRect(origin: .zero, size: proxy.size),
            screen: screen,
            padding: nil
        )
    }
}
