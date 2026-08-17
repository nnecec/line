//
//  CustomWindowActionAnchor.swift
//  Line
//
//  Created by nnecec on 2024-01-01.
//

import SwiftUI

enum CustomWindowActionAnchor: Int, Codable, Identifiable {
    var id: Self { self }

    case none = -1
    case topLeft = 0
    case top = 1
    case topRight = 2
    case right = 3
    case bottomRight = 4
    case bottom = 5
    case bottomLeft = 6
    case left = 7
    case center = 8
    case macOSCenter = 9

    var isSelectable: Bool {
        self != .none
    }
}

extension CustomWindowActionAnchor {
    private static var iconActionCache: [CustomWindowActionAnchor: WindowAction] = [:]

    var iconAction: WindowAction? {
        // Prevents re-initializing the same action multiple times
        if let cachedAction = CustomWindowActionAnchor.iconActionCache[self] {
            return cachedAction
        }

        let newAction: WindowAction? = switch self {
        case .none: nil
        case .topLeft: .standard(.proportional(.topLeftQuarter))
        case .top: .standard(.proportional(.topHalf))
        case .topRight: .standard(.proportional(.topRightQuarter))
        case .right: .standard(.proportional(.rightHalf))
        case .bottomRight: .standard(.proportional(.bottomRightQuarter))
        case .bottom: .standard(.proportional(.bottomHalf))
        case .bottomLeft: .standard(.proportional(.bottomLeftQuarter))
        case .left: .standard(.proportional(.leftHalf))
        case .center: .standard(.center(.geometric))
        case .macOSCenter: .standard(.center(.macOS))
        }

        CustomWindowActionAnchor.iconActionCache[self] = newAction
        return newAction
    }
}
