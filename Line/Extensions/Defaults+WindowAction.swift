//
//  Defaults+WindowAction.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//

import Defaults
import Foundation

extension Defaults.Keys {
    /// User-configured keybinds, using BoundWindowAction.
    static let keybinds = Key<[BoundWindowAction]>(
        "keybinds",
        default: BoundWindowAction.defaultKeybinds
    )
}
