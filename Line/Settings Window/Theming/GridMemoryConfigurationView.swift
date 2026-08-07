//
//  GridMemoryConfigurationView.swift
//  Line
//

import AppKit
import SwiftUI

@available(macOS 15.0, *)
struct GridMemoryConfigurationView: View {
    @State private var manager = GridConfigurationManager.shared

    @State private var selectedRecordIDs = Set<GridMemoryRecord.ID>()
    @State private var showClearAllConfirmation = false

    private var records: [GridMemoryRecord] {
        manager.persistentRecords
    }

    var body: some View {
        Form {
            Section {
                if records.isEmpty {
                    SettingsEmptyState(
                        systemImage: "square.grid.3x3",
                        title: "No Remembered Grid Sizes",
                        message: "Use grid mode with an app to create a persistent default."
                    )
                } else {
                    memoryTable
                    actionBar
                }
            } header: {
                Text(
                    "Remembered Grid Sizes",
                    comment: "Settings section header for persistent grid size records"
                )
            } footer: {
                Text(
                    "Persistent app and display defaults are listed here. Window-specific choices stay in memory for this Line session and reset when Line quits or Accessibility access is revoked.",
                    comment: "Settings footer explaining persistent and session-only grid memory"
                )
            }
        }
        .settingsFormPanel(maxWidth: 680)
        .alert("Clear Grid Memory?", isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                manager.clearAllMemory()
                selectedRecordIDs.removeAll()
            }
        } message: {
            Text(
                "Clear every persistent app and display grid size? Active window choices remain until the session ends.",
                comment: "Confirmation message before clearing every persistent grid memory record"
            )
        }
    }

    private var memoryTable: some View {
        Table(records, selection: $selectedRecordIDs) {
            TableColumn("Application") { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: applicationName(for: record.key.bundleId))
                        .lineLimit(1)
                    Text(verbatim: record.key.bundleId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TableColumn("Display") { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: displayName(for: record.key.screenIdentifier))
                        .lineLimit(1)
                    Text(verbatim: String(record.key.screenIdentifier.prefix(12)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TableColumn("Grid Size") { record in
                Text(verbatim: "\(record.size.columns) × \(record.size.rows)")
                    .monospacedDigit()
            }
            .width(min: 72, ideal: 90)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(minHeight: 280)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button(role: .destructive, action: removeSelectedRecords) {
                Label("Remove Selected", systemImage: "minus")
            }
            .disabled(selectedRecordIDs.isEmpty)
            .keyboardShortcut(.delete)

            Spacer()

            Button(role: .destructive) {
                showClearAllConfirmation = true
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .disabled(records.isEmpty)
        }
        .buttonStyle(.bordered)
    }

    private func removeSelectedRecords() {
        let selectedKeys = Set(
            records
                .filter { selectedRecordIDs.contains($0.id) }
                .map(\.key)
        )
        manager.clearMemory(for: selectedKeys)
        selectedRecordIDs.subtract(selectedKeys)
    }

    private func applicationName(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return bundleIdentifier
        }

        return (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
            ?? url.deletingPathExtension().lastPathComponent
    }

    private func displayName(for identifier: String) -> String {
        if let screen = NSScreen.screens.first(where: { $0.gridIdentifier == identifier }),
           !screen.localizedName.isEmpty {
            return screen.localizedName
        }

        let format = String(
            localized: "Display %@",
            comment: "Fallback display name. The value is a shortened display identifier."
        )
        return String.localizedStringWithFormat(format, String(identifier.prefix(8)))
    }
}
