//
//  GridOverlayView.swift
//  Line
//
//  SwiftUI view for rendering the grid overlay.
//  Created by nnecec on 2024-12-30.
//

import Defaults
import SwiftUI

private let gridOverlayMinimumOpacity = 0.16

/// SwiftUI view that renders the grid overlay with background, cells/lines, and selection highlight.
struct GridOverlayView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var viewModel: GridOverlayViewModel
    @ObservedObject private var accentColorController: AccentColorController = .shared

    let geometry: GridGeometry
    let template: GridTemplate

    @Default(.gridFollowsAppAccentColor) private var followsAppAccent
    @Default(.gridOverlayAccentColor) private var accentColor
    @Default(.gridOverlayOpacity) private var overlayOpacity
    @Default(.gridLineThickness) private var lineThickness
    @Default(.gridCellCornerRadius) private var cornerRadius
    @Default(.gridOverlayBlurEnabled) private var blurEnabled
    @Default(.gridGlassStyle) private var glassStyle
    @Default(.gridOverlayDrawStyle) private var drawStyle
    @Default(.gridSelectionGlow) private var selectionGlow
    @Default(.gridOverlayOuterCornerRadius) private var outerCornerRadiusSetting
    @Default(.accentColorMode) private var accentColorMode

    private var usesGlass: Bool {
        blurEnabled && !reduceTransparency
    }

    private var usesAccentTint: Bool {
        accentColorMode.usesAccentTint
    }

    private var effectiveAccent: Color {
        if !usesAccentTint {
            return Color.white
        }
        return followsAppAccent ? accentColorController.color1 : accentColor
    }

    private var effectiveOverlayOpacity: Double {
        min(1, max(gridOverlayMinimumOpacity, overlayOpacity))
    }

    /// Remap the opacity slider into a range that is visible on glass material.
    private var glassTintStrength: Double {
        let span = 1 - gridOverlayMinimumOpacity
        let t = span > 0
            ? (effectiveOverlayOpacity - gridOverlayMinimumOpacity) / span
            : 0
        // Keep glass readable: low base tint, limited range.
        return 0.04 + t * 0.10
    }

    private var glassScrimOpacity: Double {
        switch glassStyle {
        case .clear:
            return 0.015 + glassNormalizedOpacity * 0.04
        case .regular:
            return 0.025 + glassNormalizedOpacity * 0.07
        case .tinted:
            return usesAccentTint
                ? 0.02 + glassNormalizedOpacity * 0.05
                : 0.02 + glassNormalizedOpacity * 0.06
        }
    }

    private var glassNormalizedOpacity: Double {
        let span = 1 - gridOverlayMinimumOpacity
        guard span > 0 else { return 0 }
        return (effectiveOverlayOpacity - gridOverlayMinimumOpacity) / span
    }

    private var outerCornerRadius: CGFloat {
        let configured = max(0, outerCornerRadiusSetting)
        return max(configured, cornerRadius + 6)
    }

    private var selectionAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.05)
            : .spring(response: 0.2, dampingFraction: 0.86)
    }

    private var glowAmount: Double {
        min(1, max(0, selectionGlow))
    }

    var body: some View {
        let outerShape = RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
        let overlaySize = geometry.displayBounds.size

        ZStack(alignment: .topLeading) {
            if usesGlass {
                GlassEffectContainer(spacing: max(8, template.gap)) {
                    ZStack(alignment: .topLeading) {
                        backgroundView(in: outerShape)
                            .frame(width: overlaySize.width, height: overlaySize.height)

                        if let region = viewModel.selectedRegion {
                            selectionGlass(for: region)
                        }
                    }
                    .frame(width: overlaySize.width, height: overlaySize.height, alignment: .topLeading)
                }
            } else {
                backgroundView(in: outerShape)
            }

            gridContentView

            if let region = viewModel.selectedRegion {
                highlightChrome(for: region)
            }
        }
        .frame(
            width: overlaySize.width,
            height: overlaySize.height
        )
        .clipShape(outerShape)
        .overlay {
            ZStack {
                outerShape
                    .strokeBorder(Color.white.opacity(usesGlass ? 0.18 : 0.22), lineWidth: 1)

                outerShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(usesGlass ? 0.42 : 0.18),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.40)
                        ),
                        lineWidth: 0.85
                    )
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .shadow(color: .black.opacity(0.18), radius: 28, y: 12)
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundView(in shape: RoundedRectangle) -> some View {
        if usesGlass {
            Color.clear
                .glassEffect(backgroundGlassEffect, in: shape)
                .overlay {
                    shape.fill(backgroundScrim)
                }
        } else {
            shape.fill(Color.black.opacity(effectiveOverlayOpacity))
        }
    }

    private var backgroundGlassEffect: Glass {
        switch glassStyle {
        case .clear:
            .clear
        case .regular:
            // Neutral frost - lets desktop texture show through.
            .regular.tint(Color.white.opacity(0.05 + glassTintStrength * 0.35))
        case .tinted:
            if usesAccentTint {
                .regular.tint(effectiveAccent.opacity(glassTintStrength * 0.55))
            } else {
                .regular.tint(Color.white.opacity(0.05 + glassTintStrength * 0.30))
            }
        }
    }

    private var backgroundScrim: Color {
        switch glassStyle {
        case .clear:
            Color.black.opacity(glassScrimOpacity * 0.4)
        case .regular:
            Color.black.opacity(glassScrimOpacity * 0.55)
        case .tinted:
            if usesAccentTint {
                effectiveAccent.opacity(glassScrimOpacity * 0.25)
            } else {
                Color.black.opacity(glassScrimOpacity * 0.5)
            }
        }
    }

    // MARK: - Grid Content

    @ViewBuilder
    private var gridContentView: some View {
        switch drawStyle {
        case .cells:
            gridCellsView
        case .lines:
            gridLinesView
        }
    }

    private var gridCellsView: some View {
        GeometryReader { proxy in
            let gap = template.gap
            let columns = max(1, template.columns)
            let rows = max(1, template.rows)
            let cellWidth = cellLength(
                availableLength: proxy.size.width,
                count: columns,
                gap: gap
            )
            let cellHeight = cellLength(
                availableLength: proxy.size.height,
                count: rows,
                gap: gap
            )
            let cellShape = RoundedRectangle(
                cornerRadius: min(cornerRadius, min(cellWidth, cellHeight) / 2),
                style: .continuous
            )
            let borderWidth = max(0.5, lineThickness)
            let fillOpacity = usesGlass ? 0.04 : 0.08
            let strokeOpacity = usesGlass ? 0.20 : 0.22

            ZStack(alignment: .topLeading) {
                ForEach(0 ..< rows, id: \.self) { row in
                    ForEach(0 ..< columns, id: \.self) { column in
                        cellShape
                            .fill(Color.white.opacity(fillOpacity))
                            .overlay {
                                cellShape
                                    .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: borderWidth)
                            }
                            .frame(width: cellWidth, height: cellHeight)
                            .offset(
                                x: CGFloat(column) * (cellWidth + gap),
                                y: CGFloat(row) * (cellHeight + gap)
                            )
                    }
                }
            }
        }
    }

    private var gridLinesView: some View {
        GeometryReader { proxy in
            let gap = template.gap
            let columns = max(1, template.columns)
            let rows = max(1, template.rows)
            let cellWidth = cellLength(
                availableLength: proxy.size.width,
                count: columns,
                gap: gap
            )
            let cellHeight = cellLength(
                availableLength: proxy.size.height,
                count: rows,
                gap: gap
            )
            let stroke = Color.white.opacity(usesGlass ? 0.20 : 0.22)
            let thickness = max(0.5, lineThickness)

            ZStack {
                ForEach(0 ..< columns + 1, id: \.self) { col in
                    let x = CGFloat(col) * (cellWidth + gap) - (col == 0 ? 0 : gap / 2)
                    Rectangle()
                        .fill(stroke)
                        .frame(width: thickness, height: proxy.size.height)
                        .position(x: x, y: proxy.size.height / 2)
                }

                ForEach(0 ..< rows + 1, id: \.self) { row in
                    let y = CGFloat(row) * (cellHeight + gap) - (row == 0 ? 0 : gap / 2)
                    Rectangle()
                        .fill(stroke)
                        .frame(width: proxy.size.width, height: thickness)
                        .position(x: proxy.size.width / 2, y: y)
                }
            }
        }
    }

    // MARK: - Selection

    /// Soft glass body for the selection. Accent modes use a whisper of tint only.
    @ViewBuilder
    private func selectionGlass(for region: GridRegion) -> some View {
        let localRect = geometry.localRect(for: region)
        let radius = min(cornerRadius, min(localRect.width, localRect.height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let tint: Color = {
            if usesAccentTint {
                return effectiveAccent.opacity(0.08 + glowAmount * 0.06)
            }
            return Color.white.opacity(0.08 + glowAmount * 0.05)
        }()

        Color.clear
            .frame(width: localRect.width, height: localRect.height)
            .glassEffect(.regular.tint(tint), in: shape)
            .offset(x: localRect.minX, y: localRect.minY)
            .animation(selectionAnimation, value: region)
            .allowsHitTesting(false)
    }

    /// Edge + specular only when glass is on - no solid accent slab.
    @ViewBuilder
    private func highlightChrome(for region: GridRegion) -> some View {
        let localRect = geometry.localRect(for: region)
        let radius = min(cornerRadius, min(localRect.width, localRect.height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let strokeWidth = max(1.2, lineThickness + 0.35)
        let glowOpacity = usesAccentTint
            ? (0.06 + glowAmount * 0.18)
            : (0.04 + glowAmount * 0.10)
        let specularStrength = usesGlass ? 0.40 : 0.28
        let strokeColor: Color = usesAccentTint ? effectiveAccent : Color.white

        ZStack {
            if usesGlass {
                // Very light inner wash - never a solid block.
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                strokeColor.opacity(usesAccentTint ? 0.05 : 0.06),
                                strokeColor.opacity(0.015)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                strokeColor.opacity(0.28),
                                strokeColor.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(specularStrength * 0.14),
                            Color.clear
                        ],
                        center: .init(x: 0.5, y: 0.18),
                        startRadius: 0,
                        endRadius: max(localRect.width, localRect.height) * 0.55
                    )
                )
                .blendMode(.plusLighter)

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            strokeColor.opacity(usesAccentTint ? 0.70 : 0.55),
                            strokeColor.opacity(usesAccentTint ? 0.38 : 0.28),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: strokeWidth
                )

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(specularStrength),
                            Color.white.opacity(specularStrength * 0.22),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.48)
                    ),
                    lineWidth: 0.9
                )

            if usesGlass {
                shape
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    .padding(1)
            }
        }
        .shadow(color: strokeColor.opacity(glowOpacity * 0.45), radius: 4, y: 1)
        .shadow(color: strokeColor.opacity(glowOpacity * 0.55), radius: 10 + glowAmount * 4, y: 4)
        .frame(width: localRect.width, height: localRect.height, alignment: .topLeading)
        .offset(x: localRect.minX, y: localRect.minY)
        .animation(selectionAnimation, value: region)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func cellLength(
        availableLength: CGFloat,
        count: Int,
        gap: CGFloat
    ) -> CGFloat {
        guard count > 0 else { return 0 }
        let totalGap = CGFloat(max(0, count - 1)) * gap
        return max(0, (availableLength - totalGap) / CGFloat(count))
    }
}
