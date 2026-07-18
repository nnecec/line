//
//  AccentColorConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-04-19.
//

import Defaults
import SwiftUI

// MARK: - View

struct AccentColorConfigurationView: View {
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Default(.accentColorMode) private var accentColorMode
    @Default(.useGradient) private var useGradient
    @Default(.customAccentColor) private var customAccentColor
    @Default(.gradientColor) private var gradientColor

    @State private var didSyncWallpaper: Bool = false
    @State private var syncWallpaperTask: Task<(), Never>?

    var body: some View {
        Form {
            Section {
                Picker("Accent color", selection: $accentColorMode) {
                    ForEach(AccentColorOption.allCases, id: \.self) { option in
                        Label {
                            Text(option.text)
                        } icon: {
                            option.image
                        }
                        .tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Gradient", isOn: $useGradient)

                if accentColorMode == .wallpaper {
                    syncWallpaperButton
                }
            } header: {
                Text("Accent Color", comment: "Section header shown in settings")
            }

            if accentColorMode == .custom {
                Section {
                    ColorPicker("Primary color", selection: $customAccentColor, supportsOpacity: false)

                    if useGradient {
                        ColorPicker("Gradient color", selection: $gradientColor, supportsOpacity: false)
                    }
                } header: {
                    Text("Color", comment: "Section header shown in settings")
                }
                .animation(.default, value: useGradient)
            }
        }
        .settingsFormPanel()
        .animation(.default, value: accentColorMode)
    }

    private var syncWallpaperButton: some View {
        Button(action: syncWallpaper) {
            HStack {
                Text("Sync Wallpaper")

                if didSyncWallpaper {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .bold()
                }
            }
        }
    }

    private func syncWallpaper() {
        if syncWallpaperTask != nil {
            return
        }

        syncWallpaperTask = Task {
            await accentColorController.refresh(ignoreThrottle: true)

            withAnimation(.easeInOut(duration: 0.5)) {
                didSyncWallpaper = true
            }

            try? await Task.sleep(for: .seconds(2))

            withAnimation(.easeInOut(duration: 0.5)) {
                didSyncWallpaper = false
            }

            syncWallpaperTask = nil
        }
    }
}

