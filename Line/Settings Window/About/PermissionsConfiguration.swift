//
//  PermissionsConfiguration.swift
//  Line
//
//  Created by nnecec on 2026-07-03.
//

import SwiftUI

@MainActor
final class PermissionsConfigurationModel: ObservableObject {
    @Published private(set) var isAccessibilityAccessGranted = AccessibilityManager.shared.isGranted

    private var accessibilityCheckerTask: Task<(), Never>?

    func startTracking() {
        accessibilityCheckerTask = Task(priority: .background) {
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    isAccessibilityAccessGranted = status
                }
            }
        }
    }

    func stopTracking() {
        accessibilityCheckerTask?.cancel()
        accessibilityCheckerTask = nil
    }
}

struct PermissionsConfigurationView: View {
    @StateObject private var model = PermissionsConfigurationModel()

    var body: some View {
        Form {
            Section {
                accessibilityComponent
            } header: {
                Text("System Access", comment: "Section header shown in settings")
            } footer: {
                Text("Line only uses these permissions to identify and resize windows you control.")
            }
        }
        .settingsFormPanel()
        .animation(.default, value: model.isAccessibilityAccessGranted)
        .onAppear(perform: model.startTracking)
        .onDisappear(perform: model.stopTracking)
    }

    private var accessibilityComponent: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if model.isAccessibilityAccessGranted {
                    SettingsStatusBadge(title: "Granted", systemImage: "checkmark.seal.fill", isProminent: true)
                } else {
                    SettingsStatusBadge(title: "Required", systemImage: "exclamationmark.triangle")
                }

                Button("Request...") {
                    _ = AccessibilityManager.requestAccess()
                }
                .disabled(model.isAccessibilityAccessGranted)
            }
        } label: {
            SettingsRowLabel(
                "Accessibility access",
                detail: "Required for reading and moving windows across apps.",
                systemImage: "accessibility"
            )
        }
    }
}
