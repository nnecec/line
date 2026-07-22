//
//  WindowUtility.swift
//  Line
//
//  Created by nnecec on 2025-09-06.
//

import AppKit
import Defaults
import Scribe

/// Lightweight window metadata derived solely from `CGWindowListCopyWindowInfo`.
/// Prefer this over `Window` when only IDs, frames, or owner PIDs are needed (no AX calls).
struct LightweightWindowInfo: Equatable {
    let cgWindowID: CGWindowID
    let frame: CGRect
    let ownerPID: pid_t
}

/// This enum is in charge of fetching windows in the user's workspace, which will be used by Line.
@Loggable(style: .static)
enum WindowUtility {
    /// Get the target window, depending on the user's preferences. This could be the frontmost window, or the window under the cursor.
    /// - Returns: The target window
    static func userDefinedTargetWindow() -> Window? {
        var result: Window?

        log.info("Getting window at cursor...")

        if Defaults[.resizeWindowUnderCursor],
           let mouseLocation = CGEvent.mouseLocation,
           let window = windowAtPosition(mouseLocation) {
            result = window
        }

        if result == nil {
            do {
                log.info("Getting frontmost window...")

                result = try frontmostWindow()
            } catch {
                log.warn("Failed to get frontmost window: \(ApplicationLogPrivacy.errorDescription(error))")
            }
        }

        return result
    }

    /// Get the frontmost Window
    /// - Returns: Window?
    static func frontmostWindow() throws -> Window? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return try Window(pid: app.processIdentifier)
    }

    /// Get the Window at a given position.
    /// - Parameter position: The position to check for
    /// - Returns: The window at the given position, if any
    static func windowAtPosition(_ position: CGPoint) -> Window? {
        // Try SkyLight first, as it is faster and doesn't deadlock on own process
        if let windowID = SkyLightToolBelt.windowIDAtPosition(position),
           let window = try? Window.fromWindowID(windowID) {
            return window
        }

        do {
            // If we can find the window at a point using the Accessibility API, return it
            if let element = try AXUIElement.systemWide.getElementAtPosition(position),
               let windowElement: AXUIElement = try element.getValue(.window) {
                return try Window(element: windowElement)
            }
        } catch {
            log.warn("Failed to determine element at position: \(ApplicationLogPrivacy.errorDescription(error))")
        }

        // If the previous method didn't work, loop through all windows on-screen and return the first one that contains the desired point
        let windowList = windowList()
        if let window = (windowList.first { $0.frame.contains(position) }) {
            return window
        }

        return nil
    }

    /// Get a list of all windows currently shown, that are likely to be resizable by Line.
    /// Builds full `Window` values via Accessibility; prefer `lightweightWindowList()` when only
    /// IDs/frames/PIDs are required.
    static func windowList() -> [Window] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else {
            return []
        }

        var windowList: [Window] = []
        for windowInfo in list {
            if let window = try? Window.fromWindowInfo(windowInfo) {
                windowList.append(window)
            }
        }

        return windowList
    }

    /// Parse a single `CGWindowListCopyWindowInfo` entry into lightweight metadata.
    /// Applies the same CG-only filters as `Window.fromWindowInfo` (alpha, layer) without AX.
    static func lightweightInfo(from windowInfo: [String: AnyObject]) -> LightweightWindowInfo? {
        guard
            let alpha = windowInfo[kCGWindowAlpha as String] as? Double, alpha > 0.01,
            let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
            let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
            let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
            let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else {
            return nil
        }

        if let level = windowInfo[kCGWindowLayer as String] as? CGWindowLevel,
           level < kCGNormalWindowLevel || level > kCGDraggingWindowLevel {
            return nil
        }

        return LightweightWindowInfo(cgWindowID: windowID, frame: frame, ownerPID: pid)
    }

    /// On-screen windows as CG metadata only (IDs, frames, owner PIDs). No Accessibility calls.
    /// Uses the same list options and CG-side filters as `windowList()`.
    /// Order matches CG z-order (front to back). Frames share the coordinate space used by AX
    /// (`Window.frame` / `fromWindowInfo` bound matching).
    static func lightweightWindowList() -> [LightweightWindowInfo] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else {
            return []
        }

        return list.compactMap { lightweightInfo(from: $0) }
    }
}
