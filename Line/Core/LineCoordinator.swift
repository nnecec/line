//
//  LineCoordinator.swift
//  Line
//

import Defaults
import os
import Scribe
import SwiftUI

enum LineCoordinatorOpeningPolicy {
    struct GridOpenInstructions: Equatable {
        var shouldCancelPartiallyOpenedLine: Bool
        var shouldActivateLine: Bool
        var shouldStartTimeout: Bool
    }

    static func canActivateAfterOpening(
        shouldCancelOpening: Bool,
        isAccessibilityGranted: Bool
    ) -> Bool {
        !shouldCancelOpening && isAccessibilityGranted
    }

    static func instructionsAfterGridOpen(
        result: GridModeCoordinator.OpenResult,
        shouldAbortOpening: Bool
    ) -> GridOpenInstructions {
        guard result == .opened, !shouldAbortOpening else {
            return GridOpenInstructions(
                shouldCancelPartiallyOpenedLine: true,
                shouldActivateLine: false,
                shouldStartTimeout: false
            )
        }

        return GridOpenInstructions(
            shouldCancelPartiallyOpenedLine: false,
            shouldActivateLine: true,
            shouldStartTimeout: true
        )
    }
}

enum LineCoordinatorChangePolicy {
    struct Instructions: Equatable {
        var shouldRestartTimeout: Bool
        var shouldPerformHapticFeedback: Bool
        var continuation: BoundWindowAction?
    }

    static func instructions(
        isSessionActive: Bool,
        result: WindowActionSession.ChangeResult?,
        hapticFeedbackEnabled: Bool
    ) -> Instructions {
        Instructions(
            shouldRestartTimeout: isSessionActive && result?.shouldRestartTimeout == true,
            shouldPerformHapticFeedback: hapticFeedbackEnabled && result?.shouldPerformHapticFeedback == true,
            continuation: result?.continuation?.action
        )
    }
}

enum LineCoordinatorClosePolicy {
    struct Instructions: Equatable {
        var shouldReleaseCoordinatorStateBeforeSessionApply: Bool
    }

    static var windowActionSessionCloseInstructions: Instructions {
        Instructions(shouldReleaseCoordinatorStateBeforeSessionApply: true)
    }
}

/// Top-level coordinator for Line window management application.
///
/// LineCoordinator is the simplified result of extracting three sub-coordinators:
/// - GridModeCoordinator: Handles grid-based window layout selection
/// - TriggerCoordinator: Manages keyboard shortcuts and middle-click triggers
/// - SessionManager: Manages window action sessions and interactions
///
/// Responsibilities:
/// - Application lifecycle (start/shutdown)
/// - Coordinating between sub-coordinators
/// - Managing Line's active state (isLineActive)
/// - Handling concurrent open/close operations
/// - Timeout management via TriggerKeyTimeoutTimer
/// - Accessibility permission monitoring
@Loggable
@MainActor
final class LineCoordinator {
    static let shared = LineCoordinator()

    private init() {
        // Bind trigger coordinator callbacks after initialization
        triggerCoordinator.bind(
            onOpen: { [weak self] action in
                await self?.openLine(startingAction: action)
            },
            onClose: { [weak self] forceClose in
                await self?.closeLine(forceClose: forceClose)
            },
            checkIfLineOpen: { [weak self] in
                self?.isLineActiveAtomic ?? false
            }
        )
    }

    /// Context for the current resize operation, tracking frame and edge adjustment state.
    /// Initialized when Line opens with a target window and screen.
    var resizeContext: ResizeContext {
        sessionManager.resizeContext
    }

    private let windowActionCache = WindowActionCache()
    private let indicatorService = WindowActionIndicatorService()

    /// Coordinators
    private lazy var gridModeCoordinator = GridModeCoordinator(
        indicatorService: indicatorService
    )
    private(set) lazy var triggerCoordinator = TriggerCoordinator(
        windowActionCache: windowActionCache
    )
    private lazy var sessionManager = SessionManager(
        windowActionCache: windowActionCache,
        indicatorService: indicatorService
    )

    private var accessibilityCheckerTask: Task<(), Never>?

    /// Opening prepares resizeContext asynchronously. We track that setup separately
    /// so rapid trigger events cannot act on the previous/default context.
    private var isLineOpening: Bool = false
    private var pendingOpeningAction: BoundWindowAction?
    private var shouldCancelOpening: Bool = false

