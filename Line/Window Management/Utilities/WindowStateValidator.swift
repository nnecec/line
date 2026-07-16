//
//  WindowStateValidator.swift
//  Line
//
//  Created by Claude on 2026-07-16.
//

import Defaults

/// Centralized utilities for window state validation and manipulation checks.
/// Consolidates repeated window state logic from coordinators, managers, and utilities.
enum WindowStateValidator {

    // MARK: - Manipulation Checks

    /// Checks if a window can be manipulated (resized, moved, etc.).
    ///
    /// A window can be manipulated if:
    /// - It is not from an excluded application (when `checkExclusion` is true)
    /// - It is not fullscreen (when `ignoreFullscreen` setting is enabled)
    ///
    /// - Parameters:
    ///   - window: The window to check
    ///   - ignoreFullscreen: Whether to check fullscreen state (default: uses Defaults[.ignoreFullscreen])
    ///   - checkExclusion: Whether to check if the app is excluded (default: true)
    /// - Returns: `true` if the window can be manipulated
    static func canManipulate(
        _ window: Window,
        ignoreFullscreen: Bool? = nil,
        checkExclusion: Bool = true
    ) -> Bool {
        // Check app exclusion
        if checkExclusion && window.isAppExcluded {
            return false
        }

        // Check fullscreen state
        let shouldIgnoreFullscreen = ignoreFullscreen ?? Defaults[.ignoreFullscreen]
        if shouldIgnoreFullscreen && window.fullscreen {
            return false
        }

        return true
    }

    /// Checks if a window can be resized.
    ///
    /// Uses pre-resolved properties when available to avoid repeated AX calls.
    ///
    /// - Parameters:
    ///   - window: The window to check
    ///   - resolvedProperties: Optional pre-resolved properties to use instead of querying
    /// - Returns: `true` if the window can be resized
    static func canResize(
        _ window: Window,
        resolvedProperties: Window.ResolvedProperties? = nil
    ) -> Bool {
        if let resolvedProperties {
            return resolvedProperties.isResizable
        }
        return window.isResizable
    }

    /// Checks if a window should be ignored for focus navigation or window operations.
    ///
    /// A window should be ignored if:
    /// - It is from an excluded application (when `checkExclusion` is true)
    /// - It is fullscreen and `ignoreFullscreen` is enabled (when `checkFullscreen` is true)
    ///
    /// - Parameters:
    ///   - window: The window to check
    ///   - checkFullscreen: Whether to check fullscreen state (default: true)
    ///   - checkExclusion: Whether to check if the app is excluded (default: true)
    /// - Returns: `true` if the window should be ignored
    static func shouldIgnore(
        _ window: Window,
        checkFullscreen: Bool = true,
        checkExclusion: Bool = true
    ) -> Bool {
        // Check app exclusion
        if checkExclusion && window.isAppExcluded {
            return true
        }

        // Check fullscreen state
        if checkFullscreen && window.fullscreen && Defaults[.ignoreFullscreen] {
            return true
        }

        return false
    }

    // MARK: - Fullscreen Checks

    /// Checks if a window is fullscreen and should be ignored based on settings.
    ///
    /// - Parameter window: The window to check
    /// - Returns: `true` if the window is fullscreen and should be ignored
    static func isFullscreenAndIgnored(_ window: Window) -> Bool {
        window.fullscreen && Defaults[.ignoreFullscreen]
    }
}
