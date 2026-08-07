//
//  WindowEngine.swift
//  Line
//
//  Created by nnecec on 2023-06-16.
//

import Defaults
import Scribe
import SwiftUI

/// Handles the low-level resize operations for windows.
/// Use `WindowActionEngine.apply()` as the main entry point for executing window actions.
@Loggable(style: .static)
enum WindowEngine {
    /// Performs the actual resize operation on a window.
    /// This is an internal method - callers should use `WindowActionEngine.apply()` instead.
    @MainActor
    static func performResize(preparedResize: WindowResizeExecution.PreparedResize) async throws {
        _ = try await performPreparedResize(preparedResize)
    }

    /// Legacy Drag Snap adapter. Mutable state stays outside the Prepared Resize execution seam.
    @MainActor
    static func performResize(context: ResizeContext) async throws {
        if context.resolvedWindowProperties == nil {
            await context.refreshResolvedState()
        }

        guard let outcome = try await performPreparedResize(.init(context: context)) else {
            return
        }

        context.resolvedWindowProperties = outcome.resolvedWindowProperties
        context.lastAppliedFrame = outcome.finalFrame
        context.resolvedRecord = outcome.resolvedRecord
    }

    @MainActor
    private static func performPreparedResize(
        _ preparedResize: WindowResizeExecution.PreparedResize
    ) async throws -> ResizeOutcome? {
        // Immediately return for no-op or focus-only actions
        guard let window = preparedResize.window,
              !preparedResize.action.isNoOp,
              !preparedResize.action.willFocusWindow
        else {
            return nil
        }

        // Quick actions are handled by WindowActionEngine
        let quickActions: [WindowDirection] = [.hide, .minimize, .fullscreen, .minimizeOthers]
        guard !quickActions.contains(preparedResize.action.direction) else { return nil }

        let resolvedWindowProperties = preparedResize.resolvedWindowProperties
            ?? Window.ResolvedProperties(from: window)
        let willChangeScreens = ScreenUtility.screenContaining(window) != preparedResize.screen
        let targetFrame = preparedResize.targetFrame
        log.info("Resizing \(window) to \(targetFrame.padded)")

        // Record first frame if needed
        await WindowRecords.shared.recordFirstIfNeeded(
            for: window,
            resolvedProperties: resolvedWindowProperties
        )

        let storeAsFrame = WindowRecords.shared.shouldStoreAsFinalFrame(preparedResize.action)

        // If this action doesn't require storage as a frame, then record it beforehand.
        // Otherwise, this action will be recorded *after* resizing, such that its final frame is considered if undoing.
        if !storeAsFrame {
            await WindowRecords.shared.record(
                window,
                resolvedProperties: resolvedWindowProperties,
                preparedResize.action
            )
        }

        let useSystemWM: Bool = if #available(macOS 15, *) {
            Defaults[.useSystemWindowManagerWhenAvailable]
        } else {
            false
        }

        if Defaults[.focusWindowOnResize] || useSystemWM {
            window.focus()
        }

        let finalFrame: CGRect

        // Attempt system window manager if possible
        if !willChangeScreens, useSystemWM,
           #available(macOS 15, *),
           await resizeWithSystemWindowManager(window: window, to: preparedResize.action) {
            finalFrame = window.frame
        } else {
            if resolvedWindowProperties.isFullscreen {
                // Otherwise, we obviously need to disable fullscreen to resize the window
                window.fullscreen = false
            }

            let shouldAnimate = shouldAnimateResize(
                for: window,
                willChangeScreens: willChangeScreens,
                resolvedProperties: resolvedWindowProperties
            )

            do {
                finalFrame = try await resizeWindow(
                    window,
                    targetFrame: targetFrame.padded,
                    bounds: preparedResize.paddedBounds,
                    willChangeScreens: willChangeScreens,
                    animate: shouldAnimate,
                    resolvedProperties: resolvedWindowProperties
                )
            } catch {
                let fallbackFrame = try frameAfterResizeError(error, currentFrame: window.frame)
                log.error(ApplicationLogPrivacy.errorDescription(error))
                finalFrame = fallbackFrame
            }

            if Defaults[.moveCursorWithWindow] {
                CGWarpMouseCursorPosition(targetFrame.padded.center)
            }
        }

        let postResizeProperties = Window.ResolvedProperties(
            updating: finalFrame,
            from: resolvedWindowProperties
        )

        // Record post-resize actions (replaces former defer block)
        if preparedResize.action.direction == .undo {
            await WindowRecords.shared.removeLastAction(for: window)
        } else if storeAsFrame {
            await WindowRecords.shared.record(
                window,
                resolvedProperties: postResizeProperties,
                preparedResize.action
            )
        }

        let resolvedRecord = await WindowRecords.ResolvedRecord(for: window)

        await StashManager.shared.onWindowResized(
            action: preparedResize.action,
            window: window,
            screen: preparedResize.screen
        )

