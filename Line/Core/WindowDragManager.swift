//
//  WindowDragManager.swift
//  Line
//
//  Created by nnecec on 2023-09-04.
//

import Defaults
import Scribe
import SwiftUI

enum WindowDragMonitoringPolicy {
    static func shouldMonitor(
        windowSnapping: Bool,
        restoreWindowFrameOnDrag: Bool,
        hasStashedWindows: Bool
    ) -> Bool {
        windowSnapping || restoreWindowFrameOnDrag || hasStashedWindows
    }
}

@Loggable
@MainActor
final class WindowDragManager {
    static let shared = WindowDragManager()
    private init() {}

    private var resizeContext: ResizeContext?
    private var dragSession = DragSnapSession()

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: PassiveEventMonitor?
    private var leftMouseUpMonitor: PassiveEventMonitor?

    private var determineDraggedWindowTask: Task<(), Never>?
    private var determineDraggedWindowGeneration: UInt = 0
    private var accessibilityCheckerTask: Task<(), Never>?

    private var currentMousePosition: CGPoint {
        NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
    }

    /// This is to avoid running global drag logic unless a feature actually depends on it.
    private var shouldMonitorDragActions: Bool {
        WindowDragMonitoringPolicy.shouldMonitor(
            windowSnapping: Defaults[.windowSnapping],
            restoreWindowFrameOnDrag: Defaults[.restoreWindowFrameOnDrag],
            hasStashedWindows: !Defaults[.stashManagerStashedWindows].isEmpty
        )
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
                    resetDragState()
                    previewController.close()
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
            previewController.close()
            resetDragState()
            return
        }

        Task {
            let effects = dragSession.handle(
                .dragged(
                    currentFrame: resizeContext?.window?.frame,
                    configuration: .init(
                        windowSnapping: Defaults[.windowSnapping],
                        restoreInitialWindowSize: Defaults[.restoreWindowFrameOnDrag]
                    )
                )
            )
            await execute(effects)
        }
    }

    private func leftMouseUp(_: CGEvent) {
        Task {
            let effects = dragSession.handle(
                .released(
                    currentFrame: resizeContext?.window?.frame,
                    hasSnapAction: !(resizeContext?.action.direction.isNoOp ?? true),
                    windowSnapping: Defaults[.windowSnapping]
                )
            )
            await execute(effects)
        }
    }

    private func setCurrentDraggingWindow() {
        guard determineDraggedWindowTask == nil else {
            return
        }

        determineDraggedWindowGeneration &+= 1
        let generation = determineDraggedWindowGeneration
        determineDraggedWindowTask = Task {
            defer {
                if determineDraggedWindowGeneration == generation {
                    determineDraggedWindowTask = nil
                }
            }

            guard let window = WindowUtility.windowAtPosition(currentMousePosition),
                  !WindowStateValidator.shouldIgnore(window)
            else {
                _ = dragSession.handle(.windowResolutionFailed)
                return
            }

            let initialFrame = window.frame

            let context = ResizeContext(
                window: window,
                initialMousePosition: currentMousePosition
            )
            await context.refreshResolvedState()
            guard !Task.isCancelled,
                  determineDraggedWindowGeneration == generation
            else {
                return
            }

            self.resizeContext = context
            _ = dragSession.handle(.windowResolved(initialFrame: initialFrame))

            log.info("Determined window being dragged: \(window.description)")
        }
    }

    private func resetDragState() {
        resizeContext = nil
        dragSession = DragSnapSession()
        determineDraggedWindowGeneration &+= 1
        determineDraggedWindowTask?.cancel()
        determineDraggedWindowTask = nil
    }

    private func execute(_ effects: [DragSnapSession.Effect]) async {
        for effect in effects {
            switch effect {
            case .resolveWindow:
                setCurrentDraggingWindow()

            case .restoreInitialWindowSize:
                if let window = resizeContext?.window {
                    await restoreInitialWindowSize(window)
                }

            case .updateSnap:
                prepareForTopEdgeSnapIfNeeded()
                processSnapAction()

            case .notifyWindowManipulated:
                if let window = resizeContext?.window {
                    StashManager.shared.onWindowManipulated(window.cgWindowID)
                }

            case .eraseWindowRecords:
                if let window = resizeContext?.window {
                    await WindowRecords.shared.eraseRecords(for: window)
                }

            case .closePreview:
                previewController.close()

            case .applySnap:
                if let context = resizeContext {
                    do {
                        _ = try await WindowActionEngine.shared.apply(context: context)
                    } catch {
                        log.error("Failed to snap window: \(ApplicationLogPrivacy.errorDescription(error))")
                    }
                }

            case .clearRuntimeState:
                resetDragState()
            }
        }
    }

    private func prepareForTopEdgeSnapIfNeeded() {
        guard Defaults[.suppressMissionControlOnTopDrag],
              let frame = NSScreen.main?.displayBounds,
              let mouseLocation = CGEvent.mouseLocation,
              mouseLocation.y == frame.minY
        else {
            return
        }

        CGWarpMouseCursorPosition(CGPoint(x: mouseLocation.x, y: frame.minY + 1))
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
