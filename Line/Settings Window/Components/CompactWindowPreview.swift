//
//  CompactWindowPreview.swift
//  Line
//
//  Live mock of the destination-frame preview for settings.
//

import Defaults
import SwiftUI

/// Compact window preview that mirrors runtime `PreviewView` chrome on a desktop stage.
struct CompactWindowPreview: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.previewBorderStyle) private var borderStyle
    @Default(.previewBackgroundEnableBlur) private var blurEnabled
    @Default(.previewBackgroundAccentOpacity) private var accentOpacity
    @Default(.previewGlassStyle) private var glassStyle
    @Default(.accentColorMode) private var accentColorMode

    var body: some View {
        SettingsMonitorBezel(aspectRatio: 16.0 / 10.0) {
            ZStack {
                desktopBackdrop
                previewCard
                    .padding(max(4, previewPadding * 0.42))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Window preview style")
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: borderStyle)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: glassStyle)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: blurEnabled)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: previewPadding)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: previewCornerRadius)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: previewBorderThickness)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: accentOpacity)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: accentColorMode)
    }

    private var usesGlass: Bool {
        blurEnabled && !reduceTransparency
    }

    private var usesAccentTint: Bool {
        accentColorMode.usesAccentTint
    }

    private var desktopBackdrop: some View {
        ZStack(alignment: .topLeading) {
            // Patterned backdrop so glass blur is visible in settings.
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.55 : 0.78),
                    Color(nsColor: .controlBackgroundColor).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if usesAccentTint {
                RadialGradient(
                    colors: [
                        accentColorController.color1.opacity(colorScheme == .dark ? 0.14 : 0.10),
                        Color.clear
                    ],
                    center: .init(x: 0.74, y: 0.26),
                    startRadius: 4,
                    endRadius: 130
                )
            }

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    }
                    .frame(width: w * 0.30, height: h * 0.38)
                    .offset(x: w * 0.05, y: h * 0.10)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.12 : 0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                    }
                    .frame(width: w * 0.26, height: h * 0.48)
                    .offset(x: w * 0.62, y: h * 0.20)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        usesAccentTint
                            ? accentColorController.color1.opacity(0.12)
                            : Color.secondary.opacity(0.10)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                usesAccentTint
                                    ? accentColorController.color1.opacity(0.20)
                                    : Color.primary.opacity(0.08),
                                lineWidth: 0.5
                            )
                    }
                    .frame(width: w * 0.20, height: h * 0.16)
                    .offset(x: w * 0.38, y: h * 0.64)
            }
        }
    }

    private var previewCard: some View {
        let shape = RoundedRectangle(
            cornerRadius: max(PreviewChrome.minimumCornerRadius, previewCornerRadius * 0.55),
            style: .continuous
        )
        let thickness = PreviewChrome.borderThickness(
            style: borderStyle,
            configured: previewBorderThickness,
            scale: 0.85
        )

        return DestinationPreviewChrome(
            shape: shape,
            usesGlass: usesGlass,
            glassStyle: glassStyle,
            borderStyle: borderStyle,
            borderThickness: thickness,
            accent: accentColorController.color1,
            secondaryAccent: accentColorController.color2,
            tintOpacity: accentOpacity,
            usesAccentTint: usesAccentTint,
            isShown: true
        )
    }
}
