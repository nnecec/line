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
    private var mouseMovedMonitor: ActiveEventMonitor?
    private var leftMouseDownMonitor: ActiveEventMonitor?
    private var leftMouseDraggedMonitor: ActiveEventMonitor?
    private var leftMouseUpMonitor: ActiveEventMonitor?

    private weak var viewModel: GridOverlayViewModel?
    private let submitCallback: (GridOverlayViewModel.GridOverlayAction) -> ()
    private let previewCallback: (GridRegion?) -> ()

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

        // Mouse moved (hover)
        mouseMovedMonitor = ActiveEventMonitor(
            "GridMouseMoved",
            events: [.mouseMoved]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                viewModel.handleMouseMoved(at: location)
                self.previewCallback(viewModel.selectedRegion)
            }
            return .forward
        }
        mouseMovedMonitor?.start()

        // Left mouse down
        leftMouseDownMonitor = ActiveEventMonitor(
            "GridLeftMouseDown",
            events: [.leftMouseDown]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                viewModel.handleMouseDown(at: location)
                self.previewCallback(viewModel.selectedRegion)
            }
            return .forward
        }
        leftMouseDownMonitor?.start()

        // Left mouse dragged
        leftMouseDraggedMonitor = ActiveEventMonitor(
            "GridLeftMouseDragged",
            events: [.leftMouseDragged]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                viewModel.handleMouseDragged(at: location)
                self.previewCallback(viewModel.selectedRegion)
            }
            return .forward
        }
        leftMouseDraggedMonitor?.start()

        // Left mouse up (commit or cancel)
        leftMouseUpMonitor = ActiveEventMonitor(
            "GridLeftMouseUp",
            events: [.leftMouseUp]
        ) { [weak self, weak viewModel] _ in
            guard let self, let viewModel else { return .forward }
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                let action = viewModel.handleMouseUp(at: location)
                self.previewCallback(viewModel.selectedRegion)
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
}