        return ResizeOutcome(
            finalFrame: finalFrame,
            resolvedWindowProperties: postResizeProperties,
            resolvedRecord: resolvedRecord
        )
    }

    private struct ResizeOutcome {
        let finalFrame: CGRect
        let resolvedWindowProperties: Window.ResolvedProperties
        let resolvedRecord: WindowRecords.ResolvedRecord
    }

    // MARK: - System Window Manager

    @available(macOS 15, *)
    private static func resizeWithSystemWindowManager(
        window: Window,
        to action: BoundWindowAction
    ) async -> Bool {
        var currentAction = action

        if action.direction == .undo, let lastAction = await WindowRecords.shared.getLastAction(for: window) {
            currentAction = lastAction
        }

        guard
            let systemAction = currentAction.direction.systemEquivalent,
            let app = window.nsRunningApplication,
            app == NSWorkspace.shared.frontmostApplication,
            let axMenuItem = try? systemAction.getItem(for: app),
            (try? axMenuItem.getValue(.enabled)) == true
        else {
            log.info("System action not available for \(window.description)")
            return false
        }

        try? axMenuItem.performAction(.press)
        return true
    }

    // MARK: - Animation Checks

    /// Cancellation means a newer action has superseded this resize. Propagating it
    /// prevents the caller from committing post-resize history for an intermediate frame.
    static func frameAfterResizeError(_ error: Error, currentFrame: CGRect) throws -> CGRect {
        if error is CancellationError {
            throw error
        }
        return currentFrame
    }

    private static func shouldAnimateResize(
        for window: Window,
        willChangeScreens: Bool,
        resolvedProperties: Window.ResolvedProperties?
    ) -> Bool {
        if resolvedProperties?.isEnhancedUserInterface ?? window.enhancedUserInterface {
            return false
        }
        if !willChangeScreens, #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            return SystemWindowManager.MoveAndResize.enableAnimations
        }
        if !Defaults[.animateWindowResizes] {
            return false
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled, !Defaults[.ignoreLowPowerMode] {
            return false
        }
        return true
    }

    // MARK: - Window Resize

    private static func resizeWindow(
        _ window: Window,
        targetFrame: CGRect,
        bounds: CGRect,
        willChangeScreens: Bool,
        animate: Bool,
        resolvedProperties: Window.ResolvedProperties? = nil
    ) async throws -> CGRect {
        let actualFrame: CGRect

        if animate {
            try await window.setFrameAnimated(targetFrame, bounds: bounds, resolvedProperties: resolvedProperties)
            actualFrame = window.frame
        } else {
            await window.setFrame(targetFrame, sizeFirst: willChangeScreens, resolvedProperties: resolvedProperties)
            try Task.checkCancellation()

            var frameAfterResize = window.frame
            if !frameAfterResize.approximatelyEqual(to: targetFrame) {
                await window.setFrame(targetFrame, resolvedProperties: resolvedProperties)
                try Task.checkCancellation()
                frameAfterResize = window.frame
            }
            actualFrame = frameAfterResize
        }

        return handleSizeConstrainedWindow(
            window: window,
            actualFrame: actualFrame,
            targetFrame: targetFrame,
            bounds: bounds
        )
    }

    // MARK: - Size Constraints

    private static func handleSizeConstrainedWindow(
        window: Window,
        actualFrame: CGRect,
        targetFrame: CGRect,
        bounds: CGRect
    ) -> CGRect {
        guard !window.isOwnWindow, bounds != .zero else {
            return actualFrame
        }

        // Some windows have size constraints such as fixed aspect ratios, fixed width,
        // fixed height, etc. When that happens, preserve the intended anchor by
        // re-positioning the resulting frame after the resize completes.
        guard !actualFrame.size.approximatelyEqual(to: targetFrame.size, tolerance: 2) else {
            return actualFrame
        }

        let targetEdges = targetFrame.getEdgesTouchingBounds(bounds)
        let correctedFrame = anchoredFrame(
            for: actualFrame.size,
            within: targetFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )

        guard !actualFrame.origin.approximatelyEqual(to: correctedFrame.origin, tolerance: 1) else {
            return actualFrame
        }

        window.setPosition(correctedFrame.origin)
        return correctedFrame
    }

    static func anchoredFrame(
        for actualSize: CGSize,
        within requestedFrame: CGRect,
        targetEdges: Edge.Set,
        bounds: CGRect
    ) -> CGRect {
        var frame = CGRect(origin: requestedFrame.origin, size: actualSize)

        if targetEdges.contains(.leading), targetEdges.contains(.trailing) {
            frame.origin.x = requestedFrame.midX - actualSize.width / 2
        } else if targetEdges.contains(.leading) {
            frame.origin.x = requestedFrame.minX
        } else if targetEdges.contains(.trailing) {
            frame.origin.x = requestedFrame.maxX - actualSize.width
        } else {
            frame.origin.x = requestedFrame.midX - actualSize.width / 2
        }

        if targetEdges.contains(.top), targetEdges.contains(.bottom) {
            frame.origin.y = requestedFrame.midY - actualSize.height / 2
        } else if targetEdges.contains(.top) {
            frame.origin.y = requestedFrame.minY
        } else if targetEdges.contains(.bottom) {
            frame.origin.y = requestedFrame.maxY - actualSize.height
        } else {
            frame.origin.y = requestedFrame.midY - actualSize.height / 2
        }

        return frame.pushInside(bounds)
    }

    static func shouldAnchorDuringAnimation(
        actualSize: CGSize,
        requestedSize: CGSize,
        tolerance: CGFloat = 2
    ) -> Bool {
        guard !actualSize.approximatelyEqual(to: requestedSize, tolerance: tolerance) else {
            return false
        }

        // Only compensate during animation when the app ended up smaller than the
        // requested frame (fixed aspect ratio, fixed width, fixed height, etc.)
        // If the app stays larger because of a minimum size, preserving the
        // requested motion avoids visible jitter while shrinking/moving
        return actualSize.width <= requestedSize.width + tolerance &&
            actualSize.height <= requestedSize.height + tolerance
    }
}
