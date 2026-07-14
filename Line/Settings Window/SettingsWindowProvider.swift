//
//  SettingsWindowProvider.swift
//  Line
//
//  Created by nnecec on 2026-07-03.
//

import AppKit
import SwiftUI

struct SettingsWindowProvider {
    static let unavailable = SettingsWindowProvider {
        nil
    }

    private let currentWindow: @MainActor () -> NSWindow?

    init(currentWindow: @escaping @MainActor () -> NSWindow?) {
        self.currentWindow = currentWindow
    }

    @MainActor
    var window: NSWindow? {
        currentWindow()
    }
}

private struct SettingsWindowProviderKey: EnvironmentKey {
    static let defaultValue: SettingsWindowProvider = .unavailable
}

extension EnvironmentValues {
    var settingsWindowProvider: SettingsWindowProvider {
        get { self[SettingsWindowProviderKey.self] }
        set { self[SettingsWindowProviderKey.self] = newValue }
    }
}
