//
//  SessionManager.swift
//  Line
//
//  Created by Claude on 2026-07-08.

import Defaults
import os
import Scribe
import SwiftUI

@MainActor
struct SessionCloseResult {
    let actionToApplyOnRelease: ResizeContext?
}

/// Manages Window Action Session lifecycle and interactions.
///
/// A session represents the period when Line is actively showing a window action:
/// - User triggers Line (keyboard shortcut or middle-click)
/// - Session opens with ResizeContext and WindowActionSession
/// - User can change actions, screens, or interact with mouse
/// - Session closes when user releases trigger or explicitly cancels
///
/// SessionManager is independent of GridModeCoordinator (they are mutually exclusive).
@Loggable
@MainActor
final class SessionManager {
    // MARK: - Dependencies

    private let windowActionCache: WindowActionCache
    private let indicatorService: WindowActionIndicatorService

    // MARK: - Internal State

    private(set) var resizeContext: ResizeContext = .init()
    private var windowActionSession: WindowActionSession?

    private let hasParentCycleActionMirror = OSAllocatedUnfairLock<Bool>(initialState: false)
    nonisolated var hasParentCycleActionAtomic: Bool {
        hasParentCycleActionMirror.withLock { $0 }
    }

    var isActive: Bool {
        windowActionSession != nil
    }

    var hasParentCycleAction: Bool {
        hasParentCycleActionAtomic
    }

    // MARK: - Initialization

    init(
        windowActionCache: WindowActionCache,
        indicatorService: WindowActionIndicatorService
    ) {
        self.windowActionCache = windowActionCache
        self.indicatorService = indicatorService
    }

    // MARK: - Public Interface

    /// Open a new Window Action Session.
    /// - Parameters:
    ///   - window: Target window to resize (optional)
    ///   - initialMousePosition: Mouse position when session was triggered
    ///   - startingAction: Initial action to display
    ///   - isReverseCycleRequested: Whether shift is held for reverse cycle
    func open(
        window: Window?,
        initialMousePosition: CGPoint,
        startingAction: BoundWindowAction,
        isReverseCycleRequested: @escaping () -> Bool
    ) async {
        log.info("Opening session with window action")

        // Check for stashed window frame
        _ = if let window {
            await StashManager.shared.getRevealedFrameForStashedWindow(
                id: window.cgWindowID
            ) ?? window.frame
        } else {
            CGRect.zero
        }

        // Create ResizeContext adapter from Window Resize Execution.
        let preparedResize = await WindowResizeExecution.prepare(
            action: BoundWindowAction(action: .special(.noSelection), keybind: []),
            window: window,
            initialMousePosition: initialMousePosition
        )
        resizeContext = ResizeContext(preparedResize: preparedResize)

        windowActionSession = WindowActionSession(
            context: resizeContext,
            interception: StashWindowActionInterception()
        )

        // Open indicator and preview
        indicatorService.openAndUpdate(context: resizeContext)

        // Apply starting action
        await changeAction(startingAction, disableHapticFeedback: true, isReverseCycleRequested: isReverseCycleRequested)
    }

    /// Close the current session.
    /// - Parameter forceClose: If true, cancel without applying action
    func close(forceClose: Bool) -> SessionCloseResult {
        guard windowActionSession != nil else {
            return SessionCloseResult(actionToApplyOnRelease: nil)
        }
        log.info("Closing session (forceClose: \(forceClose))")

        indicatorService.closeAll()
        windowActionSession = nil
        hasParentCycleActionMirror.withLock { $0 = false }

        let shouldApplyOnRelease = !forceClose
            && Defaults[.previewVisibility]
            && !resizeContext.action.willFocusWindow
        return SessionCloseResult(
            actionToApplyOnRelease: shouldApplyOnRelease ? resizeContext : nil
        )
    }

