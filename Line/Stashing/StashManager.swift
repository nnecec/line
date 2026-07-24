//
//  StashManager.swift
//  Line
//
//  Created by Guillaume Clédat on 22/05/2025.
//

import Defaults
import Scribe
import SwiftUI

enum StashOverlapPolicy {
    static func shouldReplaceExistingWindow(
        incomingFrame: CGRect,
        incomingEdge: StashEdge?,
        existingFrame: CGRect,
        existingEdge: StashEdge?,
        isSameScreen: Bool,
        minimumVisibleSize: CGFloat
    ) -> Bool {
        guard isSameScreen, let incomingEdge, incomingEdge == existingEdge else {
            return false
        }

        return !hasEnoughIndividuallyVisibleSpace(
            between: incomingFrame,
            and: existingFrame,
            edge: incomingEdge,
            minimumVisibleSize: minimumVisibleSize
        )
    }

    private static func hasEnoughIndividuallyVisibleSpace(
        between firstFrame: CGRect,
        and secondFrame: CGRect,
        edge: StashEdge,
        minimumVisibleSize: CGFloat
    ) -> Bool {
        let firstRange: ClosedRange<CGFloat>
        let secondRange: ClosedRange<CGFloat>

        if edge.isHorizontal {
            firstRange = firstFrame.minY...firstFrame.maxY
            secondRange = secondFrame.minY...secondFrame.maxY
        } else {
            firstRange = firstFrame.minX...firstFrame.maxX
            secondRange = secondFrame.minX...secondFrame.maxX
        }

        return rangesHaveEnoughIndividuallyVisibleSpace(
            firstRange,
            secondRange,
            minimumVisibleSize: minimumVisibleSize
        )
    }

    private static func rangesHaveEnoughIndividuallyVisibleSpace(
        _ firstRange: ClosedRange<CGFloat>,
        _ secondRange: ClosedRange<CGFloat>,
        minimumVisibleSize: CGFloat
    ) -> Bool {
        if firstRange.upperBound < secondRange.lowerBound || secondRange.upperBound < firstRange.lowerBound {
            return true
        }

        let firstLength = firstRange.upperBound - firstRange.lowerBound
        let secondLength = secondRange.upperBound - secondRange.lowerBound
        let longerRange: ClosedRange<CGFloat>
        let shorterRange: ClosedRange<CGFloat>

        if firstLength >= secondLength {
            (longerRange, shorterRange) = (firstRange, secondRange)
        } else {
            (longerRange, shorterRange) = (secondRange, firstRange)
        }

        let extensionBefore = max(0, longerRange.lowerBound - shorterRange.lowerBound)
        let extensionAfter = max(0, shorterRange.upperBound - longerRange.upperBound)

        return extensionBefore >= minimumVisibleSize || extensionAfter >= minimumVisibleSize
    }
}

/// Pure helpers for stash mouse hit-testing and z-order ranking without Accessibility.
enum StashZOrderPolicy {
    /// Default expansion applied to stash/reveal frames when deciding if the cursor is "near" enough
    /// to warrant a CG window list lookup (matches `shouldHide` tolerance).
    static let proximityTolerance: CGFloat = 15

    /// Whether `location` is within `tolerance` of any stashed or revealed frame.
    /// Used to skip CG listing when the cursor is far from every stash region.
    static func isMouseNearAnyStash(
        location: CGPoint,
        stashedFrames: some Sequence<CGRect>,
        revealedFrames: some Sequence<CGRect>,
        tolerance: CGFloat = proximityTolerance
    ) -> Bool {
        for frame in stashedFrames {
            if frame.insetBy(dx: -tolerance, dy: -tolerance).contains(location) {
                return true
            }
        }
        for frame in revealedFrames {
            if frame.insetBy(dx: -tolerance, dy: -tolerance).contains(location) {
                return true
            }
        }
        return false
    }

    /// Preserve CG front-to-back order while projecting onto stashed entries.
    static func stashedInZOrder<Value>(
        zOrderedWindowIDs: some Sequence<CGWindowID>,
        stashed: [CGWindowID: Value]
    ) -> [Value] {
        zOrderedWindowIDs.compactMap { stashed[$0] }
    }
}

