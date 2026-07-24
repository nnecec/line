//
//  WindowDragManager.swift
//  Line
//
//  Created by nnecec on 2023-09-04.
//

import Defaults
import Scribe
import SwiftUI

enum WindowDragMouseUpPolicy {
    static func shouldCleanupOnMouseUp(shouldMonitorDragActions: Bool) -> Bool {
        shouldMonitorDragActions
    }

    static func shouldApplySnapOnMouseUp(windowSnapping: Bool) -> Bool {
        windowSnapping
    }
}

@Loggable
@MainActor
final class WindowDragManager {
    static let shared = WindowDragManager()
    private init() {}

    private var resizeContext: ResizeContext?
    private var initialWindowFrame: CGRect?

    /// This is to avoid repeated window resolution attempts during a non-window drag (e.g. in games).
    private var didFailToResolveDraggedWindow: Bool = false

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: PassiveEventMonitor?
    private var leftMouseUpMonitor: PassiveEventMonitor?

    private var determineDraggedWindowTask: Task<(), Never>?
    private var accessibilityCheckerTask: Task<(), Never>?

    private var currentMousePosition: CGPoint {
        NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
    }

    /// This is to avoid running global drag logic unless a feature actually depends on it.
    private var shouldMonitorDragActions: Bool {
        Defaults[.windowSnapping] ||
            Defaults[.restoreWindowFrameOnDrag] ||
            !Defaults[.stashManagerStashedWindows].isEmpty
    }

