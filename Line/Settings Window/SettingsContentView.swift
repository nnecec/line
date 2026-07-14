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
                sidebarSection("Line", tabs: SettingsTab.loopTabs)
            }
            .listStyle(.sidebar)
            .scrollEdgeEffectStyleSoftIfAvailable()
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            // Wrap detail view in ScrollView to push scrollbar to window edge
            ScrollView {
                state.currentTab.view()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle(state.currentTab.title)
            .scrollContentBackground(.hidden)
            .settingsScrollEdgeEffect()
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(state)
    }

    private func sidebarSection(_ title: String, tabs: [SettingsTab]) -> some View {
        Section(title) {
            ForEach(tabs) { tab in
                Label {
                    HStack {
                        Text(tab.title)

                        Spacer()
                    }
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

struct SettingsStatusBadge: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isProminent = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(isProminent ? Color.accentColor : .secondary)
    }
}

extension View {
    @ViewBuilder
    func settingsFormPanel(maxWidth: CGFloat = 520) -> some View {
        if #available(macOS 14.0, *) {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 16, for: .scrollContent)
                .contentMargins(.horizontal, 24, for: .scrollContent)
                .contentMargins(.bottom, 24, for: .scrollContent)
                .frame(maxWidth: maxWidth + 48) // Content width plus horizontal padding
        } else {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: maxWidth + 48)
        }
    }

    @ViewBuilder
    func settingsScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
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
}
