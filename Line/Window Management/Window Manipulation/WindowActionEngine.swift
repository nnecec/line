//
//  WindowActionEngine.swift
//  Line
//
//  Created by nnecec on 2023-06-16.
//

import Defaults
import Scribe
import SwiftUI

/// Unified entry point for executing all window actions.
///
/// `WindowActionEngine` consolidates action execution logic previously scattered across
/// `WindowEngine`, `LineCoordinator`, and other files. It routes actions to appropriate handlers
/// and returns a result indicating success and any state changes.
///
/// **Note:** Screen change actions (`nextScreen`, `previousScreen`, etc.) are NOT handled here.
/// They are resolved in the Window Action Session, which transitions Prepared Resize to the target screen
/// before calling `apply(preparedResize:)`.
@Loggable
final class WindowActionEngine {
    static let shared = WindowActionEngine()

    @MainActor
    private lazy var actionTasks = LatestTaskRegistry<CGWindowID, Result>()

    /// Result of applying a window action
    struct Result {
        /// Whether the action was successfully applied
        let success: Bool
        /// For focus actions that change the target window
        let newTargetWindow: Window?

        static let noOp = Result(success: true, newTargetWindow: nil)
        static let failed = Result(success: false, newTargetWindow: nil)
        static let resized = Result(success: true, newTargetWindow: nil)

        static func focused(_ window: Window?) -> Result {
            Result(success: window != nil, newTargetWindow: window)
        }
    }

    /// Simplified apply for callers that don't need resize context tracking (URL commands, drag snap, etc.)
    ///
    /// - Parameters:
    ///   - action: The action to apply
    ///   - window: The target window
    ///   - screen: The screen to perform the action on
    /// - Returns: Result indicating success and any state changes
    @MainActor
    func apply(
        _ action: WindowAction,
        window: Window?,
        screen: NSScreen
    ) async throws -> Result {
        let preparedResize = await WindowResizeExecution.prepare(
            action: BoundWindowAction(action: action, keybind: []),
            window: window,
            screen: screen
        )
        return try await apply(preparedResize: preparedResize)
    }

    @MainActor
    func apply(preparedResize: WindowResizeExecution.PreparedResize) async throws -> Result {
        try await apply(context: ResizeContext(preparedResize: preparedResize))
    }

    /// Apply a window action with explicit resize context tracking.
    /// The context should be updated by the caller before calling this function.
    ///
    /// - Parameters:
    ///   - action: The action to apply
    ///   - window: The target window (can be nil for some actions like focus navigation from screen center)
    ///   - resizeContext: Context containing tracking state for grow/shrink actions (passed by value, caller updates)
    /// - Returns: Result indicating success and any state changes
    /// - Throws: `CancellationError` if a new action is applied to the same window
    @MainActor
    func apply(context: ResizeContext) async throws -> Result {
        guard let windowID = context.window?.cgWindowID else {
            return try await performApply(context: context)
        }

        let handle = actionTasks.replace(for: windowID) { [weak self] in
            guard let self else { throw CancellationError() }

            let result = try await self.performApply(context: context)
            try Task.checkCancellation()
            return result
        }

        defer { actionTasks.remove(handle, for: windowID) }
        return try await handle.task.value
    }

    @MainActor
    private func performApply(context: ResizeContext) async throws -> Result {
        log.info("Applying window action context")

        let action = context.action

        // No-op actions: return early
        if action.isNoOp || action.direction == .cycle {
            return .noOp
        }

        // Focus actions: find and focus the target window
        if action.willFocusWindow {
            return handleFocusAction(action, currentWindow: context.window)
        }

        // Quick actions that don't require resize logic
        if let result = handleQuickAction(action, window: context.window) {
            return result
        }

        guard context.window != nil else {
            log.info("Cannot resize without a target window")
            return .failed
        }

        try await WindowEngine.performResize(context: context)
        return .resized
    }

    // MARK: - Focus Actions

    @MainActor
    private func handleFocusAction(_ action: BoundWindowAction, currentWindow: Window?) -> Result {
        let newTargetWindow = Self.resolveFocusTarget(
            for: action.action,
            currentWindow: currentWindow,
            directionalFocus: { window, direction in
                WindowUtility.focusWindow(from: window, direction: direction)
            },
            stackFocus: { window in
                WindowUtility.focusNextWindowInStack(from: window)
            }
        )

        return .focused(newTargetWindow)
    }

    @MainActor
    static func resolveFocusTarget(
        for action: WindowAction,
        currentWindow: Window?,
        directionalFocus: (Window?, NavigationDirection) -> Window?,
        stackFocus: (Window?) -> Window?
    ) -> Window? {
        guard case let .focus(focusAction) = action else { return nil }

        if focusAction == .focusNextInStack {
            return stackFocus(currentWindow)
        }

        guard let direction = focusAction.direction else { return nil }
        return directionalFocus(currentWindow, direction)
    }

    // MARK: - Quick Actions

    /// Handles quick actions that don't require the full resize flow.
    /// Returns nil if the action is not a quick action.
    private func handleQuickAction(_ action: BoundWindowAction, window: Window?) -> Result? {
        guard let window else {
            // Quick actions require a window
            let quickDirections: [WindowDirection] = [.hide, .minimize, .fullscreen, .minimizeOthers]
            if quickDirections.contains(action.direction) {
                log.info("Cannot apply quick action without a target window")
                return .failed
            }
            return nil
        }

        switch action.direction {
        case .hide:
            window.toggleHidden()
            return .noOp
        case .minimize:
            window.toggleMinimized()
            return .noOp
        case .fullscreen:
            window.toggleFullscreen()
            return .noOp
        case .minimizeOthers:
            minimizeOtherWindows(exceptWindow: window)
            return .noOp
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private func minimizeOtherWindows(exceptWindow: Window) {
        let allWindows = WindowUtility.windowList()
        let windowsToMinimize = allWindows.filter {
            $0.cgWindowID != exceptWindow.cgWindowID && !$0.minimized && !$0.isWindowHidden
        }

        log.info("Minimizing \(windowsToMinimize.count) other windows")

        for window in windowsToMinimize {
            window.minimized = true
        }
    }
}
