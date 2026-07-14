//
//  WindowAction+Defaults.swift
//  Line
//
//  Created by nnecec on 2025-11-11.
//

import Defaults
import Foundation

// MARK: Keybinds

extension BoundWindowAction {
    static let defaultKeybinds: [BoundWindowAction] = [
        BoundWindowAction(action: .standard(.maximize), keybind: [.kVK_Space]),
        BoundWindowAction(action: .standard(.center(.geometric)), keybind: [.kVK_Return]),
        BoundWindowAction(
            action: .cycle([
                .standard(.proportional(.topHalf)),
                .standard(.proportional(.topThird)),
                .standard(.proportional(.topTwoThirds))
            ]),
            keybind: [.kVK_UpArrow]
        ),
        BoundWindowAction(
            action: .cycle([
                .standard(.proportional(.bottomHalf)),
                .standard(.proportional(.bottomThird)),
                .standard(.proportional(.bottomTwoThirds))
            ]),
            keybind: [.kVK_DownArrow]
        ),
        BoundWindowAction(
            action: .cycle([
                .standard(.proportional(.rightHalf)),
                .standard(.proportional(.rightThird)),
                .standard(.proportional(.rightTwoThirds))
            ]),
            keybind: [.kVK_RightArrow]
        ),
        BoundWindowAction(
            action: .cycle([
                .standard(.proportional(.leftHalf)),
                .standard(.proportional(.leftThird)),
                .standard(.proportional(.leftTwoThirds))
            ]),
            keybind: [.kVK_LeftArrow]
        ),
        BoundWindowAction(action: .standard(.proportional(.topLeftQuarter)), keybind: [.kVK_UpArrow, .kVK_LeftArrow]),
        BoundWindowAction(action: .standard(.proportional(.topRightQuarter)), keybind: [.kVK_UpArrow, .kVK_RightArrow]),
        BoundWindowAction(action: .standard(.proportional(.bottomRightQuarter)), keybind: [.kVK_DownArrow, .kVK_RightArrow]),
        BoundWindowAction(action: .standard(.proportional(.bottomLeftQuarter)), keybind: [.kVK_DownArrow, .kVK_LeftArrow])
    ]
}