    private(set) var isLineActive: Bool = false {
        didSet {
            let value = isLineActive
            isLineActiveMirror.withLock { $0 = value }
        }
    }

    private let isLineActiveMirror = OSAllocatedUnfairLock<Bool>(initialState: false)
    nonisolated var isLineActiveAtomic: Bool {
        isLineActiveMirror.withLock { $0 }
    }

    private let hasParentCycleActionMirror = OSAllocatedUnfairLock<Bool>(initialState: false)
    nonisolated var hasParentCycleActionAtomic: Bool {
        hasParentCycleActionMirror.withLock { $0 }
    }

    private lazy var triggerKeyTimeoutTimer = TriggerKeyTimeoutTimer(
        closeCallback: { [weak self] forceClose in
            Task { await self?.closeLine(forceClose: forceClose) }
        }
    )

    static func canActivateAfterOpening(
        shouldCancelOpening: Bool,
        isAccessibilityGranted: Bool
    ) -> Bool {
        LineCoordinatorOpeningPolicy.canActivateAfterOpening(
            shouldCancelOpening: shouldCancelOpening,
            isAccessibilityGranted: isAccessibilityGranted
        )
    }

    static func instructionsAfterGridOpen(
        result: GridModeCoordinator.OpenResult,
        shouldAbortOpening: Bool
    ) -> LineCoordinatorOpeningPolicy.GridOpenInstructions {
        LineCoordinatorOpeningPolicy.instructionsAfterGridOpen(
            result: result,
            shouldAbortOpening: shouldAbortOpening
        )
    }

    func start() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    await triggerCoordinator.setup()
                } else {
                    triggerCoordinator.teardown()
                }
            }
        }
    }

    func shutdown() {
        accessibilityCheckerTask?.cancel()
        accessibilityCheckerTask = nil

        indicatorService.closeAll()

        triggerCoordinator.teardown()
        triggerKeyTimeoutTimer.cancel()

        isLineOpening = false
        pendingOpeningAction = nil
        shouldCancelOpening = false
        isLineActive = false
    }
}

// MARK: - Opening/Closing Line

extension LineCoordinator {
    private func openLine(startingAction: BoundWindowAction) async {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        guard !isLineOpening else {
            if startingAction.direction != .noSelection {
                pendingOpeningAction = startingAction
            }
            return
        }

        if isLineActive {
            // If grid mode is active and user presses a directional keybind,
            // close grid mode and open session mode with the new action.
            if gridModeCoordinator.isActive, startingAction.direction != .noSelection {
                log.info("Switching from grid mode to session mode with action: \(startingAction.direction)")
                gridModeCoordinator.close(reason: .cancelled)
                triggerKeyTimeoutTimer.cancel()
                isLineActive = false
                // Fall through to open session mode below
            } else {
                // If using Karabiner-Elements, TriggerKeybindObserver may call openLine twice, as key events arrive in quick succession.
                // This happens because Karabiner-Elements sends modifier keys and other keys as separate, rapid events.
                // As a result, Line might be opened before the full keybind is pressed.
                // In these cases, we can simply update the action instead of reopening the Line.
                if startingAction.direction != .noSelection { // Can switch to .noAction still!
                    await changeAction(startingAction, disableHapticFeedback: true)
                }

                return
            }
        }

        let window = WindowUtility.userDefinedTargetWindow()

        guard let window,
              WindowStateValidator.canManipulate(window)
        else {
            return
        }

        isLineOpening = true
        pendingOpeningAction = nil
        shouldCancelOpening = false
        hasParentCycleActionMirror.withLock { $0 = false }

        defer {
            isLineOpening = false
            pendingOpeningAction = nil
            shouldCancelOpening = false
        }

        log.info("Opening Line with starting action and target window: \(window.description)")

        // Refresh accent colors in case user has enabled the wallpaper processor
        Task {
            await AccentColorController.shared.refresh()
        }

        if startingAction.direction == .noSelection {
            let gridOpenResult = await gridModeCoordinator.open(
                window: window,
                initialMousePosition: NSEvent.mouseLocation,
                onComplete: { [weak self] in
                    Task { @MainActor in
                        self?.isLineActive = false
                        self?.triggerKeyTimeoutTimer.cancel()
                    }
                }
            )
            let instructions = Self.instructionsAfterGridOpen(
                result: gridOpenResult,
                shouldAbortOpening: shouldAbortOpening()
            )
            if instructions.shouldCancelPartiallyOpenedLine {
                await cancelPartiallyOpenedLine()
                return
            }

            if instructions.shouldActivateLine {
                isLineActive = true
            }
            if instructions.shouldStartTimeout {
                triggerKeyTimeoutTimer.start()
            }
            return
        }

        // Stash revealed-frame override is resolved inside SessionManager.open.
        if shouldAbortOpening() {
            await cancelPartiallyOpenedLine()
            return
        }

        await sessionManager.open(
            window: window,
            initialMousePosition: NSEvent.mouseLocation,
            startingAction: pendingOpeningAction ?? startingAction,
            isReverseCycleRequested: { [weak self] in
                self?.triggerCoordinator.keybindTrigger.effectiveEventFlags.contains(.maskShift) ?? false
            }
        )
        if shouldAbortOpening() {
            await cancelPartiallyOpenedLine()
            return
        }

        isLineActive = true
        triggerKeyTimeoutTimer.start()
    }