/// Manages the behavior of windows that can be temporarily hidden (stashed) and revealed on screen edges.
///
/// `StashManager` orchestrates a system for "stashing" windows by moving them to the edge of a screen,
/// revealing them when the mouse approaches, and hiding them again when the mouse leaves. It handles:
/// - Window stashing logic: deciding where and how to stash windows while maintaining individually targetable placements.
/// - Reveal/hide logic: dynamically revealing stashed windows when the mouse is nearby, and hiding them otherwise.
/// - Input events: listens to mouse movements to manage reveal/hide behavior efficiently.
/// - Cleanup and restore: restores windows when the app terminates or when a window is explicitly unstashed.
///
/// ## Key Features:
/// - Configurable animations for reveal/hide behaviors (see `Defaults[.animateStashedWindows]`).
/// - Configurable visibility padding to determine how much of a stashed window remains visible (see `Defaults[.stashedWindowVisiblePadding]`).
/// - Smart handling of overlapping stashed windows along the same screen edge, using edge-appropriate visible space.
/// - Debounced and throttled mouse movement handling to avoid performance issues.
/// - Automatic focus-shifting to another window when a window is hidden (optional) (see `Defaults[.shiftFocusWhenStashed]`).
///
/// ## Constants:
/// - `mouseMovedDebounceInterval`: The minimum time interval (in seconds) between processing consecutive mouse move events.
/// - `revealThrottleInterval`: The minimum time interval (in seconds) between revealing or hiding actions for a specific window.
/// - `minimumVisibleSizeToKeepWindowStacked`:
///     - The minimum required non-overlapping space (in points) between two stashed windows on the same screen edge.
///     - Uses vertical space for the left and right edges, and horizontal space for the bottom edge.
///     - Ensures that multiple stashed windows leave enough visible space along their shared edge.
///     - Allows the user to move the mouse into the stash area and target a specific window, even if windows are stacked.
///
/// ## Considerations:
/// - Currently supports only one revealed window at a time.
@Loggable
final class StashManager {
    static let shared = StashManager()
    private init() {}

    /// Should the stashed windows be animated when revealed or hidden?
    private var animate: Bool {
        Defaults[.animateStashedWindows]
    }

    /// How many pixels of the window should be visible when stashed
    var stashedWindowVisiblePadding: CGFloat {
        Defaults[.stashedWindowVisiblePadding]
    }

    private var shiftFocusWhenStashed: Bool {
        Defaults[.shiftFocusWhenStashed]
    }

    /// The time interval to debounce mouse moved events to avoid excessive processing.
    private let mouseMovedDebounceInterval: TimeInterval = 0.05

    /// The throttle interval for revealing/hiding windows when the mouse moves.
    private let revealThrottleInterval: TimeInterval = 0.1

    /// Two windows can be stacked along the same edge of the screen as long as there is enough non-overlapping space
    /// to allow the user to easily position the cursor over either window.
    /// The left and right edges use vertical space; the bottom edge uses horizontal space.
    private let minimumVisibleSizeToKeepWindowStacked: CGFloat = 100

    private lazy var store: StashedWindowsStore = {
        let store = StashedWindowsStore()
        store.delegate = self
        return store
    }()

    private var lastRevealTime: [CGWindowID: Date] = [:]
    private var mouseMonitor: PassiveEventMonitor?
    private var frontmostAppMonitor: Task<(), Never>?
    private var mouseMovedTask: Task<(), Never>?
    private var transitionIDs: [CGWindowID: UUID] = [:]

    // MARK: - Public methods

    func start() {
        Task {
            await store.restore()
        }
    }

    func onWindowManipulated(_ id: CGWindowID) {
        unmanage(windowID: id)
    }

    /// Cancels all monitoring and restores every stashed window to its initial frame.
    func shutdown() {
        mouseMovedTask?.cancel()
        mouseMovedTask = nil
        stopListeningToRevealTriggers()
        restoreAllStashedWindows()
    }

