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
private let gridOverlayCornerRadius: CGFloat = 10

/// SwiftUI view that renders the grid overlay with background, grid lines, and selection highlight.
struct GridOverlayView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var viewModel: GridOverlayViewModel

    let geometry: GridGeometry
    let template: GridTemplate

    @Default(.gridFollowsAppAccentColor) private var followsAppAccent
    @Default(.gridOverlayAccentColor) private var accentColor
    @Default(.gridOverlayOpacity) private var overlayOpacity
    @Default(.gridLineThickness) private var lineThickness
    @Default(.gridCellCornerRadius) private var cornerRadius
    @Default(.gridOverlayBlurEnabled) private var blurEnabled

    var body: some View {
        ZStack {
            // Background with glass effect container
            GlassEffectContainer(spacing: template.gap) {
                backgroundView
            }

            // Grid cells - OUTSIDE the glass effect container
            gridCellsView

            // Selected region highlight - OUTSIDE the glass effect container
            if let region = viewModel.selectedRegion {
                highlightView(for: region)
            }
        }
        .frame(
            width: geometry.displayBounds.width,
            height: geometry.displayBounds.height
        )
        .clipShape(RoundedRectangle(cornerRadius: gridOverlayCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: gridOverlayCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    // MARK: - Background

    private var effectiveOverlayOpacity: Double {
        min(1, max(gridOverlayMinimumOpacity, overlayOpacity))
    }

    @ViewBuilder
    private var backgroundView: some View {
        let shape = RoundedRectangle(cornerRadius: gridOverlayCornerRadius, style: .continuous)

        if blurEnabled, !reduceTransparency {
            Color.clear
                .glassEffect(
                    .regular.tint(.black.opacity(effectiveOverlayOpacity * 0.16)),
                    in: shape
                )
                .overlay {
                    shape.fill(Color.black.opacity(effectiveOverlayOpacity * 0.08))
                }
        } else {
            shape.fill(Color.black.opacity(effectiveOverlayOpacity))
        }
    }

    // MARK: - Grid Cells

    private var gridCellsView: some View {
        GeometryReader { proxy in
            let cellWidth = (proxy.size.width - template.gap * CGFloat(template.columns - 1)) / CGFloat(template.columns)
            let cellHeight = (proxy.size.height - template.gap * CGFloat(template.rows - 1)) / CGFloat(template.rows)

            ZStack {
                // Vertical lines
                ForEach(0 ..< template.columns + 1, id: \.self) { col in
                    let x = CGFloat(col) * (cellWidth + template.gap) - (col == 0 ? 0 : template.gap / 2)
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: lineThickness)
                        .position(x: x, y: proxy.size.height / 2)
                        .frame(height: proxy.size.height)
                }

                // Horizontal lines
                ForEach(0 ..< template.rows + 1, id: \.self) { row in
                    let y = CGFloat(row) * (cellHeight + template.gap) - (row == 0 ? 0 : template.gap / 2)
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: lineThickness)
                        .position(x: proxy.size.width / 2, y: y)
                        .frame(width: proxy.size.width)
                }
            }
        }
    }

    // MARK: - Highlight

    @ViewBuilder
    private func highlightView(for region: GridRegion) -> some View {
        let localRect = geometry.localRect(for: region)
        let effectiveAccent = followsAppAccent ? Color.accentColor : accentColor
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        shape
            .fill(effectiveAccent.opacity(blurEnabled && !reduceTransparency ? 0.28 : 0.32))
            .overlay {
                shape.strokeBorder(effectiveAccent.opacity(0.95), lineWidth: max(2, lineThickness + 1))
            }
            .shadow(color: effectiveAccent.opacity(0.28), radius: 8, y: 3)
            .frame(width: localRect.width, height: localRect.height)
            .position(x: localRect.midX, y: localRect.midY)
            .animation(.easeOut(duration: 0.1), value: region)
    }
}
