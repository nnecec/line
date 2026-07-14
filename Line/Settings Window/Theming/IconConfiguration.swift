//
//  IconConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-04-19.
//

import AppKit
import Defaults
import SwiftUI

final class IconConfigurationModel: ObservableObject {
    @Published var showingLockedAlert = false
    @Published var showingNotificationSettingsAlert = false
    @Published var selectedLockedMessage: String = ""

    let lockedMessages: [String] = [
        .init(localized: "Locked icon message 1", defaultValue: "You don’t have that yet!"),
        .init(localized: "Locked icon message 2", defaultValue: "Who do you think you are, trying to access these top secret icons?"),
        .init(localized: "Locked icon message 3", defaultValue: "Patience is a virtue, and your key to this icon."),
        .init(localized: "Locked icon message 4", defaultValue: "This icon is locked, but your potential is not!"),
        .init(localized: "Locked icon message 5", defaultValue: "Keep making progress, and this icon will be yours in no time."),
        .init(localized: "Locked icon message 6", defaultValue: "This icon is still under wraps, stay tuned!"),
        .init(localized: "Locked icon message 7", defaultValue: "Some icons are worth the wait, don't you think?"),
        .init(localized: "Locked icon message 8", defaultValue: "Not yet, but you're closer than you were yesterday!"),
        .init(localized: "Locked icon message 9", defaultValue: "Unlocking this icon is just a matter of time and actions."),
        .init(localized: "Locked icon message 10", defaultValue: "This icon is like a fine wine, it needs more time."),
        .init(localized: "Locked icon message 11", defaultValue: "Stay curious, and soon this icon will be within your reach."),
        .init(localized: "Locked icon message 12", defaultValue: "Keep up the good work, and this icon will be your reward."),
        .init(localized: "Locked icon message 13", defaultValue: "This icon is reserved for the most dedicated users."),
        .init(localized: "Locked icon message 14", defaultValue: "Your journey is not yet complete, this icon awaits at the end."),
        .init(localized: "Locked icon message 15", defaultValue: "In due time, this icon shall be revealed to you."),
        .init(localized: "Locked icon message 16", defaultValue: "Patience, this icon is not far away."),
        .init(localized: "Locked icon message 17", defaultValue: "The journey to a thousand actions begins with a single step."),
        .init(localized: "Locked icon message 18", defaultValue: "Every action brings you closer to the treasure that awaits."),
        .init(localized: "Locked icon message 19", defaultValue: "With each action, the lock on this icon weakens."),
        .init(localized: "Locked icon message 20", defaultValue: "Action after action, your dedication carves the key to success."),
        .init(localized: "Locked icon message 21", defaultValue: "The icons are not just unlocked; they're earned through steady progress."),
        .init(localized: "Locked icon message 22", defaultValue: "As your actions accumulate, so too will your collection of icons."),
        .init(localized: "Locked icon message 23", defaultValue: "Think of each action as a riddle, solving the mystery of the locked icon."),
        .init(localized: "Locked icon message 24", defaultValue: "Your persistence is the master key to all icons."),
        .init(localized: "Locked icon message 25", defaultValue: "Keep going through the obstacles; your reward is just beyond them."),
        .init(localized: "Locked icon message 26", defaultValue: "Each action you complete plants the seeds for icons to grow."),
        .init(localized: "Locked icon message 27", defaultValue: "Like the moon's phases, your icons will reveal themselves through steady progress."),
        .init(localized: "Locked icon message 28", defaultValue: "The icons await, hidden behind the progress yet to be made.")
    ]
    private var shuffledTexts: [String] = []

    func getNextUpToDateText() -> String {
        // If shuffledTexts is empty, fill it with a shuffled version of lockedMessages.
        if shuffledTexts.isEmpty {
            shuffledTexts = lockedMessages.filter { $0 != "-" }.shuffled()
        }
        // Pop the last element to avoid repeats until all messages have been shown.
        return shuffledTexts.popLast() ?? lockedMessages[0]
    }

    func handleNotificationChange() {
        if Defaults[.notificationWhenIconUnlocked] {
            AppDelegate.sendNotification(
                Bundle.main.appName,
                .init(localized: "Icon notifications enabled", defaultValue: "You will now be notified when you unlock a new icon.")
            )

            if !AppDelegate.areNotificationsEnabled() {
                Defaults[.notificationWhenIconUnlocked] = false
                showingNotificationSettingsAlert = true
            }
        }
    }

    func nextIconUnlockActionCount(currentActionCount: Int) -> Int {
        Icon.all.first { $0.unlockTime > currentActionCount }?.unlockTime ?? 0
    }
}

