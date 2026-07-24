//
//  URLDirectionResolver.swift
//  Line
//
//  Maps URL direction / action path tokens onto WindowDirection.
//

import Foundation

enum URLDirectionResolver {
    /// Resolve a direction token from `line://direction/<token>`.
    /// Accepts raw `WindowDirection` values plus short aliases (`left` → leftHalf).
    static func direction(for raw: String?) -> WindowDirection? {
        guard let raw else { return nil }
        let token = raw.lowercased()

        if let exact = WindowDirection.allCases.first(where: { $0.rawValue.lowercased() == token }) {
            return exact
        }

        switch token {
        case "left": return .leftHalf
        case "right": return .rightHalf
        case "top": return .topHalf
        case "bottom": return .bottomHalf
        default:
            let withoutHalf = token.replacingOccurrences(of: "half", with: "")
            return WindowDirection.allCases.first { $0.rawValue.lowercased() == withoutHalf }
        }
    }

    /// Resolve an action token from `line://action/<token>` against predefined directions only
    /// (custom / stash names are resolved by the handler via keybinds).
    static func predefinedAction(for raw: String?) -> WindowDirection? {
        guard let raw else { return nil }
        let token = raw.lowercased()
        return WindowDirection.allCases.first { $0.rawValue.lowercased() == token }
    }
}
