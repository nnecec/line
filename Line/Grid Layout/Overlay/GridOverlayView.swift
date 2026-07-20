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
private let gridOverlayCornerRadius: CGFloat = 12

/// SwiftUI view that renders the grid overlay with background, cells, and selection highlight.
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
    private var glassTintOpacity: Double {
        let span = 1 - gridOverlayMinimumOpacity
        let t = span > 0
            ? (effectiveOverlayOpacity - gridOverlayMinimumOpacity) / span
            : 0
        return 0.06 + t * 0.22
    }

    private var glassScrimOpacity: Double {
        let span = 1 - gridOverlayMinimumOpacity
        let t = span > 0
            ? (effectiveOverlayOpacity - gridOverlayMinimumOpacity) / span
            : 0
        return 0.04 + t * 0.14
    }

    /// Outer radius stays concentric with cell radius when cells are large.
    private var outerCornerRadius: CGFloat {
        max(gridOverlayCornerRadius, cornerRadius + 6)
    }

    private var selectionAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.05)
            : .spring(response: 0.2, dampingFraction: 0.86)
    }

    var body: some View {
        let outerShape = RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)

        ZStack {
            backgroundView(in: outerShape)

            gridCellsView

            if let region = viewModel.selectedRegion {
                highlightView(for: region)
            }
        }
        .frame(
            width: geometry.displayBounds.width,
            height: geometry.displayBounds.height
        )
        .clipShape(outerShape)
        .overlay {
            // Adaptive hairline + top specular rim (liquid-glass edge language).
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
                .glassEffect(
                    .regular.tint(.black.opacity(glassTintOpacity)),
                    in: shape
                )
                .overlay {
                    shape.fill(Color.black.opacity(glassScrimOpacity))
                }
        } else {
            shape.fill(Color.black.opacity(effectiveOverlayOpacity))
        }
    }

    // MARK: - Grid Cells

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

    // MARK: - Highlight

    @ViewBuilder
    private func highlightView(for region: GridRegion) -> some View {
        let localRect = geometry.localRect(for: region)
        let radius = min(cornerRadius, min(localRect.width, localRect.height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fillOpacity = usesGlass ? 0.26 : 0.34
        let strokeWidth = max(1.5, lineThickness + 0.5)

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
                // Specular rim on the selection block.
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
            .shadow(color: effectiveAccent.opacity(0.22), radius: 6, y: 2)
            .shadow(color: effectiveAccent.opacity(0.18), radius: 14, y: 6)
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
