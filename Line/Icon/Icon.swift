//
//  Icon.swift
//  Line
//
//  Created by nnecec on 2024-06-07.
//

import Foundation

struct Icon: Hashable {
    var name: String
    var assetName: String

    var isDefault: Bool {
        assetName == Bundle.main.infoDictionary?["CFBundleIconName"] as? String
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
        assetName: "AppIcon-Classic"
    )
    static let holo = Icon(
        name: .init(localized: .init("Icon Name: Holo", defaultValue: "Holo")),
        assetName: "AppIcon-Holo"
    )
    static let rosePine = Icon(
        name: .init(localized: .init("Icon Name: Rosé Pine", defaultValue: "Rosé Pine")),
        assetName: "AppIcon-Rose Pine"
    )
    static let metaLine = Icon(
        name: .init(localized: .init("Icon Name: Meta Line", defaultValue: "Meta Line")),
        assetName: "AppIcon-Meta Line"
    )
    static let keycap = Icon(
        name: .init(localized: .init("Icon Name: Keycap", defaultValue: "Keycap")),
        assetName: "AppIcon-Keycap"
    )
    static let white = Icon(
        name: .init(localized: .init("Icon Name: White", defaultValue: "White")),
        assetName: "AppIcon-White"
    )
    static let black = Icon(
        name: .init(localized: .init("Icon Name: Black", defaultValue: "Black")),
        assetName: "AppIcon-Black"
    )
    static let master = Icon(
        name: .init(localized: .init("Icon Name: Line Master", defaultValue: "Line Master")),
        assetName: "AppIcon-Line Master"
    )
}

// MARK: - Greg Lassale

extension Icon {
    static let neon = Icon(
        name: .init(localized: .init("Icon Name: Neon", defaultValue: "Neon")),
        assetName: "AppIcon-Neon"
    )
    static let synthwaveSunset = Icon(
        name: .init(localized: .init("Icon Name: Synthwave Sunset", defaultValue: "Synthwave Sunset")),
        assetName: "AppIcon-Synthwave Sunset"
    )
    static let blackHole = Icon(
        name: .init(localized: .init("Icon Name: Black Hole", defaultValue: "Black Hole")),
        assetName: "AppIcon-Black Hole"
    )
}

// MARK: - JSDev

extension Icon {
    static let developer = Icon(
        name: .init(localized: .init("Icon Name: Developer", defaultValue: "Developer")),
        assetName: "AppIcon-Developer"
    )

    static let summer = Icon(
        name: .init(localized: .init("Icon Name: Summer", defaultValue: "Summer")),
        assetName: "AppIcon-Summer"
    )
}

// MARK: - 0w0x

extension Icon {
    static let daylight = Icon(
        name: .init(localized: .init("Icon Name: Daylight", defaultValue: "Daylight")),
        assetName: "AppIcon-Daylight"
    )
}
