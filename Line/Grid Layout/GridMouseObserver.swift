//
//  GridMouseObserver.swift
//  Line
//
//  Observes mouse events for grid overlay interaction.
//  Created by nnecec on 2024-12-30.

//

import AppKit
import Foundation
import Scribe

@Loggable
@MainActor
final class GridMouseObserver {
    /// Trailing debounce interval for expensive window-preview updates (~60 Hz).
    static let previewThrottleInterval: Duration = .milliseconds(16)

    private var mouseMovedMonitor: ActiveEventMonitor?
    private var leftMouseDownMonitor: ActiveEventMonitor?
    private var leftMouseDraggedMonitor: ActiveEventMonitor?
    private var leftMouseUpMonitor: ActiveEventMonitor?

    private weak var viewModel: GridOverlayViewModel?
    private let submitCallback: (GridOverlayViewModel.GridOverlayAction) -> ()
    private let previewCallback: (GridRegion?) -> ()

    /// Debounced task for hover preview updates (AX-free but still non-trivial work).
    private var previewTask: Task<(), Never>?

    init(
        submitCallback: @escaping (GridOverlayViewModel.GridOverlayAction) -> (),
        previewCallback: @escaping (GridRegion?) -> ()
    ) {
        self.submitCallback = submitCallback
        self.previewCallback = previewCallback
    }

    /// Start monitoring mouse events.
    func start(viewModel: GridOverlayViewModel) {
        stop()
        self.viewModel = viewModel

        // Mouse moved (hover) — viewModel update is cheap; preview is throttled.
        mouseMovedMonitor = ActiveEventMonitor(
            "GridMouseMoved",
            events: [.mouseMoved]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                viewModel.handleMouseMoved(at: location)
                self.schedulePreview(for: viewModel.selectedRegion)
            }
            return .forward
        }
        mouseMovedMonitor?.start()

        // Left mouse down — immediate preview so click starts with correct frame.
        leftMouseDownMonitor = ActiveEventMonitor(
            "GridLeftMouseDown",
            events: [.leftMouseDown]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                viewModel.handleMouseDown(at: location)
                self.flushPreview(for: viewModel.selectedRegion)
            }
            return .forward
        }
        leftMouseDownMonitor?.start()

        // Left mouse dragged — throttle like move (high frequency).
        leftMouseDraggedMonitor = ActiveEventMonitor(
            "GridLeftMouseDragged",
            events: [.leftMouseDragged]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                viewModel.handleMouseDragged(at: location)
                self.schedulePreview(for: viewModel.selectedRegion)
            }
            return .forward
        }
        leftMouseDraggedMonitor?.start()

        // Left mouse up (commit or cancel) — flush pending preview then submit.
        leftMouseUpMonitor = ActiveEventMonitor(
            "GridLeftMouseUp",
            events: [.leftMouseUp]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                let action = viewModel.handleMouseUp(at: location)
                self.flushPreview(for: viewModel.selectedRegion)
                if let action = action {
                    self.submitCallback(action)
                }
            }
            return .forward
        }
        leftMouseUpMonitor?.start()

        log.info("Grid mouse observer started")
    }

    /// Stop monitoring mouse events.
    func stop() {
        previewTask?.cancel()
        previewTask = nil

        mouseMovedMonitor?.stop()
        leftMouseDownMonitor?.stop()
        leftMouseDraggedMonitor?.stop()
        leftMouseUpMonitor?.stop()

        mouseMovedMonitor = nil
        leftMouseDownMonitor = nil
        leftMouseDraggedMonitor = nil
        leftMouseUpMonitor = nil

        viewModel = nil

        log.info("Grid mouse observer stopped")
    }

    /// Resolve hover-only commit (trigger key released without mouse click).
    func hoverCommitAction() -> GridOverlayViewModel.GridOverlayAction? {
        viewModel?.handleHoverCommit()
    }

    /// Handle cancel (Escape, timeout, force close).
    func handleCancel() {
        viewModel?.handleCancel()
    }

    // MARK: - Preview Throttling

    /// Debounce expensive preview updates (Task cancel pattern, ~16 ms).
    private func schedulePreview(for region: GridRegion?) {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: Self.previewThrottleInterval)
            guard !Task.isCancelled else { return }
            previewCallback(region)
        }
    }

    /// Cancel any pending debounced preview and fire immediately.
    private func flushPreview(for region: GridRegion?) {
        previewTask?.cancel()
        previewTask = nil
        previewCallback(region)
    }
}
