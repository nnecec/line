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

    /// Matches the settings slider upper bound so the control never appears stuck.
    private static let maxBorderThickness: CGFloat = 2.5
    private static let minimumCornerRadius: CGFloat = 4
    private static let hairlineThickness: CGFloat = 0.75

    init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
    }

    private var usesGlass: Bool {
        previewBackgroundEnableBlur && !reduceTransparency
    }

    private var cornerRadii: RectangleCornerRadii {
        // Prefer the window's own radii. Keep a small floor after padding inset so
        // thick borders don't collapse into sharp squares on rounded windows.
        if let inset = viewModel.overrideCornerRadii?.inset(
            by: effectivePadding,
            minRadius: Self.minimumCornerRadius
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
        min(0.22, max(0, previewBackgroundAccentOpacity))
    }

    private var effectiveBorderThickness: CGFloat {
        switch borderStyle {
        case .none:
            0
        case .hairline:
            Self.hairlineThickness
        case .accent, .gradient:
            min(Self.maxBorderThickness, max(0, previewBorderThickness))
        }
    }

    private var borderInsetPadding: CGFloat {
        effectivePadding + effectiveBorderThickness / 2
    }

    /// Soft enter scale; disabled entirely when Reduce Motion is on.
    private var enterScale: CGFloat {
        if reduceMotion {
            return 1
        }
        return viewModel.isShown ? 1 : 0.98
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

        return ZStack {
            previewSurface

            // Soft material edge only when the user did not pick an explicit border.
            if borderStyle == .none, usesGlass {
                shape
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            } else if borderStyle == .none {
                shape
                    .strokeBorder(.quinary.opacity(0.6), lineWidth: 0.5)
            }

            // Top specular rim — the detail that sells liquid glass.
            if usesGlass {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(glassStyle == .clear ? 0.28 : 0.38),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.4)
                        ),
                        lineWidth: 0.8
                    )
            }

            if effectiveBorderThickness > 0 {
                shape
                    .strokeBorder(
                        borderStrokeStyle,
                        lineWidth: effectiveBorderThickness
                    )
            }
        }
        .padding(borderInsetPadding)
        .shadow(
            color: .black.opacity(viewModel.isShown ? 0.08 : 0),
            radius: 3,
            y: 1
        )
        .shadow(
            color: .black.opacity(viewModel.isShown ? 0.16 : 0),
            radius: 20,
            y: 10
        )
        .animation(luminareAnimation, value: [accentColorController.color1, accentColorController.color2])
        .animation(luminareAnimation, value: previewBackgroundAccentOpacity)
        .animation(luminareAnimation, value: viewModel.isShown)
        .animation(luminareAnimation, value: glassStyle)
        .animation(luminareAnimation, value: borderStyle)
    }

    @ViewBuilder
    private var previewSurface: some View {
        let shape = UnevenRoundedRectangle(cornerRadii: cornerRadii)

        if usesGlass {
            Color.clear
                .glassEffect(previewGlassEffect, in: .rect(cornerRadii: cornerRadii))
                .overlay {
                    shape.fill(previewBodyFill)
                }
        } else {
            shape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        }
    }

    private var previewGlassEffect: Glass {
        switch glassStyle {
        case .clear:
            .clear
        case .regular:
            .regular.tint(Color.primary.opacity(0.04))
        case .tinted:
            .regular.tint(accentColorController.color1.opacity(glassTintOpacity))
        }
    }

    private var previewBodyFill: some ShapeStyle {
        switch glassStyle {
        case .clear:
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.02),
                    Color.primary.opacity(0.008)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .regular:
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.04),
                    Color.primary.opacity(0.018)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            LinearGradient(
                colors: [
                    accentColorController.color1.opacity(0.04),
                    accentColorController.color2.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderStrokeStyle: AnyShapeStyle {
        switch borderStyle {
        case .none:
            AnyShapeStyle(Color.clear)
        case .hairline:
            AnyShapeStyle(
                usesGlass
                    ? Color.primary.opacity(0.14)
                    : Color.primary.opacity(0.22)
            )
        case .accent:
            AnyShapeStyle(
                accentColorController.color1.opacity(usesGlass ? 0.78 : 0.85)
            )
        case .gradient:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accentColorController.color1.opacity(usesGlass ? 0.78 : 0.72),
                        accentColorController.color2.opacity(usesGlass ? 0.52 : 0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
