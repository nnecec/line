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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @ObservedObject private var viewModel: PreviewViewModel

    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.previewBorderStyle) private var borderStyle
    @Default(.previewBackgroundEnableBlur) private var previewBackgroundEnableBlur
    @Default(.previewBackgroundAccentOpacity) private var previewBackgroundAccentOpacity
    @Default(.previewGlassStyle) private var glassStyle
    @Default(.accentColorMode) private var accentColorMode

    init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
    }

    private var usesGlass: Bool {
        previewBackgroundEnableBlur && !reduceTransparency
    }

    private var usesAccentTint: Bool {
        accentColorMode.usesAccentTint
    }

    private var cornerRadii: RectangleCornerRadii {
        if let inset = viewModel.overrideCornerRadii?.inset(
            by: effectivePadding,
            minRadius: PreviewChrome.minimumCornerRadius
        ),
            inset != .zero {
            return inset
        }

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
        min(0.10, max(0, previewBackgroundAccentOpacity))
    }

    private var effectiveBorderThickness: CGFloat {
        PreviewChrome.borderThickness(style: borderStyle, configured: previewBorderThickness)
    }

    private var borderInsetPadding: CGFloat {
        effectivePadding + effectiveBorderThickness / 2
    }

    private var enterScale: CGFloat {
        if reduceMotion {
            return 1
        }
        return viewModel.isShown ? 1 : 0.985
    }

    var body: some View {
        windowView()
            .compositingGroup()
            .scaleEffect(enterScale)
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
        let shape = UnevenRoundedRectangle(cornerRadii: cornerRadii)

        return DestinationPreviewChrome(
            shape: shape,
            usesGlass: usesGlass,
            glassStyle: glassStyle,
            borderStyle: borderStyle,
            borderThickness: effectiveBorderThickness,
            accent: accentColorController.color1,
            secondaryAccent: accentColorController.color2,
            tintOpacity: glassTintOpacity,
            usesAccentTint: usesAccentTint,
            isShown: viewModel.isShown
        )
        .padding(borderInsetPadding)
        .animation(luminareAnimation, value: [accentColorController.color1, accentColorController.color2])
        .animation(luminareAnimation, value: previewBackgroundAccentOpacity)
        .animation(luminareAnimation, value: viewModel.isShown)
        .animation(luminareAnimation, value: glassStyle)
        .animation(luminareAnimation, value: borderStyle)
        .animation(luminareAnimation, value: accentColorMode)
    }
}
