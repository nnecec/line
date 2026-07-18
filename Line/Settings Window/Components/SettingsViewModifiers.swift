//
//  SettingsViewModifiers.swift
//  Line
//
//  Shared form layout and platform availability helpers for settings panes.
//

import SwiftUI

extension View {
    /// Standard grouped form chrome for settings detail panes.
    @ViewBuilder
    func settingsFormPanel(maxWidth: CGFloat = 520) -> some View {
        if #available(macOS 14.0, *) {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 16, for: .scrollContent)
                .contentMargins(.horizontal, 24, for: .scrollContent)
                .contentMargins(.bottom, 24, for: .scrollContent)
                .frame(maxWidth: maxWidth + 48) // Content width plus horizontal padding
        } else {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: maxWidth + 48)
        }
    }

    /// Soft progressive blur at scroll edges on macOS 26+.
    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }

    /// Content margins for scroll content when the API is available.
    @ViewBuilder
    func contentMarginsIfAvailable(_ edges: Edge.Set, _ length: CGFloat) -> some View {
        if #available(macOS 14.0, *) {
            contentMargins(edges, length, for: .scrollContent)
        } else {
            self
        }
    }
}
