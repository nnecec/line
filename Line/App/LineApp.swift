//
//  LineApp.swift
//  Line
//
//  Created by nnecec on 2023-01-23.
//

import AppKit
import Defaults
import SwiftUI

@main
struct LineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var sparkleUpdater = SparkleUpdater.shared
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @StateObject private var settingsState: SettingsState

    @MainActor
    init() {
        let settingsState = SettingsState()
        _settingsState = StateObject(wrappedValue: settingsState)
        SettingsWindowHost.shared.configure(state: settingsState)
    }

    var body: some Scene {
        MenuBarExtra(Bundle.main.appName, image: "menubarIcon", isInserted: Binding.constant(!hideMenuBarIcon)) {
            Text(
                "Version \(VersionDisplay.current.fullDisplay)",
                comment: "Format: Version [version, e.g. 1.3.0] ([build number, e.g. 1500])"
            )
            .font(.system(size: 11, weight: .semibold))

            Button {
                showSettings(tab: .about)
            } label: {
                Text("About \(Bundle.main.appName)", comment: "Menu item that opens the About settings tab")
            }

            Button {
                sparkleUpdater.checkForUpdates()
            } label: {
                Text(
                    "Check for Updates…",
                    comment: "Button to check for updates in menubar dropdown menu"
                )
            }
            .disabled(!sparkleUpdater.canCheckForUpdates)

            if sparkleUpdater.canRetryStart {
                Text(
                    "Update service unavailable",
                    comment: "Status shown in the menu when the update service failed to start"
                )

                Button {
                    sparkleUpdater.retryStart()
                } label: {
                    Text(
                        "Retry Update Service",
                        comment: "Button that retries starting the app's update service"
                    )
                }
            }

            Divider()

            Button {
                showSettings()
            } label: {
                Text("Settings…", comment: "Menu item that opens Line settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit \(Bundle.main.appName)", comment: "Menu item that quits the app")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button {
                    showSettings(tab: .about)
                } label: {
                    Text("About \(Bundle.main.appName)", comment: "App menu About item")
                }
            }

            CommandGroup(after: .appInfo) {
                Button {
                    sparkleUpdater.checkForUpdates()
                } label: {
                    Text(
                        "Check for Updates…",
                        comment: "App menu item that checks for updates"
                    )
                }
                .disabled(!sparkleUpdater.canCheckForUpdates)
            }

            CommandGroup(replacing: .appSettings) {
                Button {
                    showSettings()
                } label: {
                    Text("Settings…", comment: "App menu Settings item")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button {
                    openURL(ProjectLinks.repositoryURL)
                } label: {
                    Text(
                        "\(Bundle.main.appName) on GitHub",
                        comment: "Help menu item that opens the project repository"
                    )
                }

                Button {
                    openURL(ProjectLinks.issuesURL)
                } label: {
                    Text(
                        "Report an Issue…",
                        comment: "Help menu item that opens the GitHub issues page"
                    )
                }

                Button {
                    openURL(ProjectLinks.urlSchemeDocsURL)
                } label: {
                    Text(
                        "URL Scheme Documentation",
                        comment: "Help menu item that opens URL scheme docs"
                    )
                }

                Divider()

                Button {
                    showSettings(tab: .permissions)
                } label: {
                    Text(
                        "Permissions…",
                        comment: "Help menu item that opens the Permissions settings tab"
                    )
                }
            }
        }
    }

    private func showSettings(tab: SettingsTab? = nil) {
        SettingsWindowHost.shared.show(tab: tab)
    }

    private func openURL(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