    func onConfigurationChanged() async {
        let stashedWindows = Array(store.stashed.values)

        for stashedWindow in stashedWindows {
            let updated = await stashedWindow.updatingStashedFrame(peekSize: stashedWindowVisiblePadding)

            store.setStashedWindow(cgWindowID: updated.window.cgWindowID, to: updated)

            // Don't animate when configuration changes
            await updated.window.setFrame(updated.stashedFrame)
        }
    }

    /// Determines whether the given window action should be intercepted by the StashManager.
    ///
    /// If the action targets a stashed window that is no longer visible, the currently focused
    /// window will be stashed in its place. The stashed window is then either revealed or hidden,
    /// depending on its current state. This allows the StashManager to take over the behavior,
    /// bypassing the default flow handled by the LineCoordinator.
    ///
    /// - Parameter action: The window action triggered.
    /// - Returns: `true` if the action is handled by the StashManager and the normal flow should be bypassed; otherwise, `false`.
    @discardableResult
    func handleIfStashed(_ action: BoundWindowAction, screen: NSScreen) -> Bool {
        guard case .stash = action.action,
              let stashedWindow = store.stashedWindow(for: action, on: screen),
              !stashedWindow.window.isWindowHidden, !stashedWindow.window.isApplicationHidden
        else {
            return false
        }

        log.info("Intercepting window action for stashed window \(stashedWindow.window.description)")

        Task {
            if store.isWindowRevealed(stashedWindow.window.cgWindowID) {
                await hideWindow(stashedWindow)
            } else {
                await revealWindow(stashedWindow)
            }
        }

        return true
    }

    func getRevealedFrameForStashedWindow(id: CGWindowID) async -> CGRect? {
        store.stashed[id]?.revealedFrame
    }
}

// MARK: - StashedWindowsStoreDelegate

extension StashManager: StashedWindowsStoreDelegate {
    func onStashedWindowsRestored() {
        if !store.stashed.isEmpty {
            startListeningToRevealTriggers()
        }
    }
}

// MARK: - Stash and Unstash

extension StashManager {
    /// Handles `windowResized` notification for the specified window and action.
    /// Decision logic lives in `StashAftermathDecision`; this method only gathers inputs and executes.
    func onWindowResized(action: BoundWindowAction, window: Window, screen: NSScreen) async {
        await applyAftermath(action: action, window: window, screen: screen)
    }

    private func applyAftermath(action: BoundWindowAction, window: Window, screen: NSScreen) async {
        let preferredScreenDiffers: Bool
        if let edge = action.stashEdge,
           let screenForEdge = getScreenForEdge(currentScreen: screen, edge: edge),
           screen != screenForEdge {
            preferredScreenDiffers = true
        } else {
            preferredScreenDiffers = false
        }

        let currentScreen = ScreenUtility.screenContaining(window) ?? screen
        let isWindowFullyOnScreen = currentScreen.cgSafeScreenFrame.contains(window.frame)

        let lastActionForUndo: WindowAction?
        if case .special(.undo) = action.action {
            lastActionForUndo = await WindowRecords.shared.getCurrentAction(for: window)?.action
        } else {
            lastActionForUndo = nil
        }

        let outcome = StashAftermathDecision.decide(
            .init(
                action: action.action,
                isManaged: isManaged(window.cgWindowID),
                preferredScreenDiffersFromCurrent: preferredScreenDiffers,
                isWindowFullyOnScreen: isWindowFullyOnScreen,
                lastActionForUndo: lastActionForUndo
            )
        )

        switch outcome {
        case .stash:
            let windowToStash = await StashedWindowInfo.create(
                window: window,
                screen: screen,
                action: action,
                peekSize: stashedWindowVisiblePadding
            )
            await stash(windowToStash)

        case .redirectStashToPreferredScreen:
            guard let edge = action.stashEdge,
                  let screenForEdge = getScreenForEdge(currentScreen: screen, edge: edge) else {
                return
            }
            log.info("Requested stash edge is unavailable on the current screen; redirecting to an eligible screen")
            await applyAftermath(action: action, window: window, screen: screenForEdge)

        case let .unstash(resetFrame):
            // initialFrame: frame already moved by the resize that triggered this hook.
            await unstash(window.cgWindowID, resetFrame: resetFrame, resetFrameAnimated: animate)

        case let .reprocess(nextAction):
            await applyAftermath(
                action: BoundWindowAction(action: nextAction, keybind: action.keybind),
                window: window,
                screen: screen
            )

        case let .refreshManagedFrames(markRevealedIfFullyOnScreen):
            guard let stashedWindow = store.stashed[window.cgWindowID] else { return }
            let updated = await stashedWindow.updatingFrames(
                screen: currentScreen,
                peekSize: stashedWindowVisiblePadding
            )
            store.setStashedWindow(cgWindowID: window.cgWindowID, to: updated)
            if markRevealedIfFullyOnScreen, !store.isWindowRevealed(window.cgWindowID) {
                store.markWindowAsRevealed(window.cgWindowID)
            }

        case .ignore:
            break

        case .unmanage:
            unmanage(windowID: window.cgWindowID)
        }
    }

