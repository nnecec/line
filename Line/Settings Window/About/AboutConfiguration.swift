//
//  AboutConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-04-26.
//

import AppKit
import SwiftUI

private let productDisplayName = "Line"

@MainActor
final class AboutConfigurationModel: ObservableObject {
    @Published var didCompleteCopyToClipboard: Bool = false

    let credits: [CreditItem] = [
        .init(
            "Loop",
            Text("Original project", comment: "Role title shown in Line’s credits section."),
            url: .init(string: "https://github.com/MrKai77/Loop")!,
            avatar: Image(nsImage: NSApp.applicationIconImage)
        )
    ]

    func copyVersionToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            "Version \(VersionDisplay.current.fullDisplay)",
            forType: NSPasteboard.PasteboardType.string
        )

        didCompleteCopyToClipboard = true

        Task { @MainActor in
            try await Task.sleep(for: .seconds(2))
            didCompleteCopyToClipboard = false
        }
    }
}

struct CreditItem: Identifiable {
    var id: String { name }

    let name: String
    let description: Text?
    let url: URL
    let avatar: Image

    init(_ name: String, _ description: Text? = nil, url: URL, avatar: Image) {
        self.name = name
        self.description = description
        self.avatar = avatar
        self.url = url
    }
}

struct AboutConfigurationView: View {
    @Environment(\.openURL) private var openURL

    @StateObject private var model = AboutConfigurationModel()
    @ObservedObject private var sparkleUpdater = SparkleUpdater.shared

    private var automaticallyChecksForUpdates: Binding<Bool> {
        Binding {
            sparkleUpdater.automaticallyChecksForUpdates
        } set: { newValue in
            sparkleUpdater.automaticallyChecksForUpdates = newValue
        }
    }

    var body: some View {
        Form {
            iconHeader
            updateSection
            communitySection
            creditsSection
        }
        .settingsFormPanel()
    }

    private var iconHeader: some View {
        Section {
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .settingsImageOutline(cornerRadius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(productDisplayName)
                        .fontWeight(.medium)

                    Text("Version \(Text(VersionDisplay.current.fullDisplay))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.copyVersionToClipboard()
                } label: {
                    Label("Copy version", systemImage: "document.on.clipboard")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 28, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Copy version to clipboard")
                .accessibilityLabel("Copy version to clipboard")
                .popover(isPresented: $model.didCompleteCopyToClipboard, arrowEdge: .bottom) {
                    Text("Copied")
                        .padding(8)
                }
            }
        }
    }

    private var updateSection: some View {
        Section {
            Text("Control how Line checks for releases and installs updates.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                sparkleUpdater.checkForUpdates()
            } label: {
                Label("Check for Updates…", systemImage: "arrow.down.circle")
            }
            .disabled(!sparkleUpdater.canCheckForUpdates)

            if sparkleUpdater.canRetryStart {
                Text(
                    "The update service could not start. You can retry without restarting Line.",
                    comment: "Status explaining that the update service can be retried without restarting the app"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    sparkleUpdater.retryStart()
                } label: {
                    Text(
                        "Retry Update Service",
                        comment: "Button that retries starting the app's update service"
                    )
                }
            }

            Toggle(isOn: automaticallyChecksForUpdates) {
                SettingsRowLabel(
                    "Automatically check for updates",
                    detail: "Notify when a new mainline release is available.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
        } header: {
            Text("Updates", comment: "Section header shown in settings")
        } footer: {
            Text(
                "Official Line releases are signed with a free Apple Development certificate and published through GitHub Releases. They are not notarized; grant Accessibility in System Settings after the first launch.",
                comment: "Footer describing the signing and distribution of official releases"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var communitySection: some View {
        Section {
            Text(
                "Share bugs, feature requests, or implementation notes with the project."
            )
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.secondary)

            Button {
                if let repositoryURL = ProjectLinks.repositoryURL {
                    openURL(repositoryURL)
                }
            } label: {
                Label("Send Feedback", systemImage: "bubble.left")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } header: {
            Text("Community", comment: "Section header shown in settings")
        }
    }

    private var creditsSection: some View {
        Section {
            ForEach(model.credits) { credit in
                creditView(credit)
            }
        } header: {
            Text("Credits", comment: "Section header shown in settings")
        }
    }

    private func creditView(_ credit: CreditItem) -> some View {
        HStack(spacing: 12) {
            credit.avatar
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(.circle)
                .settingsCircleImageOutline()

            VStack(alignment: .leading) {
                Text(credit.name)

                if let description = credit.description {
                    description
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                openURL(credit.url)
            } label: {
                Label("Open link", systemImage: "link")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Open \(credit.name) link")
            .accessibilityLabel("Open \(credit.name) link")
        }
    }
}

