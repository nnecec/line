//
//  Icon.swift
//  Line
//
//  Created by nnecec on 2024-06-07.
//

import Foundation

/// Unlock Flow:
/// - Developer: 0 actions **(Debug builds only)**
/// - Classic: 0 actions
/// - Holo: 25 actions
/// - Rosé Pine: 50 actions
/// - Meta Line: 100 actions
/// - Keycap: 200 actions
/// - White: 400 actions
/// - Black: 500 actions
/// - Daylight: 1000 actions
/// - Neon: 1500 actions
/// - Synthwave Sunset: 2000 actions
/// - Black Hole: 2500 actions
/// - Summer: 3000 actions
/// - Master: 5000 actions
struct Icon: Hashable {
    var name: String
    var assetName: String
    var unlockTime: Int
    var unlockMessage: String?

    var isDefault: Bool {
        assetName == Bundle.main.infoDictionary?["CFBundleIconName"] as? String
    }

    var isSelectable: Bool {
        IconManager.returnUnlockedIcons().contains(self)
    }

    #if RELEASE
        /// Remove developer icon in release builds
        static let all: [Icon] = [
            .classic,
            .holo,
            .rosePine,
            .metaLine,
            .keycap,
            .white,
            .black,
            .daylight,
            .neon,
            .synthwaveSunset,
            .blackHole,
            .summer,
            .master
        ]
    #else
        static let all: [Icon] = [
            .developer,
            .classic,
            .holo,
            .rosePine,
            .metaLine,
            .keycap,
            .white,
            .black,
            .daylight,
            .neon,
            .synthwaveSunset,
            .blackHole,
            .summer,
            .master
        ]
    #endif
}

// MARK: - Kai Azim

extension Icon {
    static let classic = Icon(
        name: .init(localized: .init("Icon Name: Classic", defaultValue: "Classic")),
        assetName: "AppIcon-Classic",
        unlockTime: 0
    )
    static let holo = Icon(
        name: .init(localized: .init("Icon Name: Holo", defaultValue: "Holo")),
        assetName: "AppIcon-Holo",
        unlockTime: 25,
        unlockMessage: String(
            localized: "Icon Unlock Message: Holo",
            defaultValue: """
            You've already completed 25 actions! As a reward, here's new icon: \(.init(localized: .init("Icon Name: Holo", defaultValue: "Holo"))). Keep going to unlock new icons!
            """,
            comment: "Message that is shown when a new icon is unlocked"
        )
    )
    static let rosePine = Icon(
        name: .init(localized: .init("Icon Name: Rosé Pine", defaultValue: "Rosé Pine")),
        assetName: "AppIcon-Rose Pine",
        unlockTime: 50
    )
    static let metaLine = Icon(
        name: .init(localized: .init("Icon Name: Meta Line", defaultValue: "Meta Line")),
        assetName: "AppIcon-Meta Line",
        unlockTime: 100
    )
    static let keycap = Icon(
        name: .init(localized: .init("Icon Name: Keycap", defaultValue: "Keycap")),
        assetName: "AppIcon-Keycap",
        unlockTime: 200
    )
    static let white = Icon(
        name: .init(localized: .init("Icon Name: White", defaultValue: "White")),
        assetName: "AppIcon-White",
        unlockTime: 400
    )
    static let black = Icon(
        name: .init(localized: .init("Icon Name: Black", defaultValue: "Black")),
        assetName: "AppIcon-Black",
        unlockTime: 500
    )
    static let master = Icon(
        name: .init(localized: .init("Icon Name: Line Master", defaultValue: "Line Master")),
        assetName: "AppIcon-Line Master",
        unlockTime: 5000,
        unlockMessage: String(
            localized: "Icon Unlock Message: Line Master",
            defaultValue: "5000 actions completed! Your progress has earned a new milestone. Enjoy your well-deserved reward: a brand-new icon!",
            comment: "Message that is shown when a new icon is unlocked"
        )
    )
}

// MARK: - Greg Lassale

extension Icon {
    static let neon = Icon(
        name: .init(localized: .init("Icon Name: Neon", defaultValue: "Neon")),
        assetName: "AppIcon-Neon",
        unlockTime: 1500
    )
    static let synthwaveSunset = Icon(
        name: .init(localized: .init("Icon Name: Synthwave Sunset", defaultValue: "Synthwave Sunset")),
        assetName: "AppIcon-Synthwave Sunset",
        unlockTime: 2000
    )
    static let blackHole = Icon(
        name: .init(localized: .init("Icon Name: Black Hole", defaultValue: "Black Hole")),
        assetName: "AppIcon-Black Hole",
        unlockTime: 2500
    )
}

// MARK: - JSDev

extension Icon {
    static let developer = Icon(
        name: .init(localized: .init("Icon Name: Developer", defaultValue: "Developer")),
        assetName: "AppIcon-Developer",
        unlockTime: 0
    )

    static let summer = Icon(
        name: .init(localized: .init("Icon Name: Summer", defaultValue: "Summer")),
        assetName: "AppIcon-Summer",
        unlockTime: 3000
    )
}

// MARK: - 0w0x

extension Icon {
    static let daylight = Icon(
        name: .init(localized: .init("Icon Name: Daylight", defaultValue: "Daylight")),
        assetName: "AppIcon-Daylight",
        unlockTime: 1000
    )
}
