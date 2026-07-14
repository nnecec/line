//
//  ApplicationLogging.swift
//  Line
//

import CoreGraphics
import Foundation
import Scribe

enum ApplicationBuildMode {
    case debug
    case production

    static var current: Self {
        #if DEBUG
            .debug
        #else
            .production
        #endif
    }
}

enum ApplicationLoggingPolicy {
    static func minimumLevel(for mode: ApplicationBuildMode) -> LogLevel {
        switch mode {
        case .debug:
            .debug
        case .production:
            .warning
        }
    }
}

/// Centralizes the strings that are allowed to reach Scribe. Scribe currently emits formatted
/// strings to unified logging as public data, so descriptions redact user content in every build
/// before interpolation rather than relying on build configuration or the logging backend.
enum ApplicationLogPrivacy {
    static func windowDescription(id: CGWindowID) -> String {
        "Window(id: \(id))"
    }

    static func urlDescription(_ url: URL) -> String {
        if let scheme = url.scheme {
            "\(scheme):<redacted>"
        } else {
            "<redacted-url>"
        }
    }

    static func fileDescription(_: URL) -> String {
        "<redacted-path>"
    }

    static func errorDescription(_ error: Error) -> String {
        String(reflecting: type(of: error))
    }
}
