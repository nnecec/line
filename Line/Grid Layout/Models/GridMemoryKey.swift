//
//  GridMemoryKey.swift
//  Line
//
//  Key for storing grid size memory per app and screen.
//  Created by nnecec on 2024-12-30.

//

import Foundation

/// Key for grid size memory: app bundle ID + screen identifier.
struct GridMemoryKey: Hashable {
    let bundleId: String
    let screenIdentifier: String

    /// String key for storage in Defaults.
    var storageKey: String {
        "\(bundleId)::\(screenIdentifier)"
    }

    init(bundleId: String, screenIdentifier: String) {
        self.bundleId = bundleId
        self.screenIdentifier = screenIdentifier
    }

    /// Parse from storage key string.
    init?(storageKey: String) {
        let parts = storageKey.split(separator: "::", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        self.bundleId = String(parts[0])
        self.screenIdentifier = String(parts[1])
    }
}
