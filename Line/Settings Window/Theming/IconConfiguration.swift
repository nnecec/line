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
    @Published var showingNotificationSettingsAlert = false
}

struct IconConfigurationView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var model = IconConfigurationModel()

    @Default(.currentIcon) private var currentIcon
    @Default(.showDockIcon) private var showDockIcon

    @State private var showingLiquidGlassPopover = false

    private var selectedIcon: Icon {
        IconManager.currentAppIcon
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
                        Text(icon.name)
                            .tag(icon.assetName)
                    }
                }
                .pickerStyle(.menu)
                .help("Select the icon used in the Dock and app switcher.")
            } header: {
                Text("Icon", comment: "Section header shown in settings")
            }

            Section {
                Toggle("Show in dock", isOn: $showDockIcon)
            } header: {
                Text("Options", comment: "Section header shown in settings")
            }
        }
        .settingsFormPanel()
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
                guard let icon = Icon.all.first(where: { $0.assetName == assetName })
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
        .settingsImageOutline(cornerRadius: size * 0.2)
    }
}

