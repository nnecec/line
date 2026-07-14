//
//  LineApp.swift
//  Line
//
//  Created by nnecec on 2023-01-23.
//

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

            Button("Settings…") {
                showSettings()
            }

            Divider()

            Button("Quit \(Bundle.main.appName)") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func showSettings(tab: SettingsTab? = nil) {
        SettingsWindowHost.shared.show(tab: tab)
    }
}
