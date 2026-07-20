//
//  CompactGridPreview.swift
//  Line
//
//  Created by nnecec on 2026-07-08.
//  Simplified, elegant grid layout preview for settings.
//

import Defaults
import SwiftUI

/// A compact display mockup that keeps the grid inside a bounded screen area.
@available(macOS 15.0, *)
struct CompactGridPreview: View {
    let template: GridTemplate
    let accentColor: Color
    let aspectRatio: CGFloat
    var showStyleChrome: Bool = false

    @Default(.gridOverlayDrawStyle) private var drawStyle
    @Default(.gridLineThickness) private var lineThickness
    @Default(.gridCellCornerRadius) private var cellCornerRadius
    @Default(.gridOverlayOpacity) private var overlayOpacity
    @Default(.gridOverlayBlurEnabled) private var glassEnabled
    @Default(.gridGlassStyle) private var glassStyle
    @Default(.gridSelectionGlow) private var selectionGlow
    @Default(.gridOverlayOuterCornerRadius) private var outerCornerRadius

    init(
        template: GridTemplate,
        accentColor: Color,
        aspectRatio: CGFloat = 16.0 / 10.0,
        showStyleChrome: Bool = false
    ) {
        self.template = template
        self.accentColor = accentColor
        self.aspectRatio = aspectRatio
        self.showStyleChrome = showStyleChrome
    }

    /// Outer bezel radius; inner surface uses concentric radius (outer − padding).
    private static let bezelRadius: CGFloat = 11
    private static let bezelPadding: CGFloat = 7
    private static var surfaceRadius: CGFloat { bezelRadius - bezelPadding }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: Self.bezelRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.bezelRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

                GridPreviewSurface(
                    template: template,
                    accentColor: accentColor,
                    cornerRadius: Self.surfaceRadius,
                    drawStyle: drawStyle,
                    lineThickness: lineThickness,
                    cellCornerRadius: cellCornerRadius,
                    overlayOpacity: overlayOpacity,
                    glassEnabled: glassEnabled,
                    glassStyle: glassStyle,
                    selectionGlow: selectionGlow,
                    outerCornerRadius: outerCornerRadius,
                    showStyleChrome: showStyleChrome
                )
                .padding(Self.bezelPadding)
            }
            .aspectRatio(monitorAspectRatio, contentMode: .fit)
            .overlay(alignment: .top) {
                // A small camera detail gives the bezel a familiar display silhouette.
                Circle()
                    .fill(.primary.opacity(0.22))
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
        .accessibilityLabel("Grid layout preview")
        .accessibilityValue(accessibilityValue)
        .animation(.snappy(duration: 0.2), value: drawStyle)
        .animation(.snappy(duration: 0.2), value: glassEnabled)
        .animation(.snappy(duration: 0.2), value: glassStyle)
        .animation(.snappy(duration: 0.2), value: lineThickness)
        .animation(.snappy(duration: 0.2), value: cellCornerRadius)
        .animation(.snappy(duration: 0.2), value: selectionGlow)
    }

    private var monitorAspectRatio: CGFloat {
        max(1.25, min(2.4, aspectRatio))
    }

    private var accessibilityValue: String {
        let format = String(
            localized: "%lld columns, %lld rows, %lld pixel gap",
            comment: "Accessibility value for the grid preview"
        )
        return String.localizedStringWithFormat(
            format,
            template.columns,
            template.rows,
            Int(template.gap.rounded())
        )
    }
}

