//
//  CompactGridPreview.swift
//  Line
//
//  Created by nnecec on 2026-07-08.
//  Simplified, elegant grid layout preview for settings.
//

import SwiftUI

/// A compact display mockup that keeps the grid inside a bounded screen area.
@available(macOS 15.0, *)
struct CompactGridPreview: View {
    let template: GridTemplate
    let accentColor: Color
    let aspectRatio: CGFloat

    init(
        template: GridTemplate,
        accentColor: Color,
        aspectRatio: CGFloat = 16.0 / 10.0
    ) {
        self.template = template
        self.accentColor = accentColor
        self.aspectRatio = aspectRatio
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
                    cornerRadius: Self.surfaceRadius
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
    let template: GridTemplate
    let accentColor: Color
    let cornerRadius: CGFloat

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
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.9))

                ForEach(0 ..< template.rows, id: \.self) { row in
                    ForEach(0 ..< template.columns, id: \.self) { column in
                        gridCell(width: cellWidth, height: cellHeight)
                            .offset(
                                x: CGFloat(column) * (cellWidth + gap),
                                y: CGFloat(row) * (cellHeight + gap)
                            )
                    }
                }

                hoverHighlight(
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    gap: gap
                )
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
    }

    private func gridCell(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: min(2, min(width, height) / 3), style: .continuous)
            .fill(accentColor.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: min(2, min(width, height) / 3), style: .continuous)
                    .strokeBorder(accentColor.opacity(0.42), lineWidth: 0.75)
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
        let radius = min(4, min(width, height) / 4)

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(accentColor.opacity(0.24))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.9), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
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