    /// Add the given `StashWindow` to the list of monitored windows, move the window to the stashed area
    /// and start mouse moved listener if needed.
    private func stash(_ windowToStash: StashedWindowInfo) async {
        log.info("stash \(windowToStash.window.description)")

        await unstashOverlappingWindows(windowToStash)

        store.setStashedWindow(cgWindowID: windowToStash.window.cgWindowID, to: windowToStash)
        await hideWindow(windowToStash, allowUnrevealed: true, shouldThrottle: false)
        startListeningToRevealTriggers()
    }

    /// Stop monitoring the window with the given `CGWindowID`.
    private func unstash(_ windowID: CGWindowID, resetFrame: Bool, resetFrameAnimated: Bool) async {
        if let windowToUnstash = store.stashed[windowID] {
            await unstash(windowToUnstash, resetFrame: resetFrame, resetFrameAnimated: resetFrameAnimated)
        } else {
            unmanage(windowID: windowID)
        }
    }

    /// Stop monitoring the window. If `resetFrame` is true, the window will be moved to its initial frame.
    private func unstash(_ window: StashedWindowInfo, resetFrame: Bool, resetFrameAnimated: Bool) async {
        log.info("unstash \(window.window.description)")

        if resetFrame {
            if resetFrameAnimated {
                try? await window.window.setFrameAnimated(
                    window.restoreFrame,
                    bounds: .zero
                )
            } else {
                await window.window.setFrame(window.restoreFrame)
            }
        }

        unmanage(windowID: window.window.cgWindowID)
    }

    func restoreAllStashedWindows() {
        let stashedWindowIDs = Array(store.stashed.keys)

        for stashedWindowID in stashedWindowIDs {
            unstashSynchronously(stashedWindowID, resetFrame: true)
        }
    }

    private func unstashSynchronously(_ windowID: CGWindowID, resetFrame: Bool) {
        if let windowToUnstash = store.stashed[windowID] {
            unstashSynchronously(windowToUnstash, resetFrame: resetFrame)
        } else {
            unmanage(windowID: windowID)
        }
    }

    private func unstashSynchronously(_ window: StashedWindowInfo, resetFrame: Bool) {
        log.info("unstash \(window.window.description)")

        if resetFrame {
            window.window.setFrameSynchronously(window.restoreFrame)
        }

        unmanage(windowID: window.window.cgWindowID)
    }
}

// MARK: - Reveal and Hide

private extension StashManager {
    /// Reveals a stashed window by moving it to its reveal frame.
    func revealWindow(_ window: StashedWindowInfo) async {
        let windowID = window.window.cgWindowID

        guard !store.isWindowRevealed(windowID) else { return }
        guard !shouldThrottle(windowID: windowID) else { return }

        // Keep only one window as revealed
        for revealedWindowId in store.revealed {
            guard revealedWindowId != windowID else { continue }
            guard let revealedWindow = store.stashed[revealedWindowId] else { break }

            // Run on another thread to prevent this window's reveal from delaying
            Task {
                // No need to unfocus the previously revealed window, since we'll focus our window below anyway
                await hideWindow(revealedWindow, shouldUnfocus: false)
            }
        }

        let transitionID = beginTransition(windowID: windowID, revealed: true)
        let frame = window.revealedFrame

        if shiftFocusWhenStashed {
            Task { @MainActor in
                window.window.focus()
            }
        }

        do {
            if animate {
                try await window.window.setFrameAnimated(
                    frame,
                    bounds: .zero
                )
            } else {
                await window.window.setFrame(frame)
            }
        } catch is CancellationError {
            cancelTransition(windowID: windowID, transitionID: transitionID, fallbackRevealed: false)
            return
        } catch {
            cancelTransition(windowID: windowID, transitionID: transitionID, fallbackRevealed: false)
            log.error("Failed to revealWindow \(window.window.description): \(ApplicationLogPrivacy.errorDescription(error))")
            return
        }

        if finishTransition(windowID: windowID, transitionID: transitionID) {
            log.info("revealWindow \(window.window.description)")
        }
    }

