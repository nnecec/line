//
//  VersionDisplay.swift
//  Line
//
//  Created by nnecec on 2026-01-22.
//

import SwiftUI

struct VersionDisplay {
    let shortDisplay: String
    let fullDisplay: String
    let isPrerelease: Bool

    static let unknown: VersionDisplay = .init(shortDisplay: "Unknown", fullDisplay: "Unknown", isPrerelease: false)

    static let current: VersionDisplay = {
        guard let version = Bundle.main.appVersion,
              let build = Bundle.main.appBuild
        else {
            return .unknown
        }

        #if !RELEASE
            return .format(version: version, build: build, isPrerelease: true)
        #else
            return .format(version: version, build: build, isPrerelease: false)
        #endif
    }()

    static func format(version: String?, build: Int?, isPrerelease: Bool) -> VersionDisplay {
        guard let version else {
            return .unknown
        }

        // Strip legacy marker characters that may still appear in CFBundleShortVersionString.
        let baseVersion = version
            .replacingOccurrences(of: "🧪", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let shouldTreatAsPrerelease = isPrerelease

        let buildString = if let build {
            "(\(build))"
        } else {
            ""
        }

        let shortDisplay: String = if shouldTreatAsPrerelease {
            "\(baseVersion) \(buildString)".trimmingCharacters(in: .whitespaces)
        } else {
            baseVersion
        }

        let fullDisplay: String = if shouldTreatAsPrerelease {
            "\(baseVersion) \(buildString)".trimmingCharacters(in: .whitespaces)
        } else {
            "\(baseVersion) \(buildString)".trimmingCharacters(in: .whitespaces)
        }

        return VersionDisplay(
            shortDisplay: shortDisplay,
            fullDisplay: fullDisplay,
            isPrerelease: shouldTreatAsPrerelease
        )
    }
}
