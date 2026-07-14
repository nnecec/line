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

    case grid
    case preview

    case behavior
    case keybinds

    case permissions
    case advanced
    case excludedApps
    case about

    var title: String {
        switch self {
        case .grid: .init(localized: "Settings tab: Grid", defaultValue: "Grid")
        case .preview: .init(localized: "Settings tab: Preview", defaultValue: "Preview")
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
        case .grid: Image(systemName: "square.grid.3x3")
        case .preview: Image(systemName: "inset.filled.center.rectangle")
        case .behavior: Image(systemName: "gearshape.fill")
        case .keybinds: Image(systemName: "keyboard.fill")
        case .permissions: Image(systemName: "checkmark.shield.fill")
        case .advanced: Image(systemName: "wrench.adjustable.fill")
        case .excludedApps: Image(systemName: "xmark.octagon.fill")
        case .about: Image(systemName: "info.circle.fill")
        }
    }

    @ViewBuilder func view() -> some View {
        switch self {
        case .grid:
            if #available(macOS 15.0, *) {
                GridConfigurationView()
            } else {
                Text("Grid configuration requires macOS 15.0 or later")
            }
        case .preview: PreviewConfigurationView()
        case .behavior: BehaviorConfigurationView()
        case .keybinds: KeybindsConfigurationView()
        case .permissions: PermissionsConfigurationView()
        case .advanced: AdvancedConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .about: AboutConfigurationView()
        }
    }

    static let themingTabs: [Self] = [.grid, .preview]
    static let settingsTabs: [Self] = [.behavior, .keybinds]
    static let loopTabs: [Self] = [.permissions, .advanced, .excludedApps, .about]
}
