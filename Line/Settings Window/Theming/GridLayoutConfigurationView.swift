//
//  GridLayoutConfigurationView.swift
//  Line
//
//  Grid layout template configuration (rows, columns, gap) and per-display overrides.
//  Visual styling lives in PreviewConfigurationView.
//

import AppKit
import Defaults
import SwiftUI

@available(macOS 15.0, *)
struct GridLayoutConfigurationView: View {
    @Default(.defaultGridTemplate) private var defaultTemplate

    @State private var connectedScreens: [NSScreen] = []

    var body: some View {
        Form {
            defaultTemplateSection
            screenTemplatesSection
        }
        .settingsFormPanel(maxWidth: 560)
        .onAppear(perform: refreshConnectedScreens)
    }

    // MARK: - Default Template

    private var defaultTemplateSection: some View {
        Section {
            GridTemplateEditor(template: $defaultTemplate)

            Text(templateSummary(defaultTemplate))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } header: {
            Text("Global Default Template", comment: "Settings section header for the default grid template")
        } footer: {
            Text(
                "When a display does not have a custom template, the hover grid overlay uses this default layout. Visual styling is configured in Preview.",
                comment: "Settings footer explaining the default grid template"
            )
        }
    }

    // MARK: - Screen Templates

    private var screenTemplatesSection: some View {
        Section {
            if connectedScreens.isEmpty {
                ContentUnavailableView(
                    "No Displays Detected",
                    systemImage: "display",
                    description: Text(
                        "Connect an external display to override the default grid for each display.",
                        comment: "Empty state description for per-display grid templates"
                    )
                )
            } else {
                ForEach(connectedScreens, id: \.gridIdentifier) { screen in
                    ScreenTemplateRow(screen: screen)
                }
            }

            Button(action: refreshConnectedScreens) {
                Label("Refresh Display List", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Connected Displays", comment: "Settings section header for connected displays")
        } footer: {
            Text(
                "Display settings only override the layout template. Visual styling (colors, glass effects, borders) is configured in Preview.",
                comment: "Settings footer explaining per-display grid overrides"
            )
        }
    }

    // MARK: - Helpers

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

                Text(templateSummary(customTemplate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Label("Inherit Global Default Template", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: .rect(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
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
                SettingsStatusBadge(
                    title: "Custom",
                    systemImage: "slider.horizontal.3",
                    style: .accent
                )
            } else {
                SettingsStatusBadge(
                    title: "Default",
                    systemImage: "arrow.triangle.2.circlepath",
                    style: .neutral
                )
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
