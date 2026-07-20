//
//  PermissionsConfiguration.swift
//  Line
//
//  Created by nnecec on 2026-07-03.
//

import AppKit
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
            if model.isAccessibilityAccessGranted {
                grantedSection
            } else {
                onboardingSection
            }

            privacySection
        }
        .settingsFormPanel()
        .animation(.snappy(duration: 0.22), value: model.isAccessibilityAccessGranted)
        .onAppear(perform: model.startTracking)
        .onDisappear(perform: model.stopTracking)
    }

    // MARK: - Granted

    private var grantedSection: some View {
        Section {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.green)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.green.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.green.opacity(0.22), lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility is ready")
                        .font(.headline.weight(.semibold))

                    Text("Line can identify and resize windows you control.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                SettingsStatusBadge(
                    title: "Granted",
                    systemImage: "checkmark.seal.fill",
                    style: .success
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("System Access", comment: "Section header shown in settings")
        } footer: {
            Text(
                "You can revoke access anytime in System Settings → Privacy & Security → Accessibility.",
                comment: "Footer shown when Accessibility access is already granted"
            )
        }
    }

    // MARK: - Onboarding (not granted)

    private var onboardingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 52, height: 52)
                        .background(
                            Color.orange.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.24), lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Grant Accessibility to get started")
                                .font(.headline.weight(.semibold))

                            SettingsStatusBadge(
                                title: "Required",
                                systemImage: "exclamationmark.triangle.fill",
                                style: .warning
                            )
                        }

                        Text(
                            "macOS requires this permission before Line can read window frames or move windows. Line never reads document contents."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    permissionStep(
                        number: 1,
                        title: String(localized: "Request access", comment: "Permissions onboarding step title"),
                        detail: String(
                            localized: "Line shows the system prompt so you can allow Accessibility.",
                            comment: "Permissions onboarding step detail"
                        )
                    )
                    permissionStep(
                        number: 2,
                        title: String(localized: "Confirm in System Settings", comment: "Permissions onboarding step title"),
                        detail: String(
                            localized: "If the prompt is dismissed, open Accessibility and enable Line.",
                            comment: "Permissions onboarding step detail"
                        )
                    )
                    permissionStep(
                        number: 3,
                        title: String(localized: "Return here", comment: "Permissions onboarding step title"),
                        detail: String(
                            localized: "This page updates automatically once access is granted.",
                            comment: "Permissions onboarding step detail"
                        )
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        _ = AccessibilityManager.requestAccess()
                    } label: {
                        Label("Request Access…", systemImage: "hand.raised.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .help(
                        Text(
                            "Prompt macOS to grant Accessibility access",
                            comment: "Help text for accessibility request button"
                        )
                    )

                    Button {
                        openAccessibilitySettings()
                    } label: {
                        Label(
                            "Open System Settings",
                            systemImage: "gearshape"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help(
                        Text(
                            "Open System Settings → Privacy & Security → Accessibility",
                            comment: "Help text for opening Accessibility system settings"
                        )
                    )

                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("System Access", comment: "Section header shown in settings")
        } footer: {
            Text(
                "Without Accessibility, window actions and the grid overlay cannot run.",
                comment: "Footer shown when Accessibility access is missing"
            )
        }
    }

    private func permissionStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(
                    Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Privacy note

    private var privacySection: some View {
        Section {
            SettingsRowLabel(
                "What Line can access",
                detail: "Window frames, app identity, and screen layout needed to arrange windows. Not file contents, keystrokes outside Line triggers, or network data beyond update checks.",
                systemImage: "eye.slash"
            )
        } header: {
            Text("Privacy", comment: "Section header for permissions privacy note")
        }
    }

    private func openAccessibilitySettings() {
        // Prefer the deep link into Privacy & Security → Accessibility when available.
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
