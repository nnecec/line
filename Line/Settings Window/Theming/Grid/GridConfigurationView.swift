//
//  GridConfigurationView.swift
//  Line
//
//  Created by nnecec on 2024-12-30.
//  Grid layout settings view.
//

import AppKit
import Defaults
import SwiftUI

private let gridOverlayMinimumOpacity = 0.16

@available(macOS 15.0, *)
struct GridConfigurationView: View {
    @Default(.defaultGridTemplate) private var defaultTemplate
    @Default(.gridFollowsAppAccentColor) private var followsAppAccent
    @Default(.gridOverlayAccentColor) private var accentColor
    @Default(.gridOverlayOpacity) private var overlayOpacity
    @Default(.gridLineThickness) private var lineThickness
    @Default(.gridCellCornerRadius) private var cornerRadius
    @Default(.gridOverlayBlurEnabled) private var glassEnabled

    @State private var connectedScreens: [NSScreen] = []
    @State private var showClearMemoryConfirmation = false

    var body: some View {
        Form {
            defaultTemplateSection
            screenTemplatesSection
            visualStyleSection
            memorySection
        }
        .settingsFormPanel(maxWidth: 560)
        .onAppear(perform: refreshConnectedScreens)
    }

    // MARK: - Default Template

    private var defaultTemplateSection: some View {
        Section {
            GridTemplateEditor(template: $defaultTemplate)

            VStack(alignment: .leading, spacing: 8) {
                Text(templateSummary(defaultTemplate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                CompactGridPreview(
                    template: defaultTemplate,
                    accentColor: effectiveAccentColor
                )
                .frame(height: 100)
            }
        } header: {
            Text("Global Default Template", comment: "Settings section header for the default grid template")
        } footer: {
            Text("When a display does not have a custom template, the hover grid overlay uses this default layout.", comment: "Settings footer explaining the default grid template")
        }
    }

    // MARK: - Screen Templates

    private var screenTemplatesSection: some View {
        Section {
            if connectedScreens.isEmpty {
                ContentUnavailableView(
                    "No Displays Detected",
                    systemImage: "display",
                    description: Text("Connect an external display to override the default grid for each display.", comment: "Empty state description for per-display grid templates")
                )
            } else {
                ForEach(connectedScreens, id: \.gridIdentifier) { screen in
                    ScreenTemplateRow(
                        screen: screen,
                        accentColor: effectiveAccentColor
                    )
                }
            }

            Button(action: refreshConnectedScreens) {
                Label("Refresh Display List", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Connected Displays", comment: "Settings section header for connected displays")
        } footer: {
            Text("Display settings only override the layout template. Color, opacity, and line style still use the shared hover overlay settings below.", comment: "Settings footer explaining per-display grid overrides")
        }
    }

    // MARK: - Visual Style

    private var visualStyleSection: some View {
        Section {
            Toggle(isOn: $followsAppAccent) {
                SettingsRowLabel(
                    "Follow App Accent Color",
                    detail: "Use the current system accent color so highlights match native controls.",
                    systemImage: "paintpalette"
                )
            }

            if !followsAppAccent {
                ColorPicker("Grid accent color", selection: $accentColor)
            }

            SettingsSlider.percent(
                title: "Opacity",
                value: overlayOpacityBinding,
                range: gridOverlayMinimumOpacity...1
            )

            SettingsSlider.pixels(
                title: "Line Thickness",
                value: $lineThickness.doubleBinding,
                range: 1...3,
                step: 0.5
            )

            SettingsSlider.pixels(
                title: "Corner Radius",
                value: $cornerRadius.doubleBinding,
                range: 0...20,
                step: 1
            )

            Toggle(isOn: $glassEnabled) {
                SettingsRowLabel(
                    "Enable Liquid Glass",
                    detail: "Use the system glass material for the background while keeping the active grid above the blur layer.",
                    systemImage: "sparkles.rectangle.stack"
                )
            }
        } header: {
            Text("Mouse Hover Grid Style", comment: "Settings section header for hover grid styling")
        } footer: {
            Text("These settings control the grid thumbnail, selection highlight, and overlay material shown while dragging windows.", comment: "Settings footer explaining hover grid style controls")
        }
    }

    // MARK: - Memory Management

    private var memorySection: some View {
        Section {
            Button(role: .destructive) {
                showClearMemoryConfirmation = true
            } label: {
                Label("Clear All Grid Size Memory", systemImage: "trash")
            }
            .alert("Confirm Clear", isPresented: $showClearMemoryConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    GridConfigurationManager.shared.clearAllMemory()
                }
            } message: {
                Text("This clears grid size memory for every app on every display. This action cannot be undone.", comment: "Confirmation message for clearing all grid size memory")
            }
        } header: {
            Text("Memory Management", comment: "Settings section header for grid memory controls")
        } footer: {
            Text("Grid size memory only affects the default selection size when different apps enter grid mode again.", comment: "Settings footer explaining grid size memory")
        }
    }

    // MARK: - Helpers

    private var effectiveAccentColor: Color {
        followsAppAccent ? .accentColor : accentColor
    }

    private var overlayOpacityBinding: Binding<Double> {
        Binding {
            max(gridOverlayMinimumOpacity, overlayOpacity)
        } set: { newValue in
            overlayOpacity = max(gridOverlayMinimumOpacity, newValue)
        }
    }

    private func refreshConnectedScreens() {
        connectedScreens = NSScreen.screens
    }

    private func templateSummary(_ template: GridTemplate) -> String {
        let format = String(
            localized: "%lld columns x %lld rows, %lld px gap",
            comment: "Summary of a grid template. The values are columns, rows, and gap in pixels."
        )
        return String.localizedStringWithFormat(
            format,
            template.columns,
            template.rows,
            Int(template.gap.rounded())
        )
    }
}

// MARK: - Screen Template Row

@available(macOS 15.0, *)
private struct ScreenTemplateRow: View {
    let screen: NSScreen
    let accentColor: Color

    @Default(.defaultGridTemplate) private var defaultTemplate

    @State private var useCustom = false
    @State private var customTemplate: GridTemplate = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Toggle(isOn: $useCustom) {
                SettingsRowLabel(
                    "Use Custom Template for This Display",
                    detail: "Override the global row and column counts for this display only.",
                    systemImage: "display.and.arrow.down"
                )
            }
            .toggleStyle(.switch)
            .onChange(of: useCustom) { _, newValue in
                updateCustomState(enabled: newValue)
            }

            if useCustom {
                GridTemplateEditor(template: customTemplateBinding)
            } else {
                Label("Inherit Global Default Template", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CompactGridPreview(
                template: effectiveTemplate,
                accentColor: accentColor,
                aspectRatio: screenAspectRatio
            )
            .frame(height: 80)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .onAppear(perform: synchronizeState)
        .onChange(of: defaultTemplate) { _, newDefault in
            if !useCustom {
                customTemplate = newDefault
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "display")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(screenDisplayName)
                    .font(.headline)

                Text(screenDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 12)

            if useCustom {
                SettingsStatusBadge(title: "Custom", systemImage: "slider.horizontal.3", isProminent: true)
            } else {
                SettingsStatusBadge(title: "Default", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var customTemplateBinding: Binding<GridTemplate> {
        Binding {
            customTemplate
        } set: { newTemplate in
            customTemplate = newTemplate
            GridConfigurationManager.shared.setTemplate(newTemplate, for: screen)
        }
    }

    private var effectiveTemplate: GridTemplate {
        useCustom ? customTemplate : defaultTemplate
    }

    private var screenAspectRatio: CGFloat {
        guard screen.frame.height > 0 else { return 16.0 / 10.0 }
        return max(1, min(2.4, screen.frame.width / screen.frame.height))
    }

    private var screenDisplayName: String {
        let name = screen.localizedName
        if !name.isEmpty {
            return name
        }
        let format = String(
            localized: "Display %@",
            comment: "Fallback display name. The value is a shortened display identifier."
        )
        return String.localizedStringWithFormat(
            format,
            String(screen.gridIdentifier.prefix(8))
        )
    }

    private var screenDetail: String {
        "\(Int(screen.frame.width)) x \(Int(screen.frame.height)) pt, ID \(screen.gridIdentifier.prefix(8))"
    }

    private func synchronizeState() {
        useCustom = GridConfigurationManager.shared.hasCustomTemplate(for: screen)
        customTemplate = useCustom
            ? GridConfigurationManager.shared.template(for: screen)
            : defaultTemplate
    }

    private func updateCustomState(enabled: Bool) {
        if enabled {
            GridConfigurationManager.shared.setTemplate(customTemplate, for: screen)
        } else {
            GridConfigurationManager.shared.removeTemplate(for: screen)
            customTemplate = defaultTemplate
        }
    }
}

// MARK: - Template Controls

@available(macOS 15.0, *)
private struct GridTemplateEditor: View {
    @Binding var template: GridTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSlider.number(
                title: "Rows",
                value: rowsBinding,
                range: 1...10,
                step: 1
            )

            SettingsSlider.number(
                title: "Columns",
                value: columnsBinding,
                range: 1...10,
                step: 1
            )

            SettingsSlider.pixels(
                title: "Gap",
                value: gapBinding,
                range: 0...32,
                step: 1
            )
        }
    }

    private var rowsBinding: Binding<Double> {
        Binding {
            Double(template.rows)
        } set: { newValue in
            template = GridTemplate(
                rows: Int(newValue.rounded()),
                columns: template.columns,
                gap: template.gap
            )
        }
    }

    private var columnsBinding: Binding<Double> {
        Binding {
            Double(template.columns)
        } set: { newValue in
            template = GridTemplate(
                rows: template.rows,
                columns: Int(newValue.rounded()),
                gap: template.gap
            )
        }
    }

    private var gapBinding: Binding<Double> {
        Binding {
            Double(template.gap)
        } set: { newValue in
            template = GridTemplate(
                rows: template.rows,
                columns: template.columns,
                gap: CGFloat(newValue.rounded())
            )
        }
    }
}

// MARK: - Deprecated: GridValueSlider (kept for compatibility)

@available(macOS 15.0, *)
private struct GridValueSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } label: {
                Text(title)
            }

            Slider(value: $value, in: range, step: step)
        }
    }
}

// MARK: - Preview

@available(macOS 15.0, *)
private struct GridTemplatePreview: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let template: GridTemplate
    let accentColor: Color
    let overlayOpacity: Double
    let lineThickness: CGFloat
    let cornerRadius: CGFloat
    let blurEnabled: Bool
    let aspectRatio: CGFloat

    init(
        template: GridTemplate,
        accentColor: Color,
        overlayOpacity: Double,
        lineThickness: CGFloat,
        cornerRadius: CGFloat,
        blurEnabled: Bool,
        aspectRatio: CGFloat = 16.0 / 10.0
    ) {
        self.template = template
        self.accentColor = accentColor
        self.overlayOpacity = overlayOpacity
        self.lineThickness = lineThickness
        self.cornerRadius = cornerRadius
        self.blurEnabled = blurEnabled
        self.aspectRatio = aspectRatio
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gap = previewGap(for: size)
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
                previewBackground

                ForEach(0 ..< template.rows, id: \.self) { row in
                    ForEach(0 ..< template.columns, id: \.self) { column in
                        cell(
                            width: cellWidth,
                            height: cellHeight
                        )
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
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grid layout preview")
        .accessibilityValue(Text(accessibilityValue))
    }

    private var accessibilityValue: String {
        let format = String(
            localized: "%lld columns, %lld rows, %lld pixel gap",
            comment: "Accessibility value for the grid preview. The values are columns, rows, and gap in pixels."
        )
        return String.localizedStringWithFormat(
            format,
            template.columns,
            template.rows,
            Int(template.gap.rounded())
        )
    }

    @ViewBuilder
    private var previewBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

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

    private var effectiveOverlayOpacity: Double {
        min(1, max(gridOverlayMinimumOpacity, overlayOpacity))
    }

    private var previewLineWidth: CGFloat {
        max(0.5, min(2, lineThickness))
    }

    private func previewGap(for size: CGSize) -> CGFloat {
        let longestSide = max(size.width, size.height)
        let scaledGap = template.gap * max(0.28, min(0.5, longestSide / 800))
        return min(12, max(0, scaledGap))
    }

    private func cellLength(
        availableLength: CGFloat,
        count: Int,
        gap: CGFloat
    ) -> CGFloat {
        let totalGap = CGFloat(max(0, count - 1)) * gap
        return max(1, (availableLength - totalGap) / CGFloat(count))
    }

    private func cell(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(
            cornerRadius: cellCornerRadius(width: width, height: height),
            style: .continuous
        )
        .fill(accentColor.opacity(effectiveOverlayOpacity * 0.18))
        .overlay {
            RoundedRectangle(
                cornerRadius: cellCornerRadius(width: width, height: height),
                style: .continuous
            )
            .strokeBorder(accentColor.opacity(0.55), lineWidth: previewLineWidth)
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
        let startColumn = max(0, min(1, template.columns - selectedColumns))
        let startRow = max(0, min(1, template.rows - selectedRows))
        let width = CGFloat(selectedColumns) * cellWidth + CGFloat(max(0, selectedColumns - 1)) * gap
        let height = CGFloat(selectedRows) * cellHeight + CGFloat(max(0, selectedRows - 1)) * gap
        let highlightCornerRadius = min(cornerRadius + 2, min(width, height) / 4)
        let shape = RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)

        shape
            .fill(accentColor.opacity(blurEnabled && !reduceTransparency ? 0.28 : 0.32))
            .overlay {
                shape.strokeBorder(accentColor, lineWidth: max(1.5, previewLineWidth + 0.5))
            }
            .shadow(color: accentColor.opacity(0.22), radius: 6, y: 2)
            .frame(width: width, height: height)
            .offset(
                x: CGFloat(startColumn) * (cellWidth + gap),
                y: CGFloat(startRow) * (cellHeight + gap)
            )
    }

    private func cellCornerRadius(width: CGFloat, height: CGFloat) -> CGFloat {
        min(cornerRadius, min(width, height) / 3)
    }
}

// MARK: - macOS 26 Availability Helper

private extension View {
    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }

    @ViewBuilder
    func contentMarginsIfAvailable(_ edges: Edge.Set, _ length: CGFloat) -> some View {
        if #available(macOS 14.0, *) {
            contentMargins(edges, length, for: .scrollContent)
        } else {
            self
        }
    }
}
