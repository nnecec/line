//
//  ActionPreview.swift
//  Line
//
//  Created by nnecec on 2026-03-09.
//

import SwiftUI

struct ActionPreview: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var accentColorController: AccentColorController = .shared

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
        let shape = RoundedRectangle(cornerRadius: 7)

        if reduceTransparency {
            shape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                .overlay {
                    shape.strokeBorder(accentColorController.color1.opacity(0.8), lineWidth: 1.5)
                }
        } else {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(accentColorController.color1.opacity(0.12)), in: shape)
                .overlay {
                    shape.strokeBorder(accentColorController.color1.opacity(0.8), lineWidth: 1.5)
                }
        }
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
