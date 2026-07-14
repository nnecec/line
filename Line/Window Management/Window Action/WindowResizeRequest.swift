//
//  WindowResizeRequest.swift
//  Line
//
//  Created via architecture refactor on 2026-07-02.
//
//  Immutable value object representing a window resize request.
//  Replaces the stateful ResizeContext with a pure data carrier.
//  This eliminates manual state synchronization and makes the computation layer testable.
//

import AppKit
import CoreGraphics
import Foundation

/// Immutable value object representing a window resize request.
/// Contains all the data needed to calculate a target frame, without any mutable state.
struct WindowResizeRequest: Equatable {
    let window: Window?
    let action: WindowAction
    let screen: NSScreen
    let bounds: CGRect
    let padding: PaddingConfiguration

    /// Resolved window properties (cached at creation time).
    let windowProperties: WindowProperties?

    /// Resolved window record (cached at creation time).
    let record: WindowRecord?

    /// Visible window frames used by fill-available-space calculations.
    /// When nil, the calculator snapshots the current workspace windows.
    let visibleWindowFrames: [CGRect]?

    init(
        window: Window?,
        action: WindowAction,
        screen: NSScreen,
        bounds: CGRect,
        padding: PaddingConfiguration,
        windowProperties: WindowProperties? = nil,
        record: WindowRecord? = nil,
        visibleWindowFrames: [CGRect]? = nil
    ) {
        self.window = window
        self.action = action
        self.screen = screen
        self.bounds = bounds
        self.padding = padding

        // Resolve properties at creation time (immutable snapshot)
        if let windowProperties {
            self.windowProperties = windowProperties
        } else if let window {
            self.windowProperties = WindowProperties(window: window)
        } else {
            self.windowProperties = nil
        }
        self.record = record
        self.visibleWindowFrames = visibleWindowFrames
    }

    /// Convenience initializer that uses screen's safe frame as bounds.
    init(
        window: Window?,
        action: WindowAction,
        screen: NSScreen,
        padding: PaddingConfiguration? = nil
    ) {
        let resolvedPadding = padding ?? PaddingConfiguration.getConfiguredPadding(for: screen)

        self.init(
            window: window,
            action: action,
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: resolvedPadding
        )
    }

    /// Creates a derived request with a different action (for recursive calculations like undo).
    func withAction(_ newAction: WindowAction) -> WindowResizeRequest {
        WindowResizeRequest(
            window: window,
            action: newAction,
            screen: screen,
            bounds: bounds,
            padding: padding,
            windowProperties: windowProperties,
            record: record,
            visibleWindowFrames: visibleWindowFrames
        )
    }

    /// The bounds after applying padding (used for frame calculations).
    var paddedBounds: CGRect {
        padding.applyToBounds(bounds, screen: screen)
    }
}

/// Snapshot of window properties at a point in time.
/// This avoids re-querying AX properties during calculation.
struct WindowProperties: Equatable {
    let frame: CGRect
    let isResizable: Bool

    init(window: Window) {
        self.frame = window.frame
        self.isResizable = window.isResizable
    }

    init(frame: CGRect, isResizable: Bool) {
        self.frame = frame
        self.isResizable = isResizable
    }
}

/// Cached window record data.
struct WindowRecord: Equatable {
    let initialFrame: CGRect?
    let lastAction: WindowAction?
}
