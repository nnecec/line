//
//  PreviewView.swift
//  Line
//
//  Created by nnecec on 2023-01-24.
//

import Defaults
import SwiftUI

struct PreviewView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @ObservedObject private var viewModel: PreviewViewModel

    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.previewBackgroundEnableBlur) private var previewBackgroundEnableBlur
    @Default(.previewBackgroundAccentOpacity) private var previewBackgroundAccentOpacity

    init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
    }

    private var cornerRadii: RectangleCornerRadii {
        // Prefer the window's own radii, but skip if the padded inset would be sharp.
        if let inset = viewModel.overrideCornerRadii?.inset(by: effectivePadding),
           inset != .zero {
            return inset
        }

        // Fall back to the user's default radius
        return RectangleCornerRadii(
            topLeading: previewCornerRadius,
            bottomLeading: previewCornerRadius,
            bottomTrailing: previewCornerRadius,
            topTrailing: previewCornerRadius
        )
    }

    private var effectivePadding: CGFloat {
        viewModel.isGridLayoutPreview ? 0 : previewPadding
    }

    private var glassTintOpacity: CGFloat {
        min(0.22, max(0, previewBackgroundAccentOpacity))
    }

    private var effectiveBorderThickness: CGFloat {
        min(2.5, max(0, previewBorderThickness))
    }

    var body: some View {
        windowView()
            .compositingGroup()
            .frame(width: viewModel.computedFrame.width, height: viewModel.computedFrame.height)
            .offset(x: viewModel.computedFrame.minX, y: viewModel.computedFrame.minY)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .opacity(viewModel.isShown ? 1 : 0)
    }

    private func windowView() -> some View {
        ZStack {
            previewSurface

            UnevenRoundedRectangle(cornerRadii: cornerRadii)
                .strokeBorder(.quinary, lineWidth: 1)

            if effectiveBorderThickness > 0 {
                UnevenRoundedRectangle(cornerRadii: cornerRadii)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColorController.color1.opacity(0.72),
                                accentColorController.color2.opacity(0.56)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: effectiveBorderThickness
                    )
            }
        }
        .padding(effectivePadding + effectiveBorderThickness / 2)
        .shadow(color: .black.opacity(viewModel.isShown ? 0.18 : 0), radius: 18, y: 8)
        .animation(luminareAnimation, value: [accentColorController.color1, accentColorController.color2])
        .animation(luminareAnimation, value: previewBackgroundAccentOpacity)
    }

    @ViewBuilder
    private var previewSurface: some View {
        let shape = UnevenRoundedRectangle(cornerRadii: cornerRadii)

        if previewBackgroundEnableBlur, !reduceTransparency {
            Color.clear
                .glassEffect(
                    .regular.tint(accentColorController.color1.opacity(glassTintOpacity)),
                    in: .rect(cornerRadii: cornerRadii)
                )
                .overlay {
                    shape.fill(Color.primary.opacity(0.025))
                }
        } else {
            shape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        }
    }
}