    /// Hides a stashed window by moving it to its stashed frame.
    func hideWindow(_ window: StashedWindowInfo, shouldUnfocus: Bool = true, allowUnrevealed: Bool = false, shouldThrottle: Bool = true) async {
        let windowID = window.window.cgWindowID

        guard allowUnrevealed || store.isWindowRevealed(windowID) else {
            log.warn("Skipping hideWindow because window is not revealed: \(window.window.description)")
            return
        }

        guard !shouldThrottle || !self.shouldThrottle(windowID: windowID) else {
            log.warn("Skipping hideWindow because transition is throttled: \(window.window.description)")
            return
        }

        let transitionID = beginTransition(windowID: windowID, revealed: false)
        let frame = window.stashedFrame

        if shouldUnfocus {
            unfocus(windowID)
        }

        do {
            if animate {
                try await window.window.setFrameAnimated(
                    frame,
                    bounds: .zero
                )
            } else {
                await window.window.setFrame(frame)
            }
        } catch is CancellationError {
            cancelTransition(windowID: windowID, transitionID: transitionID, fallbackRevealed: true)
            return
        } catch {
            cancelTransition(windowID: windowID, transitionID: transitionID, fallbackRevealed: true)
            log.error("Failed to hideWindow \(window.window.description): \(ApplicationLogPrivacy.errorDescription(error))")
            return
        }

        if finishTransition(windowID: windowID, transitionID: transitionID) {
            log.info("hideWindow \(window.window.description)")
        }
    }

    /// Checks if the window reveal / hide should be throttled based on the last reveal time.
    func shouldThrottle(windowID: CGWindowID) -> Bool {
        let now = Date.now
        if let lastTime = lastRevealTime[windowID], now.timeIntervalSince(lastTime) < revealThrottleInterval {
            return true
        }
        lastRevealTime[windowID] = now
        return false
    }

    /// Attempts to unfocus (i.e., shift focus away from) a specified window.
    ///
    /// This method looks for the first (topmost) visible, non-minimized window on the same screen as the specified window,
    /// and tries to activate it (i.e., bring it to the foreground).
    func unfocus(_ windowID: CGWindowID) {
        guard shiftFocusWhenStashed else { return }
        guard let stashedWindow = store.stashed[windowID] else { return }
        guard let screen = ScreenUtility.screenContaining(stashedWindow.window) ?? NSScreen.main else { return }

        let focusWindow = WindowUtility.windowList().first { window in
            guard let currentWindowScreen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return false }
            guard screen.isSameScreen(currentWindowScreen) else { return false }

            return store.stashed[window.cgWindowID] == nil
                && window.cgWindowID != windowID
                && !window.isApplicationHidden
                && !window.isWindowHidden
                && !window.minimized
        }

        if let focusWindow {
            log.info("Focusing another window on the same screen: \(focusWindow.description).")
            Task { @MainActor in
                focusWindow.focus()
            }
        }
    }
}

// MARK: - Mouse moved listener

