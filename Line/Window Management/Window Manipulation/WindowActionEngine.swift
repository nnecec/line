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
/// They are resolved by `LineCoordinator` which updates `resizeContext.screen` before calling `apply()`.
@Loggable
final class WindowActionEngine {
    static let shared = WindowActionEngine()

    @MainActor
    private var actionTasks: [CGWindowID: Task<Result, any Error>] = [:]

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

        // Cancel any existing action on this window
        actionTasks[windowID]?.cancel()

        // Create a task for this action
        let task = Task {
            let result = try await performApply(context: context)
            try Task.checkCancellation()
            return result
        }
        actionTasks[windowID] = task

        // Await the task and clean up
        let result = try await task.value

        _ = actionTasks.removeValue(forKey: windowID)

        return result
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

        try await WindowEngine.performResize(context: context)
        return .resized
    }

    // MARK: - Focus Actions

    private func handleFocusAction(_ action: BoundWindowAction, currentWindow: Window?) -> Result {
        var newTargetWindow: Window?

        if case let .focus(focusAction) = action.action {
            if focusAction == .focusNextInStack {
                newTargetWindow = WindowUtility.focusNextWindowInStack(from: currentWindow)
            } else if let focusDirection = focusAction.direction {
                newTargetWindow = WindowUtility.focusWindow(from: currentWindow, direction: focusDirection)
            }
        }

        return .focused(newTargetWindow)
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
