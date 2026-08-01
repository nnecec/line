//
//  CompactGridPreview.swift
//  Line
//
//  Created by nnecec on 2026-07-08.
//  Compact grid layout preview for settings, aligned with runtime GridOverlayView.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    var body: some View {
        SettingsMonitorBezel(aspectRatio: aspectRatio) {
            GridPreviewSurface(
                template: template,
                accentColor: accentColor,
                cornerRadius: SettingsMonitorBezelMetrics.contentCornerRadius,
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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grid layout preview")
        .accessibilityValue(accessibilityValue)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: drawStyle)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: glassEnabled)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: glassStyle)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: lineThickness)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: cellCornerRadius)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectionGlow)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: overlayOpacity)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: outerCornerRadius)
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
    @Default(.accentColorMode) private var accentColorMode

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

    private var usesAccentTint: Bool {
        accentColorMode.usesAccentTint
    }

    private var strokeColor: Color {
        usesAccentTint ? accentColor : Color.white
    }

    private var effectiveOuterRadius: CGFloat {
        if showStyleChrome {
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

    private var effectiveOverlayOpacity: Double {
        min(1, max(0.16, overlayOpacity))
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
                .strokeBorder(.white.opacity(usesGlass ? 0.18 : 0.14), lineWidth: 0.5)
        }
        .overlay {
            if usesGlass {
                RoundedRectangle(cornerRadius: effectiveOuterRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.40),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.40)
                        ),
                        lineWidth: 0.7
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
                .glassEffect(backgroundGlassEffect, in: shape)
                .overlay {
                    shape.fill(backgroundScrim)
                }
        } else {
            shape
                .fill(Color.black.opacity(showStyleChrome ? max(0.45, effectiveOverlayOpacity) : 0.9))
        }
    }

    private var backgroundGlassEffect: Glass {
        let span = 1 - 0.16
        let t = span > 0 ? (effectiveOverlayOpacity - 0.16) / span : 0
        let tintStrength = 0.04 + t * 0.10

        switch glassStyle {
        case .clear:
            return .clear
        case .regular:
            return .regular.tint(Color.white.opacity(0.05 + tintStrength * 0.35))
        case .tinted:
            if usesAccentTint {
                return .regular.tint(accentColor.opacity(tintStrength * 0.55))
            }
            return .regular.tint(Color.white.opacity(0.05 + tintStrength * 0.30))
        }
    }

    private var backgroundScrim: Color {
        let span = 1 - 0.16
        let t = span > 0 ? (effectiveOverlayOpacity - 0.16) / span : 0
        let base = 0.015 + t * 0.06

        switch glassStyle {
        case .clear:
            return Color.black.opacity(base * 0.4)
        case .regular:
            return Color.black.opacity(base * 0.55)
        case .tinted:
            if usesAccentTint {
                return accentColor.opacity(base * 0.25)
            }
            return Color.black.opacity(base * 0.5)
        }
    }

    @ViewBuilder
    private func cellGrid(
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        gap: CGFloat
    ) -> some View {
        let fillOpacity = usesGlass ? 0.04 : 0.08
        let strokeOpacity = usesGlass ? 0.20 : 0.22
        let border = max(0.5, min(1.5, lineThickness * 0.75))

        ForEach(0 ..< template.rows, id: \.self) { row in
            ForEach(0 ..< template.columns, id: \.self) { column in
                let radius = min(effectiveCellRadius, min(cellWidth, cellHeight) / 3)
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

                shape
                    .fill(Color.white.opacity(fillOpacity))
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: border)
                    }
                    .frame(width: cellWidth, height: cellHeight)
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
        let stroke = Color.white.opacity(usesGlass ? 0.20 : 0.22)
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
        let glowOpacity = usesAccentTint
            ? (0.06 + glowAmount * 0.18)
            : (0.04 + glowAmount * 0.10)
        let specularStrength = usesGlass ? 0.40 : 0.28

        ZStack {
            if usesGlass {
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
                        center: .init(x: 0.5, y: 0.16),
                        startRadius: 0,
                        endRadius: max(width, height) * 0.55
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
                    lineWidth: max(0.75, min(1.5, lineThickness))
                )

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(specularStrength),
                            Color.white.opacity(specularStrength * 0.22),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.45)
                    ),
                    lineWidth: 0.7
                )

            if usesGlass {
                shape
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    .padding(1)
            }
        }
        .shadow(color: strokeColor.opacity(glowOpacity * 0.45), radius: 3, y: 1)
        .shadow(color: strokeColor.opacity(glowOpacity * 0.55), radius: 6 + glowAmount * 3, y: 3)
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
