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
        let parts = storageKey.components(separatedBy: "::")
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty
        else {
            return nil
        }
        self.bundleId = parts[0]
        self.screenIdentifier = parts[1]
    }
}

/// A valid persistent app+screen grid size record.
struct GridMemoryRecord: Identifiable, Equatable {
    let key: GridMemoryKey
    let size: GridSize

    var id: String { key.storageKey }

    static func records(from memory: [String: GridSize]) -> [GridMemoryRecord] {
        memory.compactMap { storageKey, size in
            guard let key = GridMemoryKey(storageKey: storageKey) else { return nil }
            return GridMemoryRecord(key: key, size: size)
        }
        .sorted {
            if $0.key.bundleId != $1.key.bundleId {
                return $0.key.bundleId.localizedStandardCompare($1.key.bundleId) == .orderedAscending
            }
            return $0.key.screenIdentifier.localizedStandardCompare($1.key.screenIdentifier) == .orderedAscending
        }
    }
}
