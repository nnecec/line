//
//  SettingsContentView.swift
//  Line
//
//  Created by nnecec on 2025-10-18.
//

import SwiftUI

struct SettingsContentView: View {
    @ObservedObject var state: SettingsState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var tabSelection: Binding<SettingsTab?> {
        Binding {
            state.currentTab
        } set: { newTab in
            if let newTab {
                state.currentTab = newTab
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: tabSelection) {
                sidebarSection(
                    String(localized: "Settings sidebar section: Appearance", defaultValue: "Appearance"),
                    tabs: SettingsTab.themingTabs
                )
                sidebarSection(
                    String(localized: "Settings sidebar section: Controls", defaultValue: "Controls"),
                    tabs: SettingsTab.settingsTabs
                )
                sidebarSection(
                    String(localized: "Settings sidebar section: App", defaultValue: "App"),
                    tabs: SettingsTab.loopTabs
                )
            }
            .listStyle(.sidebar)
            .scrollEdgeEffectStyleSoftIfAvailable()
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            // Form panes own scrolling and fill the column so the scrollbar sits
            // on the detail panel's trailing edge (not beside a narrow content column).
            // Do not wrap in ScrollView — nested scroll views fight Form.
            state.currentTab.view()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(state.currentTab.title)
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(state)
    }

    private func sidebarSection(_ title: String, tabs: [SettingsTab]) -> some View {
        Section(title) {
            ForEach(tabs) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    tab.image
                }
                .tag(tab)
            }
        }
    }
}

// MARK: - Shared Settings UI

struct SettingsRowLabel: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let systemImage: String?

    init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }

    var body: some View {
        if let systemImage {
            Label {
                text
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
        } else {
            text
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