struct IconConfigurationView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var model = IconConfigurationModel()

    @Default(.currentIcon) private var currentIcon
    @Default(.showDockIcon) private var showDockIcon
    @Default(.notificationWhenIconUnlocked) private var notificationWhenIconUnlocked
    @Default(.timesUsed) private var actionCount

    @State private var showingIconHelp = false
    @State private var showingLiquidGlassPopover = false

    private var selectedIcon: Icon {
        IconManager.currentAppIcon
    }

    private var lockedIcons: [Icon] {
        Icon.all.filter { !$0.isSelectable }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Current icon") {
                    HStack(spacing: 8) {
                        AppIconThumbnail(icon: selectedIcon, size: 40)

                        Text(selectedIcon.name)

                        defaultIconInfoButton
                    }
                }

                Picker("Icon style", selection: currentIconBinding) {
                    ForEach(Icon.all, id: \.assetName) { icon in
                        Text(iconMenuTitle(for: icon))
                            .tag(icon.assetName)
                            .disabled(!icon.isSelectable)
                    }
                }
                .pickerStyle(.menu)
                .help("Select the icon used in the Dock and app switcher.")

                Button {
                    showingIconHelp = true
                } label: {
                    Label("Icon unlock progress", systemImage: "questionmark.circle")
                }
                .popover(isPresented: $showingIconHelp) {
                    Text("Locked icons unlock as you make progress.")
                        .padding()
                        .frame(width: 220)
                }
            } header: {
                Text("Icon", comment: "Section header shown in settings")
            }

            if !lockedIcons.isEmpty {
                Section {
                    ForEach(lockedIcons, id: \.assetName) { icon in
                        Button {
                            model.selectedLockedMessage = model.getNextUpToDateText()
                            model.showingLockedAlert = true
                        } label: {
                            LockedIconRow(
                                icon: icon,
                                statusText: lockedStatusText(for: icon)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(lockedHelpText(for: icon))
                    }
                } header: {
                    Text("Locked Icons", comment: "Section header shown in settings")
                }
            }

            Section {
                Toggle("Show in dock", isOn: $showDockIcon)

                Toggle(
                    "Notify when unlocking new icons",
                    isOn: Binding(
                        get: {
                            notificationWhenIconUnlocked
                        },
                        set: {
                            notificationWhenIconUnlocked = $0
                            model.handleNotificationChange()
                        }
                    )
                )
            } header: {
                Text("Options", comment: "Section header shown in settings")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden) // Liquid glass: transparent form background
        .contentMarginsIfAvailable(.top, 8) // Breathing room below toolbar
        .scrollEdgeEffectStyleSoftIfAvailable() // macOS 26 progressive blur
        .alert(String(localized: "Locked icon alert title", defaultValue: "Icon Locked"), isPresented: $model.showingLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.selectedLockedMessage)
        }
        .alert(notificationPermissionTitle, isPresented: $model.showingNotificationSettingsAlert) {
            Button(String(localized: "Notification permits: open notification settings", defaultValue: "Open Settings")) {
                openNotificationSettings()
            }

            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "Notification permits: request", defaultValue: "Please turn them on in System Settings."))
        }
    }

    private var currentIconBinding: Binding<String> {
        Binding(
            get: {
                IconManager.currentAppIcon.assetName
            },
            set: { assetName in
                guard let icon = Icon.all.first(where: { $0.assetName == assetName }),
                      icon.isSelectable
                else {
                    return
                }

                currentIcon = icon.assetName
                IconManager.refreshCurrentAppIcon()
            }
        )
    }

    private var notificationPermissionTitle: String {
        .init(
            localized: "Notification permits: info",
            defaultValue: "\(Bundle.main.appName)'s notification permissions are currently disabled."
        )
    }

    @ViewBuilder
    private var defaultIconInfoButton: some View {
        if #available(macOS 26.0, *), selectedIcon.isDefault {
            Button {
                showingLiquidGlassPopover = true
            } label: {
                Image(systemName: "sparkles")
            }
            .buttonStyle(.borderless)
            .help("Supports macOS Tahoe's Liquid Glass effects")
            .popover(isPresented: $showingLiquidGlassPopover) {
                Text("Supports macOS Tahoe's Liquid Glass effects.")
                    .padding()
                    .frame(width: 240)
            }
        }
    }

    private func iconMenuTitle(for icon: Icon) -> String {
        if icon.isSelectable {
            return icon.name
        }

        return String(
            localized: "Locked icon picker label",
            defaultValue: "\(icon.name) - Locked"
        )
    }

    private func lockedStatusText(for icon: Icon) -> String {
        guard icon.unlockTime == model.nextIconUnlockActionCount(currentActionCount: actionCount) else {
            return .init(localized: "App icon is locked", defaultValue: "Locked")
        }

        let actionsLeft = max(icon.unlockTime - actionCount, 0)
        return .init(localized: "Actions left to unlock new icon", defaultValue: "\(actionsLeft) actions left")
    }

    private func lockedHelpText(for icon: Icon) -> String {
        let actionsLeft = max(icon.unlockTime - actionCount, 0)
        return .init(localized: "Actions needed to unlock icon", defaultValue: "\(actionsLeft) more actions needed to unlock \(icon.name).")
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        openURL(url)
    }
}

private struct AppIconThumbnail: View {
    let icon: Icon
    let size: CGFloat

    var body: some View {
        Group {
            if let image = NSImage(named: icon.assetName) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
}

private struct LockedIconRow: View {
    let icon: Icon
    let statusText: String

    var body: some View {
        HStack(spacing: 10) {
            AppIconThumbnail(icon: icon, size: 32)
                .opacity(0.45)
                .overlay {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(icon.name)
                    .foregroundStyle(.primary)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
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
