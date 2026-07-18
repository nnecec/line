//
//  AdvancedConfiguration.swift
//  Line
//
//  Created by nnecec on 2024-04-26.
//

import Combine
import Defaults
import Scribe
import SwiftUI

@Loggable
@MainActor
final class AdvancedConfigurationModel: ObservableObject {
    @Published private(set) var showImportKeybindsSuccessIndicator = false
    @Published private(set) var showExportKeybindsSuccessIndicator = false
    @Published private(set) var showResetKeybindsSuccessIndicator = false

    @Published private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var lowPowerModeCheckerTask: Task<(), Never>?

    func startTracking() {
        trackLowPowerMode()
    }

    func stopTracking() {
        lowPowerModeCheckerTask?.cancel()
    }

    private func trackLowPowerMode() {
        lowPowerModeCheckerTask = Task(priority: .background) {
            let notifications = NotificationCenter.default
                .notifications(named: Notification.Name.NSProcessInfoPowerStateDidChange)

            for await info in notifications {
                guard !Task.isCancelled else { break }
                guard let processInfo = info.object as? ProcessInfo else { continue }

                await MainActor.run {
                    isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled
                }
            }
        }
    }

    /// Prompts the user to import keybinds from a file.
    func importPrompt() {
        Task {
            do {
                try await Migrator.importPrompt {
                    showSuccessIndicator(\.showImportKeybindsSuccessIndicator)
                }
            } catch {
                log.error("Error importing keybinds: \(ApplicationLogPrivacy.errorDescription(error))")
            }
        }
    }

    /// Prompts the user to export keybinds to a file.
    func exportPrompt() {
        Task {
            do {
                try await Migrator.exportPrompt {
                    showSuccessIndicator(\.showExportKeybindsSuccessIndicator)
                }
            } catch {
                log.error("Error exporting keybinds: \(ApplicationLogPrivacy.errorDescription(error))")
            }
        }
    }

    /// Resets keybinds to default values.
    func resetKeybinds() {
        Defaults.reset(.keybinds)
        showSuccessIndicator(\.showResetKeybindsSuccessIndicator)
    }

    private func showSuccessIndicator(_ keyPath: ReferenceWritableKeyPath<AdvancedConfigurationModel, Bool>) {
        Task {
            withAnimation(.smooth(duration: 0.5)) {
                self[keyPath: keyPath] = true
            }

            try? await Task.sleep(for: .seconds(2))

            withAnimation(.smooth(duration: 0.5)) {
                self[keyPath: keyPath] = false
            }
        }
    }
}

struct AdvancedConfigurationView: View {
    @Environment(\.openURL) private var openURL

    @StateObject private var model = AdvancedConfigurationModel()

    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.ignoreLowPowerMode) var ignoreLowPowerMode
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.ignoreFullscreen) var ignoreFullscreen
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.sizeIncrement) var sizeIncrement

    @State private var isConfirmingResetKeybinds: Bool = false

    private var showLowPowerModeWarning: Bool {
        animateWindowResizes && !ignoreLowPowerMode && model.isLowPowerModeEnabled
    }

    var body: some View {
        Form {
            generalSection
            keybindsSection
        }
        .settingsFormPanel()
        .onAppear(perform: model.startTracking)
        .onDisappear(perform: model.stopTracking)
    }

    private var generalSection: some View {
        Section {
            if #available(macOS 15.0, *) {
                Toggle(isOn: $useSystemWindowManagerWhenAvailable) {
                    SettingsRowLabel(
                        "Use macOS window manager when available",
                        detail: "Prefer Apple’s native window management APIs on supported systems.",
                        systemImage: "macwindow"
                    )
                }
            }

            Toggle(isOn: $animateWindowResizes) {
                SettingsRowLabel(
                    "Animate window resize",
                    detail: "Smoothly animate window movement when power conditions allow it.",
                    systemImage: "sparkles"
                )
            }

            if showLowPowerModeWarning {
                lowPowerModeWarningRow
            }

            Toggle(isOn: $ignoreFullscreen) {
                SettingsRowLabel(
                    "Ignore fullscreen windows",
                    detail: "Leave fullscreen apps out of Line’s window actions.",
                    systemImage: "arrow.down.right.and.arrow.up.left"
                )
            }

            Toggle(isOn: $hapticFeedback) {
                SettingsRowLabel(
                    "Haptic feedback",
                    detail: "Play subtle feedback for supported interactions.",
                    systemImage: "waveform.path"
                )
            }

            pixelSlider(
                Text("Size increment"),
                value: $sizeIncrement.doubleBinding,
                in: 5...50,
                step: 5
            )
        } header: {
            Text("General", comment: "Section header shown in settings")
        }
    }

    private var keybindsSection: some View {
        Section {
            Text("Import, export, or reset the complete shortcut configuration.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                keybindsButton(
                    "Import",
                    systemImage: "square.and.arrow.down",
                    showsSuccessIndicator: model.showImportKeybindsSuccessIndicator,
                    action: model.importPrompt
                )

                keybindsButton(
                    "Export",
                    systemImage: "square.and.arrow.up",
                    showsSuccessIndicator: model.showExportKeybindsSuccessIndicator,
                    action: model.exportPrompt
                )

                Button(role: .destructive) {
                    isConfirmingResetKeybinds = true
                } label: {
                    keybindsButtonLabel(
                        "Reset",
                        systemImage: "arrow.counterclockwise",
                        showsSuccessIndicator: model.showResetKeybindsSuccessIndicator
                    )
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .alert("Reset keybinds?", isPresented: $isConfirmingResetKeybinds) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive, action: model.resetKeybinds)
            } message: {
                Text("This will reset all keybinds to their original defaults.")
            }
        } header: {
            Text("Keybinds", comment: "Section header shown in settings")
        }
    }

    private var lowPowerModeWarningRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text("Window animations are unavailable in Low Power Mode.")
            } icon: {
                Image(systemName: "bolt.slash")
            }
            .font(.caption)
            .foregroundStyle(.orange)

            Spacer()

            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                Button("Battery Settings") {
                    openURL(url)
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func keybindsButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        showsSuccessIndicator: Bool,
        action: @escaping () -> ()
    ) -> some View {
        Button(action: action) {
            keybindsButtonLabel(title, systemImage: systemImage, showsSuccessIndicator: showsSuccessIndicator)
        }
    }

    private func keybindsButtonLabel(
        _ title: LocalizedStringKey,
        systemImage: String,
        showsSuccessIndicator: Bool
    ) -> some View {
        Label {
            HStack(spacing: 4) {
                Text(title)

                if showsSuccessIndicator {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .bold()
                }
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private func pixelSlider(
        _ title: Text,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                HStack(spacing: 2) {
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit()

                    Text("px", comment: "Unit symbol: pixels")
                }
                .foregroundStyle(.secondary)
            } label: {
                title
            }

            Slider(value: value, in: range, step: step)
        }
    }
}

