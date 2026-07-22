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

    /// Window properties snapshotted once when grid mode opens.
    /// Reused for hover previews so each mouse move skips AX `resolveState`.
    let windowProperties: WindowProperties?

    /// Window record snapshotted once when grid mode opens (for size modes that need it).
    let record: WindowRecord?

    init(
        window: Window?,
        screen: NSScreen,
        geometry: GridGeometry,
        template: GridTemplate,
        bundleId: String?,
        windowProperties: WindowProperties? = nil,
        record: WindowRecord? = nil
    ) {
        self.window = window
        self.screen = screen
        self.geometry = geometry
        self.template = template
        self.bundleId = bundleId
        self.windowProperties = windowProperties
        self.record = record
    }

    /// Build a preview resize using cached window properties — no AX / resolveState.
    @MainActor
    func preparePreview(for region: GridRegion) -> WindowResizeExecution.PreparedResize {
        let action = geometry.customAction(for: region)
        return WindowResizeExecution.prepareResolved(
            action: BoundWindowAction(action: action, keybind: []),
            window: window,
            screen: screen,
            bounds: geometry.workingBounds,
            padding: .zero,
            windowProperties: windowProperties,
            record: record
        )
    }
}
