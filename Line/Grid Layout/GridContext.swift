//
//  GridContext.swift
//  Line
//
//  Context for grid mode operation.
//  Created by nnecec on 2024-12-30.

//

import AppKit
import Foundation

/// Context holding grid mode state during an active grid session.
struct GridContext {
    let window: Window?
    let screen: NSScreen
    let geometry: GridGeometry
    let template: GridTemplate
    let bundleId: String?
}