private extension StashManager {
    func startListeningToRevealTriggers() {
        guard mouseMonitor == nil else { return }

        log.info("Listening for reveal triggers…")

        let monitor = PassiveEventMonitor(
            "stash_mouse_movement_monitor",
            events: [
                .mouseMoved, // Normal mouse movement
                .leftMouseDragged // Dragging items to stashed windows
            ],
            callback: { [weak self] cgEvent in
                self?.handleMouseMoved(cgEvent: cgEvent)
            }
        )
        monitor.start()
        mouseMonitor = monitor

        frontmostAppMonitor = Task { @MainActor [weak self] in
            guard let self else { return }

            let notifications = NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didActivateApplicationNotification
            )

            for await notification in notifications {
                guard !Task.isCancelled else { return }
                processFrontmostAppChange(with: notification)
            }
        }
    }

    func stopListeningToRevealTriggers() {
        guard mouseMonitor != nil else { return }

        log.info("Stopping listening for reveal triggers…")

        // Cancel tasks first
        frontmostAppMonitor?.cancel()
        frontmostAppMonitor = nil

        let monitor = mouseMonitor
        mouseMonitor = nil
        monitor?.stop()
        withExtendedLifetime(monitor) {}
    }

    /// Handles mouse movement events with a debounce to avoid excessive processing.
    private func handleMouseMoved(cgEvent _: CGEvent) {
        mouseMovedTask?.cancel()

        mouseMovedTask = Task {
            try? await Task.sleep(for: .seconds(mouseMovedDebounceInterval))

            guard !Task.isCancelled else {
                return
            }

            await processMouseMovement()
        }
    }

    /// Handles mouse movement events to reveal or hide stashed windows.
    private func processMouseMovement() async {
        let mouseLocation = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

        // Skip CG listing when cursor is far from every stash/reveal region (store frames only).
        let nearAnyStash = StashZOrderPolicy.isMouseNearAnyStash(
            location: mouseLocation,
            stashedFrames: store.stashed.values.map(\.stashedFrame),
            revealedFrames: store.stashed.values.map(\.revealedFrame)
        )
        guard nearAnyStash else { return }

        let windows = getZSortedStashedWindows()

        for window in windows {
            if store.isWindowRevealed(window.window.cgWindowID) {
                if await shouldHide(window: window, for: mouseLocation) {
                    await hideWindow(window)
                } else {
                    break
                }
            } else if await isMouseOverStashed(window: window, location: mouseLocation) {
                // The cursor is over the topmost stashed window that should be revealed
                // revealWindow will move it on screen and hide any other revealed window.
                await revealWindow(window)
                // Only one window can be revealed at a time, so stop processing.
                break
            }
        }
    }

    private func processFrontmostAppChange(with notification: Notification) {
        Task {
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let appWindow = try? Window(pid: app.processIdentifier)
            else {
                return
            }

            let mouseLocation = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
            let windows = getZSortedStashedWindows()

            for window in windows {
                if store.isWindowRevealed(window.window.cgWindowID) {
                    if appWindow.cgWindowID != window.window.cgWindowID,
                       await !isMouseOverStashed(window: window, location: mouseLocation) {
                        await hideWindow(window, shouldUnfocus: false) // No need to unfocus, since the user already did that
                    } else {
                        break
                    }
                } else {
                    if appWindow.cgWindowID == window.window.cgWindowID {
                        // The stashed window has been activated through non-mouse means (e.g. Spotlight, cmd+tab etc.)
                        // revealWindow will move it on screen and hide any other revealed window.
                        await revealWindow(window)
                        // Only one window can be revealed at a time, so stop processing.
                        break
                    }
                }
            }
        }
    }

    /// Returns the list of stashed windows sorted by their z-index (front to back).
    /// This sorting is essential because if multiple stashed windows overlap and the cursor
    /// is over their shared area, we should only reveal the topmost window.
    private func getZSortedStashedWindows() -> [StashedWindowInfo] {
        // CG on-screen list is front-to-back; use lightweight (no AX) IDs only for ranking.
        StashZOrderPolicy.stashedInZOrder(
            zOrderedWindowIDs: WindowUtility.lightweightWindowList().map(\.cgWindowID),
            stashed: store.stashed
        )
    }

    /// Determines whether a revealed window should be hidden based on the mouse location.
    /// Adds a tolerance to the revealed frame to avoid hiding the window during minor cursor movement and on resize.
    private func shouldHide(window: StashedWindowInfo, for location: CGPoint) async -> Bool {
        // Hide the window if the cursor is neither over the revealedFrame nor the stashedFrame.
        let tolerance = StashZOrderPolicy.proximityTolerance
        let revealedFrame = window.revealedFrame.insetBy(dx: -tolerance, dy: -tolerance)
        let stashedFrame = window.stashedFrame
        return !revealedFrame.contains(location) && !stashedFrame.contains(location)
    }

    /// Checks if the mouse is currently hovering over the stashed frame of a window.
    private func isMouseOverStashed(window: StashedWindowInfo, location: CGPoint) async -> Bool {
        window.stashedFrame.contains(location)
    }
}

