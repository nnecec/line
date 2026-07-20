//
//  SettingsTab.swift
//  Line
//
//  Created by nnecec on 2025-12-05.
//

import SwiftUI

@MainActor
enum SettingsTab: CaseIterable, Hashable, Identifiable {
    var id: Self { self }

    case preview
    case gridLayout

    case behavior
    case keybinds

    case permissions
    case advanced
    case excludedApps
    case about

    var title: String {
        switch self {
        case .preview: .init(localized: "Settings tab: Preview", defaultValue: "Preview")
        case .gridLayout: .init(localized: "Settings tab: Grid Layout", defaultValue: "Grid Layout")
        case .behavior: .init(localized: "Settings tab: General", defaultValue: "General")
        case .keybinds: .init(localized: "Settings tab: Keyboard Shortcuts", defaultValue: "Keyboard Shortcuts")
        case .permissions: .init(localized: "Settings tab: Permissions", defaultValue: "Permissions")
        case .advanced: .init(localized: "Settings tab: Advanced", defaultValue: "Advanced")
        case .excludedApps: .init(localized: "Settings tab: Excluded Apps", defaultValue: "Excluded Apps")
        case .about: .init(localized: "Settings tab: About Line", defaultValue: "About Line")
        }
    }

    var image: Image {
        switch self {
        case .preview: Image(systemName: "rectangle.dashed")
        case .gridLayout: Image(systemName: "square.grid.3x3")
        case .behavior: Image(systemName: "gearshape")
        case .keybinds: Image(systemName: "keyboard")
        case .permissions: Image(systemName: "lock.shield")
        case .advanced: Image(systemName: "slider.horizontal.3")
        case .excludedApps: Image(systemName: "app.badge.checkmark")
        case .about: Image(systemName: "info.circle")
        }
    }

    @ViewBuilder func view() -> some View {
        switch self {
        case .preview:
            if #available(macOS 15.0, *) {
                PreviewConfigurationView()
            } else {
                Text("Preview configuration requires macOS 15.0 or later")
            }
        case .gridLayout:
            if #available(macOS 15.0, *) {
                GridLayoutConfigurationView()
            } else {
                Text("Grid layout configuration requires macOS 15.0 or later")
            }
        case .behavior: BehaviorConfigurationView()
        case .keybinds: KeybindsConfigurationView()
        case .permissions: PermissionsConfigurationView()
        case .advanced: AdvancedConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .about: AboutConfigurationView()
        }
    }

    static let appearanceTabs: [Self] = [.preview, .gridLayout]
    static let settingsTabs: [Self] = [.behavior, .keybinds]
    static let loopTabs: [Self] = [.permissions, .advanced, .excludedApps, .about]
}
