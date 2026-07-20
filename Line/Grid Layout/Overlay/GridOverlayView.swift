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

    private var usesGlass: Bool {
        blurEnabled && !reduceTransparency
    }

    private var effectiveAccent: Color {
        followsAppAccent ? accentColorController.color1 : accentColor
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
        return 0.06 + t * 0.22
    }

    private var glassScrimOpacity: Double {
        switch glassStyle {
        case .clear:
            return 0.02 + glassNormalizedOpacity * 0.06
        case .regular:
            return 0.04 + glassNormalizedOpacity * 0.14
        case .tinted:
            return 0.03 + glassNormalizedOpacity * 0.10
        }
    }

    private var glassNormalizedOpacity: Double {
        let span = 1 - gridOverlayMinimumOpacity
        guard span > 0 else { return 0 }
        return (effectiveOverlayOpacity - gridOverlayMinimumOpacity) / span
    }

    /// Outer radius stays concentric with cell radius when cells are large.
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

        ZStack {
            // Background glass (and optionally the selection glass) share one container
            // so the system can morph material between them.
            GlassEffectContainer(spacing: max(8, template.gap)) {
                backgroundView(in: outerShape)

                if usesGlass, let region = viewModel.selectedRegion {
                    selectionGlass(for: region)
                }
            }

            gridContentView

            if let region = viewModel.selectedRegion {
                highlightChrome(for: region)
            }
        }
        .frame(
            width: geometry.displayBounds.width,
            height: geometry.displayBounds.height
        )
        .clipShape(outerShape)
        .overlay {
            ZStack {
                outerShape
                    .strokeBorder(Color.white.opacity(usesGlass ? 0.14 : 0.22), lineWidth: 1)

                outerShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(usesGlass ? 0.32 : 0.18),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.35)
                        ),
                        lineWidth: 0.75
                    )
            }
        }
        .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
        .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
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
            .regular.tint(.black.opacity(glassTintStrength * 0.85))
        case .tinted:
            .regular.tint(effectiveAccent.opacity(glassTintStrength * 0.7))
        }
    }

    private var backgroundScrim: Color {
        switch glassStyle {
        case .clear:
            Color.black.opacity(glassScrimOpacity * 0.5)
        case .regular:
            Color.black.opacity(glassScrimOpacity)
        case .tinted:
            effectiveAccent.opacity(glassScrimOpacity * 0.45)
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
            let fillOpacity = usesGlass ? 0.05 : 0.08
            let strokeOpacity = usesGlass ? 0.18 : 0.22

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
            let stroke = Color.white.opacity(usesGlass ? 0.18 : 0.22)
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

    /// Soft glass body for the selection, living inside GlassEffectContainer for morphing.
    @ViewBuilder
    private func selectionGlass(for region: GridRegion) -> some View {
        let localRect = geometry.localRect(for: region)
        let radius = min(cornerRadius, min(localRect.width, localRect.height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Color.clear
            .frame(width: localRect.width, height: localRect.height)
            .glassEffect(
                .regular.tint(effectiveAccent.opacity(0.22 + glowAmount * 0.12)),
                in: shape
            )
            .position(x: localRect.midX, y: localRect.midY)
            .animation(selectionAnimation, value: region)
    }

    /// Crisp fill / stroke / specular drawn above the glass layer.
    @ViewBuilder
    private func highlightChrome(for region: GridRegion) -> some View {
        let localRect = geometry.localRect(for: region)
        let radius = min(cornerRadius, min(localRect.width, localRect.height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fillOpacity = usesGlass ? 0.16 : 0.34
        let strokeWidth = max(1.5, lineThickness + 0.5)
        let glowOpacity = 0.12 + glowAmount * 0.28

        shape
            .fill(
                LinearGradient(
                    colors: [
                        effectiveAccent.opacity(fillOpacity + 0.06),
                        effectiveAccent.opacity(fillOpacity)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                effectiveAccent.opacity(0.98),
                                effectiveAccent.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: strokeWidth
                    )
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.4)
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: effectiveAccent.opacity(glowOpacity * 0.7), radius: 6, y: 2)
            .shadow(color: effectiveAccent.opacity(glowOpacity), radius: 14 + glowAmount * 8, y: 6)
            .frame(width: localRect.width, height: localRect.height)
            .position(x: localRect.midX, y: localRect.midY)
            .animation(selectionAnimation, value: region)
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