    func addObservers() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    setupListeners()
                } else {
                    removeListeners()
                }
            }
        }
    }

    func shutdown() {
        accessibilityCheckerTask?.cancel()
        accessibilityCheckerTask = nil
        removeListeners()
        resetDragState()
        previewController.close()
    }

    private func setupListeners() {
        removeListeners()

        let leftMouseDraggedMonitor = PassiveEventMonitor(
            "snapping_left_mouse_dragged_monitor",
            events: [.leftMouseDragged],
            callback: leftMouseDragged
        )

        let leftMouseUpMonitor = PassiveEventMonitor(
            "snapping_left_mouse_up_monitor",
            events: [.leftMouseUp],
            callback: leftMouseUp
        )

        leftMouseDraggedMonitor.start()
        leftMouseUpMonitor.start()

        self.leftMouseDraggedMonitor = leftMouseDraggedMonitor
        self.leftMouseUpMonitor = leftMouseUpMonitor
    }

    private func removeListeners() {
        leftMouseUpMonitor?.stop()
        leftMouseDraggedMonitor?.stop()

        leftMouseUpMonitor = nil
        leftMouseDraggedMonitor = nil
    }

    private func leftMouseDragged(event _: CGEvent) {
        guard shouldMonitorDragActions else {
            return
        }

        Task {
            // Process window (only ONCE during a window drag)
            if resizeContext == nil, !didFailToResolveDraggedWindow {
                setCurrentDraggingWindow()
            }

            if let window = resizeContext?.window,
               let initialFrame = initialWindowFrame,
               hasWindowResized(window.frame, initialFrame) {
                if hasWindowMoved(window.frame, initialFrame) {
                    if Defaults[.restoreWindowFrameOnDrag] {
                        await restoreInitialWindowSize(window)
                    }

                    if Defaults[.windowSnapping] {
                        // Only warp cursor away from top edge if top snap area is enabled
                        if Defaults[.suppressMissionControlOnTopDrag],
                           let frame = NSScreen.main?.displayBounds,
                           let mouseLocation = CGEvent.mouseLocation,
                           mouseLocation.y == frame.minY {
                            let newOrigin = CGPoint(x: mouseLocation.x, y: frame.minY + 1)
                            CGWarpMouseCursorPosition(newOrigin)
                        }

                        processSnapAction()
                    }
                }

                StashManager.shared.onWindowManipulated(window.cgWindowID)
                await WindowRecords.shared.eraseRecords(for: window)
            }
        }
    }

    private func leftMouseUp(_: CGEvent) {
        guard WindowDragMouseUpPolicy.shouldCleanupOnMouseUp(
            shouldMonitorDragActions: shouldMonitorDragActions
        ) else {
            return
        }

        Task {
            previewController.close()
            defer {
                resetDragState()
            }

            guard WindowDragMouseUpPolicy.shouldApplySnapOnMouseUp(
                windowSnapping: Defaults[.windowSnapping]
            ) else {
                return
            }

            if let context = resizeContext,
               !context.action.direction.isNoOp,
               let window = context.window,
               let initialFrame = initialWindowFrame,
               hasWindowMoved(window.frame, initialFrame) {
                do {
                    _ = try await WindowActionEngine.shared.apply(context: context)
                } catch {
                    log.error("Failed to snap window: \(ApplicationLogPrivacy.errorDescription(error))")
                }
            }
        }
    }

    private func setCurrentDraggingWindow() {
        guard determineDraggedWindowTask == nil else {
            return
        }

        determineDraggedWindowTask = Task {
            defer {
                determineDraggedWindowTask = nil
            }

            guard let window = WindowUtility.windowAtPosition(currentMousePosition),
                  !WindowStateValidator.shouldIgnore(window)
            else {
                didFailToResolveDraggedWindow = true
                return
            }

            initialWindowFrame = window.frame

            let context = ResizeContext(
                window: window,
                initialMousePosition: currentMousePosition
            )
            await context.refreshResolvedState()
            self.resizeContext = context

            log.info("Determined window being dragged: \(window.description)")
        }
    }

    private func resetDragState() {
        resizeContext = nil
        didFailToResolveDraggedWindow = false
        initialWindowFrame = nil
        determineDraggedWindowTask?.cancel()
        determineDraggedWindowTask = nil
    }

    private func hasWindowMoved(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        DragSnapPolicy.hasWindowMoved(windowFrame, initialFrame)
    }

    private func hasWindowResized(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        DragSnapPolicy.hasWindowResized(windowFrame, initialFrame)
    }

    private func restoreInitialWindowSize(_ window: Window) async {
        let startFrame = window.frame

        guard let initialFrame = await WindowRecords.shared.getInitialFrame(for: window) else {
            return
        }

        if let screen = NSScreen.screenWithMouse {
            var newWindowFrame = window.frame
            newWindowFrame.size = initialFrame.size
            newWindowFrame = newWindowFrame.pushInside(screen.displayBounds)
            await window.setFrame(newWindowFrame)
        } else {
            window.setSize(initialFrame.size)
        }

        // If the window doesn't contain the cursor, keep the original maxX
        if !window.frame.contains(currentMousePosition) {
            var newFrame = window.frame

            newFrame.origin.x = startFrame.maxX - newFrame.width
            await window.setFrame(newFrame)

            // If it still doesn't contain the cursor, move the window to be centered with the cursor
            if !newFrame.contains(currentMousePosition) {
                newFrame.origin.x = currentMousePosition.x - (newFrame.width / 2)
                await window.setFrame(newFrame)
            }
        }

        await WindowRecords.shared.eraseRecords(for: window)
    }

    private func processSnapAction() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        let mainScreen = NSScreen.screens[0]
        let screenFrame = screen.frame.flipY(screen: mainScreen)

        let inset = Defaults[.snapThreshold]
        let topInset = DragSnapPolicy.topInset(
            menubarHeight: screen.menubarHeight,
            edgeInset: inset
        )
        let ignored = DragSnapPolicy.ignoredFrame(
            screenFrame: screenFrame,
            edgeInset: inset,
            topInset: topInset
        )

        let oldDirection = resizeContext?.action.direction ?? .noAction
        let outcome = DragSnapPolicy.decide(
            mouseLocation: currentMousePosition,
            screenFrame: screenFrame,
            ignoredFrame: ignored,
            currentDirection: oldDirection
        )

        switch outcome {
        case let .updateDirection(newDirection):
            Task {
                await AccentColorController.shared.refresh()
            }

            log.info("Window snapping direction changed")

            resizeContext?.setScreen(to: screen)
            let action = BoundWindowAction(
                action: newDirection.toWindowAction(),
                keybind: []
            )
            resizeContext?.setAction(to: action, parent: nil)

            if let context = resizeContext {
                previewController.open(context: context)
            }

            if newDirection != .noAction, Defaults[.hapticFeedback] {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }

        case .clear:
            let action = BoundWindowAction(
                action: .special(.noAction),
                keybind: []
            )
            resizeContext?.setAction(to: action, parent: nil)
            previewController.close()

        case .unchanged:
            break
        }
    }
}
