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
    /// Prepared resize to apply on release when preview-only path was used.
    let actionToApplyOnRelease: WindowResizeExecution.PreparedResize?
}

/// Pure helpers for change-action side effects owned by SessionManager.
enum SessionChangeEffects {
    static func shouldRestartTimeout(isSessionActive: Bool, resultRequestsRestart: Bool) -> Bool {
        isSessionActive && resultRequestsRestart
    }

    static func shouldPerformHaptic(resultRequestsHaptic: Bool, hapticFeedbackEnabled: Bool) -> Bool {
        hapticFeedbackEnabled && resultRequestsHaptic
    }
}

/// Manages Window Action Session lifecycle and interactions.
///
/// A session represents the period when Line is actively showing a window action:
/// - User triggers Line (keyboard shortcut or middle-click)
/// - Session opens with a Prepared Resize bootstrap and WindowActionSession
/// - User can change actions, screens, or interact with mouse
/// - Session closes when user releases trigger or explicitly cancels
///
/// SessionManager owns change-action side effects (indicators, apply, timeout restart,
/// haptic, cycle continuation). LineCoordinator only orchestrates open/close and isLineActive.
///
/// SessionManager is independent of GridModeCoordinator (they are mutually exclusive).
@Loggable
@MainActor
final class SessionManager {
    // MARK: - Dependencies

    private let windowActionCache: WindowActionCache
    private let indicatorService: WindowActionIndicatorService
    private let onRestartTimeout: () -> Void

    // MARK: - Internal State

    private var windowActionSession: WindowActionSession?
    /// True after an immediate apply (or focus apply) landed during this session,
    /// so close must not double-apply the same intent.
    private var didApplyDuringSession = false

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

    /// Current session layout truth, if a session is open.
    var preparedResize: WindowResizeExecution.PreparedResize? {
        windowActionSession?.preparedResize
    }

    // MARK: - Initialization

    init(
        windowActionCache: WindowActionCache,
        indicatorService: WindowActionIndicatorService,
        onRestartTimeout: @escaping () -> Void = {}
    ) {
        self.windowActionCache = windowActionCache
        self.indicatorService = indicatorService
        self.onRestartTimeout = onRestartTimeout
    }

    // MARK: - Public Interface

    /// Open a new Window Action Session.
    func open(
        window: Window?,
        initialMousePosition: CGPoint,
        startingAction: BoundWindowAction,
        isReverseCycleRequested: @escaping () -> Bool
    ) async {
        log.info("Opening session with window action")

        didApplyDuringSession = false

        let preparedResize = await WindowResizeExecution.bootstrap(
            window: window,
            initialMousePosition: initialMousePosition
        )

        windowActionSession = WindowActionSession(
            preparedResize: preparedResize,
            interception: StashWindowActionInterception()
        )

        indicatorService.openAndUpdate(preparedResize: preparedResize)

        await changeAction(
            startingAction,
            disableHapticFeedback: true,
            isReverseCycleRequested: isReverseCycleRequested
        )
    }

    /// Close the current session.
    /// - Parameter forceClose: If true, cancel without applying action
    func close(forceClose: Bool) -> SessionCloseResult {
        guard let session = windowActionSession else {
            return SessionCloseResult(actionToApplyOnRelease: nil)
        }
        log.info("Closing session (forceClose: \(forceClose))")

        let current = session.preparedResize
        indicatorService.closeAll()
        windowActionSession = nil
        hasParentCycleActionMirror.withLock { $0 = false }

        let shouldApplyOnRelease = !forceClose
            && Defaults[.previewVisibility]
            && !didApplyDuringSession
            && !current.action.willFocusWindow
        didApplyDuringSession = false

        return SessionCloseResult(
            actionToApplyOnRelease: shouldApplyOnRelease ? current : nil
        )
    }

    func applyCloseResult(_ result: SessionCloseResult) async {
        guard let prepared = result.actionToApplyOnRelease else {
            return
        }

        log.info("Applying window action on session close")
        do {
            let applyResult = try await WindowActionEngine.shared.apply(preparedResize: prepared)
            log.info("Window action applied: success=\(applyResult.success)")
        } catch {
            log.error("Failed to apply window action: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }

    /// Change to a new action within the current session and run all side effects.
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

        let hasParentCycleAction = windowActionSession.hasParentCycleAction
        hasParentCycleActionMirror.withLock { $0 = hasParentCycleAction }

        guard !result.isIgnored, !result.wasIntercepted else {
            return result
        }

        if result.shouldUpdateIndicators {
            indicatorService.openAndUpdate(preparedResize: windowActionSession.preparedResize)
        }

        if result.shouldApplyImmediately || result.shouldApplyFocusAction {
            await applyImmediate()
        }

        if SessionChangeEffects.shouldRestartTimeout(
            isSessionActive: isActive,
            resultRequestsRestart: result.shouldRestartTimeout
        ) {
            onRestartTimeout()
        }

        if SessionChangeEffects.shouldPerformHaptic(
            resultRequestsHaptic: result.shouldPerformHapticFeedback,
            hapticFeedbackEnabled: Defaults[.hapticFeedback]
        ) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        if let continuation = result.continuation {
            return await changeAction(
                continuation.action,
                triggeredFromScreenChange: true,
                isReverseCycleRequested: isReverseCycleRequested
            ) ?? result
        }

        return result
    }

    /// Immediate apply: live re-prepare inheriting session layout snapshot, then replace session truth.
    private func applyImmediate() async {
        guard let session = windowActionSession else { return }
        log.info("Applying window action during session change")

        let sessionSnapshot = session.preparedResize
        do {
            let prepared = await WindowResizeExecution.prepareImmediate(from: sessionSnapshot)
            let applyResult = try await WindowActionEngine.shared.apply(preparedResize: prepared)
            log.info("Window action applied: success=\(applyResult.success)")

            if applyResult.success {
                didApplyDuringSession = true
            }

            if let newTargetWindow = applyResult.newTargetWindow {
                let rebootstrap = await WindowResizeExecution.bootstrap(
                    window: newTargetWindow,
                    screen: prepared.screen,
                    initialMousePosition: sessionSnapshot.initialMousePosition,
                    action: sessionSnapshot.action,
                    parentAction: sessionSnapshot.parentAction
                )
                session.replacePreparedResize(rebootstrap)
            } else {
                session.replacePreparedResize(prepared)
            }
        } catch {
            log.error("Failed to apply session action: \(ApplicationLogPrivacy.errorDescription(error))")
        }
    }
}