// MARK: - Overlap logic

private extension StashManager {
    /// Unstashes windows that overlap the newly stashed window on the same screen and edge, ensuring that every
    /// remaining stash keeps a large enough individually targetable area.
    ///
    /// This function scans all currently stashed windows (excluding the incoming window) and delegates the
    /// screen, edge, and visible-area decision to `StashOverlapPolicy`.
    ///
    /// If there is not enough space, the stashed window will be unstashed (i.e., made fully visible and removed from the stash)
    /// and replaced by `windowToStash`
    func unstashOverlappingWindows(_ windowToStash: StashedWindowInfo) async {
        for (id, stashedWindow) in store.stashed {
            // windowToStash is already managed by StashManager. Can't overlap with itself.
            guard id != windowToStash.window.cgWindowID else { continue }

            let shouldReplace = StashOverlapPolicy.shouldReplaceExistingWindow(
                incomingFrame: windowToStash.stashedFrame,
                incomingEdge: windowToStash.action.stashEdge,
                existingFrame: stashedWindow.stashedFrame,
                existingEdge: stashedWindow.action.stashEdge,
                isSameScreen: stashedWindow.screen.isSameScreen(windowToStash.screen),
                minimumVisibleSize: minimumVisibleSizeToKeepWindowStacked
            )

            guard shouldReplace else { continue }

            log.info("Replacing a stashed window whose visible area overlaps the incoming stash…")
            await unstash(stashedWindow, resetFrame: true, resetFrameAnimated: animate)
        }
    }
}

// MARK: - Helpers

private extension StashManager {
    func isManaged(_ windowID: CGWindowID) -> Bool {
        store.stashed[windowID] != nil
    }

    /// Cleanup references of the given window ID from the stash manager.
    func unmanage(windowID: CGWindowID) {
        store.setStashedWindow(cgWindowID: windowID, to: nil)
        store.markWindowAsRevealed(windowID)
        lastRevealTime.removeValue(forKey: windowID)
        transitionIDs.removeValue(forKey: windowID)

        if store.stashed.isEmpty {
            stopListeningToRevealTriggers()
        }
    }

    func getScreenForEdge(currentScreen: NSScreen, edge: StashEdge) -> NSScreen? {
        // Two screens are considered in the same "row" or "column" if they overlap by at least `threshold` points
        let threshold: CGFloat = 100

        return switch edge {
        case .left:
            currentScreen.leftmostScreenInSameRow(overlapThreshold: threshold)
        case .right:
            currentScreen.rightmostScreenInSameRow(overlapThreshold: threshold)
        case .bottom:
            currentScreen.bottommostScreenInSameColumn(overlapThreshold: threshold)
        }
    }

    func beginTransition(windowID: CGWindowID, revealed: Bool) -> UUID {
        let transitionID = UUID()
        transitionIDs[windowID] = transitionID

        if revealed {
            store.markWindowAsRevealed(windowID)
        } else {
            store.markWindowAsHidden(windowID)
        }

        return transitionID
    }

    @discardableResult
    func finishTransition(windowID: CGWindowID, transitionID: UUID) -> Bool {
        guard transitionIDs[windowID] == transitionID else {
            return false
        }

        transitionIDs.removeValue(forKey: windowID)
        return true
    }

    func cancelTransition(windowID: CGWindowID, transitionID: UUID, fallbackRevealed: Bool) {
        guard finishTransition(windowID: windowID, transitionID: transitionID) else {
            return
        }

        if fallbackRevealed {
            store.markWindowAsRevealed(windowID)
        } else {
            store.markWindowAsHidden(windowID)
        }
    }
}