    func applyCloseResult(_ result: SessionCloseResult) async {
        guard let resizeContext = result.actionToApplyOnRelease else {
            return
        }

        log.info("Applying window action on session close")
        do {
            let result = try await WindowActionEngine.shared.apply(context: resizeContext)
            log.info("Window action applied: success=\(result.success)")
        } catch {
            log.error("Failed to apply window action: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }

    /// Change to a new action within the current session.
    @discardableResult
    func changeAction(
        _ newAction: BoundWindowAction,
        triggeredFromScreenChange: Bool = false,
        disableHapticFeedback: Bool = false,
        canAdvanceCycle: Bool = true,
        isReverseCycleRequested: (() -> Bool)? = nil
    ) async -> WindowActionSession.ChangeResult? {
        guard let windowActionSession else {
            return nil
        }

        let result = await windowActionSession.changeAction(
            newAction,
            input: .init(
                triggeredFromScreenChange: triggeredFromScreenChange,
                disableHapticFeedback: disableHapticFeedback,
                canAdvanceCycle: canAdvanceCycle,
                isReverseCycleRequested: isReverseCycleRequested?() ?? false
            )
        )

        resizeContext = windowActionSession.context
        let hasParentCycleAction = windowActionSession.hasParentCycleAction
        hasParentCycleActionMirror.withLock { $0 = hasParentCycleAction }

        guard !result.isIgnored, !result.wasIntercepted else {
            return result
        }

        // SessionManager owns indicator and apply side effects. Timeout, haptic,
        // and continuation instructions stay available to the coordinator via
        // the returned result so those policies can remain outside this type.
        if result.shouldUpdateIndicators {
            indicatorService.openAndUpdate(context: resizeContext)
        }

        if result.shouldApplyImmediately || result.shouldApplyFocusAction {
            await applyCurrentAction()
        }

        return result
    }

    private func applyCurrentAction() async {
        log.info("Applying window action during session change")

        do {
            let preparedResize = await WindowResizeExecution.prepare(
                action: resizeContext.action,
                parentAction: resizeContext.parentAction,
                window: resizeContext.window,
                screen: resizeContext.screen,
                bounds: resizeContext.bounds,
                padding: resizeContext.padding,
                initialMousePosition: resizeContext.initialMousePosition
            )
            let executionContext = ResizeContext(preparedResize: preparedResize)
            let result = try await WindowActionEngine.shared.apply(context: executionContext)
            resizeContext = executionContext
            windowActionSession?.replaceContext(executionContext)
            log.info("Window action applied: success=\(result.success)")

            if let newTargetWindow = result.newTargetWindow {
                let updatedContext = ResizeContext(
                    window: newTargetWindow,
                    screen: resizeContext.screen,
                    bounds: resizeContext.bounds,
                    padding: resizeContext.padding,
                    action: resizeContext.action,
                    initialMousePosition: resizeContext.initialMousePosition
                )
                resizeContext = updatedContext
                windowActionSession?.replaceContext(updatedContext)
            }
        } catch {
            log.error("Failed to apply session action: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }

    /// Change to a different screen within the current session.
    func changeScreen(to newScreen: NSScreen) async {
        guard windowActionSession != nil else {
            return
        }

        log.info("Changing session screen")

        // Create new context with the new screen
        let preparedResize = await WindowResizeExecution.prepare(
            action: resizeContext.action,
            parentAction: resizeContext.parentAction,
            window: resizeContext.window,
            screen: newScreen,
            bounds: newScreen.visibleFrame,
            padding: resizeContext.padding,
            initialMousePosition: resizeContext.initialMousePosition
        )
        let newContext = ResizeContext(preparedResize: preparedResize)

        // Apply the action to the new screen's context
        do {
            let result = try await WindowActionEngine.shared.apply(context: newContext)
            if result.success {
                log.info("Window action applied to new screen")

                // Update context if new target window returned
                if let newTargetWindow = result.newTargetWindow {
                    let updatedContext = ResizeContext(
                        window: newTargetWindow,
                        screen: newContext.screen,
                        bounds: newContext.bounds,
                        padding: newContext.padding,
                        action: newContext.action,
                        initialMousePosition: newContext.initialMousePosition
                    )
                    resizeContext = updatedContext
                    windowActionSession?.replaceContext(updatedContext)
                }
            }
        } catch {
            log.error("Failed to apply session action: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }
}