@available(macOS 15.0, *)
private struct GridPreviewSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let template: GridTemplate
    let accentColor: Color
    let cornerRadius: CGFloat
    let drawStyle: GridOverlayDrawStyle
    let lineThickness: CGFloat
    let cellCornerRadius: CGFloat
    let overlayOpacity: Double
    let glassEnabled: Bool
    let glassStyle: LiquidGlassStyle
    let selectionGlow: Double
    let outerCornerRadius: CGFloat
    let showStyleChrome: Bool

    private var usesGlass: Bool {
        showStyleChrome && glassEnabled && !reduceTransparency
    }

    private var effectiveOuterRadius: CGFloat {
        if showStyleChrome {
            // Scale the full-screen outer radius into this compact surface.
            return min(cornerRadius, max(3, outerCornerRadius * 0.35))
        }
        return cornerRadius
    }

    private var effectiveCellRadius: CGFloat {
        if showStyleChrome {
            return max(1, cellCornerRadius * 0.4)
        }
        return 2
    }

    private var glowAmount: Double {
        min(1, max(0, selectionGlow))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gap = scaledGap(for: size)
            let cellWidth = cellLength(
                availableLength: size.width,
                count: template.columns,
                gap: gap
            )
            let cellHeight = cellLength(
                availableLength: size.height,
                count: template.rows,
                gap: gap
            )

            ZStack(alignment: .topLeading) {
                backgroundLayer(in: size)

                switch drawStyle {
                case .cells:
                    cellGrid(
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        gap: gap
                    )
                case .lines:
                    lineGrid(
                        size: size,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        gap: gap
                    )
                }

                hoverHighlight(
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    gap: gap
                )
            }
        }
        .clipShape(.rect(cornerRadius: effectiveOuterRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: effectiveOuterRadius, style: .continuous)
                .strokeBorder(.white.opacity(usesGlass ? 0.18 : 0.16), lineWidth: 0.5)
        }
        .overlay {
            if usesGlass {
                RoundedRectangle(cornerRadius: effectiveOuterRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.4)
                        ),
                        lineWidth: 0.6
                    )
            }
        }
    }

    @ViewBuilder
    private func backgroundLayer(in size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: effectiveOuterRadius, style: .continuous)

        if usesGlass {
            Color.clear
                .frame(width: size.width, height: size.height)
                .glassEffect(previewGlassEffect, in: shape)
                .overlay {
                    shape.fill(backgroundScrim)
                }
        } else {
            shape
                .fill(Color.black.opacity(showStyleChrome ? max(0.55, overlayOpacity) : 0.9))
        }
    }

    private var previewGlassEffect: Glass {
        switch glassStyle {
        case .clear:
            .clear
        case .regular:
            .regular.tint(.black.opacity(0.12))
        case .tinted:
            .regular.tint(accentColor.opacity(0.14))
        }
    }

    private var backgroundScrim: Color {
        switch glassStyle {
        case .clear:
            Color.black.opacity(0.08)
        case .regular:
            Color.black.opacity(0.16)
        case .tinted:
            accentColor.opacity(0.10)
        }
    }

    @ViewBuilder
    private func cellGrid(
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        gap: CGFloat
    ) -> some View {
        ForEach(0 ..< template.rows, id: \.self) { row in
            ForEach(0 ..< template.columns, id: \.self) { column in
                gridCell(width: cellWidth, height: cellHeight)
                    .offset(
                        x: CGFloat(column) * (cellWidth + gap),
                        y: CGFloat(row) * (cellHeight + gap)
                    )
            }
        }
    }

    @ViewBuilder
    private func lineGrid(
        size: CGSize,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        gap: CGFloat
    ) -> some View {
        let stroke = Color.white.opacity(0.22)
        let thickness = max(0.5, min(2, lineThickness * 0.75))

        ForEach(0 ..< template.columns + 1, id: \.self) { col in
            let x = CGFloat(col) * (cellWidth + gap) - (col == 0 ? 0 : gap / 2)
            Rectangle()
                .fill(stroke)
                .frame(width: thickness, height: size.height)
                .position(x: x, y: size.height / 2)
        }

        ForEach(0 ..< template.rows + 1, id: \.self) { row in
            let y = CGFloat(row) * (cellHeight + gap) - (row == 0 ? 0 : gap / 2)
            Rectangle()
                .fill(stroke)
                .frame(width: size.width, height: thickness)
                .position(x: size.width / 2, y: y)
        }
    }

    private func gridCell(width: CGFloat, height: CGFloat) -> some View {
        let radius = min(effectiveCellRadius, min(width, height) / 3)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let border = max(0.5, min(1.5, lineThickness * 0.75))

        return shape
            .fill(accentColor.opacity(0.08))
            .overlay {
                shape
                    .strokeBorder(accentColor.opacity(0.42), lineWidth: border)
            }
            .frame(width: width, height: height)
    }

    @ViewBuilder
    private func hoverHighlight(
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        gap: CGFloat
    ) -> some View {
        let selectedColumns = min(2, template.columns)
        let selectedRows = min(2, template.rows)
        let startColumn = max(0, template.columns - selectedColumns)
        let startRow = max(0, template.rows - selectedRows)
        let width = CGFloat(selectedColumns) * cellWidth + CGFloat(max(0, selectedColumns - 1)) * gap
        let height = CGFloat(selectedRows) * cellHeight + CGFloat(max(0, selectedRows - 1)) * gap
        let radius = min(
            max(2, effectiveCellRadius),
            min(width, height) / 4
        )
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fillOpacity = 0.20 + glowAmount * 0.10
        let glowOpacity = 0.12 + glowAmount * 0.28

        shape
            .fill(accentColor.opacity(fillOpacity))
            .overlay {
                shape
                    .strokeBorder(accentColor.opacity(0.9), lineWidth: max(0.75, min(1.5, lineThickness)))
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.45)
                        ),
                        lineWidth: 0.6
                    )
            }
            .shadow(color: accentColor.opacity(glowOpacity * 0.6), radius: 4 + glowAmount * 4, y: 2)
            .frame(width: width, height: height)
            .offset(
                x: CGFloat(startColumn) * (cellWidth + gap),
                y: CGFloat(startRow) * (cellHeight + gap)
            )
    }

    private func scaledGap(for size: CGSize) -> CGFloat {
        let longestSide = max(size.width, size.height)
        return min(7, max(0, template.gap * longestSide / 700))
    }

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
