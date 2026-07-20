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
    @State private var navigationHistory: [SettingsTab] = [.preview]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false

    private var tabSelection: Binding<SettingsTab?> {
        Binding {
            state.currentTab
        } set: { newTab in
            if let newTab {
                state.currentTab = newTab
            }
        }
    }

    private var canGoBack: Bool {
        historyIndex > 0
    }

    private var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: tabSelection) {
                sidebarSection(
                    String(localized: "Settings sidebar section: Appearance", defaultValue: "Appearance"),
                    tabs: SettingsTab.appearanceTabs
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
            .navigationTitle(
                String(localized: "Line Settings", comment: "Window title for Line settings")
            )
        } detail: {
            // Form panes own scrolling and fill the column so the scrollbar sits
            // on the detail panel's trailing edge (not beside a narrow content column).
            // Do not wrap in ScrollView - nested scroll views fight Form.
            state.currentTab.view()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(state.currentTab.title)
                .id(state.currentTab)
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(state)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    goBack()
                } label: {
                    Label(
                        String(localized: "Back", comment: "Settings toolbar back navigation"),
                        systemImage: "chevron.left"
                    )
                }
                .disabled(!canGoBack)
                .help(Text("Go to previous settings pane", comment: "Help text for settings back button"))
                .accessibilityLabel(
                    Text("Back", comment: "Accessibility label for settings back navigation")
                )

                Button {
                    goForward()
                } label: {
                    Label(
                        String(localized: "Forward", comment: "Settings toolbar forward navigation"),
                        systemImage: "chevron.right"
                    )
                }
                .disabled(!canGoForward)
                .help(Text("Go to next settings pane", comment: "Help text for settings forward button"))
                .accessibilityLabel(
                    Text("Forward", comment: "Accessibility label for settings forward navigation")
                )
            }
        }
        .onAppear {
            if navigationHistory.isEmpty {
                navigationHistory = [state.currentTab]
                historyIndex = 0
            } else if navigationHistory[historyIndex] != state.currentTab {
                navigationHistory = [state.currentTab]
                historyIndex = 0
            }
        }
        .onChange(of: state.currentTab) { _, newTab in
            recordNavigation(to: newTab)
        }
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

    private func goBack() {
        guard canGoBack else { return }
        isHistoryNavigation = true
        historyIndex -= 1
        state.currentTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func goForward() {
        guard canGoForward else { return }
        isHistoryNavigation = true
        historyIndex += 1
        state.currentTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func recordNavigation(to tab: SettingsTab) {
        guard !isHistoryNavigation else { return }
        if navigationHistory.indices.contains(historyIndex),
           navigationHistory[historyIndex] == tab {
            return
        }

        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }

        navigationHistory.append(tab)
        historyIndex = navigationHistory.count - 1
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
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .fontWeight(.medium)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 1)
    }
}
