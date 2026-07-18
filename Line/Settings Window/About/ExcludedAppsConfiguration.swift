//
//  ExcludedAppsConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-05-25.
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsConfigurationView: View {
    @Environment(\.settingsWindowProvider) private var settingsWindowProvider

    @Default(.excludedApps) private var excludedApps
    @State private var selectedApps = Set<URL>()

    var body: some View {
        Form {
            Section {
                Text("Line will skip windows owned by these applications. This is useful for launchers, screen recorders, and apps that manage their own floating panels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button {
                        showAppChooser()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }

                    Button(role: .destructive) {
                        removeSelectedApps()
                    } label: {
                        Label("Remove", systemImage: "minus")
                    }
                    .disabled(selectedApps.isEmpty)
                    .keyboardShortcut(.delete)
                }
                .buttonStyle(.borderless)
                .controlSize(.large)

                if excludedApps.isEmpty {
                    emptyState
                } else {
                    List(selection: $selectedApps) {
                        ForEach(excludedApps, id: \.self) { url in
                            ExcludedListAppView(url: url)
                                .equatable()
                                .tag(url)
                        }
                    }
                    .frame(minHeight: 220)
                }
            } header: {
                Text("Excluded Applications", comment: "Section header shown in settings")
            } footer: {
                Text("Line ignores windows from applications in this list.")
            }
        }
        .settingsFormPanel()
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "app.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No excluded applications")
                .font(.headline)

            Text("Press Add to add an application.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
    }

    private func removeSelectedApps() {
        excludedApps.removeAll { selectedApps.contains($0) }
        selectedApps.removeAll()
    }

    private func showAppChooser() {
        Task { @MainActor in
            guard let window = settingsWindowProvider.window else { return }

            let panel = NSOpenPanel()
            panel.worksWhenModal = true
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.application]
            panel.allowsOtherFileTypes = false
            panel.resolvesAliases = true
            panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first

            let result = await panel.beginSheetModal(for: window)

            if result == .OK {
                let appsToAdd = panel.urls.compactMap { excludedApps.contains($0) ? nil : $0 }
                excludedApps.append(contentsOf: appsToAdd)
            }
        }
    }
}

struct ExcludedListAppView: View, Equatable {
    @State private var app: App

    init(url: URL) {
        _app = State(initialValue: App(url: url) ?? App(
            bundleID: "unknown",
            displayName: url.lastPathComponent,
            path: url.relativePath,
            url: url.absoluteURL,
            icon: .init(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        ))
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading) {
                Text(app.displayName)

                Text(app.path)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Spacer()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
            } label: {
                Label("Reveal in Finder", systemImage: "arrow.up.forward")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .task {
            app = await app.loadIconIfNeeded()
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.app.url == rhs.app.url
    }

    struct App: Identifiable {
        var id: String { bundleID }
        let bundleID: String
        let icon: NSImage?
        let displayName: String
        let path: String
        let url: URL

        init?(url: URL) {
            guard
                let meta = NSMetadataItem(url: url),
                let bundleId = meta.value(forAttribute: NSMetadataItemCFBundleIdentifierKey) as? String,
                let displayName = meta.value(forAttribute: NSMetadataItemDisplayNameKey) as? String,
                let path = meta.value(forAttribute: NSMetadataItemPathKey) as? String
            else {
                return nil
            }

            self.bundleID = bundleId
            self.icon = nil
            self.displayName = displayName
            self.path = path
            self.url = url
        }

        init(bundleID: String, displayName: String, path: String, url: URL, icon: NSImage?) {
            self.bundleID = bundleID
            self.displayName = displayName
            self.path = path
            self.url = url
            self.icon = icon
        }

        func loadIconIfNeeded() async -> App {
            guard icon == nil else { return self }

            return .init(
                bundleID: bundleID,
                displayName: displayName,
                path: path,
                url: url,
                icon: NSWorkspace.shared.icon(forFile: path)
            )
        }
    }
}

