//
//  PreviewChrome.swift
//  Line
//
//  Shared visual chrome for window destination preview and settings mocks.
//  Keeps runtime PreviewView and CompactWindowPreview on one material language.
//

import SwiftUI

/// Shared material / stroke / shadow treatment for destination-frame previews.
enum PreviewChrome {
    static let maxBorderThickness: CGFloat = 2.5
    static let hairlineThickness: CGFloat = 0.75
    static let minimumCornerRadius: CGFloat = 4

    // MARK: - Glass

    /// Liquid glass material. Accent modes only add a whisper of tint - never a solid wash.
    static func glassEffect(
        style: LiquidGlassStyle,
        accent: Color,
        tintOpacity: CGFloat,
        usesAccentTint: Bool
    ) -> Glass {
        switch style {
        case .clear:
            .clear
        case .regular:
            // Slight neutral body so blur reads clearly against the desktop.
            .regular.tint(Color.white.opacity(0.06))
        case .tinted:
            if usesAccentTint {
                // Cap tint so the frame stays glass, not a colored slab.
                .regular.tint(accent.opacity(min(0.10, max(0, tintOpacity))))
            } else {
                .regular.tint(Color.white.opacity(0.05))
            }
        }
    }

    /// Very light body wash over glass. Avoids opaque accent blocks.
    static func bodyFill(
        style: LiquidGlassStyle,
        accent: Color,
        secondaryAccent: Color,
        usesAccentTint: Bool
    ) -> LinearGradient {
        switch style {
        case .clear:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .regular:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            if usesAccentTint {
                LinearGradient(
                    colors: [
                        accent.opacity(0.05),
                        secondaryAccent.opacity(0.02),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.07),
                        Color.white.opacity(0.025)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Border

    static func borderThickness(
        style: PreviewBorderStyle,
        configured: CGFloat,
        scale: CGFloat = 1
    ) -> CGFloat {
        switch style {
        case .none:
            0
        case .hairline:
            hairlineThickness * scale
        case .accent, .gradient:
            min(maxBorderThickness, max(0, configured)) * scale
        }
    }

    /// Border treatment. Accent modes prefer a soft rim over a solid colored slab edge.
    static func borderStroke(
        style: PreviewBorderStyle,
        usesGlass: Bool,
        accent: Color,
        secondaryAccent: Color,
        usesAccentTint: Bool
    ) -> AnyShapeStyle {
        switch style {
        case .none:
            AnyShapeStyle(Color.clear)
        case .hairline:
            AnyShapeStyle(Color.white.opacity(usesGlass ? 0.22 : 0.28))
        case .accent:
            if usesAccentTint {
                AnyShapeStyle(accent.opacity(usesGlass ? 0.42 : 0.55))
            } else {
                AnyShapeStyle(Color.white.opacity(usesGlass ? 0.22 : 0.28))
            }
        case .gradient:
            if usesAccentTint {
                AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            accent.opacity(usesGlass ? 0.40 : 0.52),
                            Color.white.opacity(usesGlass ? 0.18 : 0.22),
                            secondaryAccent.opacity(usesGlass ? 0.28 : 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(usesGlass ? 0.28 : 0.34),
                            Color.white.opacity(usesGlass ? 0.10 : 0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    // MARK: - Specular / edge

    /// Top rim that sells liquid glass on destination frames.
    static func specularRim(
        style: LiquidGlassStyle,
        usesGlass: Bool
    ) -> LinearGradient {
        let peak: Double = {
            guard usesGlass else { return 0.14 }
            switch style {
            case .clear: return 0.38
            case .regular: return 0.48
            case .tinted: return 0.44
            }
        }()

        return LinearGradient(
            colors: [
                Color.white.opacity(peak),
                Color.white.opacity(peak * 0.32),
                Color.white.opacity(0)
            ],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.50)
        )
    }

    static func softEdgeOpacity(usesGlass: Bool) -> Double {
        usesGlass ? 0.08 : 0.12
    }
}

// MARK: - Destination frame chrome view

/// Renders the glass body + border + specular rim for a destination preview.
struct DestinationPreviewChrome<ShapeType: InsettableShape>: View {
    let shape: ShapeType
    let usesGlass: Bool
    let glassStyle: LiquidGlassStyle
    let borderStyle: PreviewBorderStyle
    let borderThickness: CGFloat
    let accent: Color
    let secondaryAccent: Color
    let tintOpacity: CGFloat
    var usesAccentTint: Bool = true
    var isShown: Bool = true

    var body: some View {
        ZStack {
            surface

            if borderStyle == .none {
                shape
                    .strokeBorder(
                        Color.white.opacity(PreviewChrome.softEdgeOpacity(usesGlass: usesGlass)),
                        lineWidth: 0.5
                    )
            }

            if usesGlass {
                shape
                    .strokeBorder(
                        PreviewChrome.specularRim(style: glassStyle, usesGlass: usesGlass),
                        lineWidth: 1.0
                    )
            }

            if borderThickness > 0 {
                shape
                    .strokeBorder(
                        PreviewChrome.borderStroke(
                            style: borderStyle,
                            usesGlass: usesGlass,
                            accent: accent,
                            secondaryAccent: secondaryAccent,
                            usesAccentTint: usesAccentTint
                        ),
                        lineWidth: borderThickness
                    )
            }
        }
        .modifier(
            PreviewChromeShadowModifier(
                isShown: isShown,
                usesGlass: usesGlass,
                accent: usesAccentTint ? accent : Color.black
            )
        )
    }

    @ViewBuilder
    private var surface: some View {
        if usesGlass {
            Color.clear
                .glassEffect(
                    PreviewChrome.glassEffect(
                        style: glassStyle,
                        accent: accent,
                        tintOpacity: tintOpacity,
                        usesAccentTint: usesAccentTint
                    ),
                    in: shape
                )
                .overlay {
                    shape.fill(
                        PreviewChrome.bodyFill(
                            style: glassStyle,
                            accent: accent,
                            secondaryAccent: secondaryAccent,
                            usesAccentTint: usesAccentTint
                        )
                    )
                }
        } else {
            shape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))
        }
    }
}

private struct PreviewChromeShadowModifier: ViewModifier {
    let isShown: Bool
    let usesGlass: Bool
    let accent: Color

    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(isShown ? 0.06 : 0),
                radius: 2,
                y: 1
            )
            .shadow(
                color: accent.opacity(isShown ? (usesGlass ? 0.08 : 0.05) : 0),
                radius: 14,
                y: 6
            )
            .shadow(
                color: .black.opacity(isShown ? 0.16 : 0),
                radius: 28,
                y: 14
            )
    }
}

// MARK: - Settings live preview stage

/// Shared Displays-style stage that hosts compact grid / window previews.
struct SettingsLivePreviewStage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(stageFill)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.02),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 220
                            )
                        )

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(stageStroke, lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.05), radius: 14, y: 5)
            }
    }

    private var stageFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.55 : 0.78),
                Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.28 : 0.48)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var stageStroke: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09),
                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview frame (settings mocks)

/// Geometry tokens for the settings preview rectangle.
enum SettingsMonitorBezelMetrics {
    static let bezelRadius: CGFloat = 12
    static let bezelPadding: CGFloat = 6
    static var contentCornerRadius: CGFloat { bezelRadius - bezelPadding }
}

/// Rounded rectangular stage for compact previews in settings (no monitor stand).
struct SettingsMonitorBezel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var aspectRatio: CGFloat = 16.0 / 10.0
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SettingsMonitorBezelMetrics.bezelRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: SettingsMonitorBezelMetrics.bezelRadius, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.11),
                            lineWidth: 0.75
                        )
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 3, y: 1)

            content()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: SettingsMonitorBezelMetrics.contentCornerRadius,
                        style: .continuous
                    )
                )
                .padding(SettingsMonitorBezelMetrics.bezelPadding)
        }
        .aspectRatio(max(1.25, min(2.4, aspectRatio)), contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}
