//
//  WindowDragManager.swift
//  Line
//
//  Created by nnecec on 2023-09-04.
//

import Defaults
import Scribe
import SwiftUI

private struct DragEventSnapshot: Sendable {
    let location: CGPoint
}

enum DragFrameSamplingPolicy {
    static let minimumInterval: TimeInterval = 0.05

    static func shouldSample(lastSampleTime: TimeInterval?, now: TimeInterval) -> Bool {
        guard let lastSampleTime else { return true }
        return now - lastSampleTime >= minimumInterval
    }
}

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

    private var preparedResize: WindowResizeExecution.PreparedResize?
    private var dragSession = DragSnapSession()

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: PassiveEventMonitor?
    private var leftMouseUpMonitor: PassiveEventMonitor?

    private var determineDraggedWindowTask: Task<(), Never>?
    private var determineDraggedWindowGeneration: UInt = 0
    private var accessibilityCheckerTask: Task<(), Never>?
    private var dragDrainTask: Task<(), Never>?
    private let dragEventCoalescer = DragEventCoalescer<DragEventSnapshot>()
    private var latestMouseLocation: CGPoint?
    private var lastKnownFrame: CGRect?
    private var lastFrameSampleTime: TimeInterval?

    private var currentMousePosition: CGPoint {
        (latestMouseLocation ?? NSEvent.mouseLocation).flipY(screen: NSScreen.screens[0])
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
        dragEventCoalescer.invalidate()
        dragDrainTask?.cancel()
        dragDrainTask = nil
    }

    private func leftMouseDragged(event: CGEvent) {
        guard shouldMonitorDragActions else {
            previewController.close()
            resetDragState()
            return
        }

        enqueueDragEvent(.dragged(DragEventSnapshot(location: event.location)))
    }

    private func leftMouseUp(event: CGEvent) {
        enqueueDragEvent(.released(DragEventSnapshot(location: event.location)))
    }

    private func enqueueDragEvent(_ event: DragEventCoalescer<DragEventSnapshot>.Event) {
        let shouldSchedule: Bool
        switch event {
        case let .dragged(snapshot):
            shouldSchedule = dragEventCoalescer.submitDragged(snapshot)
        case let .released(snapshot):
            shouldSchedule = dragEventCoalescer.submitReleased(snapshot)
        }

        guard shouldSchedule else { return }
        let drainToken = dragEventCoalescer.drainToken()
        dragDrainTask = Task { @MainActor [weak self] in
            await self?.drainDragEvents(drainToken: drainToken)
        }
    }

    private func drainDragEvents(drainToken: UInt) async {
        guard dragEventCoalescer.isCurrentDrain(drainToken) else { return }
        defer {
            if dragEventCoalescer.isCurrentDrain(drainToken) {
                dragDrainTask = nil
            }
        }

        while let scheduled = dragEventCoalescer.next() {
            guard dragEventCoalescer.isCurrent(scheduled.generation) else { continue }

            switch scheduled.event {
            case let .dragged(snapshot):
                latestMouseLocation = snapshot.location
                let effects = dragSession.handle(
                    .dragged(
                        currentFrame: sampledFrameForDraggedEvent(),
                        configuration: .init(
                            windowSnapping: Defaults[.windowSnapping],
                            restoreInitialWindowSize: Defaults[.restoreWindowFrameOnDrag]
                        )
                    )
                )
                guard dragEventCoalescer.isCurrent(scheduled.generation) else { continue }
                await execute(effects)

            case let .released(snapshot):
                latestMouseLocation = snapshot.location
                let releaseFrame = liveFrameForRelease() ?? lastKnownFrame
                let effects = dragSession.handle(
                    .released(
                        currentFrame: releaseFrame,
                        hasSnapAction: !(preparedResize?.action.direction.isNoOp ?? true),
                        windowSnapping: Defaults[.windowSnapping]
                    )
                )
                // Release cleanup is never discarded because a newer event arrived.
                await execute(effects)
            }
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
            lastKnownFrame = initialFrame
            lastFrameSampleTime = ProcessInfo.processInfo.systemUptime

            let prepared = await WindowResizeExecution.bootstrap(
                window: window,
                initialMousePosition: currentMousePosition
            )
            guard !Task.isCancelled,
                  determineDraggedWindowGeneration == generation
            else {
                return
            }

            self.preparedResize = prepared
            _ = dragSession.handle(.windowResolved(initialFrame: initialFrame))

            log.info("Determined window being dragged: \(window.description)")
        }
    }

    private func resetDragState() {
        preparedResize = nil
        dragSession = DragSnapSession()
        latestMouseLocation = nil
        lastKnownFrame = nil
        lastFrameSampleTime = nil
        dragEventCoalescer.invalidate()
        determineDraggedWindowGeneration &+= 1
        determineDraggedWindowTask?.cancel()
        determineDraggedWindowTask = nil
    }

    private func sampledFrameForDraggedEvent() -> CGRect? {
        guard preparedResize?.window != nil else { return lastKnownFrame }

        let now = ProcessInfo.processInfo.systemUptime
        guard DragFrameSamplingPolicy.shouldSample(lastSampleTime: lastFrameSampleTime, now: now) else {
            return lastKnownFrame
        }

        lastFrameSampleTime = now
        guard let frame = preparedResize?.window?.frame else { return lastKnownFrame }
        lastKnownFrame = frame
        return frame
    }

    private func liveFrameForRelease() -> CGRect? {
        guard let frame = preparedResize?.window?.frame else { return nil }
        lastKnownFrame = frame
        lastFrameSampleTime = ProcessInfo.processInfo.systemUptime
        return frame
    }

    private func execute(_ effects: [DragSnapSession.Effect]) async {
        for effect in effects {
            switch effect {
            case .resolveWindow:
                setCurrentDraggingWindow()

            case .restoreInitialWindowSize:
                if let window = preparedResize?.window {
                    await restoreInitialWindowSize(window)
                }

            case .updateSnap:
                prepareForTopEdgeSnapIfNeeded()
                processSnapAction()

            case .notifyWindowManipulated:
                if let window = preparedResize?.window {
                    StashManager.shared.onWindowManipulated(window.cgWindowID)
                }

            case .eraseWindowRecords:
                if let window = preparedResize?.window {
                    await WindowRecords.shared.eraseRecords(for: window)
                }

            case .closePreview:
                previewController.close()

            case .applySnap:
                if let preparedResize {
                    do {
                        _ = try await WindowActionEngine.shared.apply(preparedResize: preparedResize)
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

        let oldDirection = preparedResize?.action.direction ?? .noAction
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

            let action = BoundWindowAction(
                action: newDirection.toWindowAction(),
                keybind: []
            )
            if let current = preparedResize {
                let next = WindowResizeExecution.transition(
                    from: current,
                    toAction: action,
                    parentAction: nil,
                    screen: screen
                )
                preparedResize = next
                previewController.open(preparedResize: next)
            }

            if newDirection != .noAction, Defaults[.hapticFeedback] {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }

        case .clear:
            let action = BoundWindowAction(
                action: .special(.noAction),
                keybind: []
            )
            if let current = preparedResize {
                preparedResize = WindowResizeExecution.transition(
                    from: current,
                    toAction: action,
                    parentAction: nil
                )
            }
            previewController.close()

        case .unchanged:
            break
        }
    }
}
