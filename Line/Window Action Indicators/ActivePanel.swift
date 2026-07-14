//
//  ActivePanel.swift
//  Line
//
//  Created by nnecec on 2025-09-16.
//

import AppKit

@MainActor
final class ActivePanel: NSPanel {
    @objc dynamic var hasKeyAppearance: Bool {
        true
    }

    @objc dynamic var hasActiveAppearance: Bool {
        true
    }
}
