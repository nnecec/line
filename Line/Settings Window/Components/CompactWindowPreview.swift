//
//  CompactWindowPreview.swift
//  Line
//
//  Live mock of the destination-frame preview for settings.
//

import Defaults
import SwiftUI

/// Compact desktop mock that shows how the window preview looks with current theming.
struct CompactWindowPreview: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.previewBorderStyle) private var borderStyle
    @Default(.previewBackgroundEnableBlur) private var blurEnabled
    @Default(.previewBackgroundAccentOpacity) private var accentOpacity
    @Default(.previewGlassStyle) private var glassStyle

    private static let bezelRadius: CGFloat = 12
    private static let bezelPadding: CGFloat = 10
    private static let maxBorderThickness: CGFloat = 2.5
    private static let hairlineThickness: CGFloat = 0.75

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: Self.bezelRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .controlBackgroundColor),
                                Color(nsColor: .windowBackgroundColor)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.bezelRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

                // Decorative "desktop" content so glass has something to sample.
                desktopContent
                    .padding(Self.bezelPadding)

                previewCard
                    .padding(Self.bezelPadding + 8)
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay(alignment: .top) {
                Circle()
                    .fill(.primary.opacity(0.2))
                    .frame(width: 2.5, height: 2.5)
                    .padding(.top, 3)
            }

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(.primary.opacity(0.18))
                .frame(width: 28, height: 3)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.primary.opacity(0.14))
                        .frame(width: 52, height: 2.5)
                        .offset(y: 3)
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Window preview style")
        .animation(.snappy(duration: 0.2), value: borderStyle)
        .animation(.snappy(duration: 0.2), value: glassStyle)
        .animation(.snappy(duration: 0.2), value: blurEnabled)
        .animation(.snappy(duration: 0.2), value: previewPadding)
        .animation(.snappy(duration: 0.2), value: previewCornerRadius)
        .animation(.snappy(duration: 0.2), value: previewBorderThickness)
        .animation(.snappy(duration: 0.2), value: accentOpacity)
    }

    private var desktopContent: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: w * 0.34, height: h * 0.42)
                    .offset(x: w * 0.06, y: h * 0.12)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: w * 0.28, height: h * 0.52)
                    .offset(x: w * 0.58, y: h * 0.22)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accentColorController.color1.opacity(0.10))
                    .frame(width: w * 0.22, height: h * 0.18)
                    .offset(x: w * 0.36, y: h * 0.62)
            }
        }
    }

    private var previewCard: some View {
        let shape = RoundedRectangle(
            cornerRadius: max(4, previewCornerRadius * 0.55),
            style: .continuous
        )
        let thickness = effectiveBorderThickness
        let pad = max(2, previewPadding * 0.45)

        return ZStack {
            previewSurface(shape: shape)

            if borderStyle == .none {
                shape
                    .strokeBorder(
                        usesGlass ? Color.primary.opacity(0.05) : Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            }

            if usesGlass {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(glassStyle == .clear ? 0.28 : 0.36),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.4)
                        ),
                        lineWidth: 0.7
                    )
            }

            if thickness > 0 {
                shape
                    .strokeBorder(borderStrokeStyle, lineWidth: thickness)
            }
        }
        .padding(pad + thickness / 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    private var usesGlass: Bool {
        blurEnabled && !reduceTransparency
    }

    private var effectiveBorderThickness: CGFloat {
        switch borderStyle {
        case .none:
            0
        case .hairline:
            Self.hairlineThickness
        case .accent, .gradient:
            min(Self.maxBorderThickness, max(0, previewBorderThickness)) * 0.85
        }
    }

    @ViewBuilder
    private func previewSurface(shape: RoundedRectangle) -> some View {
        if usesGlass {
            Color.clear
                .glassEffect(previewGlassEffect, in: shape)
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
            .regular.tint(accentColorController.color1.opacity(min(0.22, max(0, accentOpacity))))
        }
    }

    private var previewBodyFill: some ShapeStyle {
        switch glassStyle {
        case .clear:
            LinearGradient(
                colors: [Color.primary.opacity(0.02), Color.primary.opacity(0.008)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .regular:
            LinearGradient(
                colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.018)],
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
            AnyShapeStyle(Color.primary.opacity(usesGlass ? 0.14 : 0.22))
        case .accent:
            AnyShapeStyle(accentColorController.color1.opacity(usesGlass ? 0.78 : 0.85))
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
