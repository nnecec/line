//
//  SettingsViewModifiers.swift
//  Line
//
//  Shared form layout and platform availability helpers for settings panes.
//

import SwiftUI

extension View {
    /// Standard grouped form chrome for settings detail panes.
    ///
    /// The Form fills the detail column so the scroll indicator sits on the panel's
    /// trailing edge (System Settings style). Horizontal inset comes from
    /// `.formStyle(.grouped)` section chrome - do not add horizontal
    /// `contentMargins` or a narrow `maxWidth` on the Form itself, or the
    /// scrollbar tracks the content column instead of the panel edge.
    ///
    /// - Parameter maxWidth: Retained for call-site compatibility; ignored so the
    ///   scroll view can span the full detail width.
    @ViewBuilder
    func settingsFormPanel(maxWidth _: CGFloat = 520) -> some View {
        if #available(macOS 14.0, *) {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 8, for: .scrollContent)
                .contentMargins(.bottom, 24, for: .scrollContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
