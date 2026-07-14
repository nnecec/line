//
//  StashDirection.swift
//  Line
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation

enum StashEdge: String, Codable, CustomDebugStringConvertible {
    case left
    case right
    case bottom

    var debugDescription: String {
        rawValue
    }

    var isHorizontal: Bool {
        self == .left || self == .right
    }
}

// MARK: - Helpers

extension BoundWindowAction {
    var stashEdge: StashEdge? {
        action.stashEdge
    }
}

extension WindowAction {
    var stashEdge: StashEdge? {
        if case let .stash(_, edge) = self {
            return edge
        }
        if case let .custom(custom) = self {
            let name = custom.name.lowercased()
            if name.contains("stash") {
                if name.contains("left") {
                    return .left
                } else if name.contains("right") {
                    return .right
                } else if name.contains("bottom") {
                    return .bottom
                }
            }
        }
        return nil
    }
}
