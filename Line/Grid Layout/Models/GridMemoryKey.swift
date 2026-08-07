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
}

/// A valid persistent app+screen grid size record.
struct GridMemoryRecord: Identifiable, Equatable {
    let key: GridMemoryKey
    let size: GridSize

    var id: GridMemoryKey { key }
}