    private func closeLine(forceClose: Bool) async {
        if isLineOpening {
            shouldCancelOpening = true
            await cancelPartiallyOpenedLine()
        }

        guard isLineActive == true else { return }
        log.info("Closing Line (force closed: \(forceClose))")

        // Close grid mode if active
        if gridModeCoordinator.isActive {
            if forceClose {
                gridModeCoordinator.close(reason: .cancelled)
            } else {
                await gridModeCoordinator.commitHoveredSelection(onComplete: {})
            }
            isLineActive = false
            triggerKeyTimeoutTimer.cancel()
            return
        }

        // Close session if active
        let closeResult = sessionManager.close(forceClose: forceClose)
        let closeInstructions = LineCoordinatorClosePolicy.windowActionSessionCloseInstructions

        if closeInstructions.shouldReleaseCoordinatorStateBeforeSessionApply {
            isLineActive = false
            triggerKeyTimeoutTimer.cancel()
        }

        await sessionManager.applyCloseResult(closeResult)
    }

    private func shouldAbortOpening() -> Bool {
        !Self.canActivateAfterOpening(
            shouldCancelOpening: shouldCancelOpening,
            isAccessibilityGranted: AccessibilityManager.shared.isGranted
        )
    }

    private func cancelPartiallyOpenedLine() async {
        if gridModeCoordinator.isActive {
            gridModeCoordinator.close(reason: .cancelled)
        }

        if sessionManager.isActive {
            _ = sessionManager.close(forceClose: true)
        }

        indicatorService.closeAll()
        isLineActive = false
        triggerKeyTimeoutTimer.cancel()
    }
}

// MARK: - Changing Actions

extension LineCoordinator {
    /// Changes the action to the provided one, or the next cycle action if available.
    /// - Parameters:
    ///   - newAction: The action to change to. If a cycle is provided, Line will use the current action as context to choose an appropriate next action.
    ///   - triggeredFromScreenChange: If this action was triggered from a screen change, this will prevent cycle keybinds from infinitely changing screens.
    ///   - disableHapticFeedback: This will prevent haptic feedback.
    private func changeAction(
        _ newAction: BoundWindowAction,
        triggeredFromScreenChange: Bool = false,
        disableHapticFeedback: Bool = false,
        isReverseCycleRequested: Bool? = nil
    ) async {
        let result = await sessionManager.changeAction(
            newAction,
            triggeredFromScreenChange: triggeredFromScreenChange,
            disableHapticFeedback: disableHapticFeedback,
            isReverseCycleRequested: { [weak self] in
                isReverseCycleRequested ?? (self?.triggerCoordinator.keybindTrigger.effectiveEventFlags.contains(.maskShift) ?? false)
            }
        )

        // Update mirror for nonisolated access
        let hasParent = sessionManager.hasParentCycleAction
        hasParentCycleActionMirror.withLock { $0 = hasParent }

        let instructions = LineCoordinatorChangePolicy.instructions(
            isSessionActive: sessionManager.isActive,
            result: result,
            hapticFeedbackEnabled: Defaults[.hapticFeedback]
        )

        // Handle timeout restart
        if instructions.shouldRestartTimeout {
            triggerKeyTimeoutTimer.cancel()
            triggerKeyTimeoutTimer.start()
        }

        // Haptic feedback
        if instructions.shouldPerformHapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        if let continuation = instructions.continuation {
            await changeAction(
                continuation,
                triggeredFromScreenChange: true
            )
        }
    }
}
