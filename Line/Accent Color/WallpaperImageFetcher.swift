//
//  WallpaperImageFetcher.swift
//  Line
//
//  Created by nnecec on 2025-07-26.
//

import ScreenCaptureKit
import SwiftUI

final class WallpaperImageFetcher {
    static func wallpaperWindowIDs(
        from windows: [[CFString: Any]],
        screenFrame: CGRect,
        matchFrame: Bool
    ) -> [CGWindowID] {
        var wallpaperWindows = windows
            .filter { $0[kCGWindowOwnerName] as? String == "Dock" }
            .filter { ($0[kCGWindowName] as? String ?? "").contains("Wallpaper") }
            .filter { ($0[kCGWindowIsOnscreen] as? NSNumber)?.intValue == 1 }

        if matchFrame {
            wallpaperWindows = wallpaperWindows.filter { window in
                guard let bounds = windowBounds(from: window[kCGWindowBounds]) else {
                    return false
                }

                return bounds.origin.x == screenFrame.origin.x &&
                    bounds.origin.y == screenFrame.origin.y &&
                    bounds.width == screenFrame.width &&
                    bounds.height == screenFrame.height
            }
        }

        return wallpaperWindows.compactMap { wallpaperWindowID(from: $0[kCGWindowNumber]) }
    }

    /// Takes a screenshot of the main display.
    /// - Returns: An NSImage of the screenshot or nil if the operation fails.
    ///
    /// This method attempts to capture the desktop wallpaper using three approaches:
    /// 1. First, it tries to find and capture the Dock's wallpaper window directly that matches our screen dimensions
    /// 2. If that fails, it tries to capture any wallpaper window from the Dock (even if not on our exact screen)
    /// 3. As a last resort, it falls back to capturing the entire screen
    ///
    /// The direct wallpaper capture is preferred as it gets only the wallpaper without desktop icons,
    /// but requires accessibility permissions (this is accepted required for Line, so it's fine).
    /// The fallback ensures we still get colors even if permissions aren't granted.
    @concurrent
    func takeScreenshot() async throws -> NSImage? {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.displayBounds

        // First try to get the wallpaper window from the Dock app that matches our screen dimensions
        if let wallpaperImage = try? await captureWallpaperFromDock(screenFrame: screenFrame, matchFrame: true) {
            return wallpaperImage
        }

        // Second fallback: try to get any wallpaper window from the Dock, regardless of screen dimensions
        if let anyWallpaperImage = try? await captureWallpaperFromDock(screenFrame: screenFrame, matchFrame: false) {
            return anyWallpaperImage
        }

        // Final fallback: capture the full screen if we couldn't get any wallpaper window
        if let fallbackImage = try? await captureFullScreen() {
            return fallbackImage
        }

        throw WallpaperProcessorError.screenshotFailed
    }

    /// Attempts to capture the wallpaper window from the Dock app.
    /// - Parameters:
    ///   - screenFrame: The frame of the screen to capture.
    ///   - matchFrame: Whether to match the exact screen frame dimensions or get any wallpaper window.
    /// - Returns: An NSImage of the wallpaper or nil if the operation fails.
    ///
    /// This approach uses window capturing APIs to specifically target the Dock's wallpaper window.
    /// It requires appropriate permissions, but provides the cleanest capture of just the wallpaper.
    /// The method identifies the wallpaper window by filtering window properties from the Dock process.
    private func captureWallpaperFromDock(screenFrame: CGRect, matchFrame: Bool) async throws -> NSImage? {
        guard let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[CFString: Any]] else {
            throw WallpaperProcessorError.noWallpaperWindowsFound
        }

        let windowIDs = Self.wallpaperWindowIDs(
            from: windows,
            screenFrame: screenFrame,
            matchFrame: matchFrame
        )

        guard !windowIDs.isEmpty else {
            throw WallpaperProcessorError.noWallpaperWindowsFound
        }

        // Use the SkyLight API to capture high-quality images of the windows
        // This approach provides better results than the public APIs for this specific use case
        guard let image = SkyLightToolBelt.captureWindowList(windowIDs: windowIDs).first else {
            throw WallpaperProcessorError.wallpaperWindowCaptureFailed
        }

        return NSImage(cgImage: image, size: NSSize.zero)
    }

    private static func wallpaperWindowID(from value: Any?) -> CGWindowID? {
        switch value {
        case let windowID as CGWindowID:
            windowID
        case let number as NSNumber:
            CGWindowID(number.uint32Value)
        case let number as Int where number >= 0:
            CGWindowID(number)
        default:
            nil
        }
    }

    private static func windowBounds(from value: Any?) -> CGRect? {
        guard let dictionary = value as? NSDictionary else {
            return nil
        }

        return CGRect(dictionaryRepresentation: dictionary)
    }

    /// Fallback method to capture the entire screen using ScreenCaptureKit.
    /// This may include desktop icons and menubar, but it's better than nothing.
    /// - Returns: An NSImage of the screen or nil if the operation fails.
    ///
    /// This method uses ScreenCaptureKit to capture what's visible on screen.
    /// While this will include desktop icons and potentially other UI elements, it's a reliable
    /// fallback when we can't access the wallpaper window directly, and still provides
    /// useful color information in most cases.
    private func captureFullScreen() async throws -> NSImage? {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]

        // Get available content for screen capture
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        // Find the matching display
        guard let display = availableContent.displays.first(where: { scDisplay in
            scDisplay.frame == screen.frame
        }) else {
            throw WallpaperProcessorError.screenshotFailed
        }

        // Configure capture
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.showsCursor = false

        // Capture the screenshot
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return NSImage(cgImage: image, size: screen.frame.size)
    }
}
